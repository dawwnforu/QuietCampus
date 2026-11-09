-- The database receives encrypted envelopes only. It never receives vault keys.
create table public.account_deletions (
  owner_id uuid primary key references auth.users(id) on delete cascade
);
alter table public.account_deletions enable row level security;
revoke all on public.account_deletions from anon, authenticated;

create function public.account_active() returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (select 1 from auth.users where id = auth.uid()) and not exists (
    select 1 from public.account_deletions where owner_id = auth.uid()
  );
$$;
revoke all on function public.account_active() from public, anon;
grant execute on function public.account_active() to authenticated;

create table public.vaults (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  envelope jsonb not null check (jsonb_typeof(envelope) = 'object' and octet_length(envelope::text) < 16384),
  revision bigint not null default 1 check (revision > 0)
);
alter table public.vaults enable row level security;
revoke all on public.vaults from anon, authenticated;
grant select on public.vaults to authenticated;
create policy own_vault on public.vaults for select to authenticated
using (owner_id = (select auth.uid()) and (select public.account_active()));

create table public.records (
  owner_id uuid not null references auth.users(id) on delete cascade,
  id uuid not null,
  revision bigint not null check (revision > 0),
  ciphertext jsonb not null check (jsonb_typeof(ciphertext) = 'object' and octet_length(ciphertext::text) <= 2097152),
  deleted boolean not null default false,
  primary key (owner_id, id)
);
alter table public.records enable row level security;
revoke all on public.records from anon, authenticated;
grant select on public.records to authenticated;
create policy own_records on public.records for select to authenticated
using (owner_id = (select auth.uid()) and (select public.account_active()));

create table public.record_mutations (
  owner_id uuid not null references auth.users(id) on delete cascade,
  id uuid not null,
  record_id uuid not null,
  response jsonb not null,
  primary key (owner_id, id)
);
alter table public.record_mutations enable row level security;
revoke all on public.record_mutations from anon, authenticated;

create function public.put_vault(p_envelope jsonb, p_base_revision bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare result public.vaults;
begin
  if not public.account_active() then raise insufficient_privilege; end if;
  -- The per-account lock also serializes account deletion and initial creation.
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));
  if not public.account_active() then raise insufficient_privilege; end if;
  if p_base_revision = 0 then
    insert into public.vaults(owner_id, envelope) values(auth.uid(), p_envelope)
    on conflict do nothing returning * into result;
  else
    update public.vaults set envelope = p_envelope, revision = revision + 1
    where owner_id = auth.uid() and revision = p_base_revision returning * into result;
  end if;
  if result.owner_id is null then raise exception 'vault_conflict' using errcode = '40001'; end if;
  return to_jsonb(result);
end;
$$;

create function public.write_record(p_id uuid, p_base_revision bigint,
  p_mutation_id uuid, p_ciphertext jsonb, p_deleted boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare result public.records; previous public.record_mutations; response jsonb;
begin
  if not public.account_active() then raise insufficient_privilege; end if;
  if p_id is null or p_mutation_id is null or p_base_revision < 0 or p_base_revision is null
    or p_deleted is null then raise invalid_parameter_value; end if;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));
  if not public.account_active() then raise insufficient_privilege; end if;
  select * into previous from public.record_mutations where owner_id = auth.uid() and id = p_mutation_id;
  if found then
    if previous.record_id <> p_id then raise invalid_parameter_value; end if;
    return previous.response;
  end if;
  if p_base_revision = 0 then
    insert into public.records(owner_id, id, revision, ciphertext, deleted)
    values(auth.uid(), p_id, 1, p_ciphertext, p_deleted)
    on conflict do nothing returning * into result;
  else
    update public.records set revision = revision + 1, ciphertext = p_ciphertext, deleted = p_deleted
    where owner_id = auth.uid() and id = p_id and revision = p_base_revision returning * into result;
  end if;
  if result.id is null then
    select * into result from public.records where owner_id = auth.uid() and id = p_id;
    return jsonb_build_object('conflict', true, 'record', case when result.id is null then null else to_jsonb(result) end);
  end if;
  response := jsonb_build_object('conflict', false, 'record', to_jsonb(result) - 'ciphertext');
  insert into public.record_mutations values(auth.uid(), p_mutation_id, p_id, response);
  return response;
end;
$$;

create function public.begin_account_deletion() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise insufficient_privilege; end if;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text, 0));
  insert into public.account_deletions values(auth.uid()) on conflict do nothing;
end;
$$;
revoke all on function public.put_vault(jsonb,bigint), public.write_record(uuid,bigint,uuid,jsonb,boolean),
  public.begin_account_deletion() from public, anon;
grant execute on function public.put_vault(jsonb,bigint), public.write_record(uuid,bigint,uuid,jsonb,boolean),
  public.begin_account_deletion() to authenticated;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('vault-attachments', 'vault-attachments', false, 22020096, array['application/octet-stream']);
create policy own_attachment_read on storage.objects for select to authenticated
using (bucket_id = 'vault-attachments' and (storage.foldername(name))[1] = (select auth.uid())::text and array_length(string_to_array(name, '/'),1) = 2 and (select public.account_active()));
create policy own_attachment_insert on storage.objects for insert to authenticated
with check (bucket_id = 'vault-attachments' and (storage.foldername(name))[1] = (select auth.uid())::text and array_length(string_to_array(name, '/'),1) = 2 and (select public.account_active()));
create policy own_attachment_update on storage.objects for update to authenticated
using (bucket_id = 'vault-attachments' and (storage.foldername(name))[1] = (select auth.uid())::text and array_length(string_to_array(name, '/'),1) = 2 and (select public.account_active()))
with check (bucket_id = 'vault-attachments' and (storage.foldername(name))[1] = (select auth.uid())::text and array_length(string_to_array(name, '/'),1) = 2 and (select public.account_active()));

alter table public.records replica identity full;
do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.records;
  end if;
end $$;
