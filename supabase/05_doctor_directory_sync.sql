-- =============================================================================
-- Telehealth — Sinkronisasi akun dokter terdaftar ke direktori dokter
--
-- Masalah: dokter yang mendaftar lewat aplikasi hanya menulis ke `profiles`
-- dan `doctor_profiles`, sedangkan daftar dokter di aplikasi membaca tabel
-- `doctors`. Akibatnya dokter baru tidak muncul di daftar.
--
-- Solusi:
--   1. Trigger pada doctor_profiles → menyalin data ke `doctors`.
--      - Bila `directory_doctor_id` diisi, baris direktori yang sudah ada
--        diperbarui (nama, spesialisasi, pengalaman, RS, bio).
--      - Bila kosong, dibuat baris baru dengan id `acc_<user_id>`.
--   2. Backfill satu kali untuk akun dokter yang sudah terdaftar.
--
-- Jalankan setelah 01_medication_doctor_chat.sql dan 02_profiles_auth_sync.sql.
-- =============================================================================

create or replace function public.sync_doctor_directory()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_directory_id text;
begin
  select nullif(btrim(p.full_name), '') into v_name
  from public.profiles p
  where p.id = new.user_id;

  if v_name is null then
    v_name := 'Dokter Baru';
  end if;

  -- Kasus 1: dokter memilih entri direktori yang sudah ada.
  v_directory_id := nullif(btrim(new.directory_doctor_id), '');
  if v_directory_id is not null then
    update public.doctors
       set name = v_name,
           specialization = coalesce(
             nullif(btrim(new.specialization), ''),
             specialization
           ),
           experience = coalesce(new.experience_years, experience),
           hospital = coalesce(nullif(btrim(new.hospital), ''), hospital),
           bio = coalesce(nullif(btrim(new.bio), ''), bio)
     where id = v_directory_id;

    if found then
      return new;
    end if;
  end if;

  -- Kasus 2: dokter baru tanpa entri direktori → buat baris direktori sendiri.
  insert into public.doctors (
    id, name, specialization, experience, rating, price, available,
    hospital, bio, education, avatar_color
  )
  values (
    'acc_' || new.user_id,
    v_name,
    coalesce(nullif(btrim(new.specialization), ''), 'Dokter Umum'),
    coalesce(new.experience_years, 0),
    0,          -- belum ada penilaian
    100000,     -- tarif awal konsultasi
    true,
    coalesce(new.hospital, ''),
    coalesce(new.bio, ''),
    '',
    x'FF1E88E5'::bigint
  )
  on conflict (id) do update
     set name = excluded.name,
         specialization = excluded.specialization,
         experience = excluded.experience,
         hospital = excluded.hospital,
         bio = excluded.bio;

  return new;
end;
$$;

drop trigger if exists doctor_profiles_sync_directory on public.doctor_profiles;
create trigger doctor_profiles_sync_directory
after insert or update on public.doctor_profiles
for each row execute function public.sync_doctor_directory();

-- ─── Backfill akun dokter yang sudah terdaftar ──────────────────────────────
-- Entri direktori yang dipilih: perbarui datanya.
update public.doctors d
   set name = coalesce(nullif(btrim(p.full_name), ''), d.name),
       specialization = coalesce(
         nullif(btrim(dp.specialization), ''),
         d.specialization
       ),
       experience = coalesce(dp.experience_years, d.experience),
       hospital = coalesce(nullif(btrim(dp.hospital), ''), d.hospital),
       bio = coalesce(nullif(btrim(dp.bio), ''), d.bio)
  from public.doctor_profiles dp
  join public.profiles p on p.id = dp.user_id
 where d.id = nullif(btrim(dp.directory_doctor_id), '');

-- Akun dokter tanpa entri direktori: buat baris baru.
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

-- ─── Hak akses baca daftar dokter ───────────────────────────────────────────
grant select on public.doctors to anon, authenticated;
grant select on public.doctor_profiles, public.profiles to anon, authenticated;
