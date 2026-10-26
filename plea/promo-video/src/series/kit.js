// The explainer series ("How PLEA works · §N"): the parts every clip shares, on the site's dark theme.
// A clip's scene (src/series/<name>.js) puts its mechanic on the right and calls these for the rest:
// the series tag and § watermark, the step tracker, the numbered step headlines on the left, a cursor,
// and the recap card that takes over at the end, its PLEA stamp landing on the music's closing hit.
import { esc } from '../lib/ui.js';

const CURSOR = `<svg viewBox="0 0 24 24"><path d="M3 2 L3 20 L8 15 L11.5 22 L14.5 20.6 L11 13.8 L18 13.8 Z" fill="var(--ink)" stroke="var(--paper)" stroke-width="1.6" stroke-linejoin="round"/></svg>`;

// Words that rise out of a mask one by one: lines = [['Write', 'your'], ['case.']].
const words = (lines) => lines.map((l) => `<span class="mask">${l.map((w) => `<span>${esc(w)}</span>`).join('')}</span>`).join('');

// The frame: § watermark, the series tag (from bar 0) and the step tracker (from the first step).
// steps = ['Write', 'Judged', 'Sell'], at = the time each step starts, end = when the recap card takes over.
export function chrome(layer, root, c, { steps, at, end }) {
  const { cfg } = c;
  const mark = c.el('div', 'sx-mark', `§${cfg.n}`);
  root.prepend(mark);
  const tag = c.el('div', 'sx-tag', `<span class="sx-tag__pill">How PLEA works</span><span class="sx-tag__title">§${cfg.n} ${esc(cfg.title)}</span>`);
  const track = c.el('div', 'sx-steps', steps.map((s, i) =>
    `${i ? '<span class="sx-step__line"><span></span></span>' : ''}<span class="sx-step"><span class="sx-step__dot">${i + 1}</span>${esc(s)}</span>`).join(''));
  layer.append(tag, track);
  const nodes = [...track.querySelectorAll('.sx-step')], lines = [...track.querySelectorAll('.sx-step__line > span')];
  return {
    update(t) {
      const { M } = c;
      mark.style.transform = `translateX(${-6 * t}px)`;
      mark.style.opacity = M.sp(t - c.BAR(0), 'heavy');
      c.show(tag, t >= c.BAR(0));
      tag.style.transform = `translateY(${(1 - M.sp(t - c.BAR(0), 'snappy')) * -70}px)`;
      c.show(track, t >= at[0] - 0.1);
      track.style.transform = `translateY(${(1 - M.sp(t - at[0] + 0.1, 'snappy')) * -70}px)`;
      const cur = at.filter((a) => t >= a).length - 1;
      nodes.forEach((n, i) => { n.classList.toggle('is-on', i === cur && t < end); n.classList.toggle('is-done', i < cur || t >= end); });
      lines.forEach((l, i) => { l.style.transform = `scaleX(${M.sp(t - at[i + 1], 'ui')})`; });
    },
  };
}

// A numbered step headline: the number lands, the words rise on half beats, then the small line;
// at `out` it all rises away for the next step.
export function headline(layer, c, { n, lines, small, at, out = Infinity }) {
  const e = c.el('div', 'sx-head', `<div class="sx-head__n">${n}</div><div class="sx-head__lines">${words(lines)}</div><div class="sx-head__small">${esc(small)}</div>`);
  layer.appendChild(e);
  const num = e.querySelector('.sx-head__n'), ws = [...e.querySelectorAll('.mask > span')], sm = e.querySelector('.sx-head__small');
  const half = c.beatLen() / 2;
  return {
    words: ws.length,
    update(t) {
      const { M } = c;
      const on = t >= at && t < out + 0.5;
      e.style.display = on ? '' : 'none';   // display, not visibility: the small line sets its own visibility
      if (!on) return;
      const nk = M.sp(t - at, 'stamp'), nx = M.sp(t - out, 'ui');
      num.style.transform = `scale(${M.mix(0.2, 1, nk) * (1 - nx)}) rotate(${(1 - nk) * -120}deg)`;
      ws.forEach((w, k) => {
        const up = M.sp(t - (at + half * (k + 1)), 'type'), away = M.sp(t - (out + 0.03 * k), 'type');
        w.style.transform = `translateY(${(1 - up) * 115 - away * 115}%)`;
      });
      const tSmall = at + half * (ws.length + 1);
      c.show(sm, t >= tSmall);
      sm.style.transform = `translateX(${(1 - M.sp(t - tSmall, 'ui')) * -50}px)`;
      sm.style.opacity = 1 - nx;
    },
  };
}

// The cursor: glides between keyframes [[t, x, y], …] (a heavy spring per move), presses at given times.
export function cursor(layer, c, { keys, presses = [], from, to = Infinity }) {
  const e = c.el('div', 'cursor', CURSOR);
  layer.appendChild(e);
  return {
    update(t) {
      const { M } = c;
      c.show(e, t >= from && t < to);
      e.style.left = `${M.track(t, keys.map(([k, x]) => [k, x]), 'heavy')}px`;
      e.style.top = `${M.track(t, keys.map(([k, , y]) => [k, y]), 'heavy')}px`;
      e.style.transform = presses.some((p) => t >= p && t < p + 0.12) ? 'scale(0.86)' : '';
    },
  };
}

// A pressed button: in for 0.12 s, the site's :active look.
export const press = (btn, t, at) => {
  const down = t >= at && t < at + 0.12;
  btn.style.transform = down ? 'translate(4px, 4px)' : '';
  btn.style.boxShadow = down ? 'none' : '';
};

// The recap card: the clip's rule on one index card (title, sub, three rows), next clip, the PLEA stamp on the hit.
// The scene layer recedes behind it. Returns its cues too.
export function recap(layer, root, c, { at, sub, rows, fine }) {
  const { cfg } = c;
  const card = c.el('div', 'sx-card theme-light', `
    <div class="sx-card__top"><span>HOW PLEA WORKS · ${cfg.n} OF 7</span></div>
    <div class="sx-card__title">${esc(cfg.title)}.</div>
    <div class="sx-card__sub">${esc(sub)}</div>
    <div class="sx-card__rows">${rows.map((r, i) => `<div class="sx-card__row"><b>${i + 1}</b><span>${esc(r)}</span></div>`).join('')}</div>
    <div class="sx-card__foot"><span>Coming to Ethereum · @Pleaimd</span>${cfg.next ? `<span class="sx-card__next">Next: §${cfg.n + 1} ${esc(cfg.next)} →</span>` : ''}</div>`);
  Object.assign(card.style, { left: '230px', top: '108px', width: '820px' });
  const stampEl = c.el('div', 'abs', '<div style="zoom:0.5"><span class="bigstamp">PLEA</span></div>');
  Object.assign(stampEl.style, { left: '858px', top: '64px' });
  const fineEl = c.el('div', 'sx-fine', esc(fine));
  root.append(card, stampEl, fineEl);
  const rowEls = [...card.querySelectorAll('.sx-card__row')], foot = card.querySelector('.sx-card__foot');
  const tRow = (i) => at + c.beatLen() * (0.5 + 0.5 * i);
  return {
    update(t) {
      const { M } = c;
      const k = M.sp(t - at, 'heavy');
      layer.style.transform = `scale(${M.mix(1, 0.92, k)})`;
      layer.style.opacity = M.mix(1, 0.18, k);
      c.show(card, t >= at);
      const j = M.jolt(t - c.HIT - 0.06, 7);
      card.style.transform = `translateY(${(1 - k) * 760 + j}px) rotate(${(1 - k) * 4}deg)`;
      rowEls.forEach((r, i) => {
        const rk = M.sp(t - tRow(i), 'snappy');
        c.show(r, t >= tRow(i));
        r.style.transform = `translateX(${(1 - rk) * -40}px)`;
      });
      c.show(foot, t >= c.HIT + 0.35);
      foot.style.transform = `translateY(${(1 - M.sp(t - c.HIT - 0.35, 'snappy')) * 16}px)`;
      const s = M.stampLand(t - c.HIT, { from: 2.4, tiltFrom: -16, tilt: 3 });
      c.show(stampEl, s.visible);
      stampEl.style.transform = `translateY(${j}px) rotate(${s.rot}deg) scale(${s.scale})`;
      c.show(fineEl, t >= c.HIT + 0.6);
      fineEl.style.opacity = M.sp(t - c.HIT - 0.6, 'ui');
    },
    cues: () => [[at, 'whoosh', 2.0, 0.45, 300, 1800], ...rowEls.map((_, i) => [tRow(i), 'pop', 1.4]),
      [c.HIT, 'thump', 1.2, 1.6], [c.HIT + 0.35, 'tap', 1.2, 900, 0.04]],
  };
}
