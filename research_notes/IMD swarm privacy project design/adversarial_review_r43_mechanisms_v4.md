# Adversarial review of Murmuration v4, revision 4.3: registry, launch, fees and canary

Status: IN PROGRESS. This note is written as the review proceeds; sections below fill in as findings are confirmed.

## 1. Header

- Reviewed: "Murmuration v4 specification, revision 4.3", plain-text rendering (1,604 lines), dated 11 November 2026. No other file was read. Line numbers below are lines of that text file.
- Area: Screening (with the example criteria file), Token and fee, build-specification contracts 3 ScreenerRegistry, 4 FeeDistributor, 5 Distribution and 6 Token, the deposit state machine as far as screening decides it, Deployment and the canary, Economics simulated, and the related rows of Parameters, Defaults, Risks, and the gas of `launch` and `apply`.
- Scripts used for the arithmetic and the simulations are in the session scratchpad under `review_r43/mech/` (`strikes.py`, `econ.py`, `ledger.py`, `misc.py`). They are not part of the repository.
- Verdict: (pending, see the end of the run)

Terms used below. An *epoch* is one day counted from `GENESIS`. The *snapshot* is the number of active screeners fixed for an epoch. A *strike* is a point against a screener that did not reveal the majority's batch. The *ring* is the registry's record of the last 16 epochs. To *settle* a screener is to work out its strikes and credit its pay from the ring. The *pot* is the screeners' share of fees waiting to be paid.

## 2. Findings

### Q-1. High if misread. "Closing the previous epoch" after a day with no registry call

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

### Q-2. High if misread. The active count can still be inflated, through `joining` and through `activate`

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

### Q-3. Medium. The strike rule bounds a blockade at the group's share of seats, not at one day in three, and not at all at exactly half

**Where.** Line 742: "For each epoch that has a majority hash, a screener that was active and revealed it loses one strike, down to zero, and a screener that was active and did not, whether it revealed something else or nothing, gains two... An epoch with no majority hash changes nobody's count." Line 744: "A week of blocking gets the group removed, and so does any pattern that blocks more than one day in three." The same claim is on lines 111, 182 and 1504.

**How it works.** Three cases the sentence on line 744 does not cover. All were run in `strikes.py`.

1. Rotation. To stop a batch only "snapshot minus threshold plus one" members have to withhold. The rest of the group reveal the honest batch and lose a strike that day, although the day is blocked. With 30 screeners and a group of 14 (47%), 11 withhold each day and 3 rest. The group blocks 8 days in a row before anyone reaches 14 strikes, and then 42.6% of all days for ever with nobody above 13. With 15 of 31 it is 9 days in a row and 45.6% of days. The general bound is the group's size divided by three times the number that must withhold, which is close to the group's share of the snapshot. For a group of just over a third it is the page's one day in three. For a group of just under half it is nearly one day in two.
2. Exactly half. With 7 of 14 or 15 of 30, the honest half is not "more than half of the snapshot", so there is no majority hash on any day. Nobody gains a strike, the group reveals junk once a week to avoid the silence rule, and no batch is ever accepted. Neither side can remove the other.
3. Thin honest days. A strike needs the honest screeners who reveal the same batch to be more than half of the whole snapshot. With a group of 45%, two absent or out-of-step honest screeners in 30 make the day free for the blockers. They can decide at 19:59, after seeing the honest reveals, whether withholding will cost anything.

**Who and cost.** Seat holders with between a third and a half of the active seats. Against 16 honest screeners, 14 seats at 0.70 ETH are about 9.8 ETH of resalable capital and 14 stakes. Finding Q-4 shows the blocked days cost them no fee income either.

**Consequence.** Activation is delayed on up to almost half of all days, for ever, instead of the third the page states, and the first unbroken blockade is 8 or 9 days, not 7. At exactly half the stop is total. This is a delay and not a loss, and a group this large is one or two seats from the majority that the page already says controls the registry, which is why it is rated medium and not high.

**Smallest fix.** Two changes to constants and one to the rule, checked in `strikes_fix.py`. Give the credit of one strike only on a day when a batch was accepted, and make a miss cost three, with removal at 21. Then a group of any size under half blocks at most one day in three (25% of days for a bare third, 33% for 50 of 101). Dropping the credit on blocked days alone is not enough: at two strikes a miss, a group of 14 in 30 still blocks 39% of days. For exactly half, record the majority hash when a hash has at least half of the snapshot, or state on the page that an even split is a deadlock with no penalty. No mechanism needs to be removed for this.

**Confidence.** Certain for cases 1 and 2 (simulated from the rule as written). Case 3 depends on how reliable honest screeners are.

### Q-4. Medium. Blocked days still pay the blockers, and stakers gain when a batch fails

**Where.** Line 447, under "What revision 4.3 takes out": "The pot that carried blocked days forward to whoever revealed next." Line 433: "Fees from a day with no applied batch go to stakers." Against the build specification, line 746: "An epoch that does not pay leaves its fees in the pot", and line 779: `notify` "Sends 40% to the registry with `fund` if the registry's last applied batch is from this epoch or the one before, and otherwise adds it to the staker stream."

**How it works.** The pot was not taken out. What changed is the test in `notify`, and that test looks at yesterday, not at today.

1. Day 1 and day 2: batches applied. Day 3: a group blocks.
2. Any time on day 3, a member calls `Pool.sweepFees` for each asset. The last applied batch is from "the one before" (day 2), so the screeners' 40% goes to the pot. A sweep is allowed once a day per asset, so nobody can sweep again that day.
3. Day 3 closes unpaid. The fees stay in the pot.
4. Day 4: the group reveals, the batch is applied, and the pot, day 3's fees included, is divided among day 4's revealers. The blockers are among them.

So a group that blocks one day in three (or more, by Q-3) loses no fee income for the blocked days. The token share is only delayed (line 746), so it loses nothing there either. The fees go to stakers only when a sweep lands on the day after a failed day and before that day's `apply`, and screeners can always prevent that by sweeping late on the failed day. In a long blockade the rule does work from the second day on.

The same test gives stakers a reason to want batches to fail. A party with 60% of the stake and 40% of the revealing seats gains a fifth of the screeners' 40% on every sweep it can route to stakers. The sums are small at these caps ($5 a day in the first step), but the direction of the incentive is wrong: the party that can block a batch can also be the party that is paid when it is blocked.

One more leak from the same rule. On the day after the last batch ever (commits end 30 epochs after the deposit window closes, or the registry falls below seven and never recovers), the test still passes, a sweep sends 40% to the pot, and no paid epoch ever comes. Line 215 says "One rule covers a blockade, a dead registry and the time after deposits close." It leaves one day of screener fees stranded each time the registry stops.

**Who and cost.** Any blocking group, at the cost of one sweep transaction per asset on each blocked day.

**Consequence.** The answer to M-3 ("the pot paid them for the blocked days") holds for a continuous blockade and not for an intermittent one, which is the kind the strike rule permits for ever. Two summary lines on the page are false as built.

**Smallest fix.** Remove the test from `notify` and remove the carry: `fund` adds to a pot that is paid only to the revealers of the epoch in which the fees arrived, and at the closing of an epoch whose batch was not applied the pot is sent back to the distributor's staker stream. That is one rule in one contract, and it removes the cross-contract read of `lastApplied`. It could also be answered by removing the screeners' fee share from the registry altogether (section 6).

**Confidence.** Certain.

### Q-5. Medium. Pay written to the ring is in no ledger, so `fund` has two readings and unsettled pay is stranded

**Where.** Line 746: "the pot and one share of the 15% are divided equally among the screeners who revealed the accepted hash, with any remainder left in the pot, and the amount per head is written to the ring. Each of them is credited when next settled, within 16 epochs". Line 723: `fund` "Adds what arrived to the pot: the registry's balance of the asset less everything it already accounts for". Line 760: "the registry's balance is at least the pot plus everything owed plus, for the token, the stakes, the unbonding stakes and the unpaid part of the 15%." Line 708: a ring slot holds "how many revealed the accepted hash, and the pay per head in each asset". It does not hold how many have been credited.

**How it works.** Between the closing of an epoch and each screener's next settlement, that screener's pay is in neither `pot` nor `owed`. The page gives no name to money in that state.

Reading A: "everything it already accounts for" is the list in the invariant. Then a fee sweep that lands after a closing and before the screeners' commits counts yesterday's uncredited pay as newly arrived and puts it in the pot again. `ledger.py` runs this: the books exceed the balance by about one day's pay. It does not grow without limit, because the next `fund` subtracts the excess from what it adds. But when the new fees plus the uncredited pay are smaller than the excess, the subtraction underflows, `fund` reverts, and with it `notify` and the pool's sweep of that asset, until enough fees have built up in the pool. For the token the excess, about one daily share of the 15% (0.02% of supply, two thirds of a stake), is paid out of the stakes held in the same balance, and the last holder to withdraw a stake comes up short. That breaks "Nothing can reduce it" (line 759).

Reading B: the registry keeps a total of pay written to the ring and not yet credited. Then `fund` is right, and the pay of anyone who is never settled for that epoch stays in that total for good, because a reused slot cannot tell how much of it was claimed. This happens to:

- a screener that reveals and then exits, is evicted or has its seat registered by a buyer in the same epoch. Its record is settled up to the day before and then ends, and the epoch it revealed in closes later;
- a screener that reveals, stops, and is not touched by anyone for 16 epochs;
- every revealer of an epoch closed late (Q-1, reading B).

**Who and cost.** No attacker is needed. A holder with k of n revealing seats can also destroy k/n of a day's pay by exiting all of them after the reveal. It gains nothing by it.

**Consequence.** Small amounts stranded under the careful reading. Under the other one, a shortfall of about a day's pay per asset, taken from stakes in the token's case, and sweeps that fail from time to time.

**Smallest fix.** Name the third state: a per-asset total `reserved`, raised at closing and lowered at each credit, included in what `fund` subtracts and in the invariant. Add a credited count to the ring slot, and when a slot is reused return "per head times the number not credited" to the pot. Settle a record for the current epoch's pay before it ends, or let it be settled once more after it has ended. This could be answered by removing the ring: see section 6.

**Confidence.** Certain that the state is unnamed. Which reading a builder takes depends on the builder.

### Q-6. Medium. The 90-epoch bar does not bind a screener that leaves first

**Where.** Line 722: `evict` "removes the screener if one of three things is true: the seat has changed hands; it has not revealed for 7 epochs...; it has 14 strikes... For the last two grounds the seat is barred for 90 epochs". Line 721: `requestExit` "Settles, stops counting at once, moves the stake to `unbonding`". Line 713: `register` over an earlier holder's record "is evicted first, in full". Line 182: "A seat removed this way cannot register again for 90 days."

**How it works.** The bar is set only by an eviction on the silence or strike ground. Three ways round it, all one transaction:

1. A blocker at 12 or 13 strikes calls `requestExit`, and registers the same seat again at once. New record, no strikes, no bar, active again in 31 epochs.
2. A blocker at 14 strikes that sees an `evict` call waiting does the same ahead of it.
3. A blocker moves the seat to a second wallet. The first ground, "the seat has changed hands", is now true as well. The page does not say which ground decides when two hold. Registering from the second wallet evicts the old record "in full" on the first ground, with no bar.

Strikes live in the record and a record ends on exit, so strikes are reset by the same step.

**Who and cost.** Any screener. The cost is 31 days out of the registry in place of 121 (90 barred plus the 31-day wait). The stake comes back either way.

**Consequence.** The same seats can run a week-long blockade about every 38 days instead of every 128. A holder with spare seats needs about 6 waves of a blocking group, not about 18, to keep a blockade going without a break. With 15 honest screeners that is 48 seats, not 144. A holder with that many seats has easier routes to control, so this is rated medium, but the figure of 90 days on the page is not what the contract enforces.

**Smallest fix.** Either keep strikes and the bar on the seat and not on the record (`strikes[seatId]`, kept across exit and re-registration, and a bar on any exit or eviction with, say, 8 strikes or more), or remove the bar and its storage and say plainly that the penalty for a blockade is the 31-day wait. The second is the smaller design.

**Confidence.** Certain for paths 1 and 2. Path 3 depends on how `evict` orders its grounds.

### Q-7. High. No flag can count in the first batch, and the first batch covers every deposit of the first month

**Where.** Line 720: "`flag(seatId, depositId)`, `signalCriteria(seatId, hash)` | The operator of an active screener | Emit an event and store nothing." Line 714: "a screener is active no sooner than 31 epochs after registering. There is no shortcut at launch". Line 156: flags are "events up to the base block, from seats in this epoch's snapshot", and the base block is "the last block whose timestamp is before the epoch's start" (line 151). Line 648: `deposit` is open to "Anyone, from launch". Against the claims on line 109, "Screeners always have between one and two days to refuse stolen funds", and line 175, "whatever a screener learns in the first day after a deposit can still stop it."

**How it works.** A flag is the only way knowledge that is on no list gets into a batch (line 176). Only an active screener can post one. The first screeners become active at the start of epoch 31 at the earliest. The first batch is the batch of that same epoch, and it reads flags only up to the last block of epoch 30, when nobody was active and every call to `flag` reverted. So the first batch contains no flag by construction. It covers every deposit made from launch to the end of epoch 29.

1. Day 5 after launch: a protocol is drained. The thief's addresses are public within hours and on no sanctions list (the page itself says designations take weeks, line 295).
2. Day 6: the thief deposits 25 ETH, 50,000 USDT and 50,000 USDC, the whole of the first-step caps, in amounts of 10 ETH or less or from addresses funded more than 72 hours before, so the one hold rule that could apply does not. The deposits are refundable and cost gas only.
3. Days 6 to 30: every registered seat holder knows. None can flag.
4. Day 31: the published program outputs a batch that covers those deposits and refuses none of them. An honest node commits and reveals it. A screener that reveals anything else gains two strikes if a majority follows the program.
5. Day 31, after hour 12: the batch is applied, which sets `START`. The thief activates and fills the ETH, USDT and USDC caps. Honest depositors who have waited a month find the caps full until day 90 unless the thief leaves.

Flags posted on day 31 count from the batch of day 32. By then the notes are in the tree and "cannot be removed afterwards" (line 185). The same holds on the canary, with a wait of 3 days.

**Who and cost.** Anyone holding funds that are known to be stolen and not yet listed. The cost is the gas of three deposits and the 0.2% entry fee at activation.

**Consequence.** About $153,000 of identified stolen funds can be the pool's first and only crowd on the day it opens, with the screeners unable to refuse it under their own published rule. The size is bounded by the first-step caps, and the 3-epoch hold still catches a careless thief. It is rated high because it is a free way round the one part of screening that deals with fresh thefts, the two sentences quoted above are false for every deposit of the first month, and the page's legal position rests on screening being real from the first activation (lines 196 and 1336).

**Smallest fix.** Either of two, and neither adds a mechanism. In the contract: let `flag` and `signalCriteria` be called for any registered seat, since they store nothing and the criteria file already filters by snapshot; flags posted during the 30-day wait then count in the first batch. Or in the node software: the first batch a node commits to covers nothing (`upTo` is 0), so `START` is set by an empty batch and the second day's batch, which can read a day of flags, is the first to approve anything.

**Confidence.** Certain.

### Q-8. Medium. The flag quorum is a share of the whole snapshot, so seats that do nothing vote against every flag

**Where.** Line 157: "quorum": "more than half of the snapshot". Line 176: "the published rule refuses a deposit that more than half of the screeners have flagged." Line 720, as above: the guard on `flag` is "an active screener". Unlike `commit` (line 715) it does not require that the registered holder still owns the seat.

**How it works.** A batch is computed by a program. A flag is not: someone has to decide that a deposit is stolen funds and send a transaction for each seat, within the one to two days the deposit waits. The quorum counts every seat in the snapshot, including seats whose operators run the node and nothing else, seats that are down, and sold seats nobody has evicted.

Take a snapshot of 20: 9 attentive screeners, 6 that only run the program, 5 friendly to a thief. The 9 flag the deposit. The quorum is 11, so the rule does not fire. The honest batch therefore approves the deposit, all 20 reveal it, it is accepted at 14, and the thief activates. Nobody gains a strike, because nobody deviated from the batch. The 5 friends were not even needed: 9 flags of 20 fail without them.

Revision 4.3 raised the quorum from a third to a majority so that a third could not refuse anyone (M-2). The page states the price of that on one side only: "Whatever number of seats can cause a refusal controls who may enter" (line 177). The other side is that half of the seats staying passive lets through anything that is on no list, and passivity is the default behaviour of a node.

A smaller point in the same place: because `flag` and `signalCriteria` do not check that the seat is still held, the operator key of a sold seat keeps its vote on flags and on the criteria file until someone evicts the record.

**Who and cost.** A thief needs nothing but ordinary turnout. To make sure, a quarter of the seats that agree not to flag is enough when another quarter is passive.

**Consequence.** The fresh-theft path the page offers as its answer to "Can a thief get a deposit approved, spend once, and be untouchable?" (line 293) works only if more than half of all seats act by hand inside two days. The page's open question 6 asks whether enough screeners will flag. It does not say that the count is taken over seats that never will.

**Smallest fix.** In the criteria file, not in a contract: a flag by a smaller share, for example a fifth of the snapshot, holds the deposit for a few epochs, once per deposit, and a flag by a majority refuses it. A hold costs the depositor days and cannot be turned into a forced refund while it is shorter than 21 days, so a fifth gains the power to delay and not to refuse. Add the seat-ownership check to `flag` and `signalCriteria`, or have the criteria file ignore events from seats whose owner has changed.

**Confidence.** Certain as arithmetic. How often it bites depends on how many operators flag.

## 3. Contradictions between sections

(pending)

## 4. Points a builder would have to guess

(pending)

## 5. What held

(pending)

## 6. What I would cut

(pending)

## 7. Suspicions not made concrete, and what I did not check

(pending)
