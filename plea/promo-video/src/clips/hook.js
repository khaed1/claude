// Clip hook (bar 0): the series tag, then a question dropping in word by word on the beats,
// and a one-line answer on beat 3. opts: { lines: [[word, …], …], small }
import { esc } from '../lib/ui.js';

export default {
  build(root, c, opts) {
    const cfg = c.clip;
    this.tag = c.el('div', 'abs', `<span class="cap__small" style="background:var(--action);color:var(--ink)">How PLEA works · ${cfg.n} of 7</span>`);
    Object.assign(this.tag.style, { left: c.pick('64px', '40px'), top: c.pick('96px', '170px') });
    this.head = c.el('div', 'abs display');
    Object.assign(this.head.style, { left: c.pick('64px', '40px'), top: c.pick('160px', '240px'), fontSize: c.pick('104px', '92px'), lineHeight: '1.04' });
    this.words = [];
    const lines = c.pick(opts.lines, opts.vlines || opts.lines);
    let k = 0;
    lines.forEach((ws) => {
      const line = c.el('div');
      ws.forEach((w, j) => {
        const m = c.el('span', 'mask'); const s = c.el('span', '', esc(w));
        m.appendChild(s); line.appendChild(m);
        if (j < ws.length - 1) line.appendChild(document.createTextNode(' '));
        this.words.push({ s, beat: 0.5 + 0.5 * k++ });
      });
      this.head.appendChild(line);
    });
    this.small = c.el('div', 'cap', opts.small ? `<span class="cap__main">${esc(opts.small)}</span>` : '');
    [this.tag, this.head, this.small].forEach((e) => root.appendChild(e));
  },
  update(lt, t, c) {
    const { M, AT } = c;
    const tg = M.sp(t - AT(0, 0), 'snappy');
    this.tag.style.transform = `translateY(${(1 - tg) * -40}px)`;
    for (const w of this.words) w.s.style.transform = `translateY(${(1 - M.sp(t - AT(0, w.beat), 'type')) * 125}%)`;
    const k = M.sp(t - AT(0, 3), 'snappy');
    c.show(this.small, t >= AT(0, 3));
    this.small.style.transform = `translateX(${(1 - k) * -80}px)`;
  },
};
