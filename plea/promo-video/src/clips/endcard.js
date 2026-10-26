// Clip end card (bar 9 to the end): ink ground, the series line, "Make your case.", Ethereum and
// @Pleaimd on the beats, and the PLEA stamp on the song's hard stop (bar 10).
export default {
  build(root, c) {
    const cfg = c.clip;
    root.style.background = '#121212';
    this.parts = {};
    const add = (k, html, style) => { const e = c.el('div', 'abs', html); Object.assign(e.style, style); root.appendChild(e); this.parts[k] = e; };
    add('series', `How PLEA works · ${cfg.n} of 7 · ${cfg.title}`, { left: c.pick('68px', '44px'), top: c.pick('70px', '150px'), fontSize: '22px', fontWeight: 600, color: '#C9C1AE' });
    add('case', c.pick('Make your case.', 'Make your<br>case.'), { left: c.pick('64px', '40px'), top: c.pick('110px', '200px'), fontSize: c.pick('96px', '92px'), color: '#F5F0E4', fontFamily: 'var(--font-display)', fontStretch: '125%', fontWeight: 800, lineHeight: '1.02' });
    add('eth', 'Coming to Ethereum', { left: c.pick('68px', '44px'), top: c.pick('246px', '420px'), fontSize: '40px', color: '#FFD92E', fontFamily: 'var(--font-display)', fontStretch: '125%', fontWeight: 800 });
    add('x', '<svg class="icon" style="width:30px;height:30px"><use href="#i-x-logo"/></svg>@Pleaimd', { left: c.pick('68px', '44px'), top: c.pick('314px', '490px'), fontSize: '40px', fontWeight: 700, color: '#F5F0E4', display: 'flex', gap: '12px', alignItems: 'center' });
    add('fine', 'Not financial advice. Not an official IMD page. Music: “The Builder” Kevin MacLeod (incompetech.com), licensed under CC BY 4.0.', { left: c.pick('68px', '44px'), bottom: c.pick('40px', '70px'), fontSize: c.pick('15px', '17px'), color: '#C9C1AE', maxWidth: c.pick('1150px', '630px') });
    this.stamp = c.el('div', 'abs bigstamp', 'PLEA');
    Object.assign(this.stamp.style, { left: c.pick('600px', '90px'), top: c.pick('380px', '720px'), fontSize: c.pick('130px', '124px'), borderColor: '#F5F0E4' });
    root.appendChild(this.stamp);
    this.root = root;
  },
  update(lt, t, c) {
    const { M, AT, BAR } = c;
    [['series', AT(9, 0)], ['case', AT(9, 0)], ['eth', AT(9, 1.5)], ['x', AT(9, 2.5)], ['fine', AT(9, 0)]].forEach(([k, at]) => {
      const e = this.parts[k]; c.show(e, t >= at);
      e.style.transform = `translateY(${(1 - M.sp(t - at, k === 'case' ? 'type' : 'snappy')) * 40}px)`;
    });
    const st = M.stampLand(t - BAR(10));
    c.show(this.stamp, st.visible);
    this.stamp.style.transform = `rotate(${st.rot}deg) scale(${st.scale})`;
    this.stamp.style.boxShadow = `${12 * st.shadow}px ${12 * st.shadow}px 0 #F5F0E4`;
    this.root.style.transform = `translateY(${M.jolt(t - BAR(10) - 0.07, 9)}px)`;
  },
};
