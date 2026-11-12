# Security Review — PleaHook.sol (PLEA run 8.5)

**Prepared for:** job 1018, a follow-up security re-review of PLEA run 8.5's `PleaHook`, after job 1014 on the same code.

## Scope

| | |
|---|---|
| **Repo** | `https://github.com/khaed1/plea` |
| **Commit audited** | `af57f6df709acdf7fe754a58482ee35eef9e2178` (branch `testnet8.5`) — confirmed reachable: `git ls-remote` resolves it, and `git merge-base --is-ancestor` confirms it is an ancestor of `origin/testnet8.5` as of this audit |
| **Files in scope** | `src/PleaHook.sol` (871 nSLOC), `src/interfaces/IPleaParts.sol` (65 nSLOC), `src/interfaces/IStacker.sol` (5 nSLOC) — client-scoped; all other `src/` files are context only, per the job description |
| **Deployed (Sepolia)** | `PleaHook` at `0x48f607FbdBD955e283C57A28E57309b8Ec9028cC` |
| **Solidity / toolchain** | 0.8.26, `via_ir`, `cancun`, Foundry |
| **Prior rounds** | 8 rounds of AI-swarm + IMD launch audits (see `audit/FINDINGS.md`), plus One Dollar Audit job 1014 on this exact commit, judged by the client (`audit/FINDINGS.md`, ODA-1014-1 to -10) |

**Methodology:** x-ray pre-scan (entry-point/invariant extraction, done directly against the scoped files since `PleaHook.sol`'s only in-scope dependencies are the two interfaces) → context mapping (3 parallel opus agents: access-control inventory, protocol map, external-surface map) → breadth pass (6 parallel sonnet agents against ethskills checklists: general, precision-math, ERC20, defi-amm/v4-hooks, DoS, flashloans) → depth pass (12 parallel sonnet agents, pashov solidity-auditor V4, run blind to the breadth pass's findings, in 4 waves of 3) → hybrid reconciliation (this document). 18 hunting agents total, all independently reading the full scoped source.

**Severity counts:** 0 Critical · 0 High · 0 Medium · 4 Low · 9 Informational

---

## Part 1 — Verification of job 1014's three dismissed claims

The client asked us to check each resolution and say plainly if one is wrong. We re-derived all three independently (before any hunting agent ran) by reading the code directly, then cross-checked against this round's 18 agents, several of which re-examined the same mechanisms from different angles while blind to the prior round's conclusions.

### ODA-1014-1 (claimed High, dismissed) — undeliverable cashback joins the wall reserve

**Resolution: correct.** `_payCashback` (`PleaHook.sol:755-778`) falls back to `retainedImd += amount` (line 776) only when *both* `stacker.credit` reverts or is absent *and* the raw `imd.transfer` call fails or returns a falsy/malformed result. This requires IMD itself to refuse an ordinary transfer to a nonzero address. The client's on-chain read (mainnet IMD is a standard 18-decimal LayerZero OFT with no pause, blocklist, or transfer fee) is the only way to make that path unreachable, and nothing in the scoped files contradicts it. Re-confirmed independently by this round's ERC20-checklist agent (Phase 1) and the math-precision pashov agent (Phase 2).

### ODA-1014-2 (claimed Medium, dismissed) — opening-buy exception could reopen via pool drain

**Resolution: correct**, with one nuance this round surfaced and resolved. The `asClaims` test (`PleaHook.sol:605`) requires *both* `own < out` (the hook's own locally-tracked IMD — the market band, the wall band, and `retainClaims` — insufficient) *and* `imd.balanceOf(address(poolManager)) < out` (the PoolManager's real, global IMD balance across every pool it serves, insufficient). This round's dedicated flashloan-checklist agent (Phase 1) traced every writer of `market`, `wall`, and `retainClaims` and confirmed none of them can be moved by a router flash-taking the PoolManager's balance mid-unlock — a flash-take only affects the second (global-balance) half of the test, never the first. Two Phase 2 agents (defi-amm specialist, economic-security specialist) separately noted that the permissionless `rebalance()` moves value from `retainClaims` into `retainedImd`, which is *not* counted in `own` — in principle this lets `own` be nudged down over time. Both agents, and our own check, agree this still cannot stand alone: the outer gate (the PoolManager's real, global IMD balance) is what the client's own on-chain reading (259,490 IMD on Ethereum) makes impractical, and nothing in this round changes that balance. **No correction needed** — flagged only so the client sees the exact angle this round's agents pushed on before confirming it still holds.

### ODA-1014-3 (claimed Medium, dismissed) — `int128` fee cast can wrap

**Resolution: correct.** The wrap point is ~9.55 × 10²¹ IMD (human units), ~2.3 quadrillion times IMD's real supply (~4.17M). Re-derived independently this round by the precision-math (Phase 1) and math-precision (Phase 2) agents, and extended: the math-precision Phase 2 agent additionally checked the `int128` casts at lines 541, 544, 551 (not just the one originally flagged) and found the same supply-bound guarantee holds for all of them. Unreachable.

**Bottom line: all three of job 1014's resolutions hold.** This round found nothing that reopens them.

---

## Part 2 — Findings

### [LOW] Any caller can name an arbitrary third party as `trader` via `hookData`, corrupting that address's cost-basis record

**Location:** `PleaHook.sol:690-716` (`_resolveTrader`, `_validTrader`), `PleaHook.sol:728-747` (`_updateBasis`), called from `afterSwap` at `PleaHook.sol:562-564`

**Description:** `_resolveTrader` accepts any address decoded from caller-supplied `hookData` as "the trader," checking only that it isn't one of five protocol-internal addresses (`stacker`, `imd`, `simd`, `address(this)`, `poolManager`) or the caller itself when the caller has code (`_validTrader`, lines 710-716). Nothing ties the named address to who actually funded or received the trade. `afterSwap` then writes that unverified address into `basisOf` — inflating it on a buy, or draining/zeroing it on a sell (`_updateBasis`'s `else` branch, lines 740-747: `if (pleaMoved >= b.pleaHeld) { b.imdSpent = 0; b.pleaHeld = 0; b.avgBuyTime = 0; }`).

**Exploit path, walked to completion:** This surfaced independently in 8 of our 12 depth-pass agents (access-control, economic-security, execution-trace, first-principles, asymmetry, boundary, trust-gap, flow-gap specialists), which is why it gets a full writeup here despite the capped severity below. Three distinct sub-cases:

1. **Buy, Cabal alive — real PLEA is delivered to the named address.** This is the already-known and client-accepted finding R2-A3-2 ("a buy in another wallet's name moves that wallet's buy-weighted holding time… the gift is real and stays with the victim… accepted by the owner"). We re-derived it independently and confirm it is the same mechanism, not a new bug: `beforeSwap`'s sell-gate (`PleaHook.sol:453`) only restricts `sender`, not `trader`, and a buy while alive genuinely delivers PLEA to the named address (`poolManager.take(Currency.wrap(plea), trader, …)`, line 540) — so naming someone a gift that nudges their hold-time band downward is exactly what R2-A3-2 already accepted.
2. **Sell, Cabal alive.** Not reachable by an attacker: `beforeSwap` requires `sender == IPLEA(plea).gate()` for every sell while `_alive()` is true (`PleaHook.sol:453`), and `sender` is the real, PoolManager-verified direct caller — it cannot be spoofed via `hookData`. Only the trusted gate contract (out of scope, presumably naming the real approved seller) can initiate a sell in this state.
3. **Buy or sell, Cabal dead.** This is the new mechanism several agents traced concretely: once `_alive()` is false, any address can call `poolManager.swap()` directly (no `sender` restriction at all) and name an arbitrary victim via `hookData`. On a sell, the attacker sells *their own* PLEA while naming the victim — `_updateBasis` zeroes or drains the victim's record using the attacker's trade size, with no token movement from the victim. On a buy, the real PLEA the attacker paid for goes to the attacker via normal v4 delta settlement (post-death buys use "plain v4 accounting," `PleaHook.sol:544`) — only `basisOf` and the cashback stake are misdirected to the named victim, which is a pure gift from the attacker's own funds, not an extraction.

**Why this caps at Low, not Medium/High:** `basisOf` exists for one purpose — feeding the out-of-scope CabalGate's fact-score computation "at submit time" for an active plea (THREAT-MODEL.md invariant 3). New pleas can only be submitted while the Cabal is alive. Case 3 above is the only case with no real-token backing, and it is reachable *exclusively* once the Cabal is dead — the one state in which no future plea will ever read the corrupted record. Case 1 (the only case reachable while pleas still matter) is the already-accepted R2-A3-2. We could not construct a path where this issue causes financial harm beyond what R2-A3-2 already accepts, so despite the strong multi-agent convergence on the mechanism's existence, we are rating it Low: a real state-corruption primitive, confirmed reachable, with no demonstrated path to loss.

**Fix:** For defense-in-depth (not required given the above): attribute `basisOf` changes only to the address that actually settled the trade's input/output — `sender` itself, or the router's reported `msgSender()` — never an unrelated `hookData` address. If gifting-by-name is intended to stay (per R2-A3-2's acceptance), restrict it to the buy path only, since that is the one case where the named party actually receives the asset.

---

### [LOW] `rebalance()`'s wall-fill threshold can be bypassed into premature close-and-redeploy

**Location:** `PleaHook.sol:335-338` (`pendingRebalance`), `PleaHook.sol:879-884` (`_rebalance`)

**Description:** `pendingRebalance()` ORs three independent triggers: retained IMD/claims over `WALL_THRESHOLD` (1e18), wall fill over `WALL_MIN_FILL` (1,000e18), or nonzero `pleaClaims`. Inside `_rebalance()`, `_closeWall()` runs unconditionally whenever `wall.liquidity != 0` (line 883), with no re-check that the wall actually reached `WALL_MIN_FILL`. Any single trigger — including a trivial `fundWall(1e18)` donation by anyone — forces a full close-and-redeploy of an existing wall regardless of its fill level, defeating the purpose of a separate fill threshold.

**Exploit path:** A caller (no special privilege needed) calls `fundWall(1e18)` to push `retainedImd` over `WALL_THRESHOLD`, then calls `rebalance()`. If a wall currently exists with any nonzero liquidity (even well under `WALL_MIN_FILL`), it is closed and a new one is deployed. No funds are lost — `_closeWall` correctly rolls the wall's IMD back into `retainedImd` before redeploying (`PleaHook.sol:932-945`) — but the wall churns more often than its own fill gate was designed to allow, costing extra gas per redeploy and resetting the wall's guard-tracked state more often than intended.

**Fix:** Gate the `_closeWall()` call itself on `pleaInWall() >= WALL_MIN_FILL`, independent of which signal triggered `rebalance()`.

---

### [LOW] `pendingRebalance()`'s wall-fill signal is not monotonic and can be transiently front-run false

**Location:** `PleaHook.sol:325-338` (`pleaInWall`, `pendingRebalance`)

**Description:** Two of `pendingRebalance()`'s three OR conditions are monotonically non-decreasing outside `rebalance()` itself. The third, `pleaInWall() >= WALL_MIN_FILL`, is not — it reads how much PLEA the wall band currently holds at spot price, which falls when a buy pushes price back out of the wall's range. In the narrow state where the wall-fill signal is the *only* true trigger, a party watching the mempool can front-run a keeper's `rebalance()` call with a buy that pushes spot out of the wall's range, flipping `pendingRebalance()` false just before the keeper's transaction lands, forcing a revert.

**Exploit path:** Confirmed reachable, but self-limiting: the front-runner pays real swap fees (≥1.25% IMD-side plus the 0.25% PLEA burn) on both the push and any later reversal, and the window closes permanently the moment retained IMD/claims or PLEA claims cross their own always-sticky thresholds (which happens automatically as ordinary fee accrual continues). Impact is a delay to a no-payout permissionless housekeeping call, not a loss of funds.

**Fix:** No code change required given the self-healing property; optionally have keepers simulate before sending, as the client's own documentation already recommends for the separate "drained pool" case (THREAT-MODEL.md §3).

---

### [LOW] Multiple independent trust-boundary gaps around the Stacker, Seasons, and PLEA calls, all converging on the same root cause

**Location:** `PleaHook.sol:618` (`ISeasons(seasons).checkpoint()`), `PleaHook.sol:641-651` (`_burnPlea`'s `IPLEA(plea).burn()` call), `PleaHook.sol:755-778` (`_payCashback`'s `stacker.credit` call)

**Description:** Three of our 12 depth-pass agents (execution-trace, boundary, flow-gap) independently flagged the same underlying pattern from different angles: `_payCashback`'s call to `stacker.credit` is deliberately placed as the *last* step of `afterSwap`, with an explicit code comment explaining why ("pays every fee, applies the cap, then pays cashback as the very last step," `PleaHook.sol:486-488`). The calls to `ISeasons.checkpoint()` (line 618) and `IPLEA.burn()` (inside `_burnPlea`, called from `_payFees` before the cap/wall-guard/checkpoint updates run) receive no equivalent treatment — they are not wrapped in `try/catch`, and they execute before, not after, the rest of `afterSwap`'s bookkeeping. If either `Seasons` or `PLEA` (both out of scope, both named as trusted sibling contracts by the client) ever reverted unexpectedly or re-entered the pool, the asymmetry with the Stacker's deliberately-last, `try/catch`-wrapped call becomes meaningful: a revert in `Seasons.checkpoint()` blocks every trade that owes a prize fee, and a reentrant call from either could in principle let a nested swap's own hourly checkpoint write win the "first trade of the hour" slot ahead of the outer swap's.

**Why this is Low, not higher:** every path requires a trusted, out-of-scope sibling contract (`Seasons` or `PLEA`) to misbehave — the same trust boundary the client has already accepted for `IPLEA(plea).restricted()`/`launcher()`/`gate()` elsewhere in the same file. We could not inspect `Seasons.sol` or `PLEA.sol` to confirm or rule out a revert/reentry path, so this is reported as a hardening gap, not a demonstrated exploit.

**Fix:** Either confirm (from `Seasons.sol`/`PLEA.sol`, out of scope here) that `checkpoint()` and `burn()` cannot revert or reenter under any reachable condition, or apply the same `try/catch` and end-of-function placement already used for the Stacker call.

---

### [INFORMATIONAL] Three independent agents flagged the Stacker's `credit()` call for not reconciling a partial pull

**Location:** `PleaHook.sol:755-778` (`_payCashback`)

**Description:** `_payCashback` increments `totalCashback` by the full `amount` immediately after a non-reverting `stacker.credit(trader, amount)` call, without checking how much IMD the Stacker actually pulled via the `amount`-sized approval. The code's own comment ("the allowance is per credit: nothing stays approved after a credit that pulled less") shows the author anticipated a partial pull is possible. If the Stacker pulled less than `amount`, the unpulled IMD remains in the hook's balance with no accounting variable tracking it as recoverable, while `totalCashback` and the `CashbackStacked` event both overstate what was actually staked.

**Impact:** Bounded and non-exploitable by an outside party — it requires the trusted, immutable Stacker itself to under-pull, which is the same trust boundary already accepted for the rest of the Stacker integration. No funds are lost (the IMD stays in the hook, available to future `fundWall`-style accounting), only the reported totals could drift from reality over time.

**Fix:** Measure `imd.balanceOf(address(this))` before and after the `credit` call and reconcile `totalCashback`/`retainedImd` against the actual delta, rather than assuming the full approved amount was pulled.

---

### [INFORMATIONAL] Hourly price checkpoint can be set by a trade that precedes the hour boundary — already documented and accepted; one proposed defeat of the acceptance does not hold

**Location:** `PleaHook.sol:1054-1064` (`_checkpoint`)

**Description:** `_checkpoint` writes the ring buffer's slot for an hour using the price *before* the first trade of that hour (`priceBefore`, captured in `beforeSwap`'s transient storage) — i.e., whatever price the *previous* hour's last trade left behind. This is the client's own documented, accepted behavior: THREAT-MODEL.md §3 states plainly, "a pump placed as the last trade before the hour boundary becomes the reference for the next hour's pleas (the pumper keeps PLEA it cannot sell and worsens its own P&L band; at most the trend band moves)."

One of this round's breadth-pass agents proposed that a flash loan could defeat the stated economic brake ("the pumper keeps PLEA it cannot sell") by reversing the pumped position atomically, removing the holding-period cost that makes the accepted behavior self-limiting. **We traced this construction and it does not work:** `block.timestamp` (and therefore the `hour` computed from it, `PleaHook.sol:1055`) is constant for every call within a single transaction. A checkpoint write only occurs on the *first* trade to touch a given hour's ring slot (`if (c.hour != hour)`, line 1057); any later trade in the *same* transaction necessarily shares the same `hour` value as the first, so it cannot be "the first trade of the next hour" relative to an earlier trade in that same transaction. Crossing the hour boundary requires waiting for a later block with a later timestamp — which a same-transaction flash loan, by construction, cannot do. The pumped position must therefore be held across at least one real block boundary, exactly as the client's existing acceptance assumes.

**Fix:** None required. This is already-accepted behavior, correctly reasoned by the client, and the one proposed defeat of that reasoning does not survive construction.

---

### [INFORMATIONAL] `IPLEA.restricted()` is read independently three times per swap with no caching

**Location:** `PleaHook.sol:452` (`beforeSwap`), `PleaHook.sol:538` (`afterSwap`, via `_alive()`), `PleaHook.sol:598` (`afterSwap`, via `_alive()`)

**Description:** `_alive()` wraps a single external view call (`IPLEA(plea).restricted()`) with no memoization; `beforeSwap` and `afterSwap` each call it independently, and `afterSwap` calls it twice. This exact pattern was previously raised and dismissed (ODA-1014-6: "the Cabal's liveness is read separately in beforeSwap and afterSwap… noted: cabalAlive cannot change within a transaction; no exploit"). One of this round's agents raised a sharper version: an external call (`IPLEA(plea).burn()`, inside `_burnPlea`) sits between the second and third reads. We examined this and found no plausible mechanism: `burn()` only reduces the hook's own PLEA balance and has no documented or structural tie to the Cabal's liveness flag, which is a separate, independent piece of PLEA's state. We are not aware of a way for burning tokens to flip a liveness flag, and no scoped code suggests one.

**Fix:** None required beyond what ODA-1014-6 already covers; optionally cache the read once per call for clarity, though this carries no security benefit we can identify.

---

### [INFORMATIONAL] Fixed 30,000-gas stipend for a router's `msgSender()` probe has no fallback if a router needs more

**Location:** `PleaHook.sol:96` (`MSG_SENDER_GAS`), `PleaHook.sol:702-707` (`_resolveTrader`)

**Description:** `_resolveTrader`'s router-probe branch uses a hardcoded 30,000-gas stipend. A router whose `msgSender()` implementation costs more (e.g., a proxy with a `delegatecall`, or a non-trivial storage read) would see the staticcall run out of gas, which `_resolveTrader` treats identically to "no trader" (falls through to `address(0)`). While the Cabal is alive, this makes every buy through such a router revert with `RecipientRequired` (`PleaHook.sol:463`); after the Cabal dies, it instead silently drops cashback and basis tracking for that router's users with no revert or signal.

**Impact:** An availability/correctness issue tied entirely to future or third-party router implementations, not an attacker-profitable path — we could not identify any way a caller benefits from triggering this themselves, since it only degrades their own trade's bookkeeping. Also noted: the high-level Solidity staticcall at this site copies the full return buffer into memory before the length check runs, so a router could spend its 30,000 gas budget mostly on returning a large blob, forcing an expensive memory-copy on the *caller's own* transaction — self-inflicted, not a third-party griefing vector, since `sender` here is always the direct caller's own choice of router.

**Fix:** Either raise the stipend with margin validated against real router implementations, or cap the copy with a raw `staticcall` + bounded `returndatacopy` instead of the high-level call.

---

### [INFORMATIONAL] `_liquidityForSingleSide`'s rounding margin can be exactly zero for sub-1e6 amounts — examined across three independent passes, not reachable in practice

**Location:** `PleaHook.sol:1081` (`l = l - l / 1_000_000;`)

**Description:** The 1-part-per-million margin truncates to exactly 0 for any computed liquidity under 1,000,000 raw units, which is theoretically possible for very small `retainedImd` amounts passed into wall redeployment via `_rebalance`. One of our breadth-pass agents flagged this as a potential Low (a transient DoS on `rebalance()` if the margin's absence ever let `imdReq` exceed `amount`). Two of our depth-pass agents independently re-examined it: one concluded the production code paths (seed's full-supply deposit, and `WALL_THRESHOLD`-gated wall redeployment) never actually reach the danger zone; the other ran exact-arithmetic simulations replicating Solidity's real `FullMath.mulDiv`/`SqrtPriceMath` rounding semantics, sweeping `amount` from 1 wei to 2,000e18 against both production tick-range configurations, and found the required amount never exceeds the available amount at any tested scale, with or without the margin.

**Fix:** None required — the weight of evidence (two independent dismissals, one by direct simulation against the real rounding semantics) outweighs the single theoretical concern. We note it here rather than silently dropping it, consistent with the audit's own "no silent drops" standard.

---

### [INFORMATIONAL] `rebalance()`'s claim redemption can silently no-op while still reporting `acted = true`

**Location:** `PleaHook.sol:641-651` (`_burnPlea`), `PleaHook.sol:856-863` (`_rebalance`)

**Description:** `_rebalance` zeroes `pleaClaims`, burns the matching ERC-6909 claim, then calls `_burnPlea(owed)` to complete the burn. If the PoolManager still holds less PLEA than `owed` at that second check, `_burnPlea` simply re-mints the same claim amount back into `pleaClaims` — the burn-then-remint cancels out, no PLEA is actually destroyed, yet `acted = true` is set unconditionally on line 862 regardless of whether this step did anything.

**Impact:** No fund loss — the claim amount is unchanged, just not yet redeemed. The only effect is that `rebalance()` reports success for a call that accomplished nothing on this component, and the caller pays two extra external calls (burn + mint) for zero effect. `pendingRebalance()` continues to correctly report `true` until the PoolManager genuinely holds enough PLEA.

**Fix:** Have `_burnPlea` return whether it actually burned, and only set `acted = true` for this component when it did.

---

### [INFORMATIONAL] `fundWall` does not verify the actual IMD amount received before crediting `retainedImd`

**Location:** `PleaHook.sol:948-951`

**Description:** `fundWall` credits the caller-supplied `amount` to `retainedImd` without measuring `imd.balanceOf(address(this))` before/after the transfer. This duplicates the already-accepted trust assumption behind ODA-1014-8/-9 (no defense against a non-standard, fee-charging, or rebasing IMD) — accepted because the client has read IMD on-chain as a standard, fee-free, non-rebasing token. Also noted: `fundWall` is the one value-moving helper in the file without an `amount == 0` early return (every sibling helper — `_settleImd`, `_payImd`, `_burnPlea`, `_payCashback` — has one), which would only matter if IMD ever reverted on a zero-amount transfer, which it does not per the accepted token model.

**Fix:** None required given the accepted IMD model; for consistency, an `if (amount == 0) return;` guard would match the rest of the file's style.

---

### [INFORMATIONAL] `IPLEA.burn()` has no return value; `totalBurned` trusts the call succeeded without measuring the effect

**Location:** `PleaHook.sol:416-417` (`seed`), `PleaHook.sol:647-650` (`_burnPlea`)

**Description:** Both call sites increment `totalBurned` unconditionally after a non-reverting `IPLEA(plea).burn(amount)` call, with no `balanceOf` check confirming the supply/balance actually decreased by `amount`. This is a direct consequence of trusting the out-of-scope PLEA contract's `burn()` to either genuinely burn or revert — the same class of trust assumption as the rest of the IPLEA interface calls in this file (`restricted()`, `launcher()`, `gate()`).

**Fix:** None required given PLEA is treated as a trusted sibling contract throughout; optional defense-in-depth would measure the balance delta instead of trusting the requested amount.

---

## Coverage

**Entry points:** 8 external/public state-changing functions in `PleaHook.sol` (`seed`, `beforeInitialize`, `beforeAddLiquidity`, `beforeSwap`, `afterSwap`, `rebalance`, `fundWall`, `unlockCallback`) — all 8 appear in the Phase 0 access-control inventory and all 8 map to at least one threat-catalog row or an explicit "examined, no issue" note above.

**Threat catalog:** every row from the Phase 0 protocol map (router/caller abuse of `beforeSwap`/`afterSwap`, trader-identity spoofing, gate-impersonation, `rebalance`/`fundWall` griefing, overflow at extreme size, Stacker reentry, timing-based cap/guard nudging, launcher-trust at `seed`) is answered above — either by a finding, by a dismissal with reasoning, or by the ODA-1014 re-verification in Part 1.

**Invariants (x-ray-lite catalog):** all inferred single-contract and cross-contract invariants (I-1 through I-8, X-1, X-2, E-1, E-2) from the Phase 0 invariant map were re-examined by the depth-pass agents; the two explicitly flagged open questions (does `_burnPlea`'s self-re-entry from `_rebalance` ever re-mint instead of burn; can `wallImd` desync from the wall's real liquidity) were both answered during this round — the first is the "silent no-op" finding above (confirmed real but harmless), the second was not found to occur in any traced path (every `_closeWall`/redeploy sequence we and the agents traced keeps `wallImd` and `wall.liquidity` written together).

**Coverage: 8 entrypoints, 8 addressed. 9 threat-catalog rows, 9 answered. 10 inferred invariants, 10 answered (8 hold, 1 confirmed-but-harmless gap, 1 not reproduced). Holes closed this pass: 2** (the `_burnPlea` re-entry question and the `wallImd` desync question, both open at the end of Phase 0, both resolved during Phase 2).

---

## Disclaimer

This review was performed by an AI-orchestrated multi-agent audit (18 independent hunting agents across two methodologies, plus human-equivalent reconciliation). AI analysis can never verify the complete absence of vulnerabilities and no guarantee of security is given. This is a re-review of code that has already been through 8 rounds of professional audit and one prior independent AI audit (job 1014) on this exact commit — the absence of new High/Critical findings here is consistent with, not a substitute for, that accumulated scrutiny. Team security review, bug bounty programs, and on-chain monitoring remain strongly recommended, particularly around the mainnet launch's changed parameters (14,000 IMD opening market cap, 15-day seasons, IMD-funded oracle fees).

---

## Session check (2026-10-17 ~14:50 UTC, against `testnet8.5` @ `af57f6d`; the hook on `next` / `mainnet` differs only by the 1% owner fee)

Report: IPFS `bafkreicgcyql5psn36p6dyc5yhpndwypdudpjxp23dr6emufoz3ohzzg2a`, html https://leftclaw.services/result/1018.html (job started 11:38, completed 14:33 UTC). The header says 9 Informational; the report describes 8, so 12 findings in all.

**Part 1 (our ODA-1014 resolutions): all three upheld.** ODA-1014-1 (the undeliverable cashback), ODA-1014-2 (the opening exception) and ODA-1014-3 (the `int128` casts, now checked at every cast site) are confirmed as we judged them. Its note that `rebalance` moves claims into the wall reserve, outside the hook's "own IMD" measure, does not reopen ODA-1014-2: the claims path also needs the PoolManager itself to hold less IMD than one buy's payouts (259,490 IMD on Ethereum).

**L-1 (`hookData` names any wallet as the trader). The reachable part is harmless; the wording of invariant 22 is the issue.**
- While the Cabal lives: a buy in another wallet's name is the accepted R2-A3-2 (the PLEA goes to that wallet), and only the gate can sell (`SellsOnlyViaGate`), naming the real seller.
- After the death: any swap may name any wallet, so a sale can reset another wallet's cost-basis record. Nothing reads it any more: `basisOf` feeds only `CabalGate._factScoreAt`, and every plea path (`submitSell`, `submitFor`, `appeal`, `appealFor`) reverts `CabalNotWatching` once the Cabal is dead, which is for good. The named wallet also gets that swap's cashback, a gift from the attacker.
- Invariant 22 says the record is "reduced only by final sales"; true while the Cabal lives, not after.
- **Proposed:** reword invariant 22; no code change.

**L-2 (`rebalance` re-places a wall that is not yet filled). By design.** Every `rebalance` settles the wall and redeploys all retained IMD as one band just below the price (its NatSpec). The fill threshold is one of three triggers, not a gate on closing. Forcing an early re-place costs the caller a real `fundWall` donation plus gas; no value moves, and the placement guard is updated on every swap anyway. Gating the close on the fill would leave new IMD outside the wall. **Noted.**

**L-3 (a buy can turn the wall-fill signal of `pendingRebalance()` off before a keeper's call lands). Real, self-limiting.** The front-runner pays the swap fees, the other two signals only grow, and a keeper that simulates first loses nothing. **Proposed:** add it to THREAT-MODEL §3's "`pendingRebalance()` is a hint" line.

**L-4 (`Seasons.checkpoint()` and `PLEA.burn()` are called without `try`, before the rest of `afterSwap`). Not reachable.** Both are our committed code, read here (not in their scope):
- `Seasons.checkpoint()` only reads balances (`pot()`: IMD plus the PoolManager claim) and the gate's clock. It makes no external write, no unlock and no call back into the hook. Its subtraction holds because every IMD that leaves Seasons lowers `accountedPot` by as much (`closeSeason`, `flushToWall`).
- `PLEA.burn()` burns the hook's own PLEA, just taken from the PoolManager. The hook is an exempt sender, and the only external call is the gate's `restricted()` view.
- **Noted.**

**Infos:**
- I-1 (the Stacker could pull less than the cashback): **not reachable.** The imd/acc Stacker's verified source (Sourcify full match, mainnet `0x0690…f4f0` and Sepolia `0x0457…314d`): `credit` does `IMD.safeTransferFrom(msg.sender, this, imdAmount)` then `SIMD.deposit(imdAmount, trader)`, or reverts.
- I-2 (the hourly checkpoint): the accepted behaviour; their own check confirms a flash loan cannot defeat it.
- I-3: the same as ODA-1014-6.
- I-4 (the 30,000-gas `msgSender()` probe): `hookData` comes first and our site always sets it; the known routers' `msgSender()` is a storage read.
- I-5 (the zero liquidity margin): they found it unreachable.
- I-6 (a `rebalance` whose only work is PLEA claims can no-op): real. While the PoolManager holds less PLEA than `pleaClaims` (a nearly bought-out market after the death), `_burnPlea` re-mints the claim and the call still succeeds. Nothing is lost; the keeper bot must check that `pleaClaims` fell, not only that the call did not revert. **Proposed:** the same §3 line.
- I-7 (`fundWall`): standard IMD.
- I-8 (`PLEA.burn` returns nothing): our own OpenZeppelin `_burn`, which reverts on a short balance.

**Recommendation:** no code change (the hook keeps its 174 spare bytes). Reword invariant 22 (the record is the seller's own while the Cabal lives; after the death it is display only) and extend the §3 keeper-hint line (L-3, I-6). Record ODA-1018-1 to -12: L-1 "documented", L-3 and I-6 "documented", the rest "noted".
