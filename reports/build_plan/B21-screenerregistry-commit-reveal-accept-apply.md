# B21 · ScreenerRegistry: commit, reveal, accept, apply

**Kind:** Build · **IMD template:** `impl_tests_review` · **Steps:** `implement-and-test`, `write-foundry-tests`, `adversarial-review`
**Depends on:** B20
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement the epoch of 86,400 seconds from GENESIS: commit in the first 43,200, reveal in the next 28,800, and
apply from acceptance until the epoch ends. Implement the tally with leadHash and leadCount, acceptance at two
thirds of the snapshot rounded up with a snapshot of at least seven, and at closing the majority hash (the
lead, if more than half of the snapshot revealed it). Strikes, worked out when a screener is settled: for each
closed epoch in the ring with a majority hash in which the screener was active, minus one (floor zero) if it
revealed that hash, plus two if it did not, silence included. A batch is {epoch, criteriaHash, upTo, words[],
dataCid}, hashed as keccak256(abi.encode(...)) in that order. apply(batch) requires its hash to be the
accepted batch of the current epoch, not yet applied, and at most 96 words; it sets dataTime to the start of
the epoch, screenedThrough to upTo, overwrites the listed words, sets lastApplied, and on the first apply ever
records start. isApproved(id, depositTime) is id <= screenedThrough, depositTime + 86,400 <= dataTime, and bit
clear; isRefused is the same two conditions and bit set. flag(seatId, depositId) and signalCriteria(seatId,
hash) emit events. No commit is taken from Params.COMMIT_END_WAIT epochs after the deposit window closes. Work
only from the pinned commit of the project repository and the build specification (`reports/Murmuration v4
specification.html`, section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no
network. No owner, admin, pause, upgrade or setter may appear in any contract. Every duration is in seconds of
block.timestamp; no schedule may count blocks. Screening epochs count from Params.GENESIS; caps, emissions and
the deposit window count from START, which the registry records at its first applied batch. If the
specification is ambiguous, stop and report the ambiguity instead of choosing.

## Contracts named

- `src/ScreenerRegistry.sol`

## Paths the job may write

- `src/ScreenerRegistry.sol`
- `test/RegistryBatches.t.sol`

## Acceptance tests

1. A batch is accepted exactly when matching reveals reach ceil(2n/3) with n >= 7 the snapshot count; never with n < 7; at most one per epoch (fuzz over reveal orders).
2. A reveal that does not match the commitment, comes outside hours 12 to 20, or comes from a seat no longer held reverts; each screener commits and reveals once per epoch.
3. apply reverts for a batch that is not the accepted batch of the current epoch, after the epoch has ended, a second time, or with more than 96 words. Batches of different epochs never depend on each other (a skipped epoch changes nothing for the next).
4. No deposit with depositTime + 86,400 > dataTime is approved or refused, whatever upTo and the bitmap say: a batch with upTo = 2^64-1 and every bit set decides nothing made later than a day before its epoch (fuzz).
5. Strikes: four of ten screeners silent six days and revealing on the seventh are evictable on day 9; alternating silence and junk reaches 14 in seven days; one miss in three never reaches 14; an epoch with no majority changes nobody's count.
6. start is zero until the first apply and never changes afterwards.
7. apply with 96 words uses under 3,000,000 gas today and under 16,777,216 execution gas under the EIP-8037 model in the test.
8. The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
