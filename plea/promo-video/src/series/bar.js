// §2 Your bar: the need a plea must reach is 71 minus its on-chain fact score. Real data, Sepolia test run 9,
// seller 0x6828…8F4f (an IMD seat holder): plea #13 (Thu 18:25) and plea #19 (Sat 16:12) both scored 34; #13 was
// denied at need 35, #19 approved at need 33. #19's facts (read at block 11,984,884): 90,000 of 2,713,518 PLEA =
// 3.32% (16), bought Wed 14:42 = 3 days held (4), worth 1.22 IMD against 1.25 spent = at a loss (13), price flat on
// 24 h (5): 38. #13 two days earlier: held 1 day (2), the rest the same: 36.
import { chrome, headline, recap, piece, verdict, meter } from './kit.js';

const FACTS = [['Share sold', '3.32% of the bag', 16, 16], ['Held', '3 days', 4, 7], ['Profit or loss', 'at a loss', 13, 13], ['24h trend', 'flat', 5, 9]];

const pleaCard = (id, when, need) => `<div class="card" style="width:400px;box-sizing:border-box;padding:18px 22px 20px;box-shadow:8px 8px 0 var(--shadow-color)">
  <div style="display:flex;justify-content:space-between;align-items:baseline"><span class="mono" style="font-size:22px">Plea #${id}</span><span class="meta" style="font-size:14px">${when}</span></div>
  <div class="meta" style="font-size:14px;margin-top:2px">by 0x6828…8F4f · sell 90,000 PLEA</div>
  <div style="display:flex;align-items:baseline;gap:14px;margin-top:14px"><span class="sx-big" style="font-size:76px">34</span><span class="mono" style="font-size:22px;color:var(--ink-2)">vs need ${need}</span></div></div>`;

const tile = (big, label, accent) => `<div style="width:150px;height:150px;box-sizing:border-box;border:4px solid var(--ink);border-radius:14px;background:${accent ? 'var(--action)' : 'var(--card)'};
  color:${accent ? 'var(--on-action)' : 'var(--ink)'};display:grid;place-content:center;text-align:center;box-shadow:6px 6px 0 var(--shadow-color)">
  <div class="sx-big" style="font-size:68px">${big}</div><div class="mono" style="font-size:14px;margin-top:4px">${label}</div></div>`;

export default {
  build(root, c) {
    const { BAR, AT } = c;
    const T = this.T = {
      steps: [BAR(2), AT(3, 2), BAR(5)], end: BAR(7),
      ask: BAR(0), card1: AT(0, 1), card2: AT(0, 1.5), denied: BAR(1), approved: AT(1, 2),
      t71: AT(2, 1), t38: AT(2, 2), t33: AT(2, 3),
      rows: [AT(3, 2.5), AT(3, 3), AT(3, 3.5), BAR(4)], total: AT(4, 1),
      meter: BAR(5), held: AT(5, 2), slide: AT(5, 2.5), ok: BAR(6),
    };
    this.layer = c.el('div', 'layer');
    root.appendChild(this.layer);
    const L = this.layer;
    this.chrome = chrome(L, root, c, { steps: ['Formula', 'Facts', 'Lower it'], at: T.steps, end: T.end });

    // Hook: the same writer, the same score, two verdicts.
    this.ask = piece(L, c, 'Same writer. Same score.', { cls: 'abs sx-big', left: 0, top: 128, at: T.ask, out: T.steps[0], dy: -30 });
    Object.assign(this.ask.e.style, { right: '0', textAlign: 'center', fontSize: '54px' });
    this.c13 = piece(L, c, pleaCard(13, 'Thu 18:25', 35), { left: 180, top: 250, at: T.card1, out: T.steps[0], dx: -80, dy: 0 });
    this.c19 = piece(L, c, pleaCard(19, 'Sat 16:12', 33), { left: 700, top: 250, at: T.card2, out: T.steps[0], dx: 80, dy: 0 });
    this.s13 = verdict(L, c, { state: 'denied', word: 'Denied', sub: '34 vs need 35', x: 380, y: 500 });
    this.s19 = verdict(L, c, { state: 'approved', word: 'Approved', sub: '34 vs need 33', x: 900, y: 500 });

    // Step 1: 71 − 38 = 33.
    this.h1 = headline(L, c, { n: 1, lines: [['Your', 'bar'], ['=', '71', '−', 'facts.']], small: 'need = 71 − the on-chain fact score (0–45)', at: T.steps[0], out: T.steps[1] });
    const eq = (html, left, at) => piece(L, c, html, { left, top: 250, at, out: T.steps[1], dy: 50, kind: 'snappy' });
    this.eq = [eq(tile('71', 'always'), 640, T.t71), eq('<div class="sx-big" style="font-size:64px;line-height:150px">−</div>', 806, T.t38 - 0.1),
      eq(tile('38', 'facts · #19'), 860, T.t38), eq('<div class="sx-big" style="font-size:64px;line-height:150px">=</div>', 1024, T.t33 - 0.1), eq(tile('33', 'need · #19', true), 1072, T.t33)];

    // Step 2: the four facts add up to 38.
    this.h2 = headline(L, c, { n: 2, lines: [['Four', 'facts,'], ['read', 'on', 'chain.']], small: 'share sold · time held · profit or loss · 24h trend', at: T.steps[1], out: T.steps[2] });
    this.rows = FACTS.map(([label, value, pts, max], i) => piece(L, c, `<div style="display:grid;grid-template-columns:150px 1fr 76px;align-items:center;gap:14px;width:584px">
        <span style="font-weight:700;font-size:19px">${label}</span>
        <span style="position:relative;height:40px;border:3px solid var(--ink);border-radius:8px;background:var(--card);overflow:hidden">
          <span class="sx-fill" style="position:absolute;inset:0 auto 0 0;width:${(pts / 16) * 100}%;background:var(--action);border-right:3px solid var(--ink)"></span>
          <span style="position:absolute;inset:0;left:${(max / 16) * 100}%;border-left:3px dashed var(--ink-3)"></span>
          <span class="mono" style="position:absolute;left:12px;top:8px;font-size:16px;color:var(--on-action)">${value}</span></span>
        <span class="sx-big" style="font-size:28px;text-align:right;white-space:nowrap">+${pts}</span></div>`, { left: 640, top: 150 + i * 78, at: T.rows[i], out: T.steps[2], dx: 80, dy: 0, kind: 'snappy' }));
    this.total = piece(L, c, `<div style="display:flex;justify-content:space-between;align-items:center;width:584px;border-top:4px solid var(--ink);padding-top:14px">
      <span class="mono" style="font-size:18px">fact score → need 71 − 38</span><span class="sx-big" style="font-size:44px">38 → 33</span></div>`, { left: 640, top: 470, at: T.total, out: T.steps[2], dy: 30 });

    // Step 3: plea #13's bar was 35; two more days held made #19's 33, so the same 34 passed.
    this.h3 = headline(L, c, { n: 3, lines: [['Hold', 'longer,'], ['lower', 'bar.']], small: 'same seller, two days apart: held 1 → 3 days, bar 35 → 33', at: T.steps[2], out: T.end + 10 });
    this.m = meter(L, c, { x: 640, y: 300, w: 576, need: 35, needLabel: 'need 35' });
    this.score = piece(L, c, '34', { cls: 'abs sx-big', left: 640 + (34 / 45) * 576 - 32, top: 300 - 76, at: T.meter + 0.3, dy: -20, kind: 'snappy' });
    Object.assign(this.score.e.style, { width: '64px', height: '64px', boxSizing: 'border-box', borderRadius: '50%', background: 'var(--action)', color: 'var(--on-action)',
      border: '3px solid var(--ink)', display: 'grid', placeContent: 'center', fontSize: '30px' });
    this.heldChip = piece(L, c, '<span class="sx-held">Held 1 day · +2</span>', { cls: 'abs mono', left: 640, top: 196, at: T.meter + 0.2, dy: 0, dx: 40 });
    Object.assign(this.heldChip.e.style, { fontSize: '18px', border: '3px solid var(--ink)', borderRadius: '8px', padding: '6px 12px', background: 'var(--card)' });
    this.heldText = this.heldChip.e.querySelector('.sx-held');
    this.s3 = verdict(L, c, { state: 'approved', word: 'Approved', sub: '34 vs need 33', x: 930, y: 500 });

    this.recap = recap(L, root, c, {
      at: T.end, sub: 'Same score, different bar.',
      rows: ['Your bar (need) = 71 − your fact score.', 'Facts: share sold, time held, profit or loss, 24h trend.', 'Sell a small share, hold longer: a lower bar.'],
      fine: 'Pleas #13 and #19 and their facts are real (Sepolia test run 9) · Not financial advice · Music: “Spy Glass” Kevin MacLeod (incompetech.com), CC BY 4.0',
    });
  },

  update(t, c) {
    const { M } = c, T = this.T;
    this.chrome.update(t);
    this.ask.update(t);
    this.c13.update(t);
    this.c19.update(t);
    const fade = 1 - M.ramp(t, T.steps[0], T.steps[0] + 0.3);
    this.s13.update(t, T.denied, T.steps[0] + 0.3);
    this.s19.update(t, T.approved, T.steps[0] + 0.3);
    [this.s13, this.s19].forEach((s) => { s.e.style.opacity = fade; });

    this.h1.update(t);
    this.eq.forEach((p) => p.update(t));
    this.h2.update(t);
    this.rows.forEach((p) => p.update(t));
    this.rows.forEach((p, i) => {
      const f = p.e.querySelector('.sx-fill');
      f.style.transform = `scaleX(${M.sp(t - T.rows[i] - 0.1, 'ui')})`;
      f.style.transformOrigin = '0 50%';
    });
    this.total.update(t);

    this.h3.update(t);
    const mOn = t >= T.meter;
    this.m.e.style.display = mOn ? '' : 'none';
    if (mOn) {
      const k = M.sp(t - T.meter, 'ui');
      this.m.e.style.transform = `translateX(${(1 - k) * 60}px)`;
      this.m.e.style.opacity = k;
      const need = M.mix(35, 33, M.sp(t - T.slide, 'heavy'));
      const fill = 34 * M.ramp(t, T.meter + 0.3, T.meter + 0.9);
      this.m.set(fill, { need, state: t < T.meter + 0.9 ? 'pending' : need > 34 ? 'denied' : 'approved' });
      this.m.showNeed(t, T.meter);
      this.m.e.querySelector('.sx-needlabel').textContent = `need ${Math.round(need)}`;
    }
    this.score.update(t);
    this.heldChip.update(t);
    this.heldText.textContent = t < T.held ? 'Held 1 day · +2' : 'Held 3 days · +4';
    this.heldChip.e.style.background = t < T.held ? 'var(--card)' : 'var(--action)';
    this.heldChip.e.style.color = t < T.held ? 'var(--ink)' : 'var(--on-action)';
    this.s3.update(t, T.ok);

    this.recap.update(t);
  },

  cues(c) {
    const T = this.T;
    const q = [[T.ask, 'pop', 2.2], [T.card1, 'whoosh', 0.8, 0.3, 400, 2400], [T.card2, 'whoosh', 0.8, 0.3, 400, 2400],
      [T.denied, 'thump', 0.35, 1.2], [T.approved, 'thump', 0.11, 1.2],
      [T.steps[0], 'whoosh', 1.5, 0.35, 400, 2600], [T.t71, 'tap', 1.0, 900, 0.04], [T.t38, 'tap', 1.0, 1000, 0.04], [T.t33, 'thump', 0.5, 0.5],
      [T.steps[1], 'pop', 1.0, 400, 800], ...T.rows.map((r, i) => [r, 'tick', 2.5, 1300 + 200 * i, 0.02]), [T.total, 'thump', 0.5, 0.5],
      [T.steps[2], 'whoosh', 1.0, 0.35, 400, 2600], [T.meter + 0.3, 'ratchet', 0.8, 8, 0.5], [T.held, 'pop', 0.6], [T.slide, 'scratch', 1.2, 0.25], [T.ok, 'thump', 1.4, 1.3]];
    return [...q, ...this.recap.cues()].map(([t, ...r]) => [Math.round(t * 1000) / 1000, ...r]);
  },
};
