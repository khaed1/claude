/* PLEA mockup behaviour: theme, mobile menu, the byte counter with the contract's text checks,
   copy buttons, the auto-sell box and state switchers. Load in <head> (it sets the theme before
   first paint), after text-check.js. The real site rebuilds these in React; the behaviour and the
   words are the spec. */
(function () {
  'use strict';
  var KEY = 'plea-theme';
  var root = document.documentElement;

  function storedTheme() {
    try { return localStorage.getItem(KEY); } catch (e) { return null; }
  }
  function saveTheme(t) {
    try { localStorage.setItem(KEY, t); } catch (e) { /* private mode: the toggle still works for this page */ }
  }
  var fromUrl = /[?&]theme=(light|dark)\b/.exec(location.search);
  var theme = fromUrl ? fromUrl[1] : (storedTheme() || 'light');
  root.setAttribute('data-theme', theme);

  function setTheme(t) {
    root.setAttribute('data-theme', t);
    saveTheme(t);
    document.querySelectorAll('[data-theme-toggle]').forEach(function (b) {
      // One fixed name ("Dark theme") and a pressed state: never a label that contradicts the state.
      b.setAttribute('aria-pressed', t === 'dark' ? 'true' : 'false');
      if (!b.hasAttribute('data-keep-label')) b.setAttribute('aria-label', 'Dark theme');
    });
  }

  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
  function icon(name) {
    var ns = 'http://www.w3.org/2000/svg';
    var s = document.createElementNS(ns, 'svg');
    s.setAttribute('class', 'icon');
    s.setAttribute('aria-hidden', 'true');
    var u = document.createElementNS(ns, 'use');
    u.setAttribute('href', '#i-' + name);
    s.appendChild(u);
    return s;
  }

  /* The four rules a writer sees, in the contract's order. */
  function ruleRows(res, touched) {
    var has = function (code) { return res.issues.some(function (i) { return i.code === code && !i.warning; }); };
    var lenBad = has('empty') || has('too-long');
    var idle = !touched && res.bytes === 0;   // an untouched empty box is neutral, not failed
    return [
      { ok: !lenBad, idle: idle, text: idle ? '1 to 280 bytes' : lenBad ? (res.bytes === 0 ? '1 to 280 bytes: write something' : '1 to 280 bytes: ' + res.bytes + ' now, cut ' + (res.bytes - 280)) : '1 to 280 bytes (' + res.bytes + ' used)' },
      { ok: !has('control'), idle: idle, text: 'One line, no control characters' },
      { ok: !has('refused') && !has('utf8'), idle: idle, text: 'No hidden characters (zero-width, direction marks, variation selectors)' },
      { ok: !has('marker'), idle: idle, text: 'No “[plea” or “[objection” markers, in any case' }
    ];
  }

  function row(list, cls, iconName, text) {
    var li = el('li', 'check ' + cls);
    li.appendChild(icon(iconName));
    li.appendChild(el('span', null, text));
    list.appendChild(li);
  }

  function wireTextCheck(input) {
    var mode = input.getAttribute('data-text-check');
    var counter = document.getElementById(input.getAttribute('data-counter'));
    var checks = document.getElementById(input.getAttribute('data-checks'));
    var reads = document.getElementById(input.getAttribute('data-reads'));
    var wrap = input.closest('.textarea, .input');
    var submit = input.getAttribute('data-submit') ? document.getElementById(input.getAttribute('data-submit')) : null;
    var current = input.getAttribute('data-current');   // name mode: the wallet's name now
    var touched = false;
    var lastSummary = null;
    // The visible list is not a live region (it would re-read every row on each key); one short
    // polite line announces only when the verdict of the checks changes.
    var live = null;
    if (checks) {
      checks.removeAttribute('aria-live');
      live = el('p', 'sr-only');
      live.setAttribute('aria-live', 'polite');
      checks.parentNode.insertBefore(live, checks.nextSibling);
    }
    function run() {
      var T = window.PleaText;
      if (!T) return;
      var v = input.value;
      var res = mode === 'letter' ? T.checkLetter(v) : mode === 'name' ? T.checkName(v) : mode === 'objection' ? T.checkObjection(v) : T.checkText(v);
      var isCurrent = mode === 'name' && current != null && v === current;
      var bad = !res.ok;
      var showBad = bad && (touched || v.length > 0);
      if (wrap) wrap.classList.toggle('is-invalid', showBad);
      input.setAttribute('aria-invalid', showBad ? 'true' : 'false');
      if (counter && mode !== 'name') {
        var n = res.bytes;
        counter.querySelector('[data-count]').textContent = n + ' / 280 bytes';
        var bar = counter.querySelector('.counter__meter > span');
        if (bar) bar.style.width = Math.min(100, n / 280 * 100) + '%';
        counter.classList.toggle('counter--over', n > 280);
      }
      var problems = res.issues.filter(function (i) { return !i.warning && i.code !== 'clear'; });
      if (checks) {
        checks.textContent = '';
        if (mode === 'name') {
          if (isCurrent) row(checks, 'check--ok', 'check', 'This is your current name.');
          else if (res.clears) row(checks, 'check--ok', 'info', 'An empty name clears your display name.');
          else if (res.ok) row(checks, 'check--ok', 'check', 'Fits the rules. Names are unique: the chain says if it is taken.');
          else problems.forEach(function (i) { row(checks, 'check--bad', 'x', i.message); });
        } else if (mode === 'letter' && (res.kind === 'name' || res.kind === 'clear-name')) {
          if (res.kind === 'clear-name') row(checks, 'check--ok', 'info', 'NAME alone clears your display name.');
          else if (res.ok) row(checks, 'check--ok', 'check', 'The name fits the rules (3 to 20 of a–z, 0–9, _).');
          else problems.forEach(function (i) { row(checks, 'check--bad', 'x', i.message); });
        } else if (mode === 'letter' && res.kind === 'sell') {
          row(checks, 'check--ok', 'check', 'SELL needs no text.');
          res.issues.forEach(function (i) { if (i.warning) row(checks, 'check--warn', 'warning', i.message); });
        } else {
          ruleRows(res, touched).forEach(function (r) {
            row(checks, r.idle ? 'check--idle' : r.ok ? 'check--ok' : 'check--bad', r.idle ? 'minus' : r.ok ? 'check' : 'x', r.text);
          });
          res.issues.forEach(function (i) {
            if (i.code === 'empty' || i.code === 'too-long') return;
            row(checks, i.warning ? 'check--warn' : 'check--bad', i.warning ? 'warning' : 'warning-circle', i.message);
          });
        }
      }
      if (live) {
        // Announce once per change of verdict: keyed on the problem codes, never on live numbers.
        var key = isCurrent ? 'current' : res.clears ? 'clears' : res.ok ? (v.length ? 'ok' : 'empty') : problems.map(function (i) { return i.code; }).join(',');
        if (!touched) lastSummary = key;
        else if (key !== lastSummary) {
          lastSummary = key;
          live.textContent = isCurrent ? 'This is your current name.' : res.clears ? 'An empty name clears your display name.' : res.ok ? (v.length ? 'Text passes the checks.' : '') : problems.length + (problems.length === 1 ? ' problem: ' : ' problems: ') + (problems[0] ? problems[0].message : '');
        }
      }
      if (reads && res.reads) reads.textContent = res.reads;
      if (submit) {
        var block = bad || isCurrent || (!v.length && mode !== 'name');
        if (block) submit.setAttribute('aria-disabled', 'true'); else submit.removeAttribute('aria-disabled');
      }
    }
    input.addEventListener('input', function () { touched = true; run(); });
    run();
  }

  function init() {
    setTheme(root.getAttribute('data-theme'));
    document.querySelectorAll('[data-theme-toggle]').forEach(function (b) {
      b.addEventListener('click', function () { setTheme(root.getAttribute('data-theme') === 'dark' ? 'light' : 'dark'); });
    });
    document.querySelectorAll('[data-menu-toggle]').forEach(function (b) {
      var d = document.getElementById(b.getAttribute('aria-controls'));
      function setOpen(open) {
        b.setAttribute('aria-expanded', open ? 'true' : 'false');   // the name stays "Menu"; expanded says the rest
        if (d) d.hidden = !open;
        var use = b.querySelector('use');
        if (use) use.setAttribute('href', open ? '#i-x' : '#i-list');
        if (open && d) { var first = d.querySelector('a, button'); if (first) first.focus(); }
      }
      b.addEventListener('click', function () { setOpen(b.getAttribute('aria-expanded') !== 'true'); });
      document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape' && b.getAttribute('aria-expanded') === 'true') {
          var inside = (d && d.contains(document.activeElement)) || document.activeElement === b;
          setOpen(false);
          if (inside) b.focus();
        }
      });
    });
    /* A click anywhere in an .input box focuses its field (the box is taller than the <input>). */
    document.addEventListener('click', function (e) {
      var w = e.target.closest && e.target.closest('.input');
      if (w && !e.target.closest('input, button, a, select')) { var c = w.querySelector('input'); if (c) c.focus(); }
    });
    /* Buttons marked aria-disabled do nothing (they stay focusable so the reason can be read). */
    document.addEventListener('click', function (e) {
      var d = e.target.closest && e.target.closest('[aria-disabled="true"]');
      if (d) { e.preventDefault(); e.stopPropagation(); }
    }, true);
    document.querySelectorAll('[data-text-check]').forEach(wireTextCheck);
    /* One polite status line for the page (copy confirmations). */
    var status = el('p', 'sr-only');
    status.setAttribute('role', 'status');
    document.body.appendChild(status);
    function announce(msg) { status.textContent = ''; setTimeout(function () { status.textContent = msg; }, 50); }
    document.querySelectorAll('[data-copy]').forEach(function (b) {
      b.addEventListener('click', function () {
        var text = b.getAttribute('data-copy');
        var label = b.getAttribute('aria-label');
        var done = function () {
          var old = b.lastChild.textContent;
          b.lastChild.textContent = 'Copied';
          if (label) b.setAttribute('aria-label', label.replace(/^Copy /, 'Copied: '));
          announce('Copied ' + (label ? label.replace(/^Copy /, '') : 'to the clipboard') + '.');
          setTimeout(function () { b.lastChild.textContent = old; if (label) b.setAttribute('aria-label', label); }, 1500);
        };
        if (navigator.clipboard) navigator.clipboard.writeText(text).then(done, function () { announce('Copy did not work here: select the text and copy it.'); }); else done();
      });
    });
    /* A table box is a tab stop and a region only while it actually scrolls sideways. */
    function syncScrollBoxes() {
      document.querySelectorAll('.table-wrap').forEach(function (w) {
        var scrolls = w.scrollWidth > w.clientWidth + 1;
        if (scrolls) { w.setAttribute('tabindex', '0'); w.setAttribute('role', 'region'); if (!w.getAttribute('aria-label') && w.dataset.label) w.setAttribute('aria-label', w.dataset.label); }
        else { if (w.getAttribute('aria-label')) w.dataset.label = w.getAttribute('aria-label'); w.removeAttribute('tabindex'); w.removeAttribute('role'); w.removeAttribute('aria-label'); }
      });
    }
    syncScrollBoxes();
    window.addEventListener('resize', syncScrollBoxes);
    document.querySelectorAll('[data-autosell]').forEach(function (box) {
      function sync() {
        document.querySelectorAll('[data-autosell-on]').forEach(function (e) { e.hidden = !box.checked; });
        document.querySelectorAll('[data-autosell-off]').forEach(function (e) { e.hidden = box.checked; });
      }
      box.addEventListener('change', sync);
      sync();
    });
    /* State switchers for the mockups: <button data-show="group:name"> shows [data-group=group][data-name=name]. */
    document.querySelectorAll('[data-show]').forEach(function (b) {
      b.addEventListener('click', function () {
        var parts = b.getAttribute('data-show').split(':');
        document.querySelectorAll('[data-group="' + parts[0] + '"]').forEach(function (e) { e.hidden = e.getAttribute('data-name') !== parts[1]; });
        document.querySelectorAll('[data-show^="' + parts[0] + ':"]').forEach(function (o) { o.setAttribute('aria-pressed', o === b ? 'true' : 'false'); });
      });
    });
    document.querySelectorAll('[data-replay-stamp]').forEach(function (b) {
      b.addEventListener('click', function () {
        var s = document.getElementById(b.getAttribute('data-replay-stamp'));
        if (!s) return;
        s.classList.remove('stamp--land');
        void s.offsetWidth;
        s.classList.add('stamp--land');
      });
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();
})();
