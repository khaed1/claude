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
