# B22 · ScreenerRegistry: pay

**Kind:** Build · **IMD template:** `impl_tests` · **Steps:** `implement-and-test`
**Depends on:** B21
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement fund(asset), callable by the distributor, which adds to the pot whatever arrived: the registry's
balance of the asset less everything it already accounts for. Implement the 16-slot ring, each slot tagged
with its epoch and cleared when reused: the accepted hash, whether it was applied, the majority hash, how many
revealed the accepted hash, and the pay per head in each asset. An epoch pays when its batch was both accepted
and applied: at its closing the pot and one share of the screeners' token budget are divided equally among
those who revealed the accepted hash, the remainder stays in the pot, and the amount per head is written to
the ring. The budget is paid in 730 equal shares (paidEpochs counts them); after the 730th there is no token
share. A screener is credited when settled (at its next commit, exit, withdrawal or eviction attempt), to
owed[holder][asset], within 16 epochs. withdrawPay(assets) pays the caller. Work only from the pinned commit
of the project repository and the build specification (`reports/Murmuration v4 specification.html`, section
"Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause,
upgrade or setter may appear in any contract. Every duration is in seconds of block.timestamp; no schedule may
count blocks. Screening epochs count from Params.GENESIS; caps, emissions and the deposit window count from
START, which the registry records at its first applied batch. If the specification is ambiguous, stop and
report the ambiguity instead of choosing.

## Contracts named

- `src/ScreenerRegistry.sol`

## Paths the job may write

- `src/ScreenerRegistry.sol`
- `test/RegistryPay.t.sol`

## Acceptance tests

1. Each screener who revealed the accepted and applied batch is credited pot/agreed for every asset; others are credited nothing; the remainder stays in the pot.
2. An epoch whose batch was accepted and not applied pays nobody, keeps its fees in the pot and does not use a token share.
3. After 730 paid epochs the token paid equals SCREENER_BUDGET less rounding and never exceeds it; the 731st pays fees only.
4. For each asset, balance >= pot + sum of owed, plus stakes, unbonding stakes and the unpaid budget for the token, after every call (invariant test).
5. Pay earned through a seat that is then sold is paid to the holder who earned it, never to the buyer.
6. A ring slot is read only when its tag matches: a screener settled after more than 16 epochs gets nothing for the overwritten epoch and never another epoch's pay.
7. fund books the amount that arrived even when the token takes a fee on transfer (mock). Registry deployed size is at most 24,576 bytes.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
