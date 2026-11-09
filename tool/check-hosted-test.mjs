import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import sodium from 'libsodium-wrappers-sumo';
import { decryptBackup } from './decrypt-backup.mjs';

const origin = 'https://eeeeisvdrcvjgmjtobgp.supabase.co';
let stage = 'configuration';
try {
  const config = JSON.parse((await readFile('config.local.json', 'utf8')).replace(/^\uFEFF/, ''));
  assert.equal(new URL(config.SUPABASE_URL).origin, origin);
  const key = config.SUPABASE_PUBLISHABLE_KEY;
  assert.match(key, /^sb_publishable_[\w-]+$/);
  async function request(path, { token, body, bytes, method, upsert } = {}) {
    return fetch(origin + path, {
      method: method ?? (body || bytes ? 'POST' : 'GET'),
      headers: {
        apikey: key,
        ...(token ? { Authorization: 'Bearer ' + token } : {}),
        ...(body ? { 'Content-Type': 'application/json' } : {}),
        ...(bytes ? { 'Content-Type': 'application/octet-stream' } : {}),
        ...(upsert ? { 'x-upsert': 'true' } : {}),
      },
      body: bytes ?? (body ? JSON.stringify(body) : undefined),
      signal: AbortSignal.timeout(15000),
    });
  }
  async function json(path, options) {
    const response = await request(path, options);
    assert.ok(response.ok, 'HTTP ' + response.status);
    return response.json();
  }
  async function login(suffix) {
    const email = process.env['QUIET_QA_EMAIL_' + suffix];
    const password = process.env['QUIET_QA_PASSWORD_' + suffix];
    assert.match(email ?? '', /^quiet-qa-[a-z0-9-]+@example\.com$/);
    assert.ok(password);
    const session = await json('/auth/v1/token?grant_type=password', { body: { email, password } });
    assert.equal(session.user.email, email);
    assert.match(session.user.id, /^[0-9a-f-]{36}$/);
    assert.ok(session.access_token);
    return session;
  }
  stage = 'synthetic sign-in';
  const [a, b] = await Promise.all([login('A'), login('B')]);
  const owner = a.user.id;
  const token = a.access_token;
  assert.notEqual(owner, b.user.id);
  const rows = (table, owner, token) => json('/rest/v1/' + table + '?owner_id=eq.' + owner, { token });
  stage = 'fresh test accounts';
  for (const account of [a, b]) {
    assert.deepEqual(await rows('records', account.user.id, account.access_token), []);
    assert.deepEqual(await rows('vaults', account.user.id, account.access_token), []);
  }
  await sodium.ready;
  const master = sodium.randombytes_buf(32);
  const recovery = sodium.randombytes_buf(32);
  const pass = randomUUID();
  const salt = sodium.randombytes_buf(16);
  const wrapping = sodium.crypto_pwhash(32, pass, salt, 2, 67108864, sodium.crypto_pwhash_ALG_ARGON2ID13);
  const recordKey = sodium.crypto_kdf_derive_from_key(32, 1, 'RECORD01', master);
  const attachmentKey = sodium.crypto_kdf_derive_from_key(32, 1, 'ATTACH01', master);
  const encode = bytes => Buffer.from(bytes).toString('base64');
  function seal(value, key, aad) {
    const nonce = sodium.randombytes_buf(24);
    const box = sodium.crypto_aead_xchacha20poly1305_ietf_encrypt(value, sodium.from_string(aad), null, nonce, key);
    return { v: 1, nonce: encode(nonce), box: encode(box) };
  }
  try {
    const rpc = (name, body) => json('/rest/v1/rpc/' + name, { token, body });
    stage = 'encrypted vault';
    const envelope = {
      v: 1, ops: 2, mem: 67108864, salt: encode(salt),
      pass: seal(master, wrapping, owner + ':vault:pass:1'),
      recovery: seal(master, recovery, owner + ':vault:recovery:1'),
    };
    await rpc('put_vault', { p_envelope: envelope, p_base_revision: 0 });
    stage = 'private attachment';
    const file = randomUUID();
    const original = sodium.from_string('Quiet Campus synthetic attachment');
    const sealed = seal(original, attachmentKey, owner + ':attachment:' + file + ':1');
    const frame = Buffer.concat([Buffer.of(1), Buffer.from(sealed.nonce, 'base64'), Buffer.from(sealed.box, 'base64')]);
    const path = '/storage/v1/object/vault-attachments/' + owner + '/' + file + '.bin';
    assert.ok((await request(path, { token, bytes: frame, upsert: true })).ok);
    const downloaded = await request(path, { token });
    assert.ok(downloaded.ok);
    assert.deepEqual(Buffer.from(await downloaded.arrayBuffer()), frame);
    const forbidden = await request(path, { token: b.access_token });
    assert.ok([400, 403, 404].includes(forbidden.status));
    stage = 'ciphertext write, retry and account isolation';
    const id = randomUUID();
    const title = 'Quiet Campus synthetic record';
    const now = new Date().toISOString();
    const record = { v: 1, title, kind: 'note', delta: [{ insert: title + '\n' }], tags: [],
      createdAt: now, updatedAt: now, attachments: [{ id: file, name: 'synthetic.txt', size: original.length }] };
    const ciphertext = seal(sodium.from_string(JSON.stringify(record)), recordKey, owner + ':record:' + id + ':1');
    const write = { p_id: id, p_base_revision: 0, p_mutation_id: randomUUID(), p_ciphertext: ciphertext, p_deleted: false };
    const first = await rpc('write_record', write);
    assert.equal(first.conflict, false);
    assert.deepEqual(await rpc('write_record', write), first);
    const records = await rows('records', owner, token);
    const vaults = await rows('vaults', owner, token);
    assert.equal(records.length, 1);
    assert.equal(records[0].revision, 1);
    assert.deepEqual(records[0].ciphertext, ciphertext);
    assert.equal(vaults.length, 1);
    assert.deepEqual(await rows('records', owner, b.access_token), []);
    assert.deepEqual(await rows('vaults', owner, b.access_token), []);
    stage = 'backup recovery from server ciphertext';
    const backup = { format: 'quiet-campus-backup', v: 1, owner, vault: vaults[0], records, conflicts: {}, attachments: { [file]: encode(frame) } };
    for (const [secret, useRecovery] of [[pass, false], [Buffer.from(recovery).toString('base64url'), true]]) {
      const opened = await decryptBackup(backup, secret, useRecovery);
      assert.equal(opened.records[0].value.title, title);
      assert.deepEqual(opened.attachments.get(file), original);
    }
    console.log('PASS: hosted password login, ciphertext read/write, same-mutation retry, account isolation, private attachment and offline backup recovery.');
  } finally {
    for (const bytes of [master, recovery, wrapping, recordKey, attachmentKey]) sodium.memzero(bytes);
  }
} catch (error) {
  const status = /^HTTP \d+$/.test(error.message) ? ' (' + error.message + ')' : '';
  console.error('Hosted verification stopped at: ' + stage + status);
  process.exitCode = 1;
}
