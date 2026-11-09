import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, mkdirSync, rmSync, readFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { checkNativeRelease } from '../tool/check-native-release.mjs';

test('local native test runner rejects a non-test path without changing generated configuration', {skip: process.platform !== 'win32'}, () => {
  const sourceRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
  const files = ['.dart_tool/package_config.json', '.dart_tool/package_graph.json', '.flutter-plugins-dependencies', 'android/local.properties'];
  const snapshot = () => files.map(name => {
    const file = join(sourceRoot, name);
    return existsSync(file) ? createHash('sha256').update(readFileSync(file)).digest('hex') : null;
  });
  const before = snapshot();
  const result = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', join(sourceRoot, 'tool/test-native.ps1'), '../README.md'], {
    cwd: sourceRoot, encoding: 'utf8', windowsHide: true, timeout: 10000,
  });
  assert.ifError(result.error);
  assert.notEqual(result.status, 0);
  assert.match(result.stdout + result.stderr, /Only existing project test\/\*\.dart files are accepted/);
  assert.deepEqual(snapshot(), before);
});

function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'quiet-release-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const config = {
    APP_ENVIRONMENT: 'production',
    SUPABASE_URL: 'https://vault.example.org',
    SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_fictional',
  };
  const check = (platform = 'windows') => {
    writeFileSync(join(root, 'config.json'), JSON.stringify(config));
    return checkNativeRelease(root, platform, 'config.json');
  };
  return { root, config, check };
}

test('production preflight accepts public configuration but rejects test and unsafe endpoints', (t) => {
  const { config, check } = fixture(t);
  assert.deepEqual(check(), []);
  for (const endpoint of ['http://vault.example.org', 'https://localhost', 'https://127.0.0.1',
    'https://[::1]', 'https://user:password@vault.example.org', 'https://vault.example.org?secret=x',
    'https://eeeeisvdrcvjgmjtobgp.supabase.co',
    'https://eeeeisvdrcvjgmjtobgp.supabase.co.',
    'https://localhost.', 'https://vault.test.']) {
    config.SUPABASE_URL = endpoint;
    assert.ok(check().length, endpoint);
  }
  config.SUPABASE_URL = 'https://vault.example.org';
  config.APP_ENVIRONMENT = 'test';
  assert.ok(check().length);
});

test('preflight rejects secrets and malformed configs without echoing credentials', (t) => {
  const { root, config, check } = fixture(t);
  for (const key of ['sb_secret_fictional-private', '', 12,
    `x.${Buffer.from(JSON.stringify({ role: 'service_role' })).toString('base64url')}.x`]) {
    config.SUPABASE_PUBLISHABLE_KEY = key;
    assert.ok(check().length);
    if (String(key)) assert.equal(check().join().includes(String(key)), false);
  }
  config.SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_fictional';
  config.DATABASE_PASSWORD = 'fictional-private-value';
  assert.ok(check().length);
  assert.equal(check().join().includes('fictional-private-value'), false);
  writeFileSync(join(root, 'bad.json'), '{"password":"fictional-private-value"');
  assert.equal(checkNativeRelease(root, 'windows', 'bad.json').join().includes('fictional-private-value'), false);
  assert.ok(checkNativeRelease(root, 'windows', 'missing.json').length);
});

test('Android preflight requires complete signing config and never creates a keystore', (t) => {
  const { root, check } = fixture(t);
  assert.ok(check('android').length);
  mkdirSync(join(root, 'android/app'), { recursive: true });
  writeFileSync(join(root, 'android/key.properties'), 'keyAlias=androiddebugkey');
  assert.ok(check('android').length);
  writeFileSync(join(root, 'android/key.properties'), 'storeFile=release.jks\nstorePassword=fictional\nkeyAlias=release\nkeyPassword=fictional');
  assert.ok(check('android').length);
  writeFileSync(join(root, 'android/app/release.jks'), 'synthetic placeholder, not a signing key');
  assert.deepEqual(check('android'), []);
});
