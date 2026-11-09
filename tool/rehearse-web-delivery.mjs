// Local fictional rehearsal only; never connects to a payment provider or sends files.
import { constants } from 'node:fs';
import { copyFile, mkdir, readFile, writeFile } from 'node:fs/promises';
import { basename, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const product = 'quiet-campus-browser-local-candidate';

export async function deliverFictionalOrder({ orderId, providerLookup, packagePath, output }) {
  if (!/^SIM-[A-Z0-9-]{1,64}$/.test(orderId)) throw Error('Only fictional SIM orders are allowed');
  // The lookup is a test double for an independently checked provider result.
  const order = await providerLookup(orderId);
  if (!order || order.id !== orderId || order.product !== product ||
      order.simulation !== true || order.state !== 'paid' ||
      order.currency !== 'CNY' || order.amountMinor !== 1) {
    throw Error('No matching simulated paid order; a return-page redirect is insufficient');
  }
  const directory = join(resolve(output), orderId);
  await mkdir(directory, { recursive: true });
  const receiptPath = join(directory, 'SIMULATED-RECEIPT.json');
  try {
    const existing = JSON.parse(await readFile(receiptPath, 'utf8'));
    if (existing.orderId !== orderId || existing.package !== basename(packagePath)) throw Error('Receipt differs; keep existing delivery for inspection');
    return { duplicate: true, receipt: existing };
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
  const receipt = {
    simulation: true, orderId, product, package: basename(packagePath),
    mockAmountMinor: 1, currency: 'CNY', realPayments: 0, realSettlement: 0,
    status: 'local-fixture-delivery-only',
  };
  try {
    await copyFile(packagePath, join(directory, basename(packagePath)), constants.COPYFILE_EXCL);
  } catch (error) {
    if (error.code !== 'EEXIST') throw error;
    // Interrupted deliveries are left for review; do not trust an incomplete copy.
    throw Error('Package already exists without a receipt; inspect it before retrying');
  }
  await writeFile(join(directory, 'READ-ME-FIRST.txt'),
    'SIMULATION ONLY / 仅本地模拟，不是购买凭证\n' +
    '1. Unzip the candidate package / 解压候选包。\n' +
    '2. Open START-HERE.md, then Start-QuietCampus.cmd on Windows x64.\n' +
    '3. Try fictional samples first; local archives need regular encrypted backups.\n' +
    'No cloud sync, online AI, automatic backup or public hosting is included.\n', { flag: 'wx' });
  // Exclusive creation makes repeated/concurrent completion unable to fulfill twice.
  await writeFile(receiptPath, JSON.stringify(receipt, null, 2), { flag: 'wx' });
  return { duplicate: false, receipt };
}

export async function rehearseDelivery(packagePath, output) {
  // An existing rehearsal is never reset or overwritten.
  await mkdir(output);
  const paid = { id: 'SIM-QA-PAID', product, simulation: true, state: 'paid', currency: 'CNY', amountMinor: 1 };
  const providerLookup = async (id) => id === paid.id ? paid : null;
  const attempts = [];
  for (const orderId of ['SIM-REDIRECT-ONLY', paid.id, paid.id]) {
    try {
      const result = await deliverFictionalOrder({ orderId, providerLookup, packagePath, output });
      attempts.push({ orderId, outcome: result.duplicate ? 'duplicate-not-fulfilled-again' : 'one-local-copy-created' });
    } catch (error) {
      attempts.push({ orderId, outcome: 'rejected', reason: error.message });
    }
  }
  const report = { simulation: true, realUsers: 0, realOrders: 0, realRevenue: 0, realSettlement: 0, attempts };
  await writeFile(join(output, 'REHEARSAL.json'), JSON.stringify(report, null, 2), { flag: 'wx' });
  return report;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [packagePath, output] = process.argv.slice(2);
  if (!packagePath || !output || !packagePath.endsWith('.zip')) throw Error('Usage: node tool/rehearse-web-delivery.mjs CANDIDATE.zip NEW_OUTPUT_DIRECTORY');
  console.log(JSON.stringify(await rehearseDelivery(resolve(packagePath), resolve(output)), null, 2));
}
