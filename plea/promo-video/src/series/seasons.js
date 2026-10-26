// §6 Seasons: an approved plea earns its judges' score as points (×1.2, rounded down, for an IMD seat holder);
// each wallet's best three count. Seasons last 15 days; the top 25 with at least 60 points split the pot (IMD from
// 0.25% of every trade and overruled stakes) in shares from 4.50% (1st) to 3.50% (25th), and the first six seasons
// add 10,000,000 PLEA on the same shares. Real data, Sepolia test run 9 (5-hour test seasons), season 15
// (Sat 16:09–21:09): seat_holder_one (0x6828…8F4f, seat) #19 34 → 40 and #23 33 → 39 = 79, rank 1, paid 4.50%;
// 0xF73A…6dF0 #21 31 (lowered by its objection), under 60.
import { chrome, headline, recap, piece, verdict } from './kit.js';

const ticket = (id, score, pts) => `<div style="display:flex;align-items:center;gap:14px;width:584px;box-sizing:border-box;border:3px solid var(--ink);border-radius:12px;background:var(--card);padding:12px 18px;box-shadow:6px 6px 0 var(--shadow-color)">
  <span class="mono" style="font-size:18px">Plea #${id}</span><span class="stamp stamp--approved stamp--sm" style="transform:none">Approved</span>
  <span class="mono" style="font-size:17px;color:var(--ink-2);margin-left:auto">${score} × 1.2 seat =</span><span class="sx-big" style="font-size:40px">${pts}</span></div>`;

const lbRow = (rank, who, pts, max = 90) => `<div style="display:grid;grid-template-columns:40px 190px 1fr 54px;align-items:center;gap:12px;width:584px">
  <span class="sx-big" style="font-size:24px">${rank}</span><span class="mono" style="font-size:16px;white-space:nowrap">${who}</span>
  <span style="position:relative;height:34px;border:3px solid var(--ink);border-radius:8px;background:var(--card);overflow:hidden"><span class="sx-bar" style="position:absolute;inset:0 auto 0 0;width:${(pts / max) * 100}%;background:var(--action);border-right:3px solid var(--ink);transform-origin:0 50%"></span></span>
  <span class="sx-big" style="font-size:24px;text-align:right">${pts}</span></div>`;

export default {
  build(root, c) {
    const { BAR, AT } = c;
    const T = this.T = {
      steps: [BAR(2), AT(3, 2), BAR(5)], end: BAR(7),
      ask: BAR(0), row: AT(0, 1), paid: BAR(1),
      t19: AT(2, 1), t23: AT(2, 2.5), sum: AT(3, 0.5),
      lb: AT(3, 2.5), bars: BAR(4), line: AT(4, 1.5),
      ladder: AT(5, 0.5), prize: BAR(6), bonus: AT(6, 1.5),
    };
    this.layer = c.el('div', 'layer');
    root.appendChild(this.layer);
    const L = this.layer;
    this.chrome = chrome(L, root, c, { steps: ['Score', 'Rank', 'Get paid'], at: T.steps, end: T.end });

    // Hook: plead well, get paid; season 15's winner.
    this.ask = piece(L, c, 'Plead well. Get paid.', { cls: 'abs sx-big', left: 0, top: 128, at: T.ask, out: T.steps[0], dy: -30 });
    Object.assign(this.ask.e.style, { right: '0', textAlign: 'center', fontSize: '58px' });
    this.hookRow = piece(L, c, `<div style="zoom:1.3">${lbRow(1, 'seat_holder_one', 79)}</div>`, { left: 260, top: 280, at: T.row, out: T.steps[0], dy: 50 });
    this.hookStamp = verdict(L, c, { state: 'approved', word: 'Prize paid', sub: '79 points · 1st · season 15', x: 820, y: 450 });

    // Step 1: approvals score points; a seat counts 1.2×; best three count.
    this.h1 = headline(L, c, { n: 1, lines: [['Approvals'], ['score', 'points.']], small: 'the judges’ score · ×1.2 with an IMD seat · your best three count', at: T.steps[0], out: T.steps[1] });
    this.who = piece(L, c, '<span class="mono" style="font-size:16px;color:var(--ink-2)">seat_holder_one · 0x6828…8F4f · holds an IMD seat</span>', { cls: 'abs', left: 640, top: 150, at: T.steps[0] + 0.2, out: T.steps[1], dy: 0, dx: 40 });
    this.t19 = piece(L, c, ticket(19, 34, 40), { left: 640, top: 190, at: T.t19, out: T.steps[1], dx: 80, dy: 0, kind: 'snappy' });
    this.t23 = piece(L, c, ticket(23, 33, 39), { left: 640, top: 290, at: T.t23, out: T.steps[1], dx: 80, dy: 0, kind: 'snappy' });
    this.sum = piece(L, c, `<div style="display:flex;justify-content:space-between;align-items:center;width:584px;border-top:4px solid var(--ink);padding-top:12px">
      <span class="mono" style="font-size:17px">best three: 40 + 39 + —</span><span class="sx-big" style="font-size:48px">79 points</span></div>`, { left: 640, top: 400, at: T.sum, out: T.steps[1], dy: 30 });

    // Step 2: the season board; 60 points to qualify.
    this.h2 = headline(L, c, { n: 2, lines: [['Top', '25', 'with'], ['60+', 'win.']], small: '15-day seasons · the pot: 0.25% of every trade + overruled stakes', at: T.steps[1], out: T.steps[2] });
    this.lbHead = piece(L, c, '<span class="label" style="font-size:15px">Season 15 · Sepolia test run 9</span>', { cls: 'abs', left: 640, top: 150, at: T.lb, out: T.steps[2], dy: 0, dx: 40 });
    this.rows = [piece(L, c, lbRow(1, 'seat_holder_one', 79), { left: 640, top: 200, at: T.lb, out: T.end, dx: 60, dy: 0 }),
      piece(L, c, lbRow(2, '0xF73A…6dF0', 31), { left: 640, top: 260, at: T.lb + 0.12, out: T.end, dx: 60, dy: 0 })];
    const x60 = 640 + 40 + 190 + 24 + (60 / 90) * (584 - 40 - 190 - 54 - 36);
    this.line60 = piece(L, c, '<div style="height:150px;border-left:4px dashed var(--approved)"></div><div class="mono" style="font-size:15px;color:var(--approved-text);white-space:nowrap;transform:translateX(-50%)">60 to qualify</div>',
      { left: x60, top: 182, at: T.line, out: T.end, dy: -20, kind: 'snappy' });

    // Step 3: paid in IMD on a straight ladder of shares, plus the PLEA bonus in seasons 1-6.
    this.h3 = headline(L, c, { n: 3, lines: [['Paid', 'in', 'IMD,'], ['plus', 'PLEA.']], small: '1st takes 4.50% of the pot … 25th takes 3.50%', at: T.steps[2], out: T.end + 10 });
    const bars = Array.from({ length: 25 }, (_, i) => { const s = 4.5 - i / 24; return `<span style="flex:1;height:${(s / 4.5) * 100}%;background:${i === 0 ? 'var(--action)' : 'var(--ink-3)'};border-radius:3px 3px 0 0"></span>`; }).join('');
    this.ladder = piece(L, c, `<div class="label" style="font-size:14px;margin-bottom:6px">prize shares, rank 1 → 25</div><div style="display:flex;align-items:flex-end;gap:4px;width:584px;height:110px;border-bottom:3px solid var(--ink)">${bars}</div>
      <div class="mono" style="display:flex;justify-content:space-between;font-size:15px;margin-top:6px"><span>1st · 4.50%</span><span>25th · 3.50%</span></div>`, { left: 640, top: 408, at: T.ladder, out: T.end, dy: 40 });
    this.prize = verdict(L, c, { state: 'approved', word: 'Prize paid', sub: 'rank 1 · 4.50% of the pot', x: 1030, y: 334, zoom: 1.0 });
    this.bonus = piece(L, c, '<span class="mono" style="font-size:17px;border:3px solid var(--ink);border-radius:999px;padding:6px 14px;background:var(--action);color:var(--on-action)">+ 10,000,000 PLEA a season · seasons 1–6</span>',
      { cls: 'abs', left: 640, top: 600, at: T.bonus, out: T.end, dy: 20, kind: 'snappy' });

    this.recap = recap(L, root, c, {
      at: T.end, sub: 'Plead well, climb the board.',
      rows: ['Approved pleas score points: the judges’ score, ×1.2 with an IMD seat.', 'Seasons last 15 days; your best three pleas count.', 'Top 25 with 60+ points split the pot in IMD; +10M PLEA in seasons 1–6.'],
      fine: 'Season 15 of Sepolia test run 9 (5-hour test seasons) · Not financial advice · Music: “Spy Glass” Kevin MacLeod (incompetech.com), CC BY 4.0',
    });
  },

  update(t, c) {
    const { M } = c, T = this.T;
    this.chrome.update(t);
    this.ask.update(t);
    this.hookRow.update(t);
    this.hookStamp.update(t, T.paid, T.steps[0] + 0.3);
    this.hookStamp.e.style.opacity = 1 - M.ramp(t, T.steps[0], T.steps[0] + 0.3);

    this.h1.update(t);
    this.who.update(t);
    this.t19.update(t);
    this.t23.update(t);
    this.sum.update(t, `scale(${M.mix(1.08, 1, M.sp(t - T.sum, 'snappy'))})`);

    this.h2.update(t);
    this.lbHead.update(t);
    this.rows.forEach((r, i) => {
      r.update(t);
      r.e.querySelector('.sx-bar').style.transform = `scaleX(${M.sp(t - T.bars - 0.15 * i, 'ui')})`;
      if (i === 1 && t >= T.line + 0.3) r.e.style.opacity = Math.min(Number(r.e.style.opacity), 0.45);
    });
    // In step 3 the board moves up out of the ladder's way.
    const up = M.sp(t - T.steps[2], 'ui') * -40;
    this.rows.forEach((r) => { r.e.style.translate = `0 ${up}px`; });
    this.line60.update(t);
    this.line60.e.style.translate = `0 ${up}px`;

    this.h3.update(t);
    this.ladder.update(t);
    this.prize.update(t, T.prize);
    this.bonus.update(t);

    this.recap.update(t);
  },

  cues(c) {
    const T = this.T;
    const q = [[T.ask, 'pop', 2.2], [T.row, 'whoosh', 0.8, 0.3, 400, 2400], [T.paid, 'thump', 0.25, 1.2], [T.paid + 0.04, 'bell', 0.4, 1318, 0.4],
      [T.steps[0], 'whoosh', 1.5, 0.35, 400, 2600], [T.t19, 'tap', 1.2, 1000, 0.04], [T.t23, 'tap', 1.2, 1100, 0.04], [T.sum, 'thump', 0.5, 0.5],
      [T.steps[1], 'pop', 1.0, 400, 800], [T.lb, 'whoosh', 0.8, 0.3, 300, 1800], [T.bars, 'ratchet', 2.5, 10, 0.5], [T.line, 'scratch', 1.2, 0.25],
      [T.steps[2], 'whoosh', 1.0, 0.35, 400, 2600], [T.ladder, 'ratchet', 0.9, 12, 0.45], [T.prize, 'thump', 1.4, 1.3], [T.prize + 0.04, 'bell', 0.6, 1318, 0.5], [T.bonus, 'pop', 1.0]];
    return [...q, ...this.recap.cues()].map(([t, ...r]) => [Math.round(t * 1000) / 1000, ...r]);
  },
};
