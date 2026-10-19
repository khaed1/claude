// Renders the X share cards of pages/share-cards.html to PNG at exactly 1200 x 675: one file per
// element marked data-share-png="<name>", saved as shots/share-card-<name>.png.
//
//   node tools/render_share_cards.mjs [pages/share-cards.html] [--out shots] [--preview <dir>]
//
// --preview <dir> also writes each card scaled to 600 px wide (about X's timeline size) for a
// legibility check. Needs Playwright (PLAYWRIGHT=/path/to/playwright/index.mjs, default
// "playwright"); CHROMIUM=/path/to/chrome overrides the browser. Uses the same fake-origin routing as
// tools/check.mjs so the stylesheets and the icon sprite load.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const args = process.argv.slice(2);
const opt = (k, d) => { const i = args.indexOf('--' + k); return i >= 0 ? args[i + 1] : d; };
const positional = args.filter((a, i) => !a.startsWith('--') && !(i > 0 && args[i - 1].startsWith('--')));
const here = path.dirname(fileURLToPath(import.meta.url));
const file = path.resolve(positional[0] || path.join(here, '..', 'pages', 'share-cards.html'));
const outDir = path.resolve(opt('out', path.join(here, '..', 'shots')));
const previewDir = opt('preview', null);
const W = 1200, H = 675;

const pw = await import(process.env.PLAYWRIGHT || 'playwright');
const chromium = pw.chromium || pw.default.chromium;
const exe = process.env.CHROMIUM || (fs.existsSync('/opt/pw-browsers/chromium-1194/chrome-linux/chrome') ? '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' : undefined);
const browser = await chromium.launch({ executablePath: exe, proxy: process.env.HTTPS_PROXY ? { server: process.env.HTTPS_PROXY, bypass: '127.0.0.1,localhost' } : undefined });

// Serve the design folder from a fake origin through Playwright's router (as in check.mjs).
let rootDir = path.dirname(file);
while (!fs.existsSync(path.join(rootDir, 'tokens.css')) && rootDir !== path.dirname(rootDir)) rootDir = path.dirname(rootDir);
const types = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.svg': 'image/svg+xml' };
const ORIGIN = 'http://plea.design';
async function serve(route) {
  const u = decodeURIComponent(new URL(route.request().url()).pathname);
  const f = path.join(rootDir, path.normalize(u));
  if (!f.startsWith(rootDir) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) return route.fulfill({ status: 404, body: '' });
  return route.fulfill({ status: 200, contentType: types[path.extname(f)] || 'application/octet-stream', body: fs.readFileSync(f) });
}
const base = ORIGIN + '/' + path.relative(rootDir, file).split(path.sep).join('/');

const page = await browser.newPage({ viewport: { width: W, height: 900 }, deviceScaleFactor: 1 });
const errors = [];
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', (e) => errors.push(String(e)));
await page.route(ORIGIN + '/**', serve);
// The page itself in light; each card carries its own .theme-light or .theme-dark.
await page.addInitScript(() => { try { localStorage.setItem('plea-theme', 'light'); } catch (e) {} });
await page.goto(base + '?theme=light', { waitUntil: 'networkidle' });
await page.evaluate(() => document.fonts.ready);

const names = await page.$$eval('[data-share-png]', (els) => els.map((e) => e.getAttribute('data-share-png')));
if (!names.length) { console.error('No [data-share-png] cards in ' + file); process.exit(1); }
fs.mkdirSync(outDir, { recursive: true });
if (previewDir) fs.mkdirSync(previewDir, { recursive: true });

const report = { file: path.relative(process.cwd(), file), cards: [], ok: true };
for (const name of names) {
  // Clone the card's frame into a fixed 1200 px host at the top left, so the card's own unit
  // (1u = 1/1200 of the frame) is exactly one pixel, whatever the page layout around it.
  await page.evaluate(({ name, W }) => {
    document.getElementById('share-render-host')?.remove();
    const src = document.querySelector('[data-share-png="' + name + '"]');
    const host = document.createElement('div');
    host.id = 'share-render-host';
    host.style.cssText = 'position:fixed;left:0;top:0;width:' + W + 'px;z-index:2147483647;margin:0;padding:0;';
    const clone = src.cloneNode(true);
    clone.removeAttribute('data-share-png');
    clone.style.width = W + 'px';
    clone.style.maxWidth = 'none';
    host.appendChild(clone);
    document.body.appendChild(host);
  }, { name, W });
  await page.evaluate(() => document.fonts.ready);
  const card = page.locator('#share-render-host .share-card');
  const box = await card.boundingBox();
  const png = path.join(outDir, 'share-card-' + name + '.png');
  await card.screenshot({ path: png, animations: 'disabled' });
  // Overflow check: nothing inside the card may stick out of it or overlap the stamp.
  const fit = await page.evaluate(() => {
    const c = document.querySelector('#share-render-host .share-card');
    const r = c.getBoundingClientRect();
    const out = [];
    for (const el of c.querySelectorAll('*')) {
      const b = el.getBoundingClientRect();
      if (b.width && (b.right > r.right + 0.5 || b.bottom > r.bottom + 0.5 || b.left < r.left - 0.5 || b.top < r.top - 0.5)) out.push(el.className || el.tagName);
    }
    const text = c.querySelector('.share-card__text, .share-card__title');
    const stamp = c.querySelector('.share-card__stamp');
    let overlap = false;
    if (text && stamp) {
      const range = document.createRange();
      range.selectNodeContents(text);
      const s = stamp.getBoundingClientRect();
      for (const line of range.getClientRects()) {
        if (line.right > s.left && line.left < s.right && line.bottom > s.top && line.top < s.bottom) { overlap = true; break; }
      }
    }
    return { outside: out.slice(0, 6), overlap };
  });
  const entry = { name, png, width: Math.round(box.width), height: Math.round(box.height), outside: fit.outside, textUnderStamp: fit.overlap };
  if (entry.width !== W || entry.height !== H || fit.outside.length || fit.overlap) { entry.fail = true; report.ok = false; }
  if (previewDir) {
    // Scale the card to 600 px without CSS zoom: a second screenshot at half the device scale.
    const small = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 0.5 });
    // No body margin: with the default 8 px the preview was shifted and lost its right and bottom border.
    await small.setContent('<style>html,body{margin:0}</style><img src="data:image/png;base64,' + fs.readFileSync(png).toString('base64') + '" style="display:block;width:' + W + 'px;height:' + H + 'px">');
    const p = path.join(previewDir, 'share-card-' + name + '-600.png');
    await small.screenshot({ path: p });
    entry.preview = p;
    await small.close();
  }
  report.cards.push(entry);
}
await page.evaluate(() => document.getElementById('share-render-host')?.remove());
await browser.close();
report.consoleErrors = errors;
if (errors.length) report.ok = false;
console.log(JSON.stringify(report, null, 1));
process.exit(report.ok ? 0 : 1);
