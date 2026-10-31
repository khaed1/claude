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
    Object.assign(this.frame.style, c.pick({ left: '64px', top: '36px', width: '1152px', height: '470px' }, { left: '24px', top: '110px', width: '672px', height: '740px' }));
    this.img = c.el('img');
    this.img.src = c.capture('seasons/a-leaderboard.png');
    this.img2 = c.el('img');
    this.img2.src = c.capture('seasons/b-past-season16.png');
    this.frame.appendChild(this.img);
    this.frame.appendChild(this.img2);
    [this.img, this.img2].forEach((i) => Object.assign(i.style, { position: 'absolute', left: '0', top: '0', width: c.pick('1152px', '1080px'), transformOrigin: '0 0' }));
    this.prize = c.el('div', 'abs', zoom(stamp('approved', 'Prize paid', '79 points · 1st', 'lg'), c.pick(1.6, 1.4)));
    Object.assign(this.prize.style, { left: c.pick('820px', '170px'), top: c.pick('330px', '560px') });
    this.cap = c.el('div', 'cap', caption(['Every win scores. Top 25 split the pot.'], '+ 10,000,000 PLEA a season for the first six · IMD seat holders score 1.2×'));
    // An ink outline draws itself around the top row (rank 1, 79 points) on bar 26.
    this.mark = c.el('div', 'abs');
    Object.assign(this.mark.style, c.pick({ left: '70px', top: '150px', width: '1140px', height: '44px' }, { left: '30px', top: '212px', width: '662px', height: '40px' }), { border: '4px solid var(--ink)', borderRadius: '8px', transformOrigin: '0 50%', boxShadow: '4px 4px 0 var(--action)' });
    [this.frame, this.mark, this.prize, this.cap].forEach((e) => root.appendChild(e));
  },
  update(lt, t, c) {
    const { M, AT, BAR } = c;
    const k = M.sp(t - BAR(25), 'ui');
    this.frame.style.transform = `translateY(${(1 - k) * 60}px)`;
    // Before the close (block 11,986,640): push in on the leaderboard's top row. Bar 27: closed (11,986,643).
    const s = M.sp(t - AT(25, 1), 'heavy');
    this.img.style.transform = c.pick(`translate(${-40 - 60 * s}px, ${20 - 30 * s}px) scale(${1.05 + 0.15 * s})`, `translate(${-95 - 15 * s}px, ${10 - 20 * s}px) scale(${1 + 0.08 * s})`);
    const closed = t >= BAR(27);
    c.show(this.img, !closed); c.show(this.img2, closed);
    this.img2.style.transform = c.pick(`translate(-60px, 10px) scale(${1.15 + 0.03 * M.clamp((t - BAR(27)) / 2)})`, `translate(-60px, 10px) scale(${1.05 + 0.03 * M.clamp((t - BAR(27)) / 2)})`);
    c.show(this.mark, t >= BAR(26) && t < BAR(27));
    this.mark.style.transform = `scaleX(${M.sp(t - BAR(26), 'heavy')})`;
    const st = M.stampLand(t - BAR(27), { from: 1.8, tilt: 0, tiltFrom: -11 });
    c.show(this.prize, st.visible);
    this.prize.style.transform = `rotate(${st.rot}deg) scale(${st.scale})`;
    const ck = M.sp(t - AT(25, 0.5), 'snappy');
    c.show(this.cap, t >= AT(25, 0.5));
    this.cap.style.transform = `translateX(${(1 - ck) * -80}px)`;
  },
};
