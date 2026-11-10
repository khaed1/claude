# C06 · Proof fixtures and development setup

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** C04
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Produce a development Groth16 setup for spend.r1cs with snarkjs from a public powers-of-tau file pinned by
hash, clearly marked as not the ceremony, including the final beacon step. Generate the Solidity verifier and
proof fixtures for the scenarios in circuit/vectors/scenarios.json and for the end-to-end scenario of B60.
prove.mjs is a command-line prover that takes a JSON input and writes proof and public inputs. Work only from
the pinned commit of the project repository and the build specification (`reports/Murmuration v4
specification.html`, section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no
network. No owner, admin, pause, upgrade or setter may appear in any contract. If the specification is
ambiguous, stop and report the ambiguity instead of choosing.

## Paths the job may write

- `circuit/setup/dev_setup.sh`
- `circuit/build/dev/verification_key.json`
- `circuit/build/dev/Groth16Verifier.sol`
- `test/fixtures/proofs/`
- `test/fixtures/e2e/`
- `circuit/prover/prove.mjs`

## Acceptance tests

1. `snarkjs zkey verify` passes for the development key against spend.r1cs and the pinned powers-of-tau file.
2. script/check_vk.py from B51 passes on the development verification key.
3. Every fixture proof verifies with snarkjs and with the generated Solidity verifier.
4. The setup script is deterministic given its recorded entropy and beacon, and prints the hashes of every output.
5. Proving time and peak memory for one proof on the job's machine are recorded in circuit/COUNTS.md.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
