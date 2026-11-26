-- =============================================================================
-- Telehealth — Hubungkan akun dokter ke entri direktori praktiknya
--
-- Dokter yang mendaftar sendiri belum punya `directory_doctor_id`, sehingga
-- permintaan konsultasi pasien tidak bisa diarahkan ke akunnya.
-- Script ini:
--   1. Memastikan setiap akun dokter punya baris direktori `acc_<uid>`.
--   2. Mengisi `doctor_profiles.directory_doctor_id` dengan id tersebut.
--
-- Jalankan setelah 02_profiles_auth_sync.sql dan 05_doctor_directory_sync.sql.
-- Idempoten.
-- =============================================================================

-- 1. Pastikan baris direktori untuk setiap akun dokter ada.
insert into public.doctors (
  id, name, specialization, experience, rating, price, available,
  hospital, bio, education, avatar_color
)
select
  'acc_' || dp.user_id,
  coalesce(nullif(btrim(p.full_name), ''), 'Dokter Baru'),
  coalesce(nullif(btrim(dp.specialization), ''), 'Dokter Umum'),
  coalesce(dp.experience_years, 0),
  0,
  100000,
  true,
  coalesce(dp.hospital, ''),
  coalesce(dp.bio, ''),
  '',
  x'FF1E88E5'::bigint
from public.doctor_profiles dp
join public.profiles p on p.id = dp.user_id
where nullif(btrim(dp.directory_doctor_id), '') is null
on conflict (id) do update
   set name = excluded.name,
       specialization = excluded.specialization,
       experience = excluded.experience,
       hospital = excluded.hospital,
       bio = excluded.bio;

-- 2. Isi directory_doctor_id agar permintaan konsultasi bisa diarahkan.
update public.doctor_profiles
   set directory_doctor_id = 'acc_' || user_id
 where nullif(btrim(directory_doctor_id), '') is null;

-- Verifikasi: semua akun dokter harus punya directory_doctor_id.
select dp.user_id, p.full_name, dp.directory_doctor_id
  from public.doctor_profiles dp
  join public.profiles p on p.id = dp.user_id
 order by p.full_name;
