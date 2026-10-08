# Check before audit round 5 (8 Oct 2026)

Claude's own check of the D-83 fixes and the D-82 takeover removal (`c85b6a9`) before the user submits round 5, at code commit `881abb7` (where round 5 is generated). Branch head at the check: `87547c4`; `881abb7` → `87547c4` changes only docs and `audit/rounds/5/`, nothing in scope (`git diff 881abb7 87547c4 -- launchpad/contracts/src launchpad/contracts/script launchpad/contracts/upstream launchpad/audit/jobs launchpad/audit/make_jobs.py` is empty). Everything was re-run, and every round-4 finding's path was read against `git diff 38ad442 881abb7 -- launchpad/contracts`.

**Result: no contract problem.** Every code fix closes its round-4 path completely and opens no new one; the takeover removal is complete; the deploy, the keeper and the generators work. Four small problems, none in contract logic, all open for the user (ledger rows in `FINDINGS.md`, "Checks before a round"):

- **P5-1 (Low, test only):** `testFuzz_market_capInvariantAtBothFeeLevels` fails on about 7% of runs: the test trader runs out of $PONDPAD. Round-5 auditors run the suite and will likely see it.
- **P5-2 (Info, coverage):** R4-A3-9 listed `PadBuyer` through a migrated hook as untested; no test was added. It works (probe).
- **P5-3 (Low):** `Deploy.s.sol`'s 100-wallet check (R4-A3-4) counts the claims file's keys, not distinct wallets.
- **P5-4 (Info, docs):** one stale ARCHITECTURE row (pre-D-79), two takeover-era comments, a sink THREAT-MODEL §3 doesn't name, a stale ROADMAP sentence (fixed here, not read by the jobs).

Recommendation in §5: fix them (tests, docs and a few lines in `Deploy.s.sol`) and regenerate round 5 before submitting; submitting `881abb7` as it is would also be safe for funds.

## 1. What was run

| Check | Result |
|---|---|
| Foundry 1.5.1 from the release binaries (HANDOFF §3); `forge build` | 9 min (solc 546 s, via-IR), no errors |
| Local `forge test --no-match-contract Fork` | **182 / 182**. The first run was 181 / 182: `testFuzz_market_capInvariantAtBothFeeLevels` failed on its random seed (P5-1). 20 more full runs with fresh seeds (`--fuzz-seed`, `cache/fuzz` cleared each time): 182 / 182 each. That test alone, 100 fresh-seed campaigns: 7 failed |
| Mainnet fork `FORK_RPC=https://rpc.mainnet.chain.robinhood.com forge test --match-contract Fork` | **9 / 9** (`Fork.t.sol` 5, `DeployFork.t.sol` 4), first try. The command reports 11: the 2 `TestnetFork` tests match `Fork` too and return early without `TESTNET_RPC` |
| Testnet fork `TESTNET_RPC=https://rpc.testnet.chain.robinhood.com forge test --match-contract TestnetFork` | **2 / 2**, first try |
| Generators: `python3 upstream/make_fork.py`, `python3 upstream/make_staking.py` (in a worktree of `881abb7`) | Byte-identical to `src/PadMarketHook.sol` (sha256 `176417ec…ecdf4`), `src/StakedPONDPAD.sol` (`5d803ee6…4c6526`), `src/RewardDripper.sol` (`75dc1259…f3af3`) |
| Contract sizes (runtime / initcode, from the build) | `PadMarketHook` **23,089** / 24,798 bytes: **1,487 bytes** under the 24,576 limit. Next: `PadHook` 13,239, `MarketController` 12,077, `PadLens` 11,387 |
| `make_jobs.py round 5 --commit 881abb7` (in a worktree of `881abb7`, without `--check`) | Identical to the committed `audit/rounds/5/` (38 files, 9,839 lines); the scope check (every in-scope file in an area's FILES) passes |
| Fails-before (below) | **17 of 182 fail on `38ad442`**, each on what it asserts; all pass on `881abb7` |
| `Deploy.s.sol` simulation and broadcast on an anvil mainnet fork (below) | 51 transactions, all succeeded; every check below as expected |
| `keeper/keeper.mjs` | `node --check` passes; one `--once --dry` pass against the anvil deployment (below) |
| Probes (appendix) | All four behave as described in §4 |

**Fails-before.** Worktree of `38ad442`, `lib/` copied (not symlinked; the submodules' `.git` pointer files deleted in the copy), `881abb7`'s `test/` copied in except `DeployFork.t.sol` and `TestnetFork.t.sol` (the worktree keeps its own, which still pass `ctoRules`), and only three compile-time stand-ins: a two-address `CreatorVault.initialize(curve, hook)` wired as the old test base did (no CTO module), `error InvalidReceiver()` in `StakedPONDPAD`, an empty `PadMarketHook.referenceTick()`. Run with `--fuzz-seed 1`. The 17 failures: `test_holderTax_soleHolderRouterTradeKeepsOthersTax` (R4-A1-1, "the others' tax goes to holders: 0"), `test_curve_sellEventNamesTheSeller` (A1-2), `test_holderTax_coinsOwnAddressEarnsNothing` (A1-3), `test_market_capFloorCantLiftTheCap` (A2-1), `test_market_collectFeesBurnsTrimmedTokens` (A2-2), `test_vault_noSharesForAddressZeroOrTheVault`, `test_vault_transferToZeroKeepsHoldBookkeeping` (updated) and `StakingInvariantTest` ("no unredeemable shares", A3-1), `test_buyer_buysAfterAGenuineRiseAndQuietBlocks` (`PriceOutOfRange`) and `test_market_referenceTickIsWhatTheNextSwapSets` (A3-3), `test_deploy_airdropListNeedsAHundredWallets` (A3-4), `test_vault_cantRescueItsOwnShares` (A3-5), `test_buyer_minChunkCantBeZero` (A3-7), `test_airdrop_delegatedEoaSignaturesStillCount` (`BadSignature`) and `test_social_delegatedEoaVerifierSignsVouchers` (`BadVoucher`) (A3-8), `test_social_strangerClearDoesNotVoidTheNewRecipientsVoucher` (A4-6), `test_holders_routingIsFinal` ("no takeover module": the old vault still has `ctoModule()`). The coverage tests pass on both. Same result as HANDOFF §2 states.

**Deploy on an anvil fork.** `anvil --fork-url https://rpc.mainnet.chain.robinhood.com` (chain 4663); deployer = anvil account 0, `SAFE` / `RELAY` / `X_LINK_KEY` / `TWEET_CHECKER` = anvil accounts 1–4, `SALE_START` = fork time + 2 days, `AUDIT_LINK` set, `AIRDROP_CLAIMS=cache/precheck5/claims-120.json` (120 wallets, 48M, built with `airdrop/snapshot.py`'s own `build_tree`; generator in the appendix). No `CTO_RULES`.
- Simulation: estimate **57.13M gas** (~0.00229 ETH at 0.04 gwei). Broadcast (`--private-key`, `--broadcast --slow`): **51 transactions**, all from the EOA, all succeeded; **43.25M gas used**, largest 5.29M (HANDOFF §5a says 51, ~57.3M, 43.2M: matches).
- Order (1-based): `setLaunchesPaused(true)` tx 10, `CreatorVault` created tx 11 and `initialize(curve, hook)` tx 21, `VersionRegistry.activateManually` tx 29 and its handoff tx 30, the splitter's final recipients tx 43, `setLaunchesPaused(false)` tx 44, `FeeSplitter` / `PadConfig` handoffs tx 45 / 46.
- Checked with `cast` afterwards: the 13 owned contracts have the D-57 owners (48 h: `PadConfig`, `SwarmBudget`, `SocialRegistry`, `GrowthFund`, `MarketController`, `RewardDripper`, `PadBuyer`, `AirdropDistributor`; 7 days: `FeeSplitter`, `AttestationVerifier`, `VersionRegistry`, `WorkerFund`, `StakedPONDPAD`); the timelock's `transferOwnership` / `renounceOwnership` revert `OwnerIsFixed`, the deployer's `Unauthorized`; market hook owner = `MarketController`, `sinkAdmin` = 7-day timelock, `migrator` = Safe; delays 172,800 / 604,800 s; on both timelocks the Safe is proposer and canceller, anyone executes, the deployer holds no role; `launchesPaused` false, guardian = Safe; `CreatorVault.curve()` / `hook()` = the curve and the hook, `ctoModule()` reverts (no such function); $PONDPAD above IMD; deployer $PONDPAD 0, sale 900M, airdrop 50M, vesting 20M, `LiquidityReserve` 30M; airdrop root = the claims file's; version 1 current; splitter stakers = `PadBuyer`.
- Then on that deployment: a coin launched with ETH and a dev buy (3% tax: half holders, half swarm budget); another wallet bought; the creator called `setRecipient(coin, coin)`; its `setRecipient(coin, creator)` afterwards reverted `Unauthorized`; the keeper's dry pass listed `FeeSplitter.distribute`, `CreatorVault.claim(coin)` and `SwarmBudget.sweepToHolders(coin)`; sending those two funded the coin's holder stream with exactly the vault's and the budget's balances (0.0902 + 0.2705 = 0.3607 IMD, ending ~7 days later). `deployments/4663.json` and `broadcast/` deleted afterwards.

## 2. Round-4 fixes: each path against its fix

- **R4-A1-1 (`PadRouter._flushOthers`):** before each pool trade (buy, and `_sell`, which `sellForWithPermit` shares) the router reads `hook.pending(coin).holders` and, if non-zero, calls the permissionless `hook.flush(coin)` (trader 0), which pays other traders' holder tax to whoever holds now, exactly as anyone could already do. The trade's own tax then accrues and `flushFor(coin, msg.sender)` applies the sole-holder rule to just that. Nothing else can become pending in between: the router's swap can't run inside an outside unlock (`unlock` reverts) and `flushFor` runs after the router's unlock has ended. Protocol, creator and swarm fees skip the pre-flush, which is fine: the rule only concerns the holder part.
- **R4-A1-2:** `sell` emits `trader` (the router passes `msg.sender`).
- **R4-A1-3:** `isExcluded(address(this))` is a pure function of the address, so `eligibleSupply`, the corrections and `withdrawableDividendOf` stay consistent; the coin never holds its own tokens otherwise (the supply is minted to the curve). Tokens sent to the coin are now a plain sink (P5-4).
- **R4-A2-1:** `setCapFloor` refuses a floor above `hook.inventoryCap()`, so the hook's lift branch is unreachable from the controller; `openMarket` and `migrate` set the floor directly (the new cap is at least the floor, then `inheritGuards` raises it to the old cap). Raised to the cap, the floor only pins the ratchet (as `setCapDecay(0)` can, reversibly). Before the market opens the cap is 0, so every `setCapFloor` reverts: harmless, since `openMarket` always sets `capFloor = initialCapFloor` and a pre-open setting was overwritten at open anyway.
- **R4-A2-2:** `collectFees` calls `PadBurner.burn()`, which returns 0 when empty, so fee collection can't be blocked by it. It burns the controller's fixed burner; the hook's `burnSink` is that burner unless the 7-day `sinkAdmin` points it elsewhere (a listed power).
- **R4-A3-1 / A3-5 (`make_staking.py`):** `InvalidReceiver` in `_deposit` (Solady's `deposit` and `mint` both go through it) and in the `transfer` / `transferFrom` overrides (Solady's ERC20 has no other public way to move a balance; `permit` only sets allowances); burns go through `_burn`, unaffected; `rescueERC20` refuses `address(this)`. Shares parked elsewhere (e.g. `0xdead`) are the documented R1-A3-3 class.
- **R4-A3-3 (`make_fork.py`, `referenceTick()`):** it reads `refTick`, `refBlock`, `curBlockTick` and `maxRefStep`. `refTick` and `refBlock` are written only by `_observeTick` (in `afterSwap`) and `openMarket`, `refTick` also by `inheritGuards` (migration, before the new hook's first swap); `curBlockTick` by `_observeTick` and `openMarket`. If the current block has had a swap, the view returns the stored `refTick`, which that swap set. If not, its target is the close of an earlier block, and the only thing in this block that could change the inputs is a swap, which first stores exactly the value the view returned (`_observeTick` calls the view). So nothing in the current block moves it, and `PadBuyer`'s own swap writes what it read (asserted by the tests and probe 2). `maxRefStep` is a 48 h setting, never changed inside `buy()`. Two notes, neither a problem: `migrate` passes the old hook's stored `refTick`, not `referenceTick()`, so a catch-up pending at migration restarts from the migration block (slower, never faster); the backstop floor decay still reads the stored `refTick` before `_observeTick`, as upstream.
- **R4-A3-4:** `airdropRootFromClaims` refuses fewer than 100 keys; `_airdropRoot` requires `AIRDROP_CLAIMS` on 4663. It counts keys, not wallets (P5-3).
- **R4-A3-7:** `minChunk_ == 0` refused; the constructor default is 1e18.
- **R4-A3-8 (`_validSignature` in `AirdropDistributor` and `SocialRegistry`):**
  - Signer 0 returns false. `tryRecover` returns 0 for a bad signature, so a bad signature can never match a zero signer; `setVerifier` refuses 0 anyway.
  - Own key first (`ECDSA.tryRecoverCalldata`, 65- and 64-byte forms), then ERC-1271 (`isValidERC1271SignatureNowCalldata`: an account without code returns no data, so false). An EIP-7702 account's own key works whatever its delegate does.
  - Malleability: Solady's `tryRecover` doesn't refuse high-s, but no signature is used as an identifier. Replays are stopped by nonces (`nonces[account]++` before the check; per-coin and per-wallet nonces in `SocialRegistry`) and by `initiated` / `handleUsed` / `tweetUsed`, so a second encoding of a signature can't be used twice.
  - Contract signers: an ECDSA signature can't recover to a contract's address without its key; their ERC-1271 decides, as before.
- **R4-A4-6:** the nonce moves only when the caller is the recipient, the verifier or the owner; a stranger reaches `unlink` only while `linkedBy != recipient`. Vouchers bind `account = msg.sender` and `link` needs the current recipient, so an unspent old voucher helps nobody but that recipient. A new recipient that clears the stale link itself does bump its own nonce (self-inflicted; `link` overwrites a stale link anyway).
- **Docs only:** R4-A1-4 (THREAT-MODEL §3 sinks), R4-A3-2 (§3, the `syncRewards` NatSpec, ARCHITECTURE §5.3), R4-A3-6 (invariant 13, `PadBuyer` NatSpec): all present.
- **Coverage:** R4-A2-3: all six paths have tests. R4-A3-9: every listed edge has a test except `PadBuyer` through a migrated hook (P5-2). All 31 tests named in the round-4 rows exist.

## 3. The takeover removal (D-82)

- **Only the recipient changes the recipient.** `recipientOf` has two writers: `register` (the curve only; the curve's `register` runs only from the factory, right after it CREATE2-deploys a fresh coin, so never for an existing coin) and `setRecipient` (`msg.sender` must be the current recipient). No other contract writes it.
- **Routing to the coin is final.** `PadToken` only calls IMD and the PoolManager, so a coin can never call `setRecipient`. Shown on the anvil deployment above: the creator's attempt to change it back reverted.
- **Vault interface.** `CreatorVault.initialize(curve, hook)`: deployer only, once. `RecipientChanged(coin, previous, current)` has no `byCto`. `ctoModule()` and `ctoSetRecipient` are gone (`test_holders_routingIsFinal` checks with low-level calls).
- **Holder stream and swarm budget.** `claim` to the coin, `fundHolders` and `SwarmBudget.sweepToHolders` are unchanged and work (tests and the anvil run). Once the recipient is the coin, anyone can cancel open requests.
- **`Deploy.s.sol`.** No `CTOModule` import, param, `CTO_RULES` env, step, JSON key or log line. Step 5 deploys the verifier and the social registry, then `initialize(curve, hook)`. The owner lists match D-57 and THREAT-MODEL §1: 13 `FixedOwnable` contracts, and `DeployFork.t.sol`'s 13-entry list matches them.
- **Keeper.** The `cto` ABI and job are gone. Every deployment key it reads is written by `Deploy.s.sol`. Dry pass above.
- **THREAT-MODEL.** Invariant 17 is retired with its number kept, and still restates the recipient-only rule. §1 (no council; no `CTOModule` among the 7-day owner's contracts; the traders' row says the recipient alone) and §3 ("no takeover module"; R1-A4-17 binds only the version fallback) agree with it and with ARCHITECTURE §5.2 / §5.6.
- **Audit scope.** 32 `src/` files, `Deploy.s.sol` and 5 `upstream/` files: 38, every one in an area's FILES (`make_jobs.py` exits otherwise).
- **`grep -rni "cto\|takeover\|council"` over `launchpad/`.** What is left:
  - History: DECISIONS, FINDINGS, PRECHECK-4, PLAN, CTO-REMOVAL, `design/UX-RESEARCH.md`, the audit jobs' "changed since" lines, and notes in ARCHITECTURE / ROADMAP / SITE-COPY / READMEs that takeovers were removed.
  - Intentional: the frontend's `CTOModule` ABI, its `transparency.ts` / `Docs.tsx` rows and the `CreatorVault` ABI with `byCto` (they wait for the testnet redeploy), and `contracts/deployments/46630.json` (the live testnet record).
  - Negative tests in `Governance.t.sol` and `DeployFork.t.sol` that check the entry point is gone.
  - Missed by that grep, found with other words: "ousted recipient" in `SwarmBudget.cancel`'s NatSpec and in a `PondPad.t.sol` comment, and ROADMAP item 13's "the site's future takeover flow needs an 'announce' step" (P5-4).

## 4. Problems

### P5-1 (Low, test only): the cap-invariant fuzz test fails on ~7% of runs
`test/Market.t.sol:561` (`testFuzz_market_capInvariantAtBothFeeLevels`), `:97` (the trader gets 50M $PONDPAD in `MarketBase.setUp`).

Each of the ten steps sells up to 8M $PONDPAD (`1e18 + (seed >> 8) % 8_000_000e18`) or buys with up to 500 IMD. A seed that draws mostly sells needs more than the trader's 50M. The trader's transfer to the PoolManager then reverts `InsufficientBalance` (Solady ERC20) and the test fails. The market isn't at fault: the cap assertions never fail.

- **Reproduction:** `rm -rf cache/fuzz && forge test --match-test testFuzz_market_capInvariantAtBothFeeLevels --fuzz-seed 3714792172241991672` fails every time.
- **First local run:** seed `16828384444808715375`, counterexample `(326153…299697, true)`: ten sells in a row, 54,235,976 $PONDPAD in all. After a failure, forge keeps the counterexample in `cache/fuzz/failures` and replays it on every later run until that file is deleted.
- **Rate:** 7 of 100 fresh-seed campaigns failed.
- **Age:** in the test since `05239ce` (when the market was added); never reported.

**Why it matters now:** each job's four specialists and its judge are told to run `forge test --no-match-contract Fork`. At ~7% per run, a round of ~20 runs sees it with probability ≈ 1 − 0.93²⁰ ≈ 77%. A specialist may report it as a broken cap invariant until a judge reproduces it. That costs the round's attention, not funds.

**Fix (test only, no in-scope file):** give the trader 40M more at the start of the test (`pondpad.transfer(trader, 40_000_000e18);`: 90M is more than ten sells of at most 8M each). Probe 3 shows the failing inputs pass with it. Bounding each sell by the trader's balance would also work. The jobs read tests at the pinned commit, so this needs a new commit and round 5 regenerated.

### P5-2 (Info, coverage): `PadBuyer` through a migrated hook is untested (R4-A3-9 item)
`test/Staking.t.sol` (nothing calls `buy()` after `migrate`).

R4-A3-9 (6) listed "`PadBuyer.buy()` through a hook reached by `MarketController.migrate` (buy reads `controller.hook()` live)". The R4-A3-9 row is marked fixed, but its tests don't include this edge. It matters a little more since D-83: `buy()` now reads the new hook's `referenceTick()`, which starts from the inherited `refTick` and the new hook's `openMarket` block. Probe 2 shows it works: `buy()` succeeds in the migration block (the reference is the inherited `refTick`) and after quiet blocks (its own swap writes what it read).

**Fix:** move probe 2 into `Staking.t.sol` as `test_buyer_buysThroughAMigratedHook` and name it in the R4-A3-9 row.

### P5-3 (Low): the 100-wallet check counts the claims file's keys, not wallets (R4-A3-4 fix incomplete)
`script/Deploy.s.sol:204` (`require(accounts.length >= AIRDROP_MIN_WALLETS, …)`), `src/AirdropDistributor.sol:177` (`initiated[account]`).

`accounts` are the JSON keys of `.claims`. The same address written in another letter case is a second key and a second leaf, and `vm.parseAddress` maps both to one wallet, which can initiate only once. So a file with 100 keys and 99 distinct wallets passes every check: the leaves add up, the root rebuilds and there are 100 keys. Then `initiatorCount` can never reach 100 and the 50M is locked for good, the R4-A3-4 outcome. A zero-address key would do the same (address 0 can never initiate).

`airdrop/snapshot.py build` can't produce such a file: its keys are lowercased and summed per wallet (`addr_checksumless`, the `final` dict). Only a hand-edited or third-party file can. Probe 1: the 100-key / 99-wallet file is accepted, a 99-key file is refused.

**Fix options:**
- **(a) Count distinct wallets.** In `airdropRootFromClaims`, collect `bytes32(uint256(uint160(vm.parseAddress(accounts[i]))))` into an array, sort it with the existing `_sortBytes32`, and require every element to differ from the one before it and from 0. That is about six lines; the "100 wallets" message and test stay.
- **(b) Accept and document.** Add to THREAT-MODEL §3: the claims file comes from `snapshot.py`, one lowercase key per wallet.

Claude's lean: (a) if round 5 is regenerated anyway (P5-1); otherwise (b).

### P5-4 (Info): documentation and comments
- **(a)** ARCHITECTURE §5.4, the "Liquidity reserve" row (line 242), says the 3% is "held by the treasury Safe behind the timelock". Since D-79 it sits in `LiquidityReserve` until the market opens, then goes to the 48 h timelock, as §5.4.1 and THREAT-MODEL invariants 10 and 22 say. The jobs read ARCHITECTURE. This row predates `c85b6a9`.
- **(b)** "ousted recipient" (takeover wording) in `SwarmBudget.cancel`'s NatSpec (`src/SwarmBudget.sol:102`) and in the comment of `test_swarmBudget_anyoneCancelsOnceFeesGoToHolders` (`test/PondPad.t.sol:321`). Now these are the recipient's own requests from before it routed the fees to the holders.
- **(c)** THREAT-MODEL §3's sink list doesn't name a coin's own address. Since R4-A1-3, coin tokens sent to the coin contract earn nothing, and nothing can ever move them: a sink like the others, where only the sender's own funds are lost. Adding it saves a re-report.
- **(d)** ROADMAP item 13 still says "The site's future takeover flow needs an 'announce' step". **Fixed in this commit** (ROADMAP isn't one of the docs the jobs are told to read; round 5 at `881abb7` is unaffected).
- **(e)** HANDOFF §3: `--match-contract Fork` reports 11 tests on mainnet (the 2 `TestnetFork` tests return early there); say so next to "9 fork tests". **Fixed in this commit** (HANDOFF only).

## 5. Recommendation

Nothing here is a contract bug, and nothing is Critical, High or Medium. Round 5 at `881abb7` could be submitted as it is without risk to funds. Still, the round isn't submitted yet, and two items are likely to come back as findings: P5-1 (likely seen in at least one job) and P5-3 (an incomplete-fix Low). So the lean is to fix first.

1. P5-1 and P5-2 (tests), P5-4 (a)–(c) (ARCHITECTURE, THREAT-MODEL, one NatSpec line in `SwarmBudget.sol`, one test comment), P5-3 option (a) (a few lines in `Deploy.s.sol` plus a test that fails on `881abb7`).
2. All tests (local, mainnet fork, testnet fork), commit, push, then `python3 launchpad/audit/make_jobs.py round 5 --check` at the new pushed ledger commit, and update the audit note.

The in-scope change is small: one NatSpec line, and the `Deploy.s.sol` check if (a) is chosen.

If the user prefers no in-scope change, do 1 without P5-3 (a) and the `SwarmBudget.sol` comment: tests and docs only, P5-3 documented as (b). That still needs regenerating round 5, since the jobs read the tests, FINDINGS, THREAT-MODEL and ARCHITECTURE at the pinned commit.

## Appendix: probes (run on `881abb7`; all four pass there, i.e. each statement in §4 holds)

Generate the fixtures, then copy the test to `contracts/test/scratch/R5Probe.t.sol` (untracked) and run `forge test --match-path test/scratch/R5Probe.t.sol --match-test probe -vv` (~4 min to compile). Delete both before committing.

```python
# make_claims.py: writes contracts/cache/precheck5/*.json with airdrop/snapshot.py's own build_tree (cache/ is ignored).
import json, os, sys
sys.path.insert(0, "launchpad/airdrop")  # run from the repository root
from snapshot import build_tree, keccak

out = "launchpad/contracts/cache/precheck5"
os.makedirs(out, exist_ok=True)

def addr(i):
    return "0x" + keccak(b"precheck5 wallet %d" % i)[12:].hex()

def write(name, entries):
    root, _dump, claims = build_tree(entries)
    total = sum(v for _, v in entries)
    with open(os.path.join(out, name), "w") as f:
        json.dump({"root": root, "total": str(total), "claims": claims}, f)

write("claims-120.json", [(addr(i), 400_000 * 10**18) for i in range(120)])  # the anvil deploy
dup = [(addr(i), 400_000 * 10**18) for i in range(99)]
dup.append(("0x" + dup[0][0][2:].upper(), 400_000 * 10**18))  # 100 keys, 99 wallets
write("claims-dup.json", dup)
write("claims-99.json", [(addr(i), 400_000 * 10**18) for i in range(99)])
```

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../Staking.t.sol";
import {Test} from "forge-std/Test.sol";
import {MarketTest} from "../Market.t.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PadMarketHook} from "../../src/PadMarketHook.sol";
import {Deploy} from "../../script/Deploy.s.sol";

contract R5DeployProbeTest is Test {
    /// P5-3: the 100-wallet guard (R4-A3-4) counts the claims file's keys, not distinct wallets: the same address
    /// written in another letter case is a second key, a second leaf and a second "wallet", yet it initiates once.
    function test_probe_airdropListCountsKeysNotWallets() public {
        Deploy script = new Deploy();
        string memory dup = vm.readFile("cache/precheck5/claims-dup.json");
        bytes32 root = script.airdropRootFromClaims(dup); // accepted
        assertEq(root, vm.parseJsonBytes32(dup, ".root"));
        string[] memory keys = vm.parseJsonKeys(dup, ".claims");
        assertEq(keys.length, 100, "100 keys");
        uint256 distinct;
        for (uint256 i; i < keys.length; i++) {
            bool seen;
            for (uint256 j; j < i; j++) {
                if (vm.parseAddress(keys[j]) == vm.parseAddress(keys[i])) seen = true;
            }
            if (!seen) distinct++;
        }
        assertEq(distinct, 99, "only 99 wallets: initiatorCount can never reach 100");

        // Control: 99 distinct keys are refused today.
        string memory short = vm.readFile("cache/precheck5/claims-99.json");
        vm.expectRevert(bytes("airdrop list below 100 wallets"));
        script.airdropRootFromClaims(short);
    }
}

contract R5BuyerProbeTest is StakingTest {
    /// P5-2: `PadBuyer.buy()` through a hook reached by `MarketController.migrate` (untested, R4-A3-9). It reads the new
    /// hook's `referenceTick()`: the inherited `refTick` in the migration block, its catch-up afterwards.
    function test_probe_buyerBuysThroughAMigratedHook() public {
        _graduate();
        imd.mint(address(buyer), 100e18);
        _nextBlock();
        _swap(true, 1e15);
        _nextBlock();
        address addr = address(uint160(MARKET_FLAGS) | (uint160(0x8888) << 144));
        deployCodeTo(
            "PadMarketHook.sol:PadMarketHook",
            abi.encode(
                address(controller), IPoolManager(address(pm)), address(imd), address(pondpad), address(burner),
                address(rewards), uint256(1_500), uint256(1_000e18), int24(200)
            ),
            addr
        );
        vm.prank(slowTimelock);
        controller.approveMigration(addr);
        vm.prank(migrator);
        controller.migrate(addr);
        PadMarketHook next = PadMarketHook(addr);
        assertEq(address(controller.hook()), addr);
        assertFalse(market.marketOpen(), "old hook closed");
        assertEq(next.referenceTick(), next.refTick(), "migration block: the inherited reference");

        uint256 dripBefore = pondpad.balanceOf(address(rewards));
        vm.prank(keeper);
        assertGt(buyer.buy(), 0, "buys through the new hook in the migration block");
        assertGt(pondpad.balanceOf(address(rewards)), dripBefore);

        vm.warp(START + 30 minutes + 1 hours);
        for (uint256 i; i < 5; i++) {
            _nextBlock();
        }
        int24 expected = next.referenceTick();
        vm.prank(keeper);
        assertGt(buyer.buy(), 0, "and after quiet blocks");
        assertEq(next.refTick(), expected, "its swap set what it read");
    }
}

contract R5FuzzProbeTest is MarketTest {
    /// P5-1: the counterexample of the first local run (`--fuzz-seed 16828384444808715375`): ten sells in a row,
    /// 54.2M $PONDPAD in all, against the trader's 50M.
    uint256 internal constant FLAKY_SEED = 326153079808023488804245968469740090425867039056974110310716286299697;

    /// The cap-invariant fuzz test fails on the test trader's balance, not on the market.
    function test_probe_capFuzzRunsOutOfTokens() public {
        vm.expectRevert(ERC20.InsufficientBalance.selector);
        this.testFuzz_market_capInvariantAtBothFeeLevels(FLAKY_SEED, true);
    }

    /// Proposed fix: 40M more for the trader (90M >= ten sells of at most 8M each); the same inputs then pass.
    function test_probe_capFuzzWithEnoughTokens() public {
        pondpad.transfer(trader, 40_000_000e18);
        this.testFuzz_market_capInvariantAtBothFeeLevels(FLAKY_SEED, true);
    }
}
```
