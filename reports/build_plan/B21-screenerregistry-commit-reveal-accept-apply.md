# B21 · ScreenerRegistry: commit, reveal, accept, apply

**Kind:** Build · **IMD template:** `impl_tests_review` · **Steps:** `implement-and-test`, `write-foundry-tests`, `adversarial-review`
**Depends on:** B20
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement commit (first 57,600 seconds of an epoch), reveal (last 28,800), the tally with leadHash and
leadCount, acceptance at two thirds of the snapshot rounded up with a snapshot of at least seven, the majority
hash (the lead, recorded when the epoch ends if more than half of the snapshot revealed it), the miss counter
(a screener that revealed something else in an epoch with a majority hash has one more miss; one that revealed
the majority hash has none), apply, isApproved, isRefused, flag and signalCriteria. A batch is {epoch,
criteriaHash, upTo, words[], dataCid}, hashed as keccak256(abi.encode(...)) in that order. apply(batch)
requires its hash to be the accepted batch of its epoch, that epoch to be later than lastApplied, and at most
96 words in ascending order; it sets dataTime to the start of that epoch, sets screenedThrough to upTo and
overwrites the listed bitmap words. isApproved(id, depositTime) is id <= screenedThrough, bit clear, and
depositTime + 86,400 <= dataTime. No commit is taken from 30 epochs after the deposit window closes. Work only
from the pinned commit of the project repository and the build specification (`reports/Murmuration v4
specification.html`, section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no
network. No owner, admin, pause, upgrade or setter may appear in any contract. Every duration is in seconds of
block.timestamp counted from Params.GENESIS; no schedule may count blocks. If the specification is ambiguous,
stop and report the ambiguity instead of choosing.

## Contracts named

- `src/ScreenerRegistry.sol`

## Paths the job may write

- `src/ScreenerRegistry.sol`
- `test/RegistryBatches.t.sol`

## Acceptance tests

1. A batch is accepted exactly when matching reveals reach ceil(2n/3) with n >= 7 the snapshot count; never with n < 7; at most one per epoch (fuzz over reveal orders).
2. A reveal that does not match the screener's commitment, or arrives outside the reveal window, reverts; each screener commits and reveals once per epoch.
3. apply reverts for a batch that is not accepted, whose epoch is not later than lastApplied, that lists more than 96 words, or whose words are not ascending.
4. No deposit with depositTime + 86,400 > dataTime is approved, whatever upTo says: a batch with upTo = 2^64-1 approves nothing made later than one day before its epoch began (fuzz).
5. Misses: a screener that reveals a non-majority hash in 7 consecutive epochs with a majority becomes evictable; revealing the majority hash resets the count; an epoch with no majority changes nobody's count.
6. A minority of one third plus one revealing junk for 7 epochs can be evicted, after which the remaining screeners accept a batch (scenario test).
7. apply with 96 words uses under 3,000,000 gas today and under 16,777,216 execution gas under the EIP-8037 model in the test.
8. The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
