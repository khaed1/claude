# Check before audit round 6 (8 Oct 2026)

Claude's own check of the D-86 fixes (round 5, fix commit `d65698e`) before round 6 is generated, at the branch head `ffac7be` (the ledger commit). `d65698e` → `ffac7be` changes only docs: `git diff d65698e ffac7be -- launchpad/contracts launchpad/audit/jobs launchpad/audit/make_jobs.py` is empty. Everything was re-run, and every round-5 finding's path was read against `git diff 3cd764f d65698e -- launchpad/contracts`. Round 6 is not generated.

**Result: no contract bug, and every D-86 fix closes the path its round-5 finding described.** One fix is narrower than the docs say:

- **P6-1 (Low): the `fundInventory` band stops a pump made in the executing block, not one held over many blocks.** A pump held with nobody trading for about (pump ticks − 100) / `maxRefStep` Ethereum blocks drags `referenceTick()` along, and the queued add then runs at the pumped price: the round-5 judge's sandwich pays again (+58.90 IMD at 1.5× IMD slack after an 80-block hold, ~16 minutes; +269.75 IMD at 2×). It loses at 1.2× IMD slack or less whatever the hold, and one seller taking a quarter of the pump turned it into a 717 IMD loss. THREAT-MODEL invariant 11, ARCHITECTURE §5.4.1 / §5.6 and the A2 job line say the executor "can't run it inside a pump of its own" with no one-block qualifier; an auditor reading that literally may call the fix incomplete, and §2 rates a broken invariant at least High.
- **P6-2 (Info): ledger and decision-log text.** FINDINGS R2-A3-7 names a test renamed in `35aa6b1`; twelve takeover rows name tests removed with `CTOModule` (D-82) and carry no note (the R5-A1-2 class, in A4's area this time); D-86's decision row still words R5-A4-3 as planned ("or the caller made the link"), not as implemented.
- **P6-3 (Info, optional, tests only):** the vault / dripper invariant test never tries an exit to address(0) or the vault, and doesn't count successful exits.

Recommendation in §5: fix P6-1 by documentation and an owner rule (no contract change), fix P6-2, optionally add P6-3, then generate round 6 at the ledger commit. Round 6 generated at `ffac7be` as it is would be safe for funds, but P6-1's wording is likely to come back as a finding.

**Outcome (8 Oct 2026):** the user went ahead with the recommendations (D-87), implemented in `7ba6923`, nothing in `src/`, `script/` or `upstream/`. P6-1, option (a): THREAT-MODEL invariant 11 and §3, ARCHITECTURE §5.4.1 / §5.6, HANDOFF §5a and the A2 job line say the band holds within one Ethereum block and give the owner rule (each maximum's slack below 2 · fee · pool liquidity / added liquidity, 1.2× today; the Safe cancels a queued add when the price leaves that band). P6-2: R2-A3-7's test name, the note on the takeover rows, D-86's R5-A4-3 wording. P6-3: the staking invariant test tries exits to address(0) and the vault and checks that an exit within the max never reverts; it fails on `3cd764f` ("no exit pays address(0) or the vault") and passes 60 fresh-seed campaigns. After: 210 local (6 fresh-seed runs) + 9 mainnet fork + 2 testnet fork tests pass; round-6 objectives A1 6,527, A2 6,861, A3 7,118, A4 7,424 characters. Round 6 is generated at the ledger commit after `7ba6923`.

## 1. What was run

| Check | Result |
|---|---|
| Foundry 1.5.1 from the release binaries (HANDOFF §3); `forge build` | 15 min 17 s (solc 914.5 s, via-IR), no errors |
| Local `forge test --no-match-contract Fork` | **210 / 210** on the first run. 10 more full runs with fresh `--fuzz-seed` values (`cache/fuzz` deleted before each): 210 / 210 every time |
| Mainnet fork `FORK_RPC=https://rpc.mainnet.chain.robinhood.com forge test --match-contract Fork` | **9 / 9** (`Fork.t.sol` 5, `DeployFork.t.sol` 4), first try; the command reports 11 (the 2 `TestnetFork` tests return early without `TESTNET_RPC`) |
| Testnet fork `TESTNET_RPC=https://rpc.testnet.chain.robinhood.com forge test --match-contract TestnetFork` | **2 / 2**, first try |
| Generators: `python3 upstream/make_fork.py`, `python3 upstream/make_staking.py` (in a worktree of `ffac7be`) | Byte-identical: `PadMarketHook.sol` sha256 `6660449c…4eee`, `StakedPONDPAD.sol` `ac272bd5…2ec3`, `RewardDripper.sol` `53ece7ec…49b6`; `git status` clean afterwards |
| Contract sizes (runtime / initcode) | `PadMarketHook` **23,089** / 24,798 bytes: **1,487 bytes** under the 24,576 limit (unchanged). `PadHook` 13,239, `MarketController` 12,330, `PadLens` 11,387, `StakedPONDPAD` 7,345, `VersionRegistry` 7,182, `SocialRegistry` 5,435, `CreatorVault` 2,409 |
| Fails-before (below) | **12 of 210 fail on `3cd764f`**, each on what it asserts; all pass at `ffac7be` |
| `Deploy.s.sol` simulation and broadcast on an anvil mainnet fork (below) | 51 transactions, all succeeded; 70 checks as expected |
| `keeper/keeper.mjs --once --dry` against the anvil deployment | Lists exactly the due jobs (below) |
| `make_jobs.py`'s objectives for round 6 at `ffac7be` (built in memory with its own `manifest`, `parse_area` and `fill`; `rounds/6/` not written) | A1 **6,527**, A2 **6,373**, A3 **6,867**, A4 **7,241** characters, all under IMD's 8,000; 38 files, 9,978 lines in scope, every one in an area's FILES |
| Probes (appendix) | All pass, i.e. every statement in §3 and §4 holds |

**Fails-before.** Worktree of `3cd764f`, `lib/` copied (not symlinked; the submodules' `.git` pointer files deleted in the copy, so forge's "missing dependencies" install fails harmlessly and the copy is used), `ffac7be`'s `test/` copied in, and only the four compile-time stand-ins: `error PriceOutOfRange()` in `MarketController`, `error InvalidRecipient()` in `CreatorVault`, `error NoCode()` in `VersionRegistry`, `error ZeroAddress()` in `SocialRegistry`. Build 879 s. Run with `--fuzz-seed 1`: **198 pass, 12 fail**, each on its first asserted refusal or value (traces checked):

| Test | Fails on `3cd764f` with |
|---|---|
| `test_market_fundInventoryRefusesAPumpedPrice` (R5-A2-1) | the add after the 4,200 IMD pump runs ("next call did not revert") |
| `test_buyer_migrationCarriesTheCaughtUpReference` (R5-A2-2) | "the new market keeps the caught-up reference: 104764 != 107197" |
| `test_market_migrateMovesEverythingIntoNewHook` (updated) | `104767 != 104967` (stored against caught-up reference) |
| `test_vault_refusesRecipientsThatStrandFees` (R5-A1-1) | `setRecipient(coin, vault)` runs |
| `test_dripper_cantRescueParkedShares` (R5-A3-2) | `rescueERC20(sPONDPAD)` transfers the shares |
| `test_vault_noExitToAddressZeroOrTheVault` (R5-A3-3) | `redeem(…, address(0), …)` pays address(0) |
| `test_staking_generatedSourcesKeepNoStaleUpstreamPowers` (R5-A3-5) | "can rescue the buffer" found at offset 4,008 |
| `test_buyer_clampsItsLimitToATickV4Accepts` (R5-A3-4) | `PriceLimitOutOfBounds(4295128739)` |
| `test_social_newRecipientClearingAStaleLinkKeepsItsVoucher` (R5-A4-3) | "the nonce didn't move: 2 != 1" |
| `test_versions_verifierNeedsCode` (R5-A4-5) | the registry accepts an address without code |
| `test_social_verifierCantBeZero` (R5-A4-6) | the registry accepts address(0) |
| `test_versions_registerNeedsCodeAtEveryAddress` (R5-A4-7) | `register` accepts an EOA |

The 13 coverage tests pass on both. Same result as HANDOFF §5 step 26 states.

**Deploy on an anvil fork.** `anvil --fork-url https://rpc.mainnet.chain.robinhood.com` (chain 4663, block 83,660,350); deployer = anvil account 0, `SAFE` / `RELAY` / `X_LINK_KEY` / `TWEET_CHECKER` = anvil accounts 1–4, `SALE_START` = fork time + 2 days, `AUDIT_LINK` set, `AIRDROP_CLAIMS=cache/precheck6/claims-120.json` (120 wallets, 48M, built with `airdrop/snapshot.py`'s own `build_tree`; generator in the appendix). No oracle signer step exists in the script, as D-86 wants.
- Simulation: estimate **57.41M gas**. Broadcast (`--private-key`, `--broadcast --slow`): **51 transactions**, all from the EOA, all succeeded; **43.47M gas used** (43.25M at PRECHECK-5; the D-86 checks add a little), largest 5.29M.
- Order (1-based): `setLaunchesPaused(true)` tx 10, `CreatorVault` created tx 11 and `initialize(curve, hook)` tx 21 (after the hook, so `hook.poolManager()` answers), `VersionRegistry.activateManually` tx 29 and its handoff tx 30, the splitter's final recipients tx 43, `setLaunchesPaused(false)` tx 44, `FeeSplitter` / `PadConfig` handoffs tx 45 / 46.
- Checked with `cast` afterwards (70 checks): the 13 owned contracts have the D-57 owners (48 h: `PadConfig`, `SwarmBudget`, `SocialRegistry`, `GrowthFund`, `MarketController`, `RewardDripper`, `PadBuyer`, `AirdropDistributor`; 7 days: `FeeSplitter`, `AttestationVerifier`, `VersionRegistry`, `WorkerFund`, `StakedPONDPAD`); `transferOwnership` by the owning timelock reverts `OwnerIsFixed`; market hook owner = `MarketController`, `sinkAdmin` = 7-day timelock, `migrator` = Safe; delays 172,800 / 604,800 s; on both timelocks the Safe proposes and cancels, anyone executes, each timelock is its own admin and the deployer holds none of the four roles; launches unpaused, guardian = Safe; `CreatorVault.curve()` / `hook()` = the curve and the hook, `hook.poolManager()` = the PoolManager; social verifier = `X_LINK_KEY`, airdrop checker = `TWEET_CHECKER`, growth relay / granter = `RELAY` / Safe, budget relay = `RELAY`; vesting beneficiary = Safe, reserve beneficiary = 48 h timelock; dripper vault = sPONDPAD, buyer and market rewards → dripper, burn sink = burner; `maxRefStep` 100, `MAX_FUND_DEVIATION_TICKS` 100; splitter recipients `PadBuyer` / `WorkerFund` / `GrowthFund` / Safe at 4,000 / 2,500 / 2,000 / 1,500; $PONDPAD above IMD; staking `powersExpireAt` = `SALE_START` + 365 days; launch settings as D-76 (0.35 IMD fee, 4,000 IMD target, 1% graduation fee, 70% snipe tax over 80 s, 80 s max-buy window at 2%).
- **Oracle and versions (D-86):** `AttestationVerifier.signerCount()` = 0; `currentVersion` = 1, activated at deploy with the `AUDIT_LINK` as its audit reference; `manualActivationRetired` false; `retireManualActivation()` by the 7-day timelock reverts `CannotRetire`.
- **Supply:** deployer 0, sale 900M, airdrop 50M, vesting 20M, `LiquidityReserve` 30M; airdrop root = the claims file's.
- Then: a coin launched with 0.02 ETH and a dev buy (3% tax: half holders, half swarm budget); another wallet bought with 0.05 ETH after the 80 s window. **R5-A1-1 on the live wiring:** `setRecipient(coin, x)` reverts `InvalidRecipient` for the vault, the curve, the hook and the PoolManager, a second coin can't name the first, and a launch naming the vault as `feeRecipient` reverts `InvalidRecipient`. The creator then routed its fees to holders (`setRecipient(coin, coin)`); its `setRecipient(coin, creator)` afterwards reverted `Unauthorized`. The keeper's dry pass listed `FeeSplitter.distribute`, `CreatorVault.claim(coin)` and `SwarmBudget.sweepToHolders(coin)`; sending those two funded the coin's holder stream with exactly the vault's and the budget's balances (0.107903570075526759 + 0.323710710226580279 = 0.431614280302107038 IMD), ending 604,800 s later. `deployments/4663.json` and `broadcast/` deleted afterwards.

## 2. Round-5 fixes: each path against its fix

- **R5-A2-1 (`MarketController.fundInventory`):** `|hook.currentTick() − hook.referenceTick()| ≤ 100` is checked before anything is pulled. `referenceTick()` returns the stored `refTick` once the block has had a swap (the first swap of the block wrote the caught-up value), else `refTick` stepped toward an earlier block's close; nothing in the current block moves it (probe: a pump in the block leaves it equal). The add's own unlock can't be nested in an outside unlock (`AlreadyUnlocked`), and nothing between the check and the add can swap: both tokens are plain ERC-20s and the caller is the timelock. A reverted `execute` leaves the operation Ready (OpenZeppelin marks it done only on success), so a refusal only delays. The one-block sandwich of the round-5 report is closed (the regression test). **The multi-block case is P6-1.**
- **R5-A2-2 / A3-1 (`migrate`):** reads `old.referenceTick()` before `closeMarket` (which settles claims and closes the backstop, neither a swap). Then `openMarket` on the new hook sets `refBlock` to this block and `curBlockTick` to the migration price (the new pool opens at `old.currentSqrtPriceX96()`), and `inheritGuards` writes the old reference into `refTick`. In the migration block the new `referenceTick()` is that value; afterwards it steps toward the migration price, which is the old pool's last close (no swap since) or this block's running tick, exactly what the old hook would have used. A pump in the migration block before `migrate` doesn't move it (probe, R1-A2-2 kept). `inheritGuards`' range check holds since the value lies between two valid ticks; `_copyPolicy` runs after it, and nothing swaps in between.
- **R5-A1-1 (`CreatorVault`):** `_checkRecipient` runs in `register` and `setRecipient`. `hook` is `PadHook`, whose `poolManager` is an immutable getter, and `register` can only be called by the curve, which exists only after `initialize(curve, hook)`, so the extra static call adds no failure path besides the five intended refusals (anvil run above). `recipientOf[x] != 0` only for registered coins; coins are CREATE2'd from `keccak256(creator, salt)`, so no one can turn someone else's chosen recipient into a coin. Naming the coin itself still works at launch and later.
- **R5-A3-2, A3-3, A3-5 (`make_staking.py`):** `rescueERC20` refuses `imd` (the streamed $PONDPAD) and `vault`; `_withdraw` refuses `to` = address(0) or the vault, after `whenNotPaused` and before the hold check, so pauses work as before and normal exits are unchanged (210 tests, the invariant test). The dropped declarations are gone and banned in the generator; the upstream power sentence is replaced. Generated outputs reproduce byte for byte.
- **R5-A3-4 (`PadBuyer`):** `limitTick <= MIN_TICK` → `MIN_TICK + 1`, whose sqrt price v4 accepts; buys lower the tick only, so no `MAX_TICK` clamp is needed.
- **R5-A4-3 (`SocialRegistry.unlink`):** the nonce moves iff the caller is the verifier, the owner, or the recipient removing its own live link (`linkedBy` read before the delete). A stateful fuzz probe (5,000 runs × 40 random steps of recipient changes, links and unlinks by the three possible recipients, a stranger, the verifier and the owner) checks that rule at every unlink, that no caller other than the recipient, the verifier and the owner ever moves the nonce, that refusals happen only for a live link by an outsider or when nothing is linked, and that a voucher the current recipient holds survives any stale-link clear. The old recipient can't void the new recipient's voucher (it can only clear a stale link, which never moves the nonce, and `link` needs the current recipient).
- **R5-A4-5, A4-6, A4-7:** `VersionRegistry` constructor / `setVerifier` need code; `SocialRegistry` constructor / `setVerifier` refuse address(0); `register` needs code at all five addresses. `Deploy.s.sol` deploys the verifier and the five contracts first (anvil run).
- **Docs only:** R5-A2-3 (`setCapFloor` NatSpec, ARCHITECTURE §5.4.2, THREAT-MODEL §3), R5-A4-1 / A4-2 (NatSpec, THREAT-MODEL §3, ARCHITECTURE §5.5), R5-A1-2 (the five A1 rows): present. Every test the round-5 rows name exists.

## 3. The questions asked

- **Can someone hold the price more than 100 ticks from the reference to block `fundInventory`, and at what cost?** Holding still doesn't work: the reference catches up `maxRefStep` (100) ticks per Ethereum block, so a fixed displacement of d ticks blocks only about (d − 100) / 100 blocks, after which the add runs at the displaced price (P6-1). To keep it blocked the griefer must swing the price across the reference every block. Probe: closing each block 250 ticks past the reference, alternating sides, cost the griefer **33.54 IMD over 20 Ethereum blocks** (~1.7 IMD per block, ~500 IMD per hour, ~12,000 IMD per day at the 1% fee and the opening depth), and every other trader can trade against the swings. It is also beaten outright: anyone may execute, so one transaction (a helper contract) can swap the price back into the band and execute the queued add (probe: the add runs in the same block). And an Arbitrum Orbit chain normally has no public mempool, so the swings can't be timed against the execution. Before D-86 the same griefing only delayed too (a reverted execution stays executable).
- **Does a pump held over several blocks get around the band?** Yes: **P6-1**.
- **Is `referenceTick()` read safely in `migrate`?** Yes (§2).
- **Does `CreatorVault`'s `hook.poolManager()` call add a launch failure path?** No (§2; anvil run). Note for standalone harnesses: a vault initialized with a hook that has no `poolManager()` (round 5's judge used `makeAddr("hook")`) now reverts every `register`; only `Deploy.s.sol` initializes the real vault, and it passes `PadHook`.
- **Does the R5-A4-3 rule hold for every caller and recipient sequence?** Yes (§2, fuzz probe).
- **Does the no-exit check interact badly with pauses or the invariant tests?** No. `whenNotPaused` runs first; the check only adds two receivers that were never valid; the invariant handler exits only to its own actors, so it neither trips nor exercises the check (P6-3).
- **Is anything in the jobs' "changed since round 5" lines or THREAT-MODEL inconsistent with the code?** The A1, A3 and A4 lines match the code. A2's "can't run it inside a pump of its own" and THREAT-MODEL invariant 11 overstate the band (P6-1); ARCHITECTURE §5.4.1 and §5.6 likewise. DECISIONS D-86 words R5-A4-3 as planned, not as implemented (P6-2). The rest of THREAT-MODEL (invariants 13, 14, 18, 19, §1, §3) matches the code.

## 4. Problems

### P6-1 (Low): the `fundInventory` band holds for one block, not for a pump held over many (R5-A2-1 fix narrower than documented)
`src/MarketController.sol:273` (the band), `audit/THREAT-MODEL.md` invariant 11, `ARCHITECTURE-v1.md` §5.4.1 (`fundInventory` row) and §5.6, `audit/jobs/A2-market.md` ("changed since round 5").

The band compares the price with `referenceTick()`, which moves `maxRefStep` ticks per Ethereum block toward the last close. A pump that stands as the close for k blocks drags the reference 100·k ticks (at the default step), so after about (pump − 100) / 100 blocks the band admits the queued add at the pumped price, and the round-5 sandwich (pump, add, dump) works as before. Anyone can still execute the queued call and choose the block. Probe (the judge's setup: day 8, the 1% fee, the 30M reserve, liquidity sized at the proposal price, the attacker pumps as far as the IMD maximum allows, then nobody trades until the add runs):

| IMD maximum / IMD needed | Pump | Blocks held (~12 s each) | Attacker's IMD result |
|---|---|---|---|
| 1.02× | 376 ticks, 162 IMD | 3 | −2.93 |
| 1.1× | 1,887 ticks, 845 IMD | 18 | −9.30 |
| 1.2× | 3,627 ticks, 1,699 IMD | 36 | −5.73 |
| 1.3× | 5,228 ticks, 2,553 IMD | 52 | +8.10 |
| 1.4× | 6,710 ticks, 3,406 IMD | 67 | +30.15 |
| 1.5× | 8,090 ticks, 4,260 IMD | 80 (~16 min) | **+58.90** |
| 2× | 13,844 ticks, 8,528 IMD | 138 (~28 min) | **+269.75** |

At `maxRefStep` 500 (the most the documented owner rule allows, `PadBuyer.maxDeviationTicks` ≤ 500) the 1.5× hold takes 16 blocks (~3 minutes), at 2,000 (the setter's maximum) 4 blocks; the result is the same. A control: one trader selling a quarter of what the attacker bought, in the pump's second block, left the attacker **−717 IMD**.

So the band turns a risk-free one-transaction sandwich into holding a ~1.8–2.2× $PONDPAD price for 50–140 Ethereum blocks against every holder (the sale's buyers, stakers, bots) and the Safe, which can cancel the queued operation. It pays only with generous IMD slack (from about 1.3× at the 1% fee) and a market that doesn't react.

Where the threshold comes from: moving a full-range pool's price by a factor s² takes about x·(s − 1) IMD (x = the pool's IMD), so the pump and dump pay about 2 · fee · x · (s − 1) in fees, while the added position's impermanent loss, which is what the attacker takes, is about (L_add / L_pool) · x · (s − 1)². The hold pays once s − 1 > 2 · fee · L_pool / L_add: at the 1% fee and the 30M reserve against the opening pool (L_add / L_pool ≈ 0.1) that is s ≈ 1.2, which the probe brackets (−5.73 at 1.2×, +8.10 at 1.3×). The 3% fee of the first week only raises it; a pool shrunk by trims, which is when the reserve is likely to be added, lowers it. The tokens' maximum bounds the other side the same way: with it at exactly the reserve and the liquidity sized for it, the add refuses any price cheaper than the proposal's. Low by THREAT-MODEL §4 (bounded by the slack the proposal leaves, needs a dead market). But the docs claim more: invariant 11 says whoever executes "can't run it inside a pump of its own and take value from the position", ARCHITECTURE §5.6 "so nobody can execute the queued add inside a pump and dump of their own", and the A2 line the same. A round-6 auditor who holds the pump for 80 blocks has a literal break of a §2 invariant (rated at least High), likely reported as "R5-A2-1 fix incomplete".

- **Reproduction:** appendix, `test_probe_heldPumpGetsAroundTheBand` (and `…AtLargerRefSteps`, `…AgainstOneSeller`).

**Fix options:**
- **(a) Document it and add an owner rule (no contract change; Claude's recommendation).** THREAT-MODEL invariant 11: the band stops a pump made in the block the add executes; a price held across blocks moves the reference `maxRefStep` per block (as for `PadBuyer`), and the add can then run at that price, so the proposal's maxima bound the rest: the 48 h owner proposes with each maximum's slack over what the add needs at the proposal price below 2 · fee · L_pool / L_add (1.2× for the 30M reserve against the opening pool at the 1% fee; less once the pool has shrunk; the IMD maximum bounds a pump, the $PONDPAD maximum a dump, the mirror case) and the Safe cancels a queued add when the price leaves that band. THREAT-MODEL §3 lists it as deliberate (like the `maxRefStep` rule of D-84); ARCHITECTURE §5.4.1 / §5.6 and the A2 job line say "in the block it executes". The probe's numbers back the 1.2× figure for today's pool (a hold of any length loses at 1.2×). `MarketController.sol` stays as audited (its NatSpec already says "all in one transaction").
- **(b) Enforce it in code.** `fundInventory` takes the proposal's price band (for example `minSqrtPriceX96` / `maxSqrtPriceX96`, or a tick and a fixed tolerance) and refuses outside it, besides the reference band: D-86's option C, which the user didn't choose then. It enforces what (a) asks of the owner, narrows a 48 h owner power further, changes `fundInventory`'s signature (only the timelock calls it), and needs a regression test that fails on `ffac7be` (the held pump) and a round-6 auditor's look at new code.

### P6-2 (Info): ledger and decision-log text
- **(a)** `audit/FINDINGS.md` row R2-A3-7 names `test_deploy_airdropListMustFitTheAirdrop`, which `35aa6b1` (D-80, R3-A3-3) replaced by `test_deploy_airdropRootMustMatchTheClaims` (it checks the 50M refusal, "airdrop list exceeds 50M", and the root rebuild). A3's area.
- **(b)** Twelve takeover rows marked fixed name tests removed with `CTOModule` in `c85b6a9` (D-82) and carry no note: R1-A4-2, R1-A4-3, R1-A4-5, R1-A4-9, R1-A4-10, R1-A4-12, R2-A4-5, R2-A4-6, R2-A4-7, R3-A4-7, R3-A4-8, R3-A4-16 (P4-1 to P4-3 have the section's note). Their location column names `CTOModule.sol` or `CTO-RULES.md`, so the reader can tell, but it is the R5-A1-2 class (round 5's A1 judge flagged the A1 rows) in A4's area.
- **(c)** DECISIONS D-86's decision row says R5-A4-3's nonce moves when "the caller made the link". As implemented (HANDOFF §5 step 26, FINDINGS R5-A4-3, the code) it moves for the recipient's own live link only; clearing a stale link never does, whoever clears it, so the old recipient can't void the new recipient's voucher. The jobs tell auditors to read DECISIONS.

**Fix:** (a) name the current test in R2-A3-7; (b) one line above the Findings table: rows located in `CTOModule.sol`, `CTO-RULES.md` or `ctoSetRecipient` concern code removed with community takeovers (D-82, `c85b6a9`), their tests went with it, and they stay as the record; (c) add the implemented rule to D-86 ("implemented with a refinement: …"). Docs only.

### P6-3 (Info, optional, tests only): the staking invariant test doesn't try the refused exits
`test/StakingInvariant.t.sol` (`StakingHandler.withdraw` / `redeem` exit only to the acting staker, inside `try`). R5-A3-3's refusal is covered by `test_vault_noExitToAddressZeroOrTheVault` only, and a regression that made every exit revert would pass the invariant run silently (unit tests would still catch it). Round 5's A3 judge listed "an exit to address(0)" among the edges the suite lacked.

**Fix (optional):** a handler action that tries `redeem` / `withdraw` to address(0) and to the vault (asserting they never succeed: `pondpad.balanceOf(address(0))` never grows), and a count of successful exits logged in `afterInvariant` next to the drip count.

## 5. Recommendation

No contract bug, nothing Critical, High or Medium, and every round-5 path is closed. Round 6 generated at `ffac7be` as it is would be safe for funds. Still, round 6 isn't generated yet, P6-1's wording is a likely "fix incomplete" finding (with a §2 invariant literally broken), and P6-2 is the kind of ledger row a judge reports as Info. Since the user hopes round 6 is the last, the lean is to fix first, without touching `src/`:

1. P6-1 option (a) (THREAT-MODEL invariant 11 and §3, ARCHITECTURE §5.4.1 / §5.6, the A2 job line, HANDOFF §5a's operating note), P6-2 (a)–(c), and optionally P6-3 (a test-only change).
2. All tests, commit, push, then `python3 launchpad/audit/make_jobs.py round 6 --check` at the new pushed ledger commit.

The in-scope files (`src/`, `script/`, `upstream/`) stay exactly as audited-fixed in `d65698e`. If the user prefers the rule enforced in code, P6-1 option (b) is a small `MarketController` change with a regression test failing on `ffac7be`, at the cost of new code in round 6.

## Appendix: probes (run at `ffac7be`; all pass, i.e. each statement above holds)

Generate the claims list, then copy the test to `contracts/test/scratch/R6Probe.t.sol` (untracked) and run `forge test --match-path test/scratch/R6Probe.t.sol -vv` (~2.5 min to compile). Delete both before committing.

```python
# make_claims.py: writes contracts/cache/precheck6/claims-120.json with airdrop/snapshot.py's own build_tree (cache/ is ignored).
import json, os, sys
sys.path.insert(0, "launchpad/airdrop")  # run from the repository root
from snapshot import build_tree, keccak

out = "launchpad/contracts/cache/precheck6"
os.makedirs(out, exist_ok=True)

def addr(i):
    return "0x" + keccak(b"precheck6 wallet %d" % i)[12:].hex()

entries = [(addr(i), 400_000 * 10**18) for i in range(120)]
root, _dump, claims = build_tree(entries)
with open(os.path.join(out, "claims-120.json"), "w") as f:
    json.dump({"root": root, "total": str(sum(v for _, v in entries)), "claims": claims}, f)
print(root, len(claims))  # 0x4de4f917…51cb4 120
```

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {MarketTest} from "../Market.t.sol";
import {MarketController} from "../../src/MarketController.sol";
import {PadMarketHook} from "../../src/PadMarketHook.sol";
import {CreatorVault} from "../../src/CreatorVault.sol";
import {SocialRegistry} from "../../src/SocialRegistry.sol";

/// @dev PRECHECK-6 probes on the R5-A2-1 band (`MarketController.fundInventory`) and the R5-A2-2 migration read.
contract R6MarketProbeTest is MarketTest {
    struct Proposal {
        uint128 liq;
        uint256 imdNeeded;
    }

    /// @dev The judge's setup: day 8 (1% fee), the 30M reserve, liquidity sized at today's price.
    function _setUpProposal() internal returns (Proposal memory p) {
        _graduate();
        vm.warp(START + 30 minutes + 8 days);
        _nextBlock();
        uint160 spot = market.currentSqrtPriceX96();
        int24 spacing = market.tickSpacing();
        p.liq = controller.fullRangeLiquidity(spot, 1e30, 30_000_000e18, spacing);
        p.imdNeeded = SqrtPriceMath.getAmount0Delta(
            spot, TickMath.getSqrtPriceAtTick(TickMath.maxUsableTick(spacing)), p.liq, true
        );
        imd.mint(timelock, 1_000_000e18);
        pondpad.transfer(timelock, 30_000_000e18);
        vm.startPrank(timelock);
        imd.approve(address(controller), type(uint256).max);
        pondpad.approve(address(controller), type(uint256).max);
        vm.stopPrank();
        imd.mint(attacker, 100_000e18);
        vm.startPrank(attacker);
        imd.approve(address(swapper), type(uint256).max);
        pondpad.approve(address(swapper), type(uint256).max);
        vm.stopPrank();
    }

    /// @dev The lowest sqrt price (dearest $PONDPAD) at which the add still fits `maxImd` (0.1% margin).
    function _pumpLimit(Proposal memory p, uint256 maxImd) internal view returns (uint160) {
        uint160 sqrtU = TickMath.getSqrtPriceAtTick(TickMath.maxUsableTick(market.tickSpacing()));
        uint256 lq = uint256(p.liq) << 96;
        uint256 q = (maxImd * 999) / 1000;
        return uint160(lq / (q + lq / sqrtU));
    }

    function _tryAdd(Proposal memory p, uint256 maxImd) internal returns (bool ok) {
        vm.prank(timelock);
        try controller.fundInventory(p.liq, 30_000_000e18, maxImd) {
            ok = true;
        } catch {}
    }

    /// @dev Pump as far as `maxImd` allows, hold it with no other trade until the band admits the add, execute, dump.
    function _heldPump(Proposal memory p, uint256 maxImd) internal returns (int256 pnl, uint256 blocks, int24 pumped) {
        uint256 imdBefore = imd.balanceOf(attacker);
        int24 ref0 = market.referenceTick();
        _swapAs(attacker, true, 100_000e18, _pumpLimit(p, maxImd));
        pumped = market.currentTick();
        console2.log("pump ticks", int256(ref0) - int256(pumped));
        console2.log("pump IMD", imdBefore - imd.balanceOf(attacker));
        assertFalse(_tryAdd(p, maxImd), "refused in the pump's block");
        for (blocks = 1; blocks <= 400; blocks++) {
            _nextBlock();
            if (_tryAdd(p, maxImd)) break;
        }
        assertLe(blocks, 400, "the add never ran");
        _swapAs(attacker, false, pondpad.balanceOf(attacker), TickMath.MAX_SQRT_PRICE - 1);
        pnl = int256(imd.balanceOf(attacker)) - int256(imdBefore);
    }

    /// P6-1: a pump held over enough blocks drags `referenceTick()` along (maxRefStep per block), and the band then
    /// admits the add at the pumped price: the judge's sandwich pays again, if nobody trades against the pump meanwhile.
    function test_probe_heldPumpGetsAroundTheBand() public {
        Proposal memory p = _setUpProposal();
        uint256 snap = vm.snapshotState();
        uint256[7] memory slack = [uint256(1020), 1100, 1200, 1300, 1400, 1500, 2000];
        for (uint256 i; i < 7; i++) {
            vm.revertToState(snap);
            (int256 pnl, uint256 blocks,) = _heldPump(p, (p.imdNeeded * slack[i]) / 1000);
            console2.log("slack x1000", slack[i]);
            console2.log("  blocks held until the add ran", blocks);
            console2.log("  attacker IMD P&L (wei)", pnl);
            if (slack[i] >= 1500) assertGt(pnl, 0, "the held pump pays at 1.5x slack and more");
        }
    }

    /// P6-1 at the owner's larger steps: the 48 h owner may set maxRefStep up to 2,000 (the documented rule keeps it
    /// at or below PadBuyer.maxDeviationTicks, at most 500); the hold shrinks in proportion.
    function test_probe_heldPumpAtLargerRefSteps() public {
        Proposal memory p = _setUpProposal();
        uint256 snap = vm.snapshotState();
        int24[2] memory steps = [int24(500), 2_000];
        for (uint256 i; i < 2; i++) {
            vm.revertToState(snap);
            vm.prank(timelock);
            controller.setMaxRefStep(steps[i]);
            (int256 pnl, uint256 blocks,) = _heldPump(p, (p.imdNeeded * 3) / 2);
            console2.log("maxRefStep", int256(steps[i]));
            console2.log("  blocks held until the add ran", blocks);
            console2.log("  attacker IMD P&L (wei)", pnl);
            assertGt(pnl, 0);
        }
    }

    /// P6-1 control: a trader selling into the held pump (here 1/4 of what the attacker bought, at the pump's
    /// second block) leaves the attacker worse off than the plain sandwich.
    function test_probe_heldPumpAgainstOneSeller() public {
        Proposal memory p = _setUpProposal();
        uint256 maxImd = (p.imdNeeded * 3) / 2;
        uint256 imdBefore = imd.balanceOf(attacker);
        _swapAs(attacker, true, 100_000e18, _pumpLimit(p, maxImd));
        uint256 bought = pondpad.balanceOf(attacker);
        _nextBlock();
        _swap(false, bought / 4); // the trader holds 50M $PONDPAD
        uint256 blocks;
        for (blocks = 1; blocks <= 400; blocks++) {
            _nextBlock();
            if (_tryAdd(p, maxImd)) break;
        }
        _swapAs(attacker, false, pondpad.balanceOf(attacker), TickMath.MAX_SQRT_PRICE - 1);
        int256 pnl = int256(imd.balanceOf(attacker)) - int256(imdBefore);
        console2.log("blocks until the add ran", blocks);
        console2.log("attacker IMD P&L with one seller (wei)", pnl);
    }

    /// Griefing: keeping the price more than 100 ticks from the reference at every block. Holding still fails (the
    /// reference catches up 100 ticks a block); the griefer must swing the price across the reference each block.
    function test_probe_griefingTheBandCosts() public {
        Proposal memory p = _setUpProposal();
        uint256 maxImd = p.imdNeeded * 10;
        address g = attacker;
        pondpad.transfer(g, 15_000_000e18);
        int24 ref0 = market.referenceTick();
        uint256 imd0 = imd.balanceOf(g);
        uint256 pp0 = pondpad.balanceOf(g);
        uint256 blocks = 20;
        for (uint256 i; i < blocks; i++) {
            int24 ref = market.referenceTick();
            // Close the block 250 ticks past the reference, alternating sides.
            if (i % 2 == 0) _swapAs(g, true, 100_000e18, TickMath.getSqrtPriceAtTick(ref - 250));
            else _swapAs(g, false, 15_000_000e18, TickMath.getSqrtPriceAtTick(ref + 250));
            assertFalse(_tryAdd(p, maxImd), "refused while displaced");
            _nextBlock();
            int24 dev = market.currentTick() - market.referenceTick();
            assertTrue(dev > 100 || dev < -100, "still displaced at the next block's start");
            assertFalse(_tryAdd(p, maxImd), "refused at the next block's start");
        }
        // Back to the start and value the loss at the starting price.
        int24 cur = market.currentTick();
        if (cur < ref0) _swapAs(g, false, 15_000_000e18, TickMath.getSqrtPriceAtTick(ref0));
        else if (cur > ref0) _swapAs(g, true, 100_000e18, TickMath.getSqrtPriceAtTick(ref0));
        uint256 price = FullMath.mulDiv(
            uint256(TickMath.getSqrtPriceAtTick(ref0)), uint256(TickMath.getSqrtPriceAtTick(ref0)), 1 << 96
        ); // $PONDPAD per IMD, X96
        int256 dImd = int256(imd.balanceOf(g)) - int256(imd0);
        int256 dPp = int256(pondpad.balanceOf(g)) - int256(pp0);
        int256 ppInImd = dPp >= 0
            ? int256(FullMath.mulDiv(uint256(dPp), 1 << 96, price))
            : -int256(FullMath.mulDiv(uint256(-dPp), 1 << 96, price));
        int256 loss = -(dImd + ppInImd);
        console2.log("griefer loss over blocks (IMD wei)", loss);
        console2.log("blocks", blocks);
        assertGt(loss, 0);

        // The counter: anyone may execute, so one transaction can swap the price back into the band and run the add.
        _swapAs(g, true, 100_000e18, TickMath.getSqrtPriceAtTick(market.referenceTick() - 250));
        assertFalse(_tryAdd(p, maxImd));
        uint256 traderImd = imd.balanceOf(trader);
        _swapAs(trader, false, 30_000_000e18, TickMath.getSqrtPriceAtTick(market.referenceTick()));
        assertTrue(_tryAdd(p, maxImd), "restore-and-execute runs the add in the same block");
        console2.log("restorer's IMD from selling into the displacement (wei)", imd.balanceOf(trader) - traderImd);
    }

    /// R5-A2-2: a pump in the migration block, before `migrate`, can't move the inherited reference (R1-A2-2 kept),
    /// whether or not the block already had a swap.
    function test_probe_migrationReferenceIgnoresTheMigrationBlock() public {
        _graduate();
        _nextBlock();
        _swap(false, 20_000_000e18); // a fall
        for (uint256 i; i < 30; i++) {
            _nextBlock();
        }
        int24 before = market.referenceTick();
        _swap(true, 3_000e18); // a pump in the migration block
        assertEq(market.referenceTick(), before, "nothing in this block moves it");
        address addr = address(uint160(MARKET_FLAGS) | (uint160(0x8888) << 144));
        deployCodeTo(
            "PadMarketHook.sol:PadMarketHook",
            abi.encode(
                address(controller), IPoolManager(address(pm)), address(imd), address(pondpad), address(burner),
                dripper, uint256(1_500), uint256(1_000e18), int24(200)
            ),
            addr
        );
        vm.prank(slowTimelock);
        controller.approveMigration(addr);
        vm.prank(migrator);
        controller.migrate(addr);
        assertEq(PadMarketHook(addr).referenceTick(), before, "the caught-up reference, not the pumped spot");
    }
}

contract HookStub {
    address public poolManager = address(0xBEEF);
}

/// @dev R5-A4-3: random sequences of recipient changes, links and unlinks by every kind of caller. The nonce moves only
///      on a link, or an unlink by the verifier, the owner, or the recipient of its own live link.
contract R6SocialProbeTest is Test {
    uint256 internal constant KEY = 0xA11CE;
    CreatorVault internal vault;
    SocialRegistry internal social;
    address internal coin = makeAddr("coin");
    address[3] internal people;
    address internal stranger = makeAddr("stranger");
    address internal verifierAddr;

    function setUp() public {
        vm.warp(1_000_000);
        vault = new CreatorVault(makeAddr("imd"));
        vault.initialize(address(this), address(new HookStub()));
        verifierAddr = vm.addr(KEY);
        social = new SocialRegistry(address(this), address(vault), verifierAddr);
        people = [makeAddr("p0"), makeAddr("p1"), makeAddr("p2")];
        vault.register(coin, people[0]);
    }

    function _voucher(bytes32 h, address account, uint256 nonce) internal view returns (bytes memory) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                social.domainSeparator(),
                keccak256(abi.encode(social.LINK_TYPEHASH(), coin, h, account, nonce, uint256(2_000_000)))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    function testFuzz_probe_nonceMovesOnlyOnRevocations(uint256 seed) public {
        uint256 links;
        uint256 unlinks;
        for (uint256 step; step < 40; step++) {
            uint256 r = uint256(keccak256(abi.encode(seed, step)));
            address rec = vault.recipientOf(coin);
            uint256 n = social.nonces(coin);
            uint256 op = r % 3;
            if (op == 0) {
                address to = people[(r >> 8) % 3];
                if (to == rec) continue;
                vm.prank(rec);
                vault.setRecipient(coin, to);
                assertEq(social.nonces(coin), n, "a recipient change never moves the nonce");
            } else if (op == 1) {
                bytes32 h = keccak256(abi.encode("h", r));
                bytes memory v = _voucher(h, rec, n);
                vm.prank(rec);
                social.link(coin, h, 2_000_000, v);
                assertEq(social.nonces(coin), n + 1);
                links++;
            } else {
                uint256 c = (r >> 8) % 6;
                address caller = c < 3 ? people[c] : c == 3 ? stranger : c == 4 ? verifierAddr : address(this);
                address linker = social.linkedBy(coin);
                bool live = linker == rec;
                vm.prank(caller);
                try social.unlink(coin) {
                    unlinks++;
                    bool revocation = caller == verifierAddr || caller == address(this) || (caller == rec && live);
                    assertEq(social.nonces(coin), revocation ? n + 1 : n, "nonce rule");
                    // Whoever is not the recipient, the verifier or the owner can never move it.
                    if (caller != rec && caller != verifierAddr && caller != address(this)) {
                        assertEq(social.nonces(coin), n);
                    }
                } catch {
                    // Refused: a live link by a stranger or another person, or nothing linked.
                    assertTrue(linker == address(0) || (live && caller != rec && caller != verifierAddr
                        && caller != address(this)), "refused only when it should be");
                    assertEq(social.nonces(coin), n);
                }
            }
        }
        // A voucher the current recipient holds survives every stale-link clear by anyone but the verifier / owner.
        address cur = vault.recipientOf(coin);
        uint256 n2 = social.nonces(coin);
        bytes32 hh = keccak256("final");
        bytes memory held = _voucher(hh, cur, n2);
        if (social.linkedBy(coin) != address(0) && social.linkedBy(coin) != cur) {
            for (uint256 i; i < 3; i++) {
                if (social.linkedBy(coin) == address(0)) break;
                vm.prank(people[i]);
                try social.unlink(coin) {} catch {}
            }
            vm.prank(stranger);
            try social.unlink(coin) {} catch {}
        }
        vm.prank(cur);
        social.link(coin, hh, 2_000_000, held);
        console2.log("links / unlinks", links, unlinks);
    }
}
```
