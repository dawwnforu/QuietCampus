import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdir, mkdtemp, readFile, readdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { deliverFictionalOrder, rehearseDelivery } from '../tool/rehearse-web-delivery.mjs';

test('rehearsal rejects redirect-only evidence and repeats produce one delivery', async () => {
  const root = await mkdtemp(join(tmpdir(), 'quiet-delivery-'));
  const packagePath = join(root, 'candidate.zip');
  await writeFile(packagePath, 'fictional package bytes');
  const output = join(root, 'rehearsal');
  const report = await rehearseDelivery(packagePath, output);
  assert.deepEqual(report.attempts.map(a => a.outcome), ['rejected', 'one-local-copy-created', 'duplicate-not-fulfilled-again']);
  assert.equal(report.realOrders, 0);
  assert.equal(report.realRevenue, 0);
  assert.deepEqual((await readdir(join(output, 'SIM-QA-PAID'))).sort(), ['READ-ME-FIRST.txt', 'SIMULATED-RECEIPT.json', 'candidate.zip'].sort());
  assert.equal(await readFile(join(output, 'SIM-QA-PAID', 'candidate.zip'), 'utf8'), 'fictional package bytes');
  // Re-importing the module reproduces a fresh caller, not an in-memory duplicate set.
  const { deliverFictionalOrder: freshCaller } = await import(`../tool/rehearse-web-delivery.mjs?restart=${Date.now()}`);
  const paid = { id: 'SIM-QA-PAID', product: 'quiet-campus-browser-local-candidate', simulation: true, state: 'paid', currency: 'CNY', amountMinor: 1 };
  assert.equal((await freshCaller({ orderId: paid.id, providerLookup: async () => paid, packagePath, output })).duplicate, true);
  await assert.rejects(rehearseDelivery(packagePath, output), { code: 'EEXIST' });
});

test('unpaid, refunded, mismatched and real orders cannot create delivery directories', async () => {
  const output = await mkdtemp(join(tmpdir(), 'quiet-rejected-delivery-'));
  const order = { id: 'SIM-QA-REJECT', product: 'quiet-campus-browser-local-candidate', simulation: true, state: 'paid', currency: 'CNY', amountMinor: 1 };
  for (const changes of [
    { state: 'pending' }, { state: 'refunded' }, { product: 'other' },
    { currency: 'USD' }, { amountMinor: 0 }, { simulation: false }, { id: 'another-id' },
  ]) {
    await assert.rejects(deliverFictionalOrder({ orderId: order.id, providerLookup: async () => ({ ...order, ...changes }), packagePath: 'unused.zip', output }), /No matching/);
  }
  await assert.rejects(deliverFictionalOrder({ orderId: '../real-order', providerLookup: async () => order, packagePath: 'unused.zip', output }), /Only fictional/);
  assert.deepEqual(await readdir(output), []);
});

test('interrupted delivery is preserved for inspection rather than treated as completed', async () => {
  const output = await mkdtemp(join(tmpdir(), 'quiet-interrupted-delivery-'));
  const order = { id: 'SIM-INTERRUPTED', product: 'quiet-campus-browser-local-candidate', simulation: true, state: 'paid', currency: 'CNY', amountMinor: 1 };
  const directory = join(output, order.id);
  await mkdir(directory);
  await writeFile(join(directory, 'candidate.zip'), 'partial copy');
  const packagePath = join(output, 'candidate.zip');
  await writeFile(packagePath, 'complete copy');
  await assert.rejects(deliverFictionalOrder({ orderId: order.id, providerLookup: async () => order, packagePath, output }), /without a receipt/);
  assert.deepEqual(await readdir(directory), ['candidate.zip']);
  assert.equal(await readFile(join(directory, 'candidate.zip'), 'utf8'), 'partial copy');
});
