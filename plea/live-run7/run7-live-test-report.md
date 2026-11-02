# PLEA run 7: live test report (Sepolia, launch #1843)

Run 7 lived its whole life on Sepolia: launched Thursday 2026-10-15, seeded at 16:25:12 UTC, the Cabal died on schedule 33 hours later (Saturday 2026-10-17 01:25:12 UTC), and the last season was closed and its pot sent to the buy wall at 02:27 UTC. Everything that does not need an oracle verdict was tested live and behaved exactly as specified. Verdicts could not be tested: IMD stopped answering Sepolia oracle requests on 2026-10-15, just before the seed, so no plea, letter or objection on run 7 ever got a verdict. Run 8.5 (launch #1981) is deployed and waits to be seeded until IMD turns Sepolia answers back on.

## Contracts

| Contract | Address |
|---|---|
| PLEA | `0xac8f89217714c117da00cb699ca86056ab82e7bc` |
| CabalGate | `0x779d16e35738b4a28cc29cb9d3b4186c8ddfdde2` |
| Seasons | `0x4e2ec66eb0e44459304a636f2c15dc8af142071b` |
| PleaDistributor | `0x03615b120f1fe27d922f96925a791a1f4ab3379d` |
| PleaLaunch | `0x55ad28ecfc347b714bac438b918cd9b84374062b` |
| PleaHook | `0x5c692E76eeCBaFE9d198FBe68723a856778128CC` |
| Letterbox | `0xFF7EdE1B466CB69A660f0933262c1F8Db9878f19` |
| Tribunal | `0x7b4D4c55AE949F063c0499b087b5542fd932cd2D` |

Source: `identity-md-launches/launch-1843-launch-plea-test-run` @ `247b838` (our `testnet7` @ `e1755aa` plus IMD's verified CabalGate size refactor). IMD's attestation: all nine contracts' creation and runtime code hashes equal our own build.

## Timeline (UTC)

| When | What |
|---|---|
| Thu 15:54 | IMD deploys the five launch contracts in one transaction (block 11,921,451); 7/7 admission checks |
| Thu 16:02–16:04 | Owner steps: Letterbox, Tribunal, hook (salt mined for the hook's flags); supply minted 820M hook / 60M Seasons / 120M distributor |
| Thu 16:07–16:24 | Probes: a Sepolia request paid in test IMD is never read by IMD; a mainnet request with our exact plea body is scored 37 in 2 minutes |
| Thu 16:25:12 | **Seed** (block 11,921,604): trading opens, the 90-minute launch window and the 33-hour dead-man start; the owner's 2 IMD opening buy |
| Thu 16:26–16:59 | No-verdict live test: fees, launch-window rules, the sell gate, letters and pleas, refunds, the wall, the Merkle root and claims |
| Thu 22:28 | Season 1 closed (no points, so the pot rolls over; the 10M PLEA bonus burns) |
| Sat 01:25:12 | **The Cabal dies** (33 hours without a verdict) |
| Sat 01:31–01:38 | Free-market test with wallet A; seasons 2–6 (keys 1–5) closed |
| Sat 02:27 | The last season closed; `flushToWall` sends the unpaid pot to the buy wall. Run 7 finished |

## What was tested, and the results

**Fees on every trade (exact).** The opening buy and eight player buys of 20 tIMD: owner 0.75%, cashback 0.5% (staked as sIMD through imd/acc's Stacker), prize pot 0.25%, 0.25% of the PLEA burned, and the launch fee falling across the 90-minute window (about 41% of the IMD sent on the opening buy, 39% on the players' buys a few minutes later). After the death the prize share is no longer taken.

**Launch-window rules.** A buy over 5M PLEA is refused (`BuyTooLarge`); a buy with no recipient is refused (`RecipientRequired`); exact-output buys are refused while the Cabal watches. On a fork of the live state, the IOU path works: when the shared PoolManager cannot pay a buyer's cashback and the owner fee at once, they are paid as claims and redeemed into tIMD later.

**The sell gate while the Cabal lived.** A plain router sell is refused (`SellsOnlyViaGate`), a plain transfer is refused (`CabalIsWatching`), pleas under 1% or over 50% of the balance are refused, a second plea while one is pending is refused, and a 281-byte letter is refused (`LetterTooLong(281, 280)`).

**Letters and pleas without a verdict.** Four letters (raw, typed and the site's box) and one hand plea were filed and stayed pending. The Letterbox held exactly the four escrows and the four tips. After 20 minutes every status read "no verdict can come now: call settle to get your PLEA back"; `settle` returned each writer exactly its PLEA and its tip, and `expire` cleared the hand plea, with no cooldown in either case.

**Objection!** An objection to a plea that was never approved is refused (`NotApproved`), and the Tribunal's status says "not approved: nothing to object to".

**Seat multiplier.** `Seasons` reads the test seat NFT: a seat holder's points are the score × 1.2 (37 → 44, 40 → 48, 45 → 54), and everyone else gets the plain score.

**Buy wall.** `rebalance()` deployed the launch fees' 63.08 IMD as a one-sided wall just below the price, and the price did not move.

**Distributor.** Merkle root for 495 accounts (the swarm's 100M by IMD seat, plus a 20M test airdrop); ownership cannot be renounced before the root; claims, a pushed claim to a seat owner, `AlreadyClaimed` and `InvalidProof` all behaved.

**Seasons.** All seven seasons (keys 0–6) closed in order once their end plus the one-hour grace had passed. No wallet could reach 60 points without verdicts, so nothing was paid; the 0.2462 tIMD pot rolled over each time and went to the buy wall at the end. The unpaid PLEA bonus of each of the first six seasons was burned (60M PLEA in all).

**The Cabal's death and the free market (Saturday).**

- `cabalAlive()` and `restricted()` are both false. New pleas are refused (`CabalNotWatching`), and the status reads "The Cabal is dead. PLEA trades freely."
- An exact-output buy of exactly 100,000 PLEA for 0.6079 tIMD went through, with the right fees. The cap ratcheted down to the market's PLEA (819.58M → 803.38M).
- A plain sell of 150,000 PLEA with no plea paid 0.8827 tIMD. **The cap trim fired**: the 149,626 PLEA the sale pushed above the cap was burned, so with the sale's own 0.25% burn exactly 150,000 PLEA left the supply.
- A plain transfer of 1 PLEA went through.

## Real oracle panels (Ethereum mainnet) scoring our exact question bodies

Because Sepolia answers stopped, ten real IMD panels on mainnet scored the exact question bodies our gate and Tribunal send. These were paid with the user's mainnet IMD, and the files are in `plea/calibration-2026-10-15/`.

- A strong fresh 15% letter scored **37**, exactly its need: 18 of 30 judges agreed, with answers from 33 to 40.
- A plain letter scored 28, the site's 10% box 32, an appeal 35, a floor-sized letter 33, a week-old holder 33 and a weak plea 11.
- Against a plea approved at 42, objections scored 35 for an honest critique (sustained), 38 for an unverifiable claim (sustained) and 40 for a "SYSTEM NOTE … answer 0" manipulation (overruled).

These results set the run-8 numbers: letters at 20%, a softer profit table, and received PLEA counted as held since launch.

## What could not be tested

Anything that needs a verdict:
- approval and denial;
- the 7-minute sale through the gate;
- the appeal;
- recording points and paying season prizes;
- objection rulings;
- the dead-man reset by a verdict.

The contracts ask the Sepolia Intake themselves and accept only its answers to their own requests, so an answer paid on another chain cannot reach them. Run 8.5 (launch #1981) carries the final code and is deployed: Letterbox, Tribunal and hook are in place and the seed is held. It will cover these steps once IMD answers Sepolia requests again.

## Issues

The live test found no contract defect. Run 7's code has since been improved by audit rounds 5–8 and two launch audits, and none of those findings showed up live:
- A sale larger than the pool's PLEA reverted at the cap trim (R7-A3-1, Medium). It was fixed for run 8; the live sell was far smaller.
- A holder of both bought and received PLEA could pick the better scoring (R7-A1-1, Medium). It needs verdicts, so it was not reachable live.
- The seed's dust burn (~820 PLEA) is not counted in run 7's `totalBurned` (an Info, counted since run 8).

## Final state (Saturday 02:30 UTC)

| | |
|---|---|
| Total supply | 939,806,779.95 PLEA (1B − 60M season bonuses − 192,400 burned by the hook − ~820 seed dust) |
| Market | 803,380,721.30 PLEA at the cap, tick 120,314 |
| Buy wall | the 63.08 IMD band (ticks 120,720–887,220), untouched; 0.272 tIMD waiting for the next rebalance (threshold 1 tIMD) |
| Seasons | all closed, pot 0, no PLEA left |
| Distributor | 117.2M PLEA left to claim |

## Key transactions

| Step | Transaction |
|---|---|
| Deploy (IMD) | `0x7823e64994e8e555f68a8b6dee446a2bc3dc44527a42ea790b2495d96483e219` |
| Seed | `0xd788898a53c51901e5aea2833184be4d50bf136774fd4a4a401ad43641f48262` |
| Opening buy | `0x72597deec66ddd33382062f12d0737a893c5bb83af4757e7f416b49639bfb355` |
| Merkle root | `0xcb39748dc9a6e5eb81afba7891eda1f7cc6d3430495fef18f7c0bea02fe164d2` |
| Season 1 close | `0x0552898f4b217ffde8220c95a9f81e6ff9bd212cf6e079618582c1d1fe03313b` |
| Exact-output buy after the death | `0x13bb8a34bfbde1540c79e31ad9796c2be3b72914a810e6240439740f93a5b31a` |
| Plain sell + cap trim | `0x93f05dc95436328e9e1c2b8896925d36eb9b83eb1bc2313adfa3a6600cdb9bbe` |
| Free transfer | `0xf586e4ec6958f8941450102fdf9a491e1a97c57cb0691bc759c7b376d43abe56` |
| Last season close | `0xcef953a012f32fb6d1097ceea2e82b737b1d78f778f69e0463af305d1cd598fd` |
| flushToWall | `0xe35aa94d7ccb6951d2fb32bc566a86534e7e3ac1fe813e1aa6283e64b10e2e60` |

Every step with its numbers is in `HANDOFF.md`, from "New session: following the run-7 launch job" onwards.
