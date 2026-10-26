// The film: every shot builds its DOM once, then paints itself for any time t (window.seek).
import * as M from './lib/motion.js';
import { loadGrid, BAR, AT, barLen, beatLen } from './lib/grid.js';

const params = new URLSearchParams(location.search);
const fmt = params.get('fmt') === '9x16' ? '9x16' : '16x9';
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
const ctx = { M, BAR, AT, barLen, beatLen, fmt, V, pick, W: V ? 720 : 1280, H: V ? 1280 : 720, el, place, show, capture };

const shots = [];
async function init() {
  await loadGrid('../data/beats-16x9.json');
  for (const name of SHOTS) {
    let mod;
    try { mod = (await import(`./shots/${name}.js`)).default; } catch (e) { console.warn('shot missing', name, e.message); continue; }
    const root = el('section', 'shot');
    root.dataset.shot = name;
    stage.appendChild(root);
    mod.build(root, ctx);
    shots.push({ ...mod, root });
  }
  await document.fonts.ready;
  await Promise.all([...document.images].map((i) => (i.complete ? i.decode().catch(() => {}) : new Promise((r) => { i.onload = i.onerror = () => r(); }))));
}

window.seek = (t) => {
  for (const s of shots) {
    const from = typeof s.from === 'function' ? s.from(ctx) : s.from;
    const to = typeof s.to === 'function' ? s.to(ctx) : s.to;
    const on = t >= from && t < to;
    s.root.style.display = on ? '' : 'none';
    if (on) s.update(t - from, t, ctx);
  }
  const pending = [...stage.querySelectorAll('img')].filter((i) => i.offsetParent !== null && !i.complete);
  return Promise.all(pending.map((i) => new Promise((r) => { i.onload = i.onerror = () => r(); }))).then(() => true);
};
window.ready = init().then(() => { window.seek(0); return true; });
window.shotTimes = () => shots.map((s) => ({ id: s.id, from: typeof s.from === 'function' ? s.from(ctx) : s.from, to: typeof s.to === 'function' ? s.to(ctx) : s.to }));
