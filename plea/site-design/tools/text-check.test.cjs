// node --test plea/site-design/tools/text-check.test.cjs
// Unit tests for text-check.js against the contract rules (CabalGate._validateText, Letterbox).
// The differential test against the Solidity itself: node plea/site-design/tools/difftest/run.mjs
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

// ---------------------------------------------------------------- found by the differential test
// (tools/difftest/run.mjs, the Solidity on a local EVM, 2026-10-19)

test('a byte order mark after APPEAL / NAME is sent to the contract and refused (was: stripped and accepted)', () => {
  const ap = T.checkLetter('APPEAL ﻿abc');
  assert.equal(ap.kind, 'appeal');
  assert.equal(ap.ok, false);
  assert.equal(ap.error, 'BadPleaText');
  assert.equal(ap.body, '﻿abc');
  assert.equal(ap.bytes, 6);
  assert.equal(T.checkLetter('APPEAL\n﻿').ok, false);
  const nm = T.checkLetter('NAME ﻿abc');
  assert.equal(nm.kind, 'name');
  assert.equal(nm.ok, false);
  assert.equal(nm.error, 'BadName');
  const bare = T.checkLetter('NAME ﻿');           // a 3-byte name, not "clear my name"
  assert.equal(bare.kind, 'name');
  assert.equal(bare.ok, false);
  assert.equal(T.checkLetter('NAME\n﻿mira').ok, false);
});

test('an empty name clears it: setName("") is accepted (was: refused)', () => {
  const r = T.checkName('');
  assert.equal(r.ok, true);
  assert.equal(r.clears, true);
  assert.equal(r.error, null);
  assert.match(r.issues[0].message, /clears/);
});

test('raw bytes: the byte walk on input the site could never produce from a string', () => {
  const b = (...x) => Uint8Array.from(x);
  assert.equal(T.byteLength(b(0x61, 0x62)), 2);
  assert.equal(T.checkText(b(0x61)).ok, true);
  assert.equal(T.checkText(b(0xc3, 0xa9)).ok, true);                      // é
  assert.equal(T.checkText(b(0xf4, 0x8f, 0xbf, 0xbf)).ok, true);          // U+10FFFF
  assert.equal(T.checkText(b(0xed, 0x9f, 0xbf)).ok, true);                // U+D7FF
  for (const bad of [[0x80], [0xc0, 0x80], [0xc1, 0xbf], [0xc2], [0xe0, 0x9f, 0xbf], [0xed, 0xa0, 0x80], [0xed, 0xbf, 0xbf],
    [0xf0, 0x8f, 0xbf, 0xbf], [0xf4, 0x90, 0x80, 0x80], [0xf5, 0x80, 0x80, 0x80], [0xff], [0xc3, 0x41], [0xe2, 0x82, 0x41],
    [0xf0, 0x9f, 0x98], [0xef, 0xbb, 0xbf], [0xc2, 0x85], [0x00]]) {
    const r = T.checkText(b(0x61, ...bad));
    assert.equal(r.ok, false, bad.map((x) => x.toString(16)).join(' '));
    assert.equal(r.error, 'BadPleaText');
  }
  assert.match(T.checkText(b(0x61, 0xc3, 0x41)).issues[0].message, /at byte 2/);
  assert.match(T.checkText(b(0x61, 0xf0, 0x9f)).issues[0].message, /ends in the middle/);
  assert.equal(T.checkObjection(b(0xed, 0xa0, 0x80)).error, 'BadObjectionText');
  // a raw letter (transaction data): the command word, then the bytes as they are
  const ap = T.checkLetter(b(0x41, 0x50, 0x50, 0x45, 0x41, 0x4c, 0x20, 0xc3, 0x28));
  assert.equal(ap.kind, 'appeal');
  assert.equal(ap.ok, false);
  assert.deepEqual([...ap.body], [0xc3, 0x28]);
  assert.equal(T.checkLetter(b(0x53, 0x45, 0x4c, 0x4c, 0x20, 0xff)).kind, 'sell');
  assert.equal(T.checkLetter(new Uint8Array(0)).ok, false);
  assert.equal(T.checkName(b(0x61, 0x62, 0x80)).ok, false);
  assert.equal(T.checkName(b(0x6d, 0x69, 0x72, 0x61)).ok, true);
});

// ---------------------------------------------------------------- positions and words in the messages

test('positions count characters as the writer sees them, and point at invisible ones', () => {
  const heart = T.checkText('I ❤️ PLEA').issues[0];
  assert.equal(heart.at, 3);                       // I, space, ❤️
  assert.equal(heart.index, 3);                    // the U+FE0F in the string
  assert.match(heart.message, /inside “❤️” \(character 3\)/);
  const fam = T.checkText('👨‍👩‍👧 rent');
  assert.equal(fam.issues.length, 1);              // two joiners, one thing to fix
  assert.equal(fam.issues[0].at, 1);
  const zw = T.checkText('I would like to buy the keeper a sandwich.​ Twenty percent, please.').issues[0];
  assert.equal(zw.index, 42);
  assert.match(zw.message, /zero-width space \(U\+200B\) right after “…the keeper a sandwich\.” \(character 43\)/);
  assert.match(T.checkText('​start').issues[0].message, /at the very start/);
  const crlf = T.checkText('one\r\ntwo');
  assert.equal(crlf.issues.length, 1);
  assert.match(crlf.issues[0].message, /line break right after “one” \(character 4\): a plea is one line/);
  assert.match(T.checkObjection('one\ntwo').issues[0].message, /an objection is one line/);
  assert.equal(T.checkText('x [PLEA').issues[0].at, 3);
  assert.equal(T.checkText('😭[plea').issues[0].at, 2);
  assert.equal(T.checkText('😭[plea').issues[0].index, 2);
  const broken = T.checkText('a\ud800b');
  assert.equal(broken.ok, true);
  assert.equal(broken.issues[0].at, 2);
});

test('letter positions are in the whole letter, not in the text after APPEAL (was: off by 7)', () => {
  const r = T.checkLetter('APPEAL hello​');
  assert.equal(r.issues[0].at, 13);
  assert.equal(r.issues[0].index, 12);
  assert.match(r.issues[0].message, /right after “APPEAL hello” \(character 13\)/);
  assert.equal(T.checkLetter('APPEAL\n[plea').issues[0].at, 8);
  assert.equal(T.checkLetter('NAME Mira').issues[0].at, 6);
});

test('messages in plain words', () => {
  assert.equal(T.checkText('a'.repeat(281)).issues[0].message, 'Too long: 281 bytes, the most is 280. Cut 1 byte.');
  assert.match(T.checkText('ж'.repeat(141)).issues[0].message, /Cut 2 bytes\. Letters outside A–Z take 2 to 4 bytes each/);
  assert.match(T.checkText('').issues[0].message, /a plea cannot be empty/);
  assert.match(T.checkObjection('').issues[0].message, /an objection cannot be empty/);
  assert.match(T.checkObjection('[/Objection').issues[0].message, /“\[objection” and “\[\/objection” in any case, even inside a longer word like “\[objections”/);
  assert.match(T.checkText('[Please').issues[0].message, /like “\[please”/);
  assert.doesNotMatch(T.checkText('a‍b').issues[0].message, /\(.*\) \(/);   // no doubled brackets
  assert.match(T.checkText('a؀b').issues[0].message, /^Remove the Arabic number sign \(U\+0600\)/);
  // one message for APPEAL with nothing after it
  const bare = T.checkLetter('APPEAL ');
  assert.equal(bare.issues.length, 1);
  assert.match(bare.issues[0].message, /APPEAL needs your appeal text/);
  // capitals but the wrong separator: not "commands are in capitals"
  const tab = T.checkLetter('APPEAL\tplease');
  assert.equal(tab.kind, 'plea');
  assert.equal(tab.issues.find((i) => i.warning).code, 'separator');
  assert.equal(T.checkLetter('NAME:mira').issues[0].code, 'separator');
  assert.equal(T.checkLetter('Appeal to mercy').issues[0].code, 'case');
  assert.equal(T.checkLetter('APPEALING to you').issues.length, 0);
  // names: which character, and no byte count for a name that is not ASCII
  assert.equal(T.checkName('Mira').issues[0].message, 'Only lower-case a–z, digits 0–9 and _ are allowed: “M” at character 1 is not (use “m”).');
  assert.match(T.checkName('mira eth').issues[0].message, /the space at character 5/);
  const accents = T.checkName('é'.repeat(11));       // 22 bytes, 11 characters
  assert.equal(accents.ok, false);
  assert.equal(accents.issues.length, 1);
  assert.equal(accents.issues[0].code, 'name-chars');
  assert.equal(T.checkName('ab').issues[0].message, 'Use 3 to 20 characters (now 2).');
});
