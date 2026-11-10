# B14 · Pool: spend

**Kind:** Build · **IMD template:** `impl_tests_review` · **Steps:** `implement-and-test`, `write-foundry-tests`, `adversarial-review`
**Depends on:** B12, B13
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Add spend to the Pool: checkpoint roll, known-root check, gRef equal to gCur or gPrev, extHash recomputed as
keccak256(chainid, pool address, recipient, keccak(ct0), keccak(ct1)) reduced mod p, two unused and distinct
nullifiers, and for a non-zero public amount: a standard size of that asset (1, 2, 5 times a power of ten
within the asset's range), the per-asset limit (for the token: tokenOut + amount <= tokenIn + released), the
exit fee of amount/500 and payment of the rest to the recipient. Then verify through IVerifier, mark
nullifiers, insert one leaf H4(C0..C3), emit Spent with both ciphertexts. Wire B13's library in place of the
stub. Use a mock verifier in tests; real proofs come in B60. Work only from the pinned commit of the project
repository and the build specification (`reports/Murmuration v4 specification.html`, section "Build
specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade
or setter may appear in any contract. If the specification is ambiguous, stop and report the ambiguity instead
of choosing.

## Contracts named

- `src/Pool.sol`

## Paths the job may write

- `src/Pool.sol`
- `src/interfaces/IVerifier.sol`
- `test/PoolSpend.t.sol`
- `test/mocks/MockVerifier.sol`

## Acceptance tests

1. spend reverts on: unknown root, stale gRef, wrong extHash, a used nullifier, equal nullifiers, a public input >= p, a non-standard size, publicAsset != 0 with publicAmount == 0.
2. A withdrawal pays the recipient exactly amount - amount/500 and adds amount/500 to fees, for every listed size of every asset.
3. Total withdrawn per asset never exceeds total activated; for the token never exceeds activated + released (invariant test with a verifier that accepts everything).
4. Re-entrancy from an ETH recipient or a token callback cannot enter any Pool function (test with attacking mocks).
5. A spend with publicAmount == 0 moves no asset and changes no balance.
6. Gas for a spend with the mock verifier is under 900,000 (snapshot), leaving room for 255,000 of verification.
7. The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
