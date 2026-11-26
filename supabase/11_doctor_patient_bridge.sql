-- =============================================================================
-- Telehealth — Jembatan role dokter ↔ pasien
--
-- Jalankan setelah 09_doctor_module.sql. Aman dijalankan berulang.
--
-- ISI
--   1. Snapshot nama & spesialisasi dokter pada consultation_sessions, diisi
--      otomatis oleh trigger. Tujuannya: pasien dapat menampilkan info dokter
--      tanpa join ke profiles (relasi memakai Firebase UID, bukan FK).
--   2. Backfill sesi yang sudah ada.
--   3. Policy tambahan: pasien boleh membatalkan permintaannya sendiri selama
--      masih berstatus requested.
--
-- Catatan: policy baca/tulis peserta sesi, chat, dan resep sudah dibuat di
-- 09_doctor_module.sql, jadi file ini tidak mengubahnya.
-- =============================================================================

-- ── 1. Kolom snapshot dokter ─────────────────────────────────────────────────
alter table public.consultation_sessions
  add column if not exists doctor_name text not null default '',
  add column if not exists doctor_specialization text not null default '';

create index if not exists consultation_sessions_doctor_name_idx
  on public.consultation_sessions (doctor_name);

create or replace function public.consultation_sessions_fill_doctor()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if coalesce(trim(new.doctor_name), '') = '' then
    select coalesce(nullif(trim(p.full_name), ''), new.doctor_user_id)
      into new.doctor_name
    from public.profiles p
    where p.id = new.doctor_user_id;
  end if;

  if coalesce(trim(new.doctor_specialization), '') = '' then
    select dp.specialization
      into new.doctor_specialization
    from public.doctor_profiles dp
    where dp.user_id = new.doctor_user_id;
  end if;

  return new;
end;
$$;

drop trigger if exists consultation_sessions_fill_doctor on public.consultation_sessions;
create trigger consultation_sessions_fill_doctor
  before insert on public.consultation_sessions
  for each row execute function public.consultation_sessions_fill_doctor();

-- ── 2. Backfill ─────────────────────────────────────────────────────────────
update public.consultation_sessions cs
set doctor_name = coalesce(nullif(trim(p.full_name), ''), cs.doctor_user_id),
    doctor_specialization = coalesce(dp.specialization, '')
from public.profiles p
left join public.doctor_profiles dp on dp.user_id = p.id
where p.id = cs.doctor_user_id
  and (
    coalesce(trim(cs.doctor_name), '') = ''
    or coalesce(trim(cs.doctor_specialization), '') = ''
  );

-- ── 3. Pasien membatalkan permintaannya sendiri ─────────────────────────────
-- Hanya status `requested` yang boleh dibatalkan lewat policy ini; perubahan
-- status lain tetap harus melalui RPC dokter.
drop policy if exists consultation_sessions_patient_cancel on public.consultation_sessions;
create policy consultation_sessions_patient_cancel on public.consultation_sessions
  for update to anon, authenticated
  using (
    patient_user_id = app.current_uid()
    and status = 'requested'
  )
  with check (
    patient_user_id = app.current_uid()
    and status in ('requested', 'cancelled')
    and diagnosis = ''
    and doctor_notes = ''
    and started_at is null
    and completed_at is null
  );

-- ── 4. Verifikasi cepat ─────────────────────────────────────────────────────
select
  (to_regclass('public.consultation_sessions') is not null) as table_exists,
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'consultation_sessions'
      and column_name = 'doctor_name'
  ) as doctor_name_column,
  (
    select count(*)
    from public.consultation_sessions
    where coalesce(trim(doctor_name), '') <> ''
  ) as sessions_with_doctor_name;
