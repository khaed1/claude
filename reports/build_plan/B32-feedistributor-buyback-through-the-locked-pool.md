# B32 · FeeDistributor: buyback through the locked pool

**Kind:** Build · **IMD template:** `impl_tests_review` · **Steps:** `implement-and-test`, `write-foundry-tests`, `adversarial-review`
**Depends on:** B31, B40
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement buyback(): at most once per 25 blocks, swap IMD for the token in the Uniswap v3 pool created by
Distribution, exact input, recipient the burn address. The amount is min(buybackImd, FEE * virtualImdReserve /
2) where virtualImdReserve is computed from pool.liquidity() and slot0.sqrtPriceX96 for IMD's side of the
pair, and FEE is the pool's fee rate. Implement uniswapV3SwapCallback, which pays only when called by that
pool. Tests run against the real Uniswap v3 core bytecode. Work only from the pinned commit of the project
repository and the build specification (`reports/Murmuration v4 specification.html`, section "Build
specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade
or setter may appear in any contract. If the specification is ambiguous, stop and report the ambiguity instead
of choosing.

## Contracts named

- `src/FeeDistributor.sol`

## Paths the job may write

- `src/FeeDistributor.sol`
- `src/interfaces/IUniswapV3.sol`
- `test/DistributorBuyback.t.sol`

## Acceptance tests

1. The step never exceeds half of fee rate times IMD-side virtual reserves, for token0 and token1 orderings (fuzz over prices).
2. A second buyback within 25 blocks reverts.
3. The swap callback reverts for any caller but the pool, and pays exactly the amount owed.
4. Sandwich test: for 200 fuzzed attacker sizes, buying before a step and selling after it loses money net of the two fees.
5. buybackImd falls only inside the callback; a test enumerates every external function and checks it, and IMD owed to stakers is untouched by a buyback.
6. Bought tokens arrive at the burn address and the pool's IMD balance rises by the amount spent.
7. The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job. The Uniswap v3 core artifacts are
vendored as files because the job has no network.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
