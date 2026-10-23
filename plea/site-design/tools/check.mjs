// Checks a mockup page in a real browser: screenshots at 360/768/1280 px in light and dark, sideways
// overflow (and which elements cause it), console errors, and an axe-core scan (WCAG 2.1 AA: contrast,
// names, roles). Prints a JSON report; exit code 1 when anything fails.
//
//   node tools/check.mjs pages/buy.html [--out shots] [--widths 360,768,1280] [--themes light,dark] [--no-axe] [--full]
//
// Needs Playwright (PLAYWRIGHT=/path/to/playwright/index.mjs, default "playwright") and axe-core
// (AXE=/path/to/axe-core/axe.min.js). CHROMIUM=/path/to/chrome overrides the browser.
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const file = path.resolve(args[0]);
const opt = (k, d) => { const i = args.indexOf('--' + k); return i >= 0 ? args[i + 1] : d; };
const flag = (k) => args.includes('--' + k);
const outDir = opt('out', null);
const widths = opt('widths', '360,768,1280').split(',').map(Number);
const themes = opt('themes', 'light,dark').split(',');
const useAxe = !flag('no-axe');
const full = flag('full');

const pw = await import(process.env.PLAYWRIGHT || 'playwright');
const chromium = pw.chromium || pw.default.chromium;
const exe = process.env.CHROMIUM || (fs.existsSync('/opt/pw-browsers/chromium-1194/chrome-linux/chrome') ? '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' : undefined);
const browser = await chromium.launch({ executablePath: exe, proxy: process.env.HTTPS_PROXY ? { server: process.env.HTTPS_PROXY, bypass: '127.0.0.1,localhost' } : undefined });
const axeSrc = useAxe && process.env.AXE ? fs.readFileSync(process.env.AXE, 'utf8') : null;

// Serve the design folder from a fake origin through Playwright's router (file:// blocks the
// stylesheet reads axe makes; a loopback server would go through the sandbox proxy).
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

const report = { file: path.relative(process.cwd(), file), runs: [], ok: true };
for (const theme of themes) {
  for (const w of widths) {
    const page = await browser.newPage({ viewport: { width: w, height: 900 }, deviceScaleFactor: 1 });
    const errors = [];
    page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
    page.on('pageerror', (e) => errors.push(String(e)));
    await page.route(ORIGIN + '/**', serve);
    await page.addInitScript((t) => { try { localStorage.setItem('plea-theme', t); } catch (e) {} }, theme);
    await page.goto(base + '?theme=' + theme, { waitUntil: 'networkidle' });
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(150);
    const overflow = await page.evaluate(() => {
      const vw = document.documentElement.clientWidth;
      const sw = document.documentElement.scrollWidth;
      const wide = [];
      if (sw > vw) {
        for (const el of document.querySelectorAll('body *')) {
          const r = el.getBoundingClientRect();
          if (r.right > vw + 0.5 && r.width > 0) {
            // skip children of an element already listed and anything inside a scroll box
            let p = el.parentElement, inBox = false;
            while (p) { const cs = getComputedStyle(p); if (cs.overflowX === 'auto' || cs.overflowX === 'scroll' || cs.overflowX === 'hidden') { inBox = true; break; } p = p.parentElement; }
            if (inBox) continue;
            const id = el.id ? '#' + el.id : '';
            const cls = el.className && typeof el.className === 'string' ? '.' + el.className.trim().split(/\s+/).join('.') : '';
            wide.push(el.tagName.toLowerCase() + id + cls + ' right=' + Math.round(r.right));
            if (wide.length > 12) break;
          }
        }
      }
      return { viewport: vw, scrollWidth: sw, over: sw - vw, wide };
    });
    let axe = null;
    if (axeSrc) {
      await page.addScriptTag({ content: axeSrc });
      axe = await page.evaluate(async () => {
        const r = await window.axe.run(document, { runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'] }, resultTypes: ['violations'] });
        return r.violations.map((v) => ({ id: v.id, impact: v.impact, help: v.help, count: v.nodes.length, targets: v.nodes.slice(0, 4).map((n) => n.target.join(' ') + (n.any[0] ? ' :: ' + n.any[0].message : '')) }));
      });
    }
    const name = path.basename(file, '.html') + '-' + w + '-' + theme + '.png';
    if (outDir) {
      fs.mkdirSync(outDir, { recursive: true });
      await page.screenshot({ path: path.join(outDir, name), fullPage: full || true });
    }
    const height = await page.evaluate(() => document.documentElement.scrollHeight);
    const run = { width: w, theme, height, overflowX: overflow.over, wide: overflow.wide, consoleErrors: errors, axe };
    if (overflow.over > 0 || errors.length || (axe && axe.length)) { run.fail = true; report.ok = false; }
    if (outDir) run.png = path.join(outDir, name);
    report.runs.push(run);
    await page.close();
  }
}
await browser.close();
console.log(JSON.stringify(report, null, 1));
process.exit(report.ok ? 0 : 1);
