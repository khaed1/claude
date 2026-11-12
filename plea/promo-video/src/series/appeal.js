// §3 Appeal: a denied plea gets one appeal within 4 hours, judged by a fresh panel that reads the denied plea
// and its score; denied again means a 4-hour cooldown. Real data, Sepolia test run 9, seller 0x6828…8F4f:
// plea #1 denied 27 vs need 40 (Wed 13:25:12); appeal #2 sent Wed 14:44:24 (1 h 19 m later; facts 31 → 34 after
// the seller bought in, need 37), denied 30 vs need 37 (14:46:36). The same seller's plea #19 passed on Sat.
import { chrome, headline, recap, piece, verdict, typeInto, hms, keys } from './kit.js';
import { esc } from '../lib/ui.js';

const P1 = 'I got 2.5M PLEA from the airdrop when trading opened today and have held it for about 15 minutes. I want to sell 100,000 of it, 4% of my balance, to pay for gas.';
const P2 = 'Honoured Cabal, a fair verdict: my first plea was as plain as a gas receipt. Since then I bought in with my own imdTEST too. I still ask to sell 100,000 PLEA, 4% of my bag, to pay my gas; the rest stays and keeps playing the seasons. Thank you for reading me twice.';
const SENT = 79 * 60 + 12;   // the appeal went in 1 h 19 m 12 s after the denial

const card = (title, sub, body, cls = '') => `<div class="card ${cls}" style="width:560px;box-sizing:border-box;padding:16px 20px 18px;box-shadow:8px 8px 0 var(--shadow-color)">
  <div style="display:flex;justify-content:space-between;align-items:baseline"><span class="mono" style="font-size:19px">${title}</span><span class="meta" style="font-size:14px">${sub}</span></div>
  <div class="sx-body" style="margin-top:10px;font-size:18px;line-height:1.45;min-height:${body === null ? 160 : 0}px">${body ?? ''}</div></div>`;

export default {
  build(root, c) {
    const { BAR, AT } = c;
    const T = this.T = {
      steps: [BAR(2), AT(3, 2), BAR(5)], end: BAR(7),
      ask: BAR(0), card: AT(0, 1), denied: BAR(1),
      line: BAR(2) + 0.2, marker: AT(2, 1), type0: AT(2, 1.5), type1: AT(3, 1.5),
      orig: AT(3, 2.5), facts: BAR(4), score: AT(4, 2),
      again: AT(5, 0.5), cool: AT(5, 2), later: BAR(6),
    };
    this.layer = c.el('div', 'layer');
    root.appendChild(this.layer);
    const L = this.layer;
    this.chrome = chrome(L, root, c, { steps: ['Appeal', 'Re-judged', 'Cooldown'], at: T.steps, end: T.end });

    // Hook: plea #1, denied.
    this.ask = piece(L, c, 'Denied?', { cls: 'abs sx-big', left: 0, top: 118, at: T.ask, out: T.steps[0], dy: -30, kind: 'heavy' });
    Object.assign(this.ask.e.style, { right: '0', textAlign: 'center', fontSize: '76px' });
    this.hookCard = piece(L, c, card('Plea #1', 'Wed 13:22 · by 0x6828…8F4f', esc(`“${P1}”`)), { left: 360, top: 250, at: T.card, out: T.steps[0], dy: 60 });
    this.hookStamp = verdict(L, c, { state: 'denied', word: 'Denied', sub: '27 vs need 40', x: 820, y: 470 });

    // Step 1: the 4-hour appeal window from the denial; the appeal is written 1 h 19 m in.
    this.h1 = headline(L, c, { n: 1, lines: [['One', 'appeal,'], ['in', '4', 'hours.']], small: '0.5 IMD panel fee + 0.35 IMD to the buy wall', at: T.steps[0], out: T.steps[1] });
    this.line = piece(L, c, `<div style="width:584px">
      <div class="mono" style="display:flex;justify-content:space-between;font-size:15px;color:var(--ink-2)"><span>denied · Wed 13:25</span><span>window closes · 17:25</span></div>
      <div style="position:relative;height:26px;margin-top:8px;border:3px solid var(--ink);border-radius:8px;background:var(--card)">
        <span class="sx-fill" style="position:absolute;inset:0 auto 0 0;background:var(--action);border-right:3px solid var(--ink)"></span></div>
      <div class="mono sx-flag" style="position:absolute;top:58px;font-size:15px;white-space:nowrap;transform:translateX(-50%)">▲ appeal sent · 14:44 <span style="color:var(--ink-2)">(+1h 19m)</span></div></div>`,
      { left: 640, top: 150, at: T.line, out: T.steps[1], dy: -20 });
    this.fill = this.line.e.querySelector('.sx-fill');
    this.flag = this.line.e.querySelector('.sx-flag');
    this.appealCard = piece(L, c, card('Appeal of plea #1', 'Wed 14:44', null), { left: 650, top: 262, at: T.type0 - 0.3, dy: 50 });
    this.appealBody = this.appealCard.e.querySelector('.sx-body');

    // Step 2: a fresh panel reads the denied plea, its score and the new text; facts are read again.
    this.h2 = headline(L, c, { n: 2, lines: [['A', 'fresh', 'panel'], ['reads', 'both.']], small: 'the denied plea, its 27, and the new text', at: T.steps[1], out: T.steps[2] });
    this.origCard = piece(L, c, card('Plea #1 · denied 27 vs 40', 'Wed 13:22', esc(`“${P1.slice(0, 92)}…”`)), { left: 640, top: 128, at: T.orig, out: T.steps[2] + 0.2, dx: -40, dy: 0 });
    this.origCard.e.style.zIndex = '0';
    this.factsChip = piece(L, c, 'facts 31 → 34 · need 40 → 37', { cls: 'abs mono', left: 650, top: 548, at: T.facts, out: T.steps[2] + 0.3, dy: 20, kind: 'snappy' });
    Object.assign(this.factsChip.e.style, { fontSize: '17px', border: '3px solid var(--ink)', borderRadius: '8px', padding: '7px 12px', background: 'var(--card)' });
    this.scoreDisc = piece(L, c, '30', { cls: 'abs sx-big', left: 1090, top: 528, at: T.score, out: T.steps[2] + 0.3, dy: -30, kind: 'stamp' });
    Object.assign(this.scoreDisc.e.style, { width: '96px', height: '96px', boxSizing: 'border-box', borderRadius: '50%', background: 'var(--action)', color: 'var(--on-action)',
      border: '4px solid var(--ink)', display: 'grid', placeContent: 'center', fontSize: '44px', boxShadow: '6px 6px 0 var(--shadow-color)' });

    // Step 3: denied again, the 4-hour cooldown, and three days later the same seller's plea #19 passes.
    this.h3 = headline(L, c, { n: 3, lines: [['Denied', 'again?'], ['Wait', '4', 'hours.']], small: 'then plead anew: three days later, plea #19 passed', at: T.steps[2], out: T.end + 10 });
    this.again = verdict(L, c, { state: 'denied', word: 'Denied', sub: '30 vs need 37', x: 1010, y: 470 });
    this.cool = piece(L, c, `<div style="zoom:1.6"><span class="countdown countdown--wait"><svg class="icon"><use href="#i-timer"/></svg>Next plea in <span class="countdown__time">04:00:00</span></span></div>`,
      { left: 650, top: 584, at: T.cool, out: T.later, dy: 30 });
    this.coolTime = this.cool.e.querySelector('.countdown__time');
    this.later = piece(L, c, card('Plea #19 · three days later', 'Sat 16:12', esc('“Honoured Cabal, three days in, an IMD seat on the bench and four of your verdicts in my pocket…”')),
      { left: 650, top: 300, at: T.later, dy: 60, kind: 'heavy' });
    this.laterStamp = verdict(L, c, { state: 'approved', word: 'Approved', sub: '34 vs need 33', x: 1010, y: 470 });

    this.recap = recap(L, root, c, {
      at: T.end, sub: 'One more try.',
      rows: ['Denied? Appeal once, within 4 hours, with new text.', 'A fresh panel judges it on its own merits (0.85 IMD in all).', 'Denied again: a 4-hour cooldown, then plead anew.'],
      fine: 'Pleas #1, #2 and #19 are real (Sepolia test run 9) · Not financial advice · Music: “Spy Glass” Kevin MacLeod (incompetech.com), CC BY 4.0',
    });
  },

  update(t, c) {
    const { M } = c, T = this.T;
    this.chrome.update(t);
    this.ask.update(t);
    this.hookCard.update(t);
    this.hookStamp.update(t, T.denied, T.steps[0] + 0.3);
    this.hookStamp.e.style.opacity = 1 - M.ramp(t, T.steps[0], T.steps[0] + 0.3);

    this.h1.update(t);
    if (this.line.update(t)) {
      const k = M.sp(t - T.marker, 'heavy') * (SENT / 14400);
      this.fill.style.width = `${k * 100}%`;
      this.flag.style.left = `${k * 100}%`;
      c.show(this.flag, t >= T.marker + 0.3);
    }
    // The appeal card: typed in step 1, pushed back down-right in step 2, stamped in step 3, then gone.
    const shift = M.sp(t - T.orig, 'ui');
    if (this.appealCard.update(t, `translate(${shift * 24}px, ${shift * 40}px)`)) {
      typeInto(this.appealBody, `“${P2}”`, t, T.type0, T.type1);
      this.appealCard.e.style.opacity = 1 - M.ramp(t, T.later - 0.1, T.later + 0.1);
    }
    this.h2.update(t);
    this.origCard.update(t);
    this.origCard.e.style.opacity = Math.min(0.55, this.origCard.e.style.opacity);
    this.factsChip.update(t);
    this.scoreDisc.update(t, `scale(${M.mix(1.6, 1, M.sp(t - T.score, 'stamp'))})`);

    this.h3.update(t);
    this.again.update(t, T.again, T.later);
    if (this.cool.update(t)) this.coolTime.textContent = hms(14400 - Math.max(0, t - T.cool));
    this.later.update(t);
    this.laterStamp.update(t, T.later + 0.55);

    this.recap.update(t);
  },

  cues(c) {
    const T = this.T;
    const q = [[T.ask, 'thump', 0.63, 0.8], [T.card, 'whoosh', 0.8, 0.3, 400, 2400], [T.denied, 'thump', 0.35, 1.2],
      [T.steps[0], 'whoosh', 1.5, 0.35, 400, 2600], [T.marker, 'ratchet', 0.8, 6, 0.4], ...keys(c, T.type0, T.type1),
      [T.steps[1], 'pop', 1.0, 400, 800], [T.orig, 'whoosh', 0.8, 0.3, 300, 1800], [T.facts, 'tap', 1.0, 1000, 0.04], [T.score, 'thump', 0.5, 0.5],
      [T.steps[2], 'whoosh', 1.0, 0.35, 400, 2600], [T.again, 'thump', 0.31, 1.2], [T.cool, 'pop', 0.8],
      [T.cool + 1, 'tick', 2.5, 1600, 0.01, 0.4], [T.cool + 2, 'tick', 2.5, 1600, 0.01, 0.4],
      [T.later, 'whoosh', 2.4, 0.4, 300, 1800], [T.later + 0.55, 'thump', 0.7, 1.3], [T.later + 0.6, 'bell', 0.5, 1318, 0.4]];
    return [...q, ...this.recap.cues()].map(([t, ...r]) => [Math.round(t * 1000) / 1000, ...r]);
  },
};
