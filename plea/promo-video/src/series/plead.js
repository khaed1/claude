// §1 Plead: you can't just sell PLEA; you write a plea, the Cabal's panel scores it, and if it clears your bar
// you get 7 minutes to sell. Real data: plea #19 of Sepolia test run 9 (Sat 16:12 UTC, seat holder 0x6828…8F4f),
// its IMD panel (request bfc7011e…: 18 answers, 17 agreed on 34, the 28 outside the band), need 33, sold 90,000 PLEA.
// Music: the clip edit of "Spy Glass" (bars 0, 2, 4 and 6 open with the riff's hit; the closing hit is c.HIT).
import { stamp, esc } from '../lib/ui.js';
import { chrome, headline, cursor, press, recap } from './kit.js';

const TEXT = 'Honoured Cabal, three days in, an IMD seat on the bench and four of your verdicts in my pocket, each a point or two short. I ask once more, plainly: 90,000 PLEA, about 3% of my bag, to pay the gas these pleas have cost. The rest stays for the seasons to come.';
const PANEL = [['398', 35], ['485', 34], ['94', 30], ['1876', 33], ['1604', 34], ['1126', 39], ['1470', 31], ['246', 35], ['1814', 35],
  ['1211', 34], ['1979', 33], ['1511', 30], ['212', 36], ['1641', 37], ['1773', 31], ['1646', 30], ['1487', 28], ['652', 35]];   // API order
const ANSWER = 34, NEED = 33, OUT = '1487';
const RING = { x: 930, y: 392, r: 212 };
const METER = { x: 640, y: 262, w: 576 };
const RIDER_X = METER.x + (ANSWER / 45) * METER.w;   // the answer waits over its spot on the meter; the fill rises to it
const SUBMIT = [1108, 424], SELL = [1050, 556];   // where the cursor presses Submit plea and Sell now

export default {
  build(root, c) {
    const { BAR, AT } = c;
    this.T = {
      steps: [BAR(2), AT(3, 2), BAR(5)], end: BAR(7),
      ask: BAR(0), btn: AT(0, 1.5), click: AT(0, 2.5), no: BAR(1),
      type0: AT(2, 1), type1: BAR(3), submit: AT(3, 1), fly: AT(3, 1.5),
      seats: AT(3, 2), ans: AT(3, 2.5), gap: 0.075, strike: AT(4, 1), answer: AT(4, 2),
      meter: BAR(5), need: AT(5, 0.5), fill0: AT(5, 1), fill1: AT(5, 3), approved: BAR(6), window: AT(6, 0.5), sell: AT(6, 2), sold: AT(6, 2.5),
    };
    const T = this.T;
    this.layer = c.el('div', 'layer');
    root.appendChild(this.layer);
    const L = this.layer;
    this.chrome = chrome(L, root, c, { steps: ['Write', 'Judged', 'Sell'], at: T.steps, end: T.end });

    // Hook: "Want to sell PLEA?", the Sell button, a click, and the stamp that says no.
    this.ask = c.el('div', 'abs sx-big', ['Want', 'to', 'sell', 'PLEA?'].map((w) => `<span class="mask"><span>${w}</span></span>`).join(' '));
    Object.assign(this.ask.style, { left: '0', right: '0', top: '150px', textAlign: 'center', fontSize: '58px' });
    this.askWords = [...this.ask.querySelectorAll('.mask > span')];
    this.sellBtn = c.el('div', 'abs', '<div style="zoom:2.2"><button class="btn btn--primary">Sell<span class="btn__sub">90,000 PLEA</span></button></div>');
    Object.assign(this.sellBtn.style, { left: '0', right: '0', top: '300px', textAlign: 'center' });
    this.no = c.el('div', 'abs', `<div style="zoom:1.5">${stamp('denied', 'No plea, no sale', 'every sell needs an approved plea')}</div>`);
    Object.assign(this.no.style, { left: '0', right: '0', top: '330px', textAlign: 'center' });
    L.append(this.ask, this.sellBtn, this.no);

    // Step 1: the plea editor (the site's textarea, byte counter and Submit plea), typed by plea #19's writer.
    this.h1 = headline(L, c, { n: 1, lines: [['Write', 'your'], ['case.']], small: 'One plea · up to 280 bytes · any language', at: T.steps[0], out: T.steps[1] });
    this.editor = c.el('div', 'abs');
    this.editor.innerHTML = `<div class="card" style="width:584px;box-sizing:border-box;padding:18px 20px 20px;box-shadow:8px 8px 0 var(--shadow-color)">
      <div style="display:flex;align-items:center;gap:10px;margin-bottom:12px"><span class="label" style="font-size:15px">Your plea</span>
        <span class="meta" style="margin-left:auto;font-family:var(--font-mono);font-size:14px">by 0x6828…8F4f</span><span class="badge badge--seat">SEAT ×1.2</span></div>
      <div class="textarea"><div class="sx-text" style="min-height:204px;padding:12px 16px;font-size:20px;line-height:1.45"></div>
        <div class="textarea__bar"><span class="counter"><span class="counter__meter"><span></span></span><span class="sx-count">0 / 280 bytes</span></span>
        <button class="btn btn--primary btn--sm">Submit plea</button></div></div></div>`;
    Object.assign(this.editor.style, { left: '640px', top: '134px', transformOrigin: '50% 50%' });
    this.textEl = this.editor.querySelector('.sx-text');
    this.countEl = this.editor.querySelector('.sx-count');
    this.countBar = this.editor.querySelector('.counter__meter > span');
    this.submit = this.editor.querySelector('.btn');
    L.appendChild(this.editor);

    // Step 2: 30 seats in a ring around the plea; 18 answer, 17 agree, the answer lands in the middle.
    this.h2 = headline(L, c, { n: 2, lines: [['30', 'judges'], ['score', 'it.']], small: 'IMD oracle panel · 17 must agree', at: T.steps[1], out: T.steps[2] });
    const rand = c.M.rng(19);
    const slots = [...Array(30).keys()];
    for (let i = slots.length - 1; i > 0; i--) { const j = Math.floor(rand() * (i + 1)); [slots[i], slots[j]] = [slots[j], slots[i]]; }
    const bySlot = new Map(PANEL.map((p, k) => [slots[k], k]));
    this.seats = [];
    for (let s = 0; s < 30; s++) {
      const a = -Math.PI / 2 + (s / 30) * Math.PI * 2;
      const e = c.el('div', 'sx-seat');
      const x = RING.x + RING.r * Math.cos(a), y = RING.y + RING.r * Math.sin(a);
      Object.assign(e.style, { left: `${x}px`, top: `${y}px` });
      const k = bySlot.get(s);
      if (k !== undefined) e.textContent = PANEL[k][1];
      L.appendChild(e);
      this.seats.push({ e, s, x, y, k, out: k !== undefined && PANEL[k][0] === OUT });
    }
    this.mini = c.el('div', 'abs card', `<div class="mono" style="font-size:19px">Plea #19</div><div class="meta" style="font-size:14px;margin-top:2px">sell 90,000 PLEA</div>`);
    Object.assign(this.mini.style, { left: `${RING.x - 92}px`, top: `${RING.y - 40}px`, width: '184px', boxSizing: 'border-box', padding: '12px 16px', textAlign: 'center' });
    this.disc = c.el('div', 'abs', `<div class="sx-big" style="width:132px;height:132px;box-sizing:border-box;border-radius:50%;background:var(--action);color:var(--on-action);border:4px solid var(--ink);display:grid;place-content:center;font-size:64px;box-shadow:6px 6px 0 var(--shadow-color)">${ANSWER}</div>`);
    Object.assign(this.disc.style, { left: `${RING.x - 66}px`, top: `${RING.y - 66}px` });
    this.discLabel = c.el('div', 'abs mono', 'the answer · 17 of 18 agree');
    Object.assign(this.discLabel.style, { left: `${RING.x - 150}px`, width: '300px', top: `${RING.y + 80}px`, textAlign: 'center', fontSize: '15px' });
    L.append(this.mini, this.disc, this.discLabel);

    // Step 3: the bar (the site's meter: score vs need), APPROVED, the 7-minute window, Sell now, SOLD.
    this.h3 = headline(L, c, { n: 3, lines: [['Clear', 'your'], ['bar.', 'Sell.']], small: 'Approved: 7 minutes to sell', at: T.steps[2], out: T.end + 10 });
    this.meter = c.el('div', 'abs');
    this.meter.innerHTML = `<div style="zoom:2;width:${METER.w / 2}px"><div class="meter meter--pending" style="--score:0;--need:${NEED}">
      <div class="meter__bar"><div class="meter__fill"></div><div class="meter__need"></div></div><div class="meter__scale"><span>0</span><span>45</span></div></div></div>
      <div class="mono" style="position:absolute;left:${(NEED / 45) * METER.w}px;top:84px;transform:translateX(-50%);white-space:nowrap;font-size:17px;background:var(--ink);color:var(--paper);padding:4px 10px;border-radius:6px">your bar: need ${NEED}</div>`;
    Object.assign(this.meter.style, { left: `${METER.x}px`, top: `${METER.y}px`, width: `${METER.w}px` });
    this.meterBox = this.meter.querySelector('.meter');
    this.needLabel = this.meter.querySelector('.mono');
    this.rider = c.el('div', 'abs sx-big', `${ANSWER}`);
    Object.assign(this.rider.style, { left: `${METER.x}px`, top: `${METER.y - 74}px`, width: '64px', height: '64px', marginLeft: '-32px', boxSizing: 'border-box', borderRadius: '50%',
      background: 'var(--action)', color: 'var(--on-action)', border: '3px solid var(--ink)', display: 'grid', placeContent: 'center', fontSize: '30px' });
    this.approved = c.el('div', 'abs', `<div style="zoom:1.3">${stamp('approved', 'Approved', `${ANSWER} vs need ${NEED}`)}</div>`);
    this.sold = c.el('div', 'abs', `<div style="zoom:1.3">${stamp('sold', 'Sold', '90,000 PLEA')}</div>`);
    [this.approved, this.sold].forEach((e) => Object.assign(e.style, { left: '700px', top: '396px' }));
    this.urgent = c.el('div', 'abs', `<div style="zoom:1.45;display:flex;gap:12px;align-items:center">
      <span class="countdown countdown--urgent"><svg class="icon"><use href="#i-timer"/></svg>Sell within <span class="countdown__time">07:00</span></span>
      <button class="btn btn--ink">Sell now<span class="btn__sub">90,000 PLEA</span></button></div>`);
    Object.assign(this.urgent.style, { left: '640px', top: '528px' });
    this.time = this.urgent.querySelector('.countdown__time');
    this.sellNow = this.urgent.querySelector('.btn');
    L.append(this.meter, this.rider, this.approved, this.sold, this.urgent);

    this.cursors = [
      cursor(L, c, { keys: [[T.btn, 1080, 690], [T.click - 0.45, 632, 350]], presses: [T.click], from: T.btn, to: T.no + 0.6 }),
      cursor(L, c, { keys: [[T.type1 - 0.4, 1190, 700], [T.submit - 0.45, SUBMIT[0], SUBMIT[1]]], presses: [T.submit], from: T.type1 - 0.4, to: T.fly + 0.2 }),
      cursor(L, c, { keys: [[T.window, 1200, 700], [T.sell - 0.45, SELL[0], SELL[1]]], presses: [T.sell], from: T.window, to: T.end }),
    ];
    this.recap = recap(L, root, c, {
      at: T.end, sub: 'No plea, no sale.',
      rows: ['Write your case: up to 280 bytes, any language.', '30 judges score it 0–45; 17 must agree.', 'Clear your bar: 7 minutes to sell.'],
      fine: 'Plea #19 and its 18 answers are real (Sepolia test run 9) · Not financial advice · Music: “Spy Glass” Kevin MacLeod (incompetech.com), CC BY 4.0',
    });
  },

  update(t, c) {
    const { M } = c, T = this.T;
    this.chrome.update(t);

    // Hook.
    const hookOn = t < T.steps[0] + 0.5;
    const away = M.sp(t - T.steps[0], 'ui');
    [this.ask, this.sellBtn, this.no].forEach((e) => { e.style.opacity = 1 - away; });
    c.show(this.ask, hookOn);
    this.askWords.forEach((w, k) => { w.style.transform = `translateY(${(1 - M.sp(t - (T.ask + 0.13 * k), 'type')) * 115}%)`; });
    this.ask.style.transform = `translateY(${-away * 60}px)`;
    c.show(this.sellBtn, hookOn && t >= T.btn);
    const shake = t >= T.click + 0.12 && t < T.no ? Math.sin((t - T.click) * 70) * 9 * Math.exp(-(t - T.click) * 6) : 0;
    this.sellBtn.style.transform = `translate(${shake}px, ${-away * 60}px) scale(${M.mix(0.6, 1, M.sp(t - T.btn, 'snappy'))})`;
    press(this.sellBtn.querySelector('.btn'), t, T.click);
    const n = M.stampLand(t - T.no, { from: 2.2, tiltFrom: -14, tilt: -4 });
    c.show(this.no, hookOn && n.visible);
    const jn = M.jolt(t - T.no - 0.06, 8);
    this.no.style.transform = `translate(0, ${jn - away * 60}px) rotate(${n.rot}deg) scale(${n.scale})`;
    this.layer.style.translate = `0 ${jn}px`;

    // Step 1: editor slides in, the plea types itself, Submit, the card shrinks into the ring's middle.
    this.h1.update(t);
    const edOn = t >= T.steps[0] && t < T.steps[1] + 0.1;
    c.show(this.editor, edOn);
    if (edOn) {
      const ek = M.sp(t - T.steps[0], 'heavy'), fk = M.sp(t - T.fly, 'ui');
      const dx = RING.x - (640 + 292), dy = RING.y - (134 + 165);
      this.editor.style.transform = `translate(${(1 - ek) * 720 + dx * fk}px, ${dy * fk}px) scale(${M.mix(1, 0.3, fk)})`;
      this.editor.style.opacity = 1 - M.ramp(t, T.fly + 0.2, T.fly + 0.32);
      const nch = Math.round(TEXT.length * M.ramp(t, T.type0, T.type1));
      const caret = t < T.type1 + 0.6 && Math.floor(t / 0.25) % 2 === 0 ? '<span style="border-left:3px solid var(--action);margin-left:1px"></span>' : '';
      this.textEl.innerHTML = esc(TEXT.slice(0, nch)) + caret;
      this.countEl.textContent = `${nch} / 280 bytes`;
      this.countBar.style.width = `${(nch / 280) * 100}%`;
      press(this.submit, t, T.submit);
    }

    // Step 2: seats pop in, answers land (ticks), the outlier is struck, the answer lands in the middle.
    this.h2.update(t);
    const ringOn = t >= T.steps[1] - 0.1 && t < T.steps[2] + 0.6;
    const gather = M.sp(t - T.steps[2], 'ui');
    for (const st of this.seats) {
      c.show(st.e, ringOn);
      if (!ringOn) continue;
      const pop = M.sp(t - (T.seats + st.s * 0.012), 'snappy');
      const tAns = st.k !== undefined ? T.ans + st.k * T.gap : Infinity;
      const on = t >= tAns;
      st.e.classList.toggle('is-on', on && !(st.out && t >= T.strike));
      st.e.classList.toggle('is-out', st.out && t >= T.strike);
      st.e.textContent = on ? PANEL[st.k][1] : '';
      const land = M.sp(t - tAns, 'snappy');
      const agree = on && !st.out ? 1 + 0.12 * Math.max(0, Math.sin(Math.PI * M.ramp(t, T.strike + 0.15 + st.s * 0.006, T.strike + 0.45 + st.s * 0.006))) : 1;
      const s = M.mix(0.2, 1, pop) * (on ? M.mix(1.35, 1, land) : 1) * agree * (1 - gather);
      st.e.style.transform = `translate(${(RING.x - st.x) * gather}px, ${(RING.y - st.y) * gather}px) scale(${s})`;
    }
    c.show(this.mini, t >= T.fly + 0.2 && t < T.answer);
    this.mini.style.transform = `scale(${M.mix(0.6, 1, M.sp(t - T.fly - 0.2, 'snappy')) * (1 - M.sp(t - T.answer + 0.15, 'snappy'))})`;
    const d = M.stampLand(t - T.answer, { from: 1.8, tiltFrom: -20, tilt: 0 });
    c.show(this.disc, d.visible && t < T.steps[2] + 0.5);
    // On step 3 the answer flies to the meter and becomes its rider.
    const toMeter = M.sp(t - T.steps[2], 'heavy');
    this.disc.style.transform = `translate(${(RIDER_X - RING.x) * toMeter}px, ${(METER.y - 42 - RING.y) * toMeter}px) rotate(${d.rot}deg) scale(${d.scale * M.mix(1, 0.48, toMeter)})`;
    this.disc.style.opacity = 1 - M.ramp(t, T.steps[2] + 0.3, T.steps[2] + 0.4);
    c.show(this.discLabel, t >= T.answer + 0.25 && t < T.steps[2]);
    this.discLabel.style.transform = `translateY(${(1 - M.sp(t - T.answer - 0.25, 'snappy')) * 14}px)`;

    // Step 3: the meter, the need marker, the score sweeps past it, APPROVED, the window, Sell now, SOLD.
    this.h3.update(t);
    const mOn = t >= T.meter;
    const mk = M.sp(t - T.meter, 'ui');
    c.show(this.meter, mOn);
    const lift = M.sp(t - T.approved, 'heavy');
    this.meter.style.transform = `translate(${(1 - mk) * 60}px, ${-lift * 14}px)`;
    this.meter.style.opacity = mk;
    const nk = M.sp(t - T.need, 'snappy');
    this.meter.querySelector('.meter__need').style.transform = `translateY(${(1 - nk) * -40}px)`;
    this.meter.querySelector('.meter__need').style.opacity = M.ramp(t, T.need, T.need + 0.05);
    c.show(this.needLabel, t >= T.need);
    this.needLabel.style.transform = `translate(-50%, ${(1 - nk) * 12}px)`;
    // The fill eases up to the score; it turns green as it passes the need.
    const fk = M.ramp(t, T.fill0, T.fill1);
    const score = ANSWER * (1 - Math.pow(1 - fk, 2.2));
    this.meterBox.style.setProperty('--score', score.toFixed(3));
    this.meterBox.classList.toggle('meter--pending', score < NEED);
    c.show(this.rider, t >= T.steps[2] + 0.38);
    this.rider.style.transform = `translate(${RIDER_X - METER.x}px, ${-lift * 14}px)`;
    const a = M.stampLand(t - T.approved, { from: 2, tiltFrom: -12, tilt: -3 });
    c.show(this.approved, a.visible && t < T.sold);
    const ja = M.jolt(t - T.approved - 0.06, 6) + M.jolt(t - T.sold - 0.06, 6);
        this.approved.style.transform = `translateY(${ja}px) rotate(${a.rot}deg) scale(${a.scale})`;
    const s = M.stampLand(t - T.sold, { from: 1.8, tiltFrom: -12, tilt: -3 });
    c.show(this.sold, s.visible);
    this.sold.style.transform = `translateY(${ja}px) rotate(${s.rot}deg) scale(${s.scale})`;
    c.show(this.urgent, t >= T.window);
    this.urgent.style.transform = `translateY(${(1 - M.sp(t - T.window, 'ui')) * 50}px)`;
    const left = Math.max(0, 420 - Math.floor(Math.max(0, t - T.window)));
    this.time.textContent = `${String(Math.floor(left / 60)).padStart(2, '0')}:${String(left % 60).padStart(2, '0')}`;
    press(this.sellNow, t, T.sell);
    this.cursors.forEach((k) => k.update(t));

    this.recap.update(t);
  },

  cues(c) {
    const T = this.T, half = c.beatLen() / 2;
    const q = [];
    // Hook: a tap per word, the button pops, the click, the shake, the stamp.
    for (let k = 0; k < 4; k++) q.push([T.ask + 0.13 * k, 'tap', 2.0, 900, 0.02]);
    q.push([T.btn, 'pop', 0.7], [T.click, 'tap', 0.9, 1800, 0.015], [T.click + 0.12, 'ratchet', 0.9, 5, 0.25], [T.no, 'thump', 0.35, 1.2]);
    // Step 1: the headline words, keystrokes on sixteenths, the press, the card flies.
    q.push([T.steps[0], 'whoosh', 1.5, 0.35, 400, 2600], [T.steps[0], 'pop', 1.2, 400, 800]);
    for (let t = T.type0; t < T.type1; t += c.beatLen() / 4) q.push([t, 'key', 6.0]);
    q.push([T.submit, 'tap', 0.5, 1800, 0.015], [T.fly, 'whoosh', 1.0, 0.4, 300, 1800]);
    // Step 2: a tick per answer pitched by its score, the strike, the answer lands.
    q.push([T.steps[1], 'pop', 0.35, 400, 800], [T.seats, 'ratchet', 0.45, 10, 0.4]);
    PANEL.forEach(([, v], k) => q.push([T.ans + k * T.gap, 'tick', 2.5, 1200 + 60 * (v - 30), 0.02]));
    q.push([T.strike, 'scratch', 2.0, 0.2], [T.answer, 'thump', 0.7, 0.5], [T.answer + 0.02, 'bell', 0.5, 1046, 0.4]);
    // Step 3: the need marker, the sweep, APPROVED, the window, the press, SOLD.
    q.push([T.steps[2], 'whoosh', 1.0, 0.35, 400, 2600], [T.need, 'tap', 0.4, 1000, 0.04], [T.fill0, 'ratchet', 1.0, 12, T.fill1 - T.fill0 - 0.1],
      [T.approved, 'thump', 1.4, 1.3], [T.window, 'pop', 0.4]);
    for (let k = 0; k < 2; k++) q.push([T.window + k, 'tick', 2.5, 1600, 0.01, 0.4]);
    q.push([T.sell, 'tap', 2.0, 1800, 0.015], [T.sold, 'thump', 0.9, 0.9]);
    // The recap card.
    q.push(...this.recap.cues());
    return q.map(([t, ...r]) => [Math.round(t * 1000) / 1000, ...r]).filter((x) => x[0] >= 0 && half > 0);
  },
};
