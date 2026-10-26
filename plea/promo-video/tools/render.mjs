// Renders the film (or a slice) to MP4: node tools/render.mjs <out.mp4> <fmt> <from s> <to s> [fps] [audio.wav]
// Frames are painted by window.seek(t), screenshotted by Playwright and piped to ffmpeg (H.264, yuv420p).
// With an audio file, the matching slice of it is muxed in (AAC 192k).
import { chromium } from '/opt/node-tools/node_modules/playwright/index.mjs';
import { spawn } from 'node:child_process';
import { serve } from './serve.mjs';

const [out, fmt, from, to, fpsArg, audio] = process.argv.slice(2);
const FPS = Number(fpsArg || 30), T0 = Number(from), T1 = Number(to);
const server = await serve(8124);
const browser = await chromium.launch();
const [w, h] = fmt === '9x16' ? [720, 1280] : [1280, 720];
const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: Number(process.env.SCALE || 1.5) });   // SCALE=0.75 → 960 x 540 drafts
const errors = [];
page.on('pageerror', (e) => errors.push(String(e)));
await page.goto(`http://127.0.0.1:8124/promo-video/src/index.html?fmt=${fmt}`);
await page.evaluate(() => window.ready);

const args = ['-y', '-v', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-i', '-'];
if (audio) args.push('-ss', String(T0), '-t', String(T1 - T0), '-i', audio);
args.push('-c:v', 'libx264', '-crf', '16', '-preset', 'medium', '-pix_fmt', 'yuv420p', '-r', String(FPS));
if (audio) args.push('-c:a', 'aac', '-b:a', '192k', '-shortest');
args.push(out);
const ff = spawn('ffmpeg', args, { stdio: ['pipe', 'inherit', 'inherit'] });
const n = Math.round((T1 - T0) * FPS);
const started = Date.now();
for (let i = 0; i < n; i++) {
  const t = T0 + i / FPS;
  await page.evaluate(async (t) => { await window.seek(t); }, t);
  const png = await page.locator('#stage').screenshot({ type: 'png' });
  if (!ff.stdin.write(png)) await new Promise((r) => ff.stdin.once('drain', r));
  if (i % (FPS * 5) === 0) console.log(`t=${t.toFixed(2)} (${i}/${n}) ${((Date.now() - started) / 1000).toFixed(0)} s`);
}
ff.stdin.end();
await new Promise((r) => ff.on('close', r));
if (errors.length) console.log('page errors:', errors.slice(0, 5).join('\n'));
await browser.close();
server.close();
