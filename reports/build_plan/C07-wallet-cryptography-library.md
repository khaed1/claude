# C07 · Wallet cryptography library

**Kind:** Build · **IMD template:** `single` · **Steps:** `scaffold-project`
**Depends on:** C00
**Status:** draft. Not submitted. One request, 0.5 IMD.

## Objective

Implement the wallet-side primitives in TypeScript: key derivation (spk, nk, ownerPk with diversifier), note
commitment and nullifier, the long and short address formats, and the deterministic derivations that let a
wallet be rebuilt from its seed: rho and the diversifier of a deposit from a keyed hash of the seed and a per-
wallet deposit counter, and rho for outputs 1, 2 and 3 of a spend from a keyed hash of the seed, the spend's
first nullifier and the slot. Ciphertext 0 is HPKE base mode with the X-Wing KEM (HPKE id 0x647A, draft-
connolly-cfrg-xwing-kem-11), HKDF-SHA256 and ChaCha20-Poly1305: 1,120 bytes of encapsulation, an 80-byte
payload (asset 1, value 12, accrued 12, rho 31, diversifier 8, memo 16) and a 16-byte tag, 1,216 bytes in all.
Ciphertext 1 is 96 bytes sealed with a key from the seed and the first nullifier: value and accrued of outputs
1 and 2 (12 bytes each), the claim (12), 20 spare bytes and a 16-byte tag. Use audited libraries for X25519,
ML-KEM-768 and the AEAD; write no primitive by hand. Work only from the pinned commit of the project
repository and the build specification (`reports/Murmuration v4 specification.html`, section "Build
specification"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. No owner, admin, pause, upgrade
or setter may appear in any contract. Every duration is in seconds of block.timestamp counted from
Params.GENESIS; no schedule may count blocks. If the specification is ambiguous, stop and report the ambiguity
instead of choosing.

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
3. Encrypt then decrypt round-trips 1,000 random notes; ciphertext 0 is exactly 1,216 bytes and ciphertext 1 exactly 96, with the byte layout of the objective (layout test).
4. The derivations match wallet/vectors/derive.json, and a deposit's rho and diversifier are recomputed from the seed and the counter alone.
5. Decryption with the wrong key or one flipped bit fails without throwing an unhandled error.
6. A short address resolves to its key only when keccak256(key) matches.

## Notes

IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code.
Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can
run.

## Inputs

`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs this one depends on. Resolve the commit with IMD's free import check before quoting.
