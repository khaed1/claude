// §4 Objection!: for 20 minutes after an approval anyone (not the seller) may object for 0.5 IMD + a 0.35 IMD
// stake; a fresh panel re-scores the plea. New score + 2 < need: SUSTAINED, no season points, stake back.
// Otherwise OVERRULED: the recorded score becomes the lower one and the stake goes to the season's prize pot.
// The sale is never touched. Real data, Sepolia test run 9: plea #21 (0xF73A…6dF0, 70,000 PLEA) approved
// 33 vs need 33 at Sat 16:15:48 and sold; objection #3 by 0x5e33…3e0A filed 16:17:12, overruled at 31.
import { chrome, headline, recap, piece, verdict, meter, typeInto, keys } from './kit.js';
import { esc } from '../lib/ui.js';

const PLEA = 'Your honours, three days, three pleas, three near misses, and my bag is still 97% where it was. I ask to sell 70,000 PLEA, under 3% of it, to pay this week’s gas.';
const OBJ = 'Plea #21 is honest and polite, but thin: this week’s gas is its only reason, with no detail, and it leans on its own near misses for sympathy. It was approved exactly at its need of 33.';
const NEED = 33, NEW = 31;
const M0 = { x: 640, y: 372, w: 576 };

const card = (title, sub, body, tag = '') => `<div class="card" style="width:584px;box-sizing:border-box;padding:14px 20px 16px;box-shadow:8px 8px 0 var(--shadow-color)">
  <div style="display:flex;justify-content:space-between;align-items:center;gap:10px"><span class="mono" style="font-size:19px">${title}</span>${tag}<span class="meta" style="font-size:14px;margin-left:auto">${sub}</span></div>
  <div class="sx-body" style="margin-top:8px;font-size:17px;line-height:1.42">${body}</div></div>`;
const tag = (state, word) => `<span class="stamp stamp--${state} stamp--sm" style="transform:none">${word}</span>`;

export default {
  build(root, c) {
    const { BAR, AT } = c;
    const T = this.T = {
      steps: [BAR(2), AT(3, 2), BAR(5)], end: BAR(7),
      ask: BAR(0), card: AT(0, 1), slam: BAR(1),
      win: BAR(2) + 0.25, filed: AT(2, 1), type0: AT(2, 1.5), type1: AT(3, 1.5),
      meter: AT(3, 2.5), zone: BAR(4), rise0: AT(4, 1), rise1: AT(4, 2.5), sold: AT(3, 3),
      ruling: AT(5, 0.5), stake: AT(5, 2), points: BAR(6),
    };
    this.layer = c.el('div', 'layer');
    root.appendChild(this.layer);
    const L = this.layer;
    this.chrome = chrome(L, root, c, { steps: ['Object', 'Re-score', 'Ruling'], at: T.steps, end: T.end });

    // Hook: an approval at exactly its bar, and OBJECTION! slams onto it.
    this.ask = piece(L, c, 'Think it got off easy?', { cls: 'abs sx-big', left: 0, top: 120, at: T.ask, out: T.steps[0], dy: -30 });
    Object.assign(this.ask.e.style, { right: '0', textAlign: 'center', fontSize: '54px' });
    this.hookCard = piece(L, c, card('Plea #21', 'Sat 16:13 · by 0xF73A…6dF0', esc(`“${PLEA}”`), tag('approved', 'Approved 33 vs 33')), { left: 348, top: 240, at: T.card, out: T.steps[0], dy: 60 });
    this.slam = verdict(L, c, { state: 'objection', word: 'Objection!', x: 640, y: 420, zoom: 2.1, tilt: -6 });

    // Step 1: the 20-minute window opens at the verdict; the objection is written 1 m 24 s in.
    this.h1 = headline(L, c, { n: 1, lines: [['Object', 'within'], ['20', 'minutes.']], small: 'after any approval · 0.5 IMD fee + 0.35 IMD stake', at: T.steps[0], out: T.steps[1] });
    this.pleaCard = piece(L, c, card('Plea #21', '33 vs need 33', esc(`“${PLEA.slice(0, 96)}…”`), `${tag('approved', 'Approved')}<span class="sx-sold" style="display:none">${tag('sold', 'Sold')}</span>`),
      { left: 640, top: 120, at: T.steps[0] + 0.1, out: T.end, dx: 60, dy: 0 });
    this.soldTag = this.pleaCard.e.querySelector('.sx-sold');
    this.win = piece(L, c, `<div style="width:584px">
      <div class="mono" style="display:flex;justify-content:space-between;font-size:15px;color:var(--ink-2)"><span>approved · 16:15:48</span><span>objections close · 16:35:48</span></div>
      <div style="position:relative;height:22px;margin-top:6px;border:3px solid var(--ink);border-radius:8px;background:var(--card)">
        <span class="sx-fill" style="position:absolute;inset:0 auto 0 0;background:var(--objection);border-right:3px solid var(--ink)"></span></div>
      <div class="mono sx-flag" style="position:absolute;top:50px;font-size:15px;white-space:nowrap">▲ objection filed · 16:17:12 <span style="color:var(--ink-2)">(+1m 24s)</span></div></div>`,
      { left: 640, top: 262, at: T.win, out: T.steps[1], dy: 20 });
    this.winFill = this.win.e.querySelector('.sx-fill');
    this.winFlag = this.win.e.querySelector('.sx-flag');
    this.objCard = piece(L, c, card('Objection to plea #21', 'by 0x5e33…3e0A', ''), { left: 640, top: 360, at: T.type0 - 0.3, out: T.steps[1], dy: 50 });
    this.objBody = this.objCard.e.querySelector('.sx-body');
    this.objBody.style.minHeight = '120px';

    // Step 2: a second panel re-scores; below need − 2 would sustain. The sale already happened and stands.
    this.h2 = headline(L, c, { n: 2, lines: [['A', 'second', 'panel'], ['re-scores', 'it.']], small: 'the sale stands either way', at: T.steps[1], out: T.steps[2] });
    this.m = meter(L, c, { x: M0.x, y: M0.y, w: M0.w, need: NEED });
    this.m.box.querySelector('.meter__fill').style.background = 'var(--objection)';
    this.zone = piece(L, c, `<div style="width:${(NEED - 2) / 45 * M0.w}px;height:44px;box-sizing:border-box;background:repeating-linear-gradient(-45deg, rgba(255,90,78,.45) 0 10px, transparent 10px 20px);border-right:4px dashed var(--denied)"></div>
      <div class="mono" style="position:absolute;right:-4px;top:-34px;transform:translateX(50%);white-space:nowrap;font-size:16px;color:var(--denied-text)">sustained below ${NEED - 2}</div>`,
      { left: M0.x, top: M0.y, at: T.zone, out: T.end, dy: 0 });
    this.newDisc = piece(L, c, `${NEW}`, { cls: 'abs sx-big', left: M0.x + (NEW / 45) * M0.w - 32, top: M0.y - 104, at: T.rise1 - 0.1, out: T.end, dy: -20, kind: 'snappy' });
    Object.assign(this.newDisc.e.style, { width: '64px', height: '64px', boxSizing: 'border-box', borderRadius: '50%', background: 'var(--objection)', color: 'var(--on-state)',
      border: '3px solid var(--ink)', display: 'grid', placeContent: 'center', fontSize: '30px' });

    // Step 3: OVERRULED; the stake flies to the prize pot; the plea's points fall to the lower score.
    this.h3 = headline(L, c, { n: 3, lines: [['Overruled:'], ['stake', 'to'], ['the', 'pot.']], small: 'more than 2 below the bar: sustained, no points', at: T.steps[2], out: T.end + 10 });
    this.ruling = verdict(L, c, { state: 'objection', word: 'Overruled', sub: `${NEW} vs need ${NEED}`, x: 800, y: 548, zoom: 1.0 });
    this.coin = piece(L, c, '0.35 IMD', { cls: 'abs mono', left: 770, top: 540, at: T.stake, out: T.end, dy: 0, kind: 'heavy' });
    Object.assign(this.coin.e.style, { fontSize: '17px', background: 'var(--action)', color: 'var(--on-action)', border: '3px solid var(--ink)', borderRadius: '999px', padding: '6px 12px' });
    this.pot = piece(L, c, '<div class="mono" style="font-size:15px;color:var(--ink-2)">season prize pot</div><div class="sx-big sx-pot" style="font-size:26px">+0.35 IMD</div>',
      { left: 1060, top: 520, at: T.stake - 0.2, out: T.end, dx: 40, dy: 0 });
    Object.assign(this.pot.e.style, { border: '3px dashed var(--ink)', borderRadius: '12px', padding: '10px 14px', textAlign: 'center' });
    this.potVal = this.pot.e.querySelector('.sx-pot');
    this.pts = piece(L, c, `plea #21's points: <s>33</s> → ${NEW} <span style="color:var(--ink-2)">(scores only fall)</span>`, { cls: 'abs mono', left: 640, top: 622, at: T.points, out: T.end, dy: 20, kind: 'snappy' });
    Object.assign(this.pts.e.style, { fontSize: '17px' });

    this.recap = recap(L, root, c, {
      at: T.end, sub: 'Points on trial, never the sale.',
      rows: ['Anyone may object to an approval within 20 minutes (0.85 IMD).', 'A fresh panel re-scores. More than 2 below the bar: SUSTAINED, no points.', 'Otherwise OVERRULED: the stake joins the prize pot. The sale stands.'],
      fine: 'Plea #21 and its objection are real (Sepolia test run 9) · Not financial advice · Music: “Spy Glass” Kevin MacLeod (incompetech.com), CC BY 4.0',
    });
  },

  update(t, c) {
    const { M } = c, T = this.T;
    this.chrome.update(t);
    this.ask.update(t);
    this.hookCard.update(t);
    this.slam.update(t, T.slam, T.steps[0] + 0.3);
    this.slam.e.style.opacity = 1 - M.ramp(t, T.steps[0], T.steps[0] + 0.3);
    this.layer.style.translate = `0 ${M.jolt(t - T.slam - 0.05, 10)}px`;

    this.h1.update(t);
    this.pleaCard.update(t);
    this.soldTag.style.display = t >= T.sold ? '' : 'none';
    if (this.win.update(t)) {
      const k = M.sp(t - T.filed, 'heavy') * (84 / 1200);
      this.winFill.style.width = `${k * 100}%`;
      this.winFlag.style.left = `${k * 100}%`;
      c.show(this.winFlag, t >= T.filed + 0.3);
    }
    if (this.objCard.update(t)) typeInto(this.objBody, `“${OBJ}”`, t, T.type0, T.type1);

    this.h2.update(t);
    const mOn = t >= T.meter;
    this.m.e.style.display = mOn ? '' : 'none';
    if (mOn) {
      const k = M.sp(t - T.meter, 'ui');
      this.m.e.style.transform = `translateX(${(1 - k) * 60}px)`;
      this.m.e.style.opacity = k * (1 - M.ramp(t, T.end, T.end + 0.3));
      this.m.set(NEW * (1 - Math.pow(1 - M.ramp(t, T.rise0, T.rise1), 2.2)), { state: 'objection' });
      this.m.showNeed(t, T.meter + 0.2);
    }
    this.zone.update(t);
    this.newDisc.update(t);

    this.h3.update(t);
    this.ruling.update(t, T.ruling);
    // The stake leaves the stamp and lands in the pot.
    const fly = M.sp(t - T.stake, 'heavy');
    this.coin.update(t, `translate(${fly * 300}px, ${-fly * 4 - Math.sin(Math.PI * Math.min(1, fly)) * 60}px) scale(${1 - 0.3 * M.ramp(t, T.stake + 0.35, T.stake + 0.5)})`);
    this.coin.e.style.opacity = 1 - M.ramp(t, T.stake + 0.4, T.stake + 0.5);
    this.pot.update(t);
    c.show(this.potVal, t >= T.stake + 0.45);
    this.pts.update(t);

    this.recap.update(t);
  },

  cues(c) {
    const T = this.T;
    const q = [[T.ask, 'pop', 2.2], [T.card, 'whoosh', 0.8, 0.3, 400, 2400], [T.slam, 'slam', 0.2],
      [T.steps[0], 'whoosh', 1.5, 0.35, 400, 2600], [T.filed, 'ratchet', 0.8, 5, 0.3], ...keys(c, T.type0, T.type1), [T.sold, 'tap', 1.0, 1800, 0.015],
      [T.steps[1], 'pop', 1.0, 400, 800], [T.zone, 'scratch', 2.4, 0.25], [T.rise0, 'ratchet', 1.0, 10, T.rise1 - T.rise0 - 0.1], [T.rise1, 'tap', 1.2, 900, 0.04],
      [T.steps[2], 'whoosh', 1.0, 0.35, 400, 2600], [T.ruling, 'slam', 0.2], [T.stake, 'whoosh', 0.8, 0.4, 600, 3000], [T.stake + 0.45, 'bell', 0.6, 1318, 0.4],
      [T.points, 'pop', 1.0]];
    return [...q, ...this.recap.cues()].map(([t, ...r]) => [Math.round(t * 1000) / 1000, ...r]);
  },
};
