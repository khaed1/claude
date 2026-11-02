// Renders the PLEA v2 brand PNGs from the HTML files next to this script into ../ (plea/brand/v2/).
//
//   PLAYWRIGHT=/opt/node-tools/node_modules/playwright/index.mjs node render.mjs [name ...]
//
// Names: A B stamp-light stamp-dark header preview mock (default: all, in that order; the preview
// and the mock read the PNGs made before them). Google Fonts load through $HTTPS_PROXY.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const out = path.resolve(here, '..');
const pw = await import(process.env.PLAYWRIGHT || 'playwright');
const chromium = pw.chromium || pw.default.chromium;
const exe = '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';

const jobs = {
  'A':           { src: 'avatar-A.html',      png: 'pleaimd-v2-A-1000.png',          vw: 1000, vh: 1000, sel: '.frame' },
  'B':           { src: 'avatar-B.html',      png: 'pleaimd-v2-B-1000.png',          vw: 1000, vh: 1000, sel: '.frame' },
  'stamp-light': { src: 'stamp-light.html',   png: 'plea-v2-stamp-light.png',        vw: 1400, vh: 700,  sel: '.wrap', transparent: true },
  'stamp-dark':  { src: 'stamp-dark.html',    png: 'plea-v2-stamp-dark.png',         vw: 1400, vh: 700,  sel: '.wrap', transparent: true },
  'header':      { src: 'header.html',        png: 'pleaimd-v2-header-1500x500.png', vw: 1500, vh: 500,  sel: '.header' },
  'preview':     { src: 'avatar-preview.html', png: 'pleaimd-v2-avatar-preview.png', vw: 1600, vh: 1000,  sel: '.sheet' },
  'mock':        { src: 'profile-mock.html',  png: 'pleaimd-v2-profile-mock.png',    vw: 600,  vh: 600,  sel: '.x', font: 'Inter' },
};
const want = process.argv.slice(2).length ? process.argv.slice(2) : Object.keys(jobs);

const browser = await chromium.launch({ executablePath: fs.existsSync(exe) ? exe : undefined,
  proxy: process.env.HTTPS_PROXY ? { server: process.env.HTTPS_PROXY } : undefined });
try {
  for (const name of want) {
    const j = jobs[name];
    if (!j) throw new Error('unknown job ' + name);
    const page = await browser.newPage({ viewport: { width: j.vw, height: j.vh }, deviceScaleFactor: 1 });
    const errors = [];
    page.on('pageerror', (e) => errors.push(String(e)));
    page.on('requestfailed', (r) => errors.push('failed ' + r.url()));
    await page.goto('file://' + path.join(here, j.src) + (j.query || ''), { waitUntil: 'load' });
    await page.evaluate(() => document.fonts.ready);
    await page.evaluate(() => window.__ready || true);
    const fonts = await page.evaluate(() => [...document.fonts].filter((f) => f.status === 'loaded').map((f) => f.family));
    const need = j.font || 'Archivo';
    if (!fonts.includes(need)) throw new Error(name + ': ' + need + ' did not load (' + fonts.join(', ') + ')');
    if (errors.length) throw new Error(name + ': ' + errors.join('; '));
    const el = page.locator(j.sel).first();
    const file = path.join(out, j.png);
    await el.screenshot({ path: file, omitBackground: !!j.transparent, animations: 'disabled' });
    const box = await el.boundingBox();
    console.log(name.padEnd(12), j.png, Math.round(box.width) + 'x' + Math.round(box.height), 'fonts:', [...new Set(fonts)].join(', '));
    await page.close();
  }
} finally {
  await browser.close();
}
