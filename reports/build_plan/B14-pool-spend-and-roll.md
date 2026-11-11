# B14 · Pool: spend and roll

**Kind:** Build · **IMD template:** `impl_tests_review` · **Steps:** `implement-and-test`, `write-foundry-tests`, `adversarial-review`
**Depends on:** B12, B13
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Add the public roll() and spend(proof, inputs, ext) to the Pool. roll wraps B13's roll and also saves rootPrev
= rootCur and rootCur = the current root, emitting CheckpointRolled(window, g, root). The 14 public inputs
are, in order: root, nf0, nf1, nf2, C0, C1, C2, C3, publicAmount, publicAsset, relayFee, feeAsset, gRef,
extHash. ext is (recipient, relayer, ct0, ct1). spend works in the specification's order and checks every row
of its public-input table: the root; nf0 and nf1 non-zero, unused and different; nf2 zero exactly when
feeAsset is zero, otherwise unused and different from both, and zero never looked up or marked; publicAsset
zero exactly when publicAmount is; relayFee zero exactly when feeAsset is, and at most feeCeiling(feeAsset);
gRef equal to gCur or gPrev; extHash recomputed; recipient zero exactly when publicAmount is; relayer zero
exactly when relayFee is; ct0 1,216 bytes and ct1 96; every input below p. Then verify, mark, insert
H4(C0..C3), advance the index if anything leaves, lower the balance of each asset that leaves (token rule:
tokenOut + amount <= tokenIn + released), keep one five-hundredth of each amount as fees, emit Spent, and pay
the relayer and then the recipient. feeCeiling in ETH is (FEE_K * block.basefee + FEE_TIP) * FEE_GAS; in
another asset it is that times FEE_SLACK at the frozen units-per-ETH rate. ETH is paid by call with
Params.PAY_GAS; a failed payment is credited to owed[address]. Use a mock verifier in tests; real proofs come
in B60. Work only from the pinned commit of the project repository and the build specification
(`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30, Foundry,
optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any contract. Every
duration is in seconds of block.timestamp; no schedule may count blocks. Screening epochs count from
Params.GENESIS; caps, emissions and the deposit window count from START, which the registry records at its
first applied batch. If the specification is ambiguous, stop and report the ambiguity instead of choosing.

## Contracts named

- `src/Pool.sol`

## Paths the job may write

- `src/Pool.sol`
- `src/interfaces/IVerifier.sol`
- `test/PoolSpend.t.sol`
- `test/mocks/MockVerifier.sol`

## Acceptance tests

1. spend reverts on each broken row of the public-input table, one test per row, including nf2 equal to nf0, nf2 zero with a fee, a non-zero relayer with no fee, and a ciphertext of the wrong length.
2. A withdrawal pays the recipient exactly amount - amount/500 for every listed size of every asset. The relayer receives relayFee - relayFee/500 in feeAsset, for ETH and for each token.
3. A relay fee above feeCeiling(feeAsset) reverts at any base fee (fuzz), so no sequence of spends moves more through the fee than the ceiling per spend.
4. Total leaving per asset, public amounts and relay fees together, never exceeds total activated; for the token tokenOut never exceeds tokenIn + released (invariant test with a verifier that accepts everything).
5. An ETH recipient or relayer that reverts, or uses more than the gas allowance, does not make spend fail: the amount is in owed and claimOwed delivers it. Re-entrancy from either cannot enter any Pool function.
6. Root flush: after a roll and 65 further spends, a proof against rootCur is accepted; after the next roll it is accepted as rootPrev; after two rolls it is rejected.
7. Gas for a relayed spend with the mock verifier is under 900,000 (snapshot), leaving room for 290,000 of verification.
8. The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed.

## Notes

IMD's verifier runs forge build, forge test and Slither on this job.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
