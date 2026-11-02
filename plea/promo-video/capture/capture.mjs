// Captures the run 9 site at the promo video's moments (SHOTLIST.md, "Captures to make").
//   node capture.mjs [moment ...]     (no argument: every moment)
// Env: CAPTURE_OUT=<dir> (default: ./out). Each moment writes PNGs and a meta.json
// (block, clock, route, wallet, console errors) into <out>/<moment>/.
// Blocks come from the run 9 chain events (CabalGate Verdict, Tribunal Ruled,
// Seasons PrizePaid); see the comments on each moment. Each fork at block N also gets
// one empty local block stamped at the clock (see harness stampHead), because the
// site's countdowns run from the chain head's time.

import { mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import * as H from './harness.mjs';

const OUT = process.env.CAPTURE_OUT || join(dirname(fileURLToPath(import.meta.url)), 'out');
const P2 = '0xB45Acc9b62f43d5D69Bb5195b74743a721641811';
// Plea #14's real text (tx 0x93c1aaf5…, block 11971313): 268 bytes, all ASCII.
const PLEA14_TEXT = 'Dear judges, today your server took a long lunch and my plea came back from it with a 33. No complaint: I bought a day ago, I am still under water, and I need 90,000 PLEA, about 3%, to pay the fees of staying in this game. Everything else I hold stays for the seasons.';
const PLEA14_AMOUNT = '90000'; // submitSell(90000e18, text)

const iso = (ms) => new Date(ms).toISOString().replace('.000', '');
let port = 18700;

/** Fork at `block`, clock = block time + `plusS`, open `route`, settle; run `body`. */
async function atBlock({ moment, block, plusS, route, wallet, warmAct, ready }, body) {
  const dir = join(OUT, moment);
  mkdirSync(dir, { recursive: true });
  const ts = H.blockTimestamp(block);
  const clockMs = (ts + plusS) * 1000;
  console.log(`${moment}: block ${block} (${iso(ts * 1000)}), clock ${iso(clockMs)}, ${route}${wallet ? ', wallet ' + wallet : ''}`);
  const anvil = await H.startAnvil(block, port++);
  try {
    // The site's countdowns run from the head block's time: stamp an empty local head at the clock.
    const head = await H.stampHead(anvil, ts + plusS);
    const opts = { anvil, clockMs, wallet };
    await H.warm(route, opts, { act: warmAct, ready });
    // A load can still hit a cold call; retry the whole load if the site shows an RPC error.
    for (let attempt = 1; ; attempt++) {
      const s = await H.openSite(route, opts);
      try {
        await H.settle(s.page, { ready });
        if (wallet) { await H.connectWallet(s.page, wallet); await H.settle(s.page, { ready }); }
        if (await H.hasRpcError(s.page)) throw new Error('site shows an RPC error');
        await s.page.mouse.move(1435, 450); // park the pointer in the empty right margin
        const extra = (await body(s.page, dir)) || {};
        if (await H.hasRpcError(s.page)) throw new Error('site shows an RPC error');
        return { block, blockTime: iso(ts * 1000), clock: iso(clockMs), forkUrl: anvil.forkUrl, localHead: head.mined ? `${head.number} (empty, local, stamped at the clock)` : null, route, wallet: wallet || null, rpcRequests: s.log.rpc, rpcHosts: [...s.log.rpcHosts], slowestRpcMs: s.log.slowestMs, unroutedRpc: s.log.unrouted, console: s.log.console, pageErrors: s.log.pageErrors, ...extra };
      } catch (e) {
        if (attempt >= 3) throw e;
        console.log(`  attempt ${attempt} failed (${e.message}); retrying`);
      } finally {
        await s.close();
      }
    }
  } finally {
    await anvil.stop();
  }
}

/** Visible text of the page's main area, for a quick check in meta.json. */
const mainText = (page) => page.evaluate(() => (document.querySelector('main') || document.body).innerText.replace(/\n{2,}/g, '\n').slice(0, 1500));
const stripText = (page) => page.evaluate(() => document.querySelector('.status-strip')?.innerText.replace(/\s+/g, ' ').trim() || '');

const moments = {
  // 1. Plead page as p2 saw it the block before plea #14 (submitted in 11971313).
  // The amount and plea #14's text are typed with real key events, one frame per
  // character. "Sell automatically" is switched off: #14 was a plain submitSell
  // (oracle fee from imdTEST), and with it on the form wants >= 122,181 PLEA.
  async 'plead-typing'() {
    const warmAct = async (page) => {
      await page.locator('#plea-amount').fill(PLEA14_AMOUNT);
      await H.settle(page, { timeout: 60_000 });
      await page.locator('label.toggle-card').click();
      await H.settle(page, { timeout: 60_000 });
      await page.locator('textarea').fill(PLEA14_TEXT);
      await H.settle(page, { timeout: 60_000 });
    };
    const meta = await atBlock({ moment: 'plead-typing', block: 11971312, plusS: 20, route: '#/plead', wallet: P2, warmAct }, async (page, dir) => {
      await H.shootPair(page, dir, 'connected');
      // Amount: real keystrokes into the amount field.
      await page.locator('#plea-amount').click();
      await page.keyboard.type(PLEA14_AMOUNT, { delay: 90 });
      await H.settle(page);
      // Auto-sell off (see above); the fact score reads 36, need 35.
      const toggle = page.locator('label.toggle-card input');
      if (await toggle.isChecked()) await page.locator('label.toggle-card').click();
      await H.settle(page);
      await page.mouse.move(1435, 450);
      await page.evaluate(() => window.scrollTo(0, 0));
      await H.shootPair(page, dir, 'amount');

      // Boxes (CSS px, viewport-relative) of the four controls, at the current scroll.
      const measure = () => page.evaluate(() => {
        const box = (el) => { const r = el.getBoundingClientRect(); return { x: Math.round(r.x * 10) / 10, y: Math.round(r.y * 10) / 10, width: Math.round(r.width * 10) / 10, height: Math.round(r.height * 10) / 10 }; };
        const ta = document.querySelector('textarea');
        const amount = document.querySelector('#plea-amount');
        const submit = [...document.querySelectorAll('button.btn--primary')].find((x) => /Submit plea/.test(x.textContent));
        return {
          textarea: box(ta),
          textareaFrame: box(ta.parentElement), // the outlined box: textarea + counter footer
          byteCounter: box(document.querySelector('.counter')),
          byteCounterText: document.querySelector('.counter').innerText.trim(),
          amountField: box(amount.parentElement), // the outlined amount box (input + "PLEA")
          amountInput: box(amount),
          sendButton: box(submit),
          sendButtonLabel: submit.innerText.replace(/\s+/g, ' ').trim(),
        };
      });
      const atTop = await measure();

      // One scroll for every frame: "Your plea" label 16 px under the top edge (the need
      // meter above it leaves the frame), as long as the Submit button still fits.
      const ta = page.locator('textarea');
      const btn = page.locator('button.btn--primary', { hasText: 'Submit plea' });
      const scrollY = await page.evaluate(() => {
        const label = [...document.querySelectorAll('label, .field__label')].find((l) => /Your plea/.test(l.textContent));
        const top = label.getBoundingClientRect().top + scrollY;
        const b = [...document.querySelectorAll('button.btn--primary')].find((x) => /Submit plea/.test(x.textContent));
        const bottom = b.getBoundingClientRect().bottom + scrollY;
        const y = Math.round(top - 16);
        if (bottom - y > innerHeight - 16) throw new Error('Submit does not fit under the plea box');
        window.scrollTo(0, y);
        return window.scrollY;
      });
      await H.sleep(300);
      const shotDir = dir;
      await H.shoot(page, join(shotDir, 'empty.png'));
      const atFramesEmpty = await measure();

      const frames = [];
      for (let i = 0; i < PLEA14_TEXT.length; i++) {
        // Focus without scrolling, caret at the end, then one real key event.
        await ta.evaluate((el) => { el.focus({ preventScroll: true }); const n = el.value.length; el.setSelectionRange(n, n); });
        await page.keyboard.type(PLEA14_TEXT[i]);
        const n = Buffer.byteLength(PLEA14_TEXT.slice(0, i + 1));
        await page.locator('.counter', { hasText: `${n} / 280 bytes` }).waitFor({ timeout: 10_000 });
        const y = await page.evaluate(() => window.scrollY);
        if (y !== scrollY) throw new Error(`scroll moved to ${y} at frame ${i}`);
        const file = `${String(i).padStart(4, '0')}.png`;
        await H.shoot(page, join(shotDir, file));
        frames.push({ file, chars: i + 1, bytes: n, last: PLEA14_TEXT[i] });
      }
      if ((await ta.inputValue()) !== PLEA14_TEXT) throw new Error('typed text does not match');

      // Pointer over Submit (hover style); never clicked.
      const bb = await btn.boundingBox();
      await page.mouse.move(bb.x + bb.width / 2, bb.y + bb.height / 2, { steps: 8 });
      await H.sleep(400);
      await H.shoot(page, join(shotDir, 'hover.png'));
      await page.mouse.move(1435, 450);
      await H.shoot(page, join(shotDir, 'typed-full.png'), { fullPage: true });

      const atFramesTyped = await measure();
      H.writeJson(join(dir, 'boxes.json'), {
        note: 'CSS px (screenshots are 2x), relative to the 1440x900 viewport. "frames" = at frameScrollY (empty.png, NNNN.png, hover.png); "framesTyped" = same scroll after all 268 bytes (the counter text widens); "top" = at scrollY 0 (connected.png, amount.png). NNNN.png = after character NNNN+1 (0000 = 1 char, 0267 = all 268). The amount field is above the frames\' viewport (negative y there).',
        viewport: { width: 1440, height: 900, deviceScaleFactor: 2 },
        frameScrollY: scrollY,
        frames: atFramesEmpty,
        framesTyped: atFramesTyped,
        top: atTop,
      });
      H.writeJson(join(dir, 'frames.json'), frames);
      return { scrollY, frames: frames.length, amount: PLEA14_AMOUNT, autoSell: false, strip: await stripText(page) };
    });
    H.writeJson(join(OUT, 'plead-typing', 'meta.json'), meta);
  },

  // 2. Plea #1 (submitted 11962681): pending in 11962695, denied 27 vs need 40 in 11962696.
  async 'plea1-denied'() {
    const dir = join(OUT, 'plea1-denied');
    const pending = await atBlock({ moment: 'plea1-denied', block: 11962695, plusS: 5, route: '#/p/1' }, async (page, d) => {
      await H.shootPair(page, d, 'pending');
      return { strip: await stripText(page), text: await mainText(page) };
    });
    const denied = await atBlock({ moment: 'plea1-denied', block: 11962696, plusS: 30, route: '#/p/1' }, async (page, d) => {
      await H.shootPair(page, d, 'denied');
      return { strip: await stripText(page), text: await mainText(page) };
    });
    H.writeJson(join(dir, 'meta.json'), { pending, denied });
  },

  // 3. Plea #14 approved (Verdict 35 in 11971327), sold in 11971328: fork at the verdict
  // block, clock 60 s after it, so "Sell within" reads about 06:00.
  async 'plea14-approved'() {
    const meta = await atBlock({ moment: 'plea14-approved', block: 11971327, plusS: 60, route: '#/p/14', wallet: P2 }, async (page, dir) => {
      await H.shootPair(page, dir, 'approved');
      const sell = page.getByRole('button', { name: /Sell now/i }).first();
      await sell.scrollIntoViewIfNeeded();
      const bb = await sell.boundingBox();
      await page.mouse.move(bb.x + bb.width / 2, bb.y + bb.height / 2, { steps: 8 });
      await H.sleep(400);
      await H.shoot(page, join(dir, 'hover-sell.png'));
      return { sellButton: bb, scrollYHover: await page.evaluate(() => scrollY), strip: await stripText(page), text: await mainText(page) };
    });
    H.writeJson(join(OUT, 'plea14-approved', 'meta.json'), meta);
  },

  // 4. Plea #14 sold (executeSell in 11971328), before the objections (11971332/33).
  async 'plea14-sold'() {
    const meta = await atBlock({ moment: 'plea14-sold', block: 11971328, plusS: 30, route: '#/p/14', wallet: P2 }, async (page, dir) => {
      await H.shootPair(page, dir, 'sold');
      return { strip: await stripText(page), text: await mainText(page) };
    });
    H.writeJson(join(OUT, 'plea14-sold', 'meta.json'), meta);
  },

  // 5. Plea #14 after both objections were sustained (Tribunal Ruled: objection 2 in
  // 11971346, objection 1 in 11971348; 35 -> 32 each).
  async 'plea14-objected'() {
    const meta = await atBlock({ moment: 'plea14-objected', block: 11971348, plusS: 30, route: '#/p/14' }, async (page, dir) => {
      await H.shootPair(page, dir, 'objected');
      return { strip: await stripText(page), text: await mainText(page) };
    });
    H.writeJson(join(OUT, 'plea14-objected', 'meta.json'), meta);
  },

  // 6. Seasons: (a) 11986640, season key 15 (shown as "Season 16") ended, awaiting
  // close; (b) 11986643, closeSeason tx 0x141da3fb… (PrizePaid to p1, rank 1). The
  // "Past seasons" list loads after everything else and shows no loader, so wait for it.
  async seasons() {
    const ready = () => {
      const h = [...document.querySelectorAll('h2')].find((e) => /Past seasons/.test(e.textContent));
      return !!h && !!(h.closest('section') || h.parentElement.parentElement).querySelector('article');
    };
    // Scroll so `heading` (an h2/h3 text) sits 24 px under the top edge.
    const scrollToHeading = (page, re) => page.evaluate((src) => {
      const re = new RegExp(src);
      const h = [...document.querySelectorAll('h2, h3')].find((e) => re.test(e.textContent));
      const card = h.closest('.panel, article') || h;
      window.scrollTo(0, Math.round(card.getBoundingClientRect().top + scrollY - 24));
      return scrollY;
    }, re.source);
    const before = await atBlock({ moment: 'seasons', block: 11986640, plusS: 20, route: '#/seasons', ready }, async (page, d) => {
      await H.shootPair(page, d, 'a-before-close');
      const y = await scrollToHeading(page, /leaderboard/);
      await H.shoot(page, join(d, 'a-leaderboard.png'));
      return { leaderboardScrollY: y, strip: await stripText(page), text: await mainText(page) };
    });
    const closed = await atBlock({ moment: 'seasons', block: 11986643, plusS: 20, route: '#/seasons', ready }, async (page, d) => {
      await H.shootPair(page, d, 'b-closed');
      const y = await scrollToHeading(page, /^Past seasons$/);
      await H.shoot(page, join(d, 'b-past-season16.png'));
      const past = await page.evaluate(() => [...document.querySelectorAll('article')].find((a) => /Season 16/.test(a.querySelector('h3')?.textContent || ''))?.innerText.replace(/\n+/g, ' | '));
      return { pastSeasonsScrollY: y, season16: past, strip: await stripText(page), text: await mainText(page) };
    });
    H.writeJson(join(OUT, 'seasons', 'meta.json'), { before, closed });
  },

  // 7. The live site today (the Cabal is dead), dark theme, no fork, real clock.
  async 'dead-dark'() {
    const dir = join(OUT, 'dead-dark');
    mkdirSync(dir, { recursive: true });
    const meta = {};
    for (const [route, name] of [['#/', 'home'], ['#/plead', 'plead'], ['#/p/14', 'p14']]) {
      const s = await H.openSite(route, { live: true, theme: 'dark' });
      try {
        await H.settle(s.page);
        await s.page.mouse.move(1435, 450);
        await H.shootPair(s.page, dir, name);
        meta[name] = { route, capturedAt: new Date().toISOString(), rpcError: await H.hasRpcError(s.page), strip: await stripText(s.page), console: s.log.console, pageErrors: s.log.pageErrors, text: await mainText(s.page) };
        console.log(`dead-dark ${route}: done`);
      } finally {
        await s.close();
      }
    }
    H.writeJson(join(dir, 'meta.json'), meta);
  },
};

const wanted = process.argv.slice(2);
const names = wanted.length ? wanted : Object.keys(moments);
for (const n of names) if (!moments[n]) { console.error(`unknown moment ${n}; known: ${Object.keys(moments).join(', ')}`); process.exit(2); }
let failed = 0;
const stopAll = async () => { await H.stopAllAnvils(); await H.closeBrowser(); };
process.on('SIGINT', () => stopAll().then(() => process.exit(130)));
try {
  for (const n of names) {
    try { await moments[n](); console.log(`${n}: ok`); }
    catch (e) { failed++; console.error(`${n}: FAILED ${e.stack || e}`); }
  }
} finally {
  await stopAll();
}
process.exit(failed ? 1 : 0);
