// node --test plea/site-design/tools/text-check.test.cjs
// Unit tests for text-check.js against the contract rules (CabalGate._validateText, Letterbox).
const test = require('node:test');
const assert = require('node:assert/strict');
const T = require('../text-check.js');

const cp = (n) => String.fromCodePoint(n);

test('byte counts are UTF-8 bytes', () => {
  assert.equal(T.byteLength('a'), 1);
  assert.equal(T.byteLength('é'), 2);
  assert.equal(T.byteLength('ж'), 2);
  assert.equal(T.byteLength('判'), 3);
  assert.equal(T.byteLength('😭'), 4);
});

test('1-280 bytes', () => {
  assert.equal(T.checkText('').ok, false);
  assert.equal(T.checkText('').issues[0].code, 'empty');
  assert.equal(T.checkText('a'.repeat(280)).ok, true);
  assert.equal(T.checkText('a'.repeat(281)).ok, false);
  assert.equal(T.checkText('ж'.repeat(140)).ok, true);   // 280 bytes
  assert.equal(T.checkText('ж'.repeat(141)).ok, false);  // 282 bytes
  assert.equal(T.checkText('判'.repeat(93)).ok, true);   // 279 bytes
  assert.equal(T.checkText('判'.repeat(94)).ok, false);  // 282 bytes
});

test('ASCII controls and DEL are refused, space and printable ASCII pass', () => {
  for (let c = 0; c < 0x20; c++) assert.equal(T.checkText('a' + String.fromCharCode(c) + 'b').ok, false, 'c=' + c);
  assert.equal(T.checkText('a\x7fb').ok, false);
  for (let c = 0x20; c < 0x7f; c++) {
    const s = 'x' + String.fromCharCode(c) + 'x';
    assert.equal(T.checkText(s).ok, true, 'c=' + c);
  }
  assert.match(T.checkText('one\ntwo').issues[0].message, /line break/);
});

test('every refused range, at its edges', () => {
  for (const [lo, hi] of T.REFUSED.map((r) => [r[0], r[1]])) {
    assert.equal(T.checkText('a' + cp(lo) + 'b').ok, false, 'lo ' + lo.toString(16));
    assert.equal(T.checkText('a' + cp(hi) + 'b').ok, false, 'hi ' + hi.toString(16));
  }
  // neighbours that are allowed (not in any range)
  const allowed = [0xa0, 0xac, 0xae, 0x34e, 0x350, 0x5ff, 0x606, 0x61b, 0x61d, 0x6dc, 0x6de, 0x70e, 0x710,
    0x88f, 0x892, 0x8e1, 0x8e3, 0x115e, 0x1161, 0x17b3, 0x17b6, 0x180a, 0x1810, 0x200a, 0x2010, 0x2027,
    0x202f, 0x205f, 0x2070, 0x3163, 0x3165, 0xfdff, 0xfe10, 0xfefe, 0xff00, 0xff9f, 0xffa1, 0xffef, 0xfffc,
    0xfffd, 0x110bc, 0x110be, 0x110cc, 0x110ce, 0x1342f, 0x13440, 0x1bc9f, 0x1bca4, 0x1d172, 0x1d17b,
    0xdffff, 0xe1000, 0x10ffff, 0x1f600];
  for (const a of allowed) assert.equal(T.checkText('a' + cp(a) + 'b').ok, true, 'allowed ' + a.toString(16));
});

test('emoji: plain ones pass, VS16 and ZWJ sequences are refused with a tip', () => {
  assert.equal(T.checkText('rent is due 😭').ok, true);
  assert.equal(T.checkText('🇺🇦').ok, true);                 // regional indicators
  assert.equal(T.checkText('👍🏽').ok, true);                  // skin tone modifier
  const heart = T.checkText('I ❤️ PLEA');
  assert.equal(heart.ok, false);
  assert.match(heart.issues[0].message, /variation selector/);
  assert.equal(T.checkText('👨‍👩‍👧').ok, false);           // ZWJ
});

test('markers [PLEA [/PLEA [OBJECTION [/OBJECTION in any case', () => {
  for (const s of ['[PLEA]', '[plea', '[Plea x', 'x [/PLEA]', '[/pLeA', '[PLEASE let me', '[OBJECTION]', '[/objection',
    'a [ObJeCtIoN b']) {
    const r = T.checkText(s);
    assert.equal(r.ok, false, s);
    assert.equal(r.issues[0].code, 'marker', s);
  }
  for (const s of ['[ plea', '[pleb', 'plea]', '[ple', '[/ple', '[objectio', '[/objectio', '[[', '[', '[/',
    '(PLEA)', '[P LEA', '[objections are welcome? no: [objection', 'PLEA[']) {
    const r = T.checkText(s);
    if (s.endsWith('[objection')) { assert.equal(r.ok, false, s); continue; }
    assert.equal(r.ok, true, s);
  }
});

test('letters: commands in capitals followed by space, newline or nothing', () => {
  assert.equal(T.checkLetter('I bought the top.').kind, 'plea');
  assert.equal(T.checkLetter('APPEAL I was honest the first time.').kind, 'appeal');
  assert.equal(T.checkLetter('APPEAL I was honest the first time.').body, 'I was honest the first time.');
  assert.equal(T.checkLetter('APPEAL\nsecond try').body, 'second try');
  const bare = T.checkLetter('APPEAL');
  assert.equal(bare.kind, 'appeal');
  assert.equal(bare.ok, false);
  assert.equal(T.checkLetter('APPEAL ').ok, false);
  assert.equal(T.checkLetter('SELL').kind, 'sell');
  const sellPlus = T.checkLetter('SELL me some mercy');
  assert.equal(sellPlus.kind, 'sell');
  assert.equal(sellPlus.issues[0].code, 'ignored');
  assert.equal(T.checkLetter('SELLING is all I want').kind, 'plea');
  assert.equal(T.checkLetter('sell please').kind, 'plea');
  assert.equal(T.checkLetter('sell please').issues[0].code, 'case');
  assert.equal(T.checkLetter('NAME').kind, 'clear-name');
  assert.equal(T.checkLetter('NAME mira_eth').kind, 'name');
  assert.equal(T.checkLetter('NAME mira_eth').ok, true);
  assert.equal(T.checkLetter('NAME Mira').ok, false);
  assert.equal(T.checkLetter('APPEALING to you').kind, 'plea');
  assert.equal(T.checkLetter('Appeal to mercy').kind, 'plea');
});

test('letters: LetterTooLong names the length, appeal text excludes the command word', () => {
  const long = T.checkLetter('a'.repeat(281));
  assert.equal(long.ok, false);
  assert.equal(long.error, 'LetterTooLong(281, 280)');
  const ap = T.checkLetter('APPEAL ' + 'a'.repeat(280));
  assert.equal(ap.ok, true);
  assert.equal(ap.bytes, 280);
  assert.equal(T.checkLetter('a\nb').ok, false);
});

test('names: 3-20 of a-z 0-9 _, reserved words refused', () => {
  assert.equal(T.checkName('mira_eth').ok, true);
  assert.equal(T.checkName('ab').ok, false);
  assert.equal(T.checkName('a'.repeat(21)).ok, false);
  assert.equal(T.checkName('a'.repeat(20)).ok, true);
  assert.equal(T.checkName('Mira').ok, false);
  assert.equal(T.checkName('mira-eth').ok, false);
  assert.equal(T.checkName('mira eth').ok, false);
  for (const r of ['cabal', 'admin', 'imd', 'plea', 'owner']) assert.equal(T.checkName(r).ok, false, r);
  assert.equal(T.checkName('pleas').ok, true);
  assert.equal(T.checkName('née_x').ok, false);
});

test('objection text uses the same rules and the Tribunal error name', () => {
  assert.equal(T.checkObjection('The plea copies a 2025 CabalCoin plea word for word.').ok, true);
  assert.equal(T.checkObjection('[OBJECTION] fake').error, 'BadObjectionText');
});
