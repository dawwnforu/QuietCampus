import { test } from 'node:test';
import assert from 'node:assert/strict';
import sodium from 'libsodium-wrappers-sumo';
import { decryptBackup } from '../tool/decrypt-backup.mjs';
import { readFile } from 'node:fs/promises';

test('Dart-encrypted material fixture retains metadata, references and one original', async () => {
  const fixture = JSON.parse(await readFile(new URL('./fixtures/material-vault.json',import.meta.url),'utf8'));
  const archive = await decryptBackup(fixture.backup,fixture.secret);
  assert.equal(archive.records[1].value.title,'虚构的私密奖状');
  assert.equal(archive.records[1].value.materialCategory,'奖项');
  assert.equal(archive.records[1].value.attachments[0].name,'私密原件.pdf');
  assert.equal(archive.attachments.size,1);
  assert.equal(JSON.parse(archive.records[2].value.delta.find(op=>op.insert?.custom).insert.custom)['quiet-material-v1'], archive.records[1].id);
});

test('backup decrypts offline and rejects wrong passwords, account swaps and tampering', async () => {
  await sodium.ready;
  const owner = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const file = '11111111-1111-4111-8111-111111111111';
  const secret = 'a long private backup passphrase';
  const salt = sodium.randombytes_buf(16);
  const master = sodium.randombytes_buf(32);
  const wrapping = sodium.crypto_pwhash(32,secret,salt,2,67108864,sodium.crypto_pwhash_ALG_ARGON2ID13);
  const recovery = sodium.randombytes_buf(32);
  const seal = (value,key,aad) => {
    const nonce = sodium.randombytes_buf(24);
    return { v:1, nonce:Buffer.from(nonce).toString('base64'),
      box:Buffer.from(sodium.crypto_aead_xchacha20poly1305_ietf_encrypt(value,sodium.from_string(aad),null,nonce,key)).toString('base64') };
  };
  const recordKey = sodium.crypto_kdf_derive_from_key(32,1,'RECORD01',master);
  const attachmentKey = sodium.crypto_kdf_derive_from_key(32,1,'ATTACH01',master);
  const attachment = seal(new Uint8Array([0,255,17]),attachmentKey,`${owner}:attachment:${file}:1`);
  const frame = Buffer.concat([Buffer.from([1]),Buffer.from(attachment.nonce,'base64'),Buffer.from(attachment.box,'base64')]);
  const backup = { format:'quiet-campus-backup',v:1,owner,
    vault: { envelope:{ v:1,salt:Buffer.from(salt).toString('base64'),ops:2,mem:67108864,
      pass:seal(master,wrapping,`${owner}:vault:pass:1`),recovery:seal(master,recovery,`${owner}:vault:recovery:1`) } },
    records:[{id:file,deleted:false,ciphertext:seal(sodium.from_string(JSON.stringify({title:'志愿服务',attachments:[]})),recordKey,`${owner}:record:${file}:1`)}],
    conflicts:{}, attachments:{[file]:frame.toString('base64')} };
  const decoded = await decryptBackup(backup,secret);
  assert.equal(decoded.records[0].value.title,'志愿服务');
  assert.deepEqual([...decoded.attachments.get(file)],[0,255,17]);
  const material = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  const materialValue = {v:2,kind:'material',title:'示例奖状',materialCategory:'奖项',materialDate:'2026-10-20',attachments:[{id:file,name:'示例奖状.pdf',size:3}],delta:[{insert:'保存成果\n'}]};
  const embed = {insert:{custom:JSON.stringify({'quiet-material-v1':material})}};
  const notes = ['cccccccc-cccc-4ccc-8ccc-cccccccccccc','dddddddd-dddd-4ddd-8ddd-dddddddddddd'];
  const sealRecord = (id,value) => ({id,deleted:false,ciphertext:seal(sodium.from_string(JSON.stringify(value)),recordKey,`${owner}:record:${id}:1`)});
  const libraryBackup = {...backup,records:[sealRecord(material,materialValue),...notes.map(id => sealRecord(id,{v:2,kind:'project',delta:[embed,{insert:'\n'}],attachments:[]}))],conflicts:{[material]:sealRecord(material,{...materialValue,title:'旧设备的材料修改'})}};
  const library = await decryptBackup(libraryBackup,secret);
  assert.equal(library.attachments.size,1);
  assert.equal(library.records[0].value.materialDate,'2026-10-20');
  assert.deepEqual(library.records[1].value.delta[0],embed);
  assert.deepEqual(library.records[2].value.delta[0],embed);
  assert.equal(library.conflicts.length,1);
  await assert.rejects(decryptBackup({...libraryBackup,attachments:{}},secret),/missing attachment/);
  assert.equal((await decryptBackup(backup,Buffer.from(recovery).toString('base64url'),true)).records.length,1);
  await assert.rejects(decryptBackup(backup,'wrong password'));
  await assert.rejects(decryptBackup({...backup,owner:'another-account'},secret));
  const tampered = structuredClone(backup);
  const bytes = Buffer.from(tampered.records[0].ciphertext.box,'base64'); bytes[0] ^= 1;
  tampered.records[0].ciphertext.box = bytes.toString('base64');
  await assert.rejects(decryptBackup(tampered,secret));
});
