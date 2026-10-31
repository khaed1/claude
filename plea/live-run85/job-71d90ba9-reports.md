# Run 8.5 launch job `71d90ba9-a088-41dc-9a98-3eb144d6042a` — every node's findings and summary

Fetched from `GET https://api.imd.fun/jobs/71d90ba9-a088-41dc-9a98-3eb144d6042a/submissions` on 2026-10-16 after the job completed (15:20 UTC).

## audit_imported_code — accepted (2026-10-16T14:38:26.654Z)
**Findings:** 
- **low**: Oracle callbacks bind a signed answer to a request only by consuming a.requestId: neither the gate nor the Tribunal checks a.requestId == intakeId or a.questionHash, so an answer signed for one plea c  
  `src/CabalGate.sol:537`

  CabalGate.onOracleResult (src/CabalGate.sol:530-560) and Tribunal.onOracleResult (src/Tribunal.sol:308-340) look the plea or objection up by the Intake's `intakeId`, verify the attestation's signature in their own EIP-712 domain, consume `a.requestId` once, and then apply `a.answer` to that plea. Nothing compares `a.requestId` with `intakeId`, and `a.questionHash` is never read, so the contract itself does not bind the signed score to the question it paid for; the only binding is whatever the Intake enforces when it completes a request. THREAT-MODEL.md section 1 says the contracts 'must bind each answer to one exact request', and the suite's OracleReplayTest only shows that one answer cannot settle two pleas (first delivery wins), not that it settles the right one. The repository's mock Intake (test/utils/Mocks.sol `complete`) is permissionless; the live Sepolia Intake v2 at 0xa43e6F75ee006411F79Ac1C84120606C2330DE82 could not be read in this review, so whether a third party can complete request B with the attestation issued for request A is unverified. If it can, the first party to deliver chooses which pending plea receives a signed score; if only the Intake's writer can complete, the exposure reduces to the Intake writer's honesty, which the threat model already assumes.

  Reproduction: State: Alice pleads (plea A, need 26) and Bob pleads (plea B, need 45, a CannotPass-adjacent plea), both Pending with intake ids idA and idB. The oracle signs attestation X for request A: requestId = idA, answer = 45, panelSize 30, quorum 17, agreed 20, chainId 1, signed for the gate's domain. Call Intake.complete(idB, 0, abi.encode(idB, X, sig)) before the honest delivery of idA. Actual: gate.onOracleResult(idB, X, sig) passes every check (the signature verifies, requestId idA is not yet consumed, panel fields pass), marks plea B Approved with score 45 and consumes idA; the honest delivery of idA then fails AlreadyConsumed and plea A expires without a verdict. Expected: the gate refuses an attestation whose requestId (or questionHash) is not the one recorded for intakeId. The repository's own OracleReplayTest.testFuzz_oneSignedRequestCannotSettleTwoPleas drives exactly this delivery order with `deliver(intakeIdOf(second), a)` and shows the wrong plea is the one settled. Whether a third party can call the live Intake's completion is the unreached precondition.
- **info**: Coverage: all nine src contracts read; the live Sepolia dependencies and the full suite were not reached  
  `src/PleaLaunch.sol:34`

  Read in full against the Pashov checklist (state-changing externals, callers, value moved, trust): src/PLEA.sol, src/CabalGate.sol, src/Seasons.sol, src/PleaDistributor.sol, src/PleaLaunch.sol, src/PleaHook.sol, src/Letterbox.sol, src/Tribunal.sol, src/OracleAttestation.sol and src/interfaces/*. launch.json was checked against the constructors (13 PleaLaunch words in declaration order, 7 CabalGate, 4 Seasons, 2 PleaDistributor, 1 PLEA; only kind/contracts/notes; $owner only where PLEA and PleaDistributor take an owner; the bool mint flag as the static word 1; the Letterbox and Tribunal hashes verified by test/LaunchManifest.t.sol). The default profile built and its 21 tests passed (Launch, LaunchManifest, ManifestInput). Not reached: the live Sepolia Intake v2 (0xa43e...), PoolManager (0xE03A...), Stacker (0x0457...), TestIMD (0x2B69...), the mintable oracle fee asset (0x44a1...) and the seat NFT (0xA044...), so every property that depends on them (Intake completion access, callback gas, the seat NFT's balanceOf cost under the 100k gas lent) rests on the repository's mocks; the 823-test full suite in test/full/ and the forks were not run in this review's budget. No DELEGATECALL, CALLCODE or SELFDESTRUCT appears in src (grep), no proxy or initializer, no post-deployment configuration other than the committed-code deployments and the one-time distributor root the brief describes. Against the launch's forbidden list: PLEA's transfer restriction while the Cabal watches (src/PLEA.sol _update) is the agreed product mechanic with the 33-hour dead-man as its exit, and the owner's `allow` list only widens it (add-only), so it is noted rather than reported as a freeze.

  Reproduction: Not a defect: deploy the five manifest contracts on an empty chain (test/LaunchManifest.t.sol test_factoryDeploysExactManifestOnAnEmptySepoliaChain passes) and observe that nothing in the review changed any file; the findings above are the only ones substantiated.

**Summary:**

Review complete. The findings file is written and validated.

**What I did**
- Read all nine contracts in `src/` plus the interfaces, launch.json, the eight prior audit rounds' ledger and the threat model, and worked through every state-changing external function (callers, value moved, trust) against the Pashov checklist.
- Built the default profile and ran its 21 manifest tests. All pass, including the Letterbox and Tribunal code-hash commitments in launch.json and the atomic five-contract deployment on an empty chain.
- Checked launch.json by hand: only the schema's keys, one word per constructor parameter in declaration order, `$owner` only where PLEA and PleaDistributor take an owner, the mint flag as the static word 1, 13 PleaLaunch arguments.
- Grepped `src/` for DELEGATECALL, CALLCODE and SELFDESTRUCT. None, and no proxy or initializer.

**Findings** (in `.imd-findings.json`)
- **Low:** the gate's and the Tribunal's oracle callbacks bind a signed score to a request only by consuming `a.requestId`. Neither compares it with the `intakeId` being answered nor reads `a.questionHash`. The repository's own replay test shows that delivering plea A's attestation under plea B's intake id settles B. Whether a third party can complete a request on the live Sepolia Intake is the unverified precondition, which is why this is low rather than high.
- **Info:** coverage. Every source contract was read. The live Sepolia dependencies (Intake, PoolManager, Stacker, TestIMD, the mintable fee asset, the seat NFT) could not be reached, and the 823-test full suite was not run within the budget. PLEA's transfer restriction is noted as the agreed mechanic with the dead-man exit, not reported as a freeze.

No critical, high or medium defect was substantiated, so no proof test was written. No file in the tree was changed.

## adapt_contract_project — accepted (2026-10-16T14:49:00.113Z)
**Findings:** none

**Summary:**

Work is complete. Summary:

**Outcome.** Run 8.5 deploys run 8's code unchanged. No contract, test, script, manifest or build setting was modified, so the Letterbox and Tribunal hashes in launch.json stay as they are. The deliverables are a rewritten ADAPTATION.md and two audit ledger updates.

**The audit's Low does not reproduce on the live Intake.** The finding says the gate's and the Tribunal's oracle callbacks never compare the attestation's `requestId` with the callback's intake id. That observation is correct, and the repo's own replay test shows the mechanism on the permissionless mock. The exploit needs a third party to complete a request on the live Sepolia Intake v2. I pulled that contract's verified source from Sourcify, a full match of creation and runtime code. Its `complete` reverts for every caller except its writer, and the live writer is the oracle plane's own key. So only the party that already signs the answers could re-address one, which the threat model already trusts.

**The suggested fix would brick live verdicts.** The oracle plane's attestation `requestId` is its own request UUID, visible in the live attestation kept in the conformance test, not the Intake's keccak id. Comparing the two would refuse every live answer and trip the 33-hour dead-man. The question-hash alternative needs the plane's unpublished canonicalisation. The finding is therefore recorded as accepted with that reasoning rather than fixed.

**Files changed:**
- `ADAPTATION.md`: rewritten for run 8.5 with the reproduction, the live evidence, the decision, the launch-rule checks and the verification results.
- `audit/FINDINGS.md`: a round entry for this launch job and rows R85-I-1 (Low, accepted) and R85-I-2 (coverage Info).
- `audit/THREAT-MODEL.md`: invariant 4 and the Intake row now say the answer-to-request binding lives with the Intake's writer, not an on-chain check.

**Verification with the verifier's fuzz seed:**

| Check | Result |
|---|---|
| forge build, default profile | passed |
| forge test, default profile | 21 passed |
| full profile: OracleReplay, OracleConformance, TribunalOracleBoundary | 17 passed |
| full profile: Gate, GateAdversarial, Tribunal, TribunalAdversarial | 113 passed |

Runtime sizes match the brief exactly (PleaHook 24,402, CabalGate 24,038, Letterbox 23,255, Tribunal 21,654, Seasons 12,473). Fork suites were skipped for lack of RPC variables. Changes are left uncommitted in the working tree for the pipeline's upload.

## manifest — accepted (2026-10-16T14:53:40.984Z)
**Findings:** none

**Summary:**

All checks pass and the working tree is unchanged, so the manifest is complete as committed.

**Outcome:** launch.json already describes the accepted run 8.5 tree exactly, and I verified it rather than rewriting it. No file was changed.

**What I verified**

- **Schema:** the file has exactly the keys kind, contracts and notes. Five unique contracts are listed in dependency order with every argument a string. Notes are 3,793 characters, under the 4,000 cap.
- **Constructors:** argument counts match each constructor in src, in declaration order. PLEA takes one arg, CabalGate seven, Seasons four, PleaDistributor two, PleaLaunch thirteen. PLEA and PleaDistributor receive $owner, and PleaLaunch reads its owner from PLEA, so neither the factory nor IMD gains control.
- **Brief numbers:** 18000-second seasons, 118800-second dead-man, credit gas 1300000, START 1792335600, the mint flag as the static word 1, and the seat NFT 0xa0443799c320e16c80801c9c1911f3571260287f as Seasons' fourth argument.
- **Code hashes:** the 12th and 13th PleaLaunch arguments equal keccak256 of this build's Letterbox and Tribunal creation code. The Tribunal hash matches the one the round-8 commit names.
- **Protected checks:** the deployment probe deploys all five in one call on an empty chain, every runtime stays under the EIP-170 limit with no forbidden opcodes, and no contract is owned by the factory or IMD.

**Test results** with the verifier's fuzz seed on the default profile:

| Suite | Result |
|---|---|
| LaunchManifest (Atomic, Rehearsal, PostLaunch) | 11 passed |
| ManifestInput | 2 passed |
| Launch | 8 passed |

The default forge build finished in about 84 seconds. The manifest test confirms the launch fits the 16,777,216-gas cap with the factory's headroom. Nothing needs input from the requester, so no .imd-blocked.json was written.

## audit_permissions — accepted (2026-10-16T15:00:19.769Z)
**Findings:** none

**Summary:**

The review is complete and the findings file is written.

**Result:** no reproducible defect in the permission model. `.imd-findings.json` holds an empty findings list and a coverage record with a `holds` row for every one of the 56 listed entry points plus two invariant rows, each with a one-line reason.

**What I covered**, in the Access Control, Trust Gap and Asymmetry guides' terms:

- **Role map.** Every inline guard across the nine contracts: launcher-only (`PLEA.init`, `setLetterbox`, `CabalGate.begin`, `PleaHook.seed`), Letterbox-only (`courtTake`, `submitFor`, `appealFor`, `executeSellFor`), Intake-only callbacks (gate and Tribunal, each under its own EIP-712 domain), PoolManager-only unlock callbacks with their expected flags, Tribunal-only `checkpointObjection`, and the two Ownable2Step owners. The deployment-block registration in `PLEA.setLauncher` is taken inside the atomic launch transaction.
- **Weakest-guard check per storage variable.** The transfer restriction in `PLEA._update` is the one guard many paths share. Every restricted-time route into the PoolManager, the gate and the Letterbox was traced; the owner's allowlist cannot reach the pool.
- **Trust seams.** The permissionless `record`, `deliver`, `closeSeason`, `rebalance`, `expire` and `settle` paths pay nothing to the caller or only what the design states. The "read, never trust" staticcalls to the Tribunal were checked against gas starvation.
- **Asymmetry pairs.** `appeal` versus `appealFor`, `executeSell` versus `executeSellFor`, `record` versus `_tryRecord`, `settle` versus `deliver`, the two `onOracleResult` and failure callbacks, and the two text validators.

**Verified with a scratch Foundry test** (removed afterwards, nothing kept): a gas-starved `Seasons.record` never bypasses the Tribunal hold across a sweep of 60k to 3M gas, an ordinary holder's `burn` reverts while the Cabal watches, and a buy whose hookData names the gate reverts rather than landing PLEA in the gate.

**Not reached.** The live Sepolia dependencies (Intake v2, TestIMD, Stacker, the seat NFT) were not called. The full suite in test/full was not rerun, only the default build and my scratch file. Previously accepted items such as R85-I-1, R4-A2-4, R6-P-1 and R1-A1-1 were re-read and not re-reported.

## audit_flow — accepted (2026-10-16T15:00:56.166Z)
**Findings:** 
- **medium** (blocking): launch.json: Seasons' seat NFT argument is a mixed-case address with an invalid EIP-55 checksum; the tree's manifest test never checks the string  
  `launch.json:28`

  The fourth constructor argument of Seasons (the IMD seat NFT (test) the brief gives as 0xa0443799c320e16c80801c9c1911f3571260287f) is written in launch.json as the mixed-case string 0xA0443799C320e16C80801c9c1911f3571260287F. Its casing is not the EIP-55 checksum of that address: the correct checksummed form is 0xa0443799c320E16C80801c9C1911F3571260287F, which is exactly what test/LaunchManifest.t.sol:45 (address constant SEAT) and test/fork/ForkTestnet.t.sol:63 compile (solc refuses a mixed-case literal with a wrong checksum, so those constants are known-good). Every other address word in the manifest (Intake, oracle asset, pool IMD, signer, PoolManager, Stacker) checksums correctly; only this one is wrong. The manifest step and the deployer parse constructor address words off chain; the usual parsers (viem isAddress/getAddress in default strict mode, ethers getAddress) reject a mixed-case address whose checksum does not match, so the whole launch.json is refused and the run parks after the build was accepted. If the service's parser is case-insensitive instead, nothing breaks, so the impact is conditional, but the string is objectively malformed under EIP-55 and the fix is a one-word edit. The gap is not caught locally because AtomicManifestTest.test_factoryDeploysExactManifestOnAnEmptySepoliaChain builds Seasons' arguments from its own SEAT constant and only reads notes, the mint flag and the two code hashes from launch.json; no test parses .contracts[2].constructorArgs[3] and compares it to SEAT.

  Reproduction: Run: cast to-check-sum-address 0xA0443799C320e16C80801c9c1911f3571260287F -> prints 0xa0443799c320E16C80801c9C1911F3571260287F, which differs from the manifest string in letter case (A0443799C320 vs a0443799c320), i.e. the manifest word fails EIP-55 validation. Equivalent check in JS: ethers.getAddress('0xA0443799C320e16C80801c9c1911f3571260287F') throws 'bad address checksum'; viem isAddress('0xA0443799C320e16C80801c9c1911f3571260287F') returns false. Expected: the manifest's static address words are valid EIP-55 strings (or all-lowercase, as the brief writes this one) so the Seasons constructor receives the seat NFT; actual: a strict parser refuses launch.json. Fix: write the word as 0xa0443799c320E16C80801c9C1911F3571260287F (or all lowercase), and optionally have LaunchManifest.t.sol assert vm.parseJsonAddress(json, '.contracts[2].constructorArgs[3]') == SEAT and that the string equals vm.toString(SEAT) (checksummed).

**Summary:**

The snippet matches the file byte for byte, the JSON is valid, and the only file in the tree I wrote is `.imd-findings.json` (the task's output; nothing else changed).

**Outcome:** one substantiated finding, written to `.imd-findings.json` with a 59-row coverage record (all 56 listed entry points plus three invariant/manifest rows). No critical or high defects were found, so no proof test was written.

**The finding (medium, launch.json line 28).** The fourth constructor argument of Seasons, the IMD seat NFT, is written as a mixed-case address whose casing is not its EIP-55 checksum. `cast to-check-sum-address` returns a different casing, and the correct form is the one `test/LaunchManifest.t.sol:45` already compiles as its `SEAT` constant. Every other address word in the manifest checksums correctly. A strict parser (viem's default `isAddress`, ethers' `getAddress`) refuses such a string, which would park the whole launch after the build is accepted. The impact is conditional on the service's parser, which is stated in the description. It passes locally only because the manifest test builds Seasons' arguments from its own constant and never reads that word from launch.json. The fix is a one-word edit to the checksummed or all-lowercase form.

**Coverage of the assigned area.** I traced, from the Execution Trace, Periphery and First Principles checklists, the whole control flow across the five launch contracts plus the Letterbox, Tribunal and hook:

- Launch wiring and the post-launch deployments: committed code hashes, the transient/deployment-block registration window, seed's preconditions and ordering.
- The plea lifecycle: submit, fee swap, verdict callbacks, execute, lapse, expire, appeal retry, and the Letterbox escrow in every ending.
- Objection!: both pending slots, stale voiding, same-wallet rule, rulings, settle into Seasons, and the hold on points. I checked that a hold can never outlast the season's one-hour close grace.
- Fee accounting in afterSwap, including the refund-after-payouts order, ERC-6909 claim fallbacks, the PLEA transfer rule for every sender the system uses, and the Seasons pot-accounting invariant.
- Periphery helpers: the assembly decimal/hex/escape writers, the UTF-8 validators and marker checks in both copies, the share table (sums to 10,000), the letter word parser, name rules.

The default-profile suites (21 tests) pass. I did not run the full-profile suite in test/full or any fork, and I did not independently re-verify the hook's tick and liquidity arithmetic beyond its control flow, since those sit outside the assigned guides.

## audit_economics — accepted (2026-10-16T15:01:13.935Z)
**Findings:** none

**Summary:**

The review is complete and the findings file is written and validated.

**Outcome: no defect substantiated.** `.imd-findings.json` holds an empty findings list and 60 coverage rows: all 56 listed entry points marked `holds` plus four economic invariants I traced (hook fee split, Letterbox accounting, need/fact scoring, season pot conservation).

**What I covered, against the Economic Security, Invariant and Flow Gap guides**

- **Value flows and conservation.** Hook fee arithmetic on the realised fill (reserved fee capped, refund after payouts, claims when the PoolManager cannot pay, launch extra to the pool), the 82/6/12 mint, the prize-pot ledger (open season fees plus rollover equals the accounted pot, never above holdings, so a Tribunal settle can never be locked by `UnfundedStake`), prize and bonus share tables (sum 10,000 bps), stake conservation in the Tribunal, and the Letterbox's escrow-plus-tip accounting through letter, appeal, deliver and settle.
- **Dependencies and token behaviour.** Intake callbacks (signer, domain, panel, consumed once, 20-minute expiry, failure path moves no value), the Stacker credit with the plain-IMD fallback, the gas-capped seat read, the fail-open Tribunal read, and PLEA's transfer rule that keeps PLEA out of any hookless pool while the Cabal watches.
- **Flow seams.** Letter scoring before the fee sale, escrow closed before the sale, appeals at the gate while a denied escrow is still open, the objection window versus record and close grace (40 minutes inside the 1-hour grace), late overruled stakes after a flush, and the executeSellFor path where the pending plea cannot diverge from the escrow.
- **Confirmed baseline.** The default build compiles clean, and the SeasonFunds, TribunalSeasons and LetterboxInvariant suites pass on this tree (33 tests).

**Not reached.** The live Sepolia dependencies (real Intake, TestIMD, Stacker, seat NFT) and the fork suites were not exercised. Every behaviour I judged economically questionable (min-of-panels objections, the seller shield, gift buys moving hold time, the lossy unanswered-letter exit, the opening-buy claims path) is already listed as deliberate in the threat model and findings ledger, so I did not report it again.

## audit_math — accepted (2026-10-16T15:01:47.517Z)
**Findings:** 
- **low**: Share band edges are truncated to whole basis points: a plea up to 0.0099% over 20% (or 35%) of the balance still scores the better band  
  `src/CabalGate.sol:264`

  Boundary x precision seam (Pashov Numerical Gap). `_factScore` feeds `_factScoreAt` with `amount * 10_000 / bal` (src/CabalGate.sol:257), an integer division that floors the share to whole basis points, and the band test `shareBps <= 2_000` then reads any share in [20%, 20.01%) as "at most 20%" (likewise [35%, 35.01%) as "at most 35%"). The run-8 table defines the bands as "share of the balance sold at most 20%: 16, at most 35%: 9, more: 3", and round 5 (R5-A1-2) moved the profit bands to exact edges for the same reason ("a 50.9% gain is over 50%"), so a plea of 20.0099% of the balance now scores 16 share points instead of 9: 7 fact points, so a need 7 lower, for selling more than the band allows. The same code path serves submitSell, submitFor, appeal and appealFor (appeals via the lesser of the two bps-floored shares). The Letterbox cannot reach it (a letter pleads floor(20%)), but the site's `plead(amount, text)` and a direct `submitSell` can. Impact is small (at most 1/10,000 of the balance per band, 7 points), hence Low; the fix is an exact comparison such as `amount * 5 <= bal ? 16 : amount * 20 <= bal * 7 ? 9 : 3` (or `amount * 10_000 <= bal * 2_000`), which keeps every number as agreed. Note: test/full/AppealRounding.t.sol `test_shareBandsAndFiftyPercentClampKeepTheirExistingRounding` asserts the current rounding on the appeal path, so the author may have chosen it; if so this is an Info-level inconsistency with R5-A1-2 and the table's wording rather than a defect.

  Reproduction: State: Cabal begun, seller balance 1,000e18 PLEA, no buy record (basisOf = 0,0,0), latestPrice = 2^96, price24hAgo = 0, 30 days after begin. Call `gate.factScore(seller, 200e18)` -> 38 (16 share + 7 held since start + 10 profit + 5 flat). Call `gate.factScore(seller, 200e18 + 1)` (20.0000000000000000001% of the balance, i.e. more than 20%) -> 38 as well: expected 31 (9 share points), because (200e18 + 1) * 10_000 / 1_000e18 == 2_000. The window is every amount below bal * 2_001 / 10_000: e.g. amount = 200_099_999_999_999_999_999 (20.0099999...% of 1,000e18) still yields shareBps 2_000 and 16 points, while 200_100_000_000_000_000_000 yields 2_001 and 9. The 35% edge behaves the same (amounts below bal * 3_501 / 10_000 score 9 instead of 3). Observed with a scratch Foundry test (CabalGate deployed against a mock PLEA/hook; trace shows factScore(…, 2e20+1) returning 38). Through `submitSell(200e18 + 1, text)` the plea opens with factScore 38 and need 33 where the table gives factScore 31 and need 40.

**Summary:**

The review is complete and `.imd-findings.json` holds one finding plus a coverage row for all 58 entry points and three checked invariants. The scratch test is removed, so no tracked file changed.

**Result: one Low finding, no funds-at-risk defect in the math.**

- **Share band edges are truncated to basis points** (`src/CabalGate.sol:264`). The share fed to the band test is `amount * 10_000 / bal`, so any plea in the range [20%, 20.01%) of the balance reads as "at most 20%" and earns 16 share points instead of 9. The 35% edge behaves the same. I confirmed it with a scratch Foundry test: balance 1,000e18, no buy record, 30 days after begin gives 38 for a 200e18 plea and also 38 for 200e18 + 1 wei, where the table gives 31. Round 5 made the profit bands exact for the same reason, so this is the one band left on rounded percentages. The author's own appeal-rounding test asserts the current share rounding, so it may be a deliberate choice. Impact is at most 7 fact points for selling one ten-thousandth of the balance more, hence Low.

**What I verified and found sound in my area**

- The full run-8 fact table against the gate with a mock hook: hold bands at exactly 1, 3 and 7 days, profit edges at exactly 0%, 50%, 200%, 500% and 1,000%, the trend bands, the CannotPass line, and the PLEA-weighted mean of a plea larger than the buy record rounding to the nearest point with ties up.
- The hook's fee arithmetic: the exact-input and exact-output formulas match v4's `amountToSwap` so the fee is the agreed share of the fill, the fill-based fee never exceeds the reserved fee, and the cashback, owner and prize floors never exceed the fee taken. I checked that exhaustively for every amount from 1 to 200,000 wei at the 175, 3,675 and 7,175 bps rates.
- The Letterbox's 95% floor after the 2% sale fees is conservative: the hook's real net on a sale is 98.005%. The auto-sell fee is capped at the sale and cannot underflow. The appeal clamps, the 1% floor on the lesser balance and the 0.70 IMD raise line up with the gate's own checks.
- Seasons: the 25 prize shares sum to exactly 10,000 bps, the 1.2 seat multiplier fits uint8, best-three sums fit uint16, and the pot accounting cannot underflow. Cap decay in the hook uses consistent PLEA-second units and never advances its clock past now.
- Tribunal: sustained exactly when the new score plus 2 is below the need, the lowest score tracks correctly from the first ruling, and the two-objection limit counts rulings plus live pending slots.

**Not reached**

- I did not run the full-profile suite or any fork test, since a full build was outside the time budget. PLEA's transfer rule and the distributor are outside my area and have no arithmetic I needed to trace, so their rows are marked as holding on that basis.

## write_foundry_tests — accepted (2026-10-16T15:09:49.968Z)
**Findings:** none

**Summary:**

Done. The default-profile `forge test` passes with the new file included, and the working tree holds only the one new test file under `test/`.

**What I added**: `test/Run85Objection.t.sol`, which joins the light default build (a bare `forge build` / `forge test`, the profile the verifier runs). It rehearses Objection! against the real gate, Seasons, Tribunal, PLEA and pool under the Sepolia timings, with only the Intake, fee tokens and Stacker mocked.

- **Failure paths, 19 unit tests**: every refused text class (empty, 281 bytes, control bytes, overlong and surrogate UTF-8, soft hyphen, zero-width, bidi override, BOM, variation selectors U+FE0E/FE0F and U+E0100, tag characters, CGJ, Hangul fillers, U+2028, C1 controls, musical and Egyptian format controls, the `[PLEA` and `[OBJECTION` markers); the seller and the excluded owner refused; unapproved, pending and denied pleas refused; the window's last second accepted and the next second refused; a recorded plea out of reach; a stake one wei short refused; two pending objections only from different wallets, then the case full; a ruled objector barred from the second slot; a void freeing its slot; the margin edges (need-2 overruled, need-3 sustained); a higher re-score never raising the plea; late, forged, wrong-panel and out-of-range rulings refused without burning a nonce; settle refused before a ruling and twice; rulings never resetting the dead-man or stopping the approved sale.
- **Invariants over random call sequences**: a handler files, rules, refuses, silences, expires, settles, sells and advances time with bounded inputs and three objectors, with `fail-on-revert` on. Ghost variables check that the Tribunal holds exactly the unsettled stakes, nobody is refunded more than they staked, every settled stake went to its objector or the season pot, at most two rulings per plea from different wallets, the recorded score is the lowest any panel gave, sustained exactly when newScore + 2 < need, and the sale's verdict is never rewritten. An `afterInvariant` pass shows every history unwinds to a zero balance without the oracle, and a scripted witness test proves the handler reaches every ending.

**Results** with the verifier's fuzz seed:

| Scope | Result |
|---|---|
| New file | 21 passed, invariant 48 runs, 3072 calls, 0 reverts |
| Whole default profile | 42 passed, 0 failed |

**Defects**: none found, so no `.imd-findings.json` was written. The file is left uncommitted in `test/`, and nothing outside the allowed paths was created.

## audit_judge — accepted (2026-10-16T15:20:15.649Z)
**Findings:** 
- **low**: Share band edges are floored to whole basis points: a plea up to 0.01% over 20% (or 35%) of the balance still scores the better band  
  `src/CabalGate.sol:264`

  Merged from audit_math (the only specialist to report it); reproduced. `_factScore` (src/CabalGate.sol:257, `return _factScoreAt(seller, amount, amount * 10_000 / bal);`) floors the share of the balance to whole basis points before the band test at line 264, so every amount in [20%, 20.01%) of the balance reads as 'at most 20%' and scores 16 share points instead of 9, and every amount in [35%, 35.01%) scores 9 instead of 3. The run-8 table says 'share of the balance sold at most 20%: 16, at most 35%: 9, more: 3', and round 5 (R5-A1-2) moved the profit bands to exact edges for exactly this reason, so the share bands are the one table row still on a rounded percentage. The same path serves submitSell, submitFor, appeal and appealFor (an appeal uses the lesser of two bps-floored shares in `_open`, line 422-425). The Letterbox cannot reach the window (a letter pleads floor(20%)), but `Letterbox.plead(amount, text)` and a direct `submitSell` can. Impact: at most 1/10,000 of the balance per band for a 7-point (or 6-point) lower need, so Low. Minimal fix keeping every agreed number: pass `amount` and `bal` to the band test and compare exactly, e.g. `amount * 5 <= bal ? 16 : amount * 20 <= bal * 7 ? 9 : 3` (an appeal keeps the lesser-share rule by comparing `amount * oBal` against `oAmount * bal`). test/full/AppealRounding.t.sol `test_shareBandsAndFiftyPercentClampKeepTheirExistingRounding` only checks that an appeal keeps its original's band; it does not assert that 20% + 1 wei scores the 20% band, so the fix does not conflict with it. CabalGate is 24,038 bytes (538 under EIP-170), so the two extra multiplications fit.

  Reproduction: Fixture state (test/utils/Fixture.sol: trading seeded, 91 minutes past seed), then: deal(address(plea), alice, 1_000e18); skip(30 days). alice has no buy record (basisOf = 0,0,0), latestPrice != 0, price24hAgo == 0. gate.factScore(alice, 200e18) -> 38 (16 share + 7 held since start + 10 profit + 5 flat). gate.factScore(alice, 200e18 + 1) -> 38: expected 31 (9 share points), because (200e18 + 1) * 10_000 / 1_000e18 == 2_000. gate.factScore(alice, 200_100_000_000_000_000_000) (20.01%) -> 31. Same at 35%: factScore(alice, 350e18 + 1) == factScore(alice, 350e18) == 31 while factScore(alice, 350_100_000_000_000_000_000) == 25. Run with the scratch test below (it passes on this code because it asserts the defect): forge test --match-path test/scratch/ShareBand.t.sol -vv prints 'factScore at exactly 20%: 38', 'factScore at 20% + 1 wei: 38', 'factScore at 20.01%: 31'. Through submitSell(200e18 + 1, text) the plea opens with factScore 38 and need 33 where the table gives 31 and 40.

Scratch test (test/scratch/ShareBand.t.sol):
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
import {Fixture} from "../utils/Fixture.sol";
contract ShareBandScratch is Fixture {
    function test_oneWeiOver20PercentStillScoresTheBestBand() public {
        deal(address(plea), alice, 1_000e18);
        skip(30 days);
        uint8 at20 = gate.factScore(alice, 200e18);
        uint8 over20 = gate.factScore(alice, 200e18 + 1);
        uint8 at2001 = gate.factScore(alice, 200_100_000_000_000_000_000);
        assertEq(over20, at20);      // defect: should differ by 7
        assertEq(at20 - at2001, 7);
        assertEq(gate.factScore(alice, 350e18 + 1), gate.factScore(alice, 350e18));
        assertEq(gate.factScore(alice, 350e18) - gate.factScore(alice, 350_100_000_000_000_000_000), 6);
    }
}
- **info**: launch.json: Seasons' seat NFT argument is a mixed-case address whose casing is not its EIP-55 checksum (not a deployment blocker: run 7 launched with the same word)  
  `launch.json:28`

  From audit_flow (reported as Medium). The fact reproduces: the fourth constructor argument of Seasons is written as 0xA0443799C320e16C80801c9c1911f3571260287F, and the EIP-55 form of that address is 0xa0443799c320E16C80801c9C1911F3571260287F (the constant test/LaunchManifest.t.sol:45 compiles, which solc only accepts with a correct checksum). A strict parser (ethers getAddress, viem isAddress in strict mode) rejects the manifest word. The claimed impact does not reproduce: git history shows the identical string has been in launch.json since commit ca8c914 ('Run 7'), and the notes record run 7 as live launch #1843, so the service's manifest parser accepted this word once already and the Seasons constructor received the seat NFT. The brief itself writes the address all-lowercase, and every other address word in the manifest checksums correctly, so this is a one-word hygiene edit (write it as 0xa0443799c320E16C80801c9C1911F3571260287F or all-lowercase), plus optionally a LaunchManifest.t.sol assertion that vm.parseJsonAddress(json, '.contracts[2].constructorArgs[3]') == SEAT, which no test in the tree checks today (AtomicManifestTest builds Seasons' arguments from its own SEAT constant). Downgraded to Info: no code, custody or constructor-value defect, and the deployment evidence contradicts a refusal.

  Reproduction: cast to-check-sum-address 0xA0443799C320e16C80801c9c1911f3571260287F -> 0xa0443799c320E16C80801c9C1911F3571260287F, which differs from the manifest word in letter case; ethers.getAddress('0xA0443799C320e16C80801c9c1911f3571260287F') throws 'bad address checksum'. Expected: a static address word that validates under EIP-55 or is all-lowercase. Evidence that it is not blocking: git log -S'0xA0443799C320e16C80801c9c1911f3571260287F' -- launch.json shows the word introduced in ca8c914 (run 7), which the notes say deployed as launch #1843.

**Summary:**

Review complete. The findings file is written and validated: it parses, every one of the 56 entry points has a coverage row, and both snippets match the tree at the cited lines.

**What I found**

- **Kept, Low (from audit_math):** the share bands in `src/CabalGate.sol:264` test a share floored to whole basis points. A plea of 20% plus one wei still scores the "at most 20%" band. I reproduced it against the real gate with a scratch test under test/scratch/: factScore is 38 at exactly 20% and at 20% plus one wei, and 31 at 20.01%. The same holds at the 35% edge. Impact is at most one ten-thousandth of the balance for 7 points, so Low. The fix is an exact comparison that keeps every agreed number and fits CabalGate's size.
- **Downgraded to Info (from audit_flow, reported as Medium):** the Seasons seat NFT word in launch.json is mixed-case with a wrong EIP-55 checksum. The fact reproduces with cast, but the claimed refusal does not: git history shows the identical string has been in launch.json since the run 7 commit, and the notes record run 7 as live launch #1843, so the manifest parser accepted it. It is a one-word hygiene edit.

**What I checked beyond the specialists**

- The default profile test run passes, 42 tests in 7 suites, including the manifest suite that ties both committed hashes to the compiled Letterbox and Tribunal and asserts the gas cap with headroom, and the run 8.5 objection invariants.
- I read all nine contracts and traced each entry point. The Tribunal's two-slot pending case, same-objector rules, stale voiding, margin rule and stake settlement hold. Seasons' one-hour close grace exceeds the 40 minutes a plea can be held. The Letterbox's delivery floor is taken after the hook's 2%. PLEA's transfer rule admits only the gate's pull, the court escrow and exempt senders. No new defect surfaced.

**Not run:** the full suite in test/full/ and the fork tests, per the build guidance. The scratch test is the only file I created, in the directory the task reserves for that.

