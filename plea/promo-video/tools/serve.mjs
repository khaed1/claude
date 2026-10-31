// A tiny static server for the film: / = plea/ (so ../../site-design resolves), /captures = the capture PNGs.
import http from 'node:http';
import { createReadStream, statSync } from 'node:fs';
import { join, normalize, extname, resolve } from 'node:path';

const ROOT = resolve(new URL('../../', import.meta.url).pathname);            // plea/
const CAPTURES = process.env.CAPTURES || '/tmp/captures';
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css', '.json': 'application/json',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.woff2': 'font/woff2', '.wav': 'audio/wav', '.mp3': 'audio/mpeg' };

export function serve(port = 8123) {
  const server = http.createServer((req, res) => {
    const url = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    const base = url.startsWith('/captures/') ? CAPTURES : ROOT;
    const rel = url.startsWith('/captures/') ? url.slice('/captures/'.length) : url.slice(1);
    const file = normalize(join(base, rel));
    if (!file.startsWith(base)) { res.writeHead(403).end(); return; }
    try { if (!statSync(file).isFile()) throw 0; } catch { res.writeHead(404).end(); return; }
    res.writeHead(200, { 'content-type': TYPES[extname(file)] || 'application/octet-stream', 'cache-control': 'no-store' });
    createReadStream(file).pipe(res);
  });
  return new Promise((r) => server.listen(port, '127.0.0.1', () => r(server)));
}
