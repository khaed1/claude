# B40 · Distribution: launch and the locked position

**Kind:** Build · **IMD template:** `impl_tests_review` · **Steps:** `implement-and-test`, `write-foundry-tests`, `adversarial-review`
**Depends on:** B10
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement launch(), callable once by anyone from GENESIS. It creates the Token with CREATE2 and the salt
keccak256(abi.encode(block.prevrandao, msg.sender)), so the token's address cannot be computed before the
block; sends 45% of supply to the Pool and 15% to the Registry; creates the token/IMD Uniswap v3 pool at the
1% tier and initializes it at the starting price. If someone in the same block has already created and priced
it above the start, it sells at most Params.LAUNCH_RESET_MAX tokens with the starting price as the limit,
sends the IMD received to the distributor with fundBuyback, and reverts the whole call if the price is still
above the start. It then mints one position from the start tick to the maximum usable tick with what is left
of the 25%, owned by this contract, and records token, pool and the position's liquidity. Implement the views
token(), pool() and liquidity(), zero before launch, and the mint and swap callbacks, restricted to the pool.
Work only from the pinned commit of the project repository and the build specification (`reports/Murmuration
v4 specification.html`, section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no
network. No owner, admin, pause, upgrade or setter may appear in any contract. Every duration is in seconds of
block.timestamp counted from Params.GENESIS; no schedule may count blocks. If the specification is ambiguous,
stop and report the ambiguity instead of choosing.

## Contracts named

- `src/Distribution.sol`

## Paths the job may write

- `src/Distribution.sol`
- `src/interfaces/IUniswapV3.sol`
- `test/DistributionLaunch.t.sol`
- `test/vendor/uniswap-v3-core/`

## Acceptance tests

1. After launch the Pool holds 45%, the Registry 15%, the position 25% less at most LAUNCH_RESET_MAX, and 15% stays here for the swarm and founder, to the rounding stated in the test.
2. launch reverts before GENESIS, and a second launch reverts. token(), pool() and liquidity() are zero before and constant after.
3. The token's address has no code before launch and differs for a different prevrandao or caller (fuzz).
4. launch succeeds when a same-block front-runner created the pool, priced it above the start and added bids that LAUNCH_RESET_MAX tokens clear; it reverts, changing nothing, when they do not, and a retry in a later block succeeds at a new token address.
5. Gas: with 60,000,000 gas of dust positions placed in front in the same block, launch either completes under 16,777,216 execution gas or reverts cleanly; the measured worst case is reported.
6. The position is one-sided in the token for both token orderings, and also when the front-runner priced the pool below the start.
7. No function in the ABI can call pool.burn with a non-zero amount; a test enumerates selectors and a symbolic test checks liquidity never falls.
8. The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
