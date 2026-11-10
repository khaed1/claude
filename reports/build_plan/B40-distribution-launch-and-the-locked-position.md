# B40 · Distribution: launch and the locked position

**Kind:** Build · **IMD template:** `impl_tests_review` · **Steps:** `implement-and-test`, `write-foundry-tests`, `adversarial-review`
**Depends on:** B10
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement launch(), callable once by anyone: send 45% of supply to the Pool and 15% to the Registry; create
the token/IMD Uniswap v3 pool at the 1% tier if absent; initialize it at the starting price if not
initialized; if it is initialized above the starting price, swap at most Params.LAUNCH_RESET_MAX tokens with a
price limit at the start and revert if the price is still above it; then mint one position from the start tick
to the maximum usable tick with 25% of supply, owned by this contract. Implement the mint and swap callbacks,
restricted to the pool. Work only from the pinned commit of the project repository and the build specification
(`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30, Foundry,
optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any contract. If the
specification is ambiguous, stop and report the ambiguity instead of choosing.

## Contracts named

- `src/Distribution.sol`

## Paths the job may write

- `src/Distribution.sol`
- `src/interfaces/IUniswapV3.sol`
- `test/DistributionLaunch.t.sol`
- `test/vendor/uniswap-v3-core/`

## Acceptance tests

1. After launch the five destinations hold 45%, 25% (in the pool), 15%, and 15% left here for the swarm and founder, to the wei of rounding stated in the test.
2. launch succeeds when the pool does not exist, exists uninitialized, is initialized at the start, below it, and above it with dust liquidity.
3. launch reverts, changing nothing, if bringing the price down would need more than LAUNCH_RESET_MAX tokens.
4. The position is one-sided in the token for both token orderings (test with two IMD mock addresses).
5. No function in the ABI can call pool.burn with a non-zero amount; a test enumerates selectors and a symbolic test checks liquidity never falls.
6. A second launch reverts. Callbacks revert for any caller but the pool.
7. The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
