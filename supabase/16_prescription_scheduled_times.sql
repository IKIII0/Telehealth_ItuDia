-- =============================================================================
-- Telehealth — Jadwal waktu minum obat pada item resep
--
-- Menambahkan kolom `scheduled_times` (TEXT[]) pada tabel rencana obat yang
-- dipakai saat admin menekan "Verifikasi & Terbitkan Jadwal", yaitu
-- public.prescription_items (tidak ada tabel medication_plans terpisah di
-- skema ini; chaque baris prescription_items = satu rencana obat).
--
-- Jalankan setelah:
--   02_profiles_auth_sync.sql   (schema app / set_updated_at)
--   03_hospital_admin_rbac.sql  (hospital_verify_prescription)
--   09_doctor_module.sql        (app.write_prescription_items)
--
-- TANPA RLS: tidak ada policy baru. Script hanya menambah kolom + memperbarui
-- dua fungsi yang sudah ada (create or replace).
-- =============================================================================

begin;

-- =============================================================================
-- 1. Kolom jadwal minum obat
-- =============================================================================
alter table public.prescription_items
  add column if not exists scheduled_times text[] not null default '{}'::text[];

comment on column public.prescription_items.scheduled_times is
  'Jam minum obat, mis. {07:00,15:00,23:00}. Jumlahnya mengikuti frequency_per_day.';

-- =============================================================================
-- 2. Helper: jam default proporsional sesuai frekuensi/hari
--    (harus sama dengan defaultScheduledTimes() di UI)
-- =============================================================================
create or replace function app.default_scheduled_times(p_frequency int)
returns text[]
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  v_freq int := least(greatest(coalesce(p_frequency, 1), 1), 12);
  v_step int;
begin
  if v_freq = 1 then
    return array['08:00'];
  end if;
  if v_freq = 2 then
    return array['07:00', '19:00'];
  end if;
  if v_freq = 3 then
    return array['07:00', '15:00', '23:00'];
  end if;

  -- >= 4: sebar merata mulai 07:00, interval 24/jumlah jam.
  v_step := 1440 / v_freq;
  return (
    select array_agg(
             lpad((((420 + g.i * v_step) % 1440) / 60)::text, 2, '0')
             || ':' ||
             lpad((((420 + g.i * v_step) % 1440) % 60)::text, 2, '0')
             order by g.i
           )
    from generate_series(0, v_freq - 1) as g(i)
  );
end;
$$;

revoke all on function app.default_scheduled_times(int)
  from public, anon, authenticated;

-- =============================================================================
-- 3. app.write_prescription_items — simpan scheduled_times (alur dokter)
-- =============================================================================
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
  v_times text[];
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
    v_times := null;

    if jsonb_typeof(v_item) = 'string' then
      v_name  := nullif(trim(v_item #>> '{}'), '');
      v_dose  := '';
      v_freq  := 1;
      v_dur   := 1;
      v_instr := '';
      v_times := app.default_scheduled_times(v_freq);
    else
      v_name  := nullif(trim(v_item ->> 'medication_name'), '');
      v_dose  := coalesce(v_item ->> 'dose', '');
      v_freq  := least(greatest(coalesce((v_item ->> 'frequency_per_day')::int, 1), 1), 12);
      v_dur   := least(greatest(coalesce((v_item ->> 'duration_days')::int, 1), 1), 365);
      v_instr := coalesce(v_item ->> 'special_instructions', '');

      if jsonb_typeof(v_item -> 'scheduled_times') = 'array' then
        select array_agg(trim(value) order by ord)
          into v_times
        from jsonb_array_elements_text(v_item -> 'scheduled_times')
             with ordinality as t(value, ord)
        where trim(value) <> '';
      end if;
      if v_times is null or cardinality(v_times) = 0 then
        v_times := app.default_scheduled_times(v_freq);
      end if;
    end if;

    if v_name is null then
      raise exception 'Nama obat tidak boleh kosong' using errcode = '22023';
    end if;

    insert into public.prescription_items (
      prescription_id, position, medication_name, dose,
      frequency_per_day, duration_days, special_instructions, scheduled_times
    )
    values (
      p_prescription_id, v_pos, v_name, v_dose,
      v_freq, v_dur, v_instr, coalesce(v_times, '{}'::text[])
    );
    v_pos := v_pos + 1;
  end loop;
end;
$$;

revoke all on function app.write_prescription_items(uuid, jsonb)
  from public, anon, authenticated;

-- =============================================================================
-- 4. hospital_verify_prescription — simpan scheduled_times (alur admin)
-- =============================================================================
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
  v_item        jsonb;
  v_position    int := 0;
  v_uid         text := app.current_uid();
  v_duration    int;
  v_freq        int;
  v_times       text[];
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
    v_freq := greatest(coalesce((v_item ->> 'frequency_per_day')::int, 1), 1);
    v_times := null;

    if jsonb_typeof(v_item -> 'scheduled_times') = 'array' then
      select array_agg(trim(value) order by ord)
        into v_times
      from jsonb_array_elements_text(v_item -> 'scheduled_times')
           with ordinality as t(value, ord)
      where trim(value) <> '';
    end if;
    if v_times is null or cardinality(v_times) = 0 then
      v_times := app.default_scheduled_times(v_freq);
    end if;

    insert into public.prescription_items (
      prescription_id,
      position,
      medication_name,
      dose,
      frequency_per_day,
      duration_days,
      special_instructions,
      scheduled_times
    )
    values (
      p_prescription_id,
      v_position,
      coalesce(nullif(trim(v_item ->> 'medication_name'), ''), 'Tanpa nama'),
      coalesce(v_item ->> 'dose', ''),
      v_freq,
      greatest(coalesce((v_item ->> 'duration_days')::int, 1), 1),
      coalesce(v_item ->> 'special_instructions', ''),
      v_times
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

-- Pertahankan hak akses yang sudah ada (authenticated; anon untuk kompatibilitas).
grant execute on function public.hospital_verify_prescription(uuid, jsonb, text)
  to authenticated, anon;

commit;

-- =============================================================================
-- Verifikasi cepat
-- =============================================================================
select
  medication_name,
  frequency_per_day,
  scheduled_times
from public.prescription_items
order by prescription_id, position
limit 20;
