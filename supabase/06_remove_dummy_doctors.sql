-- =============================================================================
-- Telehealth — Hapus data dokter dummy
--
-- Setelah 05_doctor_directory_sync.sql dipasang, direktori dokter sudah diisi
-- dari akun dokter yang benar-benar mendaftar. Data dokter contoh (doc1..doc8)
-- tidak diperlukan lagi dan dihapus di sini.
--
-- Jalankan setelah 01, 02, dan 05.
-- =============================================================================

-- 1. Resume konsultasi yang merujuk dokter dummy (hanya bila tabelnya ada).
do $$
begin
  if to_regclass('public.consultation_summaries') is not null then
    delete from public.consultation_summaries
     where doctor_id like 'doc%'
        or conversation_id in ('conv1', 'conv2', 'conv4', 'conv6');
  end if;
end $$;

-- 2. Percakapan demo dengan dokter dummy (pesan ikut terhapus via cascade).
--    Percakapan keluarga (conv3, conv5) tetap dipertahankan.
do $$
begin
  if to_regclass('public.conversations') is not null then
    delete from public.conversations
     where id in ('conv1', 'conv2', 'conv4', 'conv6');
  end if;
end $$;

-- 3. Hapus baris direktori dokter dummy.
--    medications.doctor_id dan consultation_summaries.doctor_id otomatis
--    menjadi NULL sesuai FK ON DELETE SET NULL.
do $$
begin
  if to_regclass('public.doctors') is not null then
    delete from public.doctors where id like 'doc%';
  end if;
end $$;

-- 4. (Opsional) Bila ingin mulai dari nol tanpa obat contoh:
-- delete from public.medications
--  where start_date in ('20 Sep 2024', '22 Sep 2024', '01 Sep 2024',
--                       '15 Sep 2024', '10 Sep 2024', '18 Sep 2024');

-- Verifikasi: hanya dokter hasil pendaftaran (id berawalan acc_) yang tersisa.
select id, name, specialization, hospital from public.doctors order by name;
