// 10 · Seasons (bars 25-27): the run 9 Seasons page on a Sepolia fork as season key 15 closes
// (block 11,986,640 → 11,986,643); the camera scrolls to the leaderboard, a PRIZE PAID stamp lands
// on the top row (79 points, 1st).
import { stamp, caption, zoom } from '../lib/ui.js';

export default {
  id: 'seasons',
  from: (c) => c.BAR(25),
  to: (c) => c.BAR(28),
  build(root, c) {
    this.frame = c.el('div', 'capture');
    Object.assign(this.frame.style, { left: '64px', top: '36px', width: '1152px', height: '470px' });
    this.img = c.el('img');
    this.img.src = c.capture('seasons/closed-full.png');
    this.frame.appendChild(this.img);
    this.prize = c.el('div', 'abs', zoom(stamp('approved', 'Prize paid', '79 points · 1st', 'lg'), 1.5));
    Object.assign(this.prize.style, { left: '860px', top: '300px' });
    this.cap = c.el('div', 'cap', caption(['Every win scores. Top 25 split the pot.'], '+ 10,000,000 PLEA a season for the first six · IMD seat holders score 1.2×'));
    [this.frame, this.prize, this.cap].forEach((e) => root.appendChild(e));
  },
  update(lt, t, c) {
    const { M, AT, BAR } = c;
    const k = M.sp(t - BAR(25), 'ui');
    this.frame.style.transform = `translateY(${(1 - k) * 60}px)`;
    // Scroll (a spring) from the top of the page to the leaderboard rows (offsets set in this.view).
    const v = this.view || { scale: 0.4, y0: 0, y1: -600 };
    const s = M.sp(t - AT(25, 1), 'heavy');
    this.img.style.transform = `translateY(${M.mix(v.y0, v.y1, s)}px) scale(${v.scale})`;
    const st = M.stampLand(t - BAR(27), { from: 1.8, tilt: 0, tiltFrom: -11 });
    c.show(this.prize, st.visible);
    this.prize.style.transform = `rotate(${st.rot}deg) scale(${st.scale})`;
    const ck = M.sp(t - AT(25, 0.5), 'snappy');
    c.show(this.cap, t >= AT(25, 0.5));
    this.cap.style.transform = `translateX(${(1 - ck) * -80}px)`;
  },
};
