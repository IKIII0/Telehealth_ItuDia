-- =============================================================================
-- Telehealth — RBAC "hospital_admin" + data Web Dashboard Admin Rumah Sakit
--
-- Jalankan setelah:
--   1. 01_medication_doctor_chat.sql
--   2. 02_profiles_auth_sync.sql
--
-- ISI FILE
--   1.  Tabel hospitals + user_roles (RBAC, terhubung ke Firebase UID)
--   2.  Helper function: app.current_uid(), app.current_hospital_id()
--   3.  Tabel monitoring pasca rawat inap: patients, prescriptions,
--       prescription_items, medication_adherence, patient_reports,
--       admin_follow_ups
--   4.  View: hospital_patient_monitoring, hospital_alerts
--   5.  RPC: hospital_admin_summary, hospital_verify_prescription,
--       hospital_request_clarification, hospital_record_follow_up
--   6.  RLS policy berbasis `auth.jwt() ->> 'sub'` (Firebase UID)
--   7.  Realtime publication + seed data demo
--
-- =============================================================================
-- PENTING — FIREBASE AUTH SEBAGAI THIRD-PARTY AUTH SUPABASE
-- =============================================================================
-- Aplikasi ini memakai Firebase Authentication, bukan Supabase Auth. Agar
-- `auth.jwt()` berisi klaim Firebase (termasuk `sub` = Firebase UID), lakukan:
--
--   1. Supabase Dashboard → Authentication → Third-Party Auth → Firebase.
--      Masukkan Firebase Project ID.
--   2. Kirim Firebase ID token pada setiap request Supabase. Di Flutter hal ini
--      dilakukan oleh `SupabaseConfig.firebaseAuthClient` (lihat
--      lib/core/supabase/supabase_config.dart) yang membuat SupabaseClient
--      dengan opsi `accessToken`.
--   3. Setelah itu rol Postgres untuk request tersebut adalah `authenticated`
--      dan `auth.jwt() ->> 'sub'` berisi Firebase UID pengguna.
--
-- Tanpa langkah di atas, semua policy di file ini akan menolak akses (sesuai
-- desain: dashboard admin tidak boleh terbuka untuk anon).
--
-- CATATAN KEAMANAN
-- Fungsi helper di schema `app` dibuat SECURITY DEFINER agar dapat membaca
-- public.user_roles tanpa memicu rekursi RLS. Jalankan file ini sebagai
-- `postgres` (SQL Editor Supabase) supaya fungsi dimiliki role yang berhak.
-- Jangan pernah menaruh service_role key di aplikasi Flutter.
-- =============================================================================

create extension if not exists pgcrypto;

-- =============================================================================
-- 1. Rumah sakit & RBAC
-- =============================================================================
create table if not exists public.hospitals (
  id          uuid        primary key default gen_random_uuid(),
  name        text        not null,
  code        text        not null,
  city        text        not null default '',
  address     text        not null default '',
  phone       text        not null default '',
  email       text        not null default '',
  logo_color  bigint      not null default x'FF0E7490'::bigint,
  is_active   boolean     not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create unique index if not exists hospitals_code_unique
  on public.hospitals (lower(code));

comment on table public.hospitals is
  'Master data rumah sakit. Menjadi batas (tenant) akses hospital_admin.';

-- Tabel RBAC pusat. Satu pengguna boleh punya lebih dari satu role
-- (mis. seorang dokter juga admin rumah sakit lain).
create table if not exists public.user_roles (
  user_id     text        not null,           -- Firebase user.uid
  role        text        not null
                          check (role in ('patient', 'doctor', 'hospital_admin', 'super_admin')),
  hospital_id uuid        references public.hospitals(id) on delete cascade,
  is_active   boolean     not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  primary key (user_id, role),
  constraint user_roles_hospital_required
    check (role <> 'hospital_admin' or hospital_id is not null)
);

create index if not exists user_roles_user_idx
  on public.user_roles (user_id, role);

create index if not exists user_roles_hospital_idx
  on public.user_roles (hospital_id, role)
  where is_active;

comment on table public.user_roles is
  'RBAC aplikasi. user_id = Firebase Authentication user.uid. '
  'hospital_id membatasi data yang boleh diakses hospital_admin.';

-- profiles.role sebelumnya hanya mengizinkan patient/doctor/admin.
-- Perluas agar sesi hospital_admin ikut tersinkron dari aplikasi.
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('patient', 'doctor', 'admin', 'hospital_admin'));

-- =============================================================================
-- 2. Helper function (schema app, tidak diekspos sebagai REST endpoint)
-- =============================================================================
create schema if not exists app;

create or replace function app.current_uid()
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  -- `sub` pada JWT Firebase berisi Firebase UID.
  select nullif(auth.jwt() ->> 'sub', '');
$$;

comment on function app.current_uid() is
  'Firebase UID pemanggil, diambil dari auth.jwt() -> sub.';

create or replace function app.has_role(p_role text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = app.current_uid()
      and ur.role = p_role
      and ur.is_active
  );
$$;

create or replace function app.current_hospital_id()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select ur.hospital_id
  from public.user_roles ur
  where ur.user_id = app.current_uid()
    and ur.role = 'hospital_admin'
    and ur.is_active
  order by ur.created_at
  limit 1;
$$;

comment on function app.current_hospital_id() is
  'hospital_id milik admin yang sedang memanggil. NULL untuk role lain.';

create or replace function app.is_hospital_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select app.current_hospital_id() is not null or app.has_role('super_admin');
$$;

grant usage on schema app to authenticated;
grant execute on function app.current_uid() to authenticated;
grant execute on function app.has_role(text) to authenticated;
grant execute on function app.current_hospital_id() to authenticated;
grant execute on function app.is_hospital_admin() to authenticated;

-- =============================================================================
-- 3. Data monitoring pasca rawat inap
-- =============================================================================
create table if not exists public.hospital_patients (
  id                        uuid        primary key default gen_random_uuid(),
  hospital_id               uuid        not null references public.hospitals(id) on delete cascade,
  patient_user_id           text        not null,  -- Firebase UID pasien
  full_name                 text        not null,
  medical_record_no         text        not null default '',
  diagnosis                 text        not null default '',
  discharge_date            date        not null default current_date,
  attending_doctor_user_id  text,
  attending_doctor_name     text        not null default '',
  risk_level                text        not null default 'low'
                                        check (risk_level in ('low', 'medium', 'high')),
  is_active                 boolean     not null default true,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  unique (hospital_id, patient_user_id)
);

create index if not exists hospital_patients_hospital_idx
  on public.hospital_patients (hospital_id, is_active, risk_level);

comment on table public.hospital_patients is
  'Pasien pasca rawat inap yang dipantau oleh sebuah rumah sakit.';

create table if not exists public.prescriptions (
  id                uuid        primary key default gen_random_uuid(),
  hospital_id       uuid        not null references public.hospitals(id) on delete cascade,
  hospital_patient_id uuid      not null references public.hospital_patients(id) on delete cascade,
  doctor_user_id    text,
  doctor_name       text        not null default '',
  status            text        not null default 'pending_verification'
                                check (status in (
                                  'pending_verification',
                                  'verified',
                                  'needs_clarification',
                                  'cancelled'
                                )),
  doctor_note       text        not null default '',
  admin_note        text        not null default '',
  verified_by       text,
  verified_at       timestamptz,
  scheduled_start   date,
  scheduled_end     date,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index if not exists prescriptions_hospital_status_idx
  on public.prescriptions (hospital_id, status, created_at desc);

create index if not exists prescriptions_patient_idx
  on public.prescriptions (hospital_patient_id, created_at desc);

comment on table public.prescriptions is
  'Resep dokter. Alur: pending_verification → verified | needs_clarification.';

create table if not exists public.prescription_items (
  id                    uuid    primary key default gen_random_uuid(),
  prescription_id       uuid    not null references public.prescriptions(id) on delete cascade,
  position              int     not null default 0,
  medication_name       text    not null,
  dose                  text    not null default '',
  frequency_per_day     int     not null default 1
                                check (frequency_per_day between 1 and 12),
  duration_days         int     not null default 1
                                check (duration_days between 1 and 365),
  special_instructions  text    not null default '',
  created_at            timestamptz not null default now()
);

create index if not exists prescription_items_prescription_idx
  on public.prescription_items (prescription_id, position);

create table if not exists public.medication_adherence (
  id                  uuid    primary key default gen_random_uuid(),
  hospital_id         uuid    not null references public.hospitals(id) on delete cascade,
  hospital_patient_id uuid    not null references public.hospital_patients(id) on delete cascade,
  prescription_id     uuid    references public.prescriptions(id) on delete set null,
  taken_date          date    not null default current_date,
  scheduled_doses     int     not null default 0 check (scheduled_doses >= 0),
  taken_doses         int     not null default 0 check (taken_doses >= 0),
  missed_doses        int     generated always as (greatest(scheduled_doses - taken_doses, 0)) stored,
  note                text    not null default '',
  created_at          timestamptz not null default now(),
  unique (hospital_id, hospital_patient_id, taken_date)
);

create index if not exists medication_adherence_hospital_date_idx
  on public.medication_adherence (hospital_id, taken_date desc);

comment on table public.medication_adherence is
  'Rekap kepatuhan minum obat per pasien per hari (dilaporkan aplikasi mobile).';

create table if not exists public.patient_reports (
  id                  uuid    primary key default gen_random_uuid(),
  hospital_id         uuid    not null references public.hospitals(id) on delete cascade,
  hospital_patient_id uuid    not null references public.hospital_patients(id) on delete cascade,
  report_type         text    not null default 'symptom'
                              check (report_type in ('symptom', 'missed_dose', 'other')),
  message             text    not null,
  severity            text    not null default 'medium'
                              check (severity in ('low', 'medium', 'high')),
  status              text    not null default 'open'
                              check (status in ('open', 'in_review', 'resolved')),
  resolved_at         timestamptz,
  resolved_by         text,
  created_at          timestamptz not null default now()
);

create index if not exists patient_reports_hospital_status_idx
  on public.patient_reports (hospital_id, status, created_at desc);

create table if not exists public.admin_follow_ups (
  id                  uuid    primary key default gen_random_uuid(),
  hospital_id         uuid    not null references public.hospitals(id) on delete cascade,
  hospital_patient_id uuid    not null references public.hospital_patients(id) on delete cascade,
  prescription_id     uuid    references public.prescriptions(id) on delete set null,
  patient_report_id   uuid    references public.patient_reports(id) on delete set null,
  action              text    not null,
  note                text    not null default '',
  created_by          text    not null,           -- Firebase UID admin
  created_at          timestamptz not null default now()
);

create index if not exists admin_follow_ups_patient_idx
  on public.admin_follow_ups (hospital_patient_id, created_at desc);

-- =============================================================================
-- 4. Trigger updated_at
-- =============================================================================
drop trigger if exists hospitals_set_updated_at on public.hospitals;
create trigger hospitals_set_updated_at
  before update on public.hospitals
  for each row execute function public.set_updated_at();

drop trigger if exists user_roles_set_updated_at on public.user_roles;
create trigger user_roles_set_updated_at
  before update on public.user_roles
  for each row execute function public.set_updated_at();

drop trigger if exists hospital_patients_set_updated_at on public.hospital_patients;
create trigger hospital_patients_set_updated_at
  before update on public.hospital_patients
  for each row execute function public.set_updated_at();

drop trigger if exists prescriptions_set_updated_at on public.prescriptions;
create trigger prescriptions_set_updated_at
  before update on public.prescriptions
  for each row execute function public.set_updated_at();

-- =============================================================================
-- 5. View baca untuk dashboard
-- =============================================================================
create or replace view public.hospital_patient_monitoring
with (security_invoker = true) as
select
  hp.id,
  hp.hospital_id,
  hp.patient_user_id,
  hp.full_name,
  hp.medical_record_no,
  hp.diagnosis,
  hp.discharge_date,
  hp.attending_doctor_name,
  hp.risk_level,
  hp.is_active,
  coalesce((
    select round(100.0 * sum(a.taken_doses) / nullif(sum(a.scheduled_doses), 0), 1)
    from public.medication_adherence a
    where a.hospital_patient_id = hp.id
  ), 0)::numeric(5, 1) as adherence_score,
  coalesce((
    select sum(a.missed_doses)
    from public.medication_adherence a
    where a.hospital_patient_id = hp.id
      and a.taken_date = current_date
  ), 0)::int as missed_doses_today,
  (
    select count(*)
    from public.patient_reports r
    where r.hospital_patient_id = hp.id
      and r.status <> 'resolved'
  )::int as open_reports,
  (
    select count(*)
    from public.prescriptions p
    where p.hospital_patient_id = hp.id
      and p.status = 'pending_verification'
  )::int as pending_prescriptions,
  (
    select max(a.taken_date)
    from public.medication_adherence a
    where a.hospital_patient_id = hp.id
  ) as last_adherence_date
from public.hospital_patients hp;

comment on view public.hospital_patient_monitoring is
  'Satu baris per pasien + skor kepatuhan, dosis terlewat hari ini, dan jumlah laporan terbuka.';

create or replace view public.hospital_alerts
with (security_invoker = true) as
select
  a.id,
  a.hospital_id,
  a.hospital_patient_id,
  hp.full_name as patient_name,
  'missed_dose'::text as alert_type,
  case
    when a.missed_doses >= 2 then 'high'
    else 'medium'
  end::text as severity,
  format(
    'Melewatkan %s dari %s dosis pada %s',
    a.missed_doses,
    a.scheduled_doses,
    to_char(a.taken_date, 'DD Mon YYYY')
  ) as message,
  a.created_at
from public.medication_adherence a
join public.hospital_patients hp on hp.id = a.hospital_patient_id
where a.missed_doses > 0
union all
select
  r.id,
  r.hospital_id,
  r.hospital_patient_id,
  hp.full_name as patient_name,
  'complaint'::text as alert_type,
  r.severity,
  r.message,
  r.created_at
from public.patient_reports r
join public.hospital_patients hp on hp.id = r.hospital_patient_id
where r.status <> 'resolved';

comment on view public.hospital_alerts is
  'Peringatan aktif: dosis terlewat + keluhan pasien yang belum ditindaklanjuti.';

-- =============================================================================
-- 6. RPC
-- =============================================================================

-- Ringkasan kartu dashboard, selalu dibatasi ke rumah sakit si admin.
create or replace function public.hospital_admin_summary()
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with mine as (
    select
      app.current_hospital_id() as hospital_id,
      case
        when app.has_role('super_admin') then true
        else false
      end as is_super_admin
  ),
  scoped_patients as (
    select hp.*
    from public.hospital_patients hp, mine
    where mine.is_super_admin or hp.hospital_id = mine.hospital_id
  ),
  scoped_prescriptions as (
    select p.*
    from public.prescriptions p, mine
    where mine.is_super_admin or p.hospital_id = mine.hospital_id
  ),
  scoped_adherence as (
    select a.*
    from public.medication_adherence a, mine
    where mine.is_super_admin or a.hospital_id = mine.hospital_id
  ),
  scoped_alerts as (
    select al.*
    from public.hospital_alerts al, mine
    where mine.is_super_admin or al.hospital_id = mine.hospital_id
  )
  select jsonb_build_object(
    'hospital_id', (select hospital_id from mine),
    'hospital_name', (
      select h.name
      from public.hospitals h, mine
      where h.id = mine.hospital_id
      limit 1
    ),
    'active_patients', (
      select count(*) from scoped_patients where is_active
    ),
    'pending_prescriptions', (
      select count(*) from scoped_prescriptions where status = 'pending_verification'
    ),
    'verified_prescriptions', (
      select count(*) from scoped_prescriptions where status = 'verified'
    ),
    'adherence_score', (
      select coalesce(
        round(100.0 * sum(taken_doses) / nullif(sum(scheduled_doses), 0), 1),
        0
      )
      from scoped_adherence
    ),
    'high_risk_alerts', (
      select count(*) from scoped_alerts where severity = 'high'
    ),
    'open_alerts', (
      select count(*) from scoped_alerts
    )
  );
$$;

comment on function public.hospital_admin_summary() is
  'Ringkasan dashboard admin rumah sakit (angka sudah difilter per tenant).';

-- Verifikasi resep + terbitkan jadwal dalam satu transaksi.
create or replace function public.hospital_verify_prescription(
  p_prescription_id uuid,
  p_items jsonb,
  p_admin_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_hospital_id uuid;
  v_item jsonb;
  v_position int := 0;
  v_uid text := app.current_uid();
  v_duration int;
begin
  select p.hospital_id into v_hospital_id
  from public.prescriptions p
  where p.id = p_prescription_id;

  if v_hospital_id is null then
    raise exception 'Resep tidak ditemukan' using errcode = 'P0002';
  end if;

  if not app.has_role('super_admin')
     and v_hospital_id is distinct from app.current_hospital_id() then
    raise exception 'Anda tidak berhak memverifikasi resep rumah sakit lain'
      using errcode = '42501';
  end if;

  if p_items is null
     or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'Minimal satu obat harus diisi' using errcode = '22023';
  end if;

  delete from public.prescription_items
  where prescription_id = p_prescription_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    insert into public.prescription_items (
      prescription_id,
      position,
      medication_name,
      dose,
      frequency_per_day,
      duration_days,
      special_instructions
    )
    values (
      p_prescription_id,
      v_position,
      coalesce(nullif(trim(v_item ->> 'medication_name'), ''), 'Tanpa nama'),
      coalesce(v_item ->> 'dose', ''),
      greatest(coalesce((v_item ->> 'frequency_per_day')::int, 1), 1),
      greatest(coalesce((v_item ->> 'duration_days')::int, 1), 1),
      coalesce(v_item ->> 'special_instructions', '')
    );
    v_position := v_position + 1;
  end loop;

  select max(duration_days) into v_duration
  from public.prescription_items
  where prescription_id = p_prescription_id;

  update public.prescriptions
  set status = 'verified',
      admin_note = coalesce(nullif(trim(p_admin_note), ''), admin_note),
      verified_by = v_uid,
      verified_at = now(),
      scheduled_start = current_date,
      scheduled_end = current_date + coalesce(v_duration, 1),
      updated_at = now()
  where id = p_prescription_id;

  return jsonb_build_object(
    'prescription_id', p_prescription_id,
    'status', 'verified',
    'verified_at', now()
  );
end;
$$;

-- Minta klarifikasi ke dokter tanpa mengubah item resep.
create or replace function public.hospital_request_clarification(
  p_prescription_id uuid,
  p_message text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_updated int;
begin
  if p_message is null or length(trim(p_message)) = 0 then
    raise exception 'Pesan klarifikasi wajib diisi' using errcode = '22023';
  end if;

  update public.prescriptions p
  set status = 'needs_clarification',
      admin_note = trim(p_message),
      verified_by = null,
      verified_at = null,
      updated_at = now()
  where p.id = p_prescription_id
    and (
      app.has_role('super_admin')
      or p.hospital_id = app.current_hospital_id()
    );

  get diagnostics v_updated = row_count;

  if v_updated = 0 then
    raise exception 'Resep tidak ditemukan atau bukan milik rumah sakit Anda'
      using errcode = '42501';
  end if;

  return jsonb_build_object(
    'prescription_id', p_prescription_id,
    'status', 'needs_clarification'
  );
end;
$$;

-- Catat tindak lanjut admin; opsional sekaligus menutup laporan pasien.
create or replace function public.hospital_record_follow_up(
  p_patient_id uuid,
  p_action text,
  p_note text default '',
  p_report_id uuid default null,
  p_prescription_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_hospital_id uuid;
  v_follow_up_id uuid;
begin
  select hp.hospital_id into v_hospital_id
  from public.hospital_patients hp
  where hp.id = p_patient_id;

  if v_hospital_id is null then
    raise exception 'Pasien tidak ditemukan' using errcode = 'P0002';
  end if;

  if not app.has_role('super_admin')
     and v_hospital_id is distinct from app.current_hospital_id() then
    raise exception 'Anda tidak berhak mencatat tindak lanjut rumah sakit lain'
      using errcode = '42501';
  end if;

  insert into public.admin_follow_ups (
    hospital_id,
    hospital_patient_id,
    prescription_id,
    patient_report_id,
    action,
    note,
    created_by
  )
  values (
    v_hospital_id,
    p_patient_id,
    p_prescription_id,
    p_report_id,
    coalesce(nullif(trim(p_action), ''), 'Tindak lanjut'),
    coalesce(p_note, ''),
    app.current_uid()
  )
  returning id into v_follow_up_id;

  if p_report_id is not null then
    update public.patient_reports
    set status = 'resolved',
        resolved_at = now(),
        resolved_by = app.current_uid()
    where id = p_report_id
      and hospital_patient_id = p_patient_id;
  end if;

  return v_follow_up_id;
end;
$$;

grant execute on function public.hospital_admin_summary() to authenticated;
grant execute on function public.hospital_verify_prescription(uuid, jsonb, text) to authenticated;
grant execute on function public.hospital_request_clarification(uuid, text) to authenticated;
grant execute on function public.hospital_record_follow_up(uuid, text, text, uuid, uuid) to authenticated;

-- =============================================================================
-- 7. Row Level Security
--
-- Semua policy memakai role `authenticated` (JWT Firebase yang valid) dan
-- membatasi baris dengan app.current_hospital_id(). Anon tidak diberi akses.
-- =============================================================================
alter table public.hospitals             enable row level security;
alter table public.user_roles            enable row level security;
alter table public.hospital_patients     enable row level security;
alter table public.prescriptions         enable row level security;
alter table public.prescription_items    enable row level security;
alter table public.medication_adherence  enable row level security;
alter table public.patient_reports       enable row level security;
alter table public.admin_follow_ups      enable row level security;

-- hospitals: admin hanya melihat rumah sakitnya sendiri.
drop policy if exists hospitals_read_scoped on public.hospitals;
create policy hospitals_read_scoped on public.hospitals
  for select to authenticated
  using (
    id = app.current_hospital_id()
    or app.has_role('super_admin')
  );

-- user_roles: pengguna boleh membaca role miliknya sendiri; admin boleh
-- membaca role staf di rumah sakitnya.
drop policy if exists user_roles_read_scoped on public.user_roles;
create policy user_roles_read_scoped on public.user_roles
  for select to authenticated
  using (
    user_id = app.current_uid()
    or app.has_role('super_admin')
    or (app.is_hospital_admin() and hospital_id = app.current_hospital_id())
  );

-- Tabel operasional: CRUD penuh, tetapi hanya untuk baris milik rumah sakit
-- si admin.
drop policy if exists hospital_patients_scoped on public.hospital_patients;
create policy hospital_patients_scoped on public.hospital_patients
  for all to authenticated
  using (
    hospital_id = app.current_hospital_id()
    or app.has_role('super_admin')
  )
  with check (
    hospital_id = app.current_hospital_id()
    or app.has_role('super_admin')
  );

drop policy if exists prescriptions_scoped on public.prescriptions;
create policy prescriptions_scoped on public.prescriptions
  for all to authenticated
  using (
    hospital_id = app.current_hospital_id()
    or app.has_role('super_admin')
  )
  with check (
    hospital_id = app.current_hospital_id()
    or app.has_role('super_admin')
  );

-- prescription_items tidak menyimpan hospital_id; scope lewat parent resep.
drop policy if exists prescription_items_scoped on public.prescription_items;
create policy prescription_items_scoped on public.prescription_items
  for all to authenticated
  using (
    exists (
      select 1
      from public.prescriptions p
      where p.id = prescription_items.prescription_id
        and (
          p.hospital_id = app.current_hospital_id()
          or app.has_role('super_admin')
        )
    )
  )
  with check (
    exists (
      select 1
      from public.prescriptions p
      where p.id = prescription_items.prescription_id
        and (
          p.hospital_id = app.current_hospital_id()
          or app.has_role('super_admin')
        )
    )
  );

drop policy if exists medication_adherence_scoped on public.medication_adherence;
create policy medication_adherence_scoped on public.medication_adherence
  for all to authenticated
  using (
    hospital_id = app.current_hospital_id()
    or app.has_role('super_admin')
  )
  with check (
    hospital_id = app.current_hospital_id()
    or app.has_role('super_admin')
  );

drop policy if exists patient_reports_scoped on public.patient_reports;
create policy patient_reports_scoped on public.patient_reports
  for all to authenticated
  using (
    hospital_id = app.current_hospital_id()
    or app.has_role('super_admin')
  )
  with check (
    hospital_id = app.current_hospital_id()
    or app.has_role('super_admin')
  );

drop policy if exists admin_follow_ups_scoped on public.admin_follow_ups;
create policy admin_follow_ups_scoped on public.admin_follow_ups
  for all to authenticated
  using (
    hospital_id = app.current_hospital_id()
    or app.has_role('super_admin')
  )
  with check (
    hospital_id = app.current_hospital_id()
    or app.has_role('super_admin')
  );

-- Hak akses tabel & view untuk client Supabase (setelah lolos RLS).
grant select on public.hospitals to authenticated;
grant select on public.user_roles to authenticated;

grant select, insert, update, delete
  on public.hospital_patients,
     public.prescriptions,
     public.prescription_items,
     public.medication_adherence,
     public.patient_reports,
     public.admin_follow_ups
  to authenticated;

grant select on public.hospital_patient_monitoring to authenticated;
grant select on public.hospital_alerts to authenticated;

-- =============================================================================
-- 8. Realtime
--
-- Dashboard memantau dosis terlewat dan keluhan pasien secara langsung.
-- =============================================================================
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.medication_adherence;
    exception when duplicate_object then null;
    end;

    begin
      alter publication supabase_realtime add table public.patient_reports;
    exception when duplicate_object then null;
    end;

    begin
      alter publication supabase_realtime add table public.prescriptions;
    exception when duplicate_object then null;
    end;

    begin
      alter publication supabase_realtime add table public.hospital_patients;
    exception when duplicate_object then null;
    end;
  end if;
end;
$$;

-- =============================================================================
-- 9. Seed data demo (idempoten)
-- =============================================================================

-- Rumah sakit ----------------------------------------------------------------
insert into public.hospitals (id, name, code, city, address, phone, email, logo_color)
values
  ('a1000000-0000-4000-8000-000000000001', 'RS Sehat Sentosa', 'RS-SS-001',
   'Jakarta Selatan', 'Jl. Kesehatan Raya No. 12', '021-5550101',
   'admin@rssehatsentosa.id', x'FF0E7490'::bigint),
  ('a1000000-0000-4000-8000-000000000002', 'RS Mitra Bunda', 'RS-MB-002',
   'Bandung', 'Jl. Merdeka No. 88', '022-5550202',
   'admin@mitrabunda.id', x'FF115E59'::bigint)
on conflict (id) do nothing;

-- RBAC admin ---------------------------------------------------------------
-- GANTI 'GANTI_DENGAN_FIREBASE_UID_ADMIN' dengan UID admin dari
-- Firebase Console → Authentication → Users sebelum menjalankan file ini.
insert into public.user_roles (user_id, role, hospital_id)
values (
  'GANTI_DENGAN_FIREBASE_UID_ADMIN',
  'hospital_admin',
  'a1000000-0000-4000-8000-000000000001'
)
on conflict (user_id, role) do update
  set hospital_id = excluded.hospital_id,
      is_active = true,
      updated_at = now();

-- Contoh pemetaan akun demo lain (opsional, hapus bila tidak dipakai).
insert into public.user_roles (user_id, role, hospital_id)
values
  ('user-patient', 'patient', 'a1000000-0000-4000-8000-000000000001'),
  ('user-doctor', 'doctor', 'a1000000-0000-4000-8000-000000000001')
on conflict (user_id, role) do nothing;

-- Pasien pasca rawat inap ---------------------------------------------------
insert into public.hospital_patients (
  id, hospital_id, patient_user_id, full_name, medical_record_no, diagnosis,
  discharge_date, attending_doctor_user_id, attending_doctor_name, risk_level, is_active
)
values
  ('a2000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001',
   'user-patient', 'Budi Santoso', 'RM-2024-0117', 'Gagal jantung kongestif (NYHA II)',
   current_date - 12, 'user-doctor', 'dr. Rifki Al Sauqy, Sp.JP', 'high', true),
  ('a2000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001',
   'demo-patient-2', 'Siti Aminah', 'RM-2024-0118', 'Diabetes melitus tipe 2 dengan ulkus kaki',
   current_date - 8, 'demo-doctor-2', 'dr. Daffa Afdhillah, Sp.PD', 'medium', true),
  ('a2000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000001',
   'demo-patient-3', 'Rina Wulandari', 'RM-2024-0119', 'Pneumonia komunitas (resolusi)',
   current_date - 5, 'demo-doctor-3', 'dr. Farhan Prasetyo', 'low', true),
  ('a2000000-0000-4000-8000-000000000004', 'a1000000-0000-4000-8000-000000000001',
   'demo-patient-4', 'Ahmad Hidayat', 'RM-2024-0120', 'Stroke iskemik ringan',
   current_date - 20, 'demo-doctor-4', 'dr. Cristian, Sp.KJ', 'low', true),
  ('a2000000-0000-4000-8000-000000000005', 'a1000000-0000-4000-8000-000000000001',
   'demo-patient-5', 'Dewi Lestari', 'RM-2024-0121', 'Hipertensi dengan komplikasi ginjal',
   current_date - 3, 'demo-doctor-2', 'dr. Daffa Afdhillah, Sp.PD', 'medium', true),
  ('a2000000-0000-4000-8000-000000000006', 'a1000000-0000-4000-8000-000000000002',
   'demo-patient-6', 'Joko Purnomo', 'RM-2024-0122', 'Post operasi apendektomi',
   current_date - 4, 'demo-doctor-5', 'dr. Arkaan Ramdhan', 'low', true)
on conflict (id) do nothing;

-- Resep ---------------------------------------------------------------------
insert into public.prescriptions (
  id, hospital_id, hospital_patient_id, doctor_user_id, doctor_name, status,
  doctor_note, admin_note, verified_by, verified_at, scheduled_start, scheduled_end, created_at
)
values
  ('a3000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000001', 'user-doctor', 'dr. Rifki Al Sauqy, Sp.JP',
   'pending_verification',
   'Kontrol ulang 2 minggu, pantau tekanan darah harian.', '', null, null, null, null,
   now() - interval '2 hours'),
  ('a3000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000002', 'demo-doctor-2', 'dr. Daffa Afdhillah, Sp.PD',
   'pending_verification',
   'Periksa gula darah puasa setiap pagi.', '', null, null, null, null,
   now() - interval '5 hours'),
  ('a3000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000005', 'demo-doctor-2', 'dr. Daffa Afdhillah, Sp.PD',
   'pending_verification',
   'Batasi cairan 1.5 L per hari.', '', null, null, null, null,
   now() - interval '1 day'),
  ('a3000000-0000-4000-8000-000000000004', 'a1000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000003', 'demo-doctor-3', 'dr. Farhan Prasetyo',
   'verified',
   'Lanjutkan antibiotik sampai habis.', 'Jadwal diverifikasi oleh admin.',
   'GANTI_DENGAN_FIREBASE_UID_ADMIN', now() - interval '2 days',
   current_date - 2, current_date + 3, now() - interval '3 days'),
  ('a3000000-0000-4000-8000-000000000005', 'a1000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000004', 'demo-doctor-4', 'dr. Cristian, Sp.KJ',
   'needs_clarification',
   'Antiplatelet dosis rendah.', 'Mohon konfirmasi apakah perlu tambahan gastroprotektor.',
   null, null, null, null, now() - interval '4 days')
on conflict (id) do nothing;

-- Item resep (hanya bila resep belum punya item) -----------------------------
insert into public.prescription_items (
  prescription_id, position, medication_name, dose,
  frequency_per_day, duration_days, special_instructions
)
select
  v.prescription_id, v.position, v.medication_name, v.dose,
  v.frequency_per_day, v.duration_days, v.special_instructions
from (values
  ('a3000000-0000-4000-8000-000000000001'::uuid, 0, 'Furosemide', '40 mg', 1, 30, 'Pagi hari setelah makan'),
  ('a3000000-0000-4000-8000-000000000001'::uuid, 1, 'Spironolakton', '25 mg', 1, 30, 'Setelah makan pagi'),
  ('a3000000-0000-4000-8000-000000000001'::uuid, 2, 'Bisoprolol', '5 mg', 1, 30, 'Malam hari sebelum tidur'),
  ('a3000000-0000-4000-8000-000000000002'::uuid, 0, 'Metformin', '500 mg', 2, 30, 'Sesudah makan pagi dan malam'),
  ('a3000000-0000-4000-8000-000000000002'::uuid, 1, 'Glibenklamid', '5 mg', 1, 30, 'Pagi hari sebelum makan'),
  ('a3000000-0000-4000-8000-000000000003'::uuid, 0, 'Amlodipine', '10 mg', 1, 14, 'Malam hari'),
  ('a3000000-0000-4000-8000-000000000003'::uuid, 1, 'Ramipril', '5 mg', 1, 14, 'Pagi hari'),
  ('a3000000-0000-4000-8000-000000000004'::uuid, 0, 'Amoxicillin', '500 mg', 3, 5, 'Sebelum makan'),
  ('a3000000-0000-4000-8000-000000000004'::uuid, 1, 'Paracetamol', '500 mg', 3, 5, 'Hanya bila demam'),
  ('a3000000-0000-4000-8000-000000000005'::uuid, 0, 'Clopidogrel', '75 mg', 1, 30, 'Setelah makan pagi')
) as v(prescription_id, position, medication_name, dose, frequency_per_day, duration_days, special_instructions)
where not exists (
  select 1
  from public.prescription_items i
  where i.prescription_id = v.prescription_id
);

-- Kepatuhan 7 hari terakhir -------------------------------------------------
insert into public.medication_adherence (
  hospital_id, hospital_patient_id, prescription_id, taken_date,
  scheduled_doses, taken_doses, note
)
values
  -- Budi Santoso (risiko tinggi, kepatuhan rendah)
  ('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001',
   'a3000000-0000-4000-8000-000000000001', current_date, 3, 1, 'Dua dosis terlewat'),
  ('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001',
   'a3000000-0000-4000-8000-000000000001', current_date - 1, 3, 1, ''),
  ('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001',
   'a3000000-0000-4000-8000-000000000001', current_date - 2, 3, 2, ''),
  ('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001',
   'a3000000-0000-4000-8000-000000000001', current_date - 3, 3, 1, ''),
  -- Siti Aminah
  ('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000002',
   'a3000000-0000-4000-8000-000000000002', current_date, 2, 2, ''),
  ('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000002',
   'a3000000-0000-4000-8000-000000000002', current_date - 1, 2, 1, ''),
  ('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000002',
   'a3000000-0000-4000-8000-000000000002', current_date - 2, 2, 2, ''),
  ('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000002',
   'a3000000-0000-4000-8000-000000000002', current_date - 3, 2, 1, ''),
  -- Rina Wulandari
  ('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000003',
   'a3000000-0000-4000-8000-000000000004', current_date, 3, 3, ''),
  ('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000003',
   'a3000000-0000-4000-8000-000000000004', current_date - 1, 3, 3, ''),
  ('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000003',
   'a3000000-0000-4000-8000-000000000004', current_date - 2, 3, 3, ''),
  -- Ahmad Hidayat
  ('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000004',
   'a3000000-0000-4000-8000-000000000005', current_date, 1, 1, ''),
  ('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000004',
   'a3000000-0000-4000-8000-000000000005', current_date - 1, 1, 1, ''),
  -- Dewi Lestari
  ('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000005',
   'a3000000-0000-4000-8000-000000000003', current_date, 2, 1, 'Dosis malam terlewat'),
  ('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000005',
   'a3000000-0000-4000-8000-000000000003', current_date - 1, 2, 2, ''),
  ('a1000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000005',
   'a3000000-0000-4000-8000-000000000003', current_date - 2, 2, 1, '')
on conflict (hospital_id, hospital_patient_id, taken_date) do nothing;

-- Laporan pasien ------------------------------------------------------------
insert into public.patient_reports (
  id, hospital_id, hospital_patient_id, report_type, message, severity, status, created_at
)
values
  ('a4000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000001', 'symptom',
   'Sesak napas memberat saat berbaring, kaki bengkak.', 'high', 'open',
   now() - interval '40 minutes'),
  ('a4000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000005', 'missed_dose',
   'Lupa meminum obat malam, apakah boleh diminum sekarang?', 'medium', 'open',
   now() - interval '3 hours'),
  ('a4000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000003', 'symptom',
   'Batuk berdahak masih ada tetapi membaik.', 'low', 'resolved',
   now() - interval '2 days')
on conflict (id) do nothing;

-- Contoh tindak lanjut ------------------------------------------------------
insert into public.admin_follow_ups (
  id, hospital_id, hospital_patient_id, patient_report_id, action, note, created_by, created_at
)
values
  ('a5000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000003', 'a4000000-0000-4000-8000-000000000003',
   'Telepon pasien', 'Pasien diingatkan kontrol rawat jalan minggu depan.',
   'GANTI_DENGAN_FIREBASE_UID_ADMIN', now() - interval '1 day')
on conflict (id) do nothing;

-- =============================================================================
-- 10. Verifikasi cepat
-- =============================================================================
-- Setelah mengganti UID admin, jalankan query berikut untuk memastikan RLS
-- dan helper berfungsi (contoh UID 'user-patient' dianggap bukan admin):
--
--   select app.current_uid();            -- NULL di SQL Editor (tanpa JWT)
--   select app.current_hospital_id();    -- NULL di SQL Editor
--   select * from public.hospital_alerts;
--
-- Uji dari aplikasi: login sebagai akun yang terdaftar di user_roles dengan
-- role 'hospital_admin', lalu buka /hospital-admin/dashboard.
