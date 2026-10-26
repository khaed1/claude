// Bonus · Run a keeper: the keeper (khaed1/plea, keeper/) is a small Node.js service doing PLEA's upkeep with
// calls anyone may make: deliver approved letters and auto-sell pleas inside their 7-minute window (the runner
// earns the 0.25 IMD tip), settle letters and objections, expire stale pleas, record points, close seasons (which
// pays the prizes), flush at the end and rebalance the buy wall. It holds no power; if it stops, nothing is lost.
// Setup (keeper/README.md, VPS.md): clone, npm ci, src/new-wallet.mjs (a fresh wallet, ~0.05 ETH for gas),
// a DRY_RUN=1 pass, then run; Telegram alerts optional. The log lines are examples in the keeper's own format.
import { chrome, headline, recap, piece, typeInto, keys } from './kit.js';
import { esc } from '../lib/ui.js';

const LOG = [
  ['keeper started', ',"dryRun":false'],
  ['system found', ''],
  ['done', ',"job":"deliver"', '+0.25 IMD'],
  ['done', ',"job":"record"'],
  ['done', ',"job":"settleLetter"'],
  ['done', ',"job":"closeSeason"'],
  ['done', ',"job":"rebalance"'],
];
const JOBS = [['Sell approved letters for their writers', 'deliver'], ['Return the escrow of denied letters', 'settleLetter'], ['Settle objection stakes', 'settleObjection'],
  ['Record season points', 'record'], ['Close seasons, pay the prizes', 'closeSeason'], ['Rebalance the buy wall', 'rebalance']];
const CMDS = ['git clone https://github.com/khaed1/plea', 'cd plea/keeper && npm ci', 'node src/new-wallet.mjs', 'DRY_RUN=1 node --env-file=.env src/main.mjs', 'node --env-file=.env src/main.mjs'];
const NOTES = ['', '', '# a fresh wallet: send it ~0.05 ETH for gas', '# simulate first, send nothing', ''];

const term = (title, w, h) => `<div style="width:${w}px;height:${h}px;box-sizing:border-box;background:#0E0D0A;border:3px solid var(--ink);border-radius:12px;box-shadow:8px 8px 0 var(--shadow-color);overflow:hidden">
  <div style="display:flex;align-items:center;gap:8px;padding:8px 14px;border-bottom:2px solid var(--line-soft)"><span style="width:12px;height:12px;border-radius:50%;background:var(--denied)"></span>
  <span style="width:12px;height:12px;border-radius:50%;background:var(--pending)"></span><span style="width:12px;height:12px;border-radius:50%;background:var(--approved)"></span>
  <span class="mono" style="font-size:14px;color:var(--ink-3);margin-left:8px">${title}</span></div><div class="sx-term" style="padding:12px 16px;font-family:var(--font-mono);font-size:16px;line-height:1.6"></div></div>`;
const logLine = ([msg, rest, tip]) => `<div style="white-space:nowrap"><span style="color:var(--ink-3)">{"msg":</span><span style="color:var(--approved)">"${esc(msg)}"</span><span style="color:var(--ink-3)">${esc(rest)}}</span>${tip ? ` <span style="background:var(--action);color:var(--on-action);border-radius:6px;padding:1px 8px;margin-left:8px">${tip}</span>` : ''}</div>`;

export default {
  build(root, c) {
    const { BAR, AT } = c;
    const T = this.T = {
      steps: [BAR(2), AT(3, 2), BAR(5)], end: BAR(7),
      ask: BAR(0), term: AT(0, 1), log0: AT(0, 1.5), anyone: BAR(1),
      jobs: AT(2, 1), jobGap: 0.27,
      card: AT(3, 2.5), sent: BAR(4), done: AT(4, 1), coin: AT(4, 1.5), relay: AT(4, 3),
      type0: AT(5, 0.5), cmdGap: (AT(6, 3) - AT(5, 0.5)) / 5, started: AT(6, 3.3),
    };
    this.layer = c.el('div', 'layer');
    root.appendChild(this.layer);
    const L = this.layer;
    this.chrome = chrome(L, root, c, { steps: ['Upkeep', 'Tips', 'Set up'], at: T.steps, end: T.end });

    // Hook: who keeps the court running? A keeper's log ticks; the answer lands on it.
    this.ask = piece(L, c, 'Who keeps the court running?', { cls: 'abs sx-big', left: 0, top: 120, at: T.ask, out: T.steps[0], dy: -30 });
    Object.assign(this.ask.e.style, { right: '0', textAlign: 'center', fontSize: '52px' });
    this.hookTerm = piece(L, c, term('keeper · log (example)', 700, 300), { left: 290, top: 220, at: T.term, out: T.steps[0], dy: 50 });
    this.hookLog = this.hookTerm.e.querySelector('.sx-term');
    this.anyone = piece(L, c, '<div style="zoom:0.5"><span class="bigstamp">ANYONE</span></div>', { cls: 'abs', left: 700, top: 430, at: T.anyone, out: T.steps[0], dy: 0, kind: 'stamp' });

    // Step 1: the jobs, each a call anyone may make.
    this.h1 = headline(L, c, { n: 1, lines: [['It', 'does', 'the'], ['upkeep.']], small: 'every call is open to anyone; the keeper holds no power', at: T.steps[0], out: T.steps[1] });
    this.jobs = JOBS.map(([what, job], i) => piece(L, c, `<div style="display:grid;grid-template-columns:34px 1fr auto;align-items:center;gap:14px;width:584px;padding:9px 0;border-bottom:2px solid var(--line-soft)">
        <span class="sx-big" style="display:grid;place-content:center;width:30px;height:30px;box-sizing:border-box;border-radius:50%;background:var(--approved);color:var(--on-state);border:3px solid var(--ink);font-size:15px">✓</span>
        <span style="font-weight:700;font-size:20px">${esc(what)}</span><span class="mono" style="font-size:14px;color:var(--ink-3)">${job}</span></div>`,
      { left: 640, top: 134 + i * 62, at: T.jobs + i * T.jobGap, out: T.steps[1], dx: 60, dy: 0, kind: 'snappy' }));

    // Step 2: an approved letter's 7-minute window; the keeper delivers it and earns the tip.
    this.h2 = headline(L, c, { n: 2, lines: [['Deliveries'], ['pay', 'tips.']], small: '0.25 IMD per delivered letter; the other jobs only cost gas', at: T.steps[1], out: T.steps[2] });
    this.card = piece(L, c, `<div class="card" style="width:584px;box-sizing:border-box;padding:14px 20px;box-shadow:8px 8px 0 var(--shadow-color);display:flex;align-items:center;gap:14px">
      <span class="stamp stamp--approved stamp--sm" style="transform:none">Approved</span><span style="font-weight:700;font-size:19px">a letter plea</span>
      <span class="countdown countdown--urgent" style="margin-left:auto"><svg class="icon"><use href="#i-timer"/></svg>Sell within <span class="countdown__time">07:00</span></span></div>`,
      { left: 640, top: 140, at: T.card, out: T.steps[2], dx: 60, dy: 0 });
    this.cardTime = this.card.e.querySelector('.countdown__time');
    this.dTerm = piece(L, c, term('keeper · log (example)', 584, 150), { left: 640, top: 250, at: T.sent - 0.2, out: T.steps[2], dy: 30 });
    this.dLog = this.dTerm.e.querySelector('.sx-term');
    this.split = piece(L, c, `<div style="display:flex;gap:10px;flex-wrap:wrap"><span class="mono" style="font-size:16px;border:3px solid var(--ink);border-radius:999px;padding:5px 12px">the sale → the writer</span>
      <span class="mono" style="font-size:16px;border:3px solid var(--ink);border-radius:999px;padding:5px 12px;background:var(--action);color:var(--on-action)">the tip → the keeper</span></div>`,
      { left: 640, top: 432, at: T.coin, out: T.steps[2], dy: 20, kind: 'snappy' });
    this.wallet = piece(L, c, '<div class="label" style="font-size:14px">keeper wallet</div><div class="sx-big sx-bal" style="font-size:30px">0.00 IMD</div>', { cls: 'abs', left: 1000, top: 482, at: T.coin - 0.3, out: T.steps[2], dx: 40, dy: 0 });
    Object.assign(this.wallet.e.style, { border: '3px dashed var(--ink)', borderRadius: '12px', padding: '10px 16px', textAlign: 'center', width: '230px', boxSizing: 'border-box', whiteSpace: 'nowrap' });
    this.bal = this.wallet.e.querySelector('.sx-bal');
    this.coin = piece(L, c, '+0.25 IMD', { cls: 'abs mono', left: 760, top: 300, at: T.coin, out: T.coin + 0.6, dy: 0, kind: 'heavy' });
    Object.assign(this.coin.e.style, { fontSize: '18px', background: 'var(--action)', color: 'var(--on-action)', border: '3px solid var(--ink)', borderRadius: '999px', padding: '6px 12px' });
    this.relay = piece(L, c, '<span class="mono" style="font-size:15px;color:var(--ink-2)">sent through a private relay: nobody can copy the tip</span>', { cls: 'abs', left: 640, top: 600, at: T.relay, out: T.steps[2], dy: 10 });

    // Step 3: the setup, typed: clone, install, a fresh wallet, a dry run, run.
    this.h3 = headline(L, c, { n: 3, lines: [['Run', 'one', 'in'], ['five', 'steps.']], small: 'any always-on machine or a small VPS · alerts on Telegram', at: T.steps[2], out: T.end + 10 });
    this.setup = piece(L, c, term('your machine', 600, 400), { left: 630, top: 140, at: T.steps[2] + 0.05, out: T.end, dx: 60, dy: 0, kind: 'heavy' });
    this.setupEl = this.setup.e.querySelector('.sx-term');
    this.setupEl.style.fontSize = '17px';

    this.recap = recap(L, root, c, {
      at: T.end, sub: 'Anyone can keep the court running.',
      rows: ['It does PLEA’s upkeep: deliveries, settlements, points, seasons.', 'Each delivered letter pays a 0.25 IMD tip; the rest costs gas.', 'Clone, fund a fresh wallet with a little ETH, dry run, run.'],
      fine: 'Log lines are examples in the keeper’s format · Not financial advice · Music: “Spy Glass” Kevin MacLeod (incompetech.com), CC BY 4.0',
    });
  },

  update(t, c) {
    const { M } = c, T = this.T, half = c.beatLen() / 2;
    this.chrome.update(t);
    this.ask.update(t);
    if (this.hookTerm.update(t)) {
      const n = LOG.filter((_, i) => t >= T.log0 + i * half).length;
      this.hookLog.innerHTML = LOG.slice(0, n).map(logLine).join('') + (Math.floor(t / 0.25) % 2 ? '<span style="color:var(--action)">▍</span>' : '');
    }
    const s = M.stampLand(t - T.anyone, { from: 2.2, tiltFrom: -14, tilt: -4 });
    this.anyone.update(t, `rotate(${s.rot}deg) scale(${s.scale})`);
    this.layer.style.translate = `0 ${M.jolt(t - T.anyone - 0.05, 8)}px`;

    this.h1.update(t);
    this.jobs.forEach((j) => j.update(t));

    this.h2.update(t);
    if (this.card.update(t)) {
      const left = 420 - Math.floor(Math.max(0, t - T.card) * 1);
      this.cardTime.textContent = `0${Math.floor(left / 60)}:${String(left % 60).padStart(2, '0')}`;
    }
    if (this.dTerm.update(t)) {
      const lines = [];
      if (t >= T.sent) lines.push(logLine(['sent', ',"job":"deliver"']));
      if (t >= T.done) lines.push(logLine(['done', ',"job":"deliver"', '+0.25 IMD']));
      this.dLog.innerHTML = lines.join('');
    }
    this.split.update(t);
    this.wallet.update(t);
    this.bal.textContent = t >= T.coin + 0.5 ? '0.25 IMD' : '0.00 IMD';
    this.wallet.e.style.background = t >= T.coin + 0.5 ? 'var(--action-soft)' : '';
    const fly = M.sp(t - T.coin, 'heavy');
    this.coin.update(t, `translate(${fly * 330}px, ${fly * 200 - Math.sin(Math.PI * Math.min(1, fly)) * 70}px)`);
    this.relay.update(t);

    this.h3.update(t);
    if (this.setup.update(t)) {
      const out = [];
      CMDS.forEach((cmd, i) => {
        const t0 = T.type0 + i * T.cmdGap, t1 = t0 + T.cmdGap * 0.7;
        if (t < t0) return;
        const span = document.createElement('span');
        typeInto(span, cmd, t, t0, t1, i === CMDS.length - 1 ? t1 + 0.4 : t1);
        out.push(`<div style="white-space:nowrap"><span style="color:var(--action)">$ </span>${span.innerHTML}</div>${t >= t1 && NOTES[i] ? `<div style="color:var(--ink-3);white-space:nowrap">${esc(NOTES[i])}</div>` : ''}`);
      });
      if (t >= T.started) out.push(logLine(LOG[0]));
      this.setupEl.innerHTML = out.join('');
    }

    this.recap.update(t);
  },

  cues(c) {
    const T = this.T, half = c.beatLen() / 2;
    const q = [[T.ask, 'pop', 2.2], [T.term, 'whoosh', 0.8, 0.3, 400, 2400], ...LOG.map((_, i) => [T.log0 + i * half, 'tick', 0.5, 2200, 0.008]),
      [T.anyone, 'thump', 0.28, 1.2],
      [T.steps[0], 'whoosh', 1.5, 0.35, 400, 2600], ...JOBS.map((_, i) => [T.jobs + i * T.jobGap, 'tap', 1.0, 1000 + 120 * i, 0.03]),
      [T.steps[1], 'pop', 1.0, 400, 800], [T.card, 'whoosh', 0.8, 0.3, 400, 2400], [T.sent, 'tick', 1.6, 2200, 0.008], [T.done, 'tap', 1.0, 1800, 0.015],
      [T.coin, 'whoosh', 0.8, 0.4, 600, 3000], [T.coin + 0.5, 'bell', 0.5, 1318, 0.4],
      [T.steps[2], 'whoosh', 1.0, 0.35, 400, 2600]];
    CMDS.forEach((_, i) => q.push(...keys(c, T.type0 + i * T.cmdGap, T.type0 + i * T.cmdGap + T.cmdGap * 0.7, 4.0)));
    q.push([T.started, 'pop', 0.8]);
    return [...q, ...this.recap.cues()].map(([t, ...r]) => [Math.round(t * 1000) / 1000, ...r]);
  },
};
