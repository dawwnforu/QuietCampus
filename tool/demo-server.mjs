import http from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { resolve, relative, extname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { realpath } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';

const root = process.argv[2] ? resolve(process.argv[2]) : fileURLToPath(new URL('../build/web/', import.meta.url));
const port = process.argv[3] === undefined ? 7357 : Number(process.argv[3]);
if (!Number.isInteger(port) || port < 1024 || port > 65535) throw new Error('Invalid local port');
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm', '.css': 'text/css',
  '.png': 'image/png', '.svg': 'image/svg+xml', '.woff2': 'font/woff2', '.ttf': 'font/ttf',
  '.txt': 'text/plain; charset=utf-8', '.md': 'text/plain; charset=utf-8', '.otf': 'font/otf' };
export async function localServer(directory) {
  const safeRoot = await realpath(directory);
  await stat(resolve(safeRoot, 'index.html'));
  return http.createServer(async (request, response) => {
  try {
    if (request.headers.host !== `127.0.0.1:${request.socket.localPort}`) {
      response.writeHead(403).end();
      return;
    }
    if (!['GET', 'HEAD'].includes(request.method)) {
      response.writeHead(405).end();
      return;
    }
    const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    const file = await realpath(resolve(safeRoot, `.${pathname === '/' ? '/index.html' : pathname}`));
    const location = relative(safeRoot, file);
    if (location.startsWith('..') || location.includes(':')) {
      response.writeHead(403).end();
      return;
    }
    const bytes = await readFile(file);
    response.writeHead(200, { 'Content-Type': types[extname(file)] ?? 'application/octet-stream',
      'Cache-Control': 'no-store', 'Content-Length': bytes.length,
      'X-Content-Type-Options': 'nosniff', 'Referrer-Policy': 'no-referrer' });
    response.end(request.method === 'HEAD' ? undefined : bytes);
  } catch {
    response.writeHead(404).end('Not found');
  }
  });
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const server = await localServer(root);
  server.on('error', (error) => {
    console.error(error.code === 'EADDRINUSE'
      ? `Port ${port} is already in use. Keep the same port for your saved archive.\n端口已被占用：若静档已经运行，请继续使用原窗口；否则关闭占用程序后再试。不要清理站点数据或随意换端口。`
      : 'Could not start the local server. 本机服务无法启动，已保存的浏览器资料未改动。');
    process.exitCode = 1;
  });
  server.listen(port, '127.0.0.1', () => {
    const entry = existsSync(resolve(root, 'welcome.html')) ? '/welcome.html' : '/';
    const url = `http://127.0.0.1:${port}${entry}`;
    console.log(`Quiet Campus: ${url}\n仅本机有效。Keep this window open; Ctrl+C stops the server.\n关闭服务不会清除已保存的浏览器档案。`);
    if (process.argv[4] === '--open' && process.platform === 'win32') {
      const opener = spawn('cmd.exe', ['/d', '/c', 'start', '', url], {windowsHide: true, stdio: 'ignore'});
      opener.on('error', () => console.log(`Please open ${url} in your browser.`));
    }
  });
}
