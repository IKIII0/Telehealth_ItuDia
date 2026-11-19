-- =============================================================================
-- Telehealth — Catatan medis / resume konsultasi
--
-- Disimpan per sesi konsultasi agar dokter berikutnya bisa melihat riwayat
-- penanganan pasien: diagnosis, tindakan, dan obat yang sudah diberikan.
--
-- Jalankan setelah `01_medication_doctor_chat.sql`.
-- =============================================================================

create table if not exists public.consultation_summaries (
  id              uuid primary key default gen_random_uuid(),
  -- Relasi ke percakapan/konsultasi asal (boleh kosong bila data lama).
  conversation_id text references public.conversations(id) on delete set null,
  -- Pasien: untuk demo memakai nama; di produksi ganti dengan uuid auth.
  patient_name    text        not null,
  doctor_id       text        references public.doctors(id) on delete set null,
  doctor_name     text        not null,
  specialization  text        not null default '',
  diagnosis       text        not null,
  notes           text        not null default '',
  prescriptions   text[]      not null default '{}',
  advice          text        not null default '',
  created_at      timestamptz not null default now()
);

create index if not exists consultation_summaries_patient_idx
  on public.consultation_summaries (patient_name, created_at desc);

create index if not exists consultation_summaries_conversation_idx
  on public.consultation_summaries (conversation_id);

alter table public.consultation_summaries enable row level security;

drop policy if exists demo_all_consultation_summaries
  on public.consultation_summaries;
create policy demo_all_consultation_summaries
  on public.consultation_summaries
  for all to anon, authenticated using (true) with check (true);

-- Tidak ada seed: resume diisi dokter sungguhan setelah sesi konsultasi.
-- Seed dokter/conversation contoh sudah dihapus (lihat 06_remove_dummy_doctors.sql)
-- agar tidak ada data dokter dummy di database.
