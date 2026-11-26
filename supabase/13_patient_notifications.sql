-- =============================================================================
-- Telehealth — Notifikasi Tindak Lanjut Admin → Pasien & Keluarga
--
-- Jalankan setelah:
--   1. 02_profiles_auth_sync.sql  (tabel public.profiles / patient_profiles)
--   2. 03_hospital_admin_rbac.sql (tabel hospital_patients + view monitoring)
--
-- ISI FILE
--   1.  Kolom pendukung kontak keluarga & push token (FCM)
--   2.  Tabel log public.patient_notifications (TANPA RLS)
--   3.  Perluasan view public.hospital_patient_monitoring (nama & telp wali)
--   4.  Realtime publication untuk patient_notifications
--
-- CATATAN
--   • RLS SENGAJA DIMATIKAN pada patient_notifications agar Web Dashboard Admin
--     dapat menulis/membaca log tanpa hambatan policy.
--   • Pengiriman FCM sebenarnya dilakukan oleh Edge Function opsional
--     `send-patient-notification` yang dipanggil dari sisi admin. Bila fungsi
--     tersebut belum dideploy, notifikasi tetap tercatat dan aplikasi mobile
--     dapat menangkapnya lewat Supabase Realtime (lihat publikasi di bawah).
-- =============================================================================

begin;

-- =============================================================================
-- 1. Kolom kontak keluarga + token FCM per pasien rumah sakit
-- =============================================================================
alter table public.hospital_patients
  add column if not exists fcm_token        text,
  add column if not exists family_name      text not null default '',
  add column if not exists family_phone     text not null default '',
  add column if not exists family_fcm_token text;

comment on column public.hospital_patients.fcm_token is
  'Token FCM device HP pasien (diisi aplikasi mobile pasien).';
comment on column public.hospital_patients.family_name is
  'Nama wali/keluarga pendamping pasien.';
comment on column public.hospital_patients.family_phone is
  'Nomor WhatsApp/telepon keluarga (dipakai untuk jalur cadangan wa.me).';
comment on column public.hospital_patients.family_fcm_token is
  'Token FCM device HP keluarga bila terdaftar di aplikasi mobile.';

-- Profil pasien global (dipakai lintas modul; disimpan selaras di sini).
alter table public.patient_profiles
  add column if not exists fcm_token        text,
  add column if not exists family_name      text not null default '',
  add column if not exists family_phone     text not null default '',
  add column if not exists family_fcm_token text;

comment on column public.patient_profiles.family_phone is
  'Nomor WhatsApp/telepon keluarga pendamping pasien.';

-- =============================================================================
-- 2. Log notifikasi tindak lanjut (TANPA RLS)
-- =============================================================================
create table if not exists public.patient_notifications (
  id                  uuid        primary key default gen_random_uuid(),
  patient_uid         text        not null
                                  references public.profiles(id) on delete cascade,
  alert_reference_id  uuid,                          -- id medication_adherence / patient_reports
  sent_by_admin_uid   text        not null default '',
  recipient_target    text        not null default 'both'
                                  check (recipient_target in ('patient', 'family', 'both')),
  delivery_channel    text        not null default 'push_notification'
                                  check (delivery_channel in (
                                    'push_notification',
                                    'whatsapp_link',
                                    'both'
                                  )),
  title               text        not null default '',
  message             text        not null default '',
  status              text        not null default 'sent'
                                  check (status in ('sent', 'delivered', 'failed')),
  created_at          timestamptz not null default now()
);

create index if not exists patient_notifications_patient_idx
  on public.patient_notifications (patient_uid, created_at desc);

create index if not exists patient_notifications_alert_idx
  on public.patient_notifications (alert_reference_id, created_at desc);

comment on table public.patient_notifications is
  'Riwayat pengiriman notifikasi tindak lanjut dari admin RS ke pasien/keluarga.';

-- Matikan RLS secara eksplisit (diminta: tanpa hambatan permission).
alter table public.patient_notifications disable row level security;

-- Beri hak akses PostgREST agar dashboard (authenticated) & klien mobile dapat
-- membaca/menulis log meski RLS nonaktif.
grant select, insert, update on public.patient_notifications
  to authenticated, anon;

-- =============================================================================
-- 3. Perluasan view monitoring dengan kontak keluarga
--    (kolom baru HANYA ditambahkan di akhir agar create or replace valid)
-- =============================================================================
create or replace view public.hospital_patient_monitoring
with (security_invoker = true) as
select
  hp.id,
  hp.hospital_id,
  hp.patient_user_id,
  hp.full_name,
  hp.medical_record_no,
  hp.diagnosis,
  hp.discharge_date,
  hp.attending_doctor_name,
  hp.risk_level,
  hp.is_active,
  coalesce((
    select round(100.0 * sum(a.taken_doses) / nullif(sum(a.scheduled_doses), 0), 1)
    from public.medication_adherence a
    where a.hospital_patient_id = hp.id
  ), 0)::numeric(5, 1) as adherence_score,
  coalesce((
    select sum(a.missed_doses)
    from public.medication_adherence a
    where a.hospital_patient_id = hp.id
      and a.taken_date = current_date
  ), 0)::int as missed_doses_today,
  (
    select count(*)
    from public.patient_reports r
    where r.hospital_patient_id = hp.id
      and r.status <> 'resolved'
  )::int as open_reports,
  (
    select count(*)
    from public.prescriptions p
    where p.hospital_patient_id = hp.id
      and p.status = 'pending_verification'
  )::int as pending_prescriptions,
  (
    select max(a.taken_date)
    from public.medication_adherence a
    where a.hospital_patient_id = hp.id
  ) as last_adherence_date,
  hp.family_name,
  hp.family_phone
from public.hospital_patients hp;

comment on view public.hospital_patient_monitoring is
  'Satu baris per pasien + skor kepatuhan, dosis terlewat hari ini, jumlah laporan terbuka, dan kontak keluarga.';

-- =============================================================================
-- 4. Realtime publication
-- =============================================================================
do $$
begin
  begin
    alter publication supabase_realtime add table public.patient_notifications;
  exception when duplicate_object then null;
  end;
end $$;

commit;
