# Testing the PLEA site on a Sepolia fork (run 9)

How to see a site build working against run 9's real contracts on a local fork, with any court state you need. Nothing here touches a public chain: every write goes to a local anvil.

## 1. A base state (once)

```sh
plea/site-design/tools/fork-base.sh <port> <scratch>/base
```

Forks Sepolia at block 11,962,600 (before run 9's seed) from `rpc.sepolia.ethpandaops.io` (an archive node, so the fork never decays; publicnode prunes after ~25 minutes), then through `plea/tools/live85.py` (`FORK=1`): `fork-init` (the gate's and the Tribunal's `oracleSigner` = a test key, wallet A and IMD's writer impersonated), the seed by wallet A, A's 2 imdTEST opening buy, players p1..p8 (throwaway keys in `<scratch>/base/state/players.env`), 1 ETH + 10 imdTEST each, every approval, a distributor root (2.5M PLEA to each player, 20M to A, all claimed: "received PLEA" with no buy record), a warp past the 90-minute launch window, 1.25 imdTEST buys by p1..p4 (a buy record), and an IMD seat (test NFT) for p5. It writes `base.hex` (anvil state), `base.env` (`BASE_BLOCK`, `BASE_TIME`) and `state/`. About 3 minutes.

## 2. Your own fork from it

```sh
plea/site-design/tools/fork-load.sh <port> <scratch>/base/base.hex     # prints the anvil pid
cp -r <scratch>/base/state <your dir>/state                              # your own copy (log.jsonl, tree.json)
export RPC=http://127.0.0.1:<port> FORK=1 STATE_DIR=<your dir>/state ADDRS=plea/live-run9/addresses.json
python3 -I plea/tools/live85.py fork-init     # once per fresh fork: re-impersonates A and the writer
```

Use your own port for every anvil and every web server (two testers run at once). Save a moment with `anvil_dumpState` (fork-load.sh's header) and reload it with fork-load.sh. Stop only your own anvil: `for p in $(pgrep -x anvil); do grep -q <port> /proc/$p/cmdline && kill $p; done` (never `pkill -f` with a pattern your own command line contains).

## 3. Court actions (live85.py, on the fork)

`submit p1 100000 "text"` (hand plea: 0.5 imdTEST fee), `plead p1 100000 "text"` (the site's auto-sell box), `letter p3 "text"` / `letter p3 "APPEAL text"` / `letter p3 "NAME lynx_judge"` (raw letter), `appeal p1 <orig> <amount> "text"`, `appeal-auto`, `fork-answer plea <id> <score>` (a signed verdict), `fork-answer objection <id> <score>`, `fork-fail plea|objection <id> 1|2` (refused / no answer), `fork-warp <seconds>`, `sell p1`, `deliver p2 <id>`, `settle`, `expire`, `object p3 <id> "text"`, `texpire`, `tsettle`, `record p1 <id>`, `close a <season ids…>`, `rebalance`, `buy p6 3`, `sell-free p1` (after the death), `plea <id>`, `objection <id>`, `board`, `state`. Numbers: need = 71 − fact score; approved at score ≥ need; the sell window 7 minutes; objections 20 minutes; the cooldown and the appeal window 4 hours; a pending request expires after 20 minutes; seasons 5 hours from the seed; the Cabal dies 33 hours after the last verdict.

## 4. The site against your fork

Build a working copy of `khaed1/plea-site` and serve its export:

```sh
npm --prefix web ci && npm --prefix web run build
python3 -m http.server <web port> --bind 127.0.0.1 --directory dist &
```

Then drive it with `plea/site-design/tools/harness.mjs` (Playwright, Chromium preinstalled):

```js
import { launch, openSite, forkTime, syncClock, axe, overflow } from '/home/user/claude/plea/site-design/tools/harness.mjs'
// SITE_URL=http://127.0.0.1:<web port>/ in the environment
const fork = 'http://127.0.0.1:<port>'
const browser = await launch()
const { page, wallet, log } = await openSite(browser, {
  route: '#/p/1', width: 360, theme: 'dark', fork, clock: await forkTime(fork), oracle: true,
  wallet: { address: p1, send: true },   // impersonate first: cast rpc anvil_impersonateAccount <p1> --rpc-url $RPC
})
```

`oracle: true` answers `api.imd.fun/oracle/requests/<id>` (a fork verdict has no real IMD request behind it; pass `{agreed, panelSize, comment}` to vary it). After `fork-warp`, call `syncClock(page, await forkTime(fork))` so countdowns match the chain. The wallet signs nothing itself: with `send: true` it forwards `eth_sendTransaction` to the fork, which needs the address impersonated. axe-core: `npm install axe-core` in a scratch folder and pass `AXE=<that>/node_modules/axe-core/axe.min.js`. `log.console`, `log.pageErrors`, `log.failed` and `log.requests` record what the page did (polling volume: count `log.requests` by host over a minute).
