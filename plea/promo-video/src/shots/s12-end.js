// 12 · Free, proof and the end card (bars 32-38 and the hold): "Trading is free. Forever." as the
// band returns, three receipts on the downbeats, then the brand v2 end card; the PLEA stamp slams on
// the song's hard stop.
export default {
  id: 'end',
  from: (c) => c.BAR(32),
  to: () => 999,
  build(root, c) {
    root.classList.add('theme-dark');
    this.root = root;
    this.free = c.el('div', 'abs display');
    // The site's own words after the death (its home page: "Selling is open forever"), with the condition stated on the same slide.
    this.free.innerHTML = '<div style="font-size:40px;line-height:1.15;color:var(--ink-2)"><span class="mask"><span>When the Cabal dies,</span></span></div><div style="margin-top:6px"><span class="mask"><span>selling is open.</span></span><br><span class="mask"><span>Forever.</span></span></div>';
    Object.assign(this.free.style, { left: '64px', top: '56px', fontSize: '88px', lineHeight: '1.06' });
    const R = [['852', 'tests, both forks green'], ['8', 'swarm audit rounds'], ['5 days', 'live on Sepolia · 25 pleas · 3 objections']];
    this.receipts = R.map(([big, small], i) => {
      const e = c.el('div', 'receipt theme-light', `<div class="receipt__big">${big}</div><div class="receipt__small">${small}</div>`);
      Object.assign(e.style, { left: `${64 + i * 384}px`, top: '350px', width: '360px', minHeight: '170px' });
      e.querySelector('.receipt__big').style.fontSize = '72px'; e.querySelector('.receipt__small').style.fontSize = '20px';
      root.appendChild(e);
      return e;
    });
    this.endcard = c.el('div', 'layer');
    this.endcard.style.background = '#121212';
    this.endcard.innerHTML = `
      <div class="abs display" style="left:64px;top:96px;font-size:96px;color:#F5F0E4" data-k="case">Make your case.</div>
      <div class="abs display" style="left:68px;top:232px;font-size:40px;color:#FFD92E" data-k="eth">Coming to Ethereum</div>
      <div class="abs" style="left:68px;top:300px;font-size:40px;font-weight:700;color:#F5F0E4;display:flex;gap:12px;align-items:center" data-k="x"><svg class="icon" style="width:30px;height:30px"><use href="#i-x-logo"/></svg>@Pleaimd</div>
      <div class="abs" style="left:68px;bottom:40px;font-size:15px;color:#C9C1AE;max-width:1150px" data-k="fine">Not financial advice. Not an official IMD page. Music: “The Builder” Kevin MacLeod (incompetech.com), licensed under CC BY 4.0.</div>`;
    this.stamp = c.el('div', 'abs bigstamp', 'PLEA');
    Object.assign(this.stamp.style, { left: '600px', top: '360px', fontSize: '130px', borderColor: '#F5F0E4' });
    this.endcard.appendChild(this.stamp);
    root.appendChild(this.free);
    root.appendChild(this.endcard);
  },
  update(lt, t, c) {
    const { M, AT, BAR } = c;
    const t0 = BAR(32), tEnd = BAR(36);
    const spans = this.free.querySelectorAll('.mask > span');
    [t0 - 0.08, AT(32, 1), AT(32, 2.5)].forEach((at, i) => { spans[i].style.transform = `translateY(${(1 - M.sp(t - at, 'type')) * 125}%)`; });
    const off = M.sp(t - tEnd, 'heavy');
    this.free.style.transform = `translateX(${-1400 * off}px)`;
    this.receipts.forEach((e, i) => {
      const at = BAR(33 + i);
      c.show(e, t >= at);
      const k = M.sp(t - at, 'ui');
      e.style.transform = `translate(${-1400 * off}px, ${(1 - k) * -80}px) rotate(${M.mix(-8, [-2, 1.5, -1][i], k)}deg)`;
    });
    // The end card on bar 36: lines on beats, the stamp on the hard stop.
    c.show(this.endcard, t >= tEnd);
    const parts = Object.fromEntries([...this.endcard.querySelectorAll('[data-k]')].map((e) => [e.dataset.k, e]));
    [['case', tEnd], ['eth', AT(36, 2)], ['x', BAR(37)], ['fine', tEnd]].forEach(([k, at]) => {
      const e = parts[k]; c.show(e, t >= at);
      e.style.transform = `translateY(${(1 - M.sp(t - at, k === 'case' ? 'type' : 'snappy')) * 40}px)`;
    });
    const st = M.stampLand(t - BAR(38));
    c.show(this.stamp, st.visible);
    this.stamp.style.transform = `rotate(${st.rot}deg) scale(${st.scale})`;
    this.stamp.style.boxShadow = `${12 * st.shadow}px ${12 * st.shadow}px 0 #F5F0E4`;
    this.endcard.style.transform = `translateY(${M.jolt(t - BAR(38) - 0.07, 9)}px)`;
  },
};
