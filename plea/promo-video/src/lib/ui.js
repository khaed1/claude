// The site's components as markup (classes from site-design/components.css), filled with real data.
export const esc = (s) => String(s).replace(/[&<>"]/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[ch]));

export const stamp = (state, word, sub = '', size = 'xl') =>
  `<span class="stamp stamp--${state} stamp--${size}">${esc(word)}${sub ? `<span class="stamp__sub">${esc(sub)}</span>` : ''}</span>`;

export const zoom = (html, z) => `<div style="zoom:${z}">${html}</div>`;

export const fact = (label, value, pts) =>
  `<div class="fact"><span class="fact__label">${esc(label)}</span><span class="fact__value">${esc(value)}</span><span class="fact__pts">${esc(pts)}</span></div>`;

export const meter = (score, need, kind = 'pending') =>
  `<div class="meter meter--${kind}" style="--score:${score};--need:${need}">
     <div class="meter__bar"><div class="meter__fill"></div><div class="meter__need"></div></div>
     <div class="meter__scale"><span>0</span><span>45</span></div></div>`;

// A plea card like the site's: id, who, when, the text; optional stamp slot and facts.
export const pleaCard = ({ id, who, when, text, seat = false, meta = 'Sepolia test run 9' }) =>
  `<div class="plea">
     <div class="plea__head"><span class="plea__id">Plea #${id}</span><span class="plea__who">by ${esc(who)}</span>
       ${seat ? '<span class="badge badge--seat">SEAT ×1.2</span>' : ''}<span class="plea__time">${esc(when)} · ${esc(meta)}</span></div>
     <p class="plea__text">“${esc(text)}”</p></div>`;

export const caption = (main = [], small = '') =>
  `${main.map((m) => `<span class="cap__main">${esc(m)}</span>`).join('')}${small ? `<span class="cap__small">${esc(small)}</span>` : ''}`;

// Real run 9 data used on screen.
export const DATA = {
  p14: {
    id: 14, who: '0xB45A…1811', when: 'Thu 18:25 UTC',
    text: 'Dear judges, today your server took a long lunch and my plea came back from it with a 33. No complaint: I bought a day ago, I am still under water, and I need 90,000 PLEA, about 3%, to pay the fees of staying in this game. Everything else I hold stays for the seasons.',
    facts: [['Share sold', '3.32%', '+16'], ['Held', '1d 3h', '+2'], ['Profit or loss', '−2.18%', '+13'], ['24h trend', 'flat', '+5']],
    fact: 36, need: 35, score: 35, objection: 32,
  },
  p1: {
    id: 1, who: '0x6828…8F4f', when: 'Wed 13:22 UTC',
    text: 'I got 2.5M PLEA from the airdrop when trading opened today and have held it for about 15 minutes. I want to sell 100,000 of it, 4% of my balance, to pay for gas. The other 96% stays in my wallet and I plan to keep playing the seasons.',
    fact: 31, need: 40, score: 27,
  },
  letter4: {
    tx: '0x412e352f…e2967e92',
    text: 'Dear judges, a letter from a holder of one afternoon. I took the airdrop at the open and bought a little more after. I ask to sell a fifth of my PLEA: gas does not take IOUs and my wallet is thirsty. Four fifths stay put, and I will keep writing to you.',
  },
};
