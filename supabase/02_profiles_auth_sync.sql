-- =============================================================================
-- Telehealth — sinkronisasi profil dari Firebase Auth ke Supabase
--
-- Struktur:
--   1. profiles          → data umum semua akun (id = Firebase user.uid)
--   2. doctor_profiles   → atribut khusus role 'doctor'
--   3. patient_profiles  → atribut khusus role 'patient'
--   4. profile_overview  → view gabungan untuk kebutuhan baca
--
-- Jalankan seluruh file ini di Supabase SQL Editor. File ini berdiri sendiri
-- dan tidak bergantung pada 01_medication_doctor_chat.sql (kecuali bila Anda
-- ingin menautkan kolom directory_doctor_id ke public.doctors).
--
-- CATATAN KEAMANAN
-- Autentikasi aplikasi memakai Firebase, bukan Supabase Auth. Akibatnya
-- `auth.uid()` tidak berisi Firebase UID dan tidak bisa dipakai untuk policy.
-- Policy di bawah sengaja terbuka untuk anon/authenticated agar demo berjalan.
-- Untuk produksi, gunakan salah satu pendekatan berikut:
--   a) migrasikan autentikasi ke Supabase Auth, atau
--   b) verifikasi Firebase ID token di Edge Function lalu tulis memakai
--      service_role key (service_role melewati RLS).
-- Jangan pernah menaruh service_role key di aplikasi Flutter.
-- =============================================================================

-- ─── Extensions ──────────────────────────────────────────────────────────────
create extension if not exists pgcrypto;

-- ─── Updated_at helper ───────────────────────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- =============================================================================
-- 1. Profil umum
-- =============================================================================
create table if not exists public.profiles (
  id           text        primary key,              -- Firebase user.uid
  email        text        not null default '',
  full_name    text        not null default '',
  role         text        not null default 'patient'
                           check (role in ('patient', 'doctor', 'admin')),
  phone        text,
  birth_date   date,
  gender       text        check (gender is null or gender in ('male', 'female', 'other')),
  address      text,
  blood_type   text,
  avatar_color bigint      not null default x'FF1E88E5'::bigint,
  is_active    boolean     not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- Email unik (case-insensitive) selama tidak kosong.
create unique index if not exists profiles_email_unique
  on public.profiles (lower(email))
  where email <> '';

create index if not exists profiles_role_idx
  on public.profiles (role, created_at desc);

comment on table public.profiles is
  'Data akun umum. id sama dengan Firebase Authentication user.uid.';
comment on column public.profiles.gender is
  'Dinormalisasi: male / female / other. Form Indonesia dipetakan di Flutter.';

-- =============================================================================
-- 2. Profil dokter
--
-- Dipisah dari profiles karena kolomnya hanya relevan untuk role doctor dan
-- tidak semua akun memilikinya. Ini lebih aman daripada jsonb untuk data yang
-- perlu divalidasi/di-query (mis. pencarian berdasarkan spesialisasi).
-- =============================================================================
create table if not exists public.doctor_profiles (
  user_id             text        primary key
                                  references public.profiles(id) on delete cascade,
  specialization      text        not null default '',
  str_number          text,                           -- nomor STR / lisensi
  hospital            text,
  experience_years    int         not null default 0
                                  check (experience_years >= 0),
  bio                 text,
  practice_schedule   jsonb       not null default '{}'::jsonb, -- {"Senin - Jumat":"09:00 - 15:00"}
  directory_doctor_id text,                           -- opsional: public.doctors.id
  verified            boolean     not null default false,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- Nomor STR tidak dibuat unik di level database agar registrasi akun tidak
-- gagal sebagian. Verifikasi keunikan sebaiknya dilakukan admin setelah
-- kredensial diperiksa.
drop index if exists public.doctor_profiles_str_unique;
create index if not exists doctor_profiles_str_idx
  on public.doctor_profiles (lower(str_number))
  where str_number is not null and str_number <> '';

create index if not exists doctor_profiles_specialization_idx
  on public.doctor_profiles (specialization);

comment on table public.doctor_profiles is
  'Atribut khusus dokter. Satu baris per akun dengan role doctor.';

-- =============================================================================
-- 3. Profil pasien
--
-- Riwayat medis/alergi bersifat bebas bentuk sehingga disimpan sebagai jsonb,
-- sedangkan kolom yang sering difilter tetap kolom biasa.
-- =============================================================================
create table if not exists public.patient_profiles (
  user_id                 text        primary key
                                      references public.profiles(id) on delete cascade,
  allergies               jsonb       not null default '[]'::jsonb, -- ["debu","kacang"]
  chronic_conditions      jsonb       not null default '[]'::jsonb, -- ["hipertensi"]
  medical_history         text,
  emergency_contact_name  text,
  emergency_contact_phone text,
  height_cm               numeric(5,1) check (height_cm is null or height_cm > 0),
  weight_kg               numeric(5,1) check (weight_kg is null or weight_kg > 0),
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

comment on table public.patient_profiles is
  'Atribut khusus pasien. Satu baris per akun dengan role patient.';

-- =============================================================================
-- 4. Trigger updated_at
-- =============================================================================
drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists doctor_profiles_set_updated_at on public.doctor_profiles;
create trigger doctor_profiles_set_updated_at
  before update on public.doctor_profiles
  for each row execute function public.set_updated_at();

drop trigger if exists patient_profiles_set_updated_at on public.patient_profiles;
create trigger patient_profiles_set_updated_at
  before update on public.patient_profiles
  for each row execute function public.set_updated_at();

-- =============================================================================
-- 5. View gabungan (mudah dibaca dari aplikasi)
-- =============================================================================
create or replace view public.profile_overview
with (security_invoker = true) as
select
  p.id,
  p.email,
  p.full_name,
  p.role,
  p.phone,
  p.birth_date,
  p.gender,
  p.address,
  p.blood_type,
  p.avatar_color,
  p.is_active,
  p.created_at,
  p.updated_at,
  d.specialization,
  d.str_number,
  d.hospital,
  d.experience_years,
  d.bio,
  d.practice_schedule,
  d.directory_doctor_id,
  d.verified,
  pp.allergies,
  pp.chronic_conditions,
  pp.medical_history,
  pp.emergency_contact_name,
  pp.emergency_contact_phone,
  pp.height_cm,
  pp.weight_kg
from public.profiles p
left join public.doctor_profiles d on d.user_id = p.id
left join public.patient_profiles pp on pp.user_id = p.id;

-- =============================================================================
-- 6. Row Level Security (demo)
-- =============================================================================
alter table public.profiles         enable row level security;
alter table public.doctor_profiles  enable row level security;
alter table public.patient_profiles enable row level security;

drop policy if exists demo_all_profiles on public.profiles;
create policy demo_all_profiles on public.profiles
  for all to anon, authenticated using (true) with check (true);

drop policy if exists demo_all_doctor_profiles on public.doctor_profiles;
create policy demo_all_doctor_profiles on public.doctor_profiles
  for all to anon, authenticated using (true) with check (true);

drop policy if exists demo_all_patient_profiles on public.patient_profiles;
create policy demo_all_patient_profiles on public.patient_profiles
  for all to anon, authenticated using (true) with check (true);

-- Hak akses tabel & view untuk client Supabase.
grant select, insert, update, delete
  on public.profiles, public.doctor_profiles, public.patient_profiles
  to anon, authenticated;

grant select on public.profile_overview to anon, authenticated;

-- =============================================================================
-- 7. Opsional: tautkan data dokter ke direktori public.doctors
--    Jalankan hanya bila 01_medication_doctor_chat.sql sudah dieksekusi.
-- =============================================================================
-- alter table public.doctor_profiles
--   add constraint doctor_profiles_directory_doctor_fkey
--   foreign key (directory_doctor_id) references public.doctors(id)
--   on delete set null;
