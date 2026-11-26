-- =============================================================================
-- Telehealth — Modul database role DOKTER
--
-- Jalankan setelah:
--   1. 01_medication_doctor_chat.sql
--   2. 02_profiles_auth_sync.sql         (profiles, doctor_profiles, set_updated_at)
--   3. 03_hospital_admin_rbac.sql        (hospitals, user_roles, prescriptions, app.*)
--   4. 06_firebase_anon_compat.sql       (bila request Firebase berjalan sebagai anon)
--
-- File ini aman dijalankan berulang (idempoten).
--
-- ISI FILE
--   1.  Perluasan doctor_profiles (hospital_id, preferensi, kuota harian)
--       + trigger: hospital_id otomatis dari nama RS, sinkron ke user_roles
--   2.  Tabel baru:
--         consultation_sessions   permintaan + sesi konsultasi + catatan dokter
--         consultation_messages   chat dokter-pasien di dalam sesi
--         patient_vital_records   rekam vital pasien (dibaca dokter)
--       + prescriptions.consultation_session_id (resep terhubung ke sesi)
--   3.  Helper app.* : is_doctor, current_doctor_hospital_id, doctor_has_patient
--   4.  RPC dokter  : respon permintaan, mulai sesi, simpan catatan,
--                     serahkan resep ke admin, jawab klarifikasi, batalkan resep,
--                     ringkasan dashboard, riwayat obat & kunjungan pasien
--   5.  RLS + grant
--   6.  Realtime
--   7.  (opsional) pengetatan policy doctor_profiles
--   8.  Verifikasi cepat
--
-- PEMETAAN DARI KODE FLUTTER (lib/data)
--   ConsultationSession            -> consultation_sessions
--   ConsultationMessage            -> consultation_messages
--   PatientVitalRecord             -> patient_vital_records
--   PatientMedicationRecord        -> RPC doctor_patient_medications()
--   PastConsultationRecord         -> RPC doctor_patient_consultation_history()
--   DoctorProfile                  -> doctor_profiles (+ kolom baru)
--   _ConsultationRequest (dashboard)-> consultation_sessions status 'requested'
--   _DoctorAppointment (dashboard) -> consultation_sessions status 'scheduled'/'ongoing'
--   saveSessionNotes()             -> RPC doctor_save_consultation_notes()
--   resep dokter ke admin          -> RPC doctor_submit_prescription()
--
-- CATATAN KEAMANAN
--   * Semua identitas memakai Firebase UID (`app.current_uid()`), sama seperti
--     file 03. Tulis ke sesi/resep dilakukan lewat RPC SECURITY DEFINER agar
--     aturan status tidak bisa dilewati dari client. Dokter hanya punya SELECT
--     langsung pada tabel sesi dan resep.
--   * Policy dipasang untuk `anon` dan `authenticated` karena token Firebase
--     tanpa custom claim `role` dijalankan sebagai `anon` (lihat file 06).
--     Tanpa JWT Firebase yang valid, app.current_uid() = NULL sehingga tidak
--     ada baris yang terlihat.
--   * Jangan pernah menaruh service_role key di aplikasi Flutter.
-- =============================================================================

create extension if not exists pgcrypto;

-- Pastikan role anon dapat memanggil helper di schema app (idempoten).
grant usage on schema app to anon, authenticated;

-- =============================================================================
-- 1. Perluasan doctor_profiles
-- =============================================================================
alter table public.doctor_profiles
  add column if not exists hospital_id uuid
    references public.hospitals(id) on delete set null,
  add column if not exists accepting_consultations boolean not null default true,
  add column if not exists notify_new_request      boolean not null default true,
  add column if not exists notify_chat_message     boolean not null default true,
  add column if not exists auto_summarize          boolean not null default true,
  add column if not exists daily_quota             int     not null default 12;

alter table public.doctor_profiles
  drop constraint if exists doctor_profiles_daily_quota_check;
alter table public.doctor_profiles
  add constraint doctor_profiles_daily_quota_check
  check (daily_quota between 1 and 100);

create index if not exists doctor_profiles_hospital_idx
  on public.doctor_profiles (hospital_id)
  where hospital_id is not null;

comment on column public.doctor_profiles.hospital_id is
  'RS tempat dokter praktik. Dipakai untuk mengarahkan resep ke admin RS. '
  'Terisi otomatis bila nama RS pada kolom hospital cocok dengan hospitals.name.';
comment on column public.doctor_profiles.accepting_consultations is
  'Status Aktif/Istirahat (toggle dashboard + "Status Menerima Pasien" di profil).';
comment on column public.doctor_profiles.daily_quota is
  'Kuota antrean konsultasi per hari (kartu "Antrean 8 / 12 pasien").';

-- Cocokkan nama RS (teks bebas dari registrasi) ke hospitals.id.
-- SECURITY DEFINER karena RLS hospitals hanya mengizinkan admin membaca.
create or replace function public.doctor_profiles_resolve_hospital()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.hospital_id is null and coalesce(trim(new.hospital), '') <> '' then
    select h.id
      into new.hospital_id
    from public.hospitals h
    where lower(h.name) = lower(trim(new.hospital))
      and h.is_active
    limit 1;
  end if;
  return new;
end;
$$;

drop trigger if exists doctor_profiles_resolve_hospital on public.doctor_profiles;
create trigger doctor_profiles_resolve_hospital
  before insert or update of hospital, hospital_id on public.doctor_profiles
  for each row execute function public.doctor_profiles_resolve_hospital();

-- Registrasi dokter di aplikasi hanya menulis profiles + doctor_profiles.
-- Trigger ini menjaga user_roles (RBAC pusat) tetap konsisten.
create or replace function public.doctor_profiles_sync_role()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.user_roles (user_id, role, hospital_id)
  values (new.user_id, 'doctor', new.hospital_id)
  on conflict (user_id, role) do update
    set hospital_id = coalesce(excluded.hospital_id, public.user_roles.hospital_id);
  return new;
end;
$$;

drop trigger if exists doctor_profiles_sync_role on public.doctor_profiles;
create trigger doctor_profiles_sync_role
  after insert or update of hospital_id on public.doctor_profiles
  for each row execute function public.doctor_profiles_sync_role();

-- Backfill dokter yang sudah terdaftar sebelum file ini dijalankan.
update public.doctor_profiles dp
set hospital_id = h.id
from public.hospitals h
where dp.hospital_id is null
  and coalesce(trim(dp.hospital), '') <> ''
  and lower(h.name) = lower(trim(dp.hospital))
  and h.is_active;

insert into public.user_roles (user_id, role, hospital_id)
select dp.user_id, 'doctor', dp.hospital_id
from public.doctor_profiles dp
on conflict (user_id, role) do nothing;

-- =============================================================================
-- 2. Sesi konsultasi
--
-- Satu tabel untuk seluruh siklus:
--   requested -> scheduled -> ongoing -> completed
--        \-> rejected          \-> cancelled
-- Dashboard dokter memakai status requested (permintaan) dan scheduled/ongoing
-- (sesi terkonfirmasi); halaman Daftar Konsultasi memakai semuanya.
-- Data pasien disalin (snapshot) saat permintaan dibuat supaya catatan medis
-- tidak berubah bila profil pasien diedit kemudian.
-- =============================================================================
create table if not exists public.consultation_sessions (
  id                 uuid        primary key default gen_random_uuid(),
  doctor_user_id     text        not null,            -- Firebase UID dokter
  patient_user_id    text        not null,            -- Firebase UID pemilik akun pasien
  hospital_id        uuid        references public.hospitals(id) on delete set null,

  -- Snapshot pasien (bisa anggota keluarga: lihat patient_relation)
  patient_name       text        not null,
  patient_relation   text        not null default 'Saya sendiri',
  patient_age        int         check (patient_age is null or patient_age between 0 and 150),
  patient_gender     text        check (patient_gender is null
                                        or patient_gender in ('male', 'female', 'other')),
  patient_blood_type text        not null default '-',
  patient_allergies  jsonb       not null default '[]'::jsonb,

  complaint          text        not null default '',
  consultation_type  text        not null default 'chat'
                                 check (consultation_type in ('chat', 'video')),
  priority           text        not null default 'routine'
                                 check (priority in ('routine', 'medium', 'high')),
  status             text        not null default 'requested'
                                 check (status in (
                                   'requested', 'scheduled', 'ongoing',
                                   'completed', 'cancelled', 'rejected'
                                 )),
  fee                int         not null default 0 check (fee >= 0),

  requested_at       timestamptz not null default now(),
  responded_at       timestamptz,
  scheduled_at       timestamptz,
  started_at         timestamptz,
  completed_at       timestamptz,
  reject_reason      text        not null default '',

  -- Catatan dokter (tab "Catatan Dokter")
  diagnosis          text        not null default '',
  doctor_notes       text        not null default '',
  follow_up_date     date,

  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),

  constraint consultation_sessions_allergies_array
    check (jsonb_typeof(patient_allergies) = 'array')
);

create index if not exists consultation_sessions_doctor_idx
  on public.consultation_sessions (doctor_user_id, status, scheduled_at);
create index if not exists consultation_sessions_patient_idx
  on public.consultation_sessions (patient_user_id, created_at desc);
create index if not exists consultation_sessions_hospital_idx
  on public.consultation_sessions (hospital_id)
  where hospital_id is not null;

comment on table public.consultation_sessions is
  'Permintaan + sesi konsultasi dokter-pasien beserta catatan dokter.';
comment on column public.consultation_sessions.consultation_type is
  'chat = "Chat Dokter"/"Chat Online"; video = "Video Call".';
comment on column public.consultation_sessions.priority is
  'routine = Rutin, medium = Prioritas Sedang, high = Prioritas Tinggi.';
comment on column public.consultation_sessions.patient_gender is
  'Dinormalisasi seperti profiles.gender: male / female / other.';

drop trigger if exists consultation_sessions_set_updated_at on public.consultation_sessions;
create trigger consultation_sessions_set_updated_at
  before update on public.consultation_sessions
  for each row execute function public.set_updated_at();

-- hospital_id diisi dari profil dokter agar pasien tidak perlu mengetahuinya.
create or replace function public.consultation_sessions_fill_hospital()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.hospital_id is null then
    select coalesce(
             (select ur.hospital_id
                from public.user_roles ur
               where ur.user_id = new.doctor_user_id
                 and ur.role = 'doctor'
                 and ur.is_active
                 and ur.hospital_id is not null
               order by ur.created_at
               limit 1),
             dp.hospital_id)
      into new.hospital_id
    from public.doctor_profiles dp
    where dp.user_id = new.doctor_user_id;
  end if;
  return new;
end;
$$;

drop trigger if exists consultation_sessions_fill_hospital on public.consultation_sessions;
create trigger consultation_sessions_fill_hospital
  before insert on public.consultation_sessions
  for each row execute function public.consultation_sessions_fill_hospital();

-- Chat di dalam sesi -----------------------------------------------------------
create table if not exists public.consultation_messages (
  id              uuid        primary key default gen_random_uuid(),
  session_id      uuid        not null
                              references public.consultation_sessions(id) on delete cascade,
  sender_role     text        not null check (sender_role in ('doctor', 'patient')),
  sender_user_id  text        not null,
  body            text        not null check (length(trim(body)) > 0),
  created_at      timestamptz not null default now()
);

create index if not exists consultation_messages_session_idx
  on public.consultation_messages (session_id, created_at);

comment on table public.consultation_messages is
  'Pesan chat dokter-pasien dalam sesi. sender_role menggantikan ConsultationMessage.fromDoctor.';

-- Rekam vital pasien -----------------------------------------------------------
-- Dibaca dokter pada tab "Riwayat Medis". Pasien menulis dari Jurnal Kesehatan
-- (kategori cat1/cat2/cat3 = blood_pressure/blood_sugar/weight).
create table if not exists public.patient_vital_records (
  id               uuid          primary key default gen_random_uuid(),
  patient_user_id  text          not null,
  metric           text          not null
                                 check (metric in (
                                   'blood_pressure', 'blood_sugar', 'weight',
                                   'heart_rate', 'body_temperature'
                                 )),
  value            numeric(7, 2) not null,        -- sistolik utk blood_pressure
  secondary_value  numeric(7, 2),                 -- diastolik utk blood_pressure
  unit             text          not null default '',
  status           text          not null default 'normal'
                                 check (status in ('normal', 'warning', 'critical')),
  note             text          not null default '',
  recorded_at      timestamptz   not null default now(),
  created_at       timestamptz   not null default now()
);

create index if not exists patient_vital_records_patient_idx
  on public.patient_vital_records (patient_user_id, metric, recorded_at desc);

comment on column public.patient_vital_records.status is
  'normal = Normal, warning = Perhatian, critical = Kritis.';

-- Nilai terakhir per metrik (kartu "Vital Terkini"). security_invoker agar RLS
-- tabel dasar tetap berlaku.
create or replace view public.patient_latest_vitals
with (security_invoker = true) as
select distinct on (v.patient_user_id, v.metric)
  v.id,
  v.patient_user_id,
  v.metric,
  v.value,
  v.secondary_value,
  v.unit,
  v.status,
  v.note,
  v.recorded_at
from public.patient_vital_records v
order by v.patient_user_id, v.metric, v.recorded_at desc;

-- Resep dokter terhubung ke sesi ------------------------------------------------
alter table public.prescriptions
  add column if not exists consultation_session_id uuid
    references public.consultation_sessions(id) on delete set null;

-- Satu resep aktif per sesi (resep yang dibatalkan boleh dibuat ulang).
create unique index if not exists prescriptions_session_active_uniq
  on public.prescriptions (consultation_session_id)
  where consultation_session_id is not null and status <> 'cancelled';

create index if not exists prescriptions_doctor_idx
  on public.prescriptions (doctor_user_id, status, created_at desc);

-- =============================================================================
-- 3. Helper (schema app)
-- =============================================================================
create or replace function app.is_doctor()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select app.current_uid() is not null
     and (
       app.has_role('doctor')
       or exists (
         select 1 from public.doctor_profiles dp
         where dp.user_id = app.current_uid()
       )
     );
$$;

create or replace function app.current_doctor_hospital_id()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (select ur.hospital_id
       from public.user_roles ur
      where ur.user_id = app.current_uid()
        and ur.role = 'doctor'
        and ur.is_active
        and ur.hospital_id is not null
      order by ur.created_at
      limit 1),
    (select dp.hospital_id
       from public.doctor_profiles dp
      where dp.user_id = app.current_uid())
  );
$$;

-- Dokter hanya boleh melihat data medis pasien yang sedang/pernah ia tangani.
create or replace function app.doctor_has_patient(p_patient_user_id text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.consultation_sessions cs
    where cs.doctor_user_id = app.current_uid()
      and cs.patient_user_id = p_patient_user_id
      and cs.status in ('scheduled', 'ongoing', 'completed')
  );
$$;

-- Menulis item resep. Menerima objek lengkap ATAU string bebas, mis.
-- ["Amlodipine 10 mg 1x sehari"] (bentuk yang dihasilkan tab Catatan Dokter
-- saat ini). Admin melengkapi dosis/frekuensi saat verifikasi.
create or replace function app.write_prescription_items(
  p_prescription_id uuid,
  p_items jsonb
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_item  jsonb;
  v_pos   int := 0;
  v_name  text;
  v_dose  text;
  v_freq  int;
  v_dur   int;
  v_instr text;
begin
  if p_items is null
     or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'Minimal satu obat harus diisi' using errcode = '22023';
  end if;

  delete from public.prescription_items
  where prescription_id = p_prescription_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    if jsonb_typeof(v_item) = 'string' then
      v_name  := nullif(trim(v_item #>> '{}'), '');
      v_dose  := '';
      v_freq  := 1;
      v_dur   := 1;
      v_instr := '';
    else
      v_name  := nullif(trim(v_item ->> 'medication_name'), '');
      v_dose  := coalesce(v_item ->> 'dose', '');
      v_freq  := least(greatest(coalesce((v_item ->> 'frequency_per_day')::int, 1), 1), 12);
      v_dur   := least(greatest(coalesce((v_item ->> 'duration_days')::int, 1), 1), 365);
      v_instr := coalesce(v_item ->> 'special_instructions', '');
    end if;

    if v_name is null then
      raise exception 'Nama obat tidak boleh kosong' using errcode = '22023';
    end if;

    insert into public.prescription_items (
      prescription_id, position, medication_name, dose,
      frequency_per_day, duration_days, special_instructions
    )
    values (
      p_prescription_id, v_pos, v_name, v_dose, v_freq, v_dur, v_instr
    );
    v_pos := v_pos + 1;
  end loop;
end;
$$;

revoke all on function app.write_prescription_items(uuid, jsonb)
  from public, anon, authenticated;

grant execute on function app.is_doctor() to anon, authenticated;
grant execute on function app.current_doctor_hospital_id() to anon, authenticated;
grant execute on function app.doctor_has_patient(text) to anon, authenticated;

-- =============================================================================
-- 4. RPC dokter
-- =============================================================================

-- 4.1 Terima / tolak permintaan konsultasi ------------------------------------
create or replace function public.doctor_respond_consultation(
  p_session_id   uuid,
  p_accept       boolean,
  p_scheduled_at timestamptz default null,
  p_reason       text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid    text := app.current_uid();
  v_owner  text;
  v_status text;
begin
  if v_uid is null then
    raise exception 'Sesi login tidak valid' using errcode = '28000';
  end if;

  select cs.doctor_user_id, cs.status
    into v_owner, v_status
  from public.consultation_sessions cs
  where cs.id = p_session_id
  for update;

  if not found then
    raise exception 'Permintaan konsultasi tidak ditemukan' using errcode = 'P0002';
  end if;
  if v_owner is distinct from v_uid then
    raise exception 'Permintaan ini bukan untuk Anda' using errcode = '42501';
  end if;
  if v_status <> 'requested' then
    raise exception 'Permintaan sudah ditanggapi (status: %)', v_status
      using errcode = '22023';
  end if;

  update public.consultation_sessions
  set status       = case when p_accept then 'scheduled' else 'rejected' end,
      responded_at = now(),
      scheduled_at = case when p_accept then coalesce(p_scheduled_at, now())
                          else scheduled_at end,
      reject_reason = case when p_accept then ''
                           else coalesce(trim(p_reason), '') end
  where id = p_session_id;

  return jsonb_build_object(
    'session_id', p_session_id,
    'status', case when p_accept then 'scheduled' else 'rejected' end
  );
end;
$$;

-- 4.2 Mulai sesi (scheduled -> ongoing) ----------------------------------------
create or replace function public.doctor_start_consultation(p_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid    text := app.current_uid();
  v_owner  text;
  v_status text;
  v_start  timestamptz := now();
begin
  if v_uid is null then
    raise exception 'Sesi login tidak valid' using errcode = '28000';
  end if;

  select cs.doctor_user_id, cs.status
    into v_owner, v_status
  from public.consultation_sessions cs
  where cs.id = p_session_id
  for update;

  if not found then
    raise exception 'Sesi konsultasi tidak ditemukan' using errcode = 'P0002';
  end if;
  if v_owner is distinct from v_uid then
    raise exception 'Sesi ini bukan milik Anda' using errcode = '42501';
  end if;
  if v_status <> 'scheduled' then
    raise exception 'Hanya sesi terjadwal yang dapat dimulai.' using errcode = '22023';
  end if;

  update public.consultation_sessions
  set status = 'ongoing', started_at = v_start
  where id = p_session_id;

  return jsonb_build_object(
    'session_id', p_session_id,
    'status', 'ongoing',
    'started_at', v_start
  );
end;
$$;

-- 4.3 Simpan catatan dokter; p_complete = true sekaligus menyelesaikan sesi ----
-- Setara ConsultationRepository.saveSessionNotes(). Daftar obat TIDAK disimpan
-- di sini; serahkan lewat doctor_submit_prescription().
create or replace function public.doctor_save_consultation_notes(
  p_session_id     uuid,
  p_diagnosis      text,
  p_notes          text,
  p_follow_up_date date default null,
  p_complete       boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid text := app.current_uid();
  v_row public.consultation_sessions%rowtype;
begin
  if v_uid is null then
    raise exception 'Sesi login tidak valid' using errcode = '28000';
  end if;

  select * into v_row
  from public.consultation_sessions cs
  where cs.id = p_session_id
  for update;

  if not found then
    raise exception 'Sesi konsultasi tidak ditemukan' using errcode = 'P0002';
  end if;
  if v_row.doctor_user_id is distinct from v_uid then
    raise exception 'Sesi ini bukan milik Anda' using errcode = '42501';
  end if;
  if v_row.status not in ('scheduled', 'ongoing') then
    raise exception 'Catatan tidak dapat diubah pada sesi berstatus %', v_row.status
      using errcode = '22023';
  end if;
  if p_complete and v_row.status <> 'ongoing' then
    raise exception 'Hanya sesi yang sedang berlangsung yang dapat diselesaikan.'
      using errcode = '22023';
  end if;

  update public.consultation_sessions cs
  set diagnosis      = coalesce(trim(p_diagnosis), ''),
      doctor_notes   = coalesce(trim(p_notes), ''),
      follow_up_date = coalesce(p_follow_up_date, cs.follow_up_date),
      status         = case when p_complete then 'completed' else cs.status end,
      completed_at   = case when p_complete then now() else cs.completed_at end
  where cs.id = p_session_id
  returning * into v_row;

  return to_jsonb(v_row);
end;
$$;

-- 4.4 Serahkan resep ke admin RS -----------------------------------------------
-- Membuat (atau memakai ulang) baris hospital_patients untuk pasien tsb di RS
-- dokter, lalu menerbitkan resep berstatus pending_verification yang akan muncul
-- di halaman "Verifikasi Obat" admin tanpa perubahan kode admin.
create or replace function public.doctor_submit_prescription(
  p_session_id uuid,
  p_items      jsonb,
  p_note       text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid         text := app.current_uid();
  v_s           public.consultation_sessions%rowtype;
  v_hospital    uuid;
  v_doctor_name text;
  v_hp          uuid;
  v_rx          uuid;
begin
  if v_uid is null then
    raise exception 'Sesi login tidak valid' using errcode = '28000';
  end if;

  -- Aktifkan setelah admin RS memiliki alur verifikasi kredensial dokter:
  -- if not exists (select 1 from public.doctor_profiles
  --                where user_id = v_uid and verified) then
  --   raise exception 'Kredensial dokter belum terverifikasi' using errcode = '42501';
  -- end if;

  select * into v_s
  from public.consultation_sessions cs
  where cs.id = p_session_id
  for update;

  if not found then
    raise exception 'Sesi konsultasi tidak ditemukan' using errcode = 'P0002';
  end if;
  if v_s.doctor_user_id is distinct from v_uid then
    raise exception 'Sesi ini bukan milik Anda' using errcode = '42501';
  end if;
  if v_s.status not in ('ongoing', 'completed') then
    raise exception 'Resep hanya dapat diserahkan pada sesi berlangsung atau selesai.'
      using errcode = '22023';
  end if;
  if exists (
    select 1 from public.prescriptions rx
    where rx.consultation_session_id = p_session_id
      and rx.status <> 'cancelled'
  ) then
    raise exception 'Resep untuk sesi ini sudah diserahkan ke admin.'
      using errcode = '23505';
  end if;

  v_hospital := coalesce(v_s.hospital_id, app.current_doctor_hospital_id());
  if v_hospital is null then
    raise exception
      'Akun dokter belum terhubung ke rumah sakit. Isi nama RS pada profil '
      'sesuai data rumah sakit, atau minta admin menautkannya.'
      using errcode = '22023';
  end if;

  select coalesce(nullif(trim(pr.full_name), ''), v_uid)
    into v_doctor_name
  from public.profiles pr
  where pr.id = v_uid;
  v_doctor_name := coalesce(v_doctor_name, v_uid);

  -- Jangan menimpa data yang sudah dikelola admin (diagnosis & dokter DPJP).
  insert into public.hospital_patients as hp (
    hospital_id, patient_user_id, full_name, diagnosis,
    attending_doctor_user_id, attending_doctor_name
  )
  values (
    v_hospital, v_s.patient_user_id, v_s.patient_name, v_s.diagnosis,
    v_uid, v_doctor_name
  )
  on conflict (hospital_id, patient_user_id) do update
    set diagnosis = case when hp.diagnosis = ''
                         then excluded.diagnosis else hp.diagnosis end,
        attending_doctor_name = case when hp.attending_doctor_user_id is null
                                     then excluded.attending_doctor_name
                                     else hp.attending_doctor_name end,
        attending_doctor_user_id = coalesce(hp.attending_doctor_user_id,
                                            excluded.attending_doctor_user_id),
        is_active = true
  returning hp.id into v_hp;

  insert into public.prescriptions (
    hospital_id, hospital_patient_id, doctor_user_id, doctor_name,
    status, doctor_note, consultation_session_id
  )
  values (
    v_hospital, v_hp, v_uid, v_doctor_name,
    'pending_verification',
    coalesce(nullif(trim(p_note), ''), nullif(v_s.doctor_notes, ''), ''),
    p_session_id
  )
  returning id into v_rx;

  perform app.write_prescription_items(v_rx, p_items);

  return jsonb_build_object(
    'prescription_id', v_rx,
    'hospital_patient_id', v_hp,
    'status', 'pending_verification'
  );
end;
$$;

-- 4.5 Jawab permintaan klarifikasi admin ---------------------------------------
create or replace function public.doctor_respond_prescription_clarification(
  p_prescription_id uuid,
  p_response        text,
  p_items           jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid    text := app.current_uid();
  v_owner  text;
  v_status text;
begin
  if v_uid is null then
    raise exception 'Sesi login tidak valid' using errcode = '28000';
  end if;

  select rx.doctor_user_id, rx.status
    into v_owner, v_status
  from public.prescriptions rx
  where rx.id = p_prescription_id
  for update;

  if not found then
    raise exception 'Resep tidak ditemukan' using errcode = 'P0002';
  end if;
  if v_owner is distinct from v_uid then
    raise exception 'Resep ini bukan milik Anda' using errcode = '42501';
  end if;
  if v_status <> 'needs_clarification' then
    raise exception 'Resep tidak sedang meminta klarifikasi (status: %)', v_status
      using errcode = '22023';
  end if;
  if nullif(trim(p_response), '') is null and p_items is null then
    raise exception 'Isi tanggapan atau perbarui daftar obat' using errcode = '22023';
  end if;

  if p_items is not null then
    perform app.write_prescription_items(p_prescription_id, p_items);
  end if;

  update public.prescriptions rx
  set status = 'pending_verification',
      doctor_note = case
        when nullif(trim(p_response), '') is null then rx.doctor_note
        else concat_ws(
               E'\n\n',
               nullif(rx.doctor_note, ''),
               '[Tanggapan dokter] ' || trim(p_response)
             )
      end
  where rx.id = p_prescription_id;

  return jsonb_build_object(
    'prescription_id', p_prescription_id,
    'status', 'pending_verification'
  );
end;
$$;

-- 4.6 Batalkan resep yang belum diverifikasi -----------------------------------
create or replace function public.doctor_cancel_prescription(p_prescription_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid    text := app.current_uid();
  v_owner  text;
  v_status text;
begin
  if v_uid is null then
    raise exception 'Sesi login tidak valid' using errcode = '28000';
  end if;

  select rx.doctor_user_id, rx.status
    into v_owner, v_status
  from public.prescriptions rx
  where rx.id = p_prescription_id
  for update;

  if not found then
    raise exception 'Resep tidak ditemukan' using errcode = 'P0002';
  end if;
  if v_owner is distinct from v_uid then
    raise exception 'Resep ini bukan milik Anda' using errcode = '42501';
  end if;
  if v_status not in ('pending_verification', 'needs_clarification') then
    raise exception 'Resep berstatus % tidak dapat dibatalkan', v_status
      using errcode = '22023';
  end if;

  update public.prescriptions
  set status = 'cancelled'
  where id = p_prescription_id;

  return jsonb_build_object('prescription_id', p_prescription_id, 'status', 'cancelled');
end;
$$;

-- 4.7 Ringkasan dashboard dokter -----------------------------------------------
create or replace function public.doctor_dashboard_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid       text := app.current_uid();
  v_today     date := (now() at time zone 'Asia/Jakarta')::date;
  v_quota     int;
  v_accepting boolean;
begin
  if v_uid is null then
    raise exception 'Sesi login tidak valid' using errcode = '28000';
  end if;

  select dp.daily_quota, dp.accepting_consultations
    into v_quota, v_accepting
  from public.doctor_profiles dp
  where dp.user_id = v_uid;

  return jsonb_build_object(
    'pending_requests', (
      select count(*) from public.consultation_sessions cs
      where cs.doctor_user_id = v_uid and cs.status = 'requested'
    ),
    'today_sessions', (
      select count(*) from public.consultation_sessions cs
      where cs.doctor_user_id = v_uid
        and cs.status in ('scheduled', 'ongoing')
        and (coalesce(cs.scheduled_at, cs.requested_at)
               at time zone 'Asia/Jakarta')::date = v_today
    ),
    'queue_filled', (
      select count(*) from public.consultation_sessions cs
      where cs.doctor_user_id = v_uid
        and cs.status in ('scheduled', 'ongoing', 'completed')
        and (coalesce(cs.started_at, cs.scheduled_at, cs.requested_at)
               at time zone 'Asia/Jakarta')::date = v_today
    ),
    'completed_total', (
      select count(*) from public.consultation_sessions cs
      where cs.doctor_user_id = v_uid and cs.status = 'completed'
    ),
    'daily_quota', coalesce(v_quota, 12),
    'accepting_consultations', coalesce(v_accepting, true),
    'prescriptions_pending', (
      select count(*) from public.prescriptions rx
      where rx.doctor_user_id = v_uid and rx.status = 'pending_verification'
    ),
    'prescriptions_need_clarification', (
      select count(*) from public.prescriptions rx
      where rx.doctor_user_id = v_uid and rx.status = 'needs_clarification'
    )
  );
end;
$$;

-- 4.8 Riwayat kunjungan pasien ke dokter mana pun (tab "Kunjungan") -------------
create or replace function public.doctor_patient_consultation_history(
  p_patient_user_id   text,
  p_exclude_session_id uuid default null
)
returns table (
  id                    uuid,
  doctor_name           text,
  specialization        text,
  hospital              text,
  consulted_at          timestamptz,
  complaint             text,
  diagnosis             text,
  notes                 text,
  prescribed_medications jsonb,
  follow_up_date        date
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not app.doctor_has_patient(p_patient_user_id) then
    raise exception 'Anda tidak memiliki sesi dengan pasien ini' using errcode = '42501';
  end if;

  return query
  select
    cs.id,
    coalesce(nullif(trim(pr.full_name), ''), cs.doctor_user_id),
    coalesce(dp.specialization, ''),
    coalesce(h.name, dp.hospital, ''),
    coalesce(cs.completed_at, cs.started_at, cs.requested_at),
    cs.complaint,
    cs.diagnosis,
    cs.doctor_notes,
    coalesce((
      select jsonb_agg(
               concat_ws(' ', pi.medication_name, nullif(pi.dose, ''),
                         pi.frequency_per_day::text || 'x sehari')
               order by pi.position)
      from public.prescriptions rx
      join public.prescription_items pi on pi.prescription_id = rx.id
      where rx.consultation_session_id = cs.id
        and rx.status <> 'cancelled'
    ), '[]'::jsonb),
    cs.follow_up_date
  from public.consultation_sessions cs
  left join public.profiles pr         on pr.id = cs.doctor_user_id
  left join public.doctor_profiles dp  on dp.user_id = cs.doctor_user_id
  left join public.hospitals h         on h.id = coalesce(cs.hospital_id, dp.hospital_id)
  where cs.patient_user_id = p_patient_user_id
    and cs.status = 'completed'
    and (p_exclude_session_id is null or cs.id <> p_exclude_session_id)
  order by coalesce(cs.completed_at, cs.started_at, cs.requested_at) desc;
end;
$$;

-- 4.9 Riwayat obat pasien dari resep terverifikasi (tab "Riwayat Obat") ----------
create or replace function public.doctor_patient_medications(p_patient_user_id text)
returns table (
  id                uuid,
  medication_name   text,
  dose              text,
  frequency_per_day int,
  duration_days     int,
  instructions      text,
  start_date        date,
  end_date          date,
  prescribed_by     text,
  indication        text,
  is_active         boolean
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not app.doctor_has_patient(p_patient_user_id) then
    raise exception 'Anda tidak memiliki sesi dengan pasien ini' using errcode = '42501';
  end if;

  return query
  select
    pi.id,
    pi.medication_name,
    pi.dose,
    pi.frequency_per_day,
    pi.duration_days,
    pi.special_instructions,
    rx.scheduled_start,
    rx.scheduled_end,
    rx.doctor_name,
    coalesce(nullif(cs.diagnosis, ''), nullif(hp.diagnosis, ''), ''),
    coalesce(rx.scheduled_end >= current_date, false)
  from public.prescriptions rx
  join public.hospital_patients hp   on hp.id = rx.hospital_patient_id
  join public.prescription_items pi  on pi.prescription_id = rx.id
  left join public.consultation_sessions cs on cs.id = rx.consultation_session_id
  where hp.patient_user_id = p_patient_user_id
    and rx.status = 'verified'
  order by rx.scheduled_start desc nulls last, pi.position;
end;
$$;

revoke all on function
  public.doctor_respond_consultation(uuid, boolean, timestamptz, text),
  public.doctor_start_consultation(uuid),
  public.doctor_save_consultation_notes(uuid, text, text, date, boolean),
  public.doctor_submit_prescription(uuid, jsonb, text),
  public.doctor_respond_prescription_clarification(uuid, text, jsonb),
  public.doctor_cancel_prescription(uuid),
  public.doctor_dashboard_summary(),
  public.doctor_patient_consultation_history(text, uuid),
  public.doctor_patient_medications(text)
  from public;

grant execute on function
  public.doctor_respond_consultation(uuid, boolean, timestamptz, text),
  public.doctor_start_consultation(uuid),
  public.doctor_save_consultation_notes(uuid, text, text, date, boolean),
  public.doctor_submit_prescription(uuid, jsonb, text),
  public.doctor_respond_prescription_clarification(uuid, text, jsonb),
  public.doctor_cancel_prescription(uuid),
  public.doctor_dashboard_summary(),
  public.doctor_patient_consultation_history(text, uuid),
  public.doctor_patient_medications(text)
  to anon, authenticated;

-- =============================================================================
-- 5. Row Level Security
-- =============================================================================
alter table public.consultation_sessions  enable row level security;
alter table public.consultation_messages  enable row level security;
alter table public.patient_vital_records  enable row level security;

-- Sesi: peserta (dokter atau pasien) boleh membaca. Pasien boleh membuat
-- permintaan baru. TIDAK ada policy update/delete: perubahan lewat RPC.
drop policy if exists consultation_sessions_participant_read on public.consultation_sessions;
create policy consultation_sessions_participant_read on public.consultation_sessions
  for select to anon, authenticated
  using (
    doctor_user_id = app.current_uid()
    or patient_user_id = app.current_uid()
  );

drop policy if exists consultation_sessions_patient_insert on public.consultation_sessions;
create policy consultation_sessions_patient_insert on public.consultation_sessions
  for insert to anon, authenticated
  with check (
    patient_user_id = app.current_uid()
    and status = 'requested'
    and diagnosis = ''
    and doctor_notes = ''
    and scheduled_at is null
    and responded_at is null
    and started_at is null
    and completed_at is null
    and exists (
      select 1 from public.doctor_profiles dp
      where dp.user_id = consultation_sessions.doctor_user_id
    )
  );

-- Chat: hanya peserta sesi; kirim pesan hanya saat sesi berlangsung.
drop policy if exists consultation_messages_participant_read on public.consultation_messages;
create policy consultation_messages_participant_read on public.consultation_messages
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.consultation_sessions cs
      where cs.id = consultation_messages.session_id
        and (cs.doctor_user_id = app.current_uid()
             or cs.patient_user_id = app.current_uid())
    )
  );

drop policy if exists consultation_messages_participant_insert on public.consultation_messages;
create policy consultation_messages_participant_insert on public.consultation_messages
  for insert to anon, authenticated
  with check (
    sender_user_id = app.current_uid()
    and exists (
      select 1 from public.consultation_sessions cs
      where cs.id = consultation_messages.session_id
        and cs.status = 'ongoing'
        and (
          (consultation_messages.sender_role = 'doctor'
             and cs.doctor_user_id = app.current_uid())
          or
          (consultation_messages.sender_role = 'patient'
             and cs.patient_user_id = app.current_uid())
        )
    )
  );

-- Rekam vital: pemilik penuh; dokter hanya baca untuk pasien yang ditangani.
drop policy if exists patient_vitals_owner_all on public.patient_vital_records;
create policy patient_vitals_owner_all on public.patient_vital_records
  for all to anon, authenticated
  using (patient_user_id = app.current_uid())
  with check (patient_user_id = app.current_uid());

drop policy if exists patient_vitals_doctor_read on public.patient_vital_records;
create policy patient_vitals_doctor_read on public.patient_vital_records
  for select to anon, authenticated
  using (app.doctor_has_patient(patient_user_id));

-- Resep: dokter membaca resep miliknya (policy admin dari file 03 tetap berlaku;
-- policy permissive digabung dengan OR). Dokter tidak punya akses tulis langsung.
drop policy if exists prescriptions_doctor_read on public.prescriptions;
create policy prescriptions_doctor_read on public.prescriptions
  for select to anon, authenticated
  using (doctor_user_id = app.current_uid());

drop policy if exists prescription_items_doctor_read on public.prescription_items;
create policy prescription_items_doctor_read on public.prescription_items
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.prescriptions rx
      where rx.id = prescription_items.prescription_id
        and rx.doctor_user_id = app.current_uid()
    )
  );

-- Nama pasien pada daftar resep dokter (embed hospital_patients(...)).
drop policy if exists hospital_patients_doctor_read on public.hospital_patients;
create policy hospital_patients_doctor_read on public.hospital_patients
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.prescriptions rx
      where rx.hospital_patient_id = hospital_patients.id
        and rx.doctor_user_id = app.current_uid()
    )
  );

-- Grant tabel/view (RLS tetap menjadi pembatas baris).
grant select, insert on public.consultation_sessions to anon, authenticated;
grant select, insert on public.consultation_messages to anon, authenticated;
grant select, insert, update, delete on public.patient_vital_records to anon, authenticated;
grant select on public.patient_latest_vitals to anon, authenticated;

-- =============================================================================
-- 6. Realtime (permintaan baru & chat sesi)
-- =============================================================================
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.consultation_sessions;
    exception when duplicate_object then null;
    end;

    begin
      alter publication supabase_realtime add table public.consultation_messages;
    exception when duplicate_object then null;
    end;
  end if;
end;
$$;

-- =============================================================================
-- 7. OPSIONAL — pengetatan sebelum produksi
--
-- Policy doctor_profiles dari file 02 masih terbuka (demo). Pengetatan berikut
-- membatasi tulis ke baris milik sendiri; baca tetap terbuka untuk direktori.
-- Jalankan HANYA setelah registrasi dokter memakai JWT Firebase yang valid.
--
-- drop policy if exists demo_all_doctor_profiles on public.doctor_profiles;
-- create policy doctor_profiles_read on public.doctor_profiles
--   for select to anon, authenticated using (true);
-- create policy doctor_profiles_write_own on public.doctor_profiles
--   for insert to anon, authenticated with check (user_id = app.current_uid());
-- create policy doctor_profiles_update_own on public.doctor_profiles
--   for update to anon, authenticated
--   using (user_id = app.current_uid()) with check (user_id = app.current_uid());
-- =============================================================================

-- =============================================================================
-- 8. Verifikasi cepat (read-only)
-- =============================================================================
select
  expected.table_name,
  (to_regclass('public.' || expected.table_name) is not null) as table_exists,
  coalesce(cls.relrowsecurity, false)                         as rls_enabled
from (values
  ('consultation_sessions'),
  ('consultation_messages'),
  ('patient_vital_records')
) as expected(table_name)
left join pg_class cls on cls.oid = to_regclass('public.' || expected.table_name)
order by expected.table_name;
