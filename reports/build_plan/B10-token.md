# B10 · Token

**Kind:** Build · **IMD template:** `impl_tests` · **Steps:** `implement-and-test`
**Depends on:** B00
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement the Token contract: a plain ERC-20 with 18 decimals whose constructor creates the whole supply for
the Distribution address passed in. No owner, mint, burn function, permit, hook, fee or blocklist. Work only
from the pinned commit of the project repository and the build specification (`reports/Murmuration v4
specification.html`, section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no
network. No owner, admin, pause, upgrade or setter may appear in any contract. If the specification is
ambiguous, stop and report the ambiguity instead of choosing.

## Contracts named

- `src/Token.sol`

## Paths the job may write

- `src/Token.sol`
- `test/Token.t.sol`

## Acceptance tests

1. totalSupply equals Params.SUPPLY after construction and after any sequence of transfers (invariant test).
2. The ABI contains only the ERC-20 functions and events; a test enumerates selectors and fails on any other.
3. transfer and transferFrom move exactly the amount requested and revert on insufficient balance or allowance.
4. Deployed size is under 3,000 bytes.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
