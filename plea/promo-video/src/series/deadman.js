// §7 Dead-man: every verdict (approved or denied) keeps the Cabal alive for 33 more hours; 33 hours with no verdict
// and it dies for good (computed on chain, nothing can revive it). Then PLEA trades freely forever: no plea, no
// limits; the hook's fees go on, its prize share going to pool liquidity. The clock is shown fast-forwarded.
// Sepolia test run 9's Cabal died this way (last verdict Sat 22:28:12, dead Mon 07:28:12 UTC).
import { chrome, headline, recap, piece, verdict, cursor, press, hms } from './kit.js';

const H33 = 33 * 3600;
const MON = { x: 640, y: 300, w: 584, h: 130 };

export default {
  build(root, c) {
    const { BAR, AT } = c;
    const T = this.T = {
      steps: [BAR(2), AT(3, 2), BAR(5)], end: BAR(7),
      ask: BAR(0), beat0: AT(0, 2), beat1: BAR(1), beat2: AT(1, 2),
      v: [AT(2, 1.5), AT(2, 3.5), AT(3, 1)], death: AT(4, 2), adjourned: AT(4, 3),
      sellBtn: BAR(5) + 0.3, click: AT(5, 2), sold: BAR(6), chips: AT(6, 1.5),
    };
    T.rate = H33 / (T.death - T.v[2]);   // fast-forward: the last verdict's 33 hours run out at T.death
    this.layer = c.el('div', 'layer');
    root.appendChild(this.layer);
    const L = this.layer;
    this.chrome = chrome(L, root, c, { steps: ['Heartbeat', 'Silence', 'Free'], at: T.steps, end: T.end });

    // Hook: a heartbeat; each beat is a verdict.
    this.ask = piece(L, c, 'The Cabal has a heartbeat.', { cls: 'abs sx-big', left: 0, top: 128, at: T.ask, out: T.steps[0], dy: -30 });
    Object.assign(this.ask.e.style, { right: '0', textAlign: 'center', fontSize: '54px' });
    this.hookMon = this.monitor(L, c, 200, 300, 880, 170);
    this.hookLabel = piece(L, c, '<span class="mono" style="font-size:18px;color:var(--ink-2)">every beat is a verdict</span>', { cls: 'abs', left: 200, top: 490, at: T.beat1, out: T.steps[0], dy: 10 });

    // Steps 1-2: the 33-hour clock, reset by verdicts, then run out.
    this.h1 = headline(L, c, { n: 1, lines: [['Every', 'verdict'], ['resets', '33', 'hours.']], small: 'approved or denied, each one keeps the Cabal alive', at: T.steps[0], out: T.steps[1] });
    this.h2 = headline(L, c, { n: 2, lines: [['33', 'hours'], ['of', 'silence…']], small: 'no verdict for 33 hours: the Cabal dies, for good', at: T.steps[1], out: T.steps[2] });
    this.clock = piece(L, c, `<div class="label sx-clabel" style="font-size:15px">Cabal alive · time left <span style="color:var(--ink-3)">(fast-forward)</span></div>
      <div class="sx-big sx-clock" style="font-family:var(--font-mono);font-weight:600;font-size:92px;letter-spacing:-0.02em;margin-top:2px">33:00:00</div>`,
      { left: MON.x, top: 140, at: T.steps[0] + 0.1, out: T.steps[2], dx: 60, dy: 0 });
    this.clockEl = this.clock.e.querySelector('.sx-clock');
    this.clockLabel = this.clock.e.querySelector('.sx-clabel');
    this.mon = this.monitor(L, c, MON.x, MON.y, MON.w, MON.h);
    // One small mark per verdict under its spike: ✓ approved, ✗ denied (both reset the clock).
    this.tags = T.v.map((v, i) => piece(L, c, `<span class="sx-big" style="display:grid;place-content:center;width:30px;height:30px;box-sizing:border-box;border:3px solid var(--ink);border-radius:6px;font-size:16px;color:var(--on-state);background:var(--${i === 1 ? 'denied' : 'approved'})">${i === 1 ? '✗' : '✓'}</span>`,
      { cls: 'abs', left: this.xAt(v) - 15, top: MON.y + MON.h + 10, at: v, out: T.steps[2], dy: -14, kind: 'snappy' }));
    this.adjourned = verdict(L, c, { state: 'noverdict', word: 'Court is adjourned', sub: 'the Cabal is dead', x: 930, y: 540, zoom: 1.0 });

    // Step 3: the same Sell button as §1, and this time it just sells.
    this.h3 = headline(L, c, { n: 3, lines: [['Selling', 'is', 'open.'], ['Forever.']], small: 'fees go on; the prize share goes to pool liquidity', at: T.steps[2], out: T.end + 10 });
    this.sell = piece(L, c, '<div style="zoom:2.2"><button class="btn btn--primary">Sell<span class="btn__sub">90,000 PLEA</span></button></div>', { left: 720, top: 250, at: T.sellBtn, out: T.end, dy: 40, kind: 'snappy' });
    this.sellBtn = this.sell.e.querySelector('.btn');
    this.cur = cursor(L, c, { keys: [[T.sellBtn, 1180, 690], [T.click - 0.45, 930, 300]], presses: [T.click], from: T.sellBtn, to: T.end });
    this.soldStamp = verdict(L, c, { state: 'sold', word: 'Sold', sub: 'no plea needed', x: 940, y: 440, zoom: 1.2 });
    this.chips = piece(L, c, '<span class="mono" style="font-size:16px;border:3px solid var(--ink);border-radius:999px;padding:6px 14px">no plea · no limit · no Cabal</span>', { cls: 'abs', left: 700, top: 560, at: T.chips, out: T.end, dy: 20, kind: 'snappy' });

    this.recap = recap(L, root, c, {
      at: T.end, sub: 'When the Cabal dies, selling is open.',
      rows: ['Every verdict keeps the Cabal alive for 33 more hours.', '33 hours with no verdict: it dies, and nothing can revive it.', 'Then anyone sells freely, forever. The fees go on.'],
      fine: 'Rules from the contracts; Sepolia test run 9’s Cabal died this way · Not financial advice · Music: “Spy Glass” Kevin MacLeod (incompetech.com), CC BY 4.0',
    });
  },

  // A heart monitor: a trace drawn left to right; `beats` are spike times, `flat` (if set) is when it dies.
  monitor(L, c, x, y, w, h) {
    const e = c.el('div', 'abs');
    Object.assign(e.style, { left: `${x}px`, top: `${y}px`, width: `${w}px`, height: `${h}px`, border: '3px solid var(--ink)', borderRadius: '12px', background: 'var(--paper-2)', overflow: 'hidden', boxSizing: 'border-box' });
    e.innerHTML = `<svg width="${w}" height="${h}" style="display:block"><defs><pattern id="g${x}" width="24" height="24" patternUnits="userSpaceOnUse"><path d="M24 0H0V24" fill="none" stroke="var(--line-soft)" stroke-width="1"/></pattern></defs>
      <rect width="100%" height="100%" fill="url(#g${x})"/><polyline fill="none" stroke="var(--approved)" stroke-width="4" stroke-linejoin="round" stroke-linecap="round"/></svg>`;
    L.appendChild(e);
    return { e, line: e.querySelector('polyline'), w, h };
  },
  // Trace points from t0 to t (x = elapsed × px/s), a spike at each beat before the flat time.
  trace(m, t, t0, t1, beats, flat = Infinity) {
    const pts = [], mid = m.h * 0.58, span = t1 - t0;
    const xOf = (u) => ((u - t0) / span) * m.w;
    const end = Math.min(t, t1);
    let u = t0;
    for (const b of beats.filter((b) => b < end && b < flat)) {
      pts.push([xOf(u), mid], [xOf(b - 0.06), mid], [xOf(b - 0.03), mid - m.h * 0.42], [xOf(b), mid + m.h * 0.28], [xOf(b + 0.03), mid - m.h * 0.12], [xOf(b + 0.06), mid]);
      u = b + 0.06;
    }
    if (end > u) pts.push([xOf(u), mid], [xOf(end), mid]);
    m.line.setAttribute('points', pts.map(([a, b]) => `${a.toFixed(1)},${b.toFixed(1)}`).join(' '));
    m.line.setAttribute('stroke', t >= flat ? 'var(--denied)' : 'var(--approved)');
  },
  xAt(v) { return MON.x + ((v - this.T.steps[0]) / (this.T.steps[2] - this.T.steps[0])) * MON.w; },

  update(t, c) {
    const { M } = c, T = this.T;
    this.chrome.update(t);
    this.ask.update(t);
    // Hook monitor: three beats on the music.
    const hookOn = t >= T.ask + 0.2 && t < T.steps[0] + 0.3;
    this.hookMon.e.style.display = hookOn ? '' : 'none';
    if (hookOn) {
      this.hookMon.e.style.opacity = Math.min(M.ramp(t, T.ask + 0.2, T.ask + 0.4), 1 - M.ramp(t, T.steps[0], T.steps[0] + 0.3));
      this.trace(this.hookMon, t, T.ask + 0.2, T.steps[0], [T.beat0, T.beat1, T.beat2]);
    }
    this.hookLabel.update(t);

    this.h1.update(t);
    this.h2.update(t);
    if (this.clock.update(t)) {
      const last = [...T.v].reverse().find((v) => v <= t) ?? T.steps[0];
      const left = H33 - (t - last) * T.rate;
      const dead = t >= T.death;
      this.clockEl.textContent = hms(dead ? 0 : left);
      this.clockEl.style.color = dead ? 'var(--denied-text)' : left < 6 * 3600 ? 'var(--action)' : 'var(--ink)';
      this.clockLabel.innerHTML = dead ? 'Cabal died · no verdict for 33 hours' : 'Cabal alive · time left <span style="color:var(--ink-3)">(fast-forward)</span>';
      // A verdict snaps the clock back with a small kick.
      const kick = T.v.reduce((a, v) => a + M.jolt(t - v, 8), 0);
      this.clockEl.style.transform = `translateX(${kick}px)`;
    }
    const monOn = t >= T.steps[0] && t < T.steps[2] + 0.3;
    this.mon.e.style.display = monOn ? '' : 'none';
    if (monOn) {
      this.mon.e.style.opacity = Math.min(M.ramp(t, T.steps[0], T.steps[0] + 0.2), 1 - M.ramp(t, T.steps[2], T.steps[2] + 0.3));
      this.trace(this.mon, t, T.steps[0], T.steps[2], T.v, T.death);
    }
    this.tags.forEach((p) => p.update(t));
    this.adjourned.update(t, T.adjourned, T.steps[2] + 0.3);
    this.adjourned.e.style.opacity = 1 - M.ramp(t, T.steps[2], T.steps[2] + 0.3);

    this.h3.update(t);
    this.sell.update(t);
    press(this.sellBtn, t, T.click);
    this.cur.update(t);
    this.soldStamp.update(t, T.sold);
    this.chips.update(t);

    this.recap.update(t);
  },

  cues(c) {
    const T = this.T;
    const q = [[T.ask, 'pop', 0.7], ...[T.beat0, T.beat1, T.beat2].map((b) => [b, 'tick', 3.0, 1000, 0.05, 0.5]),
      [T.steps[0], 'whoosh', 1.5, 0.35, 400, 2600], ...T.v.map((v) => [v, 'tick', 3.0, 1000, 0.05, 0.5]), ...T.v.map((v) => [v + 0.02, 'ratchet', 0.6, 6, 0.2]),
      [T.steps[1], 'pop', 1.0, 400, 800], [T.death, 'flatline', 1.6, 1.1, 1000], [T.adjourned, 'thump', 0.9, 1.0],
      [T.steps[2], 'switch', 1.2], [T.sellBtn, 'pop', 0.8], [T.click, 'tap', 2.0, 1800, 0.015], [T.sold, 'thump', 1.4, 1.3], [T.sold + 0.04, 'bell', 0.6, 1318, 0.5], [T.chips, 'pop', 1.0]];
    return [...q, ...this.recap.cues()].map(([t, ...r]) => [Math.round(t * 1000) / 1000, ...r]);
  },
};
