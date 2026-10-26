// 7 · APPROVED → SOLD (bars 16-18): plea #14's verdict lands as the band comes back (35 vs need 35),
// the 7-minute sell window ticks, Sell now is pressed and the stamp turns to SOLD.
import { pleaCard, stamp, caption, zoom, DATA } from '../lib/ui.js';

const CURSOR = `<svg viewBox="0 0 24 24"><path d="M3 2 L3 20 L8 15 L11.5 22 L14.5 20.6 L11 13.8 L18 13.8 Z" fill="var(--ink)" stroke="var(--card)" stroke-width="1.6" stroke-linejoin="round"/></svg>`;

export default {
  id: 'approved',
  from: () => 32.15,  // the card slides in on the drum roll; the verdict lands with the band (bar 16)
  to: (c) => c.BAR(19),
  build(root, c) {
    const p = DATA.p14;
    this.card = c.el('div', 'abs');
    const inner = c.el('div', 'card', pleaCard(p));
    Object.assign(inner.style, { width: '560px', zoom: 1.45 });
    this.card.appendChild(inner);
    Object.assign(this.card.style, { left: '64px', top: '44px' });
    this.approved = c.el('div', 'abs', zoom(stamp('approved', 'Approved', '35 vs need 35'), 1.6));
    this.sold = c.el('div', 'abs', zoom(stamp('sold', 'Sold', '35 vs need 35'), 1.6));
    [this.approved, this.sold].forEach((s) => Object.assign(s.style, { left: '640px', top: '150px' }));
    // The urgent pair: the site's black sell-window box and its Sell now button.
    this.urgent = c.el('div', 'abs');
    this.urgent.innerHTML = `<div style="zoom:1.9;display:flex;gap:12px;align-items:center">
      <span class="countdown countdown--urgent"><svg class="icon"><use href="#i-timer"/></svg>Sell within <span class="countdown__time">06:59</span></span>
      <button class="btn btn--ink">Sell now<span class="btn__sub">90,000 PLEA</span></button></div>`;
    Object.assign(this.urgent.style, { left: '64px', top: '392px' });
    this.time = this.urgent.querySelector('.countdown__time');
    this.btn = this.urgent.querySelector('.btn');
    this.cursor = c.el('div', 'cursor', CURSOR);
    this.cap = c.el('div', 'cap', caption(['Approved: 7 minutes to sell.'], 'Sell now, or the window lapses'));
    [this.card, this.approved, this.sold, this.urgent, this.cursor, this.cap].forEach((e) => root.appendChild(e));
  },
  update(lt, t, c) {
    const { M, AT, BAR } = c;
    const a = M.stampLand(t - BAR(16), { from: 2, tilt: 0, tiltFrom: -11 });
    const tSold = AT(18, 2);
    c.show(this.approved, a.visible && t < tSold);
    this.approved.style.transform = `rotate(${a.rot}deg) scale(${a.scale})`;
    const s = M.stampLand(t - tSold, { from: 1.6, tilt: 0, tiltFrom: -11 });
    c.show(this.sold, s.visible);
    this.sold.style.transform = `rotate(${s.rot}deg) scale(${s.scale})`;
    const j = M.jolt(t - BAR(16) - 0.07, 8) + M.jolt(t - tSold - 0.07, 6);
    const enter = M.sp(t - 32.15, 'heavy');
    this.card.style.transform = `translate(${(1 - enter) * 1300}px, ${j}px)`;
    // The window opens on bar 17 and counts real seconds from 06:59.
    const u = M.sp(t - BAR(17), 'ui');
    c.show(this.urgent, t >= BAR(17));
    this.urgent.style.transform = `translateY(${(1 - u) * 60}px)`;
    const left = Math.max(0, 419 - Math.floor(Math.max(0, t - BAR(17))));
    this.time.textContent = `${String(Math.floor(left / 60)).padStart(2, '0')}:${String(left % 60).padStart(2, '0')}`;
    // Cursor glides to Sell now and presses on bar 18.
    const press = BAR(18);
    const g = M.sp(t - AT(17, 1.5), 'heavy');
    c.show(this.cursor, t >= AT(17, 1));
    const bx = 64 + 520, by = 392 + 50;
    this.cursor.style.left = `${M.mix(1150, bx, g)}px`;
    this.cursor.style.top = `${M.mix(640, by, g)}px`;
    const down = t >= press && t < press + 0.12;
    this.btn.style.transform = down ? 'translate(4px, 4px)' : '';
    this.btn.style.boxShadow = down ? 'none' : '';
    this.cursor.style.transform = down ? 'scale(0.88)' : '';
    const k = M.sp(t - AT(16, 1), 'snappy');
    c.show(this.cap, t >= AT(16, 1));
    this.cap.style.transform = `translateX(${(1 - k) * -80}px)`;
  },
};
