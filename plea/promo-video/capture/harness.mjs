// Capture harness: the run 9 site as it looked at a past Sepolia block.
//
// Each moment runs a local anvil fork of Sepolia at block N (--no-mining, so the
// chain head stays at N). Playwright answers every JSON-RPC POST the page sends to
// a Sepolia RPC host from that anvil; the site's own files and api.imd.fun stay live.
// The page clock is fixed to the moment so countdowns read as they did then.
// Read-only: nothing is ever sent to a real network and there is no key anywhere.

import { chromium } from '/opt/node-tools/node_modules/playwright/index.mjs';
import { spawn, execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

export const SITE = 'https://plea-test-run-9.sites.imd.fun/';
// Archive RPC for the fork: it must serve old state and 10,000-block eth_getLogs
// (the site scans its events in 10k chunks). ethpandaops and tenderly do; drpc
// (free plan) and sentio (1,000 blocks) do not; publicnode has no old state.
export const ARCHIVE_RPCS = process.env.ARCHIVE_RPC ? [process.env.ARCHIVE_RPC] : ['https://rpc.sepolia.ethpandaops.io', 'https://sepolia.gateway.tenderly.co'];
export const ARCHIVE_RPC = ARCHIVE_RPCS[0];
// Every Sepolia RPC the site may call (imd-deployment.json network.rpcUrls), plus
// a few common ones in case the fallback list changes.
export const RPC_HOSTS = new Set([
  'ethereum-sepolia-rpc.publicnode.com',
  'rpc.sepolia.ethpandaops.io',
  'sepolia.rpc.sentio.xyz',
  'rpc.sentio.xyz',
  'sepolia.drpc.org',
  'sepolia.gateway.tenderly.co',
  'rpc.sepolia.org',
  'rpc2.sepolia.org',
  '1rpc.io',
]);
const BIN = '/root/.local/bin';

// Hide only transient focus styles (applied right before each screenshot).
const NO_FOCUS_CSS = '*:focus,*:focus-visible{outline:none!important;box-shadow:none!important}';
// Anything the site shows while data is still on its way.
const LOADING_SELECTOR = '.skeleton, .share-skeleton, .loading-wall, .toast--pending';
// What the site shows when an RPC call failed (the site's RPC timeout is 6 s).
const RPC_ERROR_TEXT = /Can.t reach Sepolia|public RPC did not answer|could not be read completely/i;

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Block timestamp (seconds) from the archive RPC. */
export function blockTimestamp(n) {
  let last;
  for (const url of ARCHIVE_RPCS) {
    try { return Number(execFileSync(`${BIN}/cast`, ['block', String(n), '-f', 'timestamp', '--rpc-url', url]).toString().trim()); }
    catch (e) { last = e; }
  }
  throw last;
}

const anvils = new Set();
/**
 * Start anvil forked at `block`; resolves once it answers. Returns { url, block, stop }.
 * Tries each archive RPC in turn, twice (a public RPC sometimes answers with an error page).
 */
export async function startAnvil(block, port) {
  let last;
  for (let attempt = 0; attempt < ARCHIVE_RPCS.length * 2; attempt++) {
    const forkUrl = ARCHIVE_RPCS[attempt % ARCHIVE_RPCS.length];
    try {
      return await startAnvilOnce(block, port, forkUrl);
    } catch (e) {
      last = e;
      console.log(`  anvil on ${forkUrl} failed (${String(e.message).split('\n')[0].slice(0, 120)}); retrying`);
      await sleep(3000);
    }
  }
  throw last;
}

async function startAnvilOnce(block, port, forkUrl) {
  const proc = spawn(`${BIN}/anvil`, [
    '--fork-url', forkUrl,
    '--fork-block-number', String(block),
    '--port', String(port),
    '--no-mining',
    '--silent',
  ], { stdio: ['ignore', 'ignore', 'pipe'] });
  let stderr = '';
  proc.stderr.on('data', (d) => { stderr += d; });
  const url = `http://127.0.0.1:${port}`;
  // SIGTERM lets anvil write its fork cache (~/.foundry/cache/rpc), so a rerun at
  // the same block starts warm; SIGKILL if it does not exit.
  const stop = async () => {
    anvils.delete(stop);
    if (proc.exitCode !== null) return;
    proc.kill('SIGTERM');
    for (let i = 0; i < 40 && proc.exitCode === null; i++) await sleep(250);
    if (proc.exitCode === null) proc.kill('SIGKILL');
  };
  anvils.add(stop);
  for (let i = 0; i < 120; i++) {
    if (proc.exitCode !== null) throw new Error(`anvil exited: ${stderr}`);
    try {
      const head = await rpc(url, 'eth_blockNumber', []);
      if (BigInt(head) !== BigInt(block)) { await stop(); throw new Error(`anvil head ${head} != ${block}`); }
      return { url, block, forkUrl, stop };
    } catch (e) {
      if (String(e.message).startsWith('anvil head')) throw e;
      await sleep(500);
    }
  }
  await stop();
  throw new Error(`anvil did not start on ${port}: ${stderr}`);
}
/**
 * The site's clock is the chain head's timestamp plus the local time since it last
 * read the head (and it re-reads the head every 60 s), not Date.now() alone. So a
 * fork whose head stays at N shows N's time whatever the page clock says. To show a
 * moment `t` seconds after N, mine one empty local block stamped `t`: the state is
 * N's (no transactions), only the head's number (N+1, local) and time move.
 */
export async function stampHead(anvil, t) {
  const head = await rpc(anvil.url, 'eth_getBlockByNumber', ['latest', false]);
  if (t <= Number(head.timestamp)) return { number: Number(head.number), timestamp: Number(head.timestamp), mined: false };
  await rpc(anvil.url, 'evm_mine', [t]);
  const b = await rpc(anvil.url, 'eth_getBlockByNumber', ['latest', false]);
  if (Number(b.timestamp) !== t || b.transactions.length) throw new Error(`stamped head is ${Number(b.timestamp)} with ${b.transactions.length} txs`);
  return { number: Number(b.number), timestamp: t, mined: true };
}

/** Stop every anvil this process started. */
export async function stopAllAnvils() {
  await Promise.all([...anvils].map((s) => s()));
}

async function rpc(url, method, params) {
  const r = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }),
  });
  const j = await r.json();
  if (j.error) throw Object.assign(new Error(j.error.message), { code: j.error.code, data: j.error.data });
  return j.result;
}

let browser;
export async function getBrowser() {
  browser ??= await chromium.launch({ proxy: { server: process.env.HTTPS_PROXY } });
  return browser;
}
export async function closeBrowser() {
  if (browser) await browser.close();
  browser = undefined;
}

// EIP-1193 provider injected before the site loads (announced by EIP-6963 and set as
// window.ethereum). Like a real wallet it exposes no account until the site asks
// (eth_requestAccounts), unless autoConnect. Reads go to anvil through an exposed
// binding; signing and sending are always refused.
function walletInitScript({ address, autoConnect }) {
  const addr = address;
  let connected = !!autoConnect;
  const listeners = {};
  const emit = (ev, v) => (listeners[ev] || []).forEach((f) => { try { f(v); } catch {} });
  const refuse = (msg) => Object.assign(new Error(msg), { code: 4001 });
  const grant = () => {
    if (!connected) { connected = true; setTimeout(() => { emit('connect', { chainId: '0xaa36a7' }); emit('accountsChanged', [addr]); }); }
    return [addr];
  };
  const provider = {
    async request({ method, params }) {
      switch (method) {
        case 'eth_accounts':
          return connected ? [addr] : [];
        case 'eth_requestAccounts':
          return grant();
        case 'eth_coinbase':
          return connected ? addr : null;
        case 'eth_chainId':
          return '0xaa36a7';
        case 'net_version':
          return '11155111';
        case 'wallet_requestPermissions':
          grant();
          return [{ parentCapability: 'eth_accounts', caveats: [{ type: 'restrictReturnedAccounts', value: [addr] }] }];
        case 'wallet_getPermissions':
          return connected ? [{ parentCapability: 'eth_accounts', caveats: [{ type: 'restrictReturnedAccounts', value: [addr] }] }] : [];
        case 'wallet_revokePermissions':
          connected = false;
          setTimeout(() => emit('accountsChanged', []));
          return null;
        case 'wallet_switchEthereumChain':
        case 'wallet_addEthereumChain':
        case 'wallet_watchAsset':
          return null;
        case 'wallet_getCapabilities':
          return {};
        case 'eth_sendTransaction':
        case 'eth_sendRawTransaction':
        case 'eth_sign':
        case 'personal_sign':
        case 'eth_signTransaction':
        case 'eth_signTypedData':
        case 'eth_signTypedData_v3':
        case 'eth_signTypedData_v4':
        case 'wallet_sendCalls':
          throw refuse('Capture wallet: signing is disabled.');
        default:
          if (method.startsWith('wallet_')) return null;
          return window.__pleaAnvilRpc(method, params || []);
      }
    },
    on(ev, fn) { (listeners[ev] ||= []).push(fn); return provider; },
    removeListener(ev, fn) { listeners[ev] = (listeners[ev] || []).filter((f) => f !== fn); return provider; },
    off(ev, fn) { return provider.removeListener(ev, fn); },
  };
  const icon = 'data:image/svg+xml;base64,' + btoa('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" rx="6" fill="#121212"/><rect x="7" y="10" width="18" height="13" rx="3" fill="none" stroke="#FFD92E" stroke-width="2.5"/><circle cx="21" cy="16.5" r="1.8" fill="#FFD92E"/></svg>');
  const info = { uuid: '4f7c6a1e-1b7e-4b8e-9d1a-9e1f0c9a6b01', name: 'Browser Wallet', icon, rdns: 'fun.imd.capture' };
  const announce = () => window.dispatchEvent(new CustomEvent('eip6963:announceProvider', { detail: Object.freeze({ info, provider }) }));
  window.addEventListener('eip6963:requestProvider', announce);
  announce();
  window.ethereum = provider;
}

/**
 * Open the site at `route` (hash route like '#/plead') in a fresh browser context.
 * opts: { anvil, clockMs, wallet, autoConnect, theme: 'light'|'dark', live }
 *   anvil       — from startAnvil(); omit with live:true to use the real chain
 *   clockMs     — fixed Date.now() for the page (timers keep running)
 *   wallet      — address exposed through the injected provider (omit for none)
 *   autoConnect — expose the account without a connect click (warm-up passes)
 *   trace       — optional (requestBody, responseBody, ms) callback per routed RPC call
 * Returns { context, page, log, close }; log has the RPC count, slowest RPC (ms),
 * console errors, page errors and any JSON-RPC POST that escaped the routing.
 */
export async function openSite(route, opts = {}) {
  const { anvil, clockMs, wallet, autoConnect = false, theme = 'light', live = false } = opts;
  if (!live && !anvil) throw new Error('openSite needs an anvil fork (or live: true)');
  const b = await getBrowser();
  const context = await b.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 2,
    colorScheme: theme,
    locale: 'en-US',
    timezoneId: 'UTC',
  });
  const page = await context.newPage();
  const log = { console: [], pageErrors: [], rpc: 0, slowestMs: 0, rpcHosts: new Set(), unrouted: [] };
  page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') log.console.push(`${m.type()}: ${m.text()}`); });
  page.on('pageerror', (e) => log.pageErrors.push(String(e)));

  await context.addInitScript((t) => { try { localStorage.setItem('plea-theme', t); } catch {} }, theme);

  if (!live) {
    // Every POST to a Sepolia RPC host is answered by the fork, body forwarded as is
    // (batch requests stay batches).
    await context.route((url) => RPC_HOSTS.has(url.hostname), async (route) => {
      const req = route.request();
      const cors = { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': 'POST, OPTIONS' };
      if (req.method() === 'OPTIONS') return route.fulfill({ status: 204, headers: cors });
      if (req.method() !== 'POST') return route.fulfill({ status: 405, headers: cors, body: 'capture: only POST is forwarded' });
      log.rpc++; log.rpcHosts.add(new URL(req.url()).hostname);
      const t0 = Date.now();
      try {
        const r = await fetch(anvil.url, { method: 'POST', headers: { 'content-type': 'application/json' }, body: req.postData() });
        const body = await r.text();
        const ms = Date.now() - t0;
        log.slowestMs = Math.max(log.slowestMs, ms);
        opts.trace?.(req.postData(), body, ms);
        await route.fulfill({ status: r.status, headers: { ...cors, 'content-type': 'application/json' }, body });
      } catch (e) {
        log.slowestMs = Math.max(log.slowestMs, Date.now() - t0);
        await route.fulfill({ status: 502, headers: cors, body: String(e) }).catch(() => {});
      }
    });
    // Safety net: note any other JSON-RPC-looking POST that escaped the routing.
    page.on('request', (req) => {
      if (req.method() === 'POST' && !RPC_HOSTS.has(new URL(req.url()).hostname) && /"jsonrpc"/.test(req.postData() || '')) log.unrouted.push(req.url());
    });
  }

  if (wallet) {
    if (live) throw new Error('wallet injection is only for forks');
    await context.exposeBinding('__pleaAnvilRpc', async (_src, method, params) => {
      const t0 = Date.now();
      try { return await rpc(anvil.url, method, params); }
      finally { log.slowestMs = Math.max(log.slowestMs, Date.now() - t0); }
    });
    await context.addInitScript(walletInitScript, { address: wallet, autoConnect });
  }

  if (clockMs !== undefined) await page.clock.setFixedTime(new Date(clockMs));

  await page.goto(SITE + route, { waitUntil: 'domcontentloaded' });
  return { context, page, log, close: () => context.close() };
}

/** True when the page shows the site's RPC error (a call timed out or failed). */
export async function hasRpcError(page) {
  const text = await page.evaluate(() => document.body.innerText);
  return RPC_ERROR_TEXT.test(text);
}

/**
 * Wait until no loading UI is shown and fonts/images are done, stable for `stableMs`.
 * `ready` (optional) is a function evaluated in the page that must also return true.
 */
export async function settle(page, { timeout = 120_000, stableMs = 2500, ready } = {}) {
  const t0 = Date.now();
  let okSince = 0;
  while (Date.now() - t0 < timeout) {
    const ok = await page.evaluate(({ sel, readySrc }) => {
      if (!document.querySelector('#root')?.children.length) return false;
      if (document.querySelector(sel)) return false;
      if (document.fonts.status !== 'loaded') return false;
      if ([...document.images].some((i) => !i.complete)) return false;
      // Loading lines: "Reading the plea…", "Reading your fact score." and the like.
      const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
      for (let n = walker.nextNode(); n; n = walker.nextNode()) {
        const s = n.textContent.trim();
        if (/^(Reading|Loading)\b/.test(s) && s.length < 120 && n.parentElement?.offsetParent !== null) return false;
      }
      // eslint-disable-next-line no-new-func
      return readySrc ? !!new Function(`return (${readySrc})()`)() : true;
    }, { sel: LOADING_SELECTOR, readySrc: ready ? String(ready) : '' });
    if (ok) { okSince ||= Date.now(); if (Date.now() - okSince >= stableMs) return true; }
    else okSince = 0;
    await sleep(250);
  }
  throw new Error('page did not settle (loading UI still shown)');
}

/**
 * Warm anvil's state cache for a page: load it (wallet pre-connected) until a load
 * shows no RPC error and no call took longer than `fastMs`. The site gives up on an
 * RPC call after 6 s, and a cold fork needs 10-20 s for some calls, so the real
 * capture only runs once the fork answers from cache. `act(page)` can drive the
 * page further (e.g. type an amount) so those calls are warmed too; `ready` is the
 * page-specific check passed to settle().
 */
export async function warm(route, opts, { passes = 8, fastMs = 2500, act, ready } = {}) {
  for (let i = 1; i <= passes; i++) {
    const s = await openSite(route, { ...opts, autoConnect: true });
    try {
      const settled = await settle(s.page, { timeout: 90_000, stableMs: 2000, ready }).then(() => true, () => false);
      if (act) await act(s.page).catch(() => {});
      await sleep(1000);
      const bad = await hasRpcError(s.page);
      console.log(`  warm ${route} pass ${i}: ${s.log.rpc} rpc, slowest ${s.log.slowestMs} ms${bad ? ', RPC error shown' : ''}${settled ? '' : ', not settled'}`);
      if (settled && !bad && s.log.rpc > 0 && s.log.slowestMs < fastMs) return;
    } finally {
      await s.close();
    }
  }
  console.log(`  warm ${route}: still slow after ${passes} passes`);
}

/** Inject the no-focus style, blur the focused element, then screenshot. */
export async function shoot(page, file, { fullPage = false, blur = true } = {}) {
  await page.evaluate((css) => {
    if (!document.getElementById('capture-nofocus')) {
      const s = document.createElement('style');
      s.id = 'capture-nofocus';
      s.textContent = css;
      document.head.appendChild(s);
    }
  }, NO_FOCUS_CSS);
  if (blur) await page.evaluate(() => document.activeElement?.blur?.());
  await page.screenshot({ path: file, fullPage, animations: 'disabled', caret: 'hide' });
}

/** Viewport + full-page pair: <dir>/<name>.png and <dir>/<name>-full.png. */
export async function shootPair(page, dir, name) {
  mkdirSync(dir, { recursive: true });
  await shoot(page, join(dir, `${name}.png`));
  await shoot(page, join(dir, `${name}-full.png`), { fullPage: true });
}

/** Connect the injected wallet through the site's own Connect button and chooser. */
export async function connectWallet(page, address) {
  await page.locator('.wallet-btn').filter({ hasText: /^\s*Connect\s*$/ }).first().click();
  const choice = page.getByRole('button', { name: /Browser Wallet/i }).first();
  await choice.waitFor({ timeout: 15_000 });
  await choice.click();
  const short = new RegExp(address.slice(2, 6), 'i');
  await page.locator('.wallet-btn').filter({ hasText: short }).first().waitFor({ timeout: 20_000 });
}

export function writeJson(file, obj) {
  writeFileSync(file, JSON.stringify(obj, null, 2) + '\n');
}
