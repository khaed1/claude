# B40 · Distribution: launch and the locked position

**Kind:** Build · **IMD template:** `impl_tests_review` · **Steps:** `implement-and-test`, `write-foundry-tests`, `adversarial-review`
**Depends on:** B10
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement launch(), callable once by anyone from GENESIS. For n from 0 to 255 it computes the CREATE2 address
of the Token with the salt keccak256(abi.encode(block.prevrandao, msg.sender, n)) and takes the first
candidate that is numerically below the IMD address and for which UniswapV3Factory.getPool(candidate, IMD,
10000) is the zero address; it reverts if none qualifies. It creates the Token there, sends 45% of supply to
the Pool and 15% to the Registry, creates the pool, initializes it at the starting price, and mints one
position with the 25% from the starting tick to the highest usable tick, owned by this contract. The starting
tick is the starting price rounded down to a multiple of 200. It records token, pool, the position's liquidity
and launchTime. There is no price reset: the pool cannot exist before this transaction. Implement the views
token(), pool(), liquidity() and launchTime(), zero before launch, and the mint callback, restricted to the
pool. Work only from the pinned commit of the project repository and the build specification
(`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30, Foundry,
optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any contract. Every
duration is in seconds of block.timestamp; no schedule may count blocks. Screening epochs count from
Params.GENESIS; caps, emissions and the deposit window count from START, which the registry records at its
first applied batch. If the specification is ambiguous, stop and report the ambiguity instead of choosing.

## Contracts named

- `src/Distribution.sol`

## Paths the job may write

- `src/Distribution.sol`
- `src/interfaces/IUniswapV3.sol`
- `test/DistributionLaunch.t.sol`
- `test/vendor/uniswap-v3-core/`

## Acceptance tests

1. After launch the Pool holds 45%, the Registry 15%, the position 25%, and 15% stays here for the swarm and founder, to the rounding stated in the test.
2. launch reverts before GENESIS, and a second launch reverts. token(), pool(), liquidity() and launchTime() are zero before and constant after.
3. The token's address is below IMD's for every prevrandao and caller (fuzz), so the token is token0 and the position holds tokens only.
4. With pools created in the same block for the first 13 qualifying candidates, launch succeeds at the 14th; the front-runner's gas is at least 13 pool creations and launch's extra gas is under 150,000.
5. With every one of the 256 candidates blocked (test-only cheat), launch reverts and changes nothing; a later block succeeds.
6. Execution gas of launch is under 16,777,216 in every case above, and total gas under the EIP-8037 model is reported with the share that is state gas.
7. No function in the ABI can call pool.burn with a non-zero amount; a test enumerates selectors and a symbolic test checks liquidity never falls.
8. The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
