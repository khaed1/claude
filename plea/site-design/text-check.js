/* PLEA text checks: the contract's rules, in the browser.
 *
 * Mirrors khaed1/plea (branch next):
 *   CabalGate._validateText / _refused / _checkMarker  (plea and appeal text; BadPleaText)
 *   Tribunal._validateText (the same rules for objection text; BadObjectionText)
 *   Letterbox._read / _isWord / _after / _checkName / _checkLength  (letters, NAME, LetterTooLong)
 * A text the contract accepts must pass here, and a text it refuses must fail here, with the reason
 * in plain words. The byte count is the UTF-8 byte count the contract sees (TextEncoder, as viem
 * encodes a string argument).
 *
 * Use: PleaText.checkText(s), PleaText.checkLetter(s), PleaText.checkName(s), PleaText.byteLength(s).
 * Works as a browser global (window.PleaText) and as a CommonJS module (tests in tools/). */
(function (root) {
  'use strict';

  var MAX_BYTES = 280;
  var NAME_MIN = 3;
  var NAME_MAX = 20;
  var RESERVED_NAMES = ['cabal', 'admin', 'imd', 'plea', 'owner'];

  /* Code points the contract refuses beyond ASCII (CabalGate._refused, Unicode 15.1), with a plain
     name for the message. Inclusive ranges. */
  var REFUSED = [
    [0x80, 0x9f, 'a control character'],
    [0xad, 0xad, 'a soft hyphen (U+00AD, invisible)'],
    [0x34f, 0x34f, 'a combining grapheme joiner (U+034F, invisible)'],
    [0x600, 0x605, 'an Arabic number sign (invisible format character)'],
    [0x61c, 0x61c, 'an Arabic letter mark (U+061C, invisible)'],
    [0x6dd, 0x6dd, 'an Arabic end-of-ayah sign (format character)'],
    [0x70f, 0x70f, 'a Syriac abbreviation mark (format character)'],
    [0x890, 0x891, 'an Arabic pound or piastre mark (format character)'],
    [0x8e2, 0x8e2, 'an Arabic disputed end-of-ayah sign (format character)'],
    [0x115f, 0x1160, 'a Hangul filler (invisible)'],
    [0x17b4, 0x17b5, 'a Khmer inherent vowel (invisible)'],
    [0x180b, 0x180f, 'a Mongolian variation selector (invisible)'],
    [0x200b, 0x200f, 'a zero-width or direction mark (U+200B-200F, invisible)'],
    [0x2028, 0x2029, 'a line or paragraph separator'],
    [0x202a, 0x202e, 'a text-direction control (U+202A-202E, invisible)'],
    [0x2060, 0x206f, 'an invisible format character (U+2060-206F)'],
    [0x3164, 0x3164, 'a Hangul filler (invisible)'],
    [0xfe00, 0xfe0f, 'a variation selector (U+FE00-FE0F, invisible)'],
    [0xfeff, 0xfeff, 'a zero-width no-break space (U+FEFF, invisible)'],
    [0xffa0, 0xffa0, 'a Hangul filler (invisible)'],
    [0xfff0, 0xfffb, 'an invisible annotation or reserved character (U+FFF0-FFFB)'],
    [0x110bd, 0x110bd, 'a Kaithi number sign (format character)'],
    [0x110cd, 0x110cd, 'a Kaithi number sign above (format character)'],
    [0x13430, 0x1343f, 'an Egyptian hieroglyph format control'],
    [0x1bca0, 0x1bca3, 'a shorthand format control'],
    [0x1d173, 0x1d17a, 'a musical format control'],
    [0xe0000, 0xe0fff, 'a tag or variation selector (U+E0000-E0FFF, invisible)']
  ];

  var enc = typeof TextEncoder !== 'undefined' ? new TextEncoder() : null;

  function utf8(text) {
    if (enc) return enc.encode(text);
    return Uint8Array.from(Buffer.from(text, 'utf8'));
  }

  function byteLength(text) {
    return utf8(text).length;
  }

  function hex(cp) {
    var h = cp.toString(16).toUpperCase();
    while (h.length < 4) h = '0' + h;
    return 'U+' + h;
  }

  function refusedName(cp) {
    for (var k = 0; k < REFUSED.length; k++) {
      if (cp >= REFUSED[k][0] && cp <= REFUSED[k][1]) return REFUSED[k][2];
    }
    return null;
  }

  function asciiControlName(c) {
    if (c === 0x0a || c === 0x0d) return 'a line break (a plea is one line)';
    if (c === 0x09) return 'a tab';
    if (c === 0x7f) return 'a delete character';
    return 'a control character';
  }

  /* The gate's rules on a string: { ok, bytes, max, chars, issues: [{ code, message, at, char }] }.
     `at` is the 1-based character position (code points), for "at character 14". All issues are
     listed, not only the first, so a writer can fix them in one go; `ok` is what the contract
     decides. `errorName` is the custom error the contract reverts with. */
  function checkText(text, errorName) {
    errorName = errorName || 'BadPleaText';
    var issues = [];
    var b = utf8(text);
    var n = b.length;
    var chars = 0;

    if (n === 0) issues.push({ code: 'empty', message: 'Write something: a plea needs at least 1 byte.' });
    if (n > MAX_BYTES) {
      issues.push({ code: 'too-long', message: n + ' bytes: cut ' + (n - MAX_BYTES) + ' to reach 280.' });
    }

    // Lone surrogates in a JS string become U+FFFD when encoded; the contract would accept the
    // replacement character, but the writer did not type it, so it is flagged (not a contract refusal).
    var cpIndex = 0;
    for (var s = 0; s < text.length; s++) {
      var u = text.charCodeAt(s);
      cpIndex++;
      if (u >= 0xd800 && u <= 0xdbff) {
        var nx = text.charCodeAt(s + 1);
        if (nx >= 0xdc00 && nx <= 0xdfff) { s++; continue; }
        issues.push({ code: 'broken', warning: true, at: cpIndex, message: 'A broken character at character ' + cpIndex + ' would be sent as �.' });
      } else if (u >= 0xdc00 && u <= 0xdfff) {
        issues.push({ code: 'broken', warning: true, at: cpIndex, message: 'A broken character at character ' + cpIndex + ' would be sent as �.' });
      }
    }

    // Byte walk, exactly as _validateText (the input is TextEncoder output, so it is always
    // well-formed UTF-8; the length and overlong checks are kept for raw bytes passed in).
    var i = 0;
    while (i < n) {
      var c = b[i];
      chars++;
      if (c < 0x20 || c === 0x7f) {
        issues.push({ code: 'control', at: chars, char: c, message: 'Remove ' + asciiControlName(c) + ' at character ' + chars + '.' });
        i++;
        continue;
      }
      if (c === 0x5b) {
        var m = markerAt(b, i, n);
        if (m) issues.push({ code: 'marker', at: chars, message: 'Remove the “[' + m + '” at character ' + chars + ': the contract refuses any “[' + m.toLowerCase().replace(/^\//, '') + '” or “[/' + m.toLowerCase().replace(/^\//, '') + '” in any case (even “[please”). Drop the bracket.' });
      }
      if (c < 0x80) { i++; continue; }
      var len;
      if (c >= 0xc2 && c <= 0xdf) len = 2;
      else if (c >= 0xe0 && c <= 0xef) len = 3;
      else if (c >= 0xf0 && c <= 0xf4) len = 4;
      else { issues.push({ code: 'utf8', at: chars, message: 'Bad UTF-8 at character ' + chars + '.' }); i++; continue; }
      if (i + len > n) { issues.push({ code: 'utf8', at: chars, message: 'Bad UTF-8 at the end.' }); break; }
      var cp = c & (0x7f >> len);
      var bad = false;
      for (var k = 1; k < len; k++) {
        var cb = b[i + k];
        if ((cb & 0xc0) !== 0x80) bad = true;
        cp = (cp << 6) | (cb & 0x3f);
      }
      if (bad || (len === 3 && cp < 0x800) || (len === 4 && cp < 0x10000) || (cp >> 11) === 0x1b || cp > 0x10ffff) {
        issues.push({ code: 'utf8', at: chars, message: 'Bad UTF-8 at character ' + chars + '.' });
      } else {
        var name = refusedName(cp);
        if (name) {
          var tip = cp >= 0xfe00 && cp <= 0xfe0f ? ' Emoji like ❤️ carry one: pick the plain version or another emoji.'
            : cp === 0x200d ? ' Joined emoji (families, some flags of people) use it: use a single emoji.' : '';
          issues.push({ code: 'refused', at: chars, cp: cp, message: 'Remove ' + name + ' (' + hex(cp) + ') at character ' + chars + '.' + tip });
        }
      }
      i += len;
    }

    var refusals = issues.filter(function (x) { return !x.warning; });
    return {
      ok: refusals.length === 0,
      bytes: n,
      max: MAX_BYTES,
      chars: chars,
      error: refusals.length ? errorName : null,
      issues: issues
    };
  }

  /* _checkMarker: at a '[' (byte i), an optional '/', then "plea" (4 bytes) or "objection" (9 bytes)
     in any ASCII case. Returns the matched text as written (e.g. "PLEA", "/plea", "Objection"). */
  function markerAt(b, i, n) {
    var j = i + 1;
    var slash = '';
    if (j < n && b[j] === 0x2f) { j++; slash = '/'; }
    if (j + 4 > n) return null;
    var w4 = '';
    for (var k = 0; k < 4; k++) w4 += String.fromCharCode(b[j + k] | 0x20);
    if (w4 === 'plea') return slash + String.fromCharCode(b[j], b[j + 1], b[j + 2], b[j + 3]);
    if (j + 9 <= n) {
      var w9 = '';
      for (var q = 0; q < 9; q++) w9 += String.fromCharCode(b[j + q] | 0x20);
      if (w9 === 'objection') {
        var raw = '';
        for (var r = 0; r < 9; r++) raw += String.fromCharCode(b[j + r]);
        return slash + raw;
      }
    }
    return null;
  }

  /* Letterbox._isWord: `word` alone, or followed by a space or a newline (capitals only). */
  function isWord(b, word) {
    var nw = word.length;
    if (b.length < nw) return false;
    if (b.length > nw && b[nw] !== 0x20 && b[nw] !== 0x0a) return false;
    for (var k = 0; k < nw; k++) if (b[k] !== word.charCodeAt(k)) return false;
    return true;
  }

  function decode(bytes) {
    if (typeof TextDecoder !== 'undefined') return new TextDecoder().decode(bytes);
    return Buffer.from(bytes).toString('utf8');
  }

  /* A letter as the Letterbox reads it (raw input data or letter(text)). Returns
     { kind: 'plea'|'appeal'|'sell'|'name'|'clear-name', body, ok, bytes, issues, reads, error }.
     `reads` says in plain words what the letter does. Contract-side conditions that depend on chain
     state (cooldown, an open plea, nothing to appeal, a taken name, the balance) are not checked here. */
  function checkLetter(text) {
    var b = utf8(text);
    var res;
    if (isWord(b, 'APPEAL')) {
      var body = decode(b.length > 7 ? b.subarray(7) : new Uint8Array(0));
      res = textLetter('appeal', body, 'An appeal of your latest denied plea, for its original share of your PLEA, sold automatically if approved.');
      if (body.length === 0) res.issues.unshift({ code: 'empty', message: 'APPEAL needs your appeal text after it: APPEAL <text>.' });
    } else if (isWord(b, 'NAME')) {
      var nm = decode(b.length > 5 ? b.subarray(5) : new Uint8Array(0));
      if (nm.length === 0) {
        res = { kind: 'clear-name', body: '', ok: true, bytes: b.length, issues: [], error: null, reads: 'Clears your display name.' };
      } else {
        var cn = checkName(nm);
        res = { kind: 'name', body: nm, ok: cn.ok, bytes: b.length, issues: cn.issues, error: cn.ok ? null : 'BadName', reads: 'Sets your display name to “' + nm + '”.' };
      }
    } else if (isWord(b, 'SELL')) {
      res = { kind: 'sell', body: '', ok: true, bytes: b.length, issues: [], error: null, reads: 'Sells your approved letter plea now (if no runner has yet), and the 0.25 IMD tip comes back to you.' };
      if (b.length > 4) res.issues.push({ code: 'ignored', warning: true, message: 'Everything after SELL is ignored: this letter is read as SELL, not as a plea. To plead, start with another word (or write "sell" in lower case).' });
    } else {
      res = textLetter('plea', text, 'A new plea for 20% of your PLEA (at most 2,500,000), sold automatically if approved.');
      var first = /^(appeal|sell|name)\b/i.exec(text);
      if (first) res.issues.push({ code: 'case', warning: true, message: 'Commands are in capitals: “' + first[1] + '” here starts a plain plea, not the ' + first[1].toUpperCase() + ' command.' });
    }
    return res;
  }

  function textLetter(kind, body, reads) {
    var bytes = byteLength(body);
    var r = checkText(body, 'BadPleaText');
    // _checkLength runs first in the Letterbox and names the length.
    var error = r.error;
    if (bytes > MAX_BYTES) error = 'LetterTooLong(' + bytes + ', 280)';
    return { kind: kind, body: body, ok: r.ok, bytes: bytes, max: MAX_BYTES, chars: r.chars, issues: r.issues, error: error, reads: reads };
  }

  /* Letterbox._checkName: 3-20 bytes of a-z 0-9 _, not reserved. Uniqueness is on chain (NameTaken). */
  function checkName(name) {
    var issues = [];
    var b = utf8(name);
    if (b.length < NAME_MIN || b.length > NAME_MAX) issues.push({ code: 'name-length', message: 'Use 3 to 20 characters (now ' + b.length + ').' });
    var badChar = null;
    for (var k = 0; k < b.length; k++) {
      var c = b[k];
      if (!((c >= 0x61 && c <= 0x7a) || (c >= 0x30 && c <= 0x39) || c === 0x5f)) { badChar = k; break; }
    }
    if (badChar !== null) issues.push({ code: 'name-chars', message: 'Only lower-case a-z, digits 0-9 and _ are allowed.' });
    if (RESERVED_NAMES.indexOf(name) !== -1) issues.push({ code: 'name-reserved', message: '“' + name + '” is reserved (cabal, admin, imd, plea and owner are).' });
    return { ok: issues.length === 0, issues: issues, error: issues.length ? 'BadName' : null };
  }

  /* "193 / 280 bytes" plus a hint for scripts that take more than one byte per character. */
  function bytesLabel(text) {
    var n = byteLength(text);
    return n + ' / ' + MAX_BYTES + ' bytes';
  }

  var api = {
    MAX_BYTES: MAX_BYTES,
    REFUSED: REFUSED,
    RESERVED_NAMES: RESERVED_NAMES,
    byteLength: byteLength,
    bytesLabel: bytesLabel,
    checkText: checkText,
    checkObjection: function (s) { return checkText(s, 'BadObjectionText'); },
    checkLetter: checkLetter,
    checkName: checkName
  };
  root.PleaText = api;
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
})(typeof window !== 'undefined' ? window : globalThis);
