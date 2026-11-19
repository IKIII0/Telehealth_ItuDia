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

-- ─── Seed contoh ─────────────────────────────────────────────────────────────
insert into public.consultation_summaries
  (conversation_id, patient_name, doctor_id, doctor_name, specialization,
   diagnosis, notes, prescriptions, advice, created_at)
select v.conversation_id, v.patient_name, v.doctor_id, v.doctor_name,
       v.specialization, v.diagnosis, v.notes, v.prescriptions, v.advice,
       v.created_at
from (values
  ('conv1', 'ItuDia', 'doc1', 'dr. Rifki Al Sauqy, Sp.JP', 'Spesialis Jantung',
   'Hipertensi stadium 1',
   'Tensi 140/90. Keluhan pusing ringan saat aktivitas berat. Tidak ada riwayat serangan jantung.',
   array['Amlodipine 10 mg — 1x sehari malam', 'Paracetamol 500 mg — bila pusing'],
   'Kurangi garam, kontrol tensi tiap pagi, kontrol ulang 1 minggu.',
   timestamptz '2026-11-17 10:30:00+07'),
  ('conv2', 'ItuDia', 'doc2', 'dr. Yehezkiel Sitanggang, Sp.A', 'Spesialis Anak',
   'Demam viral, hasil laboratorium normal',
   'Suhu 38,2°C selama 2 hari, hasil darah lengkap dalam batas normal.',
   array['Paracetamol sirup — 3x sehari'],
   'Cukup cairan dan istirahat, kembali bila demam lebih dari 3 hari.',
   timestamptz '2026-11-14 09:15:00+07')
) as v(conversation_id, patient_name, doctor_id, doctor_name, specialization,
       diagnosis, notes, prescriptions, advice, created_at)
where not exists (
  select 1 from public.consultation_summaries s
  where s.conversation_id = v.conversation_id
    and s.created_at = v.created_at
);
