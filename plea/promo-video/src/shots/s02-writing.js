// 2 · Writing the plea (bars 2-4): the real Plead page as p2 saw it before plea #14 (Sepolia fork at
// block 11,971,312, Thu 18:25 UTC). The amount and the fact score, then plea #14's text typed one
// character a frame (268 real captures, the byte counter climbing), then Submit plea is pressed.
import { caption } from '../lib/ui.js';

const CURSOR = `<svg viewBox="0 0 24 24"><path d="M3 2 L3 20 L8 15 L11.5 22 L14.5 20.6 L11 13.8 L18 13.8 Z" fill="var(--ink)" stroke="var(--card)" stroke-width="1.6" stroke-linejoin="round"/></svg>`;
const N = 268;
// Views of the 1440 x 900 capture (CSS px): [x, y, scale] (stage px per capture px).
const TOP = [56, 96, 0.95];        // amount.png: title, amount 90000, the fact score
const TEXT = [80, 22, 1.4];        // typing frames (page scrolled to the plea box)
const SUBMIT = [80, 470, 1.4];     // the Submit plea button, same scroll

export default {
  id: 'writing',
  from: (c) => c.BAR(2),
  to: (c) => c.BAR(5),
  build(root, c) {
    this.frame = c.el('div', 'capture');
    Object.assign(this.frame.style, { left: '64px', top: '36px', width: '1152px', height: '480px' });
    this.img = c.el('img');
    this.img.src = c.capture('plead-typing/amount.png');
    this.frame.appendChild(this.img);
    this.cursor = c.el('div', 'cursor', CURSOR);
    this.cap = c.el('div', 'cap', caption(['Want to sell? Write the Cabal a plea.'], 'up to 280 bytes, any language'));
    [this.frame, this.cursor, this.cap].forEach((e) => root.appendChild(e));
    this.c = c;
  },
  view([x, y, s]) {
    this.img.style.width = `${1440 * s}px`;
    this.img.style.transform = `translate(${-x * s}px, ${-y * s}px)`;
  },
  update(lt, t, c) {
    const { M, AT, BAR } = c;
    const tType = AT(2, 2), tDone = AT(4, 1.5), tPan = AT(4, 2), tPress = AT(4, 3.5);
    let src, v;
    if (t < tType) { src = 'plead-typing/amount.png'; v = TOP; }
    else if (t < tPan) {
      const n = Math.min(N - 1, Math.floor(((t - tType) / (tDone - tType)) * N));
      src = t < tType + 0.05 ? 'plead-typing/empty.png' : `plead-typing/${String(Math.max(0, n)).padStart(4, '0')}.png`;
      v = TEXT;
    } else {
      src = t >= AT(4, 3) ? 'plead-typing/hover.png' : 'plead-typing/0267.png';
      const k = M.sp(t - tPan, 'heavy');
      v = [TEXT[0], M.mix(TEXT[1], SUBMIT[1], k), TEXT[2]];
    }
    const url = c.capture(src);
    if (!this.img.src.endsWith(url)) this.img.src = url;
    // A slow push-in on the first view.
    if (v === TOP) { const p = M.clamp((t - BAR(2)) / (tType - BAR(2))); v = [TOP[0] + 20 * p, TOP[1] + 10 * p, TOP[2] * (1 + 0.03 * p)]; }
    this.view(v);
    const enter = M.sp(t - BAR(2), 'ui');
    this.frame.style.transform = `translateY(${(1 - enter) * 40}px)`;
    // Cursor: glides to Submit plea, presses on beat 3.5 of bar 4.
    c.show(this.cursor, t >= AT(4, 2.5));
    const g = M.sp(t - AT(4, 2.5), 'heavy');
    const bx = 64 + (500 - SUBMIT[0]) * SUBMIT[2], by = 36 + (762 - SUBMIT[1]) * SUBMIT[2];
    this.cursor.style.left = `${M.mix(1180, bx, g)}px`;
    this.cursor.style.top = `${M.mix(600, by, g)}px`;
    this.cursor.style.transform = t >= tPress && t < tPress + 0.12 ? 'scale(0.86)' : '';
    const k = M.sp(t - BAR(3), 'snappy');
    c.show(this.cap, t >= BAR(3));
    this.cap.style.transform = `translateX(${(1 - k) * -80}px)`;
  },
};
