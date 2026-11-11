# P02 · Proofs: Poseidon at widths 3, 4 and 5

**Kind:** Proof · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** C02, R01
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Prove that the Poseidon circuits of widths 3, 4 and 5 compute the Poseidon function defined in Spec.lean
(soundness and completeness). If the pinned clean commit already contains these proofs, this job only imports
them, re-checks them under the gate and records the commit. The equality of the optimised and the reference
round structure may be taken as tested, not proved, and must then be listed as such. Work only from the pinned
commit of the project repository and the build specification (`reports/Murmuration v4 specification.html`,
section "Build specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin,
pause, upgrade or setter may appear in any contract. Every duration is in seconds of block.timestamp; no
schedule may count blocks. Screening epochs count from Params.GENESIS; caps, emissions and the deposit window
count from START, which the registry records at its first applied batch. If the specification is ambiguous,
stop and report the ambiguity instead of choosing. The gate is not a green build. It is: `lake build --wfail`;
an axiom allow-list on every theorem named below (propext, Classical.choice, Quot.sound and nothing else
unless named here); and `lake comparator` against the frozen Challenge.lean, whose hash must equal
circuit/lean/FROZEN.

## Paths the job may write

- `circuit/lean/Murmuration/Proofs/Poseidon.lean`

## Acceptance tests

1. `make lean-proofs-poseidon` passes with --wfail and no `sorry`.
2. Axiom check passes for the three soundness theorems.
3. The output lists exactly which statements are proved and which are covered by test vectors only.
4. FROZEN hashes are unchanged.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
