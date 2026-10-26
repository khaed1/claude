// 11 · The dead-man (break 3): the 33-hour clock jumps to zero on the music's hits; in the silence
// the 30 seats go dark one by one; on the roll the lights go out and the run 9 site's dead banner drops.
import { caption } from '../lib/ui.js';

const HITS = [57.845, 58.815, 59.305, 60.765, 61.18];   // edit times of break 3 (original 94.67 … 98.0 s)
const SHOW = ['33:00:00', '24:00:00', '12:00:00', '01:00:00', '00:00:01', '00:00:00'];
const DARK_AT = 62.58;                                    // the drum roll: lights out

export default {
  id: 'deadman',
  from: (c) => c.BAR(28),
  to: (c) => c.BAR(32),
  build(root, c) {
    this.root = root;
    this.label = c.el('div', 'abs label', 'The Cabal’s dead-man · no signed verdict for');
    Object.assign(this.label.style, { left: c.pick('66px', '40px'), top: c.pick('150px', '300px'), fontSize: '22px' });
    this.clock = c.el('div', 'abs mono', SHOW[0]);
    Object.assign(this.clock.style, { left: c.pick('58px', '34px'), top: c.pick('176px', '330px'), fontSize: c.pick('180px', '120px'), lineHeight: '1', transformOrigin: '0 50%' });
    this.seats = [...Array(30)].map((_, i) => {
      const e = c.el('div', 'abs');
      Object.assign(e.style, { left: `${c.pick(64 + i * 38, 40 + (i % 15) * 42)}px`, top: `${c.pick(392, 490 + Math.floor(i / 15) * 42)}px`, width: '30px', height: '30px', border: '3px solid var(--ink)', borderRadius: '6px', background: 'var(--card)' });
      root.appendChild(e);
      return e;
    });
    this.banner = c.el('div', 'abs');
    Object.assign(this.banner.style, { left: '0', top: '0', width: c.pick('1280px', '720px'), height: '118px', overflow: 'hidden', borderBottom: '3px solid var(--ink)' });
    if (c.V) {   // 9:16: the capture's one-line banner is too wide to read; the site's own banner component and words, wrapped
      Object.assign(this.banner.style, { height: 'auto', borderBottom: '0' });
      this.banner.innerHTML = '<div class="banner" style="zoom:1.3"><div class="page" style="padding-inline:16px"><span class="live-dot live-dot--dead"></span><p>The Cabal is dead: no verdict for 33 hours. PLEA trades freely forever. Pleas and objections are closed; sell on the Buy page.</p></div></div>';
    } else {
      this.bannerImg = c.el('img');
      this.bannerImg.src = c.capture('dead-dark/home.png');
      Object.assign(this.bannerImg.style, { width: '1800px', transformOrigin: '0 0' });
      this.banner.appendChild(this.bannerImg);
    }
    this.cap = c.el('div', 'cap', caption(['33 hours, no verdict:', 'the Cabal dies.']));
    [this.label, this.clock, this.banner, this.cap].forEach((e) => root.appendChild(e));
  },
  update(lt, t, c) {
    const { M, BAR, AT } = c;
    let i = 0; while (i < HITS.length && t >= HITS[i]) i++;
    this.clock.textContent = SHOW[i];
    const last = i ? HITS[i - 1] : BAR(28);
    const pop = M.sp(t - last, 'snappy');
    this.clock.style.transform = `translateY(${M.jolt(t - last, 7)}px) scale(${M.mix(1.08, 1, pop)})`;
    const dead = t >= HITS[4];
    this.clock.style.color = dead ? 'var(--denied-text)' : '';
    this.seats.forEach((e, k) => {
      const off = t >= HITS[4] + 0.045 * k;
      e.style.background = off ? '#2c2a24' : 'var(--card)';
      e.style.borderColor = off ? '#2c2a24' : 'var(--ink)';
    });
    const dark = t >= DARK_AT;
    this.root.classList.toggle('theme-dark', dark);
    this.root.classList.toggle('theme-light', !dark);
    // The site's own dead banner (live run 9 site, dark theme), cropped from the capture.
    const b = M.sp(t - (DARK_AT + 0.1), 'ui');
    c.show(this.banner, dark);
    this.banner.style.transform = `translateY(${(1 - b) * -90}px)`;
    if (this.bannerImg) this.bannerImg.style.transform = 'translate(-125px, -85px)';   // strip + banner of the 1440-px page at 1.25x
    const lines = this.cap.querySelectorAll('.cap__main');
    [[lines[0], AT(28, 1)], [lines[1], AT(28, 3)]].forEach(([e, at]) => {
      c.show(e, t >= at);
      e.style.transform = `translateX(${(1 - M.sp(t - at, 'snappy')) * -80}px)`;
    });
  },
};
