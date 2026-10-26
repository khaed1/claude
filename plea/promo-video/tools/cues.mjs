// Dumps an explainer clip's sound cues (its scene's cues(), on the clip's beat grid) for tools/sfx.py series:
// node tools/cues.mjs <clipN> <out.json>
import { chromium } from '/opt/node-tools/node_modules/playwright/index.mjs';
import { writeFileSync } from 'node:fs';
import { serve } from './serve.mjs';

const [film, out] = process.argv.slice(2);
const server = await serve(8125);
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
await page.goto(`http://127.0.0.1:8125/promo-video/src/index.html?fmt=16x9&film=${film}`);
await page.evaluate(() => window.ready);
const spec = await page.evaluate(() => window.cues());
writeFileSync(out, JSON.stringify(spec));
console.log(spec.cues.length, 'cues,', spec.length, 's →', out);
await browser.close();
server.close();
