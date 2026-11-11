# C02 · Poseidon at widths 3, 4 and 5 in clean

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** C00
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Provide Poseidon circuits for two, three and four inputs with circomlib's constants in clean. If clean's
`poseidon-n-arity` work has been merged at the pinned commit, import it; otherwise port it into this
repository and say so in the output. Check each width against circuit/vectors/poseidon.json, the same vectors
B11 uses for the on-chain hashers. Work only from the pinned commit of the project repository and the build
specification (`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30,
Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any
contract. Every duration is in seconds of block.timestamp counted from Params.GENESIS; no schedule may count
blocks. If the specification is ambiguous, stop and report the ambiguity instead of choosing.

## Paths the job may write

- `circuit/lean/Murmuration/Gadgets/Poseidon.lean`
- `circuit/lean/test/PoseidonVectors.lean`
- `circuit/vectors/poseidon.json`

## Acceptance tests

1. All vectors for widths 3, 4 and 5 pass in `make lean-poseidon`, at least 64 per width including 0 and p-1.
2. The round constants are byte-identical to circomlib's poseidon_constants (hash comparison in the test).
3. The output states which clean commit or branch each width comes from and whether its soundness proof exists there.
4. Constraint count per width is written to circuit/COUNTS.md.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run. On 10 Nov 2026 only width 2 was proved on clean's main branch; widths 3 to 5 were on an unmerged branch.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
