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

**Smallest fix.** Drop the credit of one strike on a day when no batch was accepted. Then every blocked day costs the whole group something or nothing, rotation gains nothing, and the bound is one day in three for every group size. Record the majority hash when a hash has at least half, not more than half, or state that exactly half is a known deadlock. No mechanism needs to be removed for this.

**Confidence.** Certain for cases 1 and 2 (simulated from the rule as written). Case 3 depends on how reliable honest screeners are.

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
