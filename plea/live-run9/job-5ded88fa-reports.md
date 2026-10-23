# Run 9 launch job `5ded88fa-4108-448d-b81e-9c88b42d9aa2`: node reports (IMD's, verbatim summaries)

Admitted 2026-10-19 13:35 UTC (IMD's Ethereum reader stalled from ~05:50 UTC); completed 14:38 UTC; launch #2234 (`544c0ace-4f80-4067-ac5f-9b7c590669c0`) live 14:39 UTC, 7/7 admission checks. Delivered `identity-md-launches/launch-2234-src-cabalgate-sol-src-tribunal-sol-src-p` @ `9f58da6`.

## audit_imported_code (accepted True, 2026-10-19T13:47:54 UTC; changed: nothing)

Both findings validate against the tree, and no tracked file changed. The review is complete.

**Outcome: no defect found in the contracts. The findings file holds two informational notes.**

**What was read.** All nine contracts in full: PLEA, CabalGate, Seasons, PleaDistributor, PleaLaunch, PleaHook, Letterbox, Tribunal and OracleAttestation, plus the two interfaces, launch.json, foundry.toml and the audit ledger. Nothing was out of reach. Each state-changing entry point was walked for caller, value moved and trust, with attention on the run 9 changes: imdTEST as both pool currency and oracle fee asset with the mint flag off, the 2.25% fee split and the Letterbox's 95% floor, the 700-tick wall guard, and the rounded-up share bands.

**What was run.**
- The default build and the 22 launch-manifest tests pass. They tie launch.json to the committed Letterbox and Tribunal hashes, confirm the gas fit, and rehearse atomic deployment.
- The project's Sepolia fork rehearsal, all 22 tests, passes against the live Intake, PoolManager, Stacker and seat NFT over a public RPC. That confirms the live Intake takes 0.5 imdTEST for a plea and an objection, the Stacker credit reverts and cashback falls back to plain imdTEST, and the exact-output fee sale works with one token for both roles.
- Direct chain reads: imdTEST has 18 decimals, every manifest address has code, the signer is a plain key.

**Findings written to .imd-findings.json.**
- **Info, launch.json line 15.** imdTEST's total supply on Sepolia is 25 wei and only its owner's minters can mint. The run cannot trade, plead or object until IMD mints and distributes it. The contracts are fine; the fork tests pass only because they conjure balances.
- **Info, CabalGate.sol line 138.** Two NatSpec comments still name runs 2 to 8.5's separate test tokens for the oracle asset and the pool IMD. Documentation only, no bytecode or hash change.

**Checked and found sound.** The same-token path leaves no shared allowance between the Intake and the hook. The Letterbox's floor is slightly conservative against the real 0.25% burn plus 2% IMD fee. The rounded-up share keeps a 20% letter in the 16-point band. The owner allowlist and the post-launch Merkle root are documented accepted powers, not reported.

**Not verified.** The oracle signer address in launch.json could not be checked against IMD's live attester. The Intake's own signer view returns a different key, which may simply be its request signer, and the public node refused log scans that would have shown earlier gates receiving verdicts under this signer. The address has been unchanged since PLEA v10, through runs that received real verdicts.

- Finding (info): imdTEST, the pool currency and oracle fee asset, has a 25-wei total supply on Sepolia and a minter-only mint, so no one can trade, plead or object until IMD's minters distribute it
- Finding (info): CabalGate's NatSpec still names runs 2-8.5's two Sepolia test tokens for oracleAsset and imd; run 9 passes imdTEST for both

## adapt_contract_project (accepted True, 2026-10-19T14:08:18 UTC; changed: ADAPTATION.md, src/CabalGate.sol, test/LaunchManifest.t.sol)

Run 9 is ready to launch. The code I was given already had every change the brief lists, so my diff only fixes two outdated comments, adds one test and rewrites `ADAPTATION.md`.

**What was already there.** I compared run 8.5 (af57f6d) with the current code and every brief item is in place:
- **Share bands:** they use the exact share now (`CabalGate._shareBps` rounds up), and the seat-NFT address in `launch.json` is in EIP-55 form.
- **Fees (2.25%):** the owner's share is 1% (`OWNER_BPS` 100). The Letterbox's 95% delivery floor counts the 2.25% sale fees (`HOOK_SALE_FEE_BPS` 225), and `launch.json` has the new Letterbox hash.
- **Wall guard:** `WALL_GUARD_TICKS_PER_DAY` is 700.
- **imdTEST:** `launch.json` uses imdTEST in every currency and fee-asset slot, with the mint flag 0 and START 1792594800.

Every other number in the brief is unchanged, and I didn't touch `foundry.toml` or `launch.json`.

**The two audit findings:**
1. **imdTEST has a total supply of only 25 wei, and only its owner and minters can mint it:** this is the state of the chain, not a bug in the contracts, so I changed nothing. It does mean the run can't trade, plead or object until IMD's minters give imdTEST to the owner (2 for the opening buy) and to testers (0.5 per hand plea, 0.85 per objection). I listed this as an open item in `ADAPTATION.md`.
2. **Outdated comments in CabalGate:** confirmed and fixed. The comments on `oracleAsset` and `imd` in `src/CabalGate.sol` named the two tokens from runs 2–8.5; they now say both are imdTEST. CabalGate's compiled bytecode is byte-identical to the version I was given, so neither code hash in `launch.json` changes.
   - The new test, `test_gateTakesImdTestForBothRolesAndItsNatSpecSaysSo` in `test/LaunchManifest.t.sol`, checks three things: `launch.json` gives the gate the same token for both roles, a deployed gate returns imdTEST for both, and the built docs name imdTEST and not the old addresses.

**Checks**, all with the required fuzz seed:
- `forge build` and `forge test` pass: 23 tests in 5 suites, including the new one.
- The full suite in `test/full/`, run seven files at a time, passes: 803 tests in 84 suites.
- I didn't run the fork tests in `test/fork/` because they need RPC URLs. They are the difference between my 826 tests and the brief's 852.
- The five-contract launch costs 13,490,574 gas, or 16,458,500 with the factory's 22% headroom. That is 318,716 under the 16,777,216 cap; the brief gave 13,490,541, a 33-gas difference.

Nothing was deployed, signed or broadcast.


## manifest (accepted True, 2026-10-19T14:12:06 UTC; changed: nothing)

I made no changes: the `launch.json` already in the tree is correct for test run 9, and every check passes.

**What it deploys.** The five contracts go in order, PLEA, CabalGate, Seasons, PleaDistributor and PleaLaunch, all using imdTEST (`0x56bc…58BF`):

- **PLEA and PleaDistributor:** their owner argument is `$owner`.
- **CabalGate:** imdTEST is both the oracle fee asset and the pool IMD; seasons are 18000 seconds (5 hours) and the dead-man is 118800 seconds (33 hours).
- **Seasons:** its fourth argument is the seat NFT in EIP-55 form, `0xa0443799c320E16C80801c9C1911F3571260287F`.
- **PleaLaunch:** credit gas 1300000, START 1792594800 and mint flag 0. Its 12th and 13th arguments are the code hashes of the Letterbox and the Tribunal.

**Checks.** `forge build` succeeds. `forge test` passed all 23 tests in 5 suites, run with the required fuzz seed. That includes `test/LaunchManifest.t.sol`, which ties `launch.json` to both code hashes and checks that the launch fits the gas cap. I did not run the full suite in `test/full/` or the fork tests.

**Latest commit.** It only changed two comments in `src/CabalGate.sol`, not code. It doesn't touch the Letterbox or the Tribunal, so their hashes in the manifest are still right.

**One thing in the notes.** They describe the code's history starting from run 7 rather than naming run 8.5's code (launch #1981, testnet8.5 @ af57f6d) as the base. The fixes they list do match the brief. They're explanatory text with no effect on deployment, so I left them as they are.


## audit_math (accepted True, 2026-10-19T14:18:21 UTC; changed: nothing)

I found no defects in the math area that I could back with a failing input, so `.imd-findings.json` has an empty findings list. It also has a coverage row for all 56 entry points, each marked `holds` with a one-line reason, plus three invariant rows. No source files were changed. To support the "holds" verdicts I ran `FOUNDRY_PROFILE=full forge test --match-path 'test/full/{AppealRounding,HookRevision}.t.sol'`: 69 tests passed, none failed. That includes the fuzz test that the wall guard climbs at most 700 ticks a day.

**What I checked, using the Math Precision, Boundary and Numerical Gap guides:**
- **Share bands (CabalGate):** the round-up share makes the 20% edge exact: exactly 20% scores 16 and one wei more scores 9. A letter's 20% is rounded down, so it can never land in the 9-point band. An appeal takes the lower of its own share and the original's, and the Letterbox's appeal limits stay inside the gate's 1%–50% and 2.5M bounds.
- **Fact score:** the score can't exceed 45, the need is always 26–71, and the mixed score for PLEA no buy record covers rounds to the nearest point. The thresholds for each band and the 24h trend are as specified.
- **Hook fees:** the IMD fee is 2.00% (0.5% cashback, 1% owner, 0.25% prize, 0.25% wall), plus a 0.25% PLEA burn. Together that matches the Letterbox's 2.25% (HOOK_SALE_FEE_BPS 225); the true combined cost is 2.244%.
  - The fee taken on a filled exact-input trade is never below the fee reserved before the swap.
  - The three payouts, each rounded down, always add up to no more than the fee, so the wall's share can't go negative.
  - I traced the balancing of fees and refunds and the buy-record updates for all four trade types (buy or sell, exact input or exact output).
- **Opening-buy exception and fallbacks:** the 2 imdTEST opening buy, during the 70% launch fee, does put its payouts into the pool. The ERC-6909 claims and refund fallbacks also hold.
- **Wall and inventory cap:** the 700-ticks-a-day pace carries its remainder correctly, tick rounding is correct for negative ticks, and the one-sided liquidity formulas, the opening price for the 5,700 IMD market cap and the cap's daily decay all hold.
- **Letterbox:** the 95% delivery floor, the fee limit (snapshot value +10%), the 10% balance cap, and the 0.70 IMD minimum (rounded up, so it's never missed by a wei) all check out. The only rounding loss is at most 2 wei.
- **Seasons:** the 25 prize shares add up to exactly 10,000 bps (450 down to 350). The pot's bookkeeping can't underflow, the 1.2× seat points (at most 54) and the best-three totals fit their types, and a wallet only ever moves up the leaderboard.
- **Tribunal:** "sustained when newScore + 2 < need" is computed exactly, the lowest panel score is kept, and the 20-minute deadlines line up with the gate's, Letterbox's and Seasons' deadlines.

**Static-analysis leads, all dismissed:**
- The "weak PRNG" lines are ring-buffer index arithmetic.
- The "never initialized" state variables are mappings.
- The divide-before-multiply lines are either correct tick rounding or lose at most 2 wei.
- The strict equalities are intended zero checks.

**Not reached:**
- I didn't check whether imd/acc's Sepolia Stacker really reverts on `credit` and so falls back to plain imdTEST cashback.
- I didn't check whether the live Intake accepts 0.5 imdTEST as the oracle fee.

Both need the live Sepolia contracts; `test/fork/ForkTestnet.t.sol` rehearses them, and I didn't run it. I also didn't re-check the launch gas figures, which are outside the math area.


## audit_economics (accepted True, 2026-10-19T14:19:16 UTC; changed: nothing)

The review is complete and the findings file is in place. No tree files were changed.

**Result: no reproducible defect in the economics of run 9's code.** The findings file holds an empty list and a coverage row for all 56 listed entry points, each marked `holds` with a one-line reason.

**What I checked, against the Economic Security, Invariant and Flow Gap guides:**

- **Fee conservation at 2.25%.** The IMD leg pays 0.5% cashback, 1% owner, 0.25% prize and 0.25% wall on the realised fill, with the PLEA leg's 0.25% burned. The Letterbox's delivery floor uses a 2.25% multiplicative deduction, which sits just under the real net of 99.75% times 98%, so the 5% room for a dip is real and errs in the seller's favour by a few hundredths of a percent.
- **Same token for the pool and the oracle fee.** With the mint flag at 0, the Letterbox approves the gate for the oracle fee plus the wall share from one imdTEST allowance, the gate's fee swap buys exactly that IMD plus the tip first, and the Tribunal pulls the stake and the fee from the objector. No allowance collision and no path where the tip is short.
- **Payout funding on a PoolManager that holds little imdTEST.** Payouts fall back to ERC-6909 claims measured against the pool's own pre-swap IMD, the 2 imdTEST opening buy closes the pool-liquidity exception, and every claim Seasons or the hook later redeems is backed by v4's settlement invariant.
- **Season pot accounting.** The accounted pot never exceeds the real pot, overruled stakes are booked to the plea's verdict season or to rollover, unpaid shares roll over, and the bonus's unpaid share is burned.
- **Share-band rounding and the wall guard.** The rounded-up share makes 20% and 35% exact edges on every plea and appeal path, and the 700-tick daily allowance is bounded with its remainder carried.

**Verification run on this tree.** The default build compiles, the manifest suite ties launch.json's two code-hash words to this tree's Letterbox and Tribunal and confirms the gas cap, runtime sizes match the stated figures, and 161 tests across the Letterbox, Seasons-funds, hook-revision, round-1 audit, Tribunal/Seasons and judge-findings suites pass under the full profile.

**Not reached.** The live Sepolia fork rehearsal needs an RPC URL and was not run. Static-analysis leads were all traced to known-safe patterns or already accepted findings in the audit ledger, so none is reported.


## audit_flow (accepted True, 2026-10-19T14:20:43 UTC; changed: nothing)

The review is complete. The findings file is in place and the working tree holds nothing outside it.

**Outcome: no substantiated defect in the control flow.** The file `.imd-findings.json` has an empty findings list and a coverage row for all 56 listed entry points plus two invariants, every one marked `holds` with a one-line reason.

**What I traced** (Execution Trace, Periphery and First Principles guides applied to the run-9 code):

- **The letter path end to end.** The Letterbox escrows through `courtTake` in the writer's own transaction, the gate scores on the pre-escrow balance, the exact-output fee swap is capped by the PLEA sent and returns the unspent part, and the 0.5 oracle fee plus a 0.35 appeal share are pulled from an approval the gate consumes exactly. The unearned specified-side fee refund rounds to zero wei for both the 0.75 and the 1.10 IMD fee swaps.
- **The Sepolia configuration.** With the mint flag at 0 and imdTEST as both pool currency and oracle asset, the PleaLaunch, Letterbox and Tribunal constructors all accept launch.json's arguments. The Letterbox and Tribunal suites that buy the fee in pool IMD pass under the full profile.
- **Delivery and settlement states.** Every escrow ending was checked against the gate's status machine: Pending only through a stale expire, Approved only after the window, Lapsed and Denied returned, Executed refused. No path lets an AUTO_SELL plea sell without an open escrow.
- **Objection timing.** The 20-minute window plus a 20-minute pending expiry fits inside the one-hour close grace, a void frees its slot without counting, and late Intake answers hit `TooLate` or `UnknownRequest`.
- **PLEA's transfer gate, the hook's fee and claims accounting, the wall guard at 700 ticks a day, Seasons' pot accounting, and the manifest ties.** The default launch suites pass, and `cast` confirms the seat and imdTEST words are their EIP-55 checksums.

**Not reached.** The live Sepolia Stacker's credit reverting is rehearsed only by the fork suite, which needs an RPC URL I did not have. The plain-imdTEST cashback fallback is traced in code only.


## audit_permissions (accepted True, 2026-10-19T14:22:52 UTC; changed: nothing)

The review is complete and the report is written. No repository file was changed. Only the untracked report file was created, which git status shows as clean for tracked files.

**Result: no defect found in the assigned area.** The permission model of the five launch contracts plus PleaHook, Letterbox and Tribunal holds against the Access Control, Trust Gap and Asymmetry checklists. The report at `.imd-findings.json` carries an empty findings list and 59 coverage rows: one `holds` row with a reason for each of the 57 listed entry points, plus three invariant rows.

What I traced:

- **Every privileged guard** resolves to an immutable or once-set address: launcher, letterbox, intake, poolManager, the committed Tribunal. The only live-owner powers are the add-only allowlist, early seed and two-step ownership, as the threat model lists. The allowlist cannot reach the PoolManager or the gate, so it opens OTC transfers only.
- **Paired surfaces** compared: hand plea versus Letterbox plea, hand appeal versus letter appeal, executeSell versus executeSellFor, record versus closeSeason's try-record, settle versus settleable, gate versus Tribunal oracle callbacks. Each pair mirrors its checks and state writes. The known asymmetries are the documented ones, such as the letter appeal's fee exception.
- **Trust-gap seams** checked: owner handover cannot redirect hook fees or strip a leader; the Tribunal and Seasons share one exclusion read; the sham-objection shield, the hookData gift and the system-contract sinks are already accepted in writing.
- **Manifest and live chain.** All six static Sepolia addresses have code. imdTEST's symbol matches. The seat NFT is "IdentityMD (test)". The Stacker stakes the earlier test IMD, so its credit reverts and cashback falls back to plain imdTEST. The default suite passes, and five fork rehearsals against the live Intake pass, including seller-only execute and the failure-binding test.

Not reached: the full `test/full/` suite was not re-run, and the oracle signer is an EOA whose key I cannot verify beyond its address.


## write_foundry_tests (accepted True, 2026-10-19T14:26:53 UTC; changed: test/Run9Sepolia.t.sol)

I added one new test file, `test/Run9Sepolia.t.sol`. It's part of the default build, and `forge test` with the verifier's seed passes: 46 tests in 7 suites, 23 of them mine. I found no defects, so there is no `.imd-findings.json`. The file is not committed: git has no author identity on this machine, and setting one would mean changing config, so I left it staged for the upload step.

The suite runs the real contracts set up as run 9 has them: imdTEST is both the pool currency and the oracle fee token, the mint flag is 0, Objection! is on, and the Sepolia timings and credit gas are used. The Stacker is set to stake a different token, so its credit reverts the way imd/acc's Sepolia Stacker will.

**What the 22 unit and fuzz tests check:**
- **Numbers:** the owner's share is 1%, the fees total 2.25% (matching the Letterbox's 225), the wall guard is 700 ticks a day, `PAYOUT_RESERVE` is 2 imdTEST, and the objection settings are 0.35 stake, 20 minutes, margin 2 and two per plea. The gate, launch and Tribunal all use imdTEST and none of them mints.
- **Payouts:**
  - The 2 imdTEST opening buy's payouts join the pool, and a dust buy before it doesn't use up that exception.
  - The next buy pays the owner, the prize and the cashback in plain tokens.
  - A large first buy into an empty PoolManager pays them as ERC-6909 claims, and the PoolManager holds enough to cover them.
- **Cashback fallback:** when the credit reverts, the 0.5% is paid in plain imdTEST, no sIMD is minted and no allowance is left behind. A control test with a Stacker that stakes imdTEST stacks normally, which shows the fallback comes from the token mismatch.
- **Share bands:** exactly 20% scores 7 more than 20% plus one wei, and exactly 35% scores 6 more than one wei over. A fuzz test checks the band against the exact share. A plea whose need is above 45 is refused with `CannotPass`.
- **Hand plea:** the 0.5 fee is paid in imdTEST, and the old test IMD is never touched. The plea is refused without an imdTEST allowance or balance.
- **Objections:**
  - The objector pays 0.85 imdTEST.
  - A score 3 under the need is sustained and the stake comes back; 2 under is overruled and the stake goes to the season pot.
  - An unanswered objection is voided after 20 minutes and the stake comes back.
  - Refused: the seller, an excluded owner, the same wallet twice, a third objection, objecting at 20 minutes plus one second, a denied plea, a balance one wei short, and settling twice.

**Invariants (random buys, pleas with random scores, and time jumps from several wallets):**
- The owner holds, as tokens or claims, everything the hook says it paid them.
- The prize is never more than a quarter of the owner's fees, and the owner's fees are twice the cashback, give or take a wei per trade.
- The PoolManager can always redeem every imdTEST claim.
- No cashback is left in the hook and no sIMD is ever minted.
- PLEA's supply only shrinks.
- A check after each run confirms the sequence actually traded.

The hook takes its 2% on top of the fill, so a 10.2 imdTEST buy pays the owner 0.1. That matches the code's "0.5% of the IMD fill" comment, so I treated it as intended and wrote the fee tests that way. Also, the prize share stops once the 33-hour dead-man runs out, which is also by design, so that invariant is an upper bound rather than an exact ratio.


## audit_judge (accepted True, 2026-10-19T14:37:21 UTC; changed: nothing)

Review complete. The findings file holds an empty findings list and a full coverage record.

**Outcome: no reproducible defects.** All four specialists and the independent tester reported nothing, and my own pass over the five manifest contracts plus the committed Letterbox, Tribunal and PleaHook found nothing that reproduces as a bug. There were no specialist findings to merge or drop.

**What I verified against this tree**

- The manifest commits to this build. The 12th and 13th PleaLaunch words equal the keccak256 of the compiled Letterbox and Tribunal creation code from a fresh default-profile build. Every address word is in valid EIP-55 case, and every contract address in it has code on Sepolia through this machine's RPC. The Stacker's staked token is the earlier test IMD, so the plain imdTEST cashback fallback is the live path, as the brief says.
- Sizes and deployability. Runtime sizes match the brief (PleaHook 24,402, CabalGate 24,018, Letterbox 23,255, Tribunal 21,654, Seasons 12,473), all creation codes with arguments are under 49,152 bytes, and no manifest constructor needs anything the factory does not supply.
- Test runs on this machine, all passing: the launch-manifest suite (13 tests, including the gas cap with the factory's headroom), the run 9 Sepolia suite (22 tests plus 5 invariants), and the live Sepolia fork rehearsal against the real Intake with imdTEST (22 tests, run with this machine's RPC).
- Run 9 specifics traced by hand. With imdTEST as both the pool currency and the oracle fee asset, the gate's appeal and oracle pulls, the Letterbox's single approval for fee plus wall share, and the Tribunal's stake plus fee pulls all consume exactly the intended allowances. The Letterbox's new 2.25% delivery floor matches the hook's real sale take, which nets about 97.76% of snapshot value before price impact. The 2 imdTEST opening buy closes the PAYOUT_RESERVE exception as documented.
- Static-analysis leads. The slither and aderyn lines were checked and none reproduces: the uninitialized-state mappings, weak-PRNG ring indices, divide-before-multiply tick alignment, strict equalities and the encodePacked init-code hash are all correct as written, and the uint128 cast is bounded by the 2.5M PLEA cap.

**Coverage record.** 56 entry points answered as holds, plus one invariant row for the manifest-to-build linkage. No row is unreached.

No repository file was changed. The only artifact written is the review output at the repository root, and the scratch directory was not needed since nothing carried a proof.

