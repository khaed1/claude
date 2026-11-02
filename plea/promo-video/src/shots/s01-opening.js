// 1 · Opening: the site's hero line drops in word by word on the quiet bar; the PLEA stamp slams
// down as the band comes in (bar 0); a one-line "what it is" on bar 1.
export default {
  id: 'opening',
  from: 0,
  to: (c) => c.BAR(2),
  build(root, c) {
    const L = c.el('div', 'layer');
    root.appendChild(L);
    const lines = c.pick([['Buying', 'is', 'open.'], ['Selling', 'needs'], ['a', 'plea.']], [['Buying'], ['is', 'open.'], ['Selling'], ['needs'], ['a', 'plea.']]);
    const beats = c.pick([[0, 0.5, 1], [2, 2.5], [3, 3.5]], [[0], [0.5, 1], [2], [2.5], [3, 3.5]]);
    this.words = [];
    const head = c.el('div', 'abs display');
    Object.assign(head.style, c.pick({ left: '64px', top: '96px', fontSize: '100px', lineHeight: '1.04' }, { left: '40px', top: '170px', fontSize: '96px', lineHeight: '1.04' }));
    lines.forEach((ws, i) => {
      const line = c.el('div');
      ws.forEach((w, j) => {
        const m = c.el('span', 'mask'); const s = c.el('span', '', w);
        m.appendChild(s); line.appendChild(m);
        if (j < ws.length - 1) line.appendChild(document.createTextNode(' '));
        this.words.push({ s, at: c.AT(-1, beats[i][j]) });
      });
      head.appendChild(line);
    });
    L.appendChild(head);
    this.stamp = c.el('div', 'abs bigstamp', 'PLEA');
    Object.assign(this.stamp.style, c.pick({ left: '640px', top: '372px', fontSize: '150px' }, { left: '96px', top: '740px', fontSize: '130px' }), { transformOrigin: '50% 50%' });
    L.appendChild(this.stamp);
    this.what = c.el('div', 'cap');
    this.what.innerHTML = '<span class="cap__small">A meme token on Uniswap v4</span>';
    Object.assign(this.what.style, c.pick({ left: '64px', bottom: '56px' }, { left: '40px', bottom: '190px' }));
    L.appendChild(this.what);
    this.L = L;
  },
  update(lt, t, c) {
    const { M } = c;
    for (const w of this.words) {
      const k = M.sp(t - w.at, 'type');
      w.s.style.transform = `translateY(${(1 - k) * 125}%)`;
    }
    const b0 = c.BAR(0);
    const st = M.stampLand(t - b0);
    c.show(this.stamp, st.visible);
    this.stamp.style.transform = `rotate(${st.rot}deg) scale(${st.scale})`;
    this.stamp.style.boxShadow = `${12 * st.shadow}px ${12 * st.shadow}px 0 var(--ink)`;
    const w = M.sp(t - c.BAR(1), 'snappy');
    this.what.style.transform = `translateY(${(1 - w) * 90}px)`;
    c.show(this.what, t >= c.BAR(1));
    const push = 1 + 0.035 * M.clamp((t - b0) / (c.BAR(2) - b0)) ** 0.8;
    const j = M.jolt(t - b0 - 0.07, 7);
    this.L.style.transform = `translate(0, ${j}px) scale(${push})`;
  },
};
