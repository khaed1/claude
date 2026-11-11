# C07 · Wallet cryptography library

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** C00
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement the wallet-side primitives in TypeScript exactly as "Keys, notes and addresses" in the build
specification: spendRoot, viewRoot and the X-Wing key from the seed by HKDF-SHA256 with the stated labels; sk
= spendRoot mod p; spk, nk, ownerPk; commitment and nullifier; rho and the diversifier of deposit n; rho and
the diversifier of outputs 1 to 3 from nf0 and the slot; the ciphertext-1 key from nf0 and C1, C2, C3; the
long and short address formats. Ciphertext 0 is HPKE base mode with the X-Wing KEM (0x647A, draft-connolly-
cfrg-xwing-kem-11), HKDF-SHA256 and ChaCha20-Poly1305, info "murmuration/v1/ct0" followed by the chain id and
pool address: 1,120 bytes of encapsulation, the 80-byte payload (asset 1, value 12, accrued 12, rho 31,
diversifier 8, memo 16) and a 16-byte tag. Ciphertext 1 is 96 bytes under the ciphertext-1 key with a zero
nonce: value and accrued of outputs 1 and 2 (12 bytes each), the claim (12), 20 spare bytes and a 16-byte tag.
Empty inputs take fresh random rho, leafIndex and slot. Use audited libraries for X25519, ML-KEM-768, HKDF and
the AEAD; write no primitive by hand. Work only from the pinned commit of the project repository and the build
specification (`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30,
Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any
contract. Every duration is in seconds of block.timestamp; no schedule may count blocks. Screening epochs
count from Params.GENESIS; caps, emissions and the deposit window count from START, which the registry records
at its first applied batch. If the specification is ambiguous, stop and report the ambiguity instead of
choosing.

## Paths the job may write

- `wallet/src/keys.ts`
- `wallet/src/note.ts`
- `wallet/src/derive.ts`
- `wallet/src/encrypt.ts`
- `wallet/src/address.ts`
- `wallet/test/vectors.test.ts`
- `wallet/vectors/xwing.json`
- `wallet/vectors/derive.json`
- `wallet/package.json`

## Acceptance tests

1. X-Wing passes the draft-11 test vectors in wallet/vectors/xwing.json.
2. Commitments and nullifiers match the Lean specification on the shared scenario vectors.
3. Every derivation matches wallet/vectors/derive.json, which a second implementation in another language also reproduces.
4. Encrypt then decrypt round-trips 1,000 random notes; ciphertext 0 is exactly 1,216 bytes and ciphertext 1 exactly 96, with the byte layout of the specification (layout test).
5. Two spends with the same first nullifier and different output amounts use different ciphertext-1 keys.
6. A view-only wallet built from viewRoot, spk and nk decrypts every note and computes every nullifier and cannot produce a spend.
7. Decryption with the wrong key or one flipped bit fails without throwing an unhandled error. A short address resolves to its key only when keccak256(key) matches.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
