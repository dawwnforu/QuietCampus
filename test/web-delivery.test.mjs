import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, mkdir, symlink, rm, readFile } from 'node:fs/promises';
import { join, resolve, sep } from 'node:path';
import { tmpdir } from 'node:os';
import http from 'node:http';
import { localServer } from '../tool/demo-server.mjs';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';

function request(port, path, options = {}) {
  return new Promise((resolve, reject) => {
    const req = http.request({hostname:'127.0.0.1', port, path, ...options}, res => {
      const chunks = [];
      res.on('data', chunk => chunks.push(chunk));
      res.on('end', () => resolve({status:res.statusCode, headers:res.headers, body:Buffer.concat(chunks).toString()}));
    });
    req.on('error', reject);
    req.end();
  });
}

test('loopback delivery serves UTF-8, handles HEAD and rejects writes, escapes and foreign hosts', async t => {
  const temp = await mkdtemp(join(tmpdir(), 'quiet-delivery-'));
  assert.ok(temp.startsWith(resolve(tmpdir()) + sep));
  t.after(() => rm(temp, {recursive:true, force:true}));
  const site = join(temp, 'site');
  await mkdir(site);
  await writeFile(join(site, 'index.html'), '虚构页面 <A&B>');
  await writeFile(join(temp, 'private.txt'), 'not part of the website');
  await symlink(temp, join(site, 'escape'), 'junction');
  const server = await localServer(site);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const port = server.address().port;
  const page = await request(port, '/');
  assert.equal(page.status, 200);
  assert.equal(page.body, '虚构页面 <A&B>');
  assert.match(page.headers['content-type'], /charset=utf-8/);
  assert.equal(page.headers['x-content-type-options'], 'nosniff');
  const head = await request(port, '/', {method:'HEAD'});
  assert.equal(head.status, 200);
  assert.equal(head.body, '');
  assert.equal(head.headers['content-length'], String(Buffer.byteLength(page.body)));
  assert.equal((await request(port, '/', {method:'POST'})).status, 405);
  assert.equal((await request(port, '/%2e%2e%2fprivate.txt')).status, 403);
  assert.equal((await request(port, '/escape/private.txt')).status, 403);
  assert.equal((await request(port, '/', {headers:{host:'other.example'}})).status, 403);
  assert.equal((await request(port, '/%00')).status, 404);
  await assert.rejects(promisify(execFile)(process.execPath,
    [fileURLToPath(new URL('../tool/demo-server.mjs', import.meta.url)), site, String(port)],
    {timeout:5000}), error => error.code === 1 && /already in use/.test(error.stderr));
  assert.equal((await request(port, '/')).status, 200, 'busy-port launch must leave the first server running');
});

test('landing paths preserve archive origin and distinguish fictional from private storage', async () => {
  const html = await readFile(new URL('../tool/web-product/welcome.html', import.meta.url), 'utf8');
  assert.match(html, /href="\.\/\?demo=1"/);
  assert.match(html, /href="\.\/"/);
  assert.match(html, /data-en="Fictional example"/);
  assert.match(html, /id="language-switch"/);
  assert.doesNotMatch(html, /https?:\/\/(?:localhost|127\.0\.0\.1)/);
  assert.doesNotMatch(html, /<form|password|api[_-]?key|立即购买/i);
  const js = await readFile(new URL('../tool/web-product/portal.js', import.meta.url), 'utf8');
  assert.doesNotMatch(js, /fetch\(|XMLHttpRequest|sendBeacon|innerHTML/);
});
