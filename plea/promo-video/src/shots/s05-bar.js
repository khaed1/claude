// 5 · The bar (bars 11-12): plea #14's four real fact cards drop on the beats, the need is worked
// out (71 − 36 = 35), the site's meter draws the need marker and the panel's 35 rises to meet it.
import { fact, caption, DATA } from '../lib/ui.js';

export default {
  id: 'bar',
  from: (c) => c.BAR(11),
  to: (c) => c.BAR(13),
  build(root, c) {
    const p = DATA.p14;
    this.label = c.el('div', 'abs display', 'Plea #14’s bar');
    Object.assign(this.label.style, { left: '64px', top: '48px', fontSize: '52px' });
    this.facts = p.facts.map(([l, v, pts], i) => {
      const f = c.el('div', 'abs');
      const inner = c.el('div', '', fact(l, v, pts));
      Object.assign(inner.style, { width: '160px', zoom: 1.7 });
      f.appendChild(inner);
      Object.assign(f.style, { left: `${64 + i * 292}px`, top: '128px' });
      root.appendChild(f);
      return f;
    });
    this.sum = c.el('div', 'abs mono', `fact 36 &nbsp;→&nbsp; need = 71 − 36 = <b>35</b>`);
    Object.assign(this.sum.style, { left: '64px', top: '290px', fontSize: '34px' });
    this.meterWrap = c.el('div', 'abs');
    Object.assign(this.meterWrap.style, { left: '64px', top: '372px' });
    this.meterWrap.innerHTML = `<div class="meter meter--pending" style="width:575px;zoom:2"><div class="meter__bar"><div class="meter__fill"></div><div class="meter__need"></div></div>
      <div class="meter__scale"><span>0</span><span>45</span></div></div>`;
    this.legend = c.el('div', 'abs mono', 'judges 35 · need 35');
    Object.assign(this.legend.style, { left: '64px', top: '470px', fontSize: '24px' });
    this.cap = c.el('div', 'cap', caption(['The facts set your bar.'], 'what you sell · how long you held · profit or loss · the trend'));
    [this.label, this.sum, this.meterWrap, this.legend, this.cap].forEach((e) => root.appendChild(e));
  },
  update(lt, t, c) {
    const { M, AT, BAR } = c;
    const l = M.sp(t - BAR(11), 'type');
    this.label.style.transform = `translateY(${(1 - l) * -50}px)`;
    this.facts.forEach((f, i) => {
      const at = AT(11, i);
      c.show(f, t >= at);
      const k = M.sp(t - at, 'ui');
      f.style.transform = `translateY(${(1 - k) * -40}px)`;
    });
    c.show(this.sum, t >= BAR(12));
    const s = M.sp(t - BAR(12), 'snappy');
    this.sum.style.transform = `translateX(${(1 - s) * -40}px)`;
    const need = 35 * M.sp(t - BAR(12), 'heavy');
    const score = 35 * M.sp(t - AT(12, 2), 'heavy');
    const m = this.meterWrap.firstElementChild;
    m.style.setProperty('--need', need.toFixed(3));
    m.style.setProperty('--score', score.toFixed(3));
    c.show(this.meterWrap, t >= AT(11, 3.5));
    c.show(this.legend, t >= AT(12, 2.5));
    const k = M.sp(t - AT(11, 0.5), 'snappy');
    c.show(this.cap, t >= AT(11, 0.5));
    this.cap.style.transform = `translateX(${(1 - k) * -80}px)`;
  },
};
