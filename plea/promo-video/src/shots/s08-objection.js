// 8 · OBJECTION! (bars 19-21): the word slams across plea #14; a second panel re-scores it 32,
// the objection is SUSTAINED, the points are struck and the sale stands. Then the real #14 page.
import { pleaCard, stamp, caption, zoom, DATA } from '../lib/ui.js';

export default {
  id: 'objection',
  from: (c) => c.BAR(19),
  to: (c) => c.BAR(22),
  build(root, c) {
    const p = DATA.p14;
    this.card = c.el('div', 'abs');
    const inner = c.el('div', 'card', pleaCard(p));
    Object.assign(inner.style, { width: '560px', zoom: 1.45 });
    this.card.appendChild(inner);
    Object.assign(this.card.style, { left: '64px', top: '44px' });
    this.sold = c.el('div', 'abs', zoom(stamp('sold', 'Sold', '35 vs need 35'), 1.6));
    Object.assign(this.sold.style, { left: '640px', top: '150px' });
    this.slab = c.el('div', 'abs display', 'OBJECTION!');
    Object.assign(this.slab.style, { left: '120px', top: '210px', fontSize: '128px', background: 'var(--objection)', border: '6px solid var(--ink)',
      borderRadius: '10px', padding: '14px 36px 8px', boxShadow: '12px 12px 0 var(--ink)', transformOrigin: '50% 50%' });
    // A second panel: 30 small seats flicker, then settle on 32.
    this.panel = c.el('div', 'abs');
    Object.assign(this.panel.style, { left: '860px', top: '320px', width: '360px', height: '200px' });
    const rand = c.M.rng(32);
    this.mini = [...Array(30)].map((_, i) => {
      const e = c.el('div', 'abs');
      Object.assign(e.style, { left: `${(i % 6) * 60}px`, top: `${Math.floor(i / 6) * 40}px`, width: '52px', height: '32px', border: '3px solid var(--ink)', borderRadius: '6px', background: 'var(--card)' });
      e.dataset.at = (rand() * 0.9).toFixed(3);
      this.panel.appendChild(e);
      return e;
    });
    this.sustained = c.el('div', 'abs', zoom(stamp('objection', 'Sustained', '32 vs need 35'), 1.5));
    Object.assign(this.sustained.style, { left: '700px', top: '330px' });
    this.points = c.el('div', 'abs', '<span class="display" style="font-size:44px">+35 points</span>');
    Object.assign(this.points.style, { left: '64px', top: '408px' });
    this.strike = c.el('div', 'abs');
    Object.assign(this.strike.style, { left: '58px', top: '436px', height: '8px', width: '330px', background: 'var(--denied)', transformOrigin: '0 50%' });
    this.stands = c.el('div', 'abs mono', 'no points · the sale stands');
    Object.assign(this.stands.style, { left: '64px', top: '468px', fontSize: '24px' });
    this.shot = c.el('div', 'capture');
    this.shot.innerHTML = `<img src="${c.capture('plea14-objected/viewport.png')}" alt="">`;
    Object.assign(this.shot.style, { left: '64px', top: '40px', width: '1152px', height: '480px' });
    this.cap = c.el('div', 'cap', caption(['Think it got off easy?'], 'Anyone can object for 20 minutes. A fresh panel re-scores.'));
    [this.card, this.sold, this.panel, this.sustained, this.points, this.strike, this.stands, this.shot, this.slab, this.cap].forEach((e) => root.appendChild(e));
  },
  update(lt, t, c) {
    const { M, AT, BAR } = c;
    // The slam on the downbeat, off again on beat 2.
    const inK = M.sp(t - BAR(19), 'stamp'), outK = M.sp(t - AT(19, 2), 'heavy');
    c.show(this.slab, t < AT(19, 3.5));
    this.slab.style.transform = `translateX(${outK * 1500}px) rotate(${M.mix(-20, -6, inK)}deg) scale(${M.mix(2.2, 1, inK)})`;
    const j = M.jolt(t - BAR(19) - 0.06, 10);
    this.card.style.transform = `translateY(${j}px)`;
    // Second panel from beat 2: seats flicker (seeded), then all settle.
    const t2 = AT(19, 2);
    c.show(this.panel, t >= t2 && t < BAR(20));
    this.mini.forEach((e) => {
      const at = t2 + Number(e.dataset.at);
      e.style.background = t >= at ? 'var(--objection)' : 'var(--card)';
    });
    const s = M.stampLand(t - BAR(20), { from: 1.8, tilt: 0, tiltFrom: -11 });
    c.show(this.sustained, s.visible);
    this.sustained.style.transform = `rotate(${s.rot - 2}deg) scale(${s.scale})`;
    c.show(this.points, t >= AT(19, 1));
    const sk = M.sp(t - AT(20, 1.5), 'snappy');
    c.show(this.strike, t >= AT(20, 1.5));
    this.strike.style.transform = `scaleX(${sk}) rotate(-2deg)`;
    c.show(this.stands, t >= AT(20, 2.5));
    // Bar 21: the real page after both objections (Sepolia fork capture), pushing in.
    const tc = BAR(21);
    c.show(this.shot, t >= tc);
    const ck = M.sp(t - tc, 'ui');
    this.shot.style.transform = `translateY(${(1 - ck) * 720}px)`;
    const img = this.shot.firstElementChild;
    img.style.transform = `scale(${0.8 + 0.03 * M.clamp((t - tc) / 2)})`;
    const k = M.sp(t - AT(19, 0.5), 'snappy');
    c.show(this.cap, t >= AT(19, 0.5));
    this.cap.style.transform = `translateX(${(1 - k) * -80}px)`;
  },
};
