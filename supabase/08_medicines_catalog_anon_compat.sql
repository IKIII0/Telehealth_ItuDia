-- =============================================================================
-- Telehealth — Kompatibilitas `anon` untuk `medicines_catalog`
--
-- MASALAH
-- Sama seperti 06_firebase_anon_compat.sql: Firebase ID token tidak memiliki
-- klaim `role`, sehingga Supabase menjalankan request sebagai Postgres role
-- `anon`. Policy `authenticated` pada 07_medicines_catalog.sql tidak berlaku,
-- akibatnya SELECT berhasil tetapi mengembalikan 0 baris dan dropdown
-- menampilkan "Belum ada obat di katalog".
--
-- PATCH INI
--   1. Menambahkan `anon` ke policy SELECT/INSERT/UPDATE medicines_catalog.
--   2. Memberi grant tabel kepada `anon`.
--
-- KEAMANAN
--   - SELECT katalog obat memang data referensi publik (tidak sensitif).
--   - INSERT/UPDATE tetap memakai `app.is_hospital_admin()`; request tanpa
--     Firebase JWT atau bukan admin akan ditolak.
--
-- Jalankan setelah 07_medicines_catalog.sql.
-- Rollback: 08_rollback_medicines_catalog_anon_compat.sql
-- =============================================================================

-- ─── 1. Policy: tambahkan role anon ─────────────────────────────────────────
-- `alter policy` mempertahankan USING / WITH CHECK dari file 07.
alter policy medicines_catalog_read on public.medicines_catalog
  to anon, authenticated;

alter policy medicines_catalog_admin_insert on public.medicines_catalog
  to anon, authenticated;

alter policy medicines_catalog_admin_update on public.medicines_catalog
  to anon, authenticated;

-- ─── 2. Grant tabel ─────────────────────────────────────────────────────────
grant select on public.medicines_catalog to anon;
grant insert, update on public.medicines_catalog to anon;

-- ─── 3. Verifikasi cepat ────────────────────────────────────────────────────
select
  tablename,
  policyname,
  cmd,
  roles
from pg_policies
where schemaname = 'public'
  and tablename = 'medicines_catalog'
order by policyname;

-- Cek jumlah baris yang terlihat (dari SQL Editor berjalan sebagai postgres,
-- jadi angka ini selalu terlihat; untuk menguji RLS, lihat hasil di aplikasi).
select count(*) as total_obat, count(*) filter (where is_active) as obat_aktif
from public.medicines_catalog;
