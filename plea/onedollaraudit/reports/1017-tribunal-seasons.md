# Security Review — Tribunal & Seasons (PLEA run 8.5)

**Repo:** https://github.com/khaed1/plea @ commit `af57f6df709acdf7fe754a58482ee35eef9e2178` (branch `testnet8.5`) — verified reachable on the remote via `git ls-remote`.

**On-chain:** Tribunal `0x5b3aB1f9A461995f342e1aD7124B974FD52739F1`, Seasons `0x331ba80c6f8bad20d73fd30256006a6671813227`, both on Sepolia (deployed 2026-10-16, not seeded at time of review).

**Scope (per client instruction — audited files only):**
- `src/Tribunal.sol` (561 lines, 447 nSLOC per client)
- `src/Seasons.sol` (467 lines, 339 nSLOC per client)
- `src/interfaces/IPleaParts.sol`

All other `src/` files (`CabalGate.sol`, `PLEA.sol`, `PleaLaunch.sol`, `PleaHook.sol`, `OracleAttestation.sol`, `Letterbox.sol`, `OracleAttestation.sol`) were read only as context for how they interact with Tribunal/Seasons — no findings are filed against them.

**Methodology:** Four-phase independent review — context/protocol mapping (3 parallel agents), breadth checklist pass (7 ethskills domain agents: general, precision-math, access-control, signatures/EIP-712, oracle-integration, dos, governance-pattern), depth attack-hunt (12 pashov-methodology agents across math-precision, access-control, economic-security, execution-trace, invariants, periphery, first-principles, asymmetry, boundary, and three cross-lens gap-hunters), then hybrid reconciliation against the client's own `THREAT-MODEL.md` and `FINDINGS.md` (fetched at commit `54da76be64c6f01764e27e6cc5b65811475d5e77`) to exclude anything already fixed or accepted by design. This is a fresh, independent run against this job's own scope (Tribunal/Seasons) — a companion job (PleaHook.sol) was audited separately and independently in this same session; nothing from that run was reused here. Several findings below were independently reached by 2–4 of the 22 total agents in this run, noted as a confidence signal.

**Severity counts:** 0 Critical · 1 High · 3 Medium · 3 Low · 6 Informational

---

## Findings

### [H-1] Five return-data decodes in Seasons revert outside the caller's own safety check, defeating the contract's documented "can never block a record or a close" guarantee

**Severity:** High

**Locations:**
- `_standing()` — `Seasons.sol:237-244` (decode at `L243`)
- `_tribunal()` — `Seasons.sol:246-252` (decode at `L251`)
- `_owners()` — `Seasons.sol:422-430` (decode at `L428`)
- `_pay()` — `Seasons.sol:463-466` (decode at `L465`)
- `_payBonus()` — `Seasons.sol:440-460` (decode at `L447`)

**Description.** Each of these five functions follows the pattern `staticcall/call → check ok && length → abi.decode(ret, (...))`. We empirically confirmed (a forge test run by one of the depth agents against solc 0.8.26) that Solidity's `abi.decode` performs type-canonicality validation — a `bool` word must be exactly `0` or `1`; a `uint8` word must have zero high bits; an `address` word must have zero padding in its upper 12 bytes — **inside the decode call itself**, which executes in the *caller's own frame*, strictly *after* the `ok`/`length` guard has already passed. None of the five `ok &&`-style guards catch this: a target that returns a successful, correctly-*sized* but non-canonically-*encoded* word makes the decode itself revert, uncaught.

This directly contradicts the code's own documented design intent:
```solidity
// Seasons.sol:234-236
// Read, never trust: a launcher without `tribunal()` or no Tribunal deployed means
// today's behaviour, and a Tribunal that reverts can never block a record or a close.
```
```solidity
// Seasons.sol:426
// Read, never trust: a hook without `owner()` must not be able to block a record or a close.
```
```solidity
// Seasons.sol:462
// A transfer that fails (a blocked recipient) leaves the share in the pot.
```
Each comment accounts for *revert* and *wrong length* — none accounts for *malformed-but-successful* return data, which is exactly what a non-canonical word is.

**Blast radius differs by site, and so does current reachability:**

1. **`_standing`/`_tribunal`/`_owners` (3 sites).** `_standing` is called with no try/catch from `record()` (`L228`) and `_tryRecord()` (`L403`) — a trip here reverts *every* `record()` call, permanently. `_owners`/`_excluded` is additionally called from `_dropOwner()` (unconditional inside `closeSeason`, `L411`) and from `Tribunal.object()`/`standing()` via `seasons.excluded(...)` — so this also bricks Tribunal's objection path. **Reachability today:** `plea.launcher()` and `plea.hook()` are one-time-set addresses (`PLEA.sol`'s `AlreadySet` guards) pointing at the committed Tribunal/PleaHook, whose `tribunal()`/`owner()` are plain Solidity auto-getters that always produce canonical output — **not reachable under the intended deployment**, only if that wiring is ever violated by a future redeploy or an out-of-scope bug.
2. **`_pay`/`_payBonus` (2 sites).** These decode the *protocol's own* `imd`/`plea` tokens' `transfer()` return value, not a launcher/hook-controlled address. `closeSeason()` closes seasons **strictly in order** (`nextToClose` only advances on a successful return), and the same top-25 list + amounts reproduce the identical revert on every retry — so if this is ever triggered (e.g. by a future token upgrade returning a "truthy-but-non-canonical" word for one single recipient), it **permanently and irrecoverably freezes every future season close**, with no admin override and no alternate path (`flushToWall` itself requires `finished()`, which requires `nextToClose` to have advanced through every season). **Reachability today:** not reachable with `imd`/`plea` behaving as standard, OZ-style ERC-20s, which is the expectation for both tokens in this ecosystem.

Separately, and compounding the same pattern: three of these four staticcall sites (`_standing`, `_tribunal`, `_owners`) forward **all remaining gas** with no cap — contrast `holdsSeat()` (`Seasons.sol:139-144`), which explicitly caps its own staticcall at `SEAT_READ_GAS = 100,000` specifically so "a read that fails or runs out means no multiplier" rather than blocking. The uncapped three carry the identical "can never block" promise with no equivalent defense: a gas-heavy `tribunal()`/`launcher()`/`owner()` implementation could consume the remaining transaction gas and OOG-revert `record()`/`closeSeason()`, which the invariant's own "gas-hungry... can never block" language explicitly promises will not happen. And even the one *capped* site, `holdsSeat`, only bounds the callee's own execution — Solidity still copies the full returned payload into caller memory before the length check runs, so a seat-NFT contract can use its 100k-gas budget to expand a ~200 KB return buffer, forcing a comparable memory-expansion cost onto every caller of `record()`/`closeSeason()` in addition to the capped 100k.

**Fix.** Replace `abi.decode` on all five sites with manual byte-level extraction (e.g. `uint256(bytes32(ret)) != 0` for a bool, treating any nonzero word as true without the strict validator; explicit range/zero-padding checks for `uint8`/`address`) so a malformed-but-successful response degrades to the intended safe-default/fail-open behavior instead of reverting. Add an explicit `{gas: 100_000}`-style stipend to the three currently-uncapped staticcalls, matching `holdsSeat`'s own pattern, and bound the copied returndata size (e.g. via an assembly `returndatacopy` limited to the expected word count) rather than relying on the gas cap alone.

---

### [M-1] `imd` is wired independently into CabalGate/Seasons versus PleaLaunch/Tribunal with no on-chain cross-check, unlike the existing `oracleAsset` cross-check

**Severity:** Medium

**Locations:** `Seasons.pot()` (`Seasons.sol:169-173`, reads Seasons' own `imd`), `Tribunal.settle()` (`Tribunal.sol:372-381`, pays in Tribunal's own `imd`), `Tribunal`'s constructor (`Tribunal.sol:165-179`, reads `imd` from `ITribunalLaunch(msg.sender).imd()` i.e. `PleaLaunch.imd`), `PleaLaunch`'s constructor (`PleaLaunch.sol:85-126`)

**Description.** `CabalGate`, `Seasons`, and `PleaLaunch` (and through it, `Tribunal`) each take their own `imd` address as an **independent constructor parameter**, with **no on-chain check that they agree**. The codebase already recognizes this exact class of risk and has a working pattern for it: `PleaLaunch`'s constructor explicitly cross-checks `oracleAsset_` against the gate's own view —

```solidity
// PleaLaunch.sol:119
if (IGate(gate_).oracleAsset() != oracleAsset_) revert OracleAssetMismatch();
```

— but applies **no equivalent check** for `imd_`, even though `CabalGate.imd` is a public immutable getter (`CabalGate.sol:141`) that `PleaLaunch` could read and compare just as easily, and `Seasons` is also constructed with its own independent `imd_` parameter before `PleaLaunch` is ever deployed (confirmed: `PleaLaunch`'s constructor takes `seasons_` as an address, meaning Seasons is deployed first).

**Concrete path.** A deploy-script error supplies `CabalGate`/`Seasons` with `imd = TOKEN_A` but `PleaLaunch` (and therefore `Tribunal`, which reads `ITribunalLaunch(msg.sender).imd()` at construction) with `imd = TOKEN_B`. An objection is filed and ruled Overruled; `Tribunal.settle(id)` sends `STAKE` in `TOKEN_B` to `address(seasons)` (`Tribunal.sol:378`), then calls `seasons.checkpointObjection(pleaId, STAKE)` (`L379`). Inside, `Seasons.pot()` reads `imd.balanceOf(address(this))` where Seasons' `imd = TOKEN_A` — a balance that never moved. The funding check `pot() - accountedPot < amount` (`Seasons.sol:199`) is therefore true, and `checkpointObjection` reverts `UnfundedStake()`, which propagates out and reverts the whole `settle()` call — including the `TOKEN_B` transfer that already ran in the same call frame. **Every future `settle()` call for *any* Overruled objection now reverts identically**, and the already-sent `STAKE` sits stranded in Tribunal's `TOKEN_B` balance, permanently invisible to Seasons' accounting, with no sweep function anywhere to recover it (see L-2).

**Fix.** Have `PleaLaunch`'s constructor additionally require `CabalGate(gate_).imd() == imd_` and `Seasons(seasons_).imd() == imd_`, mirroring the existing `oracleAsset` cross-check at `PleaLaunch.sol:119`.

---

### [M-2] `expire()` may be able to race the Intake's own ruling delivery, letting either party force a Void outcome instead of an unfavorable Sustain/Overrule

**Severity:** Medium (confidence is conditional on the real IdentityMD Intake's internal sequencing, which is not in this repo and could not be independently verified)

**Location:** `_stale()` — `Tribunal.sol:403-407`; `expire()` — `Tribunal.sol:363-368`; `onOracleResult`'s `Pending` guard — `Tribunal.sol:315`

**Description.** `_stale()` treats a pending objection as void-eligible under an **OR** of two conditions: either 20 minutes have elapsed since filing, **or** `intake.requests(o.intakeId).completed == true`. `expire(id)` is fully permissionless and, once `_stale()` is true, immediately sets `Ruling.Void` — after which a genuinely-delivered ruling for the same id reverts (`TooLate`/`NotPending`) and is discarded; there is no un-void path.

Per the Intake's own interface comment (`IPleaParts.sol`), `completed` is "set on every completion, answered or not," with no on-chain guarantee that this flag is set *atomically with* (rather than *before*) the actual callback delivery. If the real Intake exposes a window where `completed` reads true before `onOracleResult`/`onObjectionFailure` is actually invoked — and the project's own in-repo test mock does exactly this, per the context-building pass's review of `test/utils/Mocks.sol` — then `intake.requests(id).completed` is a public, externally observable flag that either interested party can race against:

- If a **Sustain** is about to land (the plea would earn zero points this season), the **seller** benefits from calling `expire()` first to force Void instead — the plea keeps its points.
- If an **Overrule** is about to land (the objector's stake would go to the season pot via `settle()`'s `Overruled` routing), the **objector** benefits from forcing Void instead — they get the stake back directly.

**Fix.** Do not treat `completed` alone as sufficient grounds for `expire()`: either drop that clause and rely purely on the 20-minute `filedAt` clock, add a short grace delay after `completed` first reads true before `expire()` honors it, or obtain and document a hard guarantee from the real Intake that `completed` is only ever set atomically with (or strictly after) the terminal callback attempt within the same transaction.

**Note:** this is distinct from, though adjacent to, the already-accepted `L85-I-1` (missing `requestId`/`questionHash` binding) — that finding is about *answer-to-wrong-question* risk; this one is about *timing of the `completed` flag* and does not depend on the binding gap at all.

---

### [L-1] `objectionOfIntake[rid]` is overwritten with no zero-check, which would silently cross-wire two rulings if the Intake ever returned a duplicate request id

**Severity:** Low

**Location:** `object()` — `Tribunal.sol:302-303`; `onOracleResult()`/`onObjectionFailure()`'s lookup — `Tribunal.sol:312, 354`

**Description.** `object()` writes `objectionOfIntake[rid] = id` unconditionally, with no check that the slot was previously empty. If the Intake ever returned the same `rid` for two different `object()` calls — not expected under honest operation, since request ids are described as effectively-unique, but not defended against on this side either — the second write silently overwrites the first, and `onOracleResult`/`onObjectionFailure` would thereafter apply whichever attestation the Intake sends for that `rid` to the **second** objection's id, regardless of which objection it was actually computed for. There is no secondary binding (no `questionHash` check) that would catch this — the `intakeId → id` mapping is the only link, and it is entirely Intake-controlled.

**Fix.** Revert in `object()` if `objectionOfIntake[rid] != 0` before writing, as cheap insurance for a trust assumption the contract otherwise takes entirely on faith.

---

### [L-2] No sweep or rescue path exists in Tribunal for any IMD/oracleAsset balance that isn't tied to a live, trackable objection

**Severity:** Low

**Location:** Whole file (`Tribunal.sol`) — no such function exists

**Description.** Tribunal is deliberately ownerless with no admin/pause/rescue path. Every *legitimate* objection stake is eventually resolvable: `expire()`'s 20-minute clock is independent of the Intake's liveness, so a hung request never permanently traps a stake. However, there is genuinely no way to recover any `imd`/`oracleAsset` balance that ends up in the contract **outside** that accounting — a direct mistaken transfer, rounding dust, or (per M-1) a stake stranded by an `imd` wiring mismatch. `settle()` only ever moves exactly `STAKE` for one specific, already-ruled `id`; nothing else touches the token balances.

**Fix.** Accept as a design tradeoff for a deliberately ownerless contract, or add a narrowly-scoped, permissionless sweep of `balance − outstanding-liabilities` into the Seasons prize pot.

---

### [L-3] `closeSeason` can be finalized with an incomplete `pleaIds` array, permanently forfeiting a plea's points and prize eligibility — elaborates on the client's already-accepted R5-P-1

**Severity:** Low (downgraded — base mechanism is already accepted by the client)

**Location:** `closeSeason()` — `Seasons.sol:320-329`; `record()`'s `SeasonClosed` guard — `Seasons.sol:227`

**Description.** The client's own `FINDINGS.md` (`R5-P-1`) already documents and accepts exactly this mechanism for Letter-originated pleas: *"a season closed with an empty id list drops the points of pleas nobody recorded"* — accepted as *"by design... a keeper calls record after the hold or lists the ids in closeSeason."* Three of our review agents (two in phase 1, one in phase 2) independently rediscovered this same mechanism. We are not re-reporting it as a new, unaccepted defect — but flagging two elaborations the client may want to weigh when re-confirming that acceptance:

1. **Scope.** Since Tribunal's 20-minute objection window now puts *every* plea type (not just Letter pleas) into a transient "held" state near a season boundary, R5-P-1's original Letter-specific framing is broader in practice than originally scoped.
2. **Framing.** The acceptance reasoning addresses an *accidental* keeper-timing gap; several of our agents independently constructed this as a *deliberate* adversarial race — any party (not necessarily a keeper) can call `closeSeason([])` the instant it becomes eligible, specifically to exclude a known rival's about-to-be-recordable plea, at essentially zero cost to themselves.

**Recommendation.** No action required if the client's existing acceptance already covers this broadened/adversarial framing; otherwise, consider tracking an explicit per-season "pending record" counter that blocks closing while nonzero, rather than trusting the caller's optional `pleaIds` argument to be complete.

---

### [I-1] `checkpointObjection`'s sole authorization check is a live, uncached, two-hop resolution with a dependency on an out-of-scope write-once guarantee

**Severity:** Informational

**Location:** `checkpointObjection()` — `Seasons.sol:194-207`; `_tribunal()` — `Seasons.sol:246-252`

**Description.** The only non-trivial access check in either contract (`msg.sender == tribunal`) is resolved fresh on every call via `plea.launcher()` → `launcher.tribunal()`, rather than cached. We verified this is **not** currently exploitable from within Tribunal.sol/Seasons.sol: `PLEA.launcher` is write-once, and `PleaLaunch.tribunal` is write-once and committed to a specific creation-code hash before trading can open. The one gap we could not close from inside these two files is `PLEA.setLauncher` (out of this job's scope), which the project's own code comment says depends on atomic, same-block deployment of all five launch contracts — *"The factory must deploy all five contracts atomically to prevent an intervening registration."* If that atomicity were ever violated, a second caller could register itself as `launcher`, point a fake `tribunal()` at itself, and call `checkpointObjection` for any approved `pleaId`, redirecting unaccounted IMD into an attacker-chosen season. This is noted for completeness and cross-reference against the client's PLEA.sol/PleaLaunch.sol audit history — it is not independently actionable within this job's scope.

---

### [I-2] `Seasons._owners()`'s third return slot is declared but never assigned

**Severity:** Informational

**Location:** `_owners()` — `Seasons.sol:422-430`

**Description.** `_owners()` returns `(address a, address b, address c)`, but `b` is never written anywhere in the function body; both call sites already destructure it away (`(address a,, address c) = _owners();`). No functional bug today, but the pattern suggests a possible leftover from a dropped third exclusion (e.g. the PLEA distributor) that was never fully removed during a refactor.

**Recommendation.** Remove the dead slot for clarity, or confirm with the team whether a third exclusion was intentionally dropped.

---

### [I-3] `topOf(season)` can display stale data after `closeSeason` drops an excluded owner from the payout

**Severity:** Informational

**Location:** `closeSeason()` — `Seasons.sol:336-337`; `topOf()` — `Seasons.sol:112-114`; `_dropOwner()` — `Seasons.sol:410-416`

**Description.** `_dropOwner` only mutates the in-memory copy of `_top[season]` used for the payout loop — it is never written back to storage. The public view `topOf(season)` will therefore continue to show an excluded owner occupying a top-25 rank with nonzero points after the season closes, even though they were never paid. Read-only/UX inconsistency; no funds are at risk.

---

### [I-4] `pointsFor`'s `uint8` cast can wrap for an out-of-range input, though no live caller reaches it with one

**Severity:** Informational

**Location:** `pointsFor()` — `Seasons.sol:133-135`

**Description.** `pointsFor(wallet, score)` takes `score` as a raw `uint8` with no upper-bound check; `score * 12_000 / 10_000` cast back to `uint8` wraps silently for inputs materially above the intended 0–45 range (e.g. `score = 255` → `306` → wraps to `50`). Every real, state-changing caller (`Seasons._record`, `Tribunal.status`) bounds `score ≤ 45` before calling, since both CabalGate and Tribunal revert above `MAX_PLEA_SCORE` before ever writing a score into storage — so this is only reachable by calling the public function directly with a self-chosen out-of-range argument, with no on-chain consequence beyond that caller's own read.

---

### [I-5] `accountedPot`'s unchecked subtraction assumes an exact 1:1 nominal-vs-real token transfer, with no recovery path if that assumption is ever wrong

**Severity:** Informational

**Location:** `checkpoint()` — `Seasons.sol:178-189`; `closeSeason()` — `Seasons.sol:346`; `_pay()`/`_payBonus()` — `Seasons.sol:463-466, 440-460`

**Description.** `_pay`/`_payBonus` check only that a transfer call returned success — never the actual balance delta. If any payout token call ever succeeded while debiting Seasons' real balance by *more* than the nominal amount credited to `paid` (an unusual token behavior, not expected from standard-compliant IMD/PLEA), `accountedPot` would permanently exceed `pot()`, and every future `checkpoint()`/`checkpointObjection()`/`closeSeason()` call would revert on the resulting underflow — with no recovery path, since the only reset (`flushToWall`) itself requires every season to have successfully closed first.

**Recommendation.** Resync by re-reading `pot()` directly rather than subtracting a locally-tracked delta, or floor the subtraction at zero and treat any shortfall as absorbed loss.

---

### [I-6] `closeSeason` has no keeper incentive and can only close seasons strictly in sequence

**Severity:** Informational

**Location:** `closeSeason()` — `Seasons.sol:320-351`

**Description.** `closeSeason` always operates on the single oldest unclosed season (`nextToClose`) with no way to target or skip ahead, and pays its caller nothing despite performing up to 50 token transfers plus claims redemption. A run of low-value seasons (e.g. all top-25 slots below the 60-point bar) pays nobody and must still be closed, at the caller's uncompensated gas expense, before `nextToClose` can ever reach a later, richer season. Not a fund-safety issue — a sustainability/incentive-design note.

---

## Reviewed and excluded (already fixed, already accepted by design, or found immaterial)

The following were investigated — several independently, by 2–4 of the 22 review agents across both phases — and are **not** included above, per the client's instruction not to re-report fixed or accepted items:

- **Two Sybil wallets filing sham objections to permanently close a plea's case ("the seller shield")** — found independently by 4 of our agents as a seemingly novel finding. This is **already accepted**: `FINDINGS.md` `R6-E-1` describes the identical mechanism with the identical cost figure (`2 × (0.5 fee + 0.35 stake) = 1.7 IMD`), accepted by the owner 2026-10-14 with the stated rationale that "the two-ruling cap, the 0.85 IMD price and the stake lost on an overrule are the brakes."
- **A single cheap objection's cost being disproportionate to the prize-share damage it can inflict on a rival** — found independently by one agent. **Already accepted**: `FINDINGS.md` `R5-E-1` states the identical economics ("two cheap objections is a positive-EV attack on any leader... 0.85 IMD... against one rank's prize"), accepted 2026-10-14 with a documented fallback plan ("a median or a floor at original − margin") if objection farming shows up live.
- **`closeSeason` being callable with an incomplete/empty `pleaIds` array, dropping unrecorded pleas' points** — see **L-3** above; substantially accepted as `R5-P-1`, included above only as a scope/framing elaboration, not a new finding.
- **The seat NFT's 1.2× multiplier being evaluated only at the instant `record()` is called, letting a wallet "borrow" a seat for one transaction** — found independently by one agent as a seemingly novel finding. This is **explicitly documented as deliberate** in the client's `THREAT-MODEL.md` §3: *"a wallet that holds a seat only for the recording transaction gets the multiplier... a seat sold after the recording keeps the points."*
- **The owner (or launch owner) transferring ownership away before or after a plea's verdict to bypass the exclusion list** — found independently by two agents, in both temporal directions (owner-at-verdict-then-transfers-away, and transfers-in-then-records). Both directions are **already accepted** as `R6-P-1`: *"the exclusion is read at record time and at the close, not at the verdict: a plea approved while its seller owned PLEA records after a handover... nominal: the launch owner stays excluded forever, and a second wallet achieves the same."* One agent additionally noted that `Tribunal.object()` also refuses objections (`SellerExcluded`) during the window while the seller is still the current owner — a natural corollary of the same live-ownership check, not a structurally distinct gap.
- **The missing `a.requestId`/`a.questionHash` binding between the Intake's callback routing key and the signed attestation's own identity** — found independently by one agent in Tribunal's `onOracleResult`. **Already accepted** as `L85-I-1`, which explicitly names *"the gate's and the Tribunal's oracle callbacks"* together and gives the owner's detailed reasoning for not fixing it (the live Intake v2 refuses `complete()` from anyone but IMD's writer key; comparing the two ID spaces "would refuse every live answer" since they are different ID spaces by design).

---

## Coverage summary

- **Entry points** (per the phase-0 access-control inventory): all state-changing functions in both contracts — `object`, `onOracleResult`, `onObjectionFailure`, `expire`, `settle` (Tribunal); `checkpoint`, `checkpointObjection`, `record`, `closeSeason`, `flushToWall`, `unlockCallback` (Seasons) — were each examined; each has either a finding above or an explicit "examined, no issue" note in the review trail.
- **Agreed invariants** (`THREAT-MODEL.md` §2, items 7–13 touching Tribunal/Seasons): all seven were independently re-derived and stress-tested by the invariant-specialty depth agent and cross-checked by others. Invariant 10 (fail-open reads "can never block") is violated under the conditions in **H-1**. The others hold as designed, including under deliberate attempts to defeat stake conservation, the accounting identity, and the sequential-close ordering.
- No pass depended on executing the target's own code (build/test); all analysis is static source review, per audit policy.

---

> This review was performed by an automated multi-agent pipeline (ethskills breadth + pashov-methodology depth, 22 agents across two blind phases, reconciled against the client's own threat model and findings ledger). Automated analysis can never verify the complete absence of vulnerabilities. Independent human review, the project's own test suite (823 tests per the client's description), and continued monitoring after launch are recommended alongside this report.

---

## Session check (2026-10-17 ~11:50 UTC, against `testnet8.5` @ `af57f6d`; Tribunal and Seasons unchanged on `next`)

**H-1 (a malformed answer to a fail-open read could block `record` or a close). Not reachable; the wording of invariant 10 is the issue.**
- Every decoded source is our own committed code or a standard token:
  - `Tribunal.standing` (the committed Tribunal, keccak in `PleaLaunch`);
  - `PleaLaunch.tribunal()` (PLEA's write-once launcher);
  - `PleaHook.owner()` (the committed init code);
  - `IMD.transfer` (a standard LayerZero OFT, OZ ERC-20);
  - `PLEA.transfer` (our OZ ERC-20).
- Compiled Solidity and these tokens always return canonical words. Their views are cheap, so uncapped gas changes nothing. The seat NFT read is capped at 100,000 gas and decodes a `uint256`, which cannot fail.
- Invariant 10 promises "gas-hungry or malformed" safety for all four reads; in code that holds only for the seat NFT.
- **Proposed:** reword invariant 10; no code change.

**M-1 (IMD wired separately into CabalGate, Seasons and PleaLaunch, with no on-chain cross-check). Real in principle.**
- A deploy with mismatched IMD words would make every `settle` of an overruled objection revert (`UnfundedStake`).
- Our launch cannot mismatch: `test_launchJsonAddressWordsAreTheTestedAddressesInAValidCase` (added for L85-F-1) checks all three IMD words in `launch.json` against one constant on `next` and on `mainnet`. Run 8.5 has them equal on chain.
- **Proposed (optional, cheap):** `PleaLaunch`'s constructor refuses `IGate(gate_).imd() != imd_` or `ISeasons(seasons_).imd() != imd_`, like its `oracleAsset` check (a few lines and one test; no committed hash changes).

**M-2 (`expire` races the Intake's delivery through `requests(id).completed`). Not reachable.**
- The live Intake v2's verified source (Sourcify, `src/Intake.sol`): `complete` sets `stored.completed = true` and calls the callback in the same function, so no other transaction can run in between.
- A delivered ruling leaves the objection no longer pending, and a failed one leaves it pending with `completed` true, so `expire` voids it as it should.
- The 20-minute clause is the designed expiry.

**L-1 (`objectionOfIntake[rid]` is overwritten without a zero check). Not reachable:** the Intake's ids are `keccak256(chainid, intake, ++nonce)`, unique per request.

**L-2 (no sweep in the Tribunal):** ownerless by design. **L-3:** the accepted R5-P-1. Window plus expiry (40 minutes) always ends inside the one-hour close grace (invariant 13), so a plea approved before a season's end can always be recorded before the close is allowed; the seller has every reason to, and the keeper records too.

**Infos:**
- I-1: write-once wiring; the launch is atomic.
- I-2: `_owners`' unused slot is cosmetic.
- I-3: `topOf` still shows an excluded owner (display only).
- I-4: `pointsFor` is a view; every caller stays at 45 or below.
- I-5: standard tokens.
- I-6: closes need a keeper; the keeper bot is a planned task.

**Owner's decision (2026-10-17):** no code change (the IMD cross-check skipped: the manifest test covers it); invariant 10 reworded; the twelve findings recorded as ODA-1017-1 to -12 (the header's "3 Medium" describes only two).
