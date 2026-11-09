import sodium from 'libsodium-wrappers-sumo';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { createInterface } from 'node:readline/promises';
import { Writable } from 'node:stream';

export async function decryptBackup(backup, secret, recovery = false) {
  await sodium.ready;
  if (backup.format !== 'quiet-campus-backup' || backup.v !== 1) throw Error('unsupported backup');
  const owner = backup.owner;
  const header = backup.vault.envelope;
  if (header.v !== 1 || header.ops !== 2 || header.mem !== 67108864) throw Error('unsupported KDF');
  const decode = (s) => new Uint8Array(Buffer.from(s, 'base64'));
  const open = (envelope, key, aad) => {
    if (envelope.v !== 1) throw Error('unsupported envelope');
    return sodium.crypto_aead_xchacha20poly1305_ietf_decrypt(null,
      decode(envelope.box), sodium.from_string(aad), decode(envelope.nonce), key);
  };
  const wrapping = recovery ? new Uint8Array(Buffer.from(secret.trim(), 'base64url'))
    : sodium.crypto_pwhash(32, secret, decode(header.salt), 2, 67108864, sodium.crypto_pwhash_ALG_ARGON2ID13);
  let master, recordKey, attachmentKey;
  try {
    master = open(header[recovery ? 'recovery' : 'pass'], wrapping, `${owner}:vault:${recovery ? 'recovery' : 'pass'}:1`);
    recordKey = sodium.crypto_kdf_derive_from_key(32,1,'RECORD01',master);
    attachmentKey = sodium.crypto_kdf_derive_from_key(32,1,'ATTACH01',master);
    const record = (r) => ({ id: r.id, deleted: r.deleted,
      value: JSON.parse(sodium.to_string(open(r.ciphertext, recordKey, `${owner}:record:${r.id}:1`))) });
    const records = backup.records.map(record);
    const conflicts = Object.values(backup.conflicts).map(record);
    const attachments = new Map();
    for (const [id, encoded] of Object.entries(backup.attachments)) {
      if (!/^[0-9a-f-]{36}$/.test(id)) throw Error('invalid attachment id');
      const frame = decode(encoded);
      if (frame.length < 41 || frame[0] !== 1) throw Error('invalid attachment');
      attachments.set(id, sodium.crypto_aead_xchacha20poly1305_ietf_decrypt(null,
        frame.subarray(25), sodium.from_string(`${owner}:attachment:${id}:1`), frame.subarray(1,25), attachmentKey));
    }
    for (const r of [...records,...conflicts]) {
      if (!r.deleted) for (const file of r.value.attachments ?? []) {
        if (!attachments.has(file.id)) throw Error('missing attachment');
      }
    }
    return { records, conflicts, attachments };
  } finally {
    for (const key of [wrapping,master,recordKey,attachmentKey]) if (key) sodium.memzero(key);
  }
}

async function main() {
  const [source, destination, mode] = process.argv.slice(2);
  if (!source || !destination || (mode && mode !== '--recovery')) {
    throw Error('usage: node tool/decrypt-backup.mjs backup.json NEW_DIRECTORY [--recovery]');
  }
  process.stdout.write('将在指定的新目录中生成明文。请输入加密口令或恢复密钥：');
  const muted = new Writable({ write(_chunk, _encoding, callback) { callback(); } });
  const input = createInterface({ input: process.stdin, output: muted, terminal: !!process.stdin.isTTY });
  let secret;
  try { secret = await input.question(''); } finally { input.close(); process.stdout.write('\n'); }
  const backup = JSON.parse(await readFile(source,'utf8'));
  const result = await decryptBackup(backup,secret,mode === '--recovery');
  const output = resolve(destination);
  await mkdir(output); // An existing directory is deliberately not overwritten.
  await mkdir(join(output,'attachments'));
  const names = new Map([...result.records,...result.conflicts]
    .flatMap((r) => (r.value.attachments ?? []).map((a) => [a.id,a.name])));
  for (const [id,bytes] of result.attachments) {
    const extension = /\.[a-z0-9]{1,10}$/i.exec(names.get(id) ?? '')?.[0] ?? '';
    await writeFile(join(output,'attachments',`${id}${extension}`),bytes,{ flag:'wx' });
    sodium.memzero(bytes);
  }
  await writeFile(join(output,'records.json'),JSON.stringify({records:result.records,conflicts:result.conflicts},null,2),{flag:'wx'});
  process.stdout.write(`已导出 ${result.records.length} 条记录、${result.conflicts.length} 个冲突版本和 ${result.attachments.size} 份附件。\n`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch(() => {
    process.stderr.write('解密未完成。请检查备份、口令和输出目录，保留原始备份；输出目录须不存在。\n');
    process.exitCode = 1;
  });
}
