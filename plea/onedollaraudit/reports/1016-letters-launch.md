# PLEA run 8.5 — Independent Security Audit (Letterbox, PLEA, PleaLaunch, PleaDistributor)

**Target (repo):** `https://github.com/khaed1/plea` @ commit `af57f6df709acdf7fe754a58482ee35eef9e2178` (branch `testnet8.5`)
**Deployed (Sepolia):** Letterbox `0x993eb617a0d6ad72eD0727aA734c36241bf2448C` · PLEA `0xd395ad74f5c31c8afe6316be3b8041be8bac5d1c` · PleaLaunch `0x88a2d29c6ce265e1990252b33c60753d4018ad0f` · PleaDistributor `0x1ba83d21c73d75ac79b997ab2f1e20b415daa378`

**Scope (per client instruction — audited directly, line-by-line):**
- `src/Letterbox.sol` (556 nSLOC)
- `src/PLEA.sol` (102 nSLOC)
- `src/PleaLaunch.sol` (159 nSLOC)
- `src/PleaDistributor.sol` (44 nSLOC)
- `src/interfaces/IPleaParts.sol` (65 nSLOC)
- `launch.json`

nSLOC independently recomputed per file (BSD-grep-safe method, not the vendored `enumerate.sh`, which undercounts on macOS): 556 / 102 / 159 / 44 — matches the client's stated figures exactly, confirming scope identity with the commit audited.

**Context-only files read for call-chain tracing (not independently re-audited, not a source of standalone findings unless the scoped file's own code contributes to the issue):** `src/CabalGate.sol`, `src/PleaHook.sol`, `src/Seasons.sol`, `src/Tribunal.sol`, `src/OracleAttestation.sol`, `src/interfaces/IStacker.sol`.

**Independence note.** This repository carries eight prior audit rounds plus IMD's own launch-job pipeline, recorded in `audit/THREAT-MODEL.md` and `audit/FINDINGS.md` at a later commit (`54da76b`) than the one audited here. Those documents were read **only** to avoid re-reporting findings already fixed or accepted by the project owner, per the client's explicit instruction — not as a source of findings. Every finding below was independently derived from this pass's own line-by-line reading of the pinned commit: a full mechanical scan (file enumeration, git history/hotspot analysis, nSLOC recomputation), a protocol map and access-control inventory built from the scoped files, a threat catalog (actor × entry point × asset), and a systematic line-by-line hunt across the standard audit lenses (access control, economic/fee accounting, execution-trace/reentrancy, invariant-break, trust-boundary/cross-contract assumptions, boundary/edge-case, numerical precision). Two items from the existing ledger are present (unfixed) in this exact commit and are called out below as **already known** — they are not re-reported as new findings per the client's instruction.

**Git history note.** The local clone's shallow fetch at the pinned SHA was unshallowed to the full `testnet8.5` history (116 commits) for git-security-analysis; no coverage/test execution was run (`forge build`/`forge test`/`forge coverage` are explicitly out of audit-policy scope — test *existence* only, 823 tests per the client description, confirmed via repository file listing, not executed).

---

**Severity counts:** 0 Critical · 0 High · 0 Medium · 1 Low · 2 Informational

---

## Findings

### L-1 — `PLEA.setLauncher`'s one-shot registration has no on-chain atomicity guarantee; it is a permissionless race protected only by an unenforced off-chain promise

**Severity:** Low
**File:** `src/PLEA.sol:58-74`

```solidity
/// @dev Registration also accepts any first caller in PLEA's deployment block for rehearsals.
/// The factory must deploy all five contracts atomically to prevent an intervening registration.
function setLauncher(address gate_, address seasons_, address distributor_) external {
    uint256 flag;
    assembly ("memory-safe") {
        flag := tload(DEPLOY_TX_SLOT)
    }
    if (flag != 1 && block.number != deployBlock) revert NotDeployTx();
    if (launcher != address(0)) revert AlreadySet();
    if (gate_ == address(0) || seasons_ == address(0) || distributor_ == address(0)) revert ZeroAddress();
    assembly ("memory-safe") {
        tstore(DEPLOY_TX_SLOT, 0)
    }
    launcher = msg.sender;
    gate = gate_;
    seasons = seasons_;
    distributor = distributor_;
    emit Launched(msg.sender, gate_, seasons_, distributor_);
}
```

**What the code actually enforces.** `setLauncher` has **no caller restriction at all** — it is reachable by any address, with any `gate_`/`seasons_`/`distributor_` values, as long as (a) the transient "same transaction as the constructor" flag is still set, **or** (b) `block.number == deployBlock` (same block as PLEA's own deployment, regardless of transaction), and (b) the one-shot guard `launcher == address(0)` hasn't already fired.

**Why it matters.** `launcher` is the identity that later gains `PLEA.init(hook_, poolManager_)` rights (`src/PLEA.sol:98-108`), which performs the entire supply mint: 82%/6%/12% of the 1,000,000,000-token supply to `hook_`/`seasons`/`distributor`. Whoever wins `setLauncher` permanently owns that mint — the guard is one-shot (`AlreadySet`), so the real factory's later call to the same function reverts and the legitimate launch is blocked for good. The `gate` address set here also controls `PLEA.restricted()` (via `IGate(gate).restricted()`), i.e., whoever wins this call can also point `gate` at a contract that always returns `false`, lifting every sell-gate transfer restriction on the entire supply.

**Concrete exploit path** (conditional — see mitigating factor below): if PLEA's deployment and the rest of the five `launch.json` contracts are **not** sent as one atomic transaction (a gas-limit split, a factory bug, or operational reuse of the documented multi-transaction "rehearsal" deployment pattern for a value-bearing launch), an attacker watching the chain for PLEA's deployment can submit, in the same block, `setLauncher(attackerGate, attackerSeasons, attackerDistributor)` before the real factory's follow-up transaction lands. The real deployment then reverts with `AlreadySet`, and the attacker — now `launcher` — calls `PLEA.init(attackerHook, attackerPoolManager)` directly to mint the full supply to contracts they control, with `gate` pointed at a contract that reports `restricted() == false`, removing all transfer limits.

**Mitigating factor (why this is Low, not High/Critical).** The client's own `THREAT-MODEL.md` actor table classifies "IMD's launch factory" as a **trusted deployer** specifically for the property this finding concerns ("Deploys the five `launch.json` contracts in one atomic transaction… Trusted deployer"), and `launch.json`'s own `notes` field states the mitigation in writing: *"Atomic deployment prevents another caller from taking PLEA's deployment-block registration window."* This is an explicitly accepted trust boundary, not an oversight, and IMD's factory has reportedly performed this atomic pattern across many prior launches (this is launch #1981). The finding is a genuine code-level gap — nothing in the scoped contract enforces or verifies the atomicity it depends on — but exploiting it requires breaking an assumption the client has already declared out of the contract's own threat surface.

**Recommendation (defense-in-depth, optional given the accepted trust model):** have `PLEA`'s constructor accept the intended launcher's predicted `CREATE` address (computable off-chain from the factory's nonce) and require `msg.sender == plannedLauncher` in `setLauncher`, removing the permissionless `block.number == deployBlock` fallback from the production code path entirely (route rehearsal-only multi-tx deploys through a separate, clearly-labeled test entrypoint that cannot reach mainnet).

---

### I-1 — Interface definitions for `Seasons` are duplicated and fragmented across the scoped files instead of centralized in `IPleaParts.sol`

**Severity:** Informational
**File:** `src/Letterbox.sol:14-33`, `src/interfaces/IPleaParts.sol:76-78`

`IPleaParts.sol` declares a minimal `ISeasons` with only `checkpoint()`:

```solidity
interface ISeasons {
    function checkpoint() external;
}
```

But `Letterbox.sol` defines its own, much larger local interface instead of extending or importing a shared one:

```solidity
interface ISeasonsForLetters {
    function record(uint256 pleaId) external;
    function recorded(uint256 pleaId) external view returns (bool);
    function shareBps(uint256 rank) external pure returns (uint256);
    function currentSeason() external view returns (bool live, uint256 season, uint64 endsAt);
    function checkpoint() external;
    function topOf(uint256 season) external view returns (Entry[25] memory);
    function seasonFees(uint256 season) external view returns (uint256);
    function rollover() external view returns (uint256);
    function BONUS_SEASONS() external view returns (uint256);
    function BONUS_PER_SEASON() external view returns (uint256);
    function pointsFor(address wallet, uint8 score) external view returns (uint8);
    function pointsOf(uint256 pleaId) external view returns (uint8);
    struct Entry { address wallet; uint16 points; uint64 pleaId; }
}
```

`Tribunal.sol` (out of scope, but visible in the call graph) independently defines a third variant, `ISeasonsForTribunal`, with yet another subset of the same `Seasons` surface. None of these causes a behavioral bug — each consumer only calls the subset it declares, and `Seasons.sol`'s real ABI is a superset of all three — but the fragmentation means a future change to `Seasons` (e.g., renaming or re-typing one of these functions) has to be caught by eye in three separate places rather than by the compiler in one shared interface. No fix required; noted for maintainability only.

---

### I-2 — Known, already-ledgered items present at this exact commit (not re-reported)

**Severity:** Informational (ledger confirmation only — no action item)

Two items from the client's own `FINDINGS.md` ledger (ID `L85-M-1` and `L85-F-1`) are confirmed present, unfixed, in the exact `af57f6d` source audited here, matching the client's own note that both were "fixed on `next`" but not yet in this commit:

- **`L85-M-1`** (Low, math): `CabalGate._factScoreAt` (out of scope, but the share-band computation it performs is `amount * 10_000 / bal`, a floor) scores a plea at exactly 20.00%–20.01% of balance into the ≤20% band rather than the next band down — confirmed present; the fix lives in `_shareBps` on `next`, not in this commit.
- **`L85-F-1`** (Info, flow): `launch.json`'s `Seasons` constructor argument for the seat NFT is written as `0xA0443799C320e16C80801c9c1911f3571260287F`, which is **not** that address's EIP-55 checksum casing (confirmed by inspection — compare against the ledger's stated correct casing `0xa0443799c320E16C80801c9C1911F3571260287F`). The deployed Sepolia launch (#1981) used the correct address regardless (per the client's note, "IMD's accepted it"); only the *casing* in this file is wrong, which a strict checksum-validating parser would refuse.

Both are already ledgered as Low/Info and accepted/fixed-on-`next`; they are listed here only to confirm this pass examined them against the pinned commit and found no discrepancy with the client's own record.

---

## Access-Control Inventory (scoped files)

| Contract.Function | Guard | Caller | Value-moving? | Notes |
|---|---|---|---|---|
| `Letterbox.fallback()` / `letter()` | `nonReentrant` only | anyone | PLEA → escrow, IMD fee swap | dispatches by first word; see **L-1** is unrelated — this entrypoint is sound (verified below) |
| `Letterbox.plead()` / `appealAuto()` | `nonReentrant` only | anyone | same as above | site auto-sell box |
| `Letterbox.setName()` | `nonReentrant` only | anyone (own name only) | none | unique-name registry |
| `Letterbox.deliver()` | `nonReentrant` only | anyone (permissionless runner) | IMD escrow → writer, tip → caller | by design; writer-only payout verified — see analysis below |
| `Letterbox.settle()` | `nonReentrant` only | anyone (permissionless) | PLEA + tip → escrow's writer | by design |
| `PLEA.setLauncher()` | **unguarded except timing** | anyone, inside deploy tx/block | none directly, but gates `init()`'s mint rights | **see L-1** |
| `PLEA.setLetterbox()` | `msg.sender == launcher` | launcher only | none | one-shot |
| `PLEA.courtTake()` | `msg.sender == letterbox` | Letterbox only | PLEA writer → Letterbox | one wallet's PLEA moves only inside that wallet's own tx (confirmed) |
| `PLEA.init()` | `msg.sender == launcher` | launcher only | **mints 1B supply** | one-shot; see **L-1** for the access path into `launcher` |
| `PLEA.allow()` | `onlyOwner` | PLEA owner | none directly | add-only allowlist; confirmed it cannot bypass the gate/pool transfer branches |
| `PLEA.burn()` | none (self only) | token holder | burns caller's own PLEA | restricted while Cabal watches for non-exempt senders |
| `PleaLaunch.deployHook/deployLetterbox/deployTribunal` | code-hash match, one-shot | anyone | triggers `PLEA.init()` (hook only) | front-running changes only the hook's resulting address, not its code — confirmed harmless |
| `PleaLaunch.seed()` | owner any time; anyone after `START`; one-shot | owner / anyone | opens trading | mainnet chain-id-1 timing + market-cap guard confirmed present (R8-A3-1 fix intact at this commit) |
| `PleaDistributor.setMerkleRoot()` | `onlyOwner`, one-shot | distributor owner | none directly | — |
| `PleaDistributor.renounceOwnership()` | `onlyOwner`, blocked until root set | distributor owner | none | confirmed cannot strand the 12% |
| `PleaDistributor.claim()` | none (pays only the listed account) | anyone, for anyone | distributor PLEA → listed account | standard Merkle-distributor pattern; checks-effects-interactions order confirmed (claim bit set before transfer) |

**Unguarded, value-adjacent entrypoint:** `PLEA.setLauncher()` is the only entrypoint in scope with no caller restriction beyond a timing window — see **L-1**.

---

## Threat Catalog (actor × entrypoint × asset)

| Actor | Reaches | Could gain | Invariant that must hold |
|---|---|---|---|
| Any address, same block as PLEA's deployment | `PLEA.setLauncher` | Permanent `launcher` identity → later mint of 1B PLEA via `init()`, and control of the `gate` restriction switch | The deployment of all five `launch.json` contracts is a single atomic transaction (off-chain, trusted per THREAT-MODEL's actor table) — **see L-1** |
| Letter writer | their own escrow via `_plead`/`_appeal`/`settle`/`SELL` | only their own escrowed PLEA + tip | `_openOf[writer]` one-escrow-per-writer invariant — confirmed held across every code path (new letter always settles the old one first) |
| Any runner (stranger) | `deliver(id)` / `settle(id)` for **any** open `id` | the 0.25 IMD tip only | payout of the sale/refund always targets the escrow's stored `writer`, never the caller — confirmed by direct trace of both functions |
| PLEA owner | `allow(account)` | add an address to the free-transfer allowlist | cannot reach the pool-manager or gate transfer branches of `_update` — confirmed; the allowlist only affects the generic (non-pool, non-gate) branch |
| Any deployer | `deployHook`/`deployLetterbox`/`deployTribunal` with a front-run salt | only the resulting *address* of the hook (code is fixed by the hash commitment) | code-hash commitment in `PleaLaunch`'s constructor — confirmed unconditionally enforced |
| Distributor owner | `setMerkleRoot` | sets the one root (trusted, off-chain-built) | one-shot guard + `Ownable2Step` + renounce-blocked-until-root — all confirmed present |
| Anyone | `PleaDistributor.claim()` for someone else's leaf | nothing extra — pays the leaf's own listed account | Merkle proof + claimed-bitmap check before transfer — confirmed |

---

## Invariant Verification

Mapped against the client's own numbered invariants (`THREAT-MODEL.md` §2) that the in-scope files are directly responsible for:

| ID (client doc) | Property | On-chain enforcement | Verdict (this pass) |
|---|---|---|---|
| Inv. 1 | PLEA leaves a holder's wallet only through the gate/approved sale while the Cabal lives; transfers to the pool/gate/Letterbox stay restricted except system senders and the owner's allowlist | `PLEA._update` three-branch check | **Holds** — independently re-derived the full branch logic (pool-manager branch keys on `from==gate\|\|from==hook`; gate branch keys on `msg.sender==gate`; generic branch keys on `_exempt(from)` or a Letterbox-self-send) and found no address/path that bypasses it other than the documented owner allowlist, which itself cannot reach the pool-manager or gate branches |
| Inv. 14 | Letterbox's PLEA + IMD accounting is exactly its open escrows' PLEA plus 0.25 IMD tip per open escrow; every escrow ends exactly once | `_open`/`_close`/`_deliver`/`_settle` plus the fee-swap's exact-output accounting in `_approveGate`/`_swapFee` | **Holds** — traced the full IMD balance lifecycle: the fee-sale swap buys *exactly* `feeImd` (TIP + oracle fee if not minted + appeal wall share) with no excess retained; unspent PLEA from the swap is refunded back to the writer in the same call that opens the escrow; `_close` is called exactly once per escrow (`e.open` flips false, both `deliver` and `settle` check `!e.open` first) |
| Inv. 15 | A letter pleads 20% of balance (1,000–2.5M PLEA), appeal keeps the lesser-share clamp, fees bounded by snapshot value + 10%, never more than 10% of balance (or the original's amount + slack for an appeal) | `_plead`/`_appeal` bound checks | **Holds** — walked the appeal same-share clamp arithmetic end-to-end (`sameShare`, `least`, `floorAmount`, the 50%-of-balance ceiling) and confirmed the final `amount` is always bounded within `[least, min(originalAmount, 50% of balance)]` after the floor-raise step, for every order the three clamps can fire in |
| Inv. 16 | No Letterbox selector collision with valid letter text; no ETH; every entry point `nonReentrant` | `fallback()` non-`payable`, `_isWord` matching, modifier list | **Holds** — confirmed every external state-changing function carries `nonReentrant`; `fallback()` lacking `payable` reverts any ETH-bearing call at the EVM level before user code runs |
| Inv. 17 | Launch deploys atomically with committed code hashes; front-running a deploy call changes nothing but the hook's address; `seed` waits for the Letterbox and a committed Tribunal | `PleaLaunch` constructor + `deployHook`/`deployLetterbox`/`deployTribunal`/`seed` guards | **Mostly holds, one gap flagged** — the code-hash commitment, one-shot guards, and `seed`'s dependency ordering are all confirmed correctly enforced on-chain. The *atomicity* of the initial five-contract deployment that `PLEA.setLauncher`'s access control depends on is **not** itself verifiable on-chain — it is an off-chain operational guarantee only (**L-1**) |
| Inv. 18 | Distributor: one root set once; a claim pays only its listed leaf, once; ownership two-step, no renounce before the root | `PleaDistributor` | **Holds** — confirmed bitmap packing is correct (256 bits per word, standard pattern), leaf hash uses only fixed-width fields (no `abi.encodePacked` ambiguity), checks-effects-interactions ordering is correct in `claim` |

**Coverage gate:** 17 scoped entry points (12 state-changing external functions across the 4 scoped contracts, plus 5 view-only convenience functions not independently re-listed above), 17 addressed (14 examined with an explicit verdict in the inventory table, 3 one-shot/trivial setters examined inline in the invariant walk). 7 threat-catalog rows, 7 answered. 6 inferred invariant rows drawn from the client's own numbered list that the scoped files are responsible for, 6 answered (5 hold, 1 partial-gap flagged as **L-1**). Coverage holes closed this pass: 0 (no entry point or threat row was left unexamined by either this pass's own reading or a cross-check against the existing ledger).

---

## Scope note on what was *not* independently re-audited as a primary target

Per the client's explicit scope ("other `src/` files are context only"), `CabalGate.sol`, `PleaHook.sol`, `Seasons.sol`, `Tribunal.sol`, and `OracleAttestation.sol` were read in full for call-chain context (every external call the scoped files make into them, and every assumption the scoped files make about their behavior, was traced) but were not independently re-hunted for bugs whose root cause lies entirely inside those files. No such cross-boundary issue was found during this pass — every assumption the scoped files make about the out-of-scope contracts (fee accounting, price-checkpoint staleness tolerance, fail-open reads of `Tribunal.standing`/seat `balanceOf`, the hook's `latestPrice()`/`basisOf` semantics) checked out against the actual out-of-scope code as read.

---

## Session check (2026-10-17 ~15:00 UTC, against `testnet8.5` @ `af57f6d`; `PLEA.sol`, `PleaLaunch.sol` and `PleaDistributor.sol` are unchanged on `next`, the Letterbox changed only by `HOOK_SALE_FEE_BPS` 225)

Report: IPFS `bafkreihhugsqqnua3kg4bihiphteb4pa7ow566x47uoa7d7djtwkvaqw74`, html https://leftclaw.services/result/1016.html (job started 09:08, completed 14:47 UTC). **0 Critical, 0 High, 0 Medium, 1 Low, 2 Infos.** Its walk-through confirms invariants 1, 14, 15, 16 and 18 hold, and 17 except the factory's atomicity (L-1).

**L-1 (`PLEA.setLauncher` is open to the first caller in PLEA's deployment transaction or block). Not reachable on a real launch; already a documented trust assumption.**
- The window exists on purpose. The transient flag covers the factory's single transaction. The `deployBlock` fallback covers IMD's launch rehearsal, which deploys each contract in its own transaction (`PLEA.sol`'s own comment; it has been in the code since PLEA v2, launch #1148).
- IMD's factory deploys all five `launch.json` contracts in one transaction, so nothing can run between PLEA's constructor and PleaLaunch's. Before that transaction PLEA does not exist, and after it `launcher` is set, so a second call reverts `AlreadySet`.
- Checked on chain for run 8.5 (launch #1981): `PLEA.launcher()` = PleaLaunch `0x88a2…aD0F`, `gate()` = CabalGate, `seasons()` = Seasons, `distributor()` = PleaDistributor, `deployBlock()` = 11,928,160, the factory transaction's block.
- The report's own mitigation section cites the same documents: THREAT-MODEL §1 (the factory is a trusted deployer), the `launch.json` notes ("Atomic deployment prevents another caller from taking PLEA's deployment-block registration window") and README "Deploy".
- Its fix (a planned launcher address in PLEA's constructor) does not fit IMD's pipeline. The factory's addresses are IMD's, the rehearsal runs on another chain, and `launch.json` can only reference earlier contracts. Removing the block fallback would fail IMD's rehearsal and park the launch, as happened to run 5.
- **Proposed:** one THREAT-MODEL §3 line naming the window and why it is closed in practice; no code change.

**I-1 (three local interfaces for Seasons):** maintainability only. Every consumer is tested against the real `Seasons`, so a mismatch fails the suite. **Noted.**

**I-2 (L85-M-1 and L85-F-1 present at `af57f6d`):** known and fixed on `next` (`728d819`). **Noted.**

**Recommendation:** no code change; one THREAT-MODEL §3 line; ledger rows ODA-1016-1 to -3 (L-1 "documented", I-1 and I-2 "noted").
