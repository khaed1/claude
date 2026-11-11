# B51 · Verifier and verification-key checks

**Kind:** Build · **IMD template:** `impl_tests` · **Steps:** `implement-and-test`
**Depends on:** C06
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Wrap the snarkjs-generated Groth16 verifier for the Spend circuit as Verifier.sol with one view function
verify(proof, inputs[14]). Add script/check_vk.py, which reads a verification key and fails unless: the 15
input points are pairwise different and none is the point at infinity; every point is on its curve and the G2
points are in the right subgroup; alpha, beta, gamma and delta are not the point at infinity; gamma and delta
differ; delta is not the generator. Two production verifiers were exploited in February 2026 because a setup
step was skipped and gamma equalled delta; this check is the guard. Work only from the pinned commit of the
project repository and the build specification (`reports/Murmuration v4 specification.html`, section "Build
specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade
or setter may appear in any contract. Every duration is in seconds of block.timestamp; no schedule may count
blocks. Screening epochs count from Params.GENESIS; caps, emissions and the deposit window count from START,
which the registry records at its first applied batch. If the specification is ambiguous, stop and report the
ambiguity instead of choosing.

## Contracts named

- `src/Verifier.sol`

## Paths the job may write

- `src/Verifier.sol`
- `test/Verifier.t.sol`
- `script/check_vk.py`
- `test/fixtures/proofs/`

## Acceptance tests

1. All valid fixture proofs verify; each fixture with any one of the 14 public inputs or one proof byte altered fails.
2. A public input equal to or above the field modulus is rejected.
3. check_vk.py fails on a key with gamma == delta, a point off the curve, a G2 point outside the subgroup, two equal input points, an input point at infinity, and a wrong input count (six bad fixtures).
4. Verification of 14 inputs costs under 290,000 gas (snapshot).
5. The contract has no storage and no function besides verify.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job. The fixtures come from C06 and use a
development setup, not the ceremony.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
