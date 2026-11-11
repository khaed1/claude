# L02 · Ceremony tooling

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** C04, P04
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Write the scripts for a public phase-2 ceremony for spend.r1cs with snarkjs: start from a powers-of-tau file
pinned by hash, accept contributions one after another through pull requests that add one file and one
attestation, apply a public random beacon at the end, and verify the whole chain. Anyone can run verify.sh.
The scripts must refuse a transcript without the final beacon step. Work only from the pinned commit of the
project repository and the build specification (`reports/Murmuration v4 specification.html`, section "Build
specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade
or setter may appear in any contract. Every duration is in seconds of block.timestamp; no schedule may count
blocks. Screening epochs count from Params.GENESIS; caps, emissions and the deposit window count from START,
which the registry records at its first applied batch. If the specification is ambiguous, stop and report the
ambiguity instead of choosing.

## Paths the job may write

- `ceremony/contribute.sh`
- `ceremony/verify.sh`
- `ceremony/README.md`
- `ceremony/transcript/`

## Acceptance tests

1. A rehearsal with five simulated contributors produces a final key that passes `snarkjs zkey verify` and check_vk.py.
2. verify.sh fails on a transcript with a missing contribution, a reordered one, or no beacon.
3. The r1cs hash checked by verify.sh equals the hash recorded by P04.
4. ceremony/README.md says how a contributor checks that their contribution is included.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run. Who coordinates the real ceremony is an open question; the team operates nothing.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
