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
      b.setAttribute('aria-pressed', t === 'dark' ? 'true' : 'false');
      b.setAttribute('aria-label', t === 'dark' ? 'Switch to light theme' : 'Switch to dark theme');
      var use = b.querySelector('use');
      if (use) use.setAttribute('href', t === 'dark' ? '#i-sun' : '#i-moon');
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
  function ruleRows(res) {
    var has = function (code) { return res.issues.some(function (i) { return i.code === code && !i.warning; }); };
    var lenBad = has('empty') || has('too-long');
    return [
      { ok: !lenBad, text: lenBad ? (res.bytes === 0 ? '1 to 280 bytes: write something' : '1 to 280 bytes: ' + res.bytes + ' now, cut ' + (res.bytes - 280)) : '1 to 280 bytes (' + res.bytes + ' used)' },
      { ok: !has('control'), text: 'One line, no control characters' },
      { ok: !has('refused') && !has('utf8'), text: 'No hidden characters (zero-width, direction marks, variation selectors)' },
      { ok: !has('marker'), text: 'No “[plea” or “[objection” markers, in any case' }
    ];
  }

  function wireTextCheck(input) {
    var mode = input.getAttribute('data-text-check');
    var counter = document.getElementById(input.getAttribute('data-counter'));
    var checks = document.getElementById(input.getAttribute('data-checks'));
    var reads = document.getElementById(input.getAttribute('data-reads'));
    var wrap = input.closest('.textarea, .input');
    var submit = input.getAttribute('data-submit') ? document.getElementById(input.getAttribute('data-submit')) : null;
    function run() {
      var T = window.PleaText;
      if (!T) return;
      var v = input.value;
      var res = mode === 'letter' ? T.checkLetter(v) : mode === 'name' ? T.checkName(v) : mode === 'objection' ? T.checkObjection(v) : T.checkText(v);
      if (mode === 'name') {
        res.bytes = T.byteLength(v);
      }
      var bad = !res.ok;
      if (wrap) wrap.classList.toggle('is-invalid', bad && v.length > 0);
      input.setAttribute('aria-invalid', bad && v.length > 0 ? 'true' : 'false');
      if (counter && mode !== 'name') {
        var n = res.bytes;
        counter.querySelector('[data-count]').textContent = n + ' / 280 bytes';
        var bar = counter.querySelector('.counter__meter > span');
        if (bar) bar.style.width = Math.min(100, n / 280 * 100) + '%';
        counter.classList.toggle('counter--over', n > 280);
      }
      if (checks) {
        checks.textContent = '';
        if (mode === 'name') {
          (res.issues.length ? res.issues : [{ message: 'Looks good. Names are unique: the chain says if it is taken.' }]).forEach(function (i) {
            var li = el('li', 'check ' + (res.ok ? 'check--ok' : 'check--bad'));
            li.appendChild(icon(res.ok ? 'check' : 'x'));
            li.appendChild(el('span', null, i.message));
            checks.appendChild(li);
          });
        } else {
          var bodyRes = res;
          ruleRows(bodyRes).forEach(function (r) {
            var li = el('li', 'check ' + (r.ok ? 'check--ok' : 'check--bad'));
            li.appendChild(icon(r.ok ? 'check' : 'x'));
            li.appendChild(el('span', null, r.text));
            checks.appendChild(li);
          });
          res.issues.forEach(function (i) {
            if (i.code === 'empty' || i.code === 'too-long') return;
            var li = el('li', 'check ' + (i.warning ? 'check--warn' : 'check--bad'));
            li.appendChild(icon(i.warning ? 'warning' : 'warning-circle'));
            li.appendChild(el('span', null, i.message));
            checks.appendChild(li);
          });
        }
      }
      if (reads && res.reads) reads.textContent = res.reads;
      if (submit) {
        if (bad) submit.setAttribute('aria-disabled', 'true'); else submit.removeAttribute('aria-disabled');
      }
    }
    input.addEventListener('input', run);
    run();
  }

  function init() {
    setTheme(root.getAttribute('data-theme'));
    document.querySelectorAll('[data-theme-toggle]').forEach(function (b) {
      b.addEventListener('click', function () { setTheme(root.getAttribute('data-theme') === 'dark' ? 'light' : 'dark'); });
    });
    document.querySelectorAll('[data-menu-toggle]').forEach(function (b) {
      var d = document.getElementById(b.getAttribute('aria-controls'));
      b.addEventListener('click', function () {
        var open = b.getAttribute('aria-expanded') === 'true';
        b.setAttribute('aria-expanded', open ? 'false' : 'true');
        if (d) d.hidden = open;
        var use = b.querySelector('use');
        if (use) use.setAttribute('href', open ? '#i-list' : '#i-x');
      });
    });
    document.querySelectorAll('[data-text-check]').forEach(wireTextCheck);
    document.querySelectorAll('[data-copy]').forEach(function (b) {
      b.addEventListener('click', function () {
        var text = b.getAttribute('data-copy');
        var done = function () { var old = b.lastChild.textContent; b.lastChild.textContent = 'Copied'; setTimeout(function () { b.lastChild.textContent = old; }, 1500); };
        if (navigator.clipboard) navigator.clipboard.writeText(text).then(done, function () {}); else done();
      });
    });
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
