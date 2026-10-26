// §5 Letters: a plea sent as a plain transaction whose data is the text, to the Letterbox, from any wallet. The
// first word picks the command (APPEAL, SELL, NAME; anything else is a new plea for 20% of the writer's PLEA). The
// plea's PLEA waits in escrow; the fees (0.5 IMD panel + 0.25 IMD runner tip) are bought with the writer's PLEA in
// the same transaction. Approved: anyone delivers it inside the 7-minute window and earns the tip, the whole sale
// goes to the writer. Otherwise the escrow and the tip come back. Real data, Sepolia test run 9: letter #22 from
// 0x5e33…3e0A, raw transaction data to the Letterbox 0xbc33…d1d3 (Sat 16:13), 449,842 PLEA = 20% of 2,249,212,
// denied 34 vs need 36, escrow and tip returned by settle.
import { chrome, headline, recap, piece, verdict, typeInto, keys, press } from './kit.js';

const TEXT = 'Dear Cabal, a letter from a wallet that has written to you four times since Wednesday and kept every PLEA it was given. I ask to sell a fifth of my bag to fund the gas and fees of my pleas; the other four fifths stay here, and so do I.';
const hex = (s) => '0x' + [...new TextEncoder().encode(s)].map((b) => b.toString(16).padStart(2, '0')).join('');
const HEX = hex(TEXT);

const row = (k, v) => `<div style="display:grid;grid-template-columns:70px minmax(0,1fr);gap:12px;align-items:start;padding:8px 0;border-bottom:2px solid var(--line-soft)">
  <span class="label" style="font-size:14px;padding-top:2px">${k}</span><span style="font-size:17px">${v}</span></div>`;
const chip = (html, bg = 'var(--card)', fg = 'var(--ink)') => `<span class="mono" style="display:inline-block;font-size:16px;border:3px solid var(--ink);border-radius:999px;padding:5px 12px;background:${bg};color:${fg};white-space:nowrap">${html}</span>`;

export default {
  build(root, c) {
    const { BAR, AT } = c;
    const T = this.T = {
      steps: [BAR(2), AT(3, 2), BAR(5)], end: BAR(7),
      ask: BAR(0), hex: AT(0, 1), decode: BAR(1),
      form: BAR(2) + 0.1, type0: AT(2, 1), type1: AT(3, 0.5), cmds: AT(2, 2), send: AT(3, 1),
      bag: AT(3, 2.5), split: AT(3, 3.5), escrow: BAR(4), fees: AT(4, 1.5),
      flow: AT(5, 0.5), real: BAR(6), denied: AT(6, 0.5), back: AT(6, 1.5),
    };
    this.layer = c.el('div', 'layer');
    root.appendChild(this.layer);
    const L = this.layer;
    this.chrome = chrome(L, root, c, { steps: ['Send', 'Escrow', 'Delivery'], at: T.steps, end: T.end });

    // Hook: raw transaction data that turns out to be a plea.
    this.ask = piece(L, c, 'This transaction is a plea.', { cls: 'abs sx-big', left: 0, top: 120, at: T.ask, out: T.steps[0], dy: -30 });
    Object.assign(this.ask.e.style, { right: '0', textAlign: 'center', fontSize: '50px' });
    this.hexBox = piece(L, c, '<div class="sx-hex"></div>', { cls: 'abs card', left: 240, top: 240, width: 800, at: T.hex, out: T.steps[0], dy: 40 });
    Object.assign(this.hexBox.e.style, { padding: '20px 26px', boxSizing: 'border-box', boxShadow: '8px 8px 0 var(--shadow-color)' });
    this.hexEl = this.hexBox.e.querySelector('.sx-hex');
    Object.assign(this.hexEl.style, { fontSize: '19px', lineHeight: '1.5', minHeight: '172px', wordBreak: 'break-all' });
    this.hexTag = piece(L, c, chip('to: Letterbox 0xbc33…d1d3 · Sat 16:13'), { cls: 'abs', left: 240, top: 470, at: T.decode + 0.3, out: T.steps[0], dy: 20, kind: 'snappy' });

    // Step 1: the send form: to the Letterbox, 0 ETH, the text as data; the first word can be a command.
    this.h1 = headline(L, c, { n: 1, lines: [['Text', 'the'], ['Letterbox.']], small: 'from any wallet’s data field, or an explorer’s message page', at: T.steps[0], out: T.steps[1] });
    this.form = piece(L, c, `<div class="card" style="width:584px;box-sizing:border-box;padding:12px 20px 16px;box-shadow:8px 8px 0 var(--shadow-color)">
      <div class="label" style="font-size:14px;margin-bottom:4px">Send transaction</div>
      ${row('To', '<span class="mono">Letterbox · 0xbc33…d1d3</span>')}${row('Value', '<span class="mono">0 ETH</span>')}
      ${row('Data', '<div class="sx-data" style="min-height:150px;line-height:1.42"></div><div class="mono sx-datahex" style="font-size:12px;color:var(--ink-3);margin-top:6px;white-space:nowrap;overflow:hidden"></div>')}
      <div style="display:flex;align-items:center;gap:10px;margin-top:12px"><span class="sx-cmds" style="display:flex;gap:8px;align-items:center"><span class="label" style="font-size:13px">first word:</span>${chip('APPEAL')}${chip('SELL')}${chip('NAME')}</span>
      <button class="btn btn--primary btn--sm" style="margin-left:auto">Send</button></div></div>`, { left: 640, top: 124, at: T.form, out: T.steps[1], dx: 80, dy: 0, kind: 'heavy' });
    this.data = this.form.e.querySelector('.sx-data');
    this.dataHex = this.form.e.querySelector('.sx-datahex');
    this.cmds = this.form.e.querySelector('.sx-cmds');
    this.sendBtn = this.form.e.querySelector('.btn');

    // Step 2: 20% of the bag goes into the Letterbox's escrow; the fees are bought with PLEA.
    this.h2 = headline(L, c, { n: 2, lines: [['20%', 'waits'], ['in', 'escrow.']], small: 'fees are bought with your PLEA, in the same transaction', at: T.steps[1], out: T.steps[2] });
    this.bag = piece(L, c, `<div style="width:584px"><div class="mono" style="font-size:16px;margin-bottom:8px">0x5e33…3e0A · 2,249,212 PLEA</div>
      <div style="position:relative;height:48px;border:3px solid var(--ink);border-radius:10px;background:var(--card)">
        <span style="position:absolute;inset:0 0 0 20%;background:repeating-linear-gradient(90deg, var(--paper-2) 0 8px, transparent 8px 16px)"></span>
        <span class="mono" style="position:absolute;right:12px;top:12px;font-size:15px;color:var(--ink-2)">80% stays with you</span></div></div>`,
      { left: 640, top: 140, at: T.bag, out: T.steps[2], dx: 60, dy: 0 });
    this.slice = piece(L, c, '<span class="mono" style="font-size:15px">20%</span>', { cls: 'abs', left: 643, top: 172, at: T.bag, out: T.steps[2], dx: 60, dy: 0 });
    Object.assign(this.slice.e.style, { width: `${584 * 0.2 - 6}px`, height: '42px', background: 'var(--action)', color: 'var(--on-action)', borderRight: '3px solid var(--ink)',
      borderRadius: '7px 0 0 7px', display: 'grid', placeContent: 'center' });
    this.escrow = piece(L, c, `<div class="label" style="font-size:14px">Letterbox escrow</div><div class="sx-big" style="font-size:40px;margin-top:4px">449,842 PLEA</div>
      <div class="mono" style="font-size:14px;color:var(--ink-2);margin-top:2px">20% of the bag · the plea’s amount</div>`, { left: 640, top: 300, width: 400, at: T.escrow, out: T.steps[2], dy: 30 });
    Object.assign(this.escrow.e.style, { border: '4px dashed var(--action)', borderRadius: '14px', padding: '14px 20px', boxSizing: 'border-box' });
    this.fees = piece(L, c, `<div class="label" style="font-size:14px;margin-bottom:8px">paid in PLEA, same transaction</div><div style="display:flex;gap:10px;flex-wrap:wrap">
      ${chip('0.5 IMD panel fee')}${chip('0.25 IMD runner tip')}</div>`, { left: 640, top: 470, at: T.fees, out: T.steps[2], dy: 20, kind: 'snappy' });

    // Step 3: approved letters are sold by anyone for the tip; letter #22 was denied, so it all came back.
    this.h3 = headline(L, c, { n: 3, lines: [['Approved?'], ['Anyone', 'sells', 'it.']], small: 'they earn the 0.25 IMD tip; the whole sale is yours', at: T.steps[2], out: T.end + 10 });
    this.flow = piece(L, c, `<div class="label" style="font-size:14px;margin-bottom:10px">if approved, within 7 minutes:</div>
      <div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap">${chip('escrow')}<span class="sx-big" style="font-size:22px">→</span>${chip('any wallet delivers', 'var(--action)', 'var(--on-action)')}<span class="sx-big" style="font-size:22px">→</span>${chip('IMD to you')}${chip('+0.25 tip to them')}</div>`,
      { left: 640, top: 140, at: T.flow, out: T.end, dx: 60, dy: 0 });
    this.realCard = piece(L, c, `<div class="card" style="width:584px;box-sizing:border-box;padding:14px 20px 16px;box-shadow:8px 8px 0 var(--shadow-color)">
      <div style="display:flex;justify-content:space-between"><span class="mono" style="font-size:19px">Letter #22</span><span class="meta" style="font-size:14px">Sat 16:13 · 449,842 PLEA in escrow</span></div>
      <div style="margin-top:8px;font-size:17px;line-height:1.42">“Dear Cabal, a letter from a wallet that has written to you four times since Wednesday and kept every PLEA it was given…”</div></div>`,
      { left: 640, top: 290, at: T.real, out: T.end, dy: 50, kind: 'heavy' });
    this.realStamp = verdict(L, c, { state: 'denied', word: 'Denied', sub: '34 vs need 36', x: 1060, y: 440, zoom: 1.0 });
    this.back = piece(L, c, chip('↩ escrow + tip back to the writer'), { cls: 'abs', left: 640, top: 520, at: T.back, out: T.end, dy: 20, kind: 'snappy' });

    this.recap = recap(L, root, c, {
      at: T.end, sub: 'Plead from any wallet.',
      rows: ['Send your plea as plain text to the Letterbox, from any wallet.', '20% of your PLEA waits in escrow; fees are paid in PLEA.', 'Approved: anyone sells it for a 0.25 IMD tip. If not, escrow and tip come back.'],
      fine: 'Letter #22 is real (Sepolia test run 9) · Not financial advice · Music: “Spy Glass” Kevin MacLeod (incompetech.com), CC BY 4.0',
    });
  },

  update(t, c) {
    const { M } = c, T = this.T;
    this.chrome.update(t);
    this.ask.update(t);
    // The hex decodes into the text from left to right on bar 1.
    if (this.hexBox.update(t)) {
      const k = M.ramp(t, T.decode, T.decode + 0.9);
      const n = Math.round(TEXT.length * k);
      const shown = TEXT.slice(0, n), rest = HEX.slice(2 + n * 2, 2 + n * 2 + Math.max(0, 300 - n * 2));
      this.hexEl.innerHTML = `<span style="font-family:var(--font-body);font-size:20px">${shown}</span><span class="mono" style="color:var(--ink-3)">${n ? '' : '0x'}${rest}</span>`;
    }
    this.hexTag.update(t);

    this.h1.update(t);
    if (this.form.update(t)) {
      const n = typeInto(this.data, TEXT, t, T.type0, T.type1);
      this.dataHex.textContent = n ? hex(TEXT.slice(0, Math.min(n, 40))) + '…' : '';
      this.cmds.style.opacity = M.ramp(t, T.cmds, T.cmds + 0.2);
      press(this.sendBtn, t, T.send);
    }

    this.h2.update(t);
    this.bag.update(t);
    const drop = M.sp(t - T.split, 'heavy');
    this.slice.update(t, `translate(${drop * 10}px, ${drop * 140}px) scale(${M.mix(1, 0.001, M.ramp(t, T.escrow + 0.1, T.escrow + 0.25))})`);
    this.escrow.update(t);
    this.fees.update(t);

    this.h3.update(t);
    this.flow.update(t);
    this.realCard.update(t);
    this.realStamp.update(t, T.denied);
    this.back.update(t);

    this.recap.update(t);
  },

  cues(c) {
    const T = this.T;
    const q = [[T.ask, 'pop', 0.7], [T.hex, 'whoosh', 0.8, 0.3, 400, 2400]];
    for (let k = 0; k < 14; k++) q.push([T.decode + k * 0.065, 'tick', 1.6, 2400 + 90 * (k % 5), 0.006]);
    q.push([T.steps[0], 'whoosh', 1.5, 0.35, 400, 2600], ...keys(c, T.type0, T.type1), [T.cmds, 'pop', 0.8], [T.send, 'tap', 1.2, 1800, 0.015],
      [T.steps[1], 'pop', 1.0, 400, 800], [T.bag, 'tap', 1.0, 900, 0.04], [T.split, 'whoosh', 0.9, 0.35, 300, 1800], [T.escrow, 'thump', 0.5, 0.5], [T.fees, 'pop', 0.9],
      [T.steps[2], 'whoosh', 1.0, 0.35, 400, 2600], [T.flow, 'ratchet', 0.8, 6, 0.3], [T.real, 'whoosh', 1.0, 0.4, 300, 1800], [T.denied, 'thump', 1.1, 1.2], [T.back, 'pop', 1.0]);
    return [...q, ...this.recap.cues()].map(([t, ...r]) => [Math.round(t * 1000) / 1000, ...r]);
  },
};
