import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import sodium from 'libsodium-wrappers-sumo';
import { decryptBackup } from './decrypt-backup.mjs';

await sodium.ready;
globalThis.sodium = sodium;
globalThis.self = globalThis;
await new Promise((done,fail) => {
  let passed = false, interoperable = false;
  const timer = setTimeout(() => fail(Error('Dart crypto check did not complete')),15000);
  const finish = () => { if (passed && interoperable) { clearTimeout(timer); done(); } };
  globalThis.dartPrint = (message) => {
    if (message.startsWith('CRYPTO_FIXTURE:')) {
      const fixture = JSON.parse(message.slice('CRYPTO_FIXTURE:'.length));
      (async () => {
        const archive = await decryptBackup(fixture.backup,fixture.secret);
        assert.equal(archive.records[0].value.title,'第一次志愿服务');
        assert.deepEqual([...archive.attachments.values()][0],new Uint8Array([0,255,17,99]));
        assert.equal((await decryptBackup(fixture.backup,fixture.recovery,true)).records.length,3);
        assert.equal(archive.records[1].value.kind,'material');
        assert.equal(archive.records[1].value.materialCategory,'奖项');
        assert.equal(JSON.parse(archive.records[2].value.delta.find(op=>op.insert?.custom).insert.custom)['quiet-material-v1'],archive.records[1].id);
        const incomplete = structuredClone(fixture.backup); incomplete.attachments = {};
        await assert.rejects(decryptBackup(incomplete,fixture.secret));
        interoperable = true; finish();
      })().catch((error) => { clearTimeout(timer); fail(error); });
    } else if (message.startsWith('PASS:')) { passed = true; console.log(message); finish(); }
  };
  createRequire(import.meta.url)(resolve(process.argv[2] ?? '.tooling/crypto_check.js'));
});
console.log('PASS: Dart-produced backups decrypt independently with password and recovery key');
