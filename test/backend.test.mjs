import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

const a = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const b = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const id = '11111111-1111-4111-8111-111111111111';
const m1 = '22222222-2222-4222-8222-222222222222';
const m2 = '33333333-3333-4333-8333-333333333333';
const m3 = '44444444-4444-4444-8444-444444444444';
const envelope = JSON.stringify({ v: 1, nonce: 'cipher-nonce', box: 'cipher-only' });

test('Postgres: account isolation, CAS, retries, tombstones, deletion and daily-task permissions', async () => {
  const db = new PGlite();
  try {
    await db.exec(`
      CREATE ROLE anon; CREATE ROLE authenticated;
      CREATE SCHEMA auth; CREATE SCHEMA storage;
      CREATE TABLE auth.users(id uuid PRIMARY KEY);
      CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
        $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
      GRANT USAGE ON SCHEMA auth, storage TO anon, authenticated;
      CREATE TABLE storage.buckets(id text PRIMARY KEY, name text, public boolean,
        file_size_limit bigint, allowed_mime_types text[]);
      CREATE TABLE storage.objects(id uuid DEFAULT gen_random_uuid(), bucket_id text,
        name text, PRIMARY KEY(bucket_id, name));
      ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
      GRANT SELECT,INSERT,UPDATE,DELETE ON storage.objects TO authenticated;
      CREATE FUNCTION storage.foldername(text) RETURNS text[] LANGUAGE sql IMMUTABLE AS
        $$ SELECT string_to_array($1, '/') $$;
      INSERT INTO auth.users VALUES('${a}'),('${b}');
    `);
    await db.exec(await readFile(new URL('../supabase/migrations/202610200001_private_vault.sql', import.meta.url), 'utf8'));
    await db.exec(await readFile(new URL('../supabase/migrations/202610200002_daily_tasks.sql', import.meta.url), 'utf8'));
    const login = async (uid, role = 'authenticated') => {
      await db.exec(`RESET ROLE; SET ROLE ${role};`);
      await db.query("SELECT set_config('request.jwt.claim.sub', $1, false)", [uid]);
    };
    const write = async (revision, mutation, deleted = false) => (
      await db.query('SELECT public.write_record($1,$2,$3,$4::jsonb,$5) AS r',
        [id, revision, mutation, envelope, deleted])).rows[0].r;
    // Synthetic editorial fixtures; never seeded into the application database.
    await db.exec(`INSERT INTO public.daily_tasks(task_date,title,instructions,published)
      VALUES ('2026-10-20','Published fixture','Plain text instructions',true);
      INSERT INTO public.daily_tasks(task_date,title,instructions)
      VALUES ('2026-10-21','Draft fixture','Not published');`);
    await assert.rejects(db.exec("INSERT INTO public.daily_tasks(task_date,title,instructions) VALUES ('2026-10-22','  ','x')"), /check constraint/);
    await assert.rejects(db.exec("INSERT INTO public.daily_tasks(task_date,title,instructions,estimated_minutes) VALUES ('2026-10-22','Title','x',0)"), /check constraint/);
    await assert.rejects(db.exec("INSERT INTO public.daily_tasks(task_date,title,instructions) VALUES ('2026-10-20','Duplicate','x')"), /duplicate key/);
    await login(a, 'anon');
    await assert.rejects(db.query('SELECT * FROM public.daily_tasks'), /permission denied/);
    await login(a);
    const tasks = (await db.query('SELECT task_date::text,title FROM public.daily_tasks ORDER BY task_date')).rows;
    assert.deepEqual(tasks, [{task_date:'2026-10-20',title:'Published fixture'}]);
    assert.equal((await db.query("SELECT * FROM public.daily_tasks WHERE task_date='2026-10-21'")).rows.length,0);
    await assert.rejects(db.exec("INSERT INTO public.daily_tasks(task_date,title,instructions) VALUES ('2026-10-22','Client write','x')"), /permission denied/);
    await assert.rejects(db.exec('UPDATE public.daily_tasks SET published=true'), /permission denied/);
    await assert.rejects(db.exec('DELETE FROM public.daily_tasks'), /permission denied/);
    await login(a);
    await db.query('SELECT public.put_vault($1::jsonb,0)', [envelope]);
    assert.equal((await write(0, m1)).record.revision, 1);
    assert.equal((await write(0, m1)).record.revision, 1, 'retry must not duplicate a mutation');
    assert.equal((await write(0, m2)).conflict, true, 'stale device must see conflict');
    assert.equal((await write(1, m2, true)).record.revision, 2);
    assert.equal((await write(1, m3)).record.deleted, true, 'offline edit must not revive a tombstone');
    await db.query("INSERT INTO storage.objects(bucket_id,name) VALUES ('vault-attachments',$1)", [`${a}/proof.bin`]);
    await assert.rejects(db.query("INSERT INTO storage.objects(bucket_id,name) VALUES ('vault-attachments',$1)", [`${a}/nested/proof.bin`]), /row-level security/);
    await assert.rejects(db.query("UPDATE public.records SET revision=99"), /permission denied/);
    await assert.rejects(db.query('SELECT * FROM public.record_mutations'), /permission denied/);
    await login(b);
    assert.equal((await db.query('SELECT * FROM public.records')).rows.length, 0);
    assert.equal((await db.query('SELECT * FROM public.vaults')).rows.length, 0);
    assert.equal((await db.query('SELECT * FROM storage.objects')).rows.length, 0);
    await assert.rejects(db.query("INSERT INTO storage.objects(bucket_id,name) VALUES ('vault-attachments',$1)", [`${a}/stolen.bin`]), /row-level security/);
    await db.query('SELECT public.put_vault($1::jsonb,0)', [envelope]);
    assert.equal((await write(0, m1)).record.owner_id, b, 'record IDs and mutation IDs are scoped by account');
    await login(a, 'anon');
    await assert.rejects(db.query('SELECT * FROM public.records'), /permission denied/);
    await assert.rejects(write(2, m3), /permission denied/);
    await login(a);
    await db.query('SELECT public.begin_account_deletion()');
    assert.equal((await db.query('SELECT * FROM public.daily_tasks')).rows.length,0);
    assert.equal((await db.query('SELECT * FROM public.records')).rows.length, 0);
    await assert.rejects(write(2, m3), /insufficient_privilege|insufficient privilege/i);
    await assert.rejects(db.query("INSERT INTO storage.objects(bucket_id,name) VALUES ('vault-attachments',$1)", [`${a}/late.bin`]), /row-level security/);
    await db.exec('RESET ROLE');
    await db.query('DELETE FROM auth.users WHERE id=$1', [a]);
    assert.equal((await db.query('SELECT * FROM public.record_mutations WHERE owner_id=$1', [a])).rows.length, 0);
    await login(a);
    assert.equal((await db.query('SELECT public.account_active() AS active')).rows[0].active, false,
      'an old JWT must stay blocked after its user is deleted');
  } finally { await db.close(); }
});
