# Adversarial review of Murmuration v4, revision 4.3: registry, launch, fees and canary

Status: complete. Written by a reviewer who was given only the page and told to break it.

## 1. Header

- Reviewed: "Murmuration v4 specification, revision 4.3", plain-text rendering (1,604 lines), dated 11 November 2026. No other file was read. Line numbers below are lines of that text file.
- Area: Screening (with the example criteria file), Token and fee, build-specification contracts 3 ScreenerRegistry, 4 FeeDistributor, 5 Distribution and 6 Token, the deposit state machine as far as screening decides it, Deployment and the canary, Economics simulated, and the related rows of Parameters, Defaults, Risks, and the gas of `launch` and `apply`.
- Scripts used for the arithmetic and the simulations are in the session scratchpad under `review_r43/mech/` (`strikes.py`, `strikes_fix.py`, `econ.py`, `ledger.py`, `misc.py`). They are not part of the repository.
- Findings are listed most severe first. Each gives the passage it rests on, the steps, who can do it and at what cost, what breaks, the smallest fix, and how sure I am.
- Verdict:
  - Revision 4.3 does not pass in this area. There is one high finding, Q-1, which is certain: no flag can count in the first batch, so funds known to be stolen can fill the opening caps. Two more findings, Q-2 and Q-3, are high under one of two natural readings of the registry's bookkeeping.
  - Counts: 0 critical, 1 high, 2 high if misread, 7 medium, 7 low. Also 13 contradictions between sections and 22 points a builder would have to guess.
  - The launch loop, the address derivation, the arithmetic on the page, the canary's schedule, the stream scales, the auction and the buyback all held (section 5). The faults are in the registry, and six of them are in bookkeeping that could be removed (section 6).

Terms used below. An *epoch* is one day counted from `GENESIS`. The *snapshot* is the number of active screeners fixed for an epoch. A *strike* is a point against a screener that did not reveal the majority's batch. The *ring* is the registry's record of the last 16 epochs. To *settle* a screener is to work out its strikes and credit its pay from the ring. The *pot* is the screeners' share of fees waiting to be paid.

## 2. Findings

### Q-1. High. No flag can count in the first batch, and the first batch covers every deposit of the first month

**Where.** Line 720: "`flag(seatId, depositId)`, `signalCriteria(seatId, hash)` | The operator of an active screener | Emit an event and store nothing." Line 714: "a screener is active no sooner than 31 epochs after registering. There is no shortcut at launch". Line 156: flags are "events up to the base block, from seats in this epoch's snapshot", and the base block is "the last block whose timestamp is before the epoch's start" (line 151). Line 648: `deposit` is open to "Anyone, from launch". Against the claims on line 109, "Screeners always have between one and two days to refuse stolen funds", and line 175, "whatever a screener learns in the first day after a deposit can still stop it."

**How it works.** A flag is the only way knowledge that is on no list gets into a batch (line 176). Only an active screener can post one. The first screeners become active at the start of epoch 31 at the earliest. The first batch is the batch of that same epoch, and it reads flags only up to the last block of epoch 30, when nobody was active and every call to `flag` reverted. So the first batch contains no flag by construction. It covers every deposit made from launch to the end of epoch 29.

1. Day 5 after launch: a protocol is drained. The thief's addresses are public within hours and on no sanctions list (the page itself says designations take weeks, line 295).
2. Day 6: the thief deposits 25 ETH, 50,000 USDT and 50,000 USDC, the whole of the first-step caps, in amounts of 10 ETH or less or from addresses funded more than 72 hours before, so the one hold rule that could apply does not. The deposits are refundable and cost gas only.
3. Days 6 to 30: every registered seat holder knows. None can flag.
4. Day 31: the published program outputs a batch that covers those deposits and refuses none of them. An honest node commits and reveals it. A screener that reveals anything else gains two strikes if a majority follows the program.
5. Day 31, after hour 12: the batch is applied, which sets `START`. The thief activates and fills the ETH, USDT and USDC caps. Honest depositors who have waited a month find the caps full until day 90 unless the thief leaves.

Flags posted on day 31 count from the batch of day 32. By then the notes are in the tree and "cannot be removed afterwards" (line 185). The same holds on the canary, with a wait of 3 days, and again whenever a registry that has lost all its active screeners starts up with new ones. `signalCriteria` has the same guard, so the first batch also has to use the criteria file frozen in the build, months old by then, whatever the seats think of it.

**Who and cost.** Anyone holding funds that are known to be stolen and not yet listed. The cost is the gas of three deposits and the 0.2% entry fee at activation.

**Consequence.** About $153,000 of identified stolen funds can be the pool's first and only crowd on the day it opens, with the screeners unable to refuse it under their own published rule. The size is bounded by the first-step caps, and the 3-epoch hold still catches a careless thief. It is rated high because it is a free way round the one part of screening that deals with fresh thefts, the two sentences quoted above are false for every deposit of the first month, and the page's legal position rests on screening being real from the first activation (lines 196 and 1336).

**Smallest fix.** Either of two, and neither adds a mechanism. In the contract: let `flag` and `signalCriteria` be called for any registered seat, since they store nothing and the criteria file already filters by snapshot; flags posted during the 30-day wait then count in the first batch. Or in the node software: the first batch a node commits to covers nothing (`upTo` is 0), so `START` is set by an empty batch and the second day's batch, which can read a day of flags, is the first to approve anything.

**Confidence.** Certain.

### Q-2. High if misread. "Closing the previous epoch" after a day with no registry call

**Where.** Line 700: "Every state-changing function begins by closing the previous epoch if that has not been done. Closing records that epoch's majority hash, releases its pay if its batch was applied, folds new screeners into `activeCount`, and fixes the number that counts for the new epoch." Storage, lines 706 to 707: "`activeCount`, `joining`, `snapEpoch`, `snapActive`" and "`tally[epoch][batchHash]`, `leadHash`, `leadCount` | Matching reveals, and the hash with the most this epoch". The lead hash, the accepted hash and the applied flag are single variables. Only the tally is keyed by epoch.

**How it works.** The page never says what happens when the last call was in epoch e and the next one is in epoch e+2 or later. Two readings are natural.

- Reading A, the literal one: close epoch "now minus one".
- Reading B: close the epoch that was left open, the one in `snapEpoch`, however long ago it was.

Under reading A, with 15 screeners:

1. Day e: a batch is accepted with 10 reveals and applied. `leadHash`, the accepted hash and the applied flag hold e's values.
2. Day e+1: nobody calls the registry.
3. Day e+2, first call: the contract closes e+1 with e's values still in the single variables. It looks up how many revealed the accepted hash in `tally[e+1]`, finds 0, and divides the pot by 0. The call reverts.
4. Every later call begins with the same closing, so every later call reverts: no commit, no exit, no `withdrawStake`, no `withdrawPay`, no `evict`, no `fund`. Stakes and unpaid pay are locked for good, no batch is ever applied again, and every fee sweep whose 40% goes through `fund` reverts with it.

If the builder caches the count instead, step 3 does not revert and e+1 is recorded as a paid day with e's hash: e's revealers are never credited, a share of the 15% is spent on a day that had no batch, and every active screener gains two strikes for e+1, because none of them revealed that day.

A quiet day does not need an attacker. It happens on any day all screeners are down, and it happens with certainty at the end: commits stop "30 epochs param after the deposit window closes" (line 748), and the last paid epoch is closed by whoever calls next, which may be weeks later.

Reading B leaves two smaller holes. An epoch closed more than 16 epochs late writes a ring slot that the settle loop never reads ("within 16 epochs", line 746), so that day's pay belongs to nobody. And a screener in `joining` "counts from the next epoch" (line 714) without the page saying which epoch that is when the fold happens days later.

**Who and cost.** Nobody and nothing. Under reading A the registry breaks by itself on the first quiet day after a paid one.

**Consequence.** Reading A: permanent lock of every stake and all unpaid screener pay, and the end of activation. Reading B: one day's pay stranded in rare cases.

**Smallest fix.** One sentence: "closing acts on the epoch recorded in `snapEpoch`, whatever the gap; the epochs in between have no majority hash and pay nothing". Make the lead hash, the accepted hash and the applied flag fields of that epoch's record and clear them at closing. This fault could also be answered by removing the closing step altogether: see section 6, where pay and the majority hash are written when the batch is applied and when a reveal lands, so nothing is left for a later call to finish.

**Confidence.** Depends on reading. The storage list (a `snapEpoch` field) suggests the author means reading B, and the sentence says reading A.

### Q-3. High if misread. The active count can still be inflated, through `joining` and through `activate`

**Where.** Line 714: "`activate(seatId)` | The holder or operator, from 30 epochs after registering | Checks the seat is still held. Adds the screener to `joining`. It counts from the next epoch". Line 706: "`activeCount`, `joining`, `snapEpoch`, `snapActive` | Active screeners, those who become active at the next epoch, and the number fixed for the current epoch". Line 721: `requestExit` "Settles, stops counting at once, moves the stake to `unbonding`". Line 757: "`activeCount` equals the number of records that are active. It changes only when an epoch is closed, on an exit and on an eviction."

**How it works.** Revision 4.2 lost the count when a sold seat was registered again (M-17). Revision 4.3 answers with an invariant and a rule for `register`. Two paths to the same fault are left unspecified.

Path 1, a screener that leaves while it is in `joining`.

1. Day 30 after registering: the holder calls `activate`. `joining` rises by one.
2. Same day: the holder calls `requestExit` (or moves the seat to a second wallet and registers it there, which "evicts the record first, in full", or anyone calls `evict` on the moved seat). The record goes. The page says the exit "stops counting at once", and a screener in `joining` is not counting yet, so a builder has nothing to decrement.
3. Next epoch: closing "folds new screeners into `activeCount`". The count rises by one for a record that no longer exists.
4. The stake comes back after 14 epochs. Repeat with the same seat every 31 days, or with many seats at once.

Path 2, `activate` called twice. `commit` and `reveal` say "Once per epoch" and `register` says when it reverts. `activate` says neither. Built as written, each call adds to `joining`.

With 15 honest screeners the threshold is 10. Eight phantom screeners make the snapshot 23 and the threshold 16, which 15 real screeners can never reach. The flag quorum (more than half of the snapshot) rises with it. Nothing ever lowers a phantom count: `evict` needs a record.

**Who and cost.** Any seat holder. One seat, one stake (returned), a 30-day wait and gas. Path 2 costs gas only after the first wait.

**Consequence.** No batch can be accepted again. With no fallback rule, that is a permanent stop on activation for every future deposit, and the end of screener pay.

**Smallest fix.** State it per function: `activate` reverts unless the record is registered, not yet active and not already in `joining`; exit and eviction of a record in `joining` lower `joining`, not `activeCount`. Better, remove the counter `joining`: keep only "epoch active from" in the record and count a screener at the closing of the epoch before it. Then there is one counter and one place where it rises.

**Confidence.** Depends on reading. The invariant on line 757 is stated, so a fuzzing job that checks it would catch both paths. The function table as written does not prevent either.

### Q-4. Medium. The strike rule bounds a blockade at the group's share of seats, not at one day in three, and not at all at exactly half

**Where.** Line 742: "For each epoch that has a majority hash, a screener that was active and revealed it loses one strike, down to zero, and a screener that was active and did not, whether it revealed something else or nothing, gains two... An epoch with no majority hash changes nobody's count." Line 744: "A week of blocking gets the group removed, and so does any pattern that blocks more than one day in three." The same claim is on lines 111, 182 and 1504.

**How it works.** Three cases the sentence on line 744 does not cover. All were run in `strikes.py`.

1. Rotation. To stop a batch only "snapshot minus threshold plus one" members have to withhold. The rest of the group reveal the honest batch and lose a strike that day, although the day is blocked. With 30 screeners and a group of 14 (47%), 11 withhold each day and 3 rest. The group blocks 8 days in a row before anyone reaches 14 strikes, and then 42.6% of all days for ever with nobody above 13. With 15 of 31 it is 9 days in a row and 45.6% of days. The general bound is the group's size divided by three times the number that must withhold, which is close to the group's share of the snapshot. For a group of just over a third it is the page's one day in three. For a group of just under half it is nearly one day in two.
2. Exactly half. With 7 of 14 or 15 of 30, the honest half is not "more than half of the snapshot", so there is no majority hash on any day. Nobody gains a strike, the group reveals junk once a week to avoid the silence rule, and no batch is ever accepted. Neither side can remove the other.
3. Thin honest days. A strike needs the honest screeners who reveal the same batch to be more than half of the whole snapshot. With a group of 45%, two absent or out-of-step honest screeners in 30 make the day free for the blockers. They can decide at 19:59, after seeing the honest reveals, whether withholding will cost anything.

**Who and cost.** Seat holders with between a third and a half of the active seats. Against 16 honest screeners, 14 seats at 0.70 ETH are about 9.8 ETH of resalable capital and 14 stakes. Finding Q-5 shows the blocked days cost them no fee income either.

**Consequence.** Activation is delayed on up to almost half of all days, for ever, instead of the third the page states, and the first unbroken blockade is 8 or 9 days, not 7. At exactly half the stop is total. This is a delay and not a loss, and a group this large is one or two seats from the majority that the page already says controls the registry, which is why it is rated medium and not high.

**Smallest fix.** Two changes to constants and one to the rule, checked in `strikes_fix.py`. Give the credit of one strike only on a day when a batch was accepted, and make a miss cost three, with removal at 21. Then a group of any size under half blocks at most one day in three (25% of days for a bare third, 33% for 50 of 101). Dropping the credit on blocked days alone is not enough: at two strikes a miss, a group of 14 in 30 still blocks 39% of days. For exactly half, record the majority hash when a hash has at least half of the snapshot, or state on the page that an even split is a deadlock with no penalty. No mechanism needs to be removed for this.

**Confidence.** Certain for cases 1 and 2 (simulated from the rule as written). Case 3 depends on how reliable honest screeners are.

### Q-5. Medium. Blocked days still pay the blockers, and stakers gain when a batch fails

**Where.** Line 447, under "What revision 4.3 takes out": "The pot that carried blocked days forward to whoever revealed next." Line 433: "Fees from a day with no applied batch go to stakers." Against the build specification, line 746: "An epoch that does not pay leaves its fees in the pot", and line 779: `notify` "Sends 40% to the registry with `fund` if the registry's last applied batch is from this epoch or the one before, and otherwise adds it to the staker stream."

**How it works.** The pot was not taken out. What changed is the test in `notify`, and that test looks at yesterday, not at today.

1. Day 1 and day 2: batches applied. Day 3: a group blocks.
2. Any time on day 3, a member calls `Pool.sweepFees` for each asset. The last applied batch is from "the one before" (day 2), so the screeners' 40% goes to the pot. A sweep is allowed once a day per asset, so nobody can sweep again that day.
3. Day 3 closes unpaid. The fees stay in the pot.
4. Day 4: the group reveals, the batch is applied, and the pot, day 3's fees included, is divided among day 4's revealers. The blockers are among them.

So a group that blocks one day in three (or more, by Q-4) loses no fee income for the blocked days. The token share is only delayed (line 746), so it loses nothing there either. The fees go to stakers only when a sweep lands on the day after a failed day and before that day's `apply`, and screeners can always prevent that by sweeping late on the failed day. In a long blockade the rule does work from the second day on.

The same test gives stakers a reason to want batches to fail. A party with 60% of the stake and 40% of the revealing seats gains a fifth of the screeners' 40% on every sweep it can route to stakers. The sums are small at these caps ($5 a day in the first step), but the direction of the incentive is wrong: the party that can block a batch can also be the party that is paid when it is blocked.

One more leak from the same rule. On the day after the last batch ever (commits end 30 epochs after the deposit window closes, or the registry falls below seven and never recovers), the test still passes, a sweep sends 40% to the pot, and no paid epoch ever comes. Line 215 says "One rule covers a blockade, a dead registry and the time after deposits close." It leaves one day of screener fees stranded each time the registry stops.

**Who and cost.** Any blocking group, at the cost of one sweep transaction per asset on each blocked day.

**Consequence.** The answer to M-3 ("the pot paid them for the blocked days") holds for a continuous blockade and not for an intermittent one, which is the kind the strike rule permits for ever. Two summary lines on the page are false as built.

**Smallest fix.** Remove the test from `notify` and remove the carry: `fund` adds to a pot that is paid only to the revealers of the epoch in which the fees arrived, and at the closing of an epoch whose batch was not applied the pot is sent back to the distributor's staker stream. That is one rule in one contract, and it removes the cross-contract read of `lastApplied`. It could also be answered by removing the screeners' fee share from the registry altogether (section 6).

**Confidence.** Certain.

### Q-6. Medium. Pay written to the ring is in no ledger, so `fund` has two readings and unsettled pay is stranded

**Where.** Line 746: "the pot and one share of the 15% are divided equally among the screeners who revealed the accepted hash, with any remainder left in the pot, and the amount per head is written to the ring. Each of them is credited when next settled, within 16 epochs". Line 723: `fund` "Adds what arrived to the pot: the registry's balance of the asset less everything it already accounts for". Line 760: "the registry's balance is at least the pot plus everything owed plus, for the token, the stakes, the unbonding stakes and the unpaid part of the 15%." Line 708: a ring slot holds "how many revealed the accepted hash, and the pay per head in each asset". It does not hold how many have been credited.

**How it works.** Between the closing of an epoch and each screener's next settlement, that screener's pay is in neither `pot` nor `owed`. The page gives no name to money in that state.

Reading A: "everything it already accounts for" is the list in the invariant. Then a fee sweep that lands after a closing and before the screeners' commits counts yesterday's uncredited pay as newly arrived and puts it in the pot again. `ledger.py` runs this: the books exceed the balance by about one day's pay. It does not grow without limit, because the next `fund` subtracts the excess from what it adds. But when the new fees plus the uncredited pay are smaller than the excess, the subtraction underflows, `fund` reverts, and with it `notify` and the pool's sweep of that asset, until enough fees have built up in the pool. For the token the excess, about one daily share of the 15% (0.02% of supply, two thirds of a stake), is paid out of the stakes held in the same balance, and the last holder to withdraw a stake comes up short. That breaks "Nothing can reduce it" (line 759).

Reading B: the registry keeps a total of pay written to the ring and not yet credited. Then `fund` is right, and the pay of anyone who is never settled for that epoch stays in that total for good, because a reused slot cannot tell how much of it was claimed. This happens to:

- a screener that reveals and then exits, is evicted or has its seat registered by a buyer in the same epoch. Its record is settled up to the day before and then ends, and the epoch it revealed in closes later;
- a screener that reveals, stops, and is not touched by anyone for 16 epochs;
- every revealer of an epoch closed late (Q-2, reading B).

**Who and cost.** No attacker is needed. A holder with k of n revealing seats can also destroy k/n of a day's pay by exiting all of them after the reveal. It gains nothing by it.

**Consequence.** Small amounts stranded under the careful reading. Under the other one, a shortfall of about a day's pay per asset, taken from stakes in the token's case, and sweeps that fail from time to time.

**Smallest fix.** Name the third state: a per-asset total `reserved`, raised at closing and lowered at each credit, included in what `fund` subtracts and in the invariant. Add a credited count to the ring slot, and when a slot is reused return "per head times the number not credited" to the pot. Settle a record for the current epoch's pay before it ends, or let it be settled once more after it has ended. This could be answered by removing the ring: see section 6.

**Confidence.** Certain that the state is unnamed. Which reading a builder takes depends on the builder.

### Q-7. Medium. The 90-epoch bar does not bind a screener that leaves first

**Where.** Line 722: `evict` "removes the screener if one of three things is true: the seat has changed hands; it has not revealed for 7 epochs...; it has 14 strikes... For the last two grounds the seat is barred for 90 epochs". Line 721: `requestExit` "Settles, stops counting at once, moves the stake to `unbonding`". Line 713: `register` over an earlier holder's record "is evicted first, in full". Line 182: "A seat removed this way cannot register again for 90 days."

**How it works.** The bar is set only by an eviction on the silence or strike ground. Three ways round it, all one transaction:

1. A blocker at 12 or 13 strikes calls `requestExit`, and registers the same seat again at once. New record, no strikes, no bar, active again in 31 epochs. (This assumes an exit deletes the record. If it does not, path 3 does the same.)
2. A blocker at 14 strikes that sees an `evict` call waiting does the same ahead of it.
3. A blocker moves the seat to a second wallet. The first ground, "the seat has changed hands", is now true as well. The page does not say which ground decides when two hold. Registering from the second wallet evicts the old record "in full" on the first ground, with no bar.

Strikes live in the record and a record ends on exit, so strikes are reset by the same step.

**Who and cost.** Any screener. The cost is 31 days out of the registry in place of 121 (90 barred plus the 31-day wait). The stake comes back either way.

**Consequence.** The same seats can run a week-long blockade about every 38 days instead of every 128. A holder with spare seats needs about 6 waves of a blocking group, not about 18, to keep a blockade going without a break. With 15 honest screeners that is 48 seats, not 144. A holder with that many seats has easier routes to control, so this is rated medium, but the figure of 90 days on the page is not what the contract enforces.

**Smallest fix.** Either keep strikes and the bar on the seat and not on the record (`strikes[seatId]`, kept across exit and re-registration, and a bar on any exit or eviction with, say, 8 strikes or more), or remove the bar and its storage and say plainly that the penalty for a blockade is the 31-day wait. The second is the smaller design.

**Confidence.** Certain for paths 1 and 2. Path 3 depends on how `evict` orders its grounds.

### Q-8. Medium. The flag quorum is a share of the whole snapshot, so seats that do nothing vote against every flag

**Where.** Line 157: "quorum": "more than half of the snapshot". Line 176: "the published rule refuses a deposit that more than half of the screeners have flagged." Line 720, as above: the guard on `flag` is "an active screener". Unlike `commit` (line 715) it does not require that the registered holder still owns the seat.

**How it works.** A batch is computed by a program. A flag is not: someone has to decide that a deposit is stolen funds and send a transaction for each seat, within the one to two days the deposit waits. The quorum counts every seat in the snapshot, including seats whose operators run the node and nothing else, seats that are down, and sold seats nobody has evicted.

Take a snapshot of 20: 9 attentive screeners, 6 that only run the program, 5 friendly to a thief. The 9 flag the deposit. The quorum is 11, so the rule does not fire. The honest batch therefore approves the deposit, all 20 reveal it, it is accepted at 14, and the thief activates. Nobody gains a strike, because nobody deviated from the batch. The 5 friends were not even needed: 9 flags of 20 fail without them.

Revision 4.3 raised the quorum from a third to a majority so that a third could not refuse anyone (M-2). The page states the price of that on one side only: "Whatever number of seats can cause a refusal controls who may enter" (line 177). The other side is that half of the seats staying passive lets through anything that is on no list, and passivity is the default behaviour of a node.

A smaller point in the same place: because `flag` and `signalCriteria` do not check that the seat is still held, the operator key of a sold seat keeps its vote on flags and on the criteria file until someone evicts the record.

**Who and cost.** A thief needs nothing but ordinary turnout. To make sure, a quarter of the seats that agree not to flag is enough when another quarter is passive.

**Consequence.** The fresh-theft path the page offers as its answer to "Can a thief get a deposit approved, spend once, and be untouchable?" (line 293) works only if more than half of all seats act by hand inside two days. The page's open question 6 asks whether enough screeners will flag. It does not say that the count is taken over seats that never will.

**Smallest fix.** In the criteria file, not in a contract: a flag by a smaller share, for example a fifth of the snapshot, holds the deposit for a few epochs, once per deposit, and a flag by a majority refuses it. A hold costs the depositor days and cannot be turned into a forced refund while it is shorter than 21 days, so a fifth gains the power to delay and not to refuse. Add the seat-ownership check to `flag` and `signalCriteria`, or have the criteria file ignore events from seats whose owner has changed. Removing a mechanism does not answer this: flags are the only path for fresh information.

**Confidence.** Certain as arithmetic. How often it bites depends on how many operators flag.

### Q-9. Medium. Refund by others tests the deposit's age, not how long it has been refused, and the 21 days depend on a file no contract can see

**Where.** Lines 77 and 110: "A deposit that has stayed refused for three weeks can also be sent back by anyone." Line 650: "Anyone, once the deposit is at least 21 days old param and `Registry.isRefused(id, depositTime)`. ... The 21 days are longer than any hold or flag, so a refusal that is going to lapse cannot be turned into a forced refund." Line 168: "Refused in the first N batches that cover the deposit and cleared in the next." Line 1314: "It must stay longer than the longest hold and the life of a flag." Line 177: "The file is not in any contract, so screeners can adopt another".

**How it works.** The registry stores a bit, not the day the bit was set. The contract therefore lets anyone refund a deposit that is 21 days old and refused in the current batch, even if it was refused for the first time today. Three ways an honest deposit gets there:

1. Waiting at a full cap. The page expects caps to bind for up to 90 days at a time (lines 286 and 1508), and an approved deposit can wait in the queue for the next step. The first day a majority flags it, a rival for the same cap space sends it back. Without the refund it would have been delayed by the 14-day life of the flag. With it, the place is lost.
2. A hold counted in batches during a blockade. A 7-batch hold starts one to two days after the deposit. A group of 14 in 30 can block 8 days in a row and then 43% of days (Q-4). Seven applied batches then take about 12 more days, and the clearing batch lands on about day 23. From day 21 anyone can bounce the deposit. If "N batches" is read as N epochs this path closes, and a hold that falls inside a blockade is never set at all. The page does not say which.
3. A longer hold in a later file. Two thirds of the seats can adopt a file with a 30-epoch hold. Every deposit it holds becomes refundable by anyone after day 21. The contract's constant cannot follow the file.

**Who and cost.** Anyone, for one transaction, once the conditions hold. Path 1 needs a majority to flag, path 2 a group of nearly half, path 3 a careless or hostile change of file.

**Consequence.** The depositor gets the funds back at the depositing address and loses the place in the queue and the gas. Nothing is lost for good, so this is medium. The sentence "cannot be turned into a forced refund" is true only while batches arrive daily and the file keeps its present numbers.

**Smallest fix.** Remove refund by others. The depositor can always refund, refused deposits are outside the caps, and a deposit that sits in `pending` for ever costs nobody anything. That removes `isRefused`, one parameter, one transition of the state machine and this whole class of fault (section 6). If it is kept, the registry has to record the epoch in which each refusal began, which is a second bitmap or a per-deposit slot.

**Confidence.** Certain for the age test and path 3. Path 2 depends on reading.

### Q-10. Medium. The 96-word rule lets a depositor with capital starve clearances and buy a head start at `START`

**Where.** Lines 737 to 739: "Words that set a bit come first, then words that only clear bits... At most 96 words. If more than 96 words set a bit, the batch lists the first 96 of them and lowers upTo to just below the first deposit of the first one left out. Words that only clear bits and do not fit wait for the next day." Line 161: the hold on a deposit "> 10 ETH" from an address first funded within 72 hours.

**How it works.** A depositor can make the rules set a bit in a word of its choice: a deposit of just over 10 ETH from a fresh address is held, and holding sets a bit. Filler deposits of 0.005 ETH move the deposit counter 256 ids to the next word. All of it is refundable in full.

- Starving clearances. Ninety-six held deposits a day in 96 different words use the whole batch. No word that only clears a bit fits, so no hold of anyone else's is lifted while this goes on. One wave is 961 ETH for one to two days plus 24,576 fillers (about 1.2 billion gas, 0.25 ETH at 0.2 gwei). Kept up for three weeks it turns every 3-epoch and 7-epoch hold in the pool into a deposit that anyone may send back (Q-9).
- A head start. Deposits wait for a month before `START`. A depositor who places its own deposit first and 97 held deposits in the 97 words after it limits the first batch to the ids below the 97th word. Everything later waits a day, and whoever is covered first fills the 25 ETH cap. Rewards for a cap step go to whoever fills it (line 1508).
- Cost of `apply`. A full batch is "about 2.1M today and 10.6M under Glamsterdam" (line 904). The screeners' whole pay is about $31 a day (line 1034). At the 30-day mean gas price on the page, 0.418 gwei, a full batch costs about $2 today and $9 after the fork, and at 5 gwei about $22 today and over $100 after it. On such days nobody is paid for applying, and a batch that is not applied is dropped.

**Who and cost.** Someone with about 1,000 to 2,000 ETH for days at a time and a few hundred dollars of gas a day. That is real money, which is why this is medium.

**Consequence.** Delay of activation for others, holds that never clear while the flood lasts, and a bought first place at each opening.

**Smallest fix.** Reserve part of the batch for clearances, for example at most 64 words that set a bit and at least 32 that clear. No mechanism has to be removed, and removing refund by others (Q-9) takes away the worst outcome.

**Confidence.** Certain as to the rule. Whether anyone would pay for it is a guess.

### Q-11. Low. Three terms of the example criteria do not do what the table says

**Where.** Line 169: "`fundedByListed` | Of the value in the deposited asset that the depositor received in the 7 days before the deposit, the share that came straight from listed addresses. A share, so that dust sent by a listed address changes nothing". Line 170: "`firstFunded` | The time of the first block in which the depositor received a listed asset". Line 152: "inputs": "logs, receipts and the value of top-level transactions only". Line 171: the file in force is "The one whose hash more than two thirds of the snapshot's seats have signalled, counting each seat's latest signal up to the base block. Until one has, the file named in the parameter file".

**How it works.**

1. Dust does change something. The share is taken over what the address received in the last 7 days, not over the deposit or the balance. An address that held its ETH for a month and received nothing this week has a denominator of zero. One wei from a listed address makes the share 100% and the deposit is held for 7 batches. With no inflow at all the share is 0 divided by 0, which the page does not define, and two programs that treat it differently produce different batches.
2. Both hold rules are avoided with one contract hop when the asset is ETH. ETH sent from inside a contract call appears in no log and is not the value of a top-level transaction. An address funded that way has no "first funded" time and no listed funder. The page says internal transfers are left out so that nodes agree (line 179). It does not say that the two rules meant to hold "large and freshly funded deposits" (line 1502) then hold only the careless.
3. The file in force can fall back. Read as written, the test is made each epoch on the current snapshot. If a file was adopted by 14 of 20 seats and 2 new seats join without signalling, 14 of 22 is under two thirds, no file has the quorum, and the rule says the parameter file is in force again: the lists of the freeze day, months or years old. A group of just over a third that registers and stays silent can roll the criteria back this way. The other reading, that an adopted file stays until another reaches two thirds, is not what the sentence says.

**Who and cost.** For 1, the holder of a listed address, at the cost of dust. For 2, any depositor. For 3, new seats amounting to a few percent of the registry.

**Consequence.** Wrong holds, avoidable holds, and a criteria file that can move backwards. All three are in a file that is in no contract, so they are low: they can be corrected without touching the build. The third decides what every node computes, so it has to be settled before the screening program is written.

**Smallest fix.** Take the share over the larger of the 7-day inflow and the deposit's value. Say on the page that the ETH hold rules see top-level transfers only. Define the file in force as the last file to have reached two thirds. Nothing needs removing.

**Confidence.** Certain for 1 and 2. For 3, depends on reading.

### Q-12. Low. In a small registry, removing a blocking third stops the registry

**Where.** Line 716: acceptance needs "the snapshot is at least seven". Line 722: eviction at 14 strikes. Line 474: "Seven screeners is a cliff (M-24)."

**How it works.** With 7 to 10 active screeners, a group that can block is 3 or 4 seats. After a week it has 14 strikes. Evicting it leaves 4 to 6 screeners, under seven, so no batch can be accepted until replacements have waited 31 epochs. The honest screeners must choose between a registry blocked part of the time and one stopped for a month. The page admits the cliff for one departure. It does not say that the strike rule, the remedy for a blockade, walks the registry over it. The canary starts at exactly seven.

**Who and cost.** Three seats, about 2.1 ETH of resalable capital, in a registry of seven.

**Consequence.** A month without activation, or a tolerated blockade. Rated low because the page accepts the cliff and the launch gate asks for fifteen seats.

**Smallest fix.** None inside the decided rules. State it beside the cliff, and make the fifteen seats of the launch gate a condition on registered seats in the real registry, not on seats screening another pool. The minimum of seven and the strike rule are both decided, so neither can be removed to answer it.

**Confidence.** Certain.

### Q-13. Low. Anyone can restart a holder's 14-day stake clock by evicting one of its stale records

**Where.** Line 705: "`unbonding[holder]` | Stake waiting to be returned, one total per holder, and the epoch it is released. Adding to it restarts the 14 epochs for the whole amount". Line 722: `evict` is open to anyone and "Moves the stake to `unbonding` for the holder who posted it". Line 759: "A stake leaves only to the holder who posted it, 14 epochs after exit or eviction."

**How it works.** A holder exits 20 seats and waits. It also has 5 records for seats it sold without exiting. On day 13 someone evicts one of the five ("the seat has changed hands"). The clock restarts for all 21 stakes. Thirteen days later, the next one. Five stale records delay the whole amount by 65 days. A buyer who registers a bought seat does the same without meaning to.

**Who and cost.** Anyone, for gas.

**Consequence.** Delay only, and the holder can end it by evicting its own stale records in one go. The invariant on line 759 is wrong as worded.

**Smallest fix.** Key the waiting stake by holder and release epoch, `unbonding[holder][epoch]`, so that an addition never moves an amount that is already waiting. The restart rule is the mechanism to remove here.

**Confidence.** Certain.

### Q-14. Low. A swarm list that adds up to more than 10% is paid out of the founder's share, and the contract could prevent it

**Where.** Line 230: "The contract cannot check that the list adds up to 10%, so the launch gate asks for a published recomputation". Line 817: "The founder's and each swarm entry's payout never exceeds the vested amount, and never exceeds the allocation."

**How it works.** The Distribution contract holds the swarm's 10% and the founder's 5% in one balance. If the Merkle list sums to 11% of supply, swarm claims succeed until 11% has gone and the founder's last 1% cannot be paid. The contract cannot check the sum of the list. It can keep a running total of swarm payouts and refuse to go past 10%.

**Who and cost.** Whoever builds the list, by mistake or not. The gate that guards it is off-chain (line 1430).

**Consequence.** Up to the founder's 5% misdirected in the worst case.

**Smallest fix.** One counter, `swarmPaid`, and one comparison in `claimSwarm`. This adds a check and removes nothing.

**Confidence.** Certain.

### Q-15. Low. A stablecoin issuer that freezes the registry or the distributor stops that asset's fee flow for everyone

**Where.** Line 779: `notify` "Sends 40% to the registry with `fund`". Line 506: "A token transfer that fails reverts the call". Line 1514 lists freezes of the pool and of a depositor only.

**How it works.** USDC refuses transfers to a frozen address. If Circle freezes the registry, `notify(USDC)` reverts at the transfer of the screeners' 40%, so `sweepFees(USDC)` reverts, and the stakers' 40% and the basket's 20% of USDC fees stay in the pool with it. Freezing the distributor has the same effect at the first transfer.

**Who and cost.** The issuer only.

**Consequence.** That asset's fees pile up in the pool. Users and other assets are not affected, so it fails safe.

**Smallest fix.** If the transfer to the registry fails, add the amount to the staker stream. Add the case to the risk row. Cut 4 in section 6 does not remove this, since the registry would still receive the 40%.

**Confidence.** Certain for USDC. USDT blocks transfers from a frozen address, not to one.

### Q-16. Low. The auction's floor is a fixed number of IMD, and a backlog is sold at a stale price

**Where.** Line 781: "The buyer names assets by id... The next starting price is twice the price paid, and never under a minimum param that is above the floor." Line 1281: "First starting price 100 IMD from the first receipt, floor 1 IMD, minimum restart 10 IMD."

**How it works.** `misc.py` confirms that with a steady flow the auction sells at fair value: at 505 IMD a day of fees it settles on a sale every half day at about 253 IMD. Two edges fall outside that.

1. The floor never moves. In the first 90 days the basket grows by about 0.95 IMD a day. If IMD's price rises a hundredfold, 1 IMD is $264 and the basket is sold about every hundred days.
2. An asset that could not be transferred for a time leaves a backlog. While USDC is frozen for the distributor, buyers leave it out and the price tracks the other assets. On the day of the thaw the basket holds months of USDC against a price set by the last small sale, and the first transaction takes it for that price. The difference goes to whoever orders the block.

**Who and cost.** For 2, a block builder or the fastest bidder, after an issuer's action.

**Consequence.** Lumpy sales, and one windfall per thaw at the buyback's expense.

**Smallest fix.** Feed an asset back through its 7-day basket stream when it becomes transferable again, and accept the first edge as a cost of pricing in IMD. Paying the 20% in kind to stakers, with no auction, would remove both edges and the buyback with them, which the owner's 20% decision rules out.

**Confidence.** Certain as mechanics. Likelihood is low.

### Q-17. Low. The screener whose reveal completes the two thirds gets the first place at every opening

**Where.** Line 716: "When a hash reaches two thirds of the snapshot... it is the accepted batch of the epoch." Line 717: `apply` by "Anyone, from acceptance". Line 1508: "Whoever fills a cap first collects that step's rewards".

**How it works.** The reveal that crosses the threshold, `apply` and the screener's own `activate` fit in one transaction. Nobody else can activate under that batch before it. On the first batch ever, which opens a pool with a month of queued deposits and a 25 ETH cap, the screener that holds back its reveal until it is the deciding one fills the cap. The same holds on any day new cap space and a new batch coincide.

**Who and cost.** Any screener willing to reveal last. With several seats it is easy to be the one.

**Consequence.** The first-come rewards of each step go to a screener by construction. The page admits the race and not that one party always wins it.

**Smallest fix.** None that is small: it follows from `apply` being open to the revealer. Record it beside the cap race in the risk table.

**Confidence.** Certain.

## 3. Contradictions between sections

| # | Passage A | Passage B | Which a builder would follow |
| --- | --- | --- | --- |
| 1 | Line 447, taken out in 4.3: "The pot that carried blocked days forward to whoever revealed next." | Line 746: "An epoch that does not pay leaves its fees in the pot." | B. The pot still carries. See Q-5 |
| 2 | Line 433: "Fees from a day with no applied batch go to stakers." Line 215: "When no batch was applied the day before, it goes to stakers instead." | Line 779: 40% goes to the registry "if the registry's last applied batch is from this epoch or the one before". | B. Fees swept on the failed day itself go to the pot |
| 3 | Lines 77 and 110: a deposit "that has stayed refused for three weeks" can be sent back by anyone. | Line 650: "once the deposit is at least 21 days old" and refused now. | B. The registry cannot know how long a bit has been set. See Q-9 |
| 4 | Line 773: `accounted[asset]` is "The sum of every amount above for the asset", and `buybackImd` is listed below it. | Line 790: `accounted` is "... plus the staked tokens for the token and `buybackImd` for IMD." | B. Built from A, each IMD sweep would split the waiting buyback money 40, 40, 20 a second time and the buyback would spend IMD owed to stakers. Medium if misread |
| 5 | Line 760: "Total token pay never exceeds the 15%." | Lines 746 and 779: the pot also receives 40% of fees paid in the token, and pays them to screeners. | B. The invariant should say "token pay from the budget" |
| 6 | Line 759: a stake leaves "14 epochs after exit or eviction". | Line 705: "Adding to it restarts the 14 epochs for the whole amount". | B. See Q-13 |
| 7 | Line 744: "any pattern that blocks more than one day in three" gets the group removed. Line 111: a minority "can cost a day now and then". | Line 742: a member that reveals the majority hash loses a strike on any day that has one, blocked days included. | B. The bound is the group's share. See Q-4 |
| 8 | Line 182: "A seat removed this way cannot register again for 90 days." | Lines 721 and 713: exit and re-registration by a new holder set no bar. | B. See Q-7 |
| 9 | Line 914: "The build page lists the salt and the six addresses." | Line 802: the token's address depends on `block.prevrandao` and the caller of `launch`. | B. Five addresses can be published before launch. The token's is read from `Distribution.token()` |
| 10 | Line 109: "Screeners always have between one and two days to refuse stolen funds". | Lines 714 and 720: nobody can flag before the first screeners are active. | B. See Q-1 |
| 11 | Line 241: "Revision 4.3 had recommended 0.005%", on the page of revision 4.3. Line 1031 says "recommended in revision 4.3" beside the decided 0.03%. | Line 53: the stake is 0.03%, decided. | The decided value. Wording only |
| 12 | Line 808: "About one candidate in six is skipped". | Line 1561: a random address sorts below IMD's "about 82.5% of the time". | Either. 17.5% is nearer one in 5.7 |
| 13 | Line 700: closing "releases its pay". | Line 746: the pay is written to the ring and "credited when next settled". | B. Nothing is released at closing. See Q-6 |

## 4. Points a builder would have to guess

1. Which epoch is closed after a gap, and from which epoch a screener folded late counts (Q-2).
2. What `fund` subtracts: whether pay written to the ring and not yet credited is "accounted for" (Q-6).
3. Whether `activate` can be called twice, and what exit or eviction does to a record in `joining` (Q-3).
4. What happens to a record on exit. If it is kept, `register` "reverts" for the same holder for ever. If it is deleted, the pay for the epoch of the exit has no record to be credited to.
5. Which seats `withdrawPay(assets)` settles. The registry has no index from a holder to its seats, so the call needs seat ids.
6. That `snapActive` must not move when a screener exits mid-epoch. "Stops counting at once" could be read as lowering it, and then a group that reveals and exits lowers the threshold under its own reveals: 40% of a snapshot could accept a batch.
7. Whether `evict` sets the bar when the strike ground and "the seat has changed hands" are both true (Q-7).
8. Who "was active" in an epoch for strikes: the snapshot at its start, including a screener that exited or was evicted during it.
9. Whether a hold of N counts applied batches, accepted batches or epochs (Q-9).
10. The set of seats in "this epoch's snapshot". The registry stores a count. The criteria file needs the set, and has to say whether a sold seat that nobody has evicted is in it.
11. `fundedByListed` with no inflow, whether a failed top-level transaction counts, and whether "listed" is read at the base block or at the time of the transfer (Q-11).
12. What a node does when the call to the sanctions oracle reverts or the oracle is retired. The page notes that its owner can retire it (line 305).
13. Which file is in force when the quorum is lost, and whether a signal made under a previous holder of the seat counts (Q-11).
14. Which rule is named in `dataCid` when two rules refuse one deposit.
15. How a staker stream's clock "stops" when the stake falls to zero in mid-stream: whether the end time is pushed out by the idle time.
16. In `collect()`, that the tokens burned are the amount the pool returns and never the contract's own balance, which holds the unvested founder and swarm tokens.
17. In `launch`, the "highest usable tick" (887,200 at a spacing of 200), and what happens to the few base units of the 25% that rounding leaves in the contract.
18. Whether the window edges are inclusive: a reveal at exactly hour 12 or hour 20, an `apply` in the last second of the epoch.
19. What registry calls do before `GENESIS`, when the epoch number would be negative.
20. Whether a seat barred under one holder stays barred for a buyer. As written it does, since the bar is on the seat.
21. What `notify` does when the transfer to the registry fails (Q-15).
22. Whether `flag` and `signalCriteria` begin by closing the previous epoch like other state-changing functions, given that they "store nothing".

## 5. What held

Each line says what was attacked and why it stood.

**Launch**

- The launch cannot be blocked by creating pools first. Of 256 candidates about 211 sort below IMD's address (`0xd34a` of `0x10000` is 82.5%). Creating a Uniswap v3 pool costs about 4.5M gas, so 13 fit a 60M block and 3 fit one transaction under the 16.7M cap. Under the draft Glamsterdam prices one pool is about 34M gas and cannot share a block with a 45M launch at all. The candidates depend on `block.prevrandao`, which the proposer of the slot before can know one block early, and on the sender, which nobody knows before the transaction is seen. The best-placed adversary removes 13 candidates and leaves 198.
- The launch cannot be crowded out for long. To keep a 45M transaction out of a 60M block an adversary has to buy the whole block at a higher tip, and full blocks raise the base fee by an eighth each time: about ten times after 20 blocks.
- The loop's gas is as stated: two hashes and one cold read of the factory per candidate, under 5,000 gas, about 1.3M for all 256.
- One orientation. With the token as the lower address the price is IMD per token, the 25% sits above the starting tick, and a pool initialised exactly at that tick takes no IMD when the position is placed. For a supply of one billion the starting tick is −99,600 (a valuation of about 47,300 IMD after rounding down, 1.5% under 48,000). The position's liquidity is about 1.7 × 10^24 against a limit per tick of about 3.8 × 10^34.
- A stranger can add liquidity to the Distribution contract's own position, because Uniswap lets anyone mint to any owner. That only donates tokens to a position nobody can withdraw, and the buyback step uses the liquidity recorded at launch.
- The Deployer is not circular. Its address depends on the five code hashes, the five contracts read their creator and compute the others from it, and the nonces are fixed at 1 to 5 because a failed creation reverts.

**Arithmetic on the page** (`econ.py`)

- The range: 12,000 × f / (1 − f) IMD, price 1 / (1 − f)², every row of the table, and the 6% ceiling (0.25 × f × (1 − f) peaks at 6.25%).
- Stakes: 14.4, 18.6, 29.3, 89.7 and 558 IMD for the 1st, 100th, 250th, 500th and 700th; 833 stakes in all; 220 IMD for fifteen; 1,222 for 77; 57.7 after half the pool is bought; $68 after a quarter.
- Emission: 0.77% of the users' share in the first 90 days, 12.2% in the first year, 510 tokens per ETH-equivalent per day, 1.11% a year at the start. The unlock table matches to two decimals with 30-day months.
- Fees: every row of both tables, 11,194 IMD to the buyback over 730 days, $26 a day for the screeners' 15% and $5.03 for their 40% in the first step.
- IMD's share of rewards: all five rows.
- The canary: cap steps on days 10 to 50, emissions end on day 81, deposits close on day 85, all inside 90 days of its `START`. The end of commits falls on day 115 and is correctly listed as a fork test. The caps are worth $3,197 at the start and $102,304 at the last step, and 10 ETH fills them through the third level ($12,788).
- `apply` with 96 new words: 2.12M gas today, 10.56M under Glamsterdam.

**Fee distributor** (`misc.py`)

- The new scales work. A stream of 0.4 USDT pays out 399,999 of 400,000 units whether the total stake is one base unit or 79 billion tokens. The largest intermediate value, for an amount of 2^96, is 216 bits.
- Staking for a block around a sweep earns nothing extra, since every receipt is spread over seven days.
- The auction sells at fair value when fees flow steadily: at 0.95, 30 and 505 IMD a day it settles on sales at 1.0, 15.5 and 253 IMD. A buyer who buys dust to reset the price pays the full price for it. Nothing lowers the price except time.
- The buyback step is 60 IMD per 12 hours at the starting price, against at most about 15 arriving. Pushing the price up before a step enlarges the step in proportion, and the round trip still costs the attacker 2% in pool fees against a gain of at most 1%. A step of one wei sent to use up the 12 hours delays later money by 12 hours and no more.
- A transfer fee on USDT would not break the books of the distributor or the registry, since both count what arrived.

**Registry**

- No capture approves a deposit younger than a day and a half: approval needs the deposit to be a day old at the epoch's start and no reveal lands before hour 12.
- No batch decides a deposit made after its epoch began, whatever `upTo` and the bitmap say. A bit set for a deposit not yet covered is ignored.
- At most one batch is accepted per epoch, because twice the threshold is more than the snapshot. The threshold and the blocking size were checked for 7 to 15 screeners.
- A commitment cannot be copied from the chain: it includes the seat id, and reveals start after commits close.
- Lazy settlement cannot be used to dodge strikes. A reveal needs a commit in the same epoch and a commit settles. Anyone can force a settlement by calling `evict`. A screener that neither commits nor reveals falls to the 7-epoch rule. Strikes stop at zero, so good days cannot be banked.
- Taking turns does not beat plain capture. Waves of seats that are active together need more than two thirds of the registry between them before one wave can block. Waves that are active one at a time need about 48 seats against 15 honest ones, three times the 16 that make a majority.
- One seat is one record. Starving the `ownerOf` call of gas to make a seat look "not held" does not work: the caller keeps only a 64th of the gas, too little to finish the eviction.
- A dropped batch fails safe. Strikes are counted on the majority hash whether or not the batch is applied, the next day covers the same deposits, and `START` is set only by an applied batch. Keeping `apply` out of 1,200 consecutive slots is beyond any builder.
- The batch is a function of the chain as far as I could test it: the base block is finalized, the bitmap is read there, and since a batch is applied in its own epoch or never, the bitmap at the base block is final. The snapshot count follows from the state at the base block.
- Tokens or ETH sent straight to the registry or the distributor are counted at the next receipt and are a gift.
- A refund by the depositor needs no call to the registry, so no registry state can stop it, provided the two conditions are tested in that order.

## 6. What I would cut

Six of the seventeen findings (Q-2, Q-3, Q-6, Q-7, Q-9 and Q-10) sit in three things the registry gained in revisions 4.2 and 4.3: the lazy settlement from a ring with its counters, the bar, and the refund by others with its 21 days. All three can go or shrink without touching a decision of the owner's. In order of what they would save:

1. **Refund by others.** Remove the second caller of `Pool.refund`, the view `Registry.isRefused`, the parameter of 21 days, the transition "Refused to Refunded by anyone" and the canary line that tests it. The depositor's own refund stays. Cost: a refused deposit whose owner never comes back stays in `pending` for ever. It is outside the caps and earns nothing, so it costs nobody else anything. The page's reason for the rule is that such funds "need not sit in the pool" (line 110), which is tidiness. In exchange Q-9 disappears, the worst outcome of Q-10 goes with it, and the contract stops depending on numbers in a file it cannot read.

2. **The ring, the closing step and the `joining` counter.** Replace `ring[16]` by a plain mapping from epoch to one record (majority hash, accepted hash, applied, number of revealers, pay per head) that is written once and never reused. Drop the slot tag, the reuse rule, "within 16 epochs" and the invariant about tags. Drop `joining` and keep only "epoch active from" in the screener's record. A screener is then settled for any past epoch whenever it next calls, with no deadline. Cost: about three to eight storage slots a day for the life of the registry, some 5,000 to 12,000 slots in four years, paid by the first caller of each day (roughly 0.07M to 0.18M gas today and up to 0.9M under Glamsterdam). That removes the expiry cases of Q-6, the late-closing hole of Q-2 and one of the two paths of Q-3. The ring saves state the registry can afford.

3. **The bar.** Remove `barredUntil` and the sentence about 90 days. As Q-7 shows, it binds only a screener that waits to be evicted, and the 31-day wait already applies to everyone who leaves. Cost: an evicted blocker is back in 31 days, which is what happens today to any blocker that reads the contract. If the owner wants the 90 days to be real, the strikes and the bar have to live on the seat and survive exit, which is more state, not less.

4. **The test in `notify` and the carry in the pot.** Send the screeners' 40% to the registry always. At the closing of an epoch whose batch was not applied, the registry returns that epoch's pot to the distributor's staker stream. Remove the distributor's read of `lastApplied` and the rule "this epoch or the one before". Cost: one transfer back on a failed day. This removes Q-5 and the stranded pot at the end of the registry's life, and makes line 433 true.

5. **Per-asset pay, if the owner reopens it.** The page itself records the option on line 1320: sell the whole fee for IMD in the one auction and pay stakers and screeners in IMD. That turns five staker streams, five pots and five pay-per-head figures into one of each and removes `accounted` per asset. The cost is the one the page names: all fee income priced in IMD. It is the largest cut available in this area and it is the owner's call, since payment in the asset received was decided.

6. **Smaller.** The minimum restart price of the auction (the floor does the same work, one parameter less). `Distribution.collect()` and `fundBuyback`, if the position's trading fees are left where they are: two functions and one cross-contract call fewer, at the cost of about 1% of what buyers pay into the pool never reaching the buyback.

What I would not cut: the salt loop (it is small and it holds), the seven-epoch silence rule (it is the only way to clear dead seats on days with no majority hash), the 96-word limit, and the on-chain flag and signal events.

## 7. Suspicions not made concrete, and what I did not check

- **Seats held for a moment.** `register`, `activate`, `commit` and `reveal` each test ownership at the moment of the call. If seats can be bought and sold back inside one transaction from a pool, a screener could run records on borrowed seats and tie up no capital in between, as long as nobody evicts the records. I did not check whether any such market for seats exists.
- **Splitting the honest screeners.** I looked for an input an attacker controls that would make two honest nodes compute different batches (boundary blocks, flags in the base block, the snapshot, the bitmap) and found none, given published test vectors. The screening program does not exist yet, so this is a reading of rules, not a test.
- **A finality stall longer than 12 hours** would leave every honest node unable to commit. It fails safe, with no majority hash and no strikes.
- **The sanctions oracle's owner** can list an address that has open deposits in more than 96 words, such as a shared deposit contract, and pull `screenedThrough` back for everyone above it, 96 words a day. It follows from the upTo rule and I did not cost it.
- **IMD's bridge key.** The page says it could buy every fee basket. With created IMD it could also buy the whole public float, hold most of the stake and so collect 40% of all fees in ETH and stablecoins, and price every later screener stake out of reach. This is a cost of the decided pairing, recorded and not rated.
- **The launch under Glamsterdam.** Whether a single transaction may carry about 40M of state gas depends on the final text of EIP-8037. The page lists this as a fork test and I could not do better.
- **Uniswap's protocol fee** on the 1% tier, which the page also leaves open.
- **Not checked.** The circuit, the fee note, the relay-fee ceiling and the inside of the Pool contract, by instruction. No public reference was consulted during this run: the gas of `createPool`, the behaviour of `prevrandao`, minting to another owner in Uniswap v3 and the transfer rules of USDT and USDC are stated from knowledge of those systems and were not re-read.
