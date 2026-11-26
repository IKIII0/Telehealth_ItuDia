-- =============================================================================
-- Telehealth — Satu konsultasi aktif per pasien
--
-- Jalankan setelah 09_doctor_module.sql (dan 11_doctor_patient_bridge.sql).
-- Aman dijalankan berulang.
--
-- MASALAH YANG DIPERBAIKI
--   Pasien dapat membuat permintaan baru saat masih memiliki sesi berjalan
--   (requested / scheduled / ongoing), sehingga muncul dua sesi aktif dan
--   tampilan dokter/pasien menjadi tidak konsisten.
--
-- SOLUSI
--   1. Trigger `enforce_single_active_consultation` menolak insert/update yang
--      menghasilkan lebih dari satu sesi aktif per pasien, dengan pesan jelas.
--   2. Unique index parsial sebagai pengaman terakhir di level storage.
--
-- Sesi dianggap aktif bila status: requested, scheduled, atau ongoing.
-- completed / cancelled / rejected tidak dihitung, sehingga pasien dapat
-- memulai konsultasi baru setelah sesi sebelumnya selesai atau dibatalkan.
-- =============================================================================

create or replace function public.enforce_single_active_consultation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.status in ('requested', 'scheduled', 'ongoing') then
    if exists (
      select 1
      from public.consultation_sessions cs
      where cs.patient_user_id = new.patient_user_id
        and cs.id <> new.id
        and cs.status in ('requested', 'scheduled', 'ongoing')
    ) then
      raise exception
        'Pasien masih memiliki konsultasi aktif. Selesaikan atau batalkan konsultasi tersebut sebelum memulai yang baru.'
        using errcode = '23505';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists consultation_sessions_single_active on public.consultation_sessions;
create trigger consultation_sessions_single_active
  before insert or update of status, patient_user_id
  on public.consultation_sessions
  for each row execute function public.enforce_single_active_consultation();

-- Pasien juga boleh membatalkan sesi yang sudah terjadwal (belum dimulai),
-- supaya tidak terkunci saat dokter belum memulai atau tidak bisa melanjutkan.
drop policy if exists consultation_sessions_patient_cancel on public.consultation_sessions;
create policy consultation_sessions_patient_cancel on public.consultation_sessions
  for update to anon, authenticated
  using (
    patient_user_id = app.current_uid()
    and status in ('requested', 'scheduled')
  )
  with check (
    patient_user_id = app.current_uid()
    and status in ('requested', 'scheduled', 'cancelled')
    and diagnosis = ''
    and doctor_notes = ''
    and started_at is null
    and completed_at is null
  );

-- Pengaman terakhir: tidak mungkin ada dua sesi aktif untuk satu pasien.
-- Dibuat dalam blok agar data lama yang masih bermasalah tidak menggagalkan
-- migrasi; pesan NOTICE akan menampilkan jumlah pasien yang perlu dibersihkan.
do $$
begin
  create unique index if not exists consultation_sessions_one_active_per_patient
    on public.consultation_sessions (patient_user_id)
    where status in ('requested', 'scheduled', 'ongoing');
exception
  when unique_violation then
    raise notice
      'Index unik satu-sesi-aktif tidak dibuat: ada pasien dengan lebih dari satu sesi aktif. '
      'Periksa: select patient_user_id, count(*) from public.consultation_sessions '
      'where status in (''requested'',''scheduled'',''ongoing'') group by 1 having count(*) > 1;';
end;
$$;

-- ── Verifikasi cepat ────────────────────────────────────────────────────────
select
  (select count(*) from pg_trigger
    where tgname = 'consultation_sessions_single_active') as trigger_exists,
  (select count(*) from pg_indexes
    where schemaname = 'public'
      and indexname = 'consultation_sessions_one_active_per_patient') as index_exists,
  (select count(*) from (
      select patient_user_id
      from public.consultation_sessions
      where status in ('requested', 'scheduled', 'ongoing')
      group by 1
      having count(*) > 1
   ) dup) as patients_with_multiple_active;
