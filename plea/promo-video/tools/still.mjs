// Renders stills: node tools/still.mjs <out dir> <fmt 16x9|9x16> <t1> [t2 ...]  (t in seconds)
// Env: CAPTURES=<dir of run 9 captures>. Output: <out>/<fmt>-<t>.png at 1920x1080 (or 1080x1920).
import { chromium } from '/opt/node-tools/node_modules/playwright/index.mjs';
import { mkdirSync } from 'node:fs';
import { serve } from './serve.mjs';

const [out, fmt, ...ts] = process.argv.slice(2);
mkdirSync(out, { recursive: true });
const server = await serve(8123);
const browser = await chromium.launch();
const [w, h] = fmt === '9x16' ? [720, 1280] : [1280, 720];
const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1.5 });
const errors = [];
page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') errors.push(m.text()); });
page.on('pageerror', (e) => errors.push(String(e)));
await page.goto(`http://127.0.0.1:8123/promo-video/src/index.html?fmt=${fmt}`);
await page.evaluate(() => window.ready);
for (const t of ts) {
  await page.evaluate(async (t) => { await window.seek(Number(t)); }, t);
  await page.locator('#stage').screenshot({ path: `${out}/${fmt}-${Number(t).toFixed(2)}.png` });
}
if (errors.length) console.log('console:', errors.slice(0, 8).join('\n'));
await browser.close();
server.close();
