-- =============================================================================
-- Telehealth — Master Database Obat (`medicines_catalog`)
--
-- Jalankan setelah:
--   1. 01_medication_doctor_chat.sql
--   2. 02_profiles_auth_sync.sql
--   3. 03_hospital_admin_rbac.sql   (menyediakan app.is_hospital_admin())
--
-- ISI FILE
--   1.  Ekstensi pg_trgm + tabel public.medicines_catalog
--   2.  Index pencarian teks (trigram GIN + ILIKE fallback)
--   3.  RLS: semua pengguna terotentikasi boleh SELECT; hanya hospital_admin
--       (atau super_admin) yang boleh INSERT/UPDATE
--   4.  Seed 25 obat umum pasca rawat inap (idempoten)
--
-- CATATAN
--   - File ini tidak mengubah tabel resep/pasien/dokter. Katalog obat hanya
--     menjadi referensi pencarian pada Web Dashboard Admin Rumah Sakit.
--   - `app.is_hospital_admin()` didefinisikan di 03_hospital_admin_rbac.sql dan
--     mengembalikan `true` untuk `hospital_admin` maupun `super_admin`.
--   - Jika project Anda menjalankan request sebagai role `anon` (Firebase tanpa
--     custom claim `role: authenticated`), lihat blok opsional di bagian 4.
-- =============================================================================

-- =============================================================================
-- 1. Tabel katalog obat
-- =============================================================================
create extension if not exists pg_trgm with schema extensions;

create table if not exists public.medicines_catalog (
  id                        uuid        primary key default gen_random_uuid(),
  medicine_name             text        not null unique,
  generic_name              text        not null default '',
  category                  text        not null default 'Lainnya',
  dosage_form               text        not null default 'Tablet',
  default_dosage            text        not null default '',
  default_frequency_per_day int         not null default 1
                                        check (default_frequency_per_day between 1 and 12),
  default_duration_days     int         not null default 1
                                        check (default_duration_days between 1 and 365),
  default_instructions      text        not null default '',
  is_active                 boolean     not null default true,
  created_at                timestamptz not null default now()
);

comment on table public.medicines_catalog is
  'Master referensi obat pasca rawat inap untuk autocomplete pada Web '
  'Dashboard Admin Rumah Sakit.';

comment on column public.medicines_catalog.medicine_name is
  'Nama obat + kekuatan sediaan, mis. "Amoxicillin 500 mg". Unik.';
comment on column public.medicines_catalog.generic_name is
  'Nama zat aktif / generik, mis. "Amoxicillin".';
comment on column public.medicines_catalog.default_dosage is
  'Dosis standar, mis. "1 Tablet" atau "10 ml".';
comment on column public.medicines_catalog.default_instructions is
  'Instruksi konsumsi standar, mis. "Diminum sesudah makan".';

-- =============================================================================
-- 2. Index pencarian teks
-- =============================================================================

-- Trigram GIN mempercepat ILIKE '%kata%' pada kolom nama obat & zat aktif.
create index if not exists medicines_catalog_name_trgm_idx
  on public.medicines_catalog using gin (medicine_name gin_trgm_ops);

create index if not exists medicines_catalog_generic_trgm_idx
  on public.medicines_catalog using gin (generic_name gin_trgm_ops);

-- Index tambahan untuk filter kategori/form dan daftar aktif.
create index if not exists medicines_catalog_category_idx
  on public.medicines_catalog (category, dosage_form)
  where is_active;

create index if not exists medicines_catalog_active_name_idx
  on public.medicines_catalog (is_active, medicine_name);

-- =============================================================================
-- 3. Row Level Security
-- =============================================================================
alter table public.medicines_catalog enable row level security;

-- SELECT: seluruh pengguna terotentikasi (hospital_admin, doctor, patient).
drop policy if exists medicines_catalog_read on public.medicines_catalog;
create policy medicines_catalog_read on public.medicines_catalog
  for select to authenticated
  using (true);

-- INSERT: hanya admin rumah sakit / super admin.
drop policy if exists medicines_catalog_admin_insert on public.medicines_catalog;
create policy medicines_catalog_admin_insert on public.medicines_catalog
  for insert to authenticated
  with check (app.is_hospital_admin());

-- UPDATE: hanya admin rumah sakit / super admin.
drop policy if exists medicines_catalog_admin_update on public.medicines_catalog;
create policy medicines_catalog_admin_update on public.medicines_catalog
  for update to authenticated
  using (app.is_hospital_admin())
  with check (app.is_hospital_admin());

-- Hak tabel (RLS tetap menjadi pembatas baris).
grant select on public.medicines_catalog to authenticated;
grant insert, update on public.medicines_catalog to authenticated;

-- =============================================================================
-- 4. Seed data obat umum pasca rawat inap
--
-- Idempoten: `on conflict (medicine_name) do nothing` sehingga aman dijalankan
-- ulang dan tidak menimpa perubahan admin.
-- =============================================================================
insert into public.medicines_catalog (
  medicine_name,
  generic_name,
  category,
  dosage_form,
  default_dosage,
  default_frequency_per_day,
  default_duration_days,
  default_instructions
) values
  -- Antibiotik
  ('Amoxicillin 500 mg',        'Amoxicillin',      'Antibiotik',        'Kapsul',   '1 Kapsul', 3, 7,  'Diminum sesudah makan dan dihabiskan sesuai jadwal.'),
  ('Amoxicillin 250 mg/5 ml',   'Amoxicillin',      'Antibiotik',        'Suspensi', '5 ml',     3, 7,  'Dikocok dahulu, diminum sesudah makan.'),
  ('Cefixime 200 mg',           'Cefixime',         'Antibiotik',        'Kapsul',   '1 Kapsul', 2, 5,  'Diminum sesudah makan pagi dan malam.'),
  ('Azithromycin 500 mg',       'Azithromycin',     'Antibiotik',        'Tablet',   '1 Tablet', 1, 3,  'Diminum 1 jam sebelum atau 2 jam sesudah makan.'),
  ('Ciprofloxacin 500 mg',      'Ciprofloxacin',    'Antibiotik',        'Tablet',   '1 Tablet', 2, 5,  'Diminum dengan banyak air, hindari produk susu.'),
  ('Metronidazole 500 mg',      'Metronidazole',    'Antibiotik',        'Tablet',   '1 Tablet', 3, 5,  'Diminum sesudah makan, hindari alkohol selama terapi.'),
  ('Cotrimoxazole 480 mg',      'Sulfamethoxazole', 'Antibiotik',        'Tablet',   '1 Tablet', 2, 5,  'Diminum sesudah makan dengan air putih yang cukup.'),

  -- Analgesik / antipiretik
  ('Paracetamol 500 mg',        'Paracetamol',      'Analgesik',         'Tablet',   '1 Tablet', 3, 3,  'Diminum bila nyeri/demam, maksimal 4 tablet per hari.'),
  ('Ibuprofen 400 mg',          'Ibuprofen',        'Analgesik',         'Tablet',   '1 Tablet', 3, 3,  'Diminum sesudah makan untuk mengurangi nyeri lambung.'),
  ('Tramadol 50 mg',            'Tramadol',         'Analgesik',         'Kapsul',   '1 Kapsul', 2, 3,  'Diminum sesudah makan, hindari mengemudi.'),
  ('Mefenamic Acid 500 mg',     'Mefenamic Acid',   'Analgesik',         'Tablet',   '1 Tablet', 3, 3,  'Diminum sesudah makan bila nyeri.'),

  -- Gastrointestinal
  ('Omeprazole 20 mg',          'Omeprazole',       'Gastrointestinal',  'Kapsul',   '1 Kapsul', 1, 7,  'Diminum sebelum makan pagi.'),
  ('Lansoprazole 30 mg',        'Lansoprazole',     'Gastrointestinal',  'Kapsul',   '1 Kapsul', 1, 7,  'Diminum 30 menit sebelum makan pagi.'),
  ('Domperidone 10 mg',         'Domperidone',      'Gastrointestinal',  'Tablet',   '1 Tablet', 3, 5,  'Diminum 15–30 menit sebelum makan.'),
  ('Sucralfate 500 mg/5 ml',    'Sucralfate',       'Gastrointestinal',  'Suspensi', '10 ml',    3, 7,  'Diminum saat perut kosong, 1 jam sebelum makan.'),
  ('Ranitidine 150 mg',         'Ranitidine',       'Gastrointestinal',  'Tablet',   '1 Tablet', 2, 7,  'Diminum pagi dan malam sebelum makan.'),

  -- Kardiovaskular / hipertensi
  ('Amlodipine 5 mg',           'Amlodipine',       'Kardiovaskular',    'Tablet',   '1 Tablet', 1, 30, 'Diminum pada waktu yang sama setiap hari.'),
  ('Candesartan 8 mg',          'Candesartan',      'Kardiovaskular',    'Tablet',   '1 Tablet', 1, 30, 'Diminum setiap pagi, kontrol tekanan darah rutin.'),
  ('Captopril 25 mg',           'Captopril',        'Kardiovaskular',    'Tablet',   '1 Tablet', 2, 30, 'Diminum 1 jam sebelum makan.'),
  ('Bisoprolol 5 mg',           'Bisoprolol',       'Kardiovaskular',    'Tablet',   '1 Tablet', 1, 30, 'Diminum setiap pagi, jangan berhenti mendadak.'),
  ('Furosemide 40 mg',          'Furosemide',       'Kardiovaskular',    'Tablet',   '1 Tablet', 1, 30, 'Diminum pagi hari untuk mengurangi terbangun malam.'),

  -- Antidiabetes
  ('Metformin 500 mg',          'Metformin',        'Antidiabetes',      'Tablet',   '1 Tablet', 2, 30, 'Diminum sesudah makan pagi dan malam.'),
  ('Glimepiride 2 mg',          'Glimepiride',      'Antidiabetes',      'Tablet',   '1 Tablet', 1, 30, 'Diminum sebelum makan pagi, waspadai hipoglikemia.'),

  -- Kolesterol
  ('Atorvastatin 20 mg',        'Atorvastatin',     'Kolesterol',        'Tablet',   '1 Tablet', 1, 30, 'Diminum malam hari sebelum tidur.'),
  ('Simvastatin 20 mg',         'Simvastatin',      'Kolesterol',        'Tablet',   '1 Tablet', 1, 30, 'Diminum malam hari, hindari konsumsi jeruk bali.'),

  -- Pengencer darah
  ('Aspirin 80 mg',             'Aspirin',          'Pengencer Darah',   'Tablet',   '1 Tablet', 1, 30, 'Diminum sesudah makan untuk mengurangi iritasi lambung.'),
  ('Clopidogrel 75 mg',         'Clopidogrel',      'Pengencer Darah',   'Tablet',   '1 Tablet', 1, 30, 'Diminum setiap hari pada waktu yang sama.'),

  -- Kortikosteroid
  ('Dexamethasone 0.5 mg',      'Dexamethasone',    'Kortikosteroid',    'Tablet',   '1 Tablet', 2, 3,  'Diminum sesudah makan pagi dan siang.'),

  -- Vitamin / suplemen
  ('Vitamin B Complex',         'Vitamin B Complex','Vitamin',           'Tablet',   '1 Tablet', 1, 30, 'Diminum sesudah makan.'),
  ('Vitamin C 500 mg',          'Ascorbic Acid',    'Vitamin',           'Tablet',   '1 Tablet', 1, 30, 'Diminum sesudah makan.'),
  ('Vitamin D3 1000 IU',        'Cholecalciferol',  'Vitamin',           'Tablet',   '1 Tablet', 1, 30, 'Diminum sesudah makan pagi.'),
  ('Kalsium Karbonat 500 mg',   'Calcium Carbonate','Vitamin',           'Tablet',   '1 Tablet', 2, 30, 'Diminum sesudah makan bersama air putih.')
on conflict (medicine_name) do nothing;

-- =============================================================================
-- 5. Kompatibilitas role `anon` (demo tanpa custom claim Firebase)
--
-- Bila dashboard membaca 0 baris karena JWT Firebase tidak memiliki klaim
-- `role: authenticated`, jalankan patch terpisah:
--
--   supabase/08_medicines_catalog_anon_compat.sql
--
-- Patch tersebut menambahkan role `anon` ke policy yang sudah dibuat di sini
-- (SELECT tetap terbuka untuk referensi obat; INSERT/UPDATE tetap dibatasi
-- `app.is_hospital_admin()`). Rollback tersedia di
-- `08_rollback_medicines_catalog_anon_compat.sql`.
-- =============================================================================
