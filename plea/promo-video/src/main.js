// The film: every shot builds its DOM once, then paints itself for any time t (window.seek).
// ?film=promo (default): the 78-s promo. ?film=clip1…clip7: an explainer clip from data/clips.json,
// a sequence of promo bar ranges (replayed at the same tempo, so they stay on the beat) and clip shots.
import * as M from './lib/motion.js';
import { makeGrid } from './lib/grid.js';

const params = new URLSearchParams(location.search);
const fmt = params.get('fmt') === '9x16' ? '9x16' : '16x9';
const film = params.get('film') || 'promo';
const stage = document.getElementById('stage');
stage.classList.add('fmt-' + fmt);

const SHOTS = ['s01-opening', 's02-writing', 's03-sent', 's04-judges', 's05-bar', 's06-denied',
  's07-approved', 's08-objection', 's09-letters', 's10-seasons', 's11-deadman', 's12-end'];

// Helpers handed to every shot.
const el = (tag, cls = '', html = '') => { const e = document.createElement(tag); if (cls) e.className = cls; if (html) e.innerHTML = html; return e; };
const place = (e, { x = 0, y = 0, s = 1, r = 0, o = 1, sx, sy } = {}) => {
  e.style.transform = `translate(${x}px, ${y}px) rotate(${r}deg) scale(${sx ?? s}, ${sy ?? s})`;
  e.style.opacity = o;
};
const show = (e, on) => { e.style.visibility = on ? 'visible' : 'hidden'; };
const capture = (path) => `/captures/${path}`;
const V = fmt === '9x16';
const pick = (h, v) => (V ? v : h);   // a layout value per format: 16:9, then 9:16
const base = { M, fmt, V, pick, W: V ? 720 : 1280, H: V ? 1280 : 720, el, place, show, capture };
const json = async (url) => (await fetch(url)).json();

let ctx;                       // the promo's context (its grid)
let clip = null;               // { cfg, ctx } for an explainer clip
const shots = [];
const span = (s) => [typeof s.from === 'function' ? s.from(ctx) : s.from, typeof s.to === 'function' ? s.to(ctx) : s.to];

async function init() {
  ctx = { ...base, ...makeGrid(await json('../data/beats-16x9.json')) };
  for (const name of SHOTS) {
    let mod;
    try { mod = (await import(`./shots/${name}.js`)).default; } catch (e) { console.warn('shot missing', name, e.message); continue; }
    const root = el('section', 'shot');
    root.dataset.shot = name;
    stage.appendChild(root);
    mod.build(root, ctx);
    shots.push({ ...mod, root });
  }
  if (film !== 'promo') {
    const cfg = (await json('../data/clips.json'))[film];
    const cctx = { ...base, ...makeGrid(await json(`../data/beats-clip-${cfg.music}.json`)), clip: cfg };
    for (const seg of cfg.segments) {
      if (!seg.shot) continue;
      seg.impl = Object.create((await import(`./clips/${seg.shot}.js`)).default);
      seg.root = el('section', 'shot');
      seg.root.dataset.shot = seg.shot;
      stage.appendChild(seg.root);
      seg.impl.build(seg.root, cctx, seg.opts || {});
    }
    clip = { cfg, ctx: cctx };
  }
  await document.fonts.ready;
  await Promise.all([...document.images].map((i) => (i.complete ? i.decode().catch(() => {}) : new Promise((r) => { i.onload = i.onerror = () => r(); }))));
}

function seekPromo(t, on = true) {
  for (const s of shots) {
    const [from, to] = span(s);
    const active = on && t >= from && t < to;
    s.root.style.display = active ? '' : 'none';
    if (active) s.update(t - from, t, ctx);
  }
}

function seekClip(t) {
  const { cfg, ctx: c } = clip;
  let promoT = null;
  for (const seg of cfg.segments) {
    const a = c.BAR(seg.from), b = seg.to >= 99 ? Infinity : c.BAR(seg.to);
    const active = t >= a && t < b;
    if (seg.root) { seg.root.style.display = active ? '' : 'none'; if (active) seg.impl.update(t - a, t, c, seg); }
    // Clamped to the borrowed bars: the two edits' bars differ by a few ms, which must not leak the next promo shot.
    if (active && seg.promo !== undefined) promoT = Math.min(ctx.BAR(seg.promo) + (t - a), ctx.BAR(seg.promo + seg.to - seg.from) - 0.001);
  }
  seekPromo(promoT ?? -1, promoT !== null);
}

window.seek = (t) => {
  if (clip) seekClip(t); else seekPromo(t);
  const pending = [...stage.querySelectorAll('img')].filter((i) => i.offsetParent !== null && !i.complete);
  return Promise.all(pending.map((i) => new Promise((r) => { i.onload = i.onerror = () => r(); }))).then(() => true);
};
window.ready = init().then(() => { window.seek(0); return true; });
window.shotTimes = () => shots.map((s) => { const [from, to] = span(s); return { id: s.id, from, to }; });
