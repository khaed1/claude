# C07 · Wallet cryptography library

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** C00
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement the wallet-side primitives in TypeScript: key derivation (spk, nk, ownerPk with diversifier), note
commitment and nullifier, the long and short address formats, HPKE base mode with the X-Wing KEM (HPKE id
0x647A, draft-connolly-cfrg-xwing-kem-11), HKDF-SHA256 and ChaCha20-Poly1305 for output 0 (1,216 bytes), and
the 96-byte self-encrypted change payload. Use audited libraries for X25519, ML-KEM-768 and the AEAD; write no
primitive by hand. Work only from the pinned commit of the project repository and the build specification
(`reports/Murmuration v4 specification.html`, section "Build specification"). Solidity 0.8.30, Foundry,
optimizer on, no ffi, no network. No owner, admin, pause, upgrade or setter may appear in any contract. If the
specification is ambiguous, stop and report the ambiguity instead of choosing.

## Paths the job may write

- `wallet/src/keys.ts`
- `wallet/src/note.ts`
- `wallet/src/encrypt.ts`
- `wallet/src/address.ts`
- `wallet/test/vectors.test.ts`
- `wallet/vectors/xwing.json`
- `wallet/package.json`

## Acceptance tests

1. X-Wing passes the draft-11 test vectors in wallet/vectors/xwing.json.
2. Commitments and nullifiers match the Lean specification on the shared scenario vectors.
3. Encrypt then decrypt round-trips 1,000 random notes; a ciphertext is exactly 1,216 bytes and a change payload exactly 96.
4. Decryption with the wrong key or one flipped bit fails without throwing an unhandled error.
5. A short address resolves to its key only when keccak256(key) matches.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
