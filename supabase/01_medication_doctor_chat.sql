-- =============================================================================
-- Telehealth — schema Supabase untuk modul:
--   1. Dokter (doctor list & detail)
--   2. Pengingat obat (soft delete + riwayat)
--   3. Chat (daftar percakapan + pesan)
--
-- Jalankan seluruh file ini di Supabase SQL Editor.
-- Modul lain (jurnal kesehatan, symptom checker, profil) sengaja tidak
-- disentuh karena masih memakai data simulasi.
--
-- CATATAN KEAMANAN
-- Autentikasi aplikasi saat ini masih simulasi (lihat AuthRepository), jadi
-- belum ada `auth.uid()`. Policy di bawah membuka akses untuk role anon
-- HANYA untuk keperluan demo/tugas. Sebelum dipakai produksi, ganti policy
-- dengan aturan berbasis `owner_id` dan `auth.uid()`.
-- =============================================================================

-- ─── Extensions ──────────────────────────────────────────────────────────────
create extension if not exists pgcrypto;

-- ─── Dokter ──────────────────────────────────────────────────────────────────
create table if not exists public.doctors (
  id            text primary key,
  name          text        not null,
  specialization text       not null,
  experience    int         not null default 0,
  rating        numeric(2,1) not null default 0,
  price         int         not null default 0,
  available     boolean     not null default true,
  hospital      text        not null default '',
  bio           text        not null default '',
  education     text        not null default '',
  avatar_color  bigint      not null default 0,
  created_at    timestamptz not null default now()
);

-- ─── Pengingat obat ──────────────────────────────────────────────────────────
create table if not exists public.medications (
  id         uuid primary key default gen_random_uuid(),
  name       text        not null,
  dose       text        not null,
  frequency  text        not null,
  start_date text        not null default '-',
  end_date   text        not null default '-',
  note       text        not null default '-',
  doctor_id  text        references public.doctors(id) on delete set null,
  color      bigint      not null default x'FF1E88E5'::bigint, -- biru default
  icon       text        not null default 'medication',
  -- Soft delete: baris tidak pernah dihapus fisik, hanya ditandai.
  is_deleted boolean     not null default false,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists medications_deleted_idx
  on public.medications (is_deleted, created_at desc);

create table if not exists public.medication_schedules (
  id            uuid primary key default gen_random_uuid(),
  medication_id uuid not null references public.medications(id) on delete cascade,
  position      int  not null default 0,
  period        text not null, -- Pagi / Siang / Malam
  hour          text not null, -- 08:00
  taken         boolean not null default false,
  created_at    timestamptz not null default now()
);

create index if not exists medication_schedules_medication_idx
  on public.medication_schedules (medication_id, position);

-- ─── Chat ────────────────────────────────────────────────────────────────────
create table if not exists public.conversations (
  id           text primary key,
  name         text        not null,
  role         text        not null, -- Dokter / Keluarga
  type         text        not null, -- dokter / keluarga
  last_message text        not null default '',
  time_label   text        not null default '',
  unread_count int         not null default 0,
  is_online    boolean     not null default false,
  initials     text        not null default '',
  color        bigint      not null default 0,
  created_at   timestamptz not null default now()
);

create table if not exists public.chat_messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id text not null references public.conversations(id) on delete cascade,
  body            text not null,
  is_me           boolean not null default false,
  time_label      text not null default '',
  created_at      timestamptz not null default now()
);

create index if not exists chat_messages_conversation_idx
  on public.chat_messages (conversation_id, created_at);

-- =============================================================================
-- Row Level Security (demo: akses penuh untuk anon & authenticated)
-- =============================================================================
alter table public.doctors              enable row level security;
alter table public.medications          enable row level security;
alter table public.medication_schedules enable row level security;
alter table public.conversations        enable row level security;
alter table public.chat_messages        enable row level security;

drop policy if exists demo_all_doctors on public.doctors;
create policy demo_all_doctors on public.doctors
  for all to anon, authenticated using (true) with check (true);

drop policy if exists demo_all_medications on public.medications;
create policy demo_all_medications on public.medications
  for all to anon, authenticated using (true) with check (true);

drop policy if exists demo_all_schedules on public.medication_schedules;
create policy demo_all_schedules on public.medication_schedules
  for all to anon, authenticated using (true) with check (true);

drop policy if exists demo_all_conversations on public.conversations;
create policy demo_all_conversations on public.conversations
  for all to anon, authenticated using (true) with check (true);

drop policy if exists demo_all_chat_messages on public.chat_messages;
create policy demo_all_chat_messages on public.chat_messages
  for all to anon, authenticated using (true) with check (true);

-- =============================================================================
-- Seed data (idempoten: aman dijalankan berulang)
-- =============================================================================

-- Dokter ---------------------------------------------------------------------
insert into public.doctors
  (id, name, specialization, experience, rating, price, available, hospital, bio, education, avatar_color)
values
  ('doc1', 'dr. Rifki Al Sauqy, Sp.JP', 'Spesialis Jantung', 12, 4.9, 150000, true,
   'RS Jantung Harapan Kita',
   'Spesialis jantung berpengalaman dalam penanganan penyakit jantung koroner, aritmia, dan gagal jantung.',
   'FK Universitas Indonesia • PPDS Kardiologi UI', x'FFE53935'::bigint),
  ('doc2', 'dr. Yehezkiel Sitanggang, Sp.A', 'Spesialis Anak', 8, 4.8, 120000, true,
   'RSUP Dr. Cipto Mangunkusumo',
   'Dokter spesialis anak yang berdedikasi, menangani berbagai penyakit anak dari neonatus hingga remaja.',
   'FK Universitas Gadjah Mada • PPDS Ilmu Kesehatan Anak UGM', x'FF1E88E5'::bigint),
  ('doc3', 'dr. Farhan Prasetyo', 'Dokter Umum', 5, 4.6, 75000, false,
   'Klinik Sehat Bersama',
   'Dokter umum berpengalaman menangani keluhan kesehatan sehari-hari dengan pendekatan holistik.',
   'FK Universitas Airlangga', x'FF43A047'::bigint),
  ('doc4', 'dr. Pocut Qanitah, Sp.KK', 'Spesialis Kulit', 10, 4.7, 130000, true,
   'RS Dermatologi Indonesia',
   'Spesialis kulit dan kelamin dengan keahlian dermatologi estetika dan penyakit kulit kronis.',
   'FK Universitas Padjadjaran • PPDS Dermatologi UNPAD', x'FF8E24AA'::bigint),
  ('doc5', 'dr. Daffa Afdhillah, Sp.PD', 'Spesialis Penyakit Dalam', 9, 4.8, 140000, true,
   'RS Pusat Pertamina',
   'Spesialis penyakit dalam dengan fokus diabetes, hipertensi, dan gangguan metabolisme.',
   'FK Universitas Indonesia • PPDS Penyakit Dalam UI', x'FF00897B'::bigint),
  ('doc6', 'dr. Arkaan Ramdhan', 'Dokter Umum', 6, 4.7, 80000, true,
   'Klinik Telehealth',
   'Dokter umum yang ramah dengan layanan konsultasi daring untuk keluhan ringan.',
   'FK Universitas Diponegoro', x'FFF4511E'::bigint),
  ('doc7', 'dr. Cristian, Sp.KJ', 'Psikiatri', 8, 4.8, 160000, true,
   'RS Jiwa Dr. Soeharto Heerdjan',
   'Psikiater dengan pendekatan suportif untuk kecemasan, depresi, dan gangguan tidur.',
   'FK Universitas Padjadjaran • PPDS Psikiatri UNPAD', x'FF5E35B1'::bigint),
  ('doc8', 'dr. William Bevan, Sp.DVE', 'Dermatologi', 6, 4.7, 135000, false,
   'Klinik Estetika Nusantara',
   'Dermatolog yang menangani masalah kulit, rambut, dan kuku termasuk perawatan estetika.',
   'FK Universitas Brawijaya • PPDS Dermatologi UB', x'FFD81B60'::bigint)
on conflict (id) do nothing;

-- Pengingat obat -------------------------------------------------------------
insert into public.medications
  (id, name, dose, frequency, start_date, end_date, note, doctor_id, color, icon, is_deleted)
values
  ('11111111-1111-1111-1111-111111111111', 'Paracetamol', '500 mg', '3x sehari',
   '20 Sep 2024', '27 Sep 2024', 'Sesudah makan', 'doc5', x'FF1E88E5'::bigint, 'medication', false),
  ('22222222-2222-2222-2222-222222222222', 'Amoxicillin', '500 mg', '3x sehari',
   '22 Sep 2024', '29 Sep 2024', 'Sebelum makan', 'doc3', x'FFE53935'::bigint, 'medication_liquid', false),
  ('33333333-3333-3333-3333-333333333333', 'Vitamin C', '1000 mg', '1x sehari',
   '01 Sep 2024', '30 Sep 2024', 'Sesudah makan', 'doc1', x'FFFF8F00'::bigint, 'pharmacy', false),
  ('44444444-4444-4444-4444-444444444444', 'Amlodipine', '10 mg', '1x sehari',
   '15 Sep 2024', '15 Okt 2024', 'Sebelum tidur', 'doc1', x'FF43A047'::bigint, 'favorite', false),
  ('55555555-5555-5555-5555-555555555555', 'Metformin', '500 mg', '2x sehari',
   '10 Sep 2024', '10 Okt 2024', 'Sesudah makan', 'doc5', x'FF5E35B1'::bigint, 'water_drop', false),
  ('66666666-6666-6666-6666-666666666666', 'Cetirizine', '10 mg', '1x sehari',
   '18 Sep 2024', '25 Sep 2024', 'Malam hari', 'doc4', x'FF8E24AA'::bigint, 'air', false)
on conflict (id) do nothing;

-- Jadwal obat (hanya ditanam bila obat belum punya jadwal)
insert into public.medication_schedules (medication_id, position, period, hour, taken)
select v.medication_id, v.position, v.period, v.hour, v.taken
from (values
  ('11111111-1111-1111-1111-111111111111'::uuid, 0, 'Pagi',  '08:00', true),
  ('11111111-1111-1111-1111-111111111111'::uuid, 1, 'Siang', '14:00', true),
  ('11111111-1111-1111-1111-111111111111'::uuid, 2, 'Malam', '20:00', false),
  ('22222222-2222-2222-2222-222222222222'::uuid, 0, 'Pagi',  '08:00', true),
  ('22222222-2222-2222-2222-222222222222'::uuid, 1, 'Siang', '14:00', false),
  ('22222222-2222-2222-2222-222222222222'::uuid, 2, 'Malam', '20:00', false),
  ('33333333-3333-3333-3333-333333333333'::uuid, 0, 'Pagi',  '08:00', true),
  ('44444444-4444-4444-4444-444444444444'::uuid, 0, 'Malam', '21:00', false),
  ('55555555-5555-5555-5555-555555555555'::uuid, 0, 'Pagi',  '08:00', true),
  ('55555555-5555-5555-5555-555555555555'::uuid, 1, 'Malam', '20:00', false),
  ('66666666-6666-6666-6666-666666666666'::uuid, 0, 'Malam', '21:00', true)
) as v(medication_id, position, period, hour, taken)
where not exists (
  select 1 from public.medication_schedules s
  where s.medication_id = v.medication_id
);

-- Percakapan -----------------------------------------------------------------
insert into public.conversations
  (id, name, role, type, last_message, time_label, unread_count, is_online, initials, color)
values
  ('conv1', 'dr. Rifki Al Sauqy, Sp.JP', 'Dokter', 'dokter',
   'Baik, jangan lupa minum obat secara teratur ya dan kontrol lagi minggu depan.',
   '10:30', 2, true, 'RAS', x'FFE53935'::bigint),
  ('conv2', 'dr. Yehezkiel Sitanggang, Sp.A', 'Dokter', 'dokter',
   'Hasil lab sudah saya terima, hasilnya normal semua. Tidak perlu khawatir.',
   '09:15', 0, true, 'YS', x'FF1E88E5'::bigint),
  ('conv3', 'Budi (Ayah)', 'Keluarga', 'keluarga',
   'Sudah ke dokter tadi pagi, katanya harus istirahat total selama 3 hari.',
   'Kemarin', 1, false, 'B', x'FF43A047'::bigint),
  ('conv4', 'dr. Pocut Qanitah, Sp.KK', 'Dokter', 'dokter',
   'Silakan kirimkan foto kulit yang bermasalah agar saya bisa mengevaluasi.',
   'Kemarin', 0, false, 'PQ', x'FF8E24AA'::bigint),
  ('conv5', 'Rina (Ibu)', 'Keluarga', 'keluarga',
   'Jangan lupa jadwal kontrol minggu depan ya, sudah saya daftarkan.',
   'Selasa', 3, true, 'R', x'FFFF8F00'::bigint),
  ('conv6', 'dr. Daffa Afdhillah, Sp.PD', 'Dokter', 'dokter',
   'Cek gula darah puasa besok pagi ya, lalu kirimkan hasilnya ke saya.',
   'Senin', 0, false, 'DA', x'FF00897B'::bigint)
on conflict (id) do nothing;

-- Pesan chat (hanya ditanam bila percakapan belum punya pesan)
insert into public.chat_messages (conversation_id, body, is_me, time_label)
select v.conversation_id, v.body, v.is_me, v.time_label
from (values
  ('conv1', 'Selamat pagi, ada yang bisa saya bantu?', false, '10:12'),
  ('conv1', 'Pagi Dok. Kemarin tensi saya 140/90, apakah berbahaya?', true, '10:15'),
  ('conv1', 'Masih bisa dikendalikan. Istirahat cukup dan kurangi garam ya.', false, '10:20'),
  ('conv1', 'Baik, jangan lupa minum obat secara teratur ya dan kontrol lagi minggu depan.', false, '10:30'),
  ('conv2', 'Selamat pagi, hasil laboratorium Anda sudah saya terima.', false, '09:02'),
  ('conv2', 'Bagaimana hasilnya Dok?', true, '09:10'),
  ('conv2', 'Hasil lab sudah saya terima, hasilnya normal semua. Tidak perlu khawatir.', false, '09:15'),
  ('conv3', 'Sudah ke dokter tadi pagi, katanya harus istirahat total 3 hari.', false, '08:40'),
  ('conv3', 'Baik Yah, nanti sore aku jenguk ya.', true, '08:45'),
  ('conv3', 'Sudah ke dokter tadi pagi, katanya harus istirahat total selama 3 hari.', false, 'Kemarin'),
  ('conv4', 'Silakan kirimkan foto kulit yang bermasalah agar saya bisa mengevaluasi.', false, 'Kemarin'),
  ('conv5', 'Nak, jangan lupa makan siang ya.', false, '12:05'),
  ('conv5', 'Iya Bu, sudah kok.', true, '12:20'),
  ('conv5', 'Jangan lupa jadwal kontrol minggu depan ya, sudah saya daftarkan.', false, 'Selasa'),
  ('conv6', 'Cek gula darah puasa besok pagi ya, lalu kirimkan hasilnya ke saya.', false, 'Senin')
) as v(conversation_id, body, is_me, time_label)
where not exists (
  select 1 from public.chat_messages m
  where m.conversation_id = v.conversation_id
);
