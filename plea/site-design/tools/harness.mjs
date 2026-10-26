// Shared Playwright harness for testing the PLEA site (default: the run 9 site, https://plea-test-run-9.sites.imd.fun/).
// SITE_URL=<url> tests another build (a local preview, a new label); RPC_HOSTS=<host,host> names the hosts
// whose JSON-RPC calls are answered from `fork` (default: the run 9 site's three Sepolia RPCs).
//
//   import { launch, openSite, forkTime, syncClock } from '<repo>/plea/site-design/tools/harness.mjs'
//   const browser = await launch()
//   const { page, wallet, log } = await openSite(browser, {
//     route: '#/buy', width: 1280, height: 900, theme: 'light',
//     fork: 'http://127.0.0.1:8545',            // optional: the site's Sepolia RPCs answer from this anvil fork
//     wallet: { address: '0x…', send: true },     // optional: an injected EIP-1193 / EIP-6963 wallet
//     clock: 1792600000,                         // optional: browser clock (unix seconds), e.g. await forkTime(fork)
//   })
//
// The wallet answers eth_accounts / eth_requestAccounts with `address` (connected: false starts it
// unauthorised, so eth_accounts is [] until the site asks with eth_requestAccounts: a first visit;
// by default the site reconnects by itself, as for a returning visitor), eth_chainId with its chain
// (default Sepolia 0xaa36a7; wallet.chainId to start elsewhere), handles wallet_switchEthereumChain /
// wallet_addEthereumChain, and forwards everything else to `wallet.rpc` (default: the fork). With
// send: true, eth_sendTransaction is forwarded to the fork as is: impersonate the address first
// (anvil_impersonateAccount) so anvil signs it. Without send (or without a fork) every send and every
// signature is refused with code 4001 (user rejected). wallet.calls lists every request; wallet.txs the
// sent transactions ({request, hash}). Only ever point `fork` / `wallet.rpc` at a local anvil.
//
// log.console / log.pageErrors / log.failed / log.requests collect what the page did.

const PW = process.env.PLAYWRIGHT || '/opt/node-tools/node_modules/playwright/index.mjs';
export const SITE = process.env.SITE_URL || 'https://plea-test-run-9.sites.imd.fun/';
export const RPC_HOSTS = process.env.RPC_HOSTS ? process.env.RPC_HOSTS.split(',') : ['ethereum-sepolia-rpc.publicnode.com', 'rpc.sepolia.ethpandaops.io', 'sepolia.rpc.sentio.xyz'];
const SEPOLIA = '0xaa36a7';

export async function launch(opts = {}) {
  const { chromium } = await import(PW);
  const proxy = process.env.HTTPS_PROXY ? { server: process.env.HTTPS_PROXY, bypass: '127.0.0.1,localhost' } : undefined;
  return chromium.launch({ proxy, ...opts });
}

export async function rpcCall(url, method, params = []) {
  const r = await fetch(url, { method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }) });
  const j = await r.json();
  if (j.error) { const e = new Error(j.error.message); e.code = j.error.code; e.data = j.error.data; throw e; }
  return j.result;
}

export async function forkTime(fork) {
  const b = await rpcCall(fork, 'eth_getBlockByNumber', ['latest', false]);
  return parseInt(b.timestamp, 16);
}

// Moves the page's clock to `unixSeconds` (after a fork warp, so countdowns match the chain).
export async function syncClock(page, unixSeconds) {
  await page.clock.setSystemTime(new Date(unixSeconds * 1000));
}

const CORS = { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': 'POST, GET, OPTIONS' };

export async function openSite(browser, o = {}) {
  const ctx = await browser.newContext({
    viewport: { width: o.width || 1280, height: o.height || 900 },
    reducedMotion: o.reducedMotion, colorScheme: o.colorScheme, deviceScaleFactor: o.dpr || 1,
  });
  const log = { console: [], pageErrors: [], failed: [], requests: [] };
  const page = await ctx.newPage();
  page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') log.console.push({ type: m.type(), text: m.text().slice(0, 500) }); });
  page.on('pageerror', e => log.pageErrors.push(String(e).slice(0, 500)));
  page.on('requestfailed', r => log.failed.push({ url: r.url().slice(0, 200), err: r.failure()?.errorText }));
  page.on('request', r => log.requests.push({ t: Date.now(), method: r.method(), host: new URL(r.url()).host, url: r.url().slice(0, 200) }));

  if (o.fork) {
    const fork = o.fork;
    await ctx.route(u => RPC_HOSTS.includes(new URL(u).host), async route => {
      const req = route.request();
      if (req.method() === 'OPTIONS') return route.fulfill({ status: 204, headers: CORS });
      try {
        const r = await fetch(fork, { method: 'POST', headers: { 'content-type': 'application/json' }, body: req.postData() || '' });
        return route.fulfill({ status: r.status, headers: { ...CORS, 'content-type': 'application/json' }, body: await r.text() });
      } catch (e) {
        return route.fulfill({ status: 502, headers: CORS, body: String(e) });
      }
    });
  }

  if (o.theme) await ctx.addInitScript(t => { try { localStorage.setItem('plea-theme', t); } catch {} }, o.theme);

  let wallet = null;
  if (o.wallet) {
    wallet = { address: o.wallet.address.toLowerCase(), chainId: o.wallet.chainId || SEPOLIA, calls: [], txs: [], added: [],
      send: !!o.wallet.send, rpc: o.wallet.rpc || o.fork, authorized: o.wallet.connected !== false };
    await ctx.exposeBinding('__pleaWallet', async (_src, method, params) => {
      wallet.calls.push({ method, params });
      const fail = (code, message) => ({ error: { code, message } });
      switch (method) {
        case 'eth_accounts': return { result: wallet.authorized ? [wallet.address] : [] };
        case 'eth_requestAccounts': wallet.authorized = true; return { result: [wallet.address] };
        case 'eth_chainId': return { result: wallet.chainId };
        case 'net_version': return { result: String(parseInt(wallet.chainId, 16)) };
        case 'wallet_switchEthereumChain': {
          const id = params?.[0]?.chainId?.toLowerCase();
          if (id !== SEPOLIA && !wallet.added.includes(id)) return fail(4902, 'Unrecognized chain ID');
          wallet.chainId = id; return { result: null, chainChanged: id };
        }
        case 'wallet_addEthereumChain': wallet.added.push(params?.[0]?.chainId?.toLowerCase()); wallet.addParams = params?.[0]; return { result: null };
        case 'wallet_requestPermissions': return { result: [{ parentCapability: 'eth_accounts' }] };
        case 'wallet_getPermissions': return { result: [{ parentCapability: 'eth_accounts' }] };
        case 'eth_sendTransaction': {
          if (!wallet.send || !wallet.rpc) return fail(4001, 'User rejected the request.');
          if (wallet.chainId !== SEPOLIA) return fail(4001, 'Wallet is on another chain');
          try { const hash = await rpcCall(wallet.rpc, method, params); wallet.txs.push({ request: params[0], hash }); return { result: hash }; }
          catch (e) { return { error: { code: e.code ?? -32000, message: e.message, data: e.data } }; }
        }
        case 'personal_sign': case 'eth_sign': case 'eth_signTypedData_v4': case 'eth_signTransaction':
          return fail(4001, 'User rejected the request.');
        default:
          if (!wallet.rpc) {
            // No fork: read from public Sepolia so the site behaves as with a real wallet.
            try { return { result: await rpcCall('https://' + RPC_HOSTS[0], method, params) }; }
            catch (e) { return { error: { code: e.code ?? -32000, message: e.message, data: e.data } }; }
          }
          try { return { result: await rpcCall(wallet.rpc, method, params) }; }
          catch (e) { return { error: { code: e.code ?? -32000, message: e.message, data: e.data } }; }
      }
    });
    await ctx.addInitScript(() => {
      const listeners = {};
      const emit = (ev, v) => (listeners[ev] || []).forEach(f => { try { f(v); } catch {} });
      const provider = {
        isMetaMask: false, isPleaTest: true,
        request: async ({ method, params }) => {
          const r = await window.__pleaWallet(method, params);
          if (r.error) { const e = new Error(r.error.message); e.code = r.error.code; e.data = r.error.data; throw e; }
          if (r.chainChanged) setTimeout(() => emit('chainChanged', r.chainChanged), 0);
          if (method === 'eth_requestAccounts') setTimeout(() => emit('accountsChanged', r.result), 0);
          return r.result;
        },
        on: (ev, f) => { (listeners[ev] ||= []).push(f); return provider; },
        removeListener: (ev, f) => { listeners[ev] = (listeners[ev] || []).filter(x => x !== f); return provider; },
      };
      window.ethereum = provider;
      const info = { uuid: '7d1f2c4e-0000-4000-8000-00000000plea'.slice(0, 36), name: 'PLEA Test Wallet', rdns: 'test.plea.wallet',
        icon: 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxIDEiPjxyZWN0IHdpZHRoPSIxIiBoZWlnaHQ9IjEiLz48L3N2Zz4=' };
      const announce = () => window.dispatchEvent(new CustomEvent('eip6963:announceProvider', { detail: Object.freeze({ info, provider }) }));
      window.addEventListener('eip6963:requestProvider', announce);
      announce();
    });
  }

  if (o.clock) { await page.clock.install({ time: new Date(o.clock * 1000) }); await page.clock.resume(); }
  if (o.route !== null) {
    await page.goto(SITE + (o.route || '#/'), { waitUntil: 'domcontentloaded', timeout: 90000 });
    await page.waitForLoadState('networkidle', { timeout: 30000 }).catch(() => {});
  }
  return { ctx, page, wallet, log };
}

// Runs axe-core (WCAG 2.1 AA) in the page; returns the violations.
export async function axe(page, axePath = process.env.AXE) {
  const fs = await import('node:fs');
  await page.addScriptTag({ content: fs.readFileSync(axePath, 'utf8') });
  return page.evaluate(async () => (await window.axe.run(document, { runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'] } }))
    .violations.map(v => ({ id: v.id, impact: v.impact, help: v.help, nodes: v.nodes.slice(0, 5).map(n => n.target.join(' ')) })));
}

// Sideways overflow: the document wider than the viewport, and the elements sticking out.
export async function overflow(page) {
  return page.evaluate(() => {
    const w = document.documentElement.clientWidth;
    const out = [];
    for (const el of document.querySelectorAll('body *')) {
      const r = el.getBoundingClientRect();
      if (r.width && (r.right > w + 1 || r.left < -1)) out.push((el.tagName + '.' + [...el.classList].join('.')).slice(0, 80) + ` ${Math.round(r.left)}..${Math.round(r.right)}`);
      if (out.length > 10) break;
    }
    return { scrollWidth: document.documentElement.scrollWidth, width: w, offenders: out };
  });
}
