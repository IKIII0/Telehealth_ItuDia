-- =============================================================================
-- Telehealth — DIAGNOSTIK SEMENTARA: konteks auth yang dilihat Supabase
--
-- Gunakan hanya saat dashboard admin menampilkan:
--   "Akun ini belum terdaftar sebagai admin rumah sakit"
--
-- Jalankan file ini di SQL Editor, restart aplikasi, lalu buka dashboard admin.
-- Console akan menampilkan:
--
--   [HospitalAdminRepository] auth context: {...}
--
-- Setelah masalah selesai, HAPUS fungsi ini:
--   drop function if exists public.debug_auth_context();
-- =============================================================================

create or replace function public.debug_auth_context()
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    -- Klaim JWT yang diterima PostgREST dari aplikasi
    'jwt_sub',  auth.jwt() ->> 'sub',
    'jwt_role', auth.jwt() ->> 'role',
    'jwt_aud',  auth.jwt() ->> 'aud',
    'jwt_iss',  auth.jwt() ->> 'iss',

    -- Hasil helper yang dipakai RLS admin
    'current_uid',         app.current_uid(),
    'current_hospital_id', app.current_hospital_id(),
    'is_hospital_admin',   app.is_hospital_admin(),

    -- Apakah baris user_roles benar-benar ada untuk sub pemanggil.
    -- Fungsi ini SECURITY DEFINER sehingga pemeriksaan tidak terkena RLS.
    'caller_admin_row_exists', exists (
      select 1
      from public.user_roles ur
      where ur.user_id = auth.jwt() ->> 'sub'
        and ur.role = 'hospital_admin'
        and ur.is_active
    ),
    'admin_rows_total', (
      select count(*)
      from public.user_roles
      where role = 'hospital_admin' and is_active
    )
  );
$$;

comment on function public.debug_auth_context() is
  'DIAGNOSTIK SEMENTARA. Hapus dengan drop function setelah debugging RLS.';

grant execute on function public.debug_auth_context() to anon, authenticated;

-- =============================================================================
-- Cara membaca hasil `auth context`
-- =============================================================================
--
-- 1. jwt_sub = null
--    → Supabase tidak menerima klaim Firebase. Periksa Third-Party Auth
--      Firebase dan apakah Authorization Bearer benar-benar terkirim.
--
-- 2. jwt_sub ada, tetapi berbeda dari UID aplikasi
--    → Token berasal dari akun/project Firebase lain.
--
-- 3. jwt_sub = UID aplikasi, tetapi caller_admin_row_exists = false
--    → Baris user_roles tidak ada di project Supabase yang dipakai .env
--      (project berbeda), atau UID/role/is_active tidak cocok.
--
-- 4. jwt_sub = UID aplikasi, caller_admin_row_exists = true,
--    tetapi current_hospital_id = null
--    → Periksa fungsi app.current_uid()/app.current_hospital_id() dan
--      apakah fungsi dijalankan sebagai owner yang benar.
--
-- 5. jwt_aud ≠ Firebase Project ID
--    → Token Firebase berasal dari project lain.
-- =============================================================================
