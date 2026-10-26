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
    Object.assign(inner.style, { width: '560px', zoom: c.pick(1.45, 1.1) });
    this.card.appendChild(inner);
    Object.assign(this.card.style, { left: c.pick('64px', '52px'), top: c.pick('44px', '110px') });
    this.sold = c.el('div', 'abs', zoom(stamp('sold', 'Sold', '35 vs need 35'), c.pick(1.6, 1.4)));
    Object.assign(this.sold.style, { left: c.pick('640px', '170px'), top: c.pick('150px', '360px') });
    this.slab = c.el('div', 'abs display', 'OBJECTION!');
    Object.assign(this.slab.style, { left: c.pick('120px', '26px'), top: c.pick('210px', '380px'), fontSize: c.pick('128px', '64px'), background: 'var(--objection)', border: '6px solid var(--ink)',
      borderRadius: '10px', padding: '14px 36px 8px', boxShadow: '12px 12px 0 var(--ink)', transformOrigin: '50% 50%' });
    // A second panel: 30 small seats flicker, then settle on 32.
    this.panel = c.el('div', 'abs');
    Object.assign(this.panel.style, { left: c.pick('860px', '180px'), top: c.pick('320px', '510px'), width: '360px', height: '200px' });
    const rand = c.M.rng(32);
    this.mini = [...Array(30)].map((_, i) => {
      const e = c.el('div', 'abs');
      Object.assign(e.style, { left: `${(i % 6) * 60}px`, top: `${Math.floor(i / 6) * 40}px`, width: '52px', height: '32px', border: '3px solid var(--ink)', borderRadius: '6px', background: 'var(--card)' });
      e.dataset.at = (rand() * 0.9).toFixed(3);
      this.panel.appendChild(e);
      return e;
    });
    this.sustained = c.el('div', 'abs', zoom(stamp('objection', 'Sustained', '32 vs need 35'), c.pick(1.5, 1.3)));
    Object.assign(this.sustained.style, { left: c.pick('700px', '150px'), top: c.pick('330px', '560px') });
    this.points = c.el('div', 'abs', '<span class="display" style="font-size:44px">+35 points</span>');
    Object.assign(this.points.style, { left: c.pick('64px', '40px'), top: c.pick('408px', '740px') });
    this.strike = c.el('div', 'abs');
    Object.assign(this.strike.style, { left: c.pick('58px', '34px'), top: c.pick('436px', '768px'), height: '8px', width: '330px', background: 'var(--denied)', transformOrigin: '0 50%' });
    this.stands = c.el('div', 'abs mono', 'no points · the sale stands');
    Object.assign(this.stands.style, { left: c.pick('64px', '40px'), top: c.pick('468px', '800px'), fontSize: '24px' });
    this.shot = c.el('div', 'capture');
    this.shot.innerHTML = `<img src="${c.capture('plea14-objected/objected.png')}" alt="">`;
    Object.assign(this.shot.style, c.pick({ left: '64px', top: '40px', width: '1152px', height: '480px' }, { left: '24px', top: '110px', width: '672px', height: '740px' }));
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
    if (t >= tc + 0.25) [this.sold, this.sustained, this.points, this.strike, this.stands, this.card].forEach((e) => c.show(e, false));
    const ck = M.sp(t - tc, 'ui');
    this.shot.style.transform = `translateY(${(1 - ck) * 720}px)`;
    const img = this.shot.firstElementChild;
    img.style.width = c.pick('1152px', '1440px'); img.style.transformOrigin = '0 0';
    const pz = M.clamp((t - tc) / 2);
    img.style.transform = c.pick(`translate(${-85 - 20 * pz}px, ${-90 - 20 * pz}px) scale(${1.3 + 0.03 * pz})`, `translate(${-100 - 10 * pz}px, ${-110 - 10 * pz}px) scale(${1 + 0.03 * pz})`);
    const k = M.sp(t - AT(19, 0.5), 'snappy');
    c.show(this.cap, t >= AT(19, 0.5));
    this.cap.style.transform = `translateX(${(1 - k) * -80}px)`;
  },
};
