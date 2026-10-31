// PLEA airdrop · Contest: "Plead your case" (the X contest for 75 of the 2% airdrop's 125 wallets, 160,000 PLEA each,
// every plea judged by one IMD swarm job; HANDOFF 2026-10-30). The three steps are shown on the owner's real X
// screenshots (CAPTURES/contest/: profile.png, post.png = the contest post before posting, pinned.png = the pinned
// video post); the action icons are cut from pinned.png's own action bar (CAPTURES/contest/icons/). The reply is an
// example, labelled so. Two cuts from this one scene: clip10 (cfg.fx false: the plain cut) and clip11 (cfg.fx true:
// camera pushes onto each button, click bursts, the heart pop and the repost spin, rolling counters, the 75 seats
// filling, a stamp slam and confetti on the hit).
import { chrome, headline, recap, piece, cursor, press, verdict } from './kit.js';
import { esc } from '../lib/ui.js';

const X = { dim: '#141414', gray: '#71767B', text: '#E7E9EA', blue: '#1D9BF0', green: '#00BA7C', pink: '#F91880', line: '#2F3336', pill: '#EFF3F4', edge: '#536471' };
const PLEA = 'Dear Cabal: I bought every dip, read every rule, and still can’t sell without your blessing. Choose me and I’ll plead with honour.';
const WALLET = '0xYOUR…WALLET', TAG = '@yourfriend';
const FULL = `${PLEA}\n${WALLET} ${TAG}`;
const ICON = { reply: [108, 146], repost: [340, 383], like: [577, 615], views: [814, 846], bookmark: [1048, 1080], share: [1109, 1144] };   // x ranges in pinned.png, rows 858-908
const ICON_Y0 = 858, ICON_H = 50;

// A screenshot in a frame: the crop (sx, sy, sw, sh) of an image natW wide, at scale s, plus `extra` px below it.
// Overlays go into `z` (the zoomer) at frame coordinates; fx(x, y) maps image pixels to frame coordinates.
function shot(L, c, { src, natW, sx, sy, sw, sh, s, extra = 0, bg = '#000', left, top, at, out, dx = 70, dy = 0, kind = 'heavy' }) {
  const w = sw * s, h = sh * s + extra;
  const p = piece(L, c, `<div class="sx-x" style="width:${w}px;height:${h}px;background:${bg}"><div class="sx-x__z" style="width:${w}px;height:${h}px">
      <img src="${c.capture(`contest/${src}`)}" style="position:absolute;left:${-sx * s}px;top:${-sy * s}px;width:${natW * s}px"></div></div>`,
    { left, top, at, out, dx, dy, kind });
  return Object.assign(p, { z: p.e.querySelector('.sx-x__z'), w, h, s, fx: (x, y) => [(x - sx) * s, (y - sy) * s], origin: [left + 3, top + 3] });
}
const add = (parent, html, style) => { const d = document.createElement('div'); d.innerHTML = html; const e = d.firstElementChild || d; if (style) Object.assign(e.style, style); parent.appendChild(e); return e; };
const icon = (parent, name, tone, x, y, s) => add(parent, `<img src="${'/captures/contest/icons/' + name + '-' + tone + '.png'}">`,
  { position: 'absolute', left: `${x}px`, top: `${y}px`, width: `${(ICON[name][1] - ICON[name][0]) * s}px`, height: `${ICON_H * s}px` });

// A ring that pulses around a target until it is pressed.
function ring(parent, c, { x, y, w, h, r = 999 }) {
  const e = add(parent, '<div></div>', { position: 'absolute', left: `${x}px`, top: `${y}px`, width: `${w}px`, height: `${h}px`, boxSizing: 'border-box',
    border: '3px solid var(--action)', borderRadius: `${r}px`, pointerEvents: 'none' });
  return (t, from, to) => {
    c.show(e, t >= from && t < to + 0.25);
    const pulse = 1 + 0.07 * Math.sin((t - from) * 9);
    e.style.transform = `scale(${c.M.mix(1.6, 1, c.M.sp(t - from, 'snappy')) * (t < to ? pulse : 1 + c.M.ramp(t, to, to + 0.25) * 0.5)})`;
    e.style.opacity = t < to ? c.M.ramp(t, from, from + 0.1) : 1 - c.M.ramp(t, to, to + 0.25);
  };
}

// A click burst: n rays flying out of (x, y).
function burst(parent, c, { x, y, n = 10, r0 = 10, r1 = 46, color = 'var(--action)', len = 12, thick = 4 }) {
  const rays = [...Array(n)].map((_, i) => {
    const a = (i / n) * Math.PI * 2 + 0.3;
    return [a, add(parent, '<div></div>', { position: 'absolute', left: `${x}px`, top: `${y}px`, width: `${len}px`, height: `${thick}px`, marginTop: `${-thick / 2}px`,
      background: color, borderRadius: `${thick}px`, transformOrigin: '0 50%', pointerEvents: 'none' })];
  });
  return (t, at) => {
    const on = t >= at && t < at + 0.6, k = c.M.sp(t - at, 'snappy'), fade = 1 - c.M.ramp(t, at + 0.15, at + 0.55);
    for (const [a, e] of rays) {
      c.show(e, on);
      const d = c.M.mix(r0, r1, k);
      e.style.transform = `rotate(${a}rad) translateX(${d}px) scaleX(${0.4 + 0.6 * fade})`;
      e.style.opacity = fade;
    }
  };
}

// A number that changes: rolls up (fx) or swaps. `cover` hides the screenshot's own digits.
function counter(parent, c, { x, y, w, h, from, to, color, size, weight = 400, bg = '#000', roll }) {
  const e = add(parent, `<div><div class="sx-roll"><div>${from}</div><div>${to}</div></div></div>`, { position: 'absolute', left: `${x}px`, top: `${y}px`,
    width: `${w}px`, height: `${h}px`, overflow: 'hidden', background: bg, fontFamily: 'var(--font-body)', fontSize: `${size}px`, fontWeight: weight, lineHeight: `${h}px` });
  const strip = e.firstElementChild, [a, b] = strip.children;
  b.style.color = color;
  return (t, at, show = 0) => {
    c.show(e, t >= show);
    const k = roll ? c.M.sp(t - at, 'snappy') : (t >= at ? 1 : 0);
    strip.style.transform = `translateY(${-k * h}px)`;
    a.style.color = color && t >= at ? color : X.text;
  };
}

export default {
  build(root, c) {
    const { BAR, AT, cfg } = c;
    const FX = !!cfg.fx;
    this.FX = FX;
    const T = this.T = {
      steps: [BAR(2), BAR(4), AT(7, 2)], end: BAR(11),
      words: BAR(0), wordStep: 0.2, stamp: AT(1, 2), chips: [AT(1, 0), AT(1, 0.5)], seats: [AT(1, 0), AT(1, 2.5)],
      prof: AT(2, 1), cur1: AT(2, 2), ring1: AT(2, 3), zin1: AT(2, 2.5), follow: AT(3, 1), zout1: AT(3, 2), roll1: AT(3, 2.6),
      postA: AT(4, 1), zinA: AT(4, 2.5), ringA: AT(4, 3), repA: AT(5, 0.5), likeA: AT(5, 2), zoutA: AT(5, 3), outA: AT(5, 3.6),
      postB: BAR(6), zinB: AT(6, 1), repB: AT(6, 2), likeB: AT(6, 3.5), zoutB: AT(7, 1),
      post3: AT(7, 3), comp: BAR(8), type0: AT(8, 1), type1: AT(9, 2), reply: AT(9, 3), here: AT(10, 0), not: AT(10, 2),
    };
    this.layer = c.el('div', 'layer');
    root.appendChild(this.layer);
    const L = this.layer;
    this.chrome = chrome(L, root, c, { steps: ['Follow', 'Like + repost', 'Reply'], at: T.steps, end: T.end });

    // ── Hook: the question, the prize, the verdict stamp.
    const Q = [['Why', 'should', 'YOU', 'be', 'chosen'], ['for', 'the', '$PLEA', 'airdrop?']];
    this.q = add(L, `<div class="sx-big" style="position:absolute;left:0;right:0;top:132px;text-align:center;font-size:56px;line-height:1.12">${Q.map((l) =>
      `<span class="mask" style="display:block">${l.map((w) => `<span${w === 'YOU' ? ' class="sx-you"' : ''} style="margin:0 0.13em">${esc(w)}</span>`).join('')}</span>`).join('')}</div>`);
    this.qWords = [...this.q.querySelectorAll('.mask > span')];
    this.you = this.q.querySelector('.sx-you');
    Object.assign(this.you.style, { position: 'relative', padding: '0 0.12em' });
    this.youBg = add(this.you, '<span></span>', { position: 'absolute', inset: '0.06em -0.02em 0.02em', background: 'var(--action)', zIndex: '-1', borderRadius: '6px', transformOrigin: '0 50%' });
    this.you.style.color = 'var(--on-action)';
    this.chipA = piece(L, c, `<span class="sx-chip sx-chip--y"><b class="sx-n75">75</b> winners</span>`, { left: 0, top: 296, at: T.chips[0], out: T.steps[0], dy: 24, kind: 'snappy' });
    this.chipB = piece(L, c, `<span class="sx-chip"><b class="sx-n160">160,000</b> $PLEA each</span>`, { left: 0, top: 296, at: T.chips[1], out: T.steps[0], dy: 24, kind: 'snappy' });
    Object.assign(this.chipA.e.style, { left: 'auto', right: `${1280 - 625}px` });   // the pair centred on the stage
    Object.assign(this.chipB.e.style, { left: '655px' });
    this.n75 = this.chipA.e.querySelector('.sx-n75');
    this.n160 = this.chipB.e.querySelector('.sx-n160');
    this.swarm = piece(L, c, '<span class="mono" style="font-size:19px;color:var(--ink-2)">every plea judged by IMD’s swarm</span>', { left: 0, top: 372, at: T.chips[1] + 0.3, out: T.steps[0], dy: 14 });
    Object.assign(this.swarm.e.style, { right: '0', textAlign: 'center' });
    this.stamp = verdict(L, c, { state: 'approved', word: 'CHOSEN', sub: 'by the swarm', x: 640, y: FX ? 560 : 520, zoom: 1.15, tilt: -4 });
    if (FX) {   // the 75 seats fill up
      this.seats = [...Array(75)].map((_, i) => add(L, '<div></div>', { position: 'absolute', left: `${640 - 25 * 11 + (i % 25) * 22}px`, top: `${426 + Math.floor(i / 25) * 22}px`,
        width: '16px', height: '16px', boxSizing: 'border-box', borderRadius: '4px', border: '2px solid var(--ink-3)' }));
    }

    // ── Step 1: follow @Pleaimd on the real profile.
    this.h1 = headline(L, c, { n: 1, lines: [['Follow'], ['@Pleaimd.']], small: 'tap Follow on the PLEA profile', at: T.steps[0], out: T.steps[1] });
    const P = this.prof = shot(L, c, { src: 'profile.png', natW: 1210, sx: 14, sy: 96, sw: 1196, sh: 1014, s: 0.5, left: 640, top: 138, at: T.prof, out: T.steps[1] });
    const [fx0, fy0] = P.fx(1017, 519), fw = (1178 - 1017) * 0.5, fh = (590 - 519) * 0.5;
    this.fcx = fx0 + fw / 2; this.fcy = fy0 + fh / 2;
    this.following = add(P.z, `<div>Following</div>`, { position: 'absolute', left: `${fx0}px`, top: `${fy0}px`, width: `${fw}px`, height: `${fh}px`, boxSizing: 'border-box',
      borderRadius: '999px', background: '#000', border: `1px solid ${X.edge}`, color: X.pill, fontFamily: 'var(--font-body)', fontWeight: 700, fontSize: '14px', display: 'grid', placeContent: 'center' });
    this.ring1 = ring(P.z, c, { x: fx0 - 7, y: fy0 - 7, w: fw + 14, h: fh + 14 });
    this.burst1 = burst(P.z, c, { x: this.fcx, y: this.fcy, n: 12, r0: 46, r1: 82 });
    const [cx0, cy0] = P.fx(232, 996);
    this.followers = counter(P.z, c, { x: cx0, y: cy0, w: 26, h: 15, from: '120', to: '121', size: 13.5, weight: 700, color: X.text, roll: FX });
    const fScr = [P.origin[0] + this.fcx, P.origin[1] + this.fcy];
    this.cur1 = cursor(L, c, { keys: [[T.cur1 - 0.4, 1010, 640], [T.cur1, fScr[0] - 4, fScr[1] - 3]], presses: [T.follow], from: T.cur1 - 0.4, to: T.steps[1] });

    // ── Step 2: like + repost both posts. The contest post first (its action bar drawn from the real icons).
    this.h2 = headline(L, c, { n: 2, lines: [['Like', '+'], ['repost', 'both.']], small: 'the contest post and the pinned video', at: T.steps[1], out: T.steps[2] });
    const A = this.postA = shot(L, c, { src: 'post.png', natW: 1072, sx: 0, sy: 0, sw: 1072, sh: 1070, s: 0.45, extra: 46, bg: X.dim, left: 699, top: 132, at: T.postA, out: T.outA, kind: 'heavy' });
    add(A.z, '<div></div>', { position: 'absolute', left: '0', right: '0', top: `${1070 * 0.45}px`, height: '46px', borderTop: `1px solid ${X.line}`, background: X.dim });
    const barY = 1070 * 0.45 + 23, cxA = { reply: 32, repost: 128, like: 224, views: 320, bookmark: 414, share: 455 };
    const iw = (n, s) => (ICON[n][1] - ICON[n][0]) * s;
    for (const n of Object.keys(cxA)) icon(A.z, n, 'gray', cxA[n] - iw(n, 0.45) / 2, barY - ICON_H * 0.45 / 2, 0.45);
    this.repA = icon(A.z, 'repost', 'green', cxA.repost - iw('repost', 0.45) / 2, barY - ICON_H * 0.45 / 2, 0.45);
    this.likeA = icon(A.z, 'like', 'pink', cxA.like - iw('like', 0.45) / 2, barY - ICON_H * 0.45 / 2, 0.45);
    this.repAn = add(A.z, '<div>1</div>', { position: 'absolute', left: `${cxA.repost + iw('repost', 0.45) / 2 + 4}px`, top: `${barY - 8}px`, color: X.green, fontFamily: 'var(--font-body)', fontSize: '12.5px', lineHeight: '16px' });
    this.likeAn = add(A.z, '<div>1</div>', { position: 'absolute', left: `${cxA.like + iw('like', 0.45) / 2 + 4}px`, top: `${barY - 8}px`, color: X.pink, fontFamily: 'var(--font-body)', fontSize: '12.5px', lineHeight: '16px' });
    this.ringA1 = ring(A.z, c, { x: cxA.repost - 19, y: barY - 19, w: 38, h: 38 });
    this.ringA2 = ring(A.z, c, { x: cxA.like - 19, y: barY - 19, w: 38, h: 38 });
    this.burstA1 = burst(A.z, c, { x: cxA.repost, y: barY, color: X.green, n: 8, r0: 14, r1: 30, len: 8, thick: 3 });
    this.burstA2 = burst(A.z, c, { x: cxA.like, y: barY, color: X.pink, n: 10, r0: 14, r1: 32, len: 8, thick: 3 });
    this.zA = [241, barY];
    this.labelA = piece(L, c, '<span class="sx-chip sx-chip--y sx-chip--md">1 of 2 · the contest post</span>', { left: 56, top: 470, at: T.postA + 0.1, out: T.outA, dx: -30, dy: 0, kind: 'snappy' });

    // …then the pinned video post (its real action bar: repost and like recoloured with the same icons, the count 12 → 13).
    const B = this.postB = shot(L, c, { src: 'pinned.png', natW: 1174, sx: 0, sy: 100, sw: 1174, sh: 836, s: 0.5, left: 632, top: 154, at: T.postB, out: T.steps[2], kind: 'heavy' });
    const [rbx, rby] = B.fx(ICON.repost[0], ICON_Y0), [lbx] = B.fx(ICON.like[0], ICON_Y0);
    this.repB = icon(B.z, 'repost', 'green', rbx, rby, 0.5);
    this.likeB = icon(B.z, 'like', 'pink', lbx, rby, 0.5);
    this.repBc = [rbx + iw('repost', 0.5) / 2, rby + 12.5]; this.likeBc = [lbx + iw('like', 0.5) / 2, rby + 12.5];
    this.repBn = add(B.z, '<div>1</div>', { position: 'absolute', left: `${rbx + iw('repost', 0.5) + 4}px`, top: `${rby + 4}px`, color: X.green, fontFamily: 'var(--font-body)', fontSize: '13px', lineHeight: '17px' });
    const [lnx, lny] = B.fx(622, 874);
    this.likesB = counter(B.z, c, { x: lnx, y: lny, w: 30, h: 17, from: '12', to: '13', size: 13, color: X.pink, roll: FX });
    this.ringB1 = ring(B.z, c, { x: this.repBc[0] - 20, y: this.repBc[1] - 20, w: 40, h: 40 });
    this.ringB2 = ring(B.z, c, { x: this.likeBc[0] - 20, y: this.likeBc[1] - 20, w: 40, h: 40 });
    this.burstB1 = burst(B.z, c, { x: this.repBc[0], y: this.repBc[1], color: X.green, n: 8, r0: 15, r1: 32, len: 8, thick: 3 });
    this.burstB2 = burst(B.z, c, { x: this.likeBc[0], y: this.likeBc[1], color: X.pink, n: 10, r0: 15, r1: 34, len: 8, thick: 3 });
    this.zB = [293, this.repBc[1]];
    this.labelB = piece(L, c, '<span class="sx-chip sx-chip--y sx-chip--md">2 of 2 · the pinned video</span>', { left: 56, top: 470, at: T.postB + 0.1, out: T.steps[2], dx: -30, dy: 0, kind: 'snappy' });

    const Z = FX ? 1.12 : 1;   // the fx cut leans each post towards the viewer around its action bar
    const zmap = (o, p, base) => base + o + (p - o) * Z;
    const scrA = (x) => [zmap(this.zA[0], x, A.origin[0]) - 4, zmap(this.zA[1], barY, A.origin[1]) - 3];
    const scrB = ([x, y]) => [zmap(this.zB[0], x, B.origin[0]) - 4, zmap(this.zB[1], y, B.origin[1]) - 3];
    const kA1 = scrA(cxA.repost), kA2 = scrA(cxA.like), kB1 = scrB(this.repBc), kB2 = scrB(this.likeBc);
    this.cur2 = cursor(L, c, { keys: [[T.zinA, 1060, 700], [T.repA - 0.35, ...kA1], [T.likeA - 0.35, ...kA2], [T.outA, 1100, 690], [T.zinB + 0.1, ...kB1], [T.likeB - 0.4, ...kB2]],
      presses: [T.repA, T.likeA, T.repB, T.likeB], from: T.zinA, to: T.steps[2] });

    // ── Step 3: reply on the contest post (an example reply, typed).
    this.h3 = headline(L, c, { n: 3, lines: [['Reply', 'on', 'the'], ['contest', 'post.']], small: 'your plea + your ETH wallet + tag a friend', at: T.steps[2], out: T.end + 10 });
    const C = this.post3 = shot(L, c, { src: 'post.png', natW: 1072, sx: 0, sy: 0, sw: 1072, sh: 562, s: 0.45, extra: 172, bg: X.dim, left: 699, top: 118, at: T.post3, out: T.end, kind: 'heavy' });
    const top3 = 562 * 0.45;
    this.comp = add(C.z, `<div class="sx-comp">
        <div class="sx-comp__av">YOU</div>
        <div class="sx-comp__to">Replying to <span style="color:${X.blue}">@Pleaimd</span></div>
        <div class="sx-comp__me"><b>You</b> <span>@you · now</span></div>
        <div class="sx-comp__text"><span class="sx-comp__ph">Post your reply</span><span class="sx-comp__typed"></span></div>
        <div class="sx-comp__btn">Reply</div>
        <div class="sx-comp__ex">example</div></div>`, { position: 'absolute', left: '0', right: '0', top: `${top3}px`, height: '172px' });
    this.ph = this.comp.querySelector('.sx-comp__ph'); this.typed = this.comp.querySelector('.sx-comp__typed');
    this.btn = this.comp.querySelector('.sx-comp__btn'); this.to = this.comp.querySelector('.sx-comp__to'); this.me = this.comp.querySelector('.sx-comp__me');
    this.compIn = T.comp;
    this.burst3 = burst(C.z, c, { x: 482.4 - 14 - 34, y: top3 + 172 - 12 - 16, color: X.blue, n: 12, r0: 30, r1: 60, len: 10 });
    const bScr = [C.origin[0] + 482.4 - 14 - 34 - 4, C.origin[1] + top3 + 172 - 12 - 16 - 3];
    this.cur3 = cursor(L, c, { keys: [[T.type1 - 0.2, 1150, 700], [T.reply - 0.3, ...bScr]], presses: [T.reply], from: T.type1 - 0.2, to: T.end });
    this.label3 = piece(L, c, '<span class="sx-chip sx-chip--y sx-chip--md">on the contest post</span>', { left: 56, top: 470, at: T.post3 + 0.1, out: T.end, dx: -30, dy: 0, kind: 'snappy' });
    this.ok3 = piece(L, c, '<span class="sx-chip sx-chip--ok">✓ Reply here, under the contest post</span>', { left: 699, top: 612, at: T.here, out: T.end, dy: 20, kind: 'snappy' });
    this.no3 = piece(L, c, '<span class="sx-chip sx-chip--no">✗ Not under the pinned video</span>', { left: 699, top: 662, at: T.not, out: T.end, dy: 20, kind: 'snappy' });
    if (FX) this.hereStamp = verdict(L, c, { state: 'approved', word: 'HERE', x: 1165, y: 650, zoom: 0.85, tilt: 6 });

    this.recap = recap(L, root, c, {
      at: T.end, sub: '75 winners × 160,000 $PLEA. IMD’s swarm judges.',
      rows: ['Follow @Pleaimd.', 'Like + repost the contest post and the pinned video.', 'Reply on the contest post: your plea + ETH wallet + a tag.'],
      fine: 'Your own wallet · 20+ Ethereum transactions before the post · one wallet per X account (3+ months) · we never DM · Music: “Spy Glass” Kevin MacLeod (incompetech.com), CC BY 4.0',
    });
    if (FX) {   // confetti on the closing hit, falling in front of the card
      const R = c.M.rng(2026), COL = ['var(--action)', 'var(--approved)', 'var(--denied)', X.pink, X.blue, '#F5F0E4'];
      this.confetti = [...Array(80)].map((_, i) => ({ e: add(root, '<div></div>', { position: 'absolute', left: '0', top: '0', width: `${6 + R() * 8}px`, height: `${10 + R() * 10}px`,
        background: COL[i % COL.length], borderRadius: '2px', zIndex: '60' }), x: 60 + R() * 1160, y: -40 - R() * 260, vx: (R() - 0.5) * 160, vy: 120 + R() * 260, spin: (R() - 0.5) * 900, wob: R() * 6 }));
    }
  },

  update(t, c) {
    const { M } = c, T = this.T, FX = this.FX;
    this.chrome.update(t);

    // Hook
    const qOn = t < T.steps[0] + 0.6;
    this.q.style.display = qOn ? '' : 'none';
    this.qWords.forEach((w, i) => {
      const up = M.sp(t - (T.words + T.wordStep * i), 'type'), away = M.sp(t - (T.steps[0] + 0.03 * i), 'type');
      w.style.transform = `translateY(${(1 - up) * 115 - away * 115}%)`;
      w.style.display = 'inline-block';
    });
    const tYou = T.words + T.wordStep * 2;
    this.youBg.style.transform = `scaleX(${M.sp(t - tYou - 0.1, 'snappy')})`;
    if (FX) this.you.style.scale = `${1 + 0.18 * Math.max(0, Math.sin(Math.PI * M.ramp(t, tYou + 0.1, tYou + 0.45)))}`;
    this.chipA.update(t); this.chipB.update(t); this.swarm.update(t);
    if (FX) {
      this.n75.textContent = String(Math.round(75 * M.ramp(t, T.seats[0], T.seats[1])));
      this.n160.textContent = Math.round(160000 * M.sp(t - T.chips[1], 'heavy')).toLocaleString('en-US');
      this.seats.forEach((d, i) => {
        const at = M.mix(T.seats[0], T.seats[1], i / 74), on = t >= at;
        c.show(d, t >= T.seats[0] - 0.2 && t < T.steps[0] + 0.4);
        d.style.background = on ? 'var(--action)' : 'transparent';
        d.style.borderColor = on ? 'var(--ink)' : 'var(--ink-3)';
        d.style.transform = `scale(${on ? M.mix(1.6, 1, M.sp(t - at, 'snappy')) : 1}) translateY(${-M.sp(t - T.steps[0] - 0.01 * i, 'ui') * 30}px)`;
        d.style.opacity = 1 - M.ramp(t, T.steps[0], T.steps[0] + 0.3);
      });
    }
    this.stamp.update(t, T.stamp, T.steps[0]);
    this.layer.style.translate = FX ? `${M.jolt(t - T.stamp - 0.05, 9)}px ${M.jolt(t - T.stamp - 0.05, 12) + M.jolt(t - (T.here ?? 0) - 0.05, 8)}px` : '';

    // Step 1
    this.h1.update(t);
    if (this.prof.update(t, FX ? `rotate(${(1 - M.sp(t - T.prof, 'heavy')) * 5}deg)` : '')) {
      const z = FX ? 1 + 0.7 * (M.sp(t - T.zin1, 'heavy') - M.sp(t - T.zout1, 'heavy')) : 1;
      this.prof.z.style.transformOrigin = `${this.fcx}px ${this.fcy}px`;
      this.prof.z.style.transform = `scale(${z})`;
      this.ring1(t, T.ring1, T.follow);
      c.show(this.following, t >= T.follow);
      this.following.style.transform = FX ? `scale(${M.mix(0.6, 1, M.sp(t - T.follow, 'snappy'))})` : '';
      if (FX) this.burst1(t, T.follow); else this.burst1(-1, 0);
      this.followers(t, FX ? T.roll1 : T.follow + 0.3);
    }
    this.cur1.update(t);

    // Step 2
    this.h2.update(t);
    this.labelA.update(t); this.labelB.update(t);
    const zA = FX ? 1 + 0.12 * (M.sp(t - T.zinA, 'heavy') - M.sp(t - T.zoutA, 'heavy')) : 1;
    this.postA.e.style.transformOrigin = `${3 + this.zA[0]}px ${3 + this.zA[1]}px`;
    if (this.postA.update(t, FX ? `translateX(${-M.sp(t - T.outA, 'ui') * 260}px) rotate(${(1 - M.sp(t - T.postA, 'heavy')) * 4 - M.sp(t - T.outA, 'ui') * 10}deg) scale(${zA})` : '')) {
      this.ringA1(t, T.ringA, T.repA); this.ringA2(t, T.repA + 0.15, T.likeA);
      this.toggle(this.repA, this.repAn, t, T.repA, 'spin');
      this.toggle(this.likeA, this.likeAn, t, T.likeA, 'pop');
      if (FX) { this.burstA1(t, T.repA); this.burstA2(t, T.likeA); } else { this.burstA1(-1, 0); this.burstA2(-1, 0); }
    }
    const zB = FX ? 1 + 0.12 * (M.sp(t - T.zinB, 'heavy') - M.sp(t - T.zoutB, 'heavy')) : 1;
    this.postB.e.style.transformOrigin = `${3 + this.zB[0]}px ${3 + this.zB[1]}px`;
    if (this.postB.update(t, FX ? `rotate(${(1 - M.sp(t - T.postB, 'heavy')) * 5}deg) scale(${zB})` : '')) {
      this.ringB1(t, T.zinB + 0.1, T.repB); this.ringB2(t, T.repB + 0.15, T.likeB);
      this.toggle(this.repB, this.repBn, t, T.repB, 'spin');
      this.toggle(this.likeB, null, t, T.likeB, 'pop');
      this.likesB(t, T.likeB);
      if (FX) { this.burstB1(t, T.repB); this.burstB2(t, T.likeB); } else { this.burstB1(-1, 0); this.burstB2(-1, 0); }
    }
    this.cur2.update(t);

    // Step 3
    this.h3.update(t);
    this.label3.update(t);
    if (this.post3.update(t, FX ? `rotate(${(1 - M.sp(t - T.post3, 'heavy')) * 4}deg)` : '')) {
      const k = M.sp(t - T.comp, 'ui');
      this.comp.style.opacity = M.ramp(t, T.comp, T.comp + 0.15);
      this.comp.style.transform = `translateY(${(1 - k) * 30}px)`;
      const n = Math.round(FULL.length * M.ramp(t, T.type0, T.type1));
      this.ph.style.display = n === 0 ? '' : 'none';
      const caret = t >= T.type0 && t < T.reply && Math.floor(t / 0.25) % 2 === 0 ? '<span style="border-left:2px solid #1D9BF0;margin-left:1px"></span>' : '';
      const typed = FULL.slice(0, n), tagAt = FULL.length - TAG.length;
      this.typed.innerHTML = esc(typed.slice(0, Math.min(n, tagAt))).replace('\n', '<br>') + (n > tagAt ? `<span style="color:${X.blue}">${esc(typed.slice(tagAt))}</span>` : '') + caret;
      const posted = t >= T.reply + 0.15;
      c.show(this.btn, !posted); c.show(this.to, !posted); c.show(this.me, posted);
      this.btn.style.opacity = n > 0 ? 1 : 0.5;
      press(this.btn, t, T.reply);
      this.comp.style.boxShadow = posted ? `inset 0 0 0 ${3 * (1 - M.ramp(t, T.reply + 0.15, T.reply + 1.2))}px var(--action)` : '';
      if (FX) this.burst3(t, T.reply); else this.burst3(-1, 0);
      this.post3.z.style.transformOrigin = '50% 80%';
      this.post3.z.style.transform = FX ? `scale(${1 + 0.05 * M.sp(t - T.type0, 'heavy') - 0.05 * M.sp(t - T.reply, 'heavy')})` : '';
    }
    this.cur3.update(t);
    this.ok3.update(t);
    this.no3.update(t, FX ? `translateX(${8 * Math.exp(-(t - T.not) * 8) * Math.sin((t - T.not) * 50) * (t >= T.not ? 1 : 0)}px)` : '');
    if (FX) this.hereStamp.update(t, T.here, T.end);

    this.recap.update(t);
    if (FX) for (const p of this.confetti) {
      const dt = t - c.HIT;
      c.show(p.e, dt >= 0);
      if (dt < 0) continue;
      p.e.style.transform = `translate(${p.x + p.vx * dt + Math.sin(dt * 4 + p.wob) * 14}px, ${p.y + p.vy * dt + 340 * dt * dt}px) rotate(${p.spin * dt}deg)`;
    }
  },

  // An action turning on at `at`: the coloured icon over the grey one (a spin or a pop in the fx cut), its count.
  toggle(iconEl, countEl, t, at, how) {
    const on = t >= at;
    iconEl.style.visibility = on ? 'visible' : 'hidden';
    if (countEl) countEl.style.visibility = on ? 'visible' : 'hidden';
    if (!this.FX || !on) { iconEl.style.transform = ''; return; }
    const k = Math.min(1, (t - at) / 0.45);
    iconEl.style.transform = how === 'spin' ? `rotate(${(1 - (1 - k) ** 3) * 360}deg)` : `scale(${1 + 0.45 * Math.sin(Math.PI * Math.min(1, (t - at) / 0.3))})`;
  },

  cues(c) {
    const T = this.T, FX = this.FX;
    const q = [[T.stamp, 'thump', FX ? 0.36 : 0.26, 1.2], [T.chips[0], 'pop', 1.2], [T.chips[1], 'pop', 1.2, 600, 1300],
      [T.steps[0], 'whoosh', 1.5, 0.35, 400, 2600], [T.prof, 'whoosh', 0.8, 0.3, 400, 2400], [T.follow, 'tap', 1.2, 1500, 0.03], [T.follow + 0.05, 'pop', 0.9, 700, 1400],
      [T.steps[1], 'whoosh', 1.4, 0.35, 400, 2600], [T.postA, 'whoosh', 0.8, 0.3, 400, 2400], [T.repA, 'tick', 2.0, 1900, 0.012], [T.likeA, 'pop', 1.2, 800, 1600],
      [T.postB, 'whoosh', 0.9, 0.3, 400, 2400], [T.repB, 'tick', 2.0, 1900, 0.012], [T.likeB, 'pop', 1.2, 800, 1600],
      [T.steps[2], 'whoosh', 1.4, 0.35, 400, 2600], [T.post3, 'whoosh', 0.8, 0.3, 400, 2400], [T.comp, 'tap', 0.9, 1100, 0.03],
      [T.reply, 'tick', 1.8, 2200, 0.01], [T.reply + 0.15, 'bell', 0.5, 1318, 0.4], [T.here, 'pop', 1.2], [T.not, 'tap', 1.0, 600, 0.05]];
    if (FX) {
      q.push([T.zin1, 'whoosh', 0.6, 0.4, 300, 1600], [T.zinA, 'whoosh', 0.6, 0.4, 300, 1600], [T.zinB, 'whoosh', 0.6, 0.4, 300, 1600],
        [T.roll1, 'tick', 1.6, 2400, 0.01], [T.likeB + 0.05, 'tick', 1.4, 2600, 0.01], [T.here, 'thump', 0.3, 1.0], [T.outA, 'whoosh', 0.9, 0.3, 500, 2800]);
      for (let i = 0; i < 12; i++) q.push([c.M.mix(T.seats[0], T.seats[1], i / 11), 'tick', 0.9, 1500 + 90 * i, 0.008]);
    }
    for (let t = T.type0; t < T.type1; t += c.beatLen() / 4) q.push([t, 'key', 4.0]);
    return [...q, ...this.recap.cues()].map(([t, ...r]) => [Math.round(t * 1000) / 1000, ...r]);
  },
};
