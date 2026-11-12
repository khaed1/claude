// 9 · Letters (bars 22-24): a transaction card in our style (not Etherscan). Letter #4's real input
// data is hex that flips into its text; the card is sent to the Letterbox and waits, pending.
import { stamp, caption, esc, DATA } from '../lib/ui.js';

export default {
  id: 'letters',
  from: (c) => c.BAR(22),
  to: (c) => c.BAR(25),
  build(root, c) {
    const text = DATA.letter4.text;
    this.text = text;
    this.hex = [...new TextEncoder().encode(text)].map((b) => b.toString(16).padStart(2, '0')).join('');
    this.tx = c.el('div', 'abs');
    this.tx.innerHTML = `<div class="card" style="width:${c.pick(760, 560)}px;zoom:${c.pick(1.32, 1.15)};padding:16px 22px">
      <div class="cluster cluster--between"><span class="display" style="font-size:22px">Transaction</span><span class="badge badge--letter"><svg class="icon"><use href="#i-envelope-simple"/></svg>letter</span></div>
      <div class="costs" style="margin-top:10px">
        <div><dt>From</dt><dd class="mono">0x5e33…3e0A</dd></div>
        <div><dt>To</dt><dd class="mono">Letterbox 0xbc33…d1d3</dd></div>
        <div><dt>Value</dt><dd class="mono">0 ETH</dd></div></div>
      <div class="label" style="margin-top:10px">Input data</div>
      <div class="input-data mono" style="margin-top:4px;padding:8px 10px;border:2px solid var(--ink);border-radius:8px;background:var(--paper-2);font-size:13px;line-height:1.45;font-weight:500;height:${c.pick(118, 230)}px;overflow:hidden;word-break:break-all"></div>
      <div class="meta" style="margin-top:6px">Sepolia test run 9 · letter #4 · Wed 14:45 UTC</div></div>`;
    Object.assign(this.tx.style, { left: c.pick('64px', '38px'), top: c.pick('36px', '110px'), transformOrigin: '0 0' });
    this.data = this.tx.querySelector('.input-data');
    this.pending = c.el('div', 'abs');
    this.pending.innerHTML = `<div class="label" style="zoom:1.6;margin-bottom:6px">The Letterbox</div><div class="card" style="width:360px;zoom:${c.pick(2.1, 1.7)}"><div class="cluster cluster--between"><span class="plea__id">Letter #4</span>${stamp('pending', 'Pending', '', 'sm')}</div>
      <div class="meta" style="margin-top:8px">20% of the writer’s PLEA in escrow</div></div>`;
    Object.assign(this.pending.style, { left: c.pick('330px', '54px'), top: c.pick('96px', '330px') });
    this.cap = c.el('div', 'cap', caption(['No site? Plead in a transaction.'], 'If it wins, it sells itself.'));
    [this.pending, this.tx, this.cap].forEach((e) => root.appendChild(e));
  },
  update(lt, t, c) {
    const { M, AT, BAR } = c;
    const t0 = BAR(22);
    const k = M.sp(t - t0, 'ui');
    // Decode: from beat 1 of bar 22 to bar 24, characters flip left to right from hex to text.
    const prog = M.clamp((t - AT(22, 1)) / (BAR(24) - 0.3 - AT(22, 1)));
    const n = Math.floor(prog * this.text.length);
    this.data.innerHTML = `<span style="font-family:var(--font-body);font-size:15px;font-weight:600;color:var(--ink)">${esc(this.text.slice(0, n))}</span><span style="color:var(--ink-2)">${this.hex.slice(n * 2)}</span>`;
    // Sent on bar 24: the card shrinks and flies right; the pending letter lands.
    const send = M.sp(t - BAR(24), 'heavy');
    this.tx.style.transform = `translate(${send * c.pick(760, 160)}px, ${(1 - k) * 40 + send * c.pick(60, 760)}px) scale(${M.mix(1, 0.3, send)}) rotate(${send * 6}deg)`;
    c.show(this.tx, send < 0.97);
    const p = M.sp(t - AT(24, 1), 'ui');
    c.show(this.pending, t >= AT(24, 1));
    this.pending.style.transform = `translateY(${(1 - p) * -50}px) rotate(${M.mix(-6, -2, p)}deg)`;
    const ck = M.sp(t - AT(22, 0.5), 'snappy');
    c.show(this.cap, t >= AT(22, 0.5));
    this.cap.style.transform = `translateX(${(1 - ck) * -80}px)`;
  },
};
