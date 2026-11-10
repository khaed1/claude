# B12 · Pool: deposit, activate, refund

**Kind:** Build · **IMD template:** `impl_tests_review` · **Steps:** `implement-and-test`, `write-foundry-tests`, `adversarial-review`
**Depends on:** B11
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement the Pool's deposit, activate and refund functions and their accounting exactly as in the build
specification: record hash per deposit, pending/shielded/fees per asset, the cap counted on activated value
only, the 7,200-block minimum age, Registry.isApproved read at activation, the entry fee of amount/500, the
commitment computed on-chain as H3(packed, index, ownerCommit) and inserted as H4(commitment, 0, 0, 0). The
reward index is read through an internal hook that B13 fills; use a stub returning a stored value. spend is
out of scope. Work only from the pinned commit of the project repository and the build specification
(`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30, Foundry,
optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any contract. If the
specification is ambiguous, stop and report the ambiguity instead of choosing.

## Contracts named

- `src/Pool.sol`

## Paths the job may write

- `src/Pool.sol`
- `src/interfaces/IRegistry.sol`
- `test/PoolDeposit.t.sol`
- `test/mocks/MockRegistry.sol`
- `test/mocks/Tokens.sol`

## Acceptance tests

1. Only the depositor can activate or refund; any other caller reverts (fuzzed caller).
2. A deposit ends in exactly one of activated or refunded; a second activate or refund reverts.
3. refund returns exactly the deposited amount in every screening state, including refused, and after the deposit window.
4. activate reverts before 7,200 blocks, when not approved, and when shielded + net would exceed cap(asset).
5. deposit reverts after DEPOSIT_END, for an unlisted asset, below the smallest size, and when the amount received differs from the amount named (fee-on-transfer mock).
6. For each asset, balance >= pending + shielded + fees after every call (invariant test, 5,000 runs).
7. The emitted commitment equals the reference computed in the test from the event fields.
8. The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
