# B14 · Pool: spend and roll

**Kind:** Build · **IMD template:** `impl_tests_review` · **Steps:** `implement-and-test`, `write-foundry-tests`, `adversarial-review`
**Depends on:** B12, B13
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Add the public roll() and spend(proof, inputs, ext) to the Pool. roll wraps B13's roll and also saves rootPrev
= rootCur and rootCur = the current root, emitting CheckpointRolled(window, g, root). The 13 public inputs
are, in order: root, nf0, nf1, nf2, C0, C1, C2, C3, publicAmount, publicAsset, relayFee, gRef, extHash. ext is
(recipient, relayer, ct0, ct1). spend works in the specification's order: roll; root is one of the last 64 or
rootCur or rootPrev; gRef is gCur or gPrev; extHash equals keccak256(abi.encode(chainid, pool, recipient,
relayer, keccak256(ct0), keccak256(ct1))) mod p; every input below p; the zero conventions (publicAsset is
zero exactly when publicAmount is, recipient is zero when nothing leaves, nf2 is zero exactly when relayFee
is); nullifiers unused and distinct; verify; mark nullifiers and insert H4(C0..C3); if anything leaves,
advance the index, then for a public amount require a standard size and enough balance (for the token:
tokenOut + amount <= tokenIn + released), lower the balance and keep amount/500 as the exit fee, and for a
relay fee lower the ETH balance; emit Spent with gRef, relayFee, relayer and both ciphertexts; pay the
recipient and the relayer last. activate calls roll first. Use a mock verifier in tests; real proofs come in
B60. Work only from the pinned commit of the project repository and the build specification
(`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30, Foundry,
optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any contract. Every
duration is in seconds of block.timestamp counted from Params.GENESIS; no schedule may count blocks. If the
specification is ambiguous, stop and report the ambiguity instead of choosing.

## Contracts named

- `src/Pool.sol`

## Paths the job may write

- `src/Pool.sol`
- `src/interfaces/IVerifier.sol`
- `test/PoolSpend.t.sol`
- `test/mocks/MockVerifier.sol`

## Acceptance tests

1. spend reverts on: unknown root, stale gRef, wrong extHash (including a changed relayer), a used nullifier, equal nullifiers, a public input >= p, a non-standard size, and each broken zero convention.
2. A withdrawal pays the recipient exactly amount - amount/500 and adds amount/500 to fees, for every listed size of every asset; the relayer receives exactly relayFee in ETH and shielded ETH falls by it.
3. Total withdrawn per asset never exceeds total activated; for the token tokenOut never exceeds tokenIn + released (invariant test with a verifier that accepts everything).
4. Re-entrancy from an ETH recipient, a relayer or a token callback cannot enter any Pool function (attacking mocks).
5. Root flush: after a roll and 65 further spends, a proof against rootCur is accepted; after the next roll it is accepted as rootPrev; after two rolls it is rejected.
6. Liveness: after any idle time, one roll makes a spend against gCur succeed, and a note activated in a quiet pool is spendable after the next roll.
7. Gas for a relayed spend with the mock verifier is under 900,000 (snapshot), leaving room for 285,000 of verification.
8. The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
