import { test } from 'node:test';
import assert from 'node:assert/strict';
import { lstat, readFile, readdir } from 'node:fs/promises';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

test('prepared static site fits the documented direct-upload limits and excludes private fixtures', async () => {
  const root = fileURLToPath(new URL('../build/web-product/', import.meta.url));
  const files = [];
  async function visit(directory) {
    for (const entry of await readdir(directory, { withFileTypes: true })) {
      const path = join(directory, entry.name);
      const stat = await lstat(path);
      assert.equal(stat.isSymbolicLink(), false, `Do not upload linked files: ${path}`);
      if (entry.isDirectory()) await visit(path);
      else {
        assert.ok(stat.size <= 25 * 1024 * 1024, `Above Pages single-file limit: ${entry.name}`);
        files.push(relative(root, path).replaceAll('\\', '/'));
      }
    }
  }
  await visit(root);
  assert.ok(files.length > 0 && files.length <= 1000, 'Dashboard drag-and-drop file limit');
  for (const path of files) assert.doesNotMatch(path, /(?:^|\/)(?:\.env|config\.local\.json|node_modules|runtime|qa|.*\.db(?:-wal|-shm)?|quiet-campus-backup.*\.json|valid\.json|missing-file\.json)$/i);
  for (const path of ['index.html', 'main.dart.js', 'welcome.html', 'guide.zh-CN.html', 'guide.en.html', 'privacy.html', 'licenses.html', 'release.json', '_headers']) assert.ok(files.includes(path), path);
  const manifest = JSON.parse(await readFile(join(root, 'release.json'), 'utf8'));
  assert.equal(manifest.edition, 'browser-local');
  assert.equal(manifest.cloudSync, false);
  const headers = await readFile(join(root, '_headers'), 'utf8');
  assert.match(headers, /^\/\*/);
  assert.match(headers, /Cache-Control: no-store/);
  assert.match(headers, /X-Content-Type-Options: nosniff/);
});
