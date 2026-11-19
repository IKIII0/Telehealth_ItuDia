-- =============================================================================
-- Telehealth — Solusi B (SEMENTARA): kompatibilitas Firebase Third-Party Auth
--
-- MASALAH
-- Firebase ID token tidak memiliki klaim `role`, sehingga Supabase menjalankan
-- request sebagai Postgres role `anon`. Policy admin di 03_hospital_admin_rbac
-- hanya dipasang untuk role `authenticated`, sehingga query dari aplikasi
-- mengembalikan 0 baris walau baris user_roles ada.
--
-- PATCH INI
--   1. Memberi role `anon` akses ke schema app + helper function.
--   2. Menambahkan `anon` ke seluruh policy dashboard admin.
--   3. Memberi grant tabel, view, dan RPC kepada `anon`.
--
-- KENAPA MASIH AMAN UNTUK DEMO
-- Semua policy tetap memakai:
--   hospital_id = app.current_hospital_id()
-- dan app.current_hospital_id() hanya terisi bila JWT memiliki `sub` yang
-- terdaftar di user_roles sebagai hospital_admin dan aktif.
-- Request tanpa Firebase JWT / user non-admin tetap mendapat NULL sehingga
-- tidak ada baris yang terlihat.
--
-- PERINGATAN
-- Ini BUKAN pola yang disarankan untuk produksi. Solusi resmi adalah custom
-- claim `role: authenticated` (lihat scripts/set_firebase_role_claim.js).
-- Rollback: jalankan supabase/06_rollback_firebase_anon_compat.sql.
--
-- Jalankan setelah 03_hospital_admin_rbac.sql.
-- =============================================================================

-- ─── 1. Helper function untuk role anon ─────────────────────────────────────
grant usage on schema app to anon;

grant execute on function app.current_uid() to anon;
grant execute on function app.has_role(text) to anon;
grant execute on function app.current_hospital_id() to anon;
grant execute on function app.is_hospital_admin() to anon;

-- ─── 2. Policy: tambahkan role anon ─────────────────────────────────────────
-- `alter policy` mempertahankan USING / WITH CHECK yang sudah didefinisikan
-- di 03_hospital_admin_rbac.sql.
alter policy hospitals_read_scoped on public.hospitals
  to anon, authenticated;

alter policy user_roles_read_scoped on public.user_roles
  to anon, authenticated;

alter policy hospital_patients_scoped on public.hospital_patients
  to anon, authenticated;

alter policy prescriptions_scoped on public.prescriptions
  to anon, authenticated;

alter policy prescription_items_scoped on public.prescription_items
  to anon, authenticated;

alter policy medication_adherence_scoped on public.medication_adherence
  to anon, authenticated;

alter policy patient_reports_scoped on public.patient_reports
  to anon, authenticated;

alter policy admin_follow_ups_scoped on public.admin_follow_ups
  to anon, authenticated;

-- ─── 3. Grant tabel ─────────────────────────────────────────────────────────
grant select on public.hospitals to anon;
grant select on public.user_roles to anon;

grant select, insert, update, delete
  on public.hospital_patients,
     public.prescriptions,
     public.prescription_items,
     public.medication_adherence,
     public.patient_reports,
     public.admin_follow_ups
  to anon;

-- ─── 4. Grant view ──────────────────────────────────────────────────────────
grant select on public.hospital_patient_monitoring to anon;
grant select on public.hospital_alerts to anon;

-- ─── 5. Grant RPC dashboard ─────────────────────────────────────────────────
grant execute on function public.hospital_admin_summary() to anon;
grant execute on function public.hospital_verify_prescription(uuid, jsonb, text) to anon;
grant execute on function public.hospital_request_clarification(uuid, text) to anon;
grant execute on function public.hospital_record_follow_up(uuid, text, text, uuid, uuid) to anon;

-- ─── 6. Verifikasi cepat ────────────────────────────────────────────────────
-- Jalankan dari aplikasi setelah restart. Log `auth context` boleh tetap
-- menunjukkan jwt_role: anon — yang penting query user_roles sekarang
-- mengembalikan baris karena policy juga berlaku untuk anon.
--
-- Dari SQL Editor (berjalan sebagai postgres, jadi hanya memeriksa konfigurasi):
select
  tablename,
  policyname,
  roles
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
