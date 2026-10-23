// Input generator for the differential test (seeded, so a run can be repeated exactly).
// Every case is { suite, input, note, plant? }:
//   suite: 'gate' | 'objection' | 'letter' | 'name'
//   input: a JavaScript string (what the site gets), or a Uint8Array (raw bytes the site could
//          never produce from a string: tested only where text-check.js accepts bytes)
//   plant: { index, cp } for a text with exactly one planted defect at UTF-16 index `index`, so
//          the runner can check the position the message names.

export function rng(seed) {
  let a = seed >>> 0;
  const next = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  const int = (lo, hi) => lo + Math.floor(next() * (hi - lo + 1));
  const pick = (arr) => arr[Math.floor(next() * arr.length)];
  const chance = (p) => next() < p;
  return { next, int, pick, chance };
}

const enc = new TextEncoder();
const bytesOf = (s) => (typeof s === 'string' ? enc.encode(s).length : s.length);
const cp = (n) => String.fromCodePoint(n);

/* The refused ranges, read from the contract's own _refused expression (not from the JS table). */
export function refusedRangesFromSource(refusedSrc) {
  const body = refusedSrc.slice(refusedSrc.indexOf('return'));
  const out = [];
  for (const m of body.matchAll(/cp\s*<=\s*(0x[0-9a-f]+)|cp\s*==\s*(0x[0-9a-f]+)|cp\s*-\s*(0x[0-9a-f]+)\s*<=\s*(\d+)|cp\s*>>\s*(\d+)\s*==\s*(0x[0-9a-f]+)/gi)) {
    if (m[1]) out.push([0, Number(m[1])]);
    else if (m[2]) out.push([Number(m[2]), Number(m[2])]);
    else if (m[3]) out.push([Number(m[3]), Number(m[3]) + Number(m[4])]);
    else { const s = Number(m[5]); const v = Number(m[6]); out.push([v << s, ((v + 1) << s) - 1]); }
  }
  const terms = body.split('||').length;
  if (out.length !== terms) throw new Error('could not read every term of _refused (' + out.length + ' of ' + terms + ')');
  return out;
}

const EMOJI = ['😭', '🙏', '❤️', '❤', '☺️', '☺', '👨‍👩‍👧', '👩‍💻', '👍🏽', '🇺🇦', '🇯🇵', '🏳️‍🌈', '🏴󠁧󠁢󠁳󠁣󠁴󠁿', '1️⃣', '#⃣', '©️', '™', '🫠', '🧑🏿‍🦱', '👁‍🗨', '✌︎', '💸', '🐋', '🦐'];
const WORDS = ['I', 'held', 'the', 'bag', 'through', 'dip', 'please', 'sell', 'appeal', 'name', 'rent', 'PLEA', 'plea', 'objection',
  'Cabal', 'mercy', '20%', '$', '"quoted"', 'back\\slash', 'a,b;c', '(x)', '{y}', '<z>', '~', '`', '|', '^', '@', '#', '&', '*', '!', '?', ']', '/'];
const SCRIPTS = [
  [0xa1, 0xff], [0x100, 0x17f], [0x370, 0x3ff], [0x400, 0x4ff], [0x5d0, 0x5ea], [0x620, 0x64a], [0x900, 0x97f], [0xe01, 0xe5b],
  [0x4e00, 0x9fff], [0xac00, 0xd7a3], [0x3041, 0x30ff], [0x1f300, 0x1faff], [0x20000, 0x2a6df], [0x300, 0x36f]
];
const LONE = ['\ud800', '\udbff', '\udc00', '\udfff', '\ud83d', '\ude2d'];
const SPECIAL_OK = [0xfffd, 0xfffe, 0xffff, 0xfdd0, 0xfdef, 0xe000, 0xf8ff, 0xf0000, 0xffffd, 0x100000, 0x10fffd, 0x10ffff, 0x378,
  0x2fffe, 0xe1000, 0xeffff, 0x1fffe, 0xa0, 0x2010, 0x2027, 0x2030, 0x3000, 0xfe10, 0x20e3, 0x34e, 0x350, 0xd7ff];

export function markerVariants() {
  const out = [];
  const cases = (w) => {
    const res = [];
    for (let mask = 0; mask < 1 << w.length; mask++) {
      let s = '';
      for (let k = 0; k < w.length; k++) s += mask & (1 << k) ? w[k].toUpperCase() : w[k];
      res.push(s);
    }
    return res;
  };
  for (const w of cases('plea')) { out.push('[' + w, '[/' + w); }
  for (const w of cases('objection')) { out.push('[' + w, '[/' + w); }
  return out;
}

const NEAR_MARKERS = ['[ple', '[/ple', '[pl', '[p', '[', '[/', '[//plea', '[ plea', '[\nplea', '[pleb', '[plEb', '[objectio', '[/objectio',
  '[OBJECTIO', '[obj', '[[', '[/[', '[ｐlea', '[рlea', '[pléa', '[/​plea', '[\\plea', '(plea', '{plea', '[0bjection', '[`lea',
  '[pleA ', '[/Objectio n'];

let REFUSED_NOW = [];
const isRefused = (c) => REFUSED_NOW.some(([lo, hi]) => c >= lo && c <= hi);

function codePointsOf(lo, hi, r, clean) {
  let c;
  do c = r.int(lo, hi); while ((c >= 0xd800 && c <= 0xdfff) || (clean && isRefused(c)));
  return c;
}

/* A string with no defect (as far as the contract is concerned): no controls, refused characters,
   lone surrogates or '[' (so no marker can form across a junction). */
function benign(r, maxBytes) {
  let s = '';
  let n = 0;
  for (let guard = 0; guard < 400; guard++) {
    let f;
    const x = r.next();
    if (x < 0.45) f = r.pick(WORDS) + ' ';
    else if (x < 0.75) { const [lo, hi] = r.pick(SCRIPTS); f = cp(codePointsOf(lo, hi, r, true)); }
    else if (x < 0.85) f = r.pick(EMOJI.filter((e) => !/[‍️︎]|\udb40/.test(e)));
    else if (x < 0.9) f = cp(r.pick(SPECIAL_OK));
    else f = String.fromCharCode(r.int(0x20, 0x7e)).replace('[', '(');
    const fb = bytesOf(f);
    if (n + fb > maxBytes) break;
    s += f;
    n += fb;
  }
  return s;
}

/* One defect the contract refuses (in any context), with the code point it starts with. */
function defect(r, refused) {
  const x = r.next();
  if (x < 0.25) { const c = r.pick([...Array(32).keys(), 0x7f]); return { s: String.fromCharCode(c), cp: c }; }
  if (x < 0.55) {
    const [lo, hi] = r.pick(refused.filter(([lo]) => lo > 0));
    const c = r.chance(0.5) ? r.pick([lo, hi]) : r.int(lo, hi);
    return { s: cp(c), cp: c };
  }
  if (x < 0.7) { const c = r.int(0x80, 0x9f); return { s: cp(c), cp: c }; }
  const m = r.pick(markerVariants());
  return { s: m, cp: 0x5b };
}

/* Random text biased to the edges: lengths near 280, every kind of defect, near-misses. */
function randomText(r, refused) {
  const x = r.next();
  const target = x < 0.3 ? r.int(0, 300) : x < 0.6 ? r.int(268, 292) : x < 0.7 ? r.pick([279, 280, 281]) : r.int(0, 40);
  // about 4 in 10 have no planted defect (only near-misses, which may still form a marker)
  const clean = r.chance(0.4);
  let s = '';
  let n = 0;
  for (let guard = 0; guard < 600 && n < target; guard++) {
    let f;
    const y = r.next();
    if (clean) {
      if (y < 0.02) f = r.pick(NEAR_MARKERS);
      else if (y < 0.03) f = cp(r.pick(SPECIAL_OK));
      else f = benign(r, Math.max(1, Math.min(12, target - n)));
    } else if (y < 0.03) f = defect(r, refused).s;
    else if (y < 0.05) f = r.pick(NEAR_MARKERS);
    else if (y < 0.06) f = r.pick(LONE);
    else if (y < 0.08) f = cp(codePointsOf(0x80, 0x10ffff, r));
    else if (y < 0.1) { const [lo, hi] = r.pick(refused); f = cp(Math.max(0, r.pick([lo - 1, hi + 1, lo, hi]))); }
    else if (y < 0.13) f = r.pick(EMOJI);
    else f = benign(r, r.int(1, 12));
    if (!f) continue;
    s += f;
    n = bytesOf(s);
  }
  return s;
}

function repeatTo(ch, bytes, pad = 'a') {
  const w = bytesOf(ch);
  return ch.repeat(Math.floor(bytes / w)) + pad.repeat(bytes % w);
}

/* Texts for the gate and the Tribunal. */
function textCases(r, refused, count) {
  const cases = [];
  const add = (input, note, plant) => cases.push({ input, note, plant });
  add('', 'empty');
  for (const ch of ['a', 'ж', '判', '😭']) {
    for (const t of [1, 2, 3, 4, 5, 278, 279, 280, 281, 282, 283, 284]) {
      add(repeatTo(ch, t), 'length ' + t + ' of ' + ch);
      add('a'.repeat(t % bytesOf(ch)) + ch.repeat(Math.floor(t / bytesOf(ch))), 'length ' + t + ' of ' + ch + ' (padding first)');
      if (t > bytesOf(ch)) add('a'.repeat(t - bytesOf(ch)) + ch, 'length ' + t + ', ' + ch + ' last');
    }
  }
  for (let c = 0; c < 0x20; c++) for (const pos of ['start', 'mid', 'end']) {
    const s = String.fromCharCode(c);
    add(pos === 'start' ? s + 'abc' : pos === 'mid' ? 'ab' + s + 'cd' : 'abc' + s, 'control ' + c + ' ' + pos, { index: pos === 'start' ? 0 : pos === 'mid' ? 2 : 3, cp: c });
  }
  add('abc\x7f', 'DEL', { index: 3, cp: 0x7f });
  add('\x7f', 'DEL alone', { index: 0, cp: 0x7f });
  for (const [lo, hi] of refused) {
    for (const c of [lo - 1, lo, lo + 1, hi - 1, hi, hi + 1]) {
      if (c < 0 || c > 0x10ffff || (c >= 0xd800 && c <= 0xdfff)) continue;
      add('a' + cp(c) + 'b', 'range edge ' + c.toString(16), { index: 1, cp: c });
      add(cp(c), 'alone ' + c.toString(16), { index: 0, cp: c });
    }
  }
  for (const m of markerVariants()) {
    add(m, 'marker alone');
    add(m + ']', 'marker ]');
    add('x ' + m + ' y', 'marker mid', { index: 2, cp: 0x5b });
    add('é' + m, 'marker after 2-byte', { index: 1, cp: 0x5b });
    add('😭' + m, 'marker after emoji', { index: 2, cp: 0x5b });
    add(m.slice(0, -1), 'marker cut');
    add('a'.repeat(280 - bytesOf(m)) + m, 'marker at the 280th byte', { index: 280 - bytesOf(m), cp: 0x5b });
    add('a'.repeat(281 - bytesOf(m)) + m, 'marker past 280');
  }
  for (const m of NEAR_MARKERS) { add(m, 'near marker'); add('a ' + m + 'z', 'near marker mid'); add('a ' + m, 'near marker end'); }
  for (const e of ['[/', '[', 'x[/', 'x [', '[/p', '[/pl', '[/ple', '[/plea', 'abc[/']) add(e, '[/ at the end');
  for (const e of EMOJI) { add(e, 'emoji'); add('rent ' + e + ' due', 'emoji mid'); }
  for (const c of SPECIAL_OK) add('a' + cp(c) + 'b', 'special ' + c.toString(16));
  for (const l of LONE) { add('a' + l + 'b', 'lone surrogate'); add(l, 'lone surrogate alone'); add('a'.repeat(278) + l, 'lone surrogate to 281 bytes'); add('a'.repeat(277) + l, 'lone surrogate to 280 bytes'); }
  // one planted defect in clean text, for the positions
  for (let k = 0; k < Math.floor(count / 6); k++) {
    const pre = benign(r, r.int(0, 200));
    const d = defect(r, refused);
    const post = benign(r, r.int(0, 60));
    add(pre + d.s + post, 'planted', { index: pre.length, cp: d.cp });
  }
  while (cases.length < count) add(randomText(r, refused), 'random');
  return cases;
}

/* Raw bytes (invalid UTF-8 and friends), for where text-check.js accepts bytes. */
const RAW_BAD = [
  [0x80], [0xbf], [0xc0, 0x80], [0xc0, 0xaf], [0xc1, 0xbf], [0xc2], [0xdf], [0xe0, 0x80, 0x80], [0xe0, 0x9f, 0xbf], [0xe0, 0xa0],
  [0xed, 0xa0, 0x80], [0xed, 0xbf, 0xbf], [0xed, 0x9f, 0xbf], [0xee, 0x80, 0x80], [0xf0, 0x80, 0x80, 0x80], [0xf0, 0x8f, 0xbf, 0xbf],
  [0xf0, 0x90, 0x80, 0x80], [0xf4, 0x8f, 0xbf, 0xbf], [0xf4, 0x90, 0x80, 0x80], [0xf5, 0x80, 0x80, 0x80], [0xf8, 0x88, 0x80, 0x80, 0x80],
  [0xfe], [0xff], [0xc3, 0x41], [0xc3, 0xc3, 0xa9], [0xe2, 0x82, 0x41], [0xe2, 0x41, 0xac], [0xf0, 0x9f, 0x98, 0x41], [0xf0, 0x9f, 0x98],
  [0xef, 0xbb, 0xbf], [0xef, 0xbf, 0xbd], [0xef, 0xbf, 0xbe], [0xe2, 0x80, 0x8b], [0xc2, 0x85], [0xc2, 0xa0], [0x00], [0x5b, 0x50, 0x4c, 0x45, 0x41],
  [0x5b, 0xd0, 0x4c, 0x45, 0x41], [0x5b, 0x70, 0x6c, 0x65, 0xe1], [0xf3, 0xa0, 0x80, 0x81], [0xf3, 0xa1, 0x80, 0x80], [0xf3, 0xb0, 0x80, 0x80]
];

function rawCases(r, count) {
  const cases = [];
  const add = (b, note) => cases.push({ input: Uint8Array.from(b), note });
  for (let a = 0; a < 256; a++) add([a], 'raw 1 byte');
  for (const s of RAW_BAD) { add(s, 'raw seq'); add([0x61, ...s, 0x62], 'raw seq mid'); add([0x61, ...s], 'raw seq end'); }
  for (let a = 0xc0; a < 0x100; a++) for (const b of [0x00, 0x41, 0x7f, 0x80, 0x81, 0x8f, 0x90, 0x9f, 0xa0, 0xbf, 0xc0, 0xff]) {
    add([a, b], 'raw lead+1');
    add([a, b, 0x80], 'raw lead+2');
    add([a, b, 0x80, 0x80], 'raw lead+3');
    add([a, b, 0xbf, 0xbf, 0x61], 'raw lead+3 a');
  }
  while (cases.length < count) {
    const b = [];
    const target = r.chance(0.3) ? r.int(276, 284) : r.int(1, 60);
    while (b.length < target) {
      const x = r.next();
      if (x < 0.5) b.push(r.int(0x20, 0x7e));
      else if (x < 0.75) b.push(...r.pick(RAW_BAD));
      else if (x < 0.9) b.push(...enc.encode(cp(codePointsOf(0x80, 0x10ffff, r))));
      else b.push(r.int(0, 255));
    }
    add(b, 'raw random');
  }
  return cases;
}

const LETTER_WORDS = ['APPEAL', 'SELL', 'NAME', 'appeal', 'Appeal', 'sell', 'Sell', 'name', 'Name', 'APPEALS', 'APPEALING', 'APPEA', 'SELLS', 'SEL',
  'NAMES', 'NAM', 'ＡＰＰＥＡＬ', 'ΑPPEAL', '[PLEA]', ''];
const SEPS = [' ', '\n', '\t', '', '\r', '\r\n', '  ', ' \n', '\n ', '\n\n', 'x', ':', '-', '_', ' ', '​', '﻿', '　', ' ', '\x00', '\x7f', 'é'];
const NAME_CHARS = 'abcdefghijklmnopqrstuvwxyz0123456789_';
const NAME_BAD = ['A', 'Z', 'M', '-', ' ', '.', '!', '\n', '\t', '\x00', '\x7f', 'é', 'ж', '😭', '﻿', '​', 'ı', 'ſ', 'K', '０', '`', '{', '/', ':', '@', '[', '^'];
const RESERVED = ['cabal', 'admin', 'imd', 'plea', 'owner'];

export function nameCase(r) {
  const x = r.next();
  if (x < 0.15) {
    const w = r.pick(RESERVED);
    return r.pick([w, w.toUpperCase(), w[0].toUpperCase() + w.slice(1), w + '_', '_' + w, w + '0', w + 's', w.slice(0, -1), ' ' + w, w + ' ', w + '\n', '﻿' + w, w + w]);
  }
  const len = x < 0.6 ? r.pick([0, 1, 2, 3, 4, 19, 20, 21, 22]) : r.int(0, 26);
  let s = '';
  for (let k = 0; k < len; k++) s += r.chance(0.06) ? r.pick(NAME_BAD) : NAME_CHARS[r.int(0, NAME_CHARS.length - 1)];
  return s;
}

function nameCases(r, count) {
  const cases = [];
  const add = (input, note) => cases.push({ input, note });
  for (const w of RESERVED) add(w, 'reserved');
  for (const n of [0, 1, 2, 3, 4, 19, 20, 21, 22]) { add('a'.repeat(n), 'length ' + n); add('_'.repeat(n), 'length ' + n + ' _'); add('9'.repeat(n), 'length ' + n + ' 9'); }
  for (const b of NAME_BAD) { add('ab' + b, 'bad 3rd'); add(b + 'abc', 'bad 1st'); add('é'.repeat(10), '10 é = 20 bytes'); add('é'.repeat(2), '2 é = 4 bytes'); }
  for (let c = 0; c < 128; c++) add('ab' + String.fromCharCode(c), 'ascii ' + c);
  while (cases.length < count) add(nameCase(r), 'random name');
  return cases;
}

function letterCases(r, refused, count) {
  const cases = [];
  const add = (input, note) => cases.push({ input, note });
  for (const w of LETTER_WORDS) for (const sep of SEPS) {
    add(w + sep, 'word+sep');
    add(w + sep + 'I was honest', 'word+sep+text');
    add(w + sep + 'mira_eth', 'word+sep+name');
    add(w + sep + nameCase(r), 'word+sep+random name');
    add(w + sep + randomText(r, refused), 'word+sep+random text');
  }
  for (const body of ['', ' ', 'x', 'mira_eth', 'Mira', 'ab', 'abc', 'a'.repeat(20), 'a'.repeat(21), 'plea', 'imd', '﻿abc', '﻿', '​abc']) {
    add('NAME ' + body, 'NAME body'); add('NAME\n' + body, 'NAME nl body'); add('APPEAL ' + body, 'APPEAL body'); add('APPEAL\n' + body, 'APPEAL nl body');
  }
  for (const ch of ['a', 'ж', '判', '😭']) for (const t of [279, 280, 281]) {
    add(repeatTo(ch, t), 'letter length ' + t + ' ' + ch);
    add('APPEAL ' + repeatTo(ch, t), 'appeal length ' + t + ' ' + ch);
    add('APPEAL\n' + repeatTo(ch, t), 'appeal nl length ' + t + ' ' + ch);
    add('SELL ' + repeatTo(ch, t), 'sell + length ' + t + ' ' + ch);
    add('NAME ' + repeatTo(ch, t), 'name + length ' + t + ' ' + ch);
  }
  // one planted defect after a command word, for the positions (relative to the whole letter)
  for (let k = 0; k < Math.floor(count / 10); k++) {
    const head = r.pick(['APPEAL ', 'APPEAL\n', '']);
    const pre = benign(r, r.int(0, 150));
    if (head === '' && /^(APPEAL|NAME|SELL)( |\n|$)/.test(pre)) continue;
    const d = defect(r, refused);
    const post = benign(r, r.int(0, 60));
    cases.push({ input: head + pre + d.s + post, note: 'planted letter', plant: { index: head.length + pre.length, cp: d.cp } });
  }
  add('APPEAL ' + '[PLEA]', 'appeal marker');
  add('APPEAL [/objection', 'appeal marker');
  add('[PLEA] APPEAL', 'marker first');
  add('APPEAL ' + 'a'.repeat(273), 'appeal 280 total');
  add('a'.repeat(280), 'plea 280');
  add('a'.repeat(281), 'plea 281');
  while (cases.length < count) {
    const x = r.next();
    if (x < 0.5) add(r.pick(LETTER_WORDS.slice(0, 3)) + r.pick([' ', '\n', ' ', '']) + (r.chance(0.3) ? nameCase(r) : randomText(r, refused)), 'random command');
    else add(randomText(r, refused), 'random letter');
  }
  return cases;
}

/* Raw letters / names: bytes after a command word. */
function rawLetterCases(r, count) {
  const raw = rawCases(r, count);
  const out = [];
  for (const c of raw) {
    const w = r.pick(['APPEAL ', 'NAME ', 'SELL ', 'APPEAL\n', 'NAME\n', '', '', '']);
    out.push({ input: Uint8Array.from([...enc.encode(w), ...c.input]), note: 'raw letter ' + JSON.stringify(w) + ' + ' + c.note });
  }
  return out;
}

export function generate({ seed, scale, refused, bytes }) {
  const r = rng(seed);
  REFUSED_NOW = refused;
  const n = (k) => Math.max(1, Math.round(k * scale));
  const out = [];
  const tag = (suite, list) => { for (const c of list) out.push({ suite, ...c }); };
  const texts = textCases(r, refused, n(24000));
  tag('gate', texts);
  tag('objection', texts.filter((_, k) => k % 2 === 0));
  tag('objection', textCases(r, refused, n(3000)).filter((c) => c.note === 'random' || c.note === 'planted'));
  tag('letter', letterCases(r, refused, n(10000)));
  tag('name', nameCases(r, n(4000)));
  if (bytes) {
    const raw = rawCases(r, n(6000));
    tag('gate', raw);
    tag('objection', raw.filter((_, k) => k % 3 === 0));
    tag('letter', rawLetterCases(r, n(5000)));
    tag('letter-raw', rawLetterCases(r, n(5000)));
    tag('letter-raw', letterCases(r, refused, n(3000)).map((c) => ({ ...c, input: enc.encode(c.input), note: 'as raw data: ' + c.note })));
    tag('name', rawCases(r, n(1500)).map((c) => ({ ...c, input: c.input.subarray(0, 24) })));
  }
  return out;
}
