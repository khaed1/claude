# Check before audit round 4 (7 Oct 2026)

Claude's own check of the D-80 fixes before the user submits round 4, at code commit `4499824` (branch head `ce01194`; `35aa6b1` → `ce01194` changes only docs and `audit/rounds/4/`). Everything was re-run, and every round-3 fix was read against its report's path.

**Result: the tests pass and most fixes close their paths, but the R3-A4-8 fix (recorded "no" answers) has three holes (P4-1 to P4-3) and the R3-A4-4 fix leaves freeze paths in the timelocks (P4-4).** Round 4 as generated at `4499824` is **not to be submitted**. The user decided the fixes (D-81): items P4-1, P4-2, P4-3 and P4-5 are approved; P4-4 is waiting on the user. Next session: implement D-81, then regenerate round 4 at the new pushed commit (`python3 launchpad/audit/make_jobs.py round 4 --check`). The ledger rows are in `FINDINGS.md` ("Checks before a round").

**Outcome (7 Oct 2026):** D-81 implemented in `505fe96`: P4-1, P4-2 and P4-3 fixed in `CTOModule` (`announce` / `announcedAt`, "no" ordering, lowercase handles, per-coin block only after a confirmation "no"), each with a regression test that fails on `4499824` and passes after; P4-4 accepted and documented (the user's choice); P4-5 docs fixed. Fails-before: worktree of `4499824` with `lib/` copied, the new `test/` copied in, and only these stand-ins in `CTOModule`: empty `announce` and `announcedAt`, errors `NotAnnounced`, `AlreadyAnnounced`, `AnswerBeforeNotice` (the §1 stand-ins aren't needed there: `4499824` already has the D-80 code). 7 of 182 local tests fail there: the 6 new ones (`test_cto_laterNoDoesNotUnblockAnEarlierYes`, `test_cto_noIssuedAfterAYesBlocksProposingIt`, `test_cto_handleCaseIsTheSameQuestion`, `test_cto_answerBeforeTheNoticeDoesNotCount`, `test_cto_announcementIsOncePerQuestion`, `test_cto_firstQuestionNoDoesNotBlockTheCoin`), each on the behaviour it asserts, and the updated `test_cto_guards` (a plain-wallet recipient is now refused at `announce`); all 182 pass after. Round 4 regenerated at the ledger commit after it.

## 1. What was run (all as expected)

| Check | Result |
|---|---|
| Foundry 1.5.1 from the release binaries (HANDOFF §3); `forge build` | ~12.5 min (via-IR), no errors |
| Local `forge test --no-match-contract Fork` | **176 / 176** |
| Mainnet fork `FORK_RPC=https://rpc.mainnet.chain.robinhood.com forge test --match-contract Fork` | **9 / 9** (`Fork.t.sol` 5, `DeployFork.t.sol` 4) |
| Testnet fork `TESTNET_RPC=https://rpc.testnet.chain.robinhood.com forge test --match-contract TestnetFork` | **2 / 2**; the first attempt failed in `setUp` with an RPC error (`unsupported block number`, a lagging node), the rerun passed |
| Generators: `python3 upstream/make_fork.py`, `python3 upstream/make_staking.py` (run on a copy) | Byte-identical to `src/PadMarketHook.sol` (sha256 `c49b60c3…364d`), `src/StakedPONDPAD.sol` (`7e2eda01…5f73`), `src/RewardDripper.sol` (`75dc1259…f3af3`) |
| Fails-before (below) | Every round-3 regression test fails on the round-3 source and passes on HEAD |
| `Deploy.s.sol` simulation and broadcast from an EOA (below) | One-time handoff and launch pause work |

**Fails-before.** Worktree of `0f4f750` with `lib/` copied (not symlinked; the submodules' `.git` pointer files were deleted in the copy so `git status` works there), HEAD's `test/` copied in, and only these compile-time stand-ins (reuse them for the D-81 check at `4499824`, adding the new names D-81 introduces):
- `src/FixedOwnable.sol`: an abstract contract declaring only `error OwnerIsFixed()` (no round-3 contract inherits it).
- `src/PondPadTimelock.sol`: a stock `TimelockController` subclass with a `minimumDelay` getter and `error DelayBelowMinimum(uint256, uint256)`.
- `FeeSplitter`: the extra constructor argument (ignored) and `error NotPondpad()`; the old `Deploy.s.sol` passes `pondpad` for it.
- `MarketController`: `error PolicyOutOfBounds()`.
- `AttestationVerifier`: an empty `setThresholds(uint16, uint16, uint16)` overload.
- `PadToken`: an empty `holderStream()` view.
- `CTOModule`: `error BlockedByNo()`, `AnswerYes()`, `TooLate()`; empty `recordNo` and `recordConfirmNo`.
- `BondingCurve.sell`: the extra `trader` argument (ignored); the old `PadRouter` passes `msg.sender`.

Result: 32 of 176 local tests fail there (all 28 new tests for code fixes, i.e. every regression test `FINDINGS.md` names, plus the 4 updated tests `test_cto_routeFeesToHolders`, `test_holderStream_fundingInsideAnUnlockCantStallIt`, `test_verifier_settingsBounded`, `test_dripper_smallBufferStillSweeps`); fork test `test_deployFork_ownersAndDelaysAreFixed` fails there; all pass on HEAD; the 10 coverage tests pass on both. Three tests `FINDINGS.md` names pass on the old source by design: `test_holderStream_dustTopUpsCantStretchIt` (the R2-A4-3 guard, kept), `test_cto_laterNoDoesNotEndAProposal` (behaviour) and `test_cto_holderLumpCantBeCapturedInOneBlock` (the round-1 test, unchanged since `23549a8`: it still acts only in the funding block; the real R3-A4-1 regression test is `test_holderStream_oneTransactionCaptureEarnsNothing`).

**Deploy from an EOA.** `anvil --fork-url https://rpc.mainnet.chain.robinhood.com` (chain 4663); deployer = anvil account 0 (`0xf39F…2266`), `SAFE` / `RELAY` / `X_LINK_KEY` / `TWEET_CHECKER` = anvil accounts 1–4, `SALE_START` = now + 2 days, `CTO_RULES=ipfs://bafy…`, `AUDIT_LINK` set (so version 1 is activated before the registry's handoff), `AIRDROP_CLAIMS` = a claims.json built with `airdrop/snapshot.py`'s own `build_tree` from `test/fixtures/airdrop-tree.json` (7 leaves, 28,000 $PONDPAD; the script rebuilt the same root), placed under `contracts/cache/` because of `fs_permissions`. Then `forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --sender <account 0>` (simulation: estimate 61.9M gas, ~0.0025 ETH at 0.04 gwei) and the same with `--private-key <account 0> --broadcast --slow`:
- **52 transactions** (51 without `AUDIT_LINK`), all sent by the EOA, all succeeded; **46.6M gas used**, largest 5.28M. (HANDOFF §5a still says 48 transactions and ~57.6M gas: P4-5.)
- Order: `setLaunchesPaused(true)` is tx 9 (step 3), the splitter's final recipients tx 43, `setLaunchesPaused(false)` tx 44, the three handoffs (`VersionRegistry` tx 30, `FeeSplitter` tx 45, `PadConfig` tx 46) succeeded as calls from the EOA, so `FixedOwnable`'s creator is the deployer EOA (not a script contract).
- After the run, checked with `cast` (timelocks impersonated): all 14 owned contracts have the D-57 owner; the owner's `transferOwnership`, `renounceOwnership` and `requestOwnershipHandover` revert `OwnerIsFixed`; the deployer's `transferOwnership` reverts `Unauthorized`; `PadMarketHook.owner` = `MarketController`, `sinkAdmin` = 7-day timelock; `launchesPaused` false; delays 172,800 s / 604,800 s, `minimumDelay` the same, a self-call `updateDelay(0)` reverts `DelayBelowMinimum`; the deployer holds no timelock role; the Safe is proposer and canceller, anyone executes, each timelock is its own `DEFAULT_ADMIN_ROLE` (see P4-4); deployer $PONDPAD 0, sale 900M, airdrop 50M, vesting 20M, `LiquidityReserve` 30M; $PONDPAD above IMD; version 1 current; splitter stakers = `PadBuyer`. A coin launch (`launchWith`, 2 IMD with a dev buy) then succeeded.

## 2. Fixes that check out

- **Holder stream (`PadToken`, R3-A4-1 / A4-2 / A1-2):** `distribute()` counts `accountedImd + remaining` as accounted, so stream IMD is never paid as a lump; `claim` settles the stream before `distribute`; `_settleStream` runs in `_beforeTokenTransfer` with no external call, so it also runs inside an outside PoolManager unlock and a flash-borrowed or same-second balance earns nothing (balance changes within one second settle nothing); per-step rounding is recomputed from `remaining / (end − last)`, so it self-corrects and the end pays the rest; while nobody is eligible the end moves with the clock; the weighted end stays in (now, now + 7 days]; no overflow (`remaining` is `uint128`). `fundHolderStream` may now run inside an unlock (time-weighting makes the moment irrelevant).
- **`FixedOwnable`** under a real broadcast (above); `PondPadTimelock` refuses a delay below the deploy value.
- **`refTick` catch-up (R3-A3-2):** the first swap after quiet blocks catches the reference up before `PadBuyer` can act, so the round-3 pump-buy-dump now hits `PriceOutOfRange`; `PadBuyer` reading a stale reference without a preceding swap only buys cheaper. The backstop placement floor still decays at most `floorDecayTicksPerDay` (400 ticks/day) toward `refTick + 1`, so a faster reference can't relocate the backstop faster. Dragging the reference still needs the manipulated close to stand for each block.
- **Drip floor (R3-A3-1):** a drip releases at most 1/7 of the buffer, plus a final sweep when less than one $PONDPAD would remain (so the whole of a buffer under ~1.17 $PONDPAD); a small buffer drains in ~44 daily windows; no underflow.
- The rest of `git diff 5d4daed 35aa6b1`: cap floor / decay bounds, `fundInventory`, the synced-currency guard, $PONDPAD-only `distributeToken`, `PadLens` per-word steps (the loop always ends), exact-fraction agreement, `highestActivated`, `SocialRegistry` nonce and badge, the airdrop root rebuild (exercised by the broadcast), the council lapse wait, the dev-buy fixes, holder tax to growth when only the trader is eligible.

## 3. Problems

### P4-1 (Low): a later "no" unblocks an earlier "yes" (R3-A4-8 fix incomplete)
`src/CTOModule.sol:389` (`_blockedByNo`), `:359` (`answeredNoAt` keeps only the latest "no").
Only the latest recorded "no" per question is kept, and a "yes" is blocked only if issued at or after it. Path: a "no" at T−3h is recorded; a "yes" at T−2h is refused (`BlockedByNo`); the proposer asks again, gets a "no" at T−1h and records it itself (`answeredNoAt` moves to T−1h); the same T−2h "yes" is then accepted. Probe 1.
**Fix (approved, D-81):** for `propose`, a "yes" doesn't count while a recorded "no" to the same question was issued after it or less than 90 days before it: `noAt != 0 && yesAt < noAt + NO_ANSWER_HOLD` (drop `yesAt >= noAt`). Keep the ending rule of `recordNo` as it is (a "no" ends a pending takeover only if the "yes" was issued at or after it, within 90 days). CTO-RULES: reword the "A 'false' counts too" bullet.

### P4-2 (Low): the handle's letter case makes a fresh question
`src/SocialRegistry.sol:115` (stores the handle as given; the voucher signs only `keccak256(lower(handle))`), `src/CTOModule.sol:227`, `:341`.
The proposer chooses the casing at `linkWallet`, and `question`, `questionKey` and the stored `_proposerX` use it as stored. Path: a "no" is recorded for "frogdao"; the same wallet relinks as "FrogDAO" with a new voucher from the X link service (same X account); a "yes" for the "FrogDAO" question is accepted. Probe 2.
**Fix (approved, D-81):** `CTOModule` lowercases the proposer's handle (`LibString.lower`) in the question text, `questionKey`, the stored `_proposerX` and `recordNo`'s comparison. X handles are case-insensitive, so the panel reads the same account. No rule change.

### P4-3 (likely Medium): anyone can manufacture a valid "no", and the per-coin block turns it into a 90-day freeze (new path opened by D-80)
`src/CTOModule.sol:348` (`recordNo`), `:393` (`_endByNo` sets `endedByNoAt`), `:271` (`_propose` refuses while `endedByNoAt` is recent); `CTO-RULES.md` R1 and R5.
R1 and R5 require the X announcement at least 7 days before the oracle question, and the announcement names the coin, the receiver and the proposer's X account, i.e. the whole question text. During those 7 days anyone (the creator, a griefer) asks the question, gets a correct "false" (R1 not met yet) and records it with `recordNo` for 0.5 IMD: every "yes" to that question issued in the next 90 days is refused. Recorded after the community proposed (an attestation is valid for hours: the live one in `Governance.t.sol` is 6 h), the same "no" ends the pending takeover, and `endedByNoAt` then bars every proposer, every multisig and the council for that coin for 90 days. A new receiver or X account means a new 7-day announcement, which can be pre-empted the same way. Probe 3 (the contract can't tell an early "no", so the probe shows the mechanics).
**Fix (approved, D-81, option A):** an onchain announcement.
- `announce(coin, newRecipient)`: called by the proposer's wallet, which needs a linked X account (`SocialRegistry.walletHandle`); records `announcedAt[questionKey(coin, newRecipient, lower(handle))]` once (a later call never moves it) and emits an event. Optional sanity checks: the coin is registered, the recipient is a contract.
- `propose`: needs `announcedAt[key] != 0` and `att.issuedAt >= announcedAt[key] + 7 days` (`ANNOUNCE_NOTICE`).
- `recordNo`: counts a "no" only if `announcedAt[key] != 0` and it was issued at least 7 days after the announcement; an earlier "no" is refused (new error), so asking before the notice is over is worthless.
- CTO-RULES R1 / R5: the 7 days count from the onchain announcement by the proposer's wallet as well as the X post (the panel can check both); ARCHITECTURE §5.2 and THREAT-MODEL invariant 17 to match. The council fallback keeps its own 7-day notice and needs no announcement.
- Interface: new `announce`, `announcedAt`, event and error; the site's takeover flow gets an "announce" step (no takeover UI exists yet).
- The alternative B (drop first-question "no" recording, keep only `recordConfirmNo`) was not chosen.
**Per-coin 90-day block (approved, D-81):** keep it only after a confirmation "no" (`recordConfirmNo`: asked after the contest, panel ≥ 75, naming the contest time, so it can't be asked early; this matches the council's 90-day wait after a contested lapse). A first-question "no" still ends a pending takeover whose "yes" was issued after it, and blocks that question for 90 days, but no longer blocks the coin. (The user had not explicitly approved the per-coin block in D-80.)

### P4-4 (Low): the timelocks can still freeze themselves or change their proposer (R3-A4-4 fix incomplete) — decided: accept and document (D-81)
`src/PondPadTimelock.sol:32` (`updateDelay`), OpenZeppelin 5.0.2 `TimelockController` (the constructor makes the timelock its own `DEFAULT_ADMIN_ROLE`), `AccessControl.renounceRole`.
None of these lets anything act faster than the delay or moves funds; each needs the Safe:
- `updateDelay` has a floor but no ceiling: one delayed self-call to a huge delay means no later operation can ever become ready, so everything that timelock owns is frozen for good (the freeze `FixedOwnable` blocks for `renounceOwnership`, by another route). For the 48 h timelock that includes the 30M liquidity reserve it receives from `LiquidityReserve`.
- The timelock is its own role admin: one delayed self-call can grant `PROPOSER_ROLE` to another address (a single-key wallet, a DAO) or revoke the Safe (removing every proposer freezes everything). The round-3 A4 report named this; D-80 didn't address it.
- The Safe can `renounceRole(PROPOSER_ROLE)` (or the canceller role) at once, with no delay: everything freezes immediately.
Probe 4. Options for the user:
- **Lock it in code** (`PondPadTimelock`: delay between the deploy value and a ceiling such as 30 days; drop its own admin role in the constructor; refuse `renounceRole`). Pros: matches D-80's "fixed owners"; no freeze, no proposer change, by anyone, ever; a round-4 judge can't call R3-A4-4 incomplete. Cons: the proposer is the team Safe forever (its signers can still rotate inside the Safe, but if that Safe ever has to be abandoned, or governance should move to a new Safe or a DAO, there is no way: owned contracts are `FixedOwnable`, so they can't move to a new timelock either); the delay can't go above the ceiling; one more change for round 4.
- **Accept and document** (THREAT-MODEL §1 and §3: the Safe can freeze governance or change the proposer, only through the delay except its own renounce). Pros: no code change; keeps the only way to ever replace the Safe as proposer or hand governance to a DAO (a visible 48 h / 7-day proposal); every path needs the Safe itself, which can already harm governance in other ways (e.g. propose sending the 30M reserve somewhere). Cons: a compromised or mistaken Safe can freeze all settings, instantly via renounce; a gap in the D-80 "fixed owners" story that must be stated.
- A middle way (cap the delay only, keep the role admin) stops an accidental "100 years" delay but not a deliberate freeze by renounce.
Claude's lean: accept and document, optionally with a delay ceiling against accidents, because locking the roles removes the only way to replace the Safe.

### P4-5 (Info): documentation (approved, D-81)
- `audit/THREAT-MODEL.md` invariant 6 still says lumps are released "through `CreatorVault`'s holder stream ... at most one day's share per release (D-78); funding the stream is refused inside an outside unlock, and a top-up never lowers its rate (D-79)", which the code no longer does; keep only the D-80 description.
- The dripper bound wording (THREAT-MODEL invariant 14, ARCHITECTURE §5.6, D-79 / D-80 notes): "at most 1/7 of the buffer, plus the rest when less than one $PONDPAD would remain" instead of "or a remainder under one $PONDPAD".
- HANDOFF §5a: 52 transactions (51 without `AUDIT_LINK`), ~46.6M gas used on the fork broadcast (estimate 61.9M, ~0.0025 ETH at 0.04 gwei), largest ~5.3M.
- `FINDINGS.md` R3-A4-1: `test_cto_holderLumpCantBeCapturedInOneBlock` is the round-1 guard (passes on the round-3 source); the R3-A4-1 regression test is `test_holderStream_oneTransactionCaptureEarnsNothing`.
- THREAT-MODEL §3: a sole holder can still recover its own holder tax by buying from a second wallet (the check is per address; same class as the accepted R1-A1-3), so round 4 doesn't re-report it.

## 4. Plan for the next session (D-81)

1. P4-1, P4-2, P4-3 in `CTOModule` (and P4-4 if the user chooses to lock the timelocks), each with a regression test that fails on `4499824` (worktree with `lib/` copied, the stand-ins above plus empty stand-ins for `announce` / `announcedAt` and the new errors) and passes after. The probes below are the starting point: turn each into a test asserting the fixed behaviour. Update the existing R3-A4-8 tests for the announcement (`test_cto_noAnswer*`, `test_cto_laterNoDoesNotEndAProposal`, `_proposeAsBob` and every attested `propose` in `Governance.t.sol`, `DeployFork.t.sol`, `TestnetFork.t.sol`).
2. Docs: CTO-RULES (R1, R5, "A 'false' counts too", the per-coin block), THREAT-MODEL (invariants 6, 14, 17; §1 / §3 for P4-4 if accepted; the §3 second-wallet line), ARCHITECTURE §5.2 / §5.6, HANDOFF §5a and §5, DECISIONS (D-81 implemented, code-change row), ROADMAP item 13, FINDINGS (P4 rows fixed with the commit; the R3-A4-1 test note), `audit/jobs/A4-governance.md` "changed since round 3" line.
3. All tests (local, mainnet fork, testnet fork), commit, push to `claude/bold-gauss-qhlw86`, regenerate round 4 at the pushed commit, update the audit note, and give the user the repository link and the four job descriptions.

## Appendix: probes (run on `4499824`; all four pass there, i.e. each problem is real)

Copy to `contracts/test/scratch/R4Probe.t.sol` (untracked) and run `forge test --match-path test/scratch/R4Probe.t.sol --match-test probe -vv`. Delete before committing.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../Governance.t.sol";
import {PondPadTimelock} from "../../src/PondPadTimelock.sol";

contract R4ProbeTest is GovernanceTest {
    /// P4-1: a later "no" replaces `answeredNoAt` and so unblocks a "yes" issued between two "no" answers.
    function test_probe_laterNoUnblocksEarlierYes() public {
        _approveOracle();
        address coin = _coinWithCreatorFees(_noTax());
        _linkX(bob, "frogdao");
        vm.warp(P);
        string memory q = cto.question(coin, newOwner, "frogdao");
        OracleAttestation memory no1 = _att(q, false);
        no1.issuedAt = uint64(P - 3 hours);
        bytes memory no1Sig = _sign(no1, oracleKey);
        cto.recordNo(coin, newOwner, "frogdao", no1, no1Sig);

        OracleAttestation memory yes = _att(q, true);
        yes.issuedAt = uint64(P - 2 hours); // asked again after the first "no": blocked
        bytes memory yesSig = _sign(yes, oracleKey);
        vm.prank(bob);
        vm.expectRevert(CTOModule.BlockedByNo.selector);
        cto.propose(coin, newOwner, yes, yesSig);

        OracleAttestation memory no2 = _att(q, false);
        no2.issuedAt = uint64(P - 1 hours); // a third ask, after the "yes", answered "no"
        bytes memory no2Sig = _sign(no2, oracleKey);
        cto.recordNo(coin, newOwner, "frogdao", no2, no2Sig); // recorded by the proposer itself

        vm.prank(bob);
        cto.propose(coin, newOwner, yes, yesSig); // the blocked "yes" now counts
        assertEq(cto.pendingOf(coin).newRecipient, newOwner, "BYPASS: later no unblocked the earlier yes");
    }

    /// P4-2: the handle's letter case is the proposer's choice (the voucher binds the lowercased hash), and the
    /// question and the "no" key use it as stored: another casing is a fresh question.
    function test_probe_handleCaseDodgesRecordedNo() public {
        _approveOracle();
        address coin = _coinWithCreatorFees(_noTax());
        _linkX(bob, "frogdao");
        vm.warp(P);
        OracleAttestation memory no = _att(cto.question(coin, newOwner, "frogdao"), false);
        no.issuedAt = uint64(P - 2 hours);
        bytes memory noSig = _sign(no, oracleKey);
        cto.recordNo(coin, newOwner, "frogdao", no, noSig);

        _linkX(bob, "FrogDAO"); // same X account, new voucher, another casing
        assertEq(social.walletHandle(bob), "FrogDAO");
        OracleAttestation memory yes = _att(cto.question(coin, newOwner, "FrogDAO"), true);
        yes.issuedAt = uint64(P - 1 hours);
        bytes memory yesSig = _sign(yes, oracleKey);
        vm.prank(bob);
        cto.propose(coin, newOwner, yes, yesSig);
        assertEq(cto.pendingOf(coin).newRecipient, newOwner, "BYPASS: another casing dodged the recorded no");
    }

    /// P4-3: a "no" issued before a pending "yes" (e.g. asked while CTO-RULES R1's 7 days had not passed) ends the
    /// takeover and blocks every proposal for the coin, any recipient or proposer, for 90 days.
    function test_probe_earlyNoEndsTakeoverAndBlocksCoin() public {
        _approveOracle();
        address coin = _coinWithCreatorFees(_noTax());
        _linkX(bob, "frogdao");
        vm.warp(P);
        string memory q = cto.question(coin, newOwner, "frogdao");
        OracleAttestation memory early = _att(q, false);
        early.issuedAt = uint64(P - 2 hours); // asked a little before R1's 7 days were up: a valid "no"
        bytes memory earlySig = _sign(early, oracleKey);
        OracleAttestation memory yes = _att(q, true);
        yes.issuedAt = uint64(P - 1 hours); // the community's question once the 7 days were up
        bytes memory yesSig = _sign(yes, oracleKey);
        vm.prank(bob);
        cto.propose(coin, newOwner, yes, yesSig);

        vm.prank(creator);
        cto.recordNo(coin, newOwner, "frogdao", early, earlySig);
        assertEq(cto.pendingOf(coin).newRecipient, address(0), "ended");

        // Another proposer with another multisig: blocked for 90 days.
        address carol = makeAddr("carol");
        _linkX(carol, "toaddao");
        address otherSafe = address(new MockSafe());
        OracleAttestation memory yes2 = _att(cto.question(coin, otherSafe, "toaddao"), true);
        yes2.issuedAt = uint64(P);
        bytes memory yes2Sig = _sign(yes2, oracleKey);
        vm.prank(carol);
        vm.expectRevert(CTOModule.Cooldown.selector);
        cto.propose(coin, otherSafe, yes2, yes2Sig);
        vm.prank(council);
        vm.expectRevert(CTOModule.Cooldown.selector);
        cto.proposeByCouncil(coin, otherSafe, "ipfs://evidence");
    }

    /// P4-4: the delay can be raised without limit (freezing every owned power), the timelock is its own role
    /// admin, and the Safe can drop its proposer role at once.
    function test_probe_timelockFreezePaths() public {
        address safe = makeAddr("safe");
        address[] memory proposers = new address[](1);
        proposers[0] = safe;
        address[] memory executors = new address[](1);
        PondPadTimelock tl = new PondPadTimelock(2 days, proposers, executors, address(0));

        bytes memory raise = abi.encodeCall(tl.updateDelay, (type(uint256).max / 2));
        vm.prank(safe);
        tl.schedule(address(tl), 0, raise, 0, 0, 2 days);
        vm.warp(block.timestamp + 2 days);
        tl.execute(address(tl), 0, raise, 0, 0);
        assertEq(tl.getMinDelay(), type(uint256).max / 2, "delay raised without bound");

        PondPadTimelock tl2 = new PondPadTimelock(2 days, proposers, executors, address(0));
        assertTrue(tl2.hasRole(tl2.DEFAULT_ADMIN_ROLE(), address(tl2)), "self-admin kept");

        bytes32 proposerRole = tl2.PROPOSER_ROLE(); // read before the prank (an external call in args uses it up)
        vm.prank(safe);
        tl2.renounceRole(proposerRole, safe);
        assertFalse(tl2.hasRole(proposerRole, safe), "proposer gone, no delay");
    }
}
```
