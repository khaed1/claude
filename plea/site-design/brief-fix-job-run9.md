Fix the PLEA Sepolia test run 9 site (web/ in this repository, from your previous job at commit 520d734) as listed in one review file: github.com/khaed1/claude at commit 3eb565e0e4f39d1926250c6eadb2f7dbf235f852, plea/site-design/run9-site-review.md. Change no contracts.

The file has 73 fix items for 158 problems our testers found and a second reviewer confirmed, on forks of Sepolia and in a real browser. Each item says Now (route, state, web/src file:line), Should (the brief, a mockup or a contract) and Fix. Do them all: P1 first (19 items across sections T, C, S, X), then P2, then P3. Keep everything under "What works (keep it)" working. The brief (plea/site-design/brief-site-job-run9.md at the same commit) and the design system (plea/site-design/ at commit 91b34fe4b8e5: tokens.css, components.css, components.html, PAGE-KIT.md, pages/*.html with their "Design reference · other states" bands) still apply.

The P1 items in short:
- T1: the first buy after the seed gets no quote (float tick math in swap-math.ts), so Approve and Buy stay disabled for everyone. Port TickMath.getSqrtPriceAtTick exactly in bigint; never gate the approval on the quote.
- T2: the seed control only for PLEA.owner(), with plain words, then the opening buy (Decision D1).
- T3: partial fills. Price limit from the post-trade price, simulate before sending, report the real fill.
- T4: decode hook errors the PoolManager wraps (WrappedError) and map every custom error in the ABIs to plain words; check the launch cap before the approval.
- T5: fee rows with per-trade amounts, the launch-window fee, no prize share after the death.
- T6: after the death, Buy/Sell shows the dead-state rules.
- C1: a lapsed approval or an expired unanswered plea must not lock the seller out of Plead (CabalGate._clearStale); remove the "Mark plea lapsed" call to expire, which always reverts.
- C2: Sell now's default minimum from the live price, not the hourly checkpoint.
- C3: the auto-sell Plead checks the Letterbox's 0.70 floor and 10% fee rule before sending.
- C4: the automatic appeal's amount counts the escrow the Letterbox returns first.
- C5: no appeal box where no appeal is possible; the sale panel per state as in plea.html.
- C6: the meter follows the verdict. C7: a sold appeal is stamped OVERTURNED. C8: a VOID objection has no score; OVERRULED shows its points.
- S1: one season model (running, ended but not closed, dead) with each season's own pot (seasonFees, plus the rollover for the season that receives it). S2: the Seasons page as in seasons.html.
- X1: RPC timeouts and fallback (a hung first RPC leaves the site blank for minutes; the third RPC cannot serve it). X2: polling volume (about 260 eth_calls a minute on an idle page today). X3: the need marker overflows the page.

Decisions: D1 above. D2: remove the "Fund the buy wall" donation control and its PleaHook approval; keep Rebalance as a small public action with one plain sentence. D3: remove the Coinbase Wallet SDK connector (telemetry and a cookie on every page load); EIP-6963 and injected wallets stay.

QA before you finish: check every fix on a local fork of Sepolia (seed, buys, pleas with signed verdicts by setting the gate's and the Tribunal's oracle signer to a test key with anvil_setStorageAt on the fork only, appeals, objections, and time warps for the windows, the seasons and the death) in a real browser at 320, 360, 768 and 1280 px, light and dark, with and without a wallet; then the read-only parts against the live Sepolia contracts. No horizontal scroll, no console errors, no axe violations. Add unit tests for the tick math, the season pots and the appeal amount. Add FIXES.md listing each item ref, what you changed and how you checked it.
