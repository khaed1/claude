// 4 · The Cabal judges (bars 7-10): 30 seats; plea #14's real panel answers one by one (17 seats,
// IMD request 69014807…), the scores sort into a row, the middle one (35) is the answer, and a
// judge's real note winks.
import { caption, esc } from '../lib/ui.js';

const PANEL = [['482', 35], ['721', 39], ['1842', 35], ['203', 37], ['405', 35], ['1748', 35], ['978', 34], ['1485', 35], ['572', 34],
  ['80', 33], ['1113', 30], ['1800', 38], ['158', 33], ['1285', 33], ['1978', 34], ['1039', 35], ['901', 35]];   // API order
const NOTE = '…a light server-lunch joke make the plea well made.';
const GX = 596, GY = 52, SW = 96, SH = 60, GAP = 12;

export default {
  id: 'judges',
  from: (c) => c.BAR(7),
  to: (c) => c.BAR(11),
  build(root, c) {
    const rand = c.M.rng(14);
    const slots = [...Array(30).keys()];
    for (let i = slots.length - 1; i > 0; i--) { const j = Math.floor(rand() * (i + 1)); [slots[i], slots[j]] = [slots[j], slots[i]]; }
    const answered = new Map(PANEL.map((p, k) => [slots[k], k]));
    this.seats = [];
    for (let s = 0; s < 30; s++) {
      const x = GX + (s % 6) * (SW + GAP), y = GY + Math.floor(s / 6) * (SH + GAP);
      const e = c.el('div', 'seat is-empty');
      Object.assign(e.style, { left: `${x}px`, top: `${y}px`, width: `${SW}px`, height: `${SH}px` });
      root.appendChild(e);
      const k = answered.get(s);
      const seat = { e, x, y, k, s };
      if (k !== undefined) {
        e.innerHTML = `<span class="seat__id">seat ${PANEL[k][0]}</span><span class="seat__score">${PANEL[k][1]}</span>`;
        seat.score = PANEL[k][1];
      } else e.innerHTML = '<span class="seat__id">—</span>';
      this.seats.push(seat);
    }
    // Sorted row: ranks by score (stable by arrival).
    const order = PANEL.map((p, k) => ({ k, v: p[1] })).sort((a, b) => a.v - b.v || a.k - b.k);
    this.rank = new Map(order.map((o, r) => [o.k, r]));
    this.head = c.el('div', 'abs display', 'The Cabal');
    Object.assign(this.head.style, { left: '64px', top: '56px', fontSize: '72px' });
    this.sub = c.el('div', 'abs meta', 'judges plea #14 · Thu 18:26 UTC · Sepolia test run 9');
    Object.assign(this.sub.style, { left: '66px', top: '142px', fontSize: '18px' });
    this.big = c.el('div', 'abs', `<div class="label" style="font-size:16px">the panel’s answer</div><div class="display" style="font-size:150px;line-height:1">35</div>`);
    Object.assign(this.big.style, { left: '640px', top: '36px' });
    this.note = c.el('div', 'card abs', `<div class="plea__text" style="font-size:20px">“${esc(NOTE)}”</div><div class="meta" style="margin-top:6px">judge at seat 1039 · craft 9 of 12</div>`);
    Object.assign(this.note.style, { left: `${GX}px`, top: '430px', width: '636px', padding: '14px 20px' });
    this.cap = c.el('div', 'cap', caption(['30 judges. 17 must agree.'], 'IMD oracle panel · each scores the plea 0–45'));
    [this.head, this.sub, this.big, this.note, this.cap].forEach((e) => root.appendChild(e));
  },
  update(lt, t, c) {
    const { M, AT, BAR } = c;
    const h = M.sp(t - BAR(7), 'type');
    this.head.style.transform = `translateY(${(1 - h) * -70}px)`;
    c.show(this.sub, t >= AT(7, 0.5));
    const tSort = BAR(9), tLift = AT(9, 2);
    for (const st of this.seats) {
      const pop = M.sp(t - (BAR(7) + st.s * 0.015), 'snappy');
      const tAns = st.k !== undefined ? AT(7, 1) + st.k * 0.1225 : Infinity;
      const on = t >= tAns;
      st.e.classList.toggle('is-empty', !on);
      const land = M.sp(t - tAns, 'snappy');
      let x = 0, y = 0, s = M.mix(0.4, 1, pop) * (on ? M.mix(1.25, 1, land) : 1), o = 1;
      if (st.k !== undefined && t >= tSort) {
        // Into one sorted row across the frame (centres), then the middle score lifts to the answer.
        const r = this.rank.get(st.k);
        const m = M.sp(t - (tSort + r * 0.02), 'ui');
        const cx = 64 + r * 68 + 31, cy = 318;
        x = (cx - (st.x + SW / 2)) * m; y = (cy - (st.y + SH / 2)) * m;
        s = M.mix(1, 0.64, m);
        if (r === 8) {
          const lift = M.sp(t - tLift, 'heavy');
          x = M.mix(x, 700 - (st.x + SW / 2), lift); y = M.mix(y, 150 - (st.y + SH / 2), lift); s = M.mix(s, 1.7, lift);
          o = t >= BAR(10) ? 0 : 1;
          st.e.style.background = lift > 0.01 ? 'var(--ink)' : ''; st.e.style.color = lift > 0.01 ? 'var(--card)' : '';
        } else if (t >= tLift) o = M.mix(1, 0.4, M.sp(t - tLift, 'ui'));
      } else if (st.k === undefined && t >= tSort) o = M.mix(1, 0, M.sp(t - tSort, 'ui'));
      c.place(st.e, { x, y, s, o });
    }
    c.show(this.big, t >= BAR(10));
    const b = M.sp(t - BAR(10), 'snappy');
    this.big.style.transform = `scale(${M.mix(0.85, 1, b)})`;
    c.show(this.note, t >= AT(10, 1));
    const n = M.sp(t - AT(10, 1), 'ui');
    this.note.style.transform = `translateY(${(1 - n) * 50}px)`;
    const k = M.sp(t - AT(7, 1), 'snappy');
    c.show(this.cap, t >= AT(7, 1));
    this.cap.style.transform = `translateX(${(1 - k) * -80}px)`;
  },
};
