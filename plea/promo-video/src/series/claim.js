// Bonus · Claim your PLEA: PleaDistributor holds 12% of the supply (120,000,000 PLEA): the IMD swarm's 10% (an
// equal share for every IMD seat that did swarm work, paid to the seat's owner wallet; plea/tools/distributor_root.py)
// and a 2% airdrop list. The owner sets the Merkle root once; then the list is final. `claim(index, account, amount,
// proof)` is open to anyone and always pays `account`, so any wallet can send it (gas only); there is no deadline.
// Claimed PLEA is ordinary PLEA: selling it while the Cabal lives takes a plea, scored as held since trading opened
// at profit 10 (a 20% plea, flat price: need 69 - (16 + 0/1/2/3 + 10 + 5) = 38 / 37 / 36 / 35 on day 0 / 1 / 3 / 7;
// with the price up over 2% on 24 h, from day 1: 33 / 32 / 31; day 0 has no 24 h price, so it scores flat).
// The claim shown is real: Sepolia test run 9, claim #0, sent by 0x4b91…6821 on Wed 2026-10-21 13:10:25 UTC (tx
// 0xb096654b…e817): Claimed(0, 0x6828…8F4f, 2,500,000 PLEA), the PLEA moved from the distributor to 0x6828…8F4f.
import { chrome, headline, recap, piece, typeInto, cursor, press } from './kit.js';

const ADDR = '0x6828002d07385205dB0d998a109417E25B8e8F4f';
const SPLIT = [['82%', 'the pool', 'var(--card)', 'var(--ink)'], ['6%', 'seasons', 'var(--paper-2)', 'var(--ink)'], ['12%', 'claims', 'var(--action)', 'var(--on-action)']];
const BARS = [['Day 0', 38, null], ['Day 1', 37, 33], ['Day 3', 36, 32], ['A week', 35, 31]];   // [day, need with a flat price, need with a rising one]

const share = (tag, big, sub) => `<div class="card" style="width:584px;box-sizing:border-box;padding:16px 22px 18px;box-shadow:8px 8px 0 var(--shadow-color)">
  <div class="label" style="font-size:15px">${tag}</div><div class="sx-big" style="font-size:44px;margin-top:4px">${big}</div>
  <div style="font-size:17px;color:var(--ink-2);margin-top:6px;line-height:1.35">${sub}</div></div>`;

export default {
  build(root, c) {
    const { BAR, AT } = c;
    const T = this.T = {
      steps: [BAR(2), AT(3, 2), BAR(5)], end: BAR(7),
      ask: BAR(0), bar: AT(0, 1), lift: AT(0, 3), stamp: BAR(1),
      who1: AT(2, 1), who2: AT(2, 2), seats: AT(2, 3),
      card: AT(3, 2.3), type0: AT(3, 2.8), type1: AT(3, 3.8), ok: BAR(4), press: AT(4, 1.5), sent: AT(4, 2),
      rows: [AT(5, 1), AT(5, 1.5), AT(5, 2), AT(5, 2.5)], seat: AT(6, 1),
    };
    this.layer = c.el('div', 'layer');
    root.appendChild(this.layer);
    const L = this.layer;
    this.chrome = chrome(L, root, c, { steps: ['Who', 'Claim', 'Then'], at: T.steps, end: T.end });

    // Hook: the supply bar; the 12% lifts out of it and the CLAIM stamp lands on it.
    this.ask = piece(L, c, '12% of PLEA waits to be claimed.', { cls: 'abs sx-big', left: 0, top: 128, at: T.ask, out: T.steps[0], dy: -30 });
    Object.assign(this.ask.e.style, { right: '0', textAlign: 'center', fontSize: '50px' });
    this.supply = piece(L, c, `<div class="mono" style="font-size:16px;color:var(--ink-2);margin-bottom:10px">1,000,000,000 PLEA at launch</div>
      <div style="display:flex;width:1000px;height:96px;gap:0">${SPLIT.map(([p, label, bg, fg], i) => `<div class="sx-seg${i === 2 ? ' sx-claims' : ''}" style="flex:${parseFloat(p)};box-sizing:border-box;border:4px solid var(--ink);${i ? 'border-left:0;' : ''}background:${bg};color:${fg};display:grid;place-content:center;text-align:center;${i === 0 ? 'border-radius:14px 0 0 14px;' : ''}${i === 2 ? 'border-radius:0 14px 14px 0;' : ''}">
        <span class="sx-big" style="font-size:${i === 1 ? 26 : 36}px">${p}</span>${i === 1 ? '' : `<span class="mono" style="font-size:14px">${label}</span>`}</div>`).join('')}</div>
      <div class="mono" style="position:relative;height:24px;font-size:14px;color:var(--ink-2)"><span style="position:absolute;left:${(82 + 3) * 10}px;top:6px;transform:translateX(-50%)">seasons</span></div>`,
      { left: 140, top: 270, at: T.bar, out: T.steps[0], dy: 50 });
    this.claims = this.supply.e.querySelector('.sx-claims');
    this.stamp = piece(L, c, '<div style="zoom:0.5"><span class="bigstamp">CLAIM</span></div>', { cls: 'abs', left: 860, top: 452, at: T.stamp, out: T.steps[0], dy: 0, kind: 'stamp' });

    // Step 1: who is on the list: the swarm's 10% and the 2% airdrop.
    this.h1 = headline(L, c, { n: 1, lines: [['Who', 'gets'], ['the', '12%?']], small: 'the owner sets the list once; then it is final', at: T.steps[0], out: T.steps[1] });
    this.who1 = piece(L, c, share('IMD swarm · 10%', '100,000,000 PLEA', 'an equal share for every IMD seat that did swarm work, paid to the seat’s owner wallet'),
      { left: 640, top: 150, at: T.who1, out: T.steps[1], dx: 60, dy: 0, kind: 'snappy' });
    this.who2 = piece(L, c, share('Airdrop · 2%', '20,000,000 PLEA', 'an equal share for each wallet on the airdrop list'),
      { left: 640, top: 340, at: T.who2, out: T.steps[1], dx: 60, dy: 0, kind: 'snappy' });
    this.seats = piece(L, c, `<div style="display:flex;align-items:center;gap:10px">${[0, 1, 2].map(() => '<span class="mono" style="font-size:14px;border:3px solid var(--ink);border-radius:8px;padding:5px 10px;background:var(--card)">seat</span>').join('')}
      <span class="mono" style="font-size:17px;margin-left:6px">3 seats → 3 shares</span></div>`, { left: 640, top: 520, at: T.seats, out: T.steps[1], dy: 16, kind: 'snappy' });

    // Step 2: a real claim, sent by one wallet for another.
    this.h2 = headline(L, c, { n: 2, lines: [['Claim', 'for'], ['any', 'address.']], small: 'the sender pays only gas; the PLEA lands on the listed wallet', at: T.steps[1], out: T.steps[2] });
    this.card = piece(L, c, `<div class="card" style="width:600px;box-sizing:border-box;padding:18px 22px 20px;box-shadow:8px 8px 0 var(--shadow-color)">
      <div style="display:flex;justify-content:space-between;align-items:baseline"><span class="card__title" style="margin:0">Check an address</span><span class="meta" style="font-size:14px">Sepolia test run 9</span></div>
      <div class="field" style="margin-top:12px"><span class="field__label">Address on the list</span>
        <div class="input" style="min-height:52px"><span class="mono sx-addr" style="font-size:15px;white-space:nowrap"></span></div></div>
      <div class="notice notice--ok sx-ok" style="margin-top:12px"><div><p class="notice__title">2,500,000 PLEA claimable (claim #0)</p></div></div>
      <button class="btn btn--primary btn--block sx-btn" type="button" style="margin-top:12px">Claim 2,500,000&nbsp;PLEA <span class="btn__sub">gas only</span></button></div>`,
      { left: 640, top: 128, at: T.card, out: T.steps[2], dx: 60, dy: 0, kind: 'heavy' });
    this.addrEl = this.card.e.querySelector('.sx-addr');
    this.okEl = this.card.e.querySelector('.sx-ok');
    this.btn = this.card.e.querySelector('.sx-btn');
    this.sent = piece(L, c, `<div style="display:flex;flex-direction:column;gap:8px">
      <span class="mono" style="font-size:16px;border:3px solid var(--ink);border-radius:999px;padding:5px 14px;background:var(--card)">sent by 0x4b91…6821 · gas only</span>
      <span class="mono" style="font-size:16px;border:3px solid var(--ink);border-radius:999px;padding:5px 14px;background:var(--approved);color:var(--on-state)">✓ 2,500,000 PLEA → 0x6828…8F4f</span></div>`,
      { left: 640, top: 520, at: T.sent, out: T.steps[2], dy: 20, kind: 'snappy' });
    this.cur = cursor(L, c, { keys: [[T.ok - 0.3, 1160, 620], [T.press - 0.15, 990, 372]], presses: [T.press], from: T.ok - 0.3, to: T.steps[2] });

    // Step 3: claimed PLEA plays like any PLEA: selling takes a plea.
    this.h3 = headline(L, c, { n: 3, lines: [['Then', 'plead'], ['to', 'sell', 'it.']], small: 'claimed PLEA counts as held since trading opened', at: T.steps[2], out: T.end + 10 });
    this.tableHead = piece(L, c, '<span class="label" style="font-size:15px">Your bar (need) for a 20% plea of claimed PLEA, by price</span>', { cls: 'abs', left: 640, top: 150, at: T.steps[2] + 0.1, out: T.end, dy: 10 });
    const COLS = 'display:grid;grid-template-columns:96px 1fr 62px 96px;align-items:center;gap:12px;width:584px';
    this.cols = piece(L, c, `<div style="${COLS}"><span></span><span></span><span class="mono" style="font-size:13px;text-align:right;color:var(--ink-2)">flat</span>
      <span class="mono" style="font-size:13px;text-align:center;color:var(--ink-2)">rising</span></div>`, { cls: 'abs', left: 640, top: 192, at: T.rows[0], out: T.end, dy: 10 });
    this.rows = BARS.map(([day, need, up], i) => piece(L, c, `<div style="${COLS}">
        <span style="font-weight:700;font-size:19px">${day}</span>
        <span style="position:relative;height:36px;border:3px solid var(--ink);border-radius:8px;background:var(--card);overflow:hidden">
          <span class="sx-fill" style="position:absolute;inset:0 auto 0 0;width:${(need / 45) * 100}%;background:var(--action);border-right:3px solid var(--ink)"></span></span>
        <span class="sx-big" style="font-size:28px;text-align:right">${need}</span>
        <span class="sx-big sx-up" style="font-size:26px;text-align:center;border:3px solid var(--ink);border-radius:999px;padding:2px 0;${up ? 'background:var(--approved);color:var(--on-state)' : 'color:var(--ink-3)'}">${up ?? '–'}</span></div>`,
      { left: 640, top: 222 + i * 60, at: T.rows[i], out: T.end, dx: 60, dy: 0, kind: 'snappy' }));
    this.note = piece(L, c, '<span class="mono" style="font-size:14px;color:var(--ink-2)">rising = up over 2% on 24 h · day 0 has no 24 h price yet</span>', { cls: 'abs', left: 640, top: 466, at: T.rows[3] + 0.2, out: T.end, dy: 10 });
    this.seat = piece(L, c, '<span class="mono" style="font-size:17px;border:3px solid var(--ink);border-radius:999px;padding:6px 14px;background:var(--action);color:var(--on-action)">IMD seat owners: 1.2× season points</span>',
      { cls: 'abs', left: 640, top: 520, at: T.seat, out: T.end, dy: 16, kind: 'snappy' });

    this.recap = recap(L, root, c, {
      at: T.end, sub: '12% for the swarm and the airdrop.',
      rows: ['10% to IMD seats that did swarm work, 2% to an airdrop list.', 'Anyone can send a claim; the PLEA goes to the listed address.', 'No deadline. Selling it takes a plea, like any PLEA.'],
      fine: 'Claim #0 is real (Sepolia test run 9) · the list is set once, as a Merkle root · Not financial advice · Music: “Spy Glass” Kevin MacLeod (incompetech.com), CC BY 4.0',
    });
  },

  update(t, c) {
    const { M } = c, T = this.T;
    this.chrome.update(t);
    this.ask.update(t);
    this.supply.update(t);
    const lift = M.sp(t - T.lift, 'snappy');
    this.claims.style.transform = `translateY(${-22 * lift}px)`;
    this.claims.style.boxShadow = lift > 0.01 ? `${8 * lift}px ${8 * lift}px 0 var(--shadow-color)` : '';
    const s = M.stampLand(t - T.stamp, { from: 2.2, tiltFrom: -14, tilt: -5 });
    this.stamp.update(t, `rotate(${s.rot}deg) scale(${s.scale})`);
    this.layer.style.translate = `0 ${M.jolt(t - T.stamp - 0.05, 8)}px`;

    this.h1.update(t);
    this.who1.update(t);
    this.who2.update(t);
    this.seats.update(t);

    this.h2.update(t);
    if (this.card.update(t)) {
      typeInto(this.addrEl, ADDR, t, T.type0, T.type1, T.ok);
      c.show(this.okEl, t >= T.ok);
      this.okEl.style.transform = `translateY(${(1 - M.sp(t - T.ok, 'snappy')) * 12}px)`;
      press(this.btn, t, T.press);
      this.btn.setAttribute('aria-busy', t >= T.press + 0.12 && t < T.sent ? 'true' : 'false');
    }
    this.sent.update(t);
    this.cur.update(t);

    this.h3.update(t);
    this.tableHead.update(t);
    this.cols.update(t);
    this.rows.forEach((p, i) => {
      p.update(t);
      const f = p.e.querySelector('.sx-fill');
      f.style.transform = `scaleX(${M.sp(t - T.rows[i] - 0.1, 'ui')})`;
      f.style.transformOrigin = '0 50%';
    });
    this.note.update(t);
    this.seat.update(t);

    this.recap.update(t);
  },

  cues(c) {
    const T = this.T;
    const q = [[T.ask, 'pop', 2.2], [T.bar, 'whoosh', 0.8, 0.3, 400, 2400], [T.lift, 'pop', 0.8], [T.stamp, 'thump', 0.28, 1.2],
      [T.steps[0], 'whoosh', 1.5, 0.35, 400, 2600], [T.who1, 'tap', 1.0, 1000, 0.03], [T.who2, 'tap', 1.0, 1150, 0.03], [T.seats, 'tick', 1.6, 1800, 0.01],
      [T.steps[1], 'pop', 1.0, 400, 800], [T.card, 'whoosh', 0.8, 0.3, 400, 2400], [T.ok, 'tap', 1.0, 1600, 0.02], [T.press, 'tick', 1.6, 2200, 0.008],
      [T.sent, 'bell', 0.5, 1318, 0.4],
      [T.steps[2], 'whoosh', 1.0, 0.35, 400, 2600], ...T.rows.map((r, i) => [r, 'tick', 2.5, 1300 + 200 * i, 0.02]), [T.seat, 'pop', 0.8]];
    for (let t = T.type0; t < T.type1; t += c.beatLen() / 4) q.push([t, 'key', 4.0]);
    return [...q, ...this.recap.cues()].map(([t, ...r]) => [Math.round(t * 1000) / 1000, ...r]);
  },
};
