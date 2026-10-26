// 6 · DENIED (break 1): on the music's hits, plea #1 (airdrop only, 15 minutes held) and its meter;
// the DENIED stamp lands on the last hit, and the silence carries the verdict.
import { pleaCard, stamp, caption, zoom, DATA } from '../lib/ui.js';

const HITS = [27.58, 27.84, 28.08, 29.54];   // the edit's break-1 hits (original 33.20, 33.46, 33.70, 35.16 s)

export default {
  id: 'denied',
  from: (c) => c.BAR(13),
  to: (c) => c.BAR(16),
  build(root, c) {
    const p = DATA.p1;
    this.card = c.el('div', 'abs');
    const inner = c.el('div', 'card', pleaCard(p));
    Object.assign(inner.style, { width: '560px', zoom: 1.45 });
    this.card.appendChild(inner);
    Object.assign(this.card.style, { left: '64px', top: '44px' });
    this.meter = c.el('div', 'abs');
    this.meter.innerHTML = `<div class="meter meter--denied" style="width:400px;zoom:2;--score:0;--need:40"><div class="meter__bar"><div class="meter__fill"></div><div class="meter__need"></div></div>
      <div class="meter__scale"><span>0</span><span>45</span></div></div>`;
    Object.assign(this.meter.style, { left: '64px', top: '384px' });
    this.legend = c.el('div', 'abs mono', 'judges 27 · need 40 · 13 short');
    Object.assign(this.legend.style, { left: '64px', top: '474px', fontSize: '24px', color: 'var(--denied-text)' });
    this.stamp = c.el('div', 'abs', zoom(stamp('denied', 'Denied', '27 vs need 40'), 1.9));
    Object.assign(this.stamp.style, { left: '800px', top: '330px' });
    this.cap = c.el('div', 'cap', caption(['Denied: wait 4 hours, one appeal.'], 'On Sepolia, 4 of 25 pleas got through.'));
    [this.card, this.meter, this.legend, this.stamp, this.cap].forEach((e) => root.appendChild(e));
  },
  update(lt, t, c) {
    const { M, AT, BAR } = c;
    const [h1, h2, h3, h4] = HITS;
    const out = M.sp(t - 31.85, 'heavy');                 // the roll wipes everything off to the left
    const j = M.jolt(t - h1, 6) + M.jolt(t - h4 - 0.05, 9);
    this.card.style.transform = `translate(${-1400 * out}px, ${j}px)`;
    c.show(this.meter, t >= h2);
    const fill = 27 * M.sp(t - h2, 'heavy');
    this.meter.firstElementChild.style.setProperty('--score', fill.toFixed(3));
    this.meter.style.transform = `translateX(${-1400 * out}px)`;
    c.show(this.legend, t >= h3);
    this.legend.style.transform = `translateX(${-1400 * out}px) scale(${M.mix(1.3, 1, M.sp(t - h3, 'snappy'))})`;
    const st = M.stampLand(t - h4, { from: 2.2, tilt: 0, tiltFrom: -11 });
    c.show(this.stamp, st.visible);
    this.stamp.style.transform = `translateX(${-1400 * out / 1.7}px) rotate(${st.rot}deg) scale(${st.scale})`;
    const cm = this.cap.querySelector('.cap__main'), cs = this.cap.querySelector('.cap__small');
    c.show(cm, t >= 30.15); c.show(cs, t >= 30.95);
    cm.style.transform = `translateX(${(1 - M.sp(t - 30.15, 'snappy')) * -80 - 1400 * out}px)`;
    cs.style.transform = `translateX(${(1 - M.sp(t - 30.95, 'snappy')) * -80 - 1400 * out}px)`;
  },
};
