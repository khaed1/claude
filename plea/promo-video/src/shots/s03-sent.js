// 3 · Sent (bars 5-6): plea #14 lifts out of the form as the site's plea card, folds into an
// envelope, slides into the docket beside the day's other pleas, and a receipt drops.
import { pleaCard, stamp, caption, DATA } from '../lib/ui.js';

const ENVELOPE = `<svg viewBox="0 0 440 260" width="440" height="260"><rect x="3" y="3" width="434" height="254" rx="10" fill="var(--paper-2)" stroke="var(--ink)" stroke-width="6"/>
  <path d="M6 10 L220 150 L434 10" fill="none" stroke="var(--ink)" stroke-width="6" stroke-linejoin="round"/>
  <path d="M6 250 L170 118 M434 250 L270 118" stroke="var(--ink)" stroke-width="4" opacity=".55"/></svg>`;

export default {
  id: 'sent',
  from: (c) => c.BAR(5),
  to: (c) => c.BAR(7),
  build(root, c) {
    const p = DATA.p14;
    // The docket: two of the same evening's pleas, pending, stacked on the right.
    this.docket = [13, 15].map((id, i) => {
      const d = c.el('div', 'abs');
      const inner = c.el('div', 'card', `<div class="cluster cluster--between"><span class="plea__id">Plea #${id}</span>${stamp('pending', 'Pending', '', 'sm')}</div>
        <div class="meta" style="margin-top:8px">Thu 18:25 UTC · Sepolia test run 9</div>`);
      Object.assign(inner.style, { width: '280px', zoom: 1.35 });
      d.appendChild(inner);
      Object.assign(d.style, { left: `${830 + i * 20}px`, top: `${96 + i * 30}px`, transform: `rotate(${i ? 2 : -2}deg)` });
      root.appendChild(d);
      return d;
    });
    this.card = c.el('div', 'abs');
    const inner = c.el('div', 'card', pleaCard(p));
    Object.assign(inner.style, { width: '560px', zoom: 1.45 });
    this.card.appendChild(inner);
    Object.assign(this.card.style, { left: '64px', top: '56px', transformOrigin: '50% 50%' });
    root.appendChild(this.card);
    this.env = c.el('div', 'abs', ENVELOPE);
    Object.assign(this.env.style, { left: '200px', top: '120px', transformOrigin: '50% 50%' });
    this.envStamp = c.el('div', 'abs', stamp('pending', 'Pending', 'Plea #14', 'lg'));
    Object.assign(this.envStamp.style, { left: '120px', top: '86px' });
    this.env.appendChild(this.envStamp);
    root.appendChild(this.env);
    this.receipt = c.el('div', 'receipt', '<div class="receipt__small">Oracle fee</div><div class="receipt__big">0.5 paid</div><div class="receipt__small">to IMD · Thu 18:25 UTC</div>');
    Object.assign(this.receipt.style, { left: '930px', top: '392px', width: '290px' });
    root.appendChild(this.receipt);
    this.wait = c.el('div', 'abs', `<div class="display" style="font-size:60px;line-height:1.05">Waiting for<br>the Cabal</div><div class="meta" style="font-size:20px;margin-top:10px">up to 20 minutes, usually 3 to 6</div>`);
    Object.assign(this.wait.style, { left: '64px', top: '96px' });
    root.appendChild(this.wait);
    this.cap = c.el('div', 'cap', caption(['The Cabal takes no bribes.', 'Just a 0.5 IMD fee.']));
    root.appendChild(this.cap);
  },
  update(lt, t, c) {
    const { M, AT, BAR } = c;
    const t0 = BAR(5);
    // The card appears where the form was, then folds (squashes) on beat 1 and becomes the envelope.
    const fold = M.sp(t - AT(5, 1), 'snappy');
    const lift = M.sp(t - t0, 'ui');
    const cardOn = t < AT(5, 1.6);
    c.show(this.card, cardOn);
    this.card.style.transform = `translateY(${(1 - lift) * 24}px) scale(${1 - 0.04 * (1 - lift)}, ${M.mix(1, 0.08, fold)})`;
    // Envelope: pops from the fold, then slides to the docket on beat 2.5 and lands on bar 6.
    const pop = M.sp(t - AT(5, 1.5), 'snappy');
    const slide = M.sp(t - AT(5, 2.5), 'heavy');
    c.show(this.env, t >= AT(5, 1.5));
    const x = M.mix(0, 640, slide), y = M.mix(0, -6, slide), r = M.mix(0, 4, slide);
    this.env.style.transform = `translate(${x}px, ${y}px) rotate(${r}deg) scale(${M.mix(0.6, 1, pop) * M.mix(1, 0.78, slide)})`;
    const st = M.stampLand(t - AT(5, 3.2), { from: 1.5, tilt: 0, tiltFrom: -11 });
    c.show(this.envStamp, st.visible);
    this.envStamp.style.transform = `rotate(${st.rot}deg) scale(${st.scale})`;
    // The docket stack is there from the start; it nudges when the envelope lands.
    const bump = M.jolt(t - AT(5, 3.3), 5);
    this.docket.forEach((d, i) => { d.style.transform = `translateY(${bump}px) rotate(${i ? 2 : -2}deg)`; });
    // The site's own step name, top left, as the envelope travels.
    const w = M.sp(t - AT(5, 2.5), 'type');
    c.show(this.wait, t >= AT(5, 2.5));
    this.wait.style.transform = `translateY(${(1 - w) * -60}px)`;
    // Receipt drops on bar 6, beat 1.
    const rc = M.sp(t - AT(6, 1), 'ui');
    c.show(this.receipt, t >= AT(6, 1));
    this.receipt.style.transform = `translateY(${(1 - rc) * -60}px) rotate(${M.mix(-8, 3, rc)}deg)`;
    // Caption lines on bar 6 and bar 6 beat 2.
    const lines = this.cap.querySelectorAll('.cap__main');
    [BAR(6), AT(6, 2)].forEach((at, i) => {
      const k = M.sp(t - at, 'snappy');
      c.show(lines[i], t >= at);
      lines[i].style.transform = `translateX(${(1 - k) * -80}px)`;
    });
  },
};
