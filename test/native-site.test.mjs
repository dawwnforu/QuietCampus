import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve, sep } from 'node:path';
import { prepareNativeSite } from '../tool/prepare-native-site.mjs';

test('native release pages keep links local, disclose test scope and never add account or diary forms', async (t) => {
  const dir = await mkdtemp(join(tmpdir(), 'quiet-native-site-'));
  assert.ok(dir.startsWith(resolve(tmpdir()) + sep));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const pages = await prepareNativeSite(dir);
  assert.equal(pages.length, 6);
  for (const page of pages) {
    const html = await readFile(join(dir, page), 'utf8');
    assert.match(html, /noindex,nofollow/);
    assert.match(html, /尚未正式上架/);
    assert.doesNotMatch(html, /<(form|input|textarea|script)\b/i);
    for (const [, url] of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
      if (!url.startsWith('https://') && !url.startsWith('#')) assert.ok((await readFile(join(dir, url))).length);
    }
  }
  assert.match(await readFile(join(dir, 'download.html'), 'utf8'), /正在构建与核验/);
  const url = 'https://drive.google.com/file/d/fictional-apk-id/view?usp=drivesdk';
  await prepareNativeSite(dir, url);
  assert.ok((await readFile(join(dir, 'download.html'), 'utf8')).includes(url));
  await assert.rejects(prepareNativeSite(dir, 'javascript:alert(1)'));
  await assert.rejects(prepareNativeSite(dir, 'https://user:password@drive.google.com/file/d/id/view'));
});
