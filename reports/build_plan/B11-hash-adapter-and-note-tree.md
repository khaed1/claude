# B11 · Hash adapter and note tree

**Kind:** Build · **IMD template:** `impl_tests` · **Steps:** `implement-and-test`
**Depends on:** B00
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement Hash.sol, which calls the three poseidon-solidity contracts already on mainnet (addresses and code
hashes in Params) for H2, H3 and H4, and NoteTree.sol: an append-only tree of depth 32 with empty leaf ZERO,
one insert per call, the last 64 roots kept in a ring, and leaf = H4(C0, C1, C2, C3). Tests etch the hasher
bytecode from fixtures. Work only from the pinned commit of the project repository and the build specification
(`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30, Foundry,
optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any contract. Every
duration is in seconds of block.timestamp counted from Params.GENESIS; no schedule may count blocks. If the
specification is ambiguous, stop and report the ambiguity instead of choosing.

## Contracts named

- `src/lib/NoteTree.sol`
- `src/lib/Hash.sol`

## Paths the job may write

- `src/lib/Hash.sol`
- `src/lib/NoteTree.sol`
- `test/NoteTree.t.sol`
- `test/vectors/poseidon.json`

## Acceptance tests

1. H2, H3 and H4 match every vector in test/vectors/poseidon.json (generated from circomlibjs, at least 64 per width, including 0 and p-1).
2. Inputs at or above the field modulus revert.
3. After n inserts the root equals a reference implementation in the test for n in 1..300 and for the fuzzed case.
4. isKnownRoot is true for the last 64 roots and false for the 65th and for zero.
5. An insert costs at most 700,000 gas with warm hashers (gas snapshot test).
6. The constructor reverts if any hasher's code hash differs from Params.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
