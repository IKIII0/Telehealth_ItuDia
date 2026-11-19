-- =============================================================================
-- Telehealth — Pemeriksaan kesiapan integrasi Web Dashboard Admin Rumah Sakit
--
-- Jalankan SETELAH:
--   1. 01_medication_doctor_chat.sql
--   2. 02_profiles_auth_sync.sql
--   3. 03_hospital_admin_rbac.sql
--
-- File ini HANYA BERISI QUERY BACA (read-only). Tidak membuat/mengubah tabel
-- maupun policy. Gunakan hasilnya untuk memastikan dashboard admin benar-benar
-- terhubung ke Supabase dan RLS membatasi data per rumah sakit.
--
-- CATATAN SUPABASE SQL EDITOR
-- Supabase hanya menampilkan result set dari statement TERAKHIR. Karena itu:
--   • Untuk melihat detail per bagian, jalankan SELECT satu per satu, atau
--   • Jalankan seluruh file; bagian 9 di paling bawah merangkum semua
--     pemeriksaan dalam satu tabel.
--
--
-- Prasyarat di luar SQL:
--   • Supabase Dashboard → Authentication → Third-Party Auth → Firebase
--     (isi Firebase Project ID) agar auth.jwt() ->> 'sub' = Firebase UID.
--   • Akun Firebase admin sudah terdaftar di public.user_roles dengan
--     role = 'hospital_admin' dan hospital_id yang valid.
-- =============================================================================

-- ─── 1. Tabel inti ada dan RLS aktif ─────────────────────────────────────────
select
  expected.table_name,
  (to_regclass('public.' || expected.table_name) is not null) as table_exists,
  coalesce(cls.relrowsecurity, false)                         as rls_enabled,
  coalesce(cls.relforcerowsecurity, false)                    as force_rls
from (values
  ('hospitals'),
  ('user_roles'),
  ('hospital_patients'),
  ('prescriptions'),
  ('prescription_items'),
  ('medication_adherence'),
  ('patient_reports'),
  ('admin_follow_ups')
) as expected(table_name)
left join pg_class cls
  on cls.oid = to_regclass('public.' || expected.table_name)
order by expected.table_name;

-- ─── 2. Policy RLS admin terpasang ──────────────────────────────────────────
select
  tablename,
  policyname,
  cmd,
  roles,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
  and tablename in (
    'hospitals',
    'user_roles',
    'hospital_patients',
    'prescriptions',
    'prescription_items',
    'medication_adherence',
    'patient_reports',
    'admin_follow_ups'
  )
order by tablename, policyname;

-- ─── 3. RPC yang dipanggil dashboard ────────────────────────────────────────
select
  expected.routine,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = expected.routine
  ) as function_exists,
  exists (
    select 1
    from information_schema.routine_privileges rp
    where rp.routine_schema = 'public'
      and rp.routine_name = expected.routine
      and rp.grantee = 'authenticated'
      and rp.privilege_type = 'EXECUTE'
  ) as executable_by_authenticated
from (values
  ('hospital_admin_summary'),
  ('hospital_verify_prescription'),
  ('hospital_request_clarification'),
  ('hospital_record_follow_up')
) as expected(routine);

-- ─── 4. View baca dashboard ─────────────────────────────────────────────────
select
  expected.view_name,
  (to_regclass('public.' || expected.view_name) is not null) as view_exists
from (values
  ('hospital_patient_monitoring'),
  ('hospital_alerts')
) as expected(view_name);

-- ─── 5. Admin sudah terhubung ke rumah sakit ─────────────────────────────────
-- Ganti placeholder dengan Firebase UID admin bila ingin memeriksa akun
-- tertentu. Query ini hanya menampilkan; TIDAK menulis data.
select
  ur.user_id,
  ur.role,
  ur.is_active,
  ur.hospital_id,
  h.name as hospital_name,
  h.code as hospital_code
from public.user_roles ur
left join public.hospitals h on h.id = ur.hospital_id
where ur.role = 'hospital_admin'
order by h.name nulls last, ur.user_id;

-- ─── 6. Kelengkapan data awal ───────────────────────────────────────────────
select
  (select count(*) from public.hospital_patients where is_active) as active_patients,
  (select count(*) from public.prescriptions
    where status = 'pending_verification')                       as pending_prescriptions,
  (select count(*) from public.prescriptions where status = 'verified')
                                                                 as verified_prescriptions,
  (select count(*) from public.prescription_items)               as prescription_items,
  (select count(*) from public.medication_adherence)              as adherence_rows,
  (select count(*) from public.patient_reports where status <> 'resolved')
                                                                 as open_reports,
  (select count(*) from public.admin_follow_ups)                  as follow_up_rows;

-- ─── 7. Realtime publication ────────────────────────────────────────────────
select
  expected.table_name,
  exists (
    select 1
    from pg_publication_tables pt
    where pt.pubname = 'supabase_realtime'
      and pt.schemaname = 'public'
      and pt.tablename = expected.table_name
  ) as in_realtime_publication
from (values
  ('medication_adherence'),
  ('patient_reports'),
  ('prescriptions'),
  ('hospital_patients')
) as expected(table_name)
order by expected.table_name;

-- ─── 8. Smoke test RLS dari sisi client (opsional, jalankan manual) ─────────
-- SQL Editor Supabase berjalan sebagai `postgres` sehingga auth.jwt() kosong.
-- Untuk meniru request Flutter dengan Firebase UID tertentu, jalankan blok
-- berikut di sesi terpisah dan ganti nilai UID:
--
--   begin;
--     set local role authenticated;
--     set local request.jwt.claims =
--       '{"sub":"FIREBASE_UID_ADMIN","role":"authenticated"}';
--     select app.current_uid();           -- harus = FIREBASE_UID_ADMIN
--     select app.current_hospital_id();   -- harus = hospital_id admin
--     select * from public.hospital_admin_summary();
--     select * from public.hospital_alerts;
--   rollback;
--
-- Bila current_hospital_id() NULL, periksa kembali baris user_roles admin.
-- Bila query mengembalikan 0 baris padahal data seed ada, RLS bekerja sesuai
-- desain (data milik rumah sakit lain tidak boleh terlihat).

-- =============================================================================
-- 9. RINGKASAN SATU OUTPUT (statement terakhir)
--
-- Supabase SQL Editor hanya menampilkan hasil statement terakhir. Query ini
-- menggabungkan seluruh pemeriksaan menjadi satu tabel agar bisa dibaca
-- sekaligus. Bila ingin detail policy/RPC, jalankan bagian 1-8 satu per satu.
-- =============================================================================
with checks as (
  -- tabel + RLS
  select
    'Skema'::text as grp,
    'Tabel ' || e.table_name as item,
    case
      when to_regclass('public.' || e.table_name) is null then 'MISSING'
      when coalesce(cls.relrowsecurity, false) then 'OK'
      else 'RLS OFF'
    end::text as status,
    case
      when to_regclass('public.' || e.table_name) is null then 'tabel tidak ditemukan'
      when coalesce(cls.relrowsecurity, false) then 'RLS aktif'
      else 'RLS belum diaktifkan'
    end::text as detail
  from (values
    ('hospitals'),
    ('user_roles'),
    ('hospital_patients'),
    ('prescriptions'),
    ('prescription_items'),
    ('medication_adherence'),
    ('patient_reports'),
    ('admin_follow_ups')
  ) as e(table_name)
  left join pg_class cls
    on cls.oid = to_regclass('public.' || e.table_name)

  union all

  -- policy
  select
    'RLS',
    p.tablename || ' / ' || p.policyname,
    'OK',
    'roles=' || array_to_string(p.roles, ',') || '; cmd=' || p.cmd
  from pg_policies p
  where p.schemaname = 'public'
    and p.tablename in (
      'hospitals',
      'user_roles',
      'hospital_patients',
      'prescriptions',
      'prescription_items',
      'medication_adherence',
      'patient_reports',
      'admin_follow_ups'
    )

  union all

  -- RPC
  select
    'RPC',
    e.routine,
    case
      when exists (
        select 1 from pg_proc pr
        join pg_namespace n on n.oid = pr.pronamespace
        where n.nspname = 'public' and pr.proname = e.routine
      ) then 'OK'
      else 'MISSING'
    end,
    case
      when exists (
        select 1 from information_schema.routine_privileges rp
        where rp.routine_schema = 'public'
          and rp.routine_name = e.routine
          and rp.grantee = 'authenticated'
          and rp.privilege_type = 'EXECUTE'
      ) then 'EXECUTE untuk authenticated tersedia'
      else 'grant execute belum ada'
    end
  from (values
    ('hospital_admin_summary'),
    ('hospital_verify_prescription'),
    ('hospital_request_clarification'),
    ('hospital_record_follow_up')
  ) as e(routine)

  union all

  -- view
  select
    'View',
    e.view_name,
    case
      when to_regclass('public.' || e.view_name) is not null then 'OK'
      else 'MISSING'
    end,
    'view baca dashboard'
  from (values
    ('hospital_patient_monitoring'),
    ('hospital_alerts')
  ) as e(view_name)

  union all

  -- mapping admin
  select
    'Akses',
    'Mapping hospital_admin',
    case
      when count(*) filter (where role = 'hospital_admin' and is_active) = 0
        then 'MISSING'
      when count(*) filter (where user_id like 'GANTI%') > 0
        then 'PLACEHOLDER'
      else 'OK'
    end,
    count(*) filter (where role = 'hospital_admin' and is_active)::text
      || ' admin aktif; '
      || count(*) filter (where user_id like 'GANTI%')::text
      || ' placeholder'
  from public.user_roles

  union all

  -- data awal
  select 'Data', 'Pasien aktif', 'INFO',
    (select count(*) from public.hospital_patients where is_active)::text || ' baris'
  union all
  select 'Data', 'Resep pending_verification', 'INFO',
    (select count(*) from public.prescriptions
      where status = 'pending_verification')::text || ' baris'
  union all
  select 'Data', 'Resep verified', 'INFO',
    (select count(*) from public.prescriptions
      where status = 'verified')::text || ' baris'
  union all
  select 'Data', 'Item resep', 'INFO',
    (select count(*) from public.prescription_items)::text || ' baris'
  union all
  select 'Data', 'Baris adherence', 'INFO',
    (select count(*) from public.medication_adherence)::text || ' baris'
  union all
  select 'Data', 'Laporan pasien terbuka', 'INFO',
    (select count(*) from public.patient_reports
      where status <> 'resolved')::text || ' baris'
  union all
  select 'Data', 'Tindak lanjut admin', 'INFO',
    (select count(*) from public.admin_follow_ups)::text || ' baris'

  union all

  -- realtime
  select
    'Realtime',
    e.table_name,
    case
      when exists (
        select 1 from pg_publication_tables pt
        where pt.pubname = 'supabase_realtime'
          and pt.schemaname = 'public'
          and pt.tablename = e.table_name
      ) then 'OK'
      else 'OFF'
    end,
    'publication supabase_realtime'
  from (values
    ('medication_adherence'),
    ('patient_reports'),
    ('prescriptions'),
    ('hospital_patients')
  ) as e(table_name)
)
select grp, item, status, detail
from checks
order by
  case grp
    when 'Skema' then 1
    when 'RLS' then 2
    when 'RPC' then 3
    when 'View' then 4
    when 'Akses' then 5
    when 'Data' then 6
    when 'Realtime' then 7
    else 8
  end,
  item;
