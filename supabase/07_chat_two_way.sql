-- =============================================================================
-- Telehealth — Chat dua arah pasien ↔ dokter
--
-- Sebelumnya `chat_messages.is_me` hanya bermakna dari sudut pandang pasien.
-- Untuk percakapan dua arah, arah pesan disimpan eksplisit di kolom `sender`.
--
-- Jalankan setelah 01_medication_doctor_chat.sql.
-- =============================================================================

alter table public.chat_messages
  add column if not exists sender text;

-- Backfill data lama: pesan lama dengan is_me dianggap dari pasien.
update public.chat_messages
   set sender = case when is_me then 'patient' else 'doctor' end
 where sender is null;

alter table public.chat_messages
  alter column sender set default 'patient';

alter table public.chat_messages
  drop constraint if exists chat_messages_sender_check;
alter table public.chat_messages
  add constraint chat_messages_sender_check
  check (sender in ('patient', 'doctor'));

create index if not exists chat_messages_conversation_created_idx
  on public.chat_messages (conversation_id, created_at);

-- Aktifkan Supabase Realtime untuk tabel chat (idempoten).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'chat_messages'
  ) then
    alter publication supabase_realtime add table public.chat_messages;
  end if;
end $$;

-- Verifikasi arah pesan per percakapan.
select conversation_id, sender, count(*) as jumlah
  from public.chat_messages
 group by conversation_id, sender
 order by conversation_id, sender;
