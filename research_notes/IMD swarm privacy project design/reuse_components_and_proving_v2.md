# Murmuration: reusable audited components and whether collaborative proving is needed (v2)

Research dates: 9–10 November 2026. Read-only work: no transactions, posts or commits. Sources marked (9 Nov) or (10 Nov) by fetch date. "Measured here" means a measurement made in this session; the method is given next to it. Items that could not be confirmed are marked NOT VERIFIED and collected at the end.

Inputs read first: `cost_inputs.md` (all), and the TACEO / proving / mobile parts of `imd_and_swarm_tech.md` and `privacy_problems.md`. Both earlier notes list "no benchmark of coSNARK proving for Railgun/Privacy-Pools-sized circuits" and "no 2026 mobile proving figures for Railgun, Privacy Pools or Aztec" as gaps; Part 1 closes most of that.

---

## Part 1. Is delegated / collaborative proving needed?

### Verdict

No. Every circuit Railgun and Privacy Pools v1 ask a user to prove is a Groth16/circom circuit of 10k–76k R1CS constraints, and Railgun's own mobile wallet already proves all of them natively on the phone. Published phone benchmarks put Groth16 circuits twice that size at under 1 s on 2023–24 flagships and 1–3 s on mid-range and budget Android. TACEO's 3-party coGroth16 is real and fast (about 0.5 s for 2^16 constraints by its own figures), but it is semi-honest, permissioned, unaudited and partly GPL-3.0, and it would add an audit surface to solve a problem these pools do not have.

### 1a–1b. Circuit sizes (measured here)

Method: circuit sources fetched from the repos below, compiled with circom 2.2.2 (npm `circom2@0.2.22`), circomlib 2.0.5, `--O2`. Railgun's repo pins circom 2.0.6, so counts may differ by a few constraints.

| Pool | Circuit | Parameters | Non-linear constraints | Public signals |
|---|---|---|---|---|
| Railgun V2 | JoinSplit 1x1 | depth-16 Poseidon tree, EdDSA-Poseidon | 9,759 | 4 |
| Railgun V2 | JoinSplit 1x2 | | 10,164 | 5 |
| Railgun V2 | JoinSplit 2x2 | | 14,810 | 6 |
| Railgun V2 | JoinSplit 2x3 | | 15,218 | 7 |
| Railgun V2 | JoinSplit 3x3 | | 19,852 | 8 |
| Railgun V2 | JoinSplit 8x2 | | 42,638 | 12 |
| Railgun V2 | JoinSplit 7x7 | | 40,035 | 16 |
| Railgun V2 | JoinSplit 10x4 | | 52,731 | 16 |
| Railgun V2 | JoinSplit 13x1 (largest variant) | | 65,427 | 16 |
| Railgun PPOI | POI 3x3 | depth 16, max 13 in / 13 out | 21,914 | 5 in + 3 out |
| Railgun PPOI | POI 13x13 | | 76,074 | 15 in + 13 out |
| Privacy Pools v1 | Withdraw(32) | two depth-32 LeanIMT proofs (state + ASP) | 17,442 at `--O2`; 17,654 non-linear + 19,178 linear at `--O1` (36,901 wires) | 6 in + 2 out |
| Privacy Pools v1 | Commitment (ragequit) | | 714 | 2 in + 2 out |

- Railgun's generator emits every nullifiers x commitments pair with nullifiers + commitments <= 14, which is 91 variants; the repo's test vectors contain 91 entries. Cost is about 4.6k constraints per input and 0.4k per output, so 13x1 is the ceiling. Sources (9 Nov): https://raw.githubusercontent.com/Railgun-Privacy/circuits-v2/main/lib/circuitConfigs.js , https://raw.githubusercontent.com/Railgun-Privacy/circuits-v2/main/src/library/joinsplit.circom , https://raw.githubusercontent.com/Railgun-Privacy/circuits-v2/main/scripts/generate_circuits
- PPOI ships exactly two shapes, 3x3 and 13x13; the repo now builds a `circom-witnesscalc` v0.3.0 witness graph next to WASM and C++, and uses the Hermez 2^20 ptau. Sources (9 Nov): https://raw.githubusercontent.com/Railgun-Privacy/circuits-ppoi/main/lib/config.ts , https://raw.githubusercontent.com/Railgun-Privacy/circuits-ppoi/main/src/library/poi-transaction.circom , https://raw.githubusercontent.com/Railgun-Privacy/circuits-ppoi/main/README.md
- Both Railgun circuit repos carry "No License is provided for any party under any circumstances" (`License.md`), which matters for forking, not for serving the pool.
- Privacy Pools v1: Groth16, bn128, circomkit, snarkjs 0.7.5, `Withdraw` instantiated with depth 32, setup on a 2^16 ptau; Apache-2.0. The 36,901 wire count matches the "36901 signals" in the Nethereum docs. Sources (9 Nov): https://raw.githubusercontent.com/0xbow-io/privacy-pools-core/main/packages/circuits/circuits/withdraw.circom , https://raw.githubusercontent.com/0xbow-io/privacy-pools-core/main/packages/circuits/src/index.ts , https://raw.githubusercontent.com/0xbow-io/privacy-pools-core/main/packages/circuits/package.json , https://docs.nethereum.com/docs/protocols/nethereum-privacypools-circuits (via search)
- Privacy Pools v2: L2BEAT lists Groth16 verifiers `DepositVerifier`, `RagequitVerifier` and `Transact1x1` … `Transact5x5` (25 join-split shapes), and flags "Beta verifiers used single-contributor keys". The v2 web app is Expo / React Native Web with browser "proving workers" and same-origin Groth16 artifacts. Circuit source was not located, so the constraint count is NOT VERIFIED; by analogy with v1 (about 17k per input because of two depth-32 proofs) a 5x5 would be on the order of 90k–100k, an estimate only. Sources (10 Nov): https://l2beat.com/privacy/projects/privacy-pools-v2 , https://raw.githubusercontent.com/0xbow-io/privacy-pools-v2/main/README.md

Everything measured is below 2^17 = 131,072 constraints.

### 1a. How Railgun proves on phones

- Railgun docs: "There is a distinct Groth16 prover for node/browser (snarkjs) and a different prover for mobile (native prover)"; "Mobile apps use a C++ implementation". (9 Nov) https://docs.railgun.org/developer-guide/wallet/getting-started/3.-load-a-groth16-prover-for-each-platform
- The engine exposes `setNativeProverGroth16(nativeProveRailgun, nativeProvePOI, circuits)`; the native path takes the circuit id, the `.dat` artifact and the zkey, for both join-split and POI circuits. (9 Nov) https://raw.githubusercontent.com/Railgun-Community/engine/main/src/prover/prover.ts
- Railway Wallet mobile (React Native + nodejs-mobile) depends on `@railgun-privacy/native-prover` 4.0.3, a node-gyp C++ addon distributed as an IPFS tarball, and calls `getProver().setNativeProverGroth16(nativeProveRailgun, nativeProvePOI, CIRCUITS)` with `useNativeArtifacts = true`. (9 Nov) https://raw.githubusercontent.com/Railway-Wallet/Railway-Wallet/main/mobile/nodejs-src/nodejs-project/package.json , https://raw.githubusercontent.com/Railway-Wallet/Railway-Wallet/main/mobile/nodejs-src/nodejs-project/src/services/core/railgun/node-railgun-engine.ts
- Not found: any published Railgun or Railway proving-time figure for phones or browsers, and the internals of the native prover (whether it wraps rapidsnark). NOT VERIFIED.

PPOI cost per transaction: each POI proof is one more Groth16 proof of 21.9k (3x3) or 76.1k (13x13) constraints, generated per Railgun txid and per POI list. Proof size is the usual Groth16 3 group elements (about 1 KB as JSON per the EF report below). It is extra latency, not a capability problem.

### Desktop reference (measured here)

snarkjs 0.7.5 `groth16.fullProve` (WASM witness + WASM prover, the same path a browser uses) under Node 22 on a 4-vCPU Intel Xeon 2.1 GHz cloud VM, with a locally generated development ptau/zkey (not the production keys), inputs from the repos' own test vectors, best of three runs in a fresh process:

| Circuit | Constraints | fullProve time | Peak RSS (whole Node process) | zkey size |
|---|---|---|---|---|
| Railgun 2x3 | 15,218 | 1.25 s | 351 MB | 9.2 MB |
| Railgun POI 3x3 | 21,914 | 1.9 s | 375 MB | 14.2 MB |
| Railgun 13x1 | 65,427 | 4.3 s | 585 MB | 37.6 MB |
| Railgun POI 13x13 | 76,074 | 5.9 s | 615 MB | 47.9 MB |

This is the slow path. Native provers are 7–15x faster than snarkjs on the same device (next section).

### 1c. Phone benchmarks for Groth16 / circom

| Source | Device | Circuit (approx. constraints) | Prover | Witness | Proof |
|---|---|---|---|---|---|
| mopro docs v0.3 | iPhone 16 Pro (2024) | Keccak256 (~150k) | witnesscalc / circom-witnesscalc + rapidsnark | 142 ms / 75 ms | 630 ms |
| mopro | iPhone 16 Pro | SHA256 | rapidsnark | 41–51 ms | 187 ms |
| mopro | iPhone 16 Pro | Semaphore-32 | rapidsnark | 15–22 ms | 143 ms |
| mopro | iPhone 16 Pro | Keccak256 | snarkjs | 147 ms | 5,182 ms |
| mopro | Samsung S23 Ultra (2023) | Keccak256 (~150k) | rapidsnark | 71–101 ms | 744 ms |
| mopro | Samsung S23 Ultra | SHA256 | rapidsnark | 29–44 ms | 228 ms |
| mopro | Samsung S23 Ultra | Semaphore-32 | rapidsnark | 10–15 ms | 166 ms |
| mopro | Samsung S23 Ultra | Keccak256 | snarkjs | 292 ms | 11,096 ms |
| mopro (browser) | iPhone 16 Pro / S23 Ultra | Keccak256 | arkworks + rayon in WASM | – | 1,718 ms / 2,733 ms |
| Deimos (BlocSoc IIT Roorkee, via MoPro, circom) | iPhone 13 | SHA-256 (~30k) | mopro circom | – | 0.76 s |
| Deimos | AC2001, MediaTek Helio, "mid-range" | SHA-256 (~30k) | mopro circom | – | 0.86 s |
| Deimos | RMX3710 | SHA-256 (~30k) | mopro circom | – | 1.56 s |
| Deimos | A059, "budget" | SHA-256 (~30k) / Keccak-256 (~150k) | mopro circom | – | 1.91 s / 2.90 s |
| TACEO (23 Jul 2025) | Samsung Galaxy S23+ | chacha20 2^15 / sha256 2^16 / keccak256 2^18 / merkle_tree_10_t3 2^18 | local prover not named | – | 0.99 s / 1.69 s / 8.0 s / 15.4 s |

- mopro: "Both native witness generation and proof generation are generally faster than snarkjs in the browser, with potential speed improvements of up to 20 times." The 150k figure for Keccak256 is from mopro's own v0.0.1 page ("Keccak256 (150k constraints): 1.5s" on an iPhone 14 Pro Max, arkworks era). (9 Nov) https://zkmopro.org/docs/performance , https://zkmopro.org/docs/0.0.1/performance
- mopro memory limit: iPhone 15 Pro and Pixel 6 Pro crash on a halo2 RSA circuit needing about 5 GB because the app is usually limited to about 3 GB. Same page.
- Deimos tables, including tier labels, are from an undated HackMD write-up. (10 Nov) https://hackmd.io/76ek6xStTxKwF6NS5BaDng
- EF client-side-proving team, Q1'26 report, on an AWS mac2.metal (Apple M1, 8 cores, 16 GB): Circom Groth16 needs 23.5 MB RAM for Poseidon; proofs about 1 KB; preprocessing (zkey) "1.25 GB for Keccak, 592 MB for SHA-256, 21.3 MB even for Poseidon" at the suite's largest inputs. Baseline phones: Android 3.82 GB RAM, iPhone 5.7 GB. "GPU-accelerated mobile proving is still early (Metal MSM v2, ICICLE-Metal)". (9 Nov) https://hackmd.io/@clientsideproving/report-q1 , https://hackmd.io/@clientsideproving/ByqafXAv1e
- Same benchmark suite, Circom SHA-256 rows: 159K constraints, 636 ms, 238 MB; 541K, 2.3 s, 616 MB; 1.1M, 4.8 s, 1.26 GB. (10 Nov) https://hackmd.io/@QmCYMVNVQuqRJhiqMlXVdA/Sya1ewPA-e (table credited to https://ethproofs.org/csp-benchmarks)
- A mopro issue reports rapidsnark at about 4.5 s for a 443,351-constraint circuit on an iPhone 15 Plus (search snippet only, NOT VERIFIED at source). https://github.com/zkmopro/mopro/issues/44

Other systems asked about:

- Aztec "Tierra" (Alpha V6), announced 3 Nov 2026: "'1 second' client side proofs on a native device, a 2x speedup compared to the previous network". No device, memory or browser figure is given. Bankless reports the comparison as about 2.5 s for a token transfer on V5. This is a different proving stack (not Groth16) and is context only. (9 Nov) https://aztec.network/blog/introducing-aztec-tierra , https://www.bankless.com/read/news/aztec-ships-tierra-upgrade-closing-the-v5-proving-hole
- Zcash: the "~200 ms" figure is from Zakura's own benchmarks for Zakura Common, released 29 Aug 2026 (MIT/Apache-2.0). Transaction construction "from more than three seconds to below 200 milliseconds" under some test conditions; mobile proof generation "more than fourteenfold" faster. The Blockworks/Messari Q3 2026 report says "on an iPhone" without a model. Ironwood (activated 28 Jul 2026) reuses the Orchard circuit and Halo 2. Vendor figures, not independently reproduced. (10 Nov) https://crypto.news/zcash-private-transactions-could-fall-below-200ms/ ; (9 Nov, search) https://app.blockworks.com/report/zcash-token-holder-report-q3-2026 , https://www.theblock.co/news/ecosystems/2026-07-28-zcash-ironwood-upgrade-launching-new-shielded-pool-after-orchard-vulnerability-409934

### 1d. Numbers for a Groth16 circuit under ~200k constraints

| Quantity | Value | Basis |
|---|---|---|
| Native proof time, 2023–24 flagship | 0.15–0.75 s plus 10–150 ms witness | mopro, rapidsnark, 9k–150k constraints |
| Native proof time, mid-range / budget Android | about 0.9–3 s | Deimos, 30k–150k constraints |
| Browser / WASM on a phone | about 1.7–11 s at 150k | mopro (arkworks-rayon vs snarkjs) |
| Peak RAM, native Groth16 | about 240 MB at 159k constraints, so roughly 100–300 MB below 200k | EF suite on Apple M1 (not a phone) |
| Peak RAM, snarkjs WASM | 350–615 MB for 15k–76k | measured here, Node on x86 |
| zkey download | 9–48 MB for 15k–76k | measured here, development keys |
| Phone budget | app limit about 3 GB; baseline RAM 3.82 GB Android / 5.7 GB iPhone | mopro; EF baseline report |

Is there any Railgun or Privacy Pools circuit a phone cannot prove today? None found. The largest is Railgun POI 13x13 at 76,074 constraints, half of the Keccak256 benchmark circuit that a budget Android phone proved in 2.9 s, and Railway's mobile app already runs it natively. Privacy Pools v2 is the one open point because its circuit source was not located; it is Groth16 with at most 5 inputs and 5 outputs.

The peak-RAM figure for a phone itself is an inference from an M1 measurement plus this session's snarkjs runs; no source measured Groth16 memory on a mid-range phone.

### 1e. TACEO on 10 Nov 2026

| Question | Finding | Source |
|---|---|---|
| Hosted network or software? | Both. TACEO:Proof is "an MPC + coSNARK network that enables developers to offload Groth16 proof generation"; a job runs on 3 distinct node operators chosen per job. The underlying coCircom / coNoir code is open source and can be run by anyone. | (9 Nov) https://docs.taceo.io/docs/services/taceo-proof/overview/ , https://raw.githubusercontent.com/TaceoLabs/co-snarks/main/README.md |
| Who runs nodes? | "We operate a permissioned network with a vetted set of node operators." The TACEO Network launched publicly on 19 Mar 2026 with Nethermind, P2P.org, InfStones, Stakecraft, Moonli, H2O Nodes, ZKPassport, CTU Prague and TU Graz. A "bring your own" model lets a customer nominate its own operators. | (9 Nov) https://docs.taceo.io/docs/services/taceo-proof/ops/onboarding/ , https://core.taceo.io/articles/taceo-network , https://docs.taceo.io/docs/taceo-network/node-operators/ |
| Security model | REP3 or 3-party Shamir. "Both protocols are semi-honest secure under the honest majority assumption." TACEO cites a 2025 paper for promotion to active security; the REP3 share-compression option forfeits that. | (9 Nov) https://docs.taceo.io/docs/services/taceo-proof/dev/bestpractice/ |
| Licence | `Apache-2.0 OR MIT` for the repo; `co-circom` and `circom-mpc-compiler` are GPL-3.0-only. | co-snarks README |
| Audit status | "This software is **experimental** and **un-audited**". | co-snarks README |
| Latency | "typical proofs (2^16 constraints) … take ≈ 500 ms"; node requirement "a circuit of size 2^16 in under one second". End to end from a client: 0.43 s (2^15), 0.67 s (2^16), 1.8–2.2 s (2^18), REP3, cached job data. Upload for a 2^16 witness is about 1 MiB (REP3) or 3 MiB (Shamir). Witness extension inside MPC is the expensive part; proving itself has constant communication. | docs overview and best-practice pages; (9 Nov) https://core.taceo.io/articles/taceo-proof-prod |
| Overhead vs local | TACEO's own table has the network beating a Galaxy S23+ (0.67 s vs 1.69 s at 2^16), but the phone's prover is not named. mopro shows rapidsnark at 0.23 s for SHA256 on an S23 Ultra, so against a native prover the network is not faster at this size. | comparison of the two sources |
| Token / pricing | "No chain, no token … operators are compensated directly by TACEO." Access by voucher. No price list found. | node-operators page |
| Other services | TACEO:OPRF (used by World ID), OMap, Match, and Merces private accounts (Monad and World Chain mainnet with volume caps). | (9 Nov) https://docs.taceo.io/docs/start-here/deployments-and-status/ |

Consequence for Murmuration: running coGroth16 among seat holders would mean operating unaudited MPC software with a GPL-3.0 component under a semi-honest assumption, for circuits that phones already prove in about a second. Dropping it removes a novel audit item. If a future pool has circuits too large for phones, TACEO:Proof can be called as an external service without Murmuration writing any proving code.

---

## Part 2. Audited building blocks

Mainnet facts below were checked by read-only JSON-RPC (`eth_getCode`, `eth_call`, `eth_getStorageAt`, `eth_simulateV1` with state overrides) against https://ethereum-rpc.publicnode.com at about block 26,380,000 (9 Nov 2026), and source verification by the Sourcify API (`https://sourcify.dev/server/v2/contract/1/<address>`).

### Summary table

| Component | Version / mainnet address | Audit | Licence | What it does for us unmodified |
|---|---|---|---|---|
| Safe | v1.4.1: Safe `0x41675C099F32341bf84BFc5382aF534df5C7461a`, SafeL2 `0x29fcB43b46531BcA003ddC8FCB67FFE91900C762`, ProxyFactory `0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67`, CompatibilityFallbackHandler `0xfd0732Dc9E303f09fCEf3a7388Ad10A83459Ec99`, MultiSend `0x38869bf66a61cF6bDB996A6aE40D5853Fd43B526`, MultiSendCallOnly `0x9641d764fc13c8B624c04430C7356C1C7C8102e2`, SignMessageLib `0xd53cd0aB83D845Ac265BE939c57F53AD838012c9`. v1.5.0: Safe `0xFf51A5898e281Db6DfC7855790607438dF2ca44b`, SafeL2 `0xEdd160fEBBD92E350D4D398fb636302fccd67C7e`, ProxyFactory `0x14F2982D601c9458F93bd70B218933A6f8165e7b`, CompatibilityFallbackHandler `0x3EfCBb83A4A7AfcB4F68D501E2c2203a38be77f4`, MultiSend `0x218543288004CD07832472D464648173c77D7eB7` | 1.4.0/1.4.1: Ackee Blockchain. 1.5.0: Certora and Ackee; Certora specs in repo | LGPL-3.0 | A t-of-n ERC-1271 signer for panel statements, treasury, group admin, attester |
| Zodiac Roles v2 | `0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5` (deployed 12 Jun 2026); older v2.1 mastercopy `0x9646fDAD06d3e24444381f44362a3B0eB343D337` (1 Dec 2023) | G0 Group (Apr and Nov 2023), Omniscia (May and Nov 2023) | LGPL-3.0 | Scoped permissions for many member addresses acting through a Safe |
| Semaphore v4 | Semaphore `0xC10E5102A2Cc077BE3B9740Fc0Ad7e27Ff8E0245` (16 Oct 2026), Verifier `0x4DeC9E3784EcC1eE002001BfE91deEf4A48931f8`, PoseidonT3 `0xB43122Ecb241DD50062641f089876679fd06599a`; npm 4.14.5 | PSE internal audit, March 2024, of v4.0.0-beta.1 | MIT | Anonymous one-signal-per-scope membership proofs for an operator group |
| CREATE2 factory | Arachnid `0x4e59b44847b379578588920cA78FbF26c0B4956C`; Safe Singleton Factory `0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7`; CreateX `0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed` | not applicable (69-byte factories); CreateX source verified | – | Same-address deployment of anything we do write |
| ERC-8004 registries | IdentityRegistry `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`, ReputationRegistry `0x8004BAa17C55a88189AE136b182e5fdA19dE9b63`, both v2.0.0 | none found | MIT (SPDX) / CC0 (README) | Operator identity, endpoint, role and key publication; open feedback |
| EAS | EAS `0xA1207F3BBa224E2c9c3c6D5aF63D0eb1582Ce587`, SchemaRegistry `0xA7b39296258348C78294F95B872b282326A97BDF`, both v0.26 | none found | MIT | Timestamped, revocable, indexed publication of roots |
| Waku RLN | no mainnet or Linea mainnet deployment found | – | MIT | nothing new relative to `cost_inputs.md` |
| Restaking slashing | – | – | – | not usable off the shelf |

### 2f. Safe as a pure ERC-1271 t-of-n signer

Answer: yes, with no new contract. Verified by simulation: a Safe proxy pointing at the mainnet v1.4.1 (and v1.5.0) singleton with the matching CompatibilityFallbackHandler returns the ERC-1271 magic value `0x1626ba7e` from `isValidSignature(bytes32 hash, bytes signatures)` when `signatures` is the concatenation of threshold-many 65-byte owner signatures.

Method: `eth_call` / `eth_simulateV1` with a state override that places the factory's proxy runtime code at an unused address and sets the singleton slot, owner linked list, owner count, threshold (= n) and fallback-handler slot; owner keys generated locally. Nothing was broadcast.

| n signatures (threshold = n) | v1.4.1 `isValidSignature` execution gas | v1.4.1 as a whole transaction | v1.5.0 execution gas | v1.5.0 as a whole transaction | v1.4.1 `execTransaction` no-op, whole transaction |
|---|---|---|---|---|---|
| 1 | 26,723 | 49,743 | 22,414 | 45,434 | 68,840 |
| 3 | 39,241 | 64,333 | 34,517 | 59,609 | 82,972 |
| 5 | 51,759 | 78,923 | 46,620 | 73,784 | 97,106 |
| 7 | 64,279 | 93,503 | 58,724 | 87,948 | 111,228 |
| 10 | 83,062 | 115,394 | 76,881 | 109,213 | 132,429 |
| 20 | 145,679 | 188,359 | 137,409 | 180,089 | 203,088 |

- "Execution gas" excludes the 21,000 base and calldata. A contract that calls the Safe pays about 2,600 more for the cold account unless it is in an access list.
- Per extra signer: about 6,260 execution gas on v1.4.1 (6,050 on v1.5.0) plus about 1,036 calldata gas for the 65 bytes. `execTransaction` grows by about 7,066 gas per signer in total.
- Seven signatures: 64,279 gas to verify inside another contract's call on v1.4.1, or 93,503 as a standalone transaction.

Gotchas, from the v1.4.1 handler source (9 Nov, https://raw.githubusercontent.com/safe-global/safe-smart-account/v1.4.1/contracts/handler/CompatibilityFallbackHandler.sol):

1. Owners do not sign the raw hash. The handler wraps it: `SafeMessage(bytes message)` with `message = abi.encode(hash)`, hashed under the Safe's EIP-712 domain (chain id and Safe address). Signers must sign that typed data.
2. Signatures must be ordered by ascending owner address, 65 bytes each; exactly `threshold` are checked.
3. Validity follows the Safe's current owners and threshold. Removing or rotating an owner invalidates old signature sets that used that owner; lowering the threshold makes smaller sets valid. There is no nonce, expiry or revocation, so the signed statement must carry its own epoch and expiry.
4. The Safe's fallback handler must be the CompatibilityFallbackHandler. Check each Safe.
5. The domain separator binds chain id and Safe address, so signatures do not replay across chains.
6. An empty signature takes the other path: the message hash must have been approved on-chain through `SignMessageLib` (a Safe transaction).
7. v1.5.0 removed the legacy `isValidSignature(bytes,bytes)` from the handler. The unreleased branch tightens contract-signature handling further (strict 32-byte return check, new `GS024`/`GS025` errors). (9 Nov) https://raw.githubusercontent.com/safe-global/safe-smart-account/main/CHANGELOG.md
8. No owner-count cap was found; cost is linear. (Owner-manager source not re-read this session.)

Addresses and verification: all addresses above are in `safe-deployments` as canonical for chain 1 and have code on mainnet; Sourcify reports exact matches. v1.4.1 Safe was deployed 15 Jun 2023; v1.5.0 Safe 3 Jul 2025. Solidity 0.7.6. (9 Nov) https://raw.githubusercontent.com/safe-global/safe-deployments/main/src/assets/v1.4.1/safe.json , https://raw.githubusercontent.com/safe-global/safe-deployments/main/src/assets/v1.5.0/safe.json

Audits: v1.4.0/1.4.1 by Ackee Blockchain on commit `eb93dbb0`, with one later ERC-4337 opcode fix not re-audited; v1.5.0 by Certora (commit `1c8b24a0`) and Ackee (commit `5d265053`). Report PDFs: `docs/Safe_Audit_Report_1_4_0.pdf`, `docs/Safe_Audit_Report_1_5_0_Certora.pdf`, `docs/Safe_Audit_Report_1_5_0_Ackee.pdf` in the repo. Report dates were not extracted. (9 Nov) https://raw.githubusercontent.com/safe-global/safe-smart-account/main/docs/audit_1_4_0.md , https://raw.githubusercontent.com/safe-global/safe-smart-account/main/docs/audit_1_5_0.md

### 2g. Zodiac Roles Modifier v2

- The repository layout changed: `gnosisguild/zodiac-modifier-roles` main now hosts Roles v3, "not yet released for production", BUSL-1.1, audited by Côme du Crest (October 2026). Roles v2, "the version in production today", is at `zodiaceco/zodiac-modifier-roles-v2`. (9 Nov) https://raw.githubusercontent.com/gnosisguild/zodiac-modifier-roles/main/README.md , https://raw.githubusercontent.com/zodiaceco/zodiac-modifier-roles-v2/main/README.md
- v2 mainnet: Roles `0xF2964CE6161ce0e75964Fe7927cE114cb0B283D5`, Integrity `0x6a6Af4b16458Bc39817e4019fB02BD3b26d41049`, Packer `0x869718c939652084bc491fbc5ce0d3c1d5b309f0`, MultiSendUnwrapper `0xB4Cd4bb764C089f20DA18700CE8bc5e49F369efD`. Solidity 0.8.21, LGPL-3.0-only.
- Audit caveat: the four reports in the repo are dated April, May and November 2023, and the README says issues were resolved as of commit `a19c0ebd`. Sourcify shows `0xF2964…` was deployed on 12 June 2026, while the earlier mastercopy `0x9646…` was deployed on 1 December 2023. Whether the June 2026 build is covered by an audit is NOT VERIFIED.
- Scoping supported (from `Types.sol`): clearance per target or per function; execution options (send value, delegatecall, both); parameter conditions `And`/`Or`/`Nor`, `Matches`, `ArraySome`/`ArrayEvery`/`ArraySubset`, `EqualTo`, `EqualToAvatar`, `GreaterThan`/`LessThan` (signed and unsigned), `Bitmask`, `Custom`; allowances `WithinAllowance`, `EtherWithinAllowance`, `CallWithinAllowance` with refill periods.
- Members: `Role.members` is a mapping from address to bool and `assignRoles(module, roleKeys, memberOf)` takes any address, so a role can have many members.
- Tooling caveat: the hosted Roles app enforces licence terms for some features ("renew your Zodiac subscription"); the contracts can be configured directly.

### 2h. Semaphore v4

- Mainnet deployment exists as of 16 Oct 2026 (Sourcify match; `groupCounter()` returned 0 on 9 Nov, so no groups exist yet). `@semaphore-protocol/contracts` 4.14.5 was published 17 Oct 2026; depends on `@zk-kit/lean-imt.sol` 2.0.1. (9–10 Nov) https://raw.githubusercontent.com/semaphore-protocol/semaphore/main/packages/utils/src/networks/deployed-contracts.json , https://registry.npmjs.org/@semaphore-protocol/contracts
- Audit: "Semaphore PSE audit", by Mridul, Yufei Li and Kyle Charbonnet, March 2024, scope v4.0.0-beta.1 (contracts, circuits, TypeScript) and zk-kit LeanIMT. It is an internal PSE audit, not an external firm, and predates the 4.14.x code now deployed. (9 Nov) https://raw.githubusercontent.com/semaphore-protocol/semaphore/main/apps/website/public/Semaphore_4.0.0_Audit.pdf
- Limits: tree depth 1–32 (`MAX_DEPTH = 32`); one admin address per group (can be a Safe); old roots stay valid for `merkleTreeDuration` (default 1 hour).
- Gas, measured here by `eth_simulateV1` on the mainnet deployment: `createGroup()` 91,038; `addMember` 96,040 for the first member, then 145,701–255,637 for members 2–40 (tree depth up to 6, rising with depth); `addMembers` in one call: 7 members 529,732 (75.7k each), 20 members 1,310,264 (65.5k each), 100 members 5,869,237 (58.7k each). `validateProof` was not re-measured; `cost_inputs.md` has about 285.6k from HashCloak.
- Maintainer: the EF shut PSE on 23 June 2026 (search result, Bankless coverage). The repo is still active: CODEOWNERS is `@semaphore-protocol/core-devs`, npm releases 4.14.3 (8 Jul 2026), 4.14.4 and 4.14.5 (16–17 Oct 2026) were published by `vplasencia`, and the mainnet deployment is from October. Which organisation now funds it is NOT VERIFIED; the README still points to PSE.
- Can a Semaphore group replace a custom operator registry? For anonymous signalling, yes: one identity commitment per operator, group admin a Safe, each proof yields a nullifier unique per (identity, scope), so setting scope to the epoch gives one signal per operator per epoch. Proofs can be checked off-chain for free. It does not give k-messages-per-epoch limits or stake slashing on double signalling as RLN does; a duplicate is only rejected. It does not publish endpoints or keys, so it complements ERC-8004 instead of replacing it.

### 2i. Deterministic deployment

- EIP-7997 "Deterministic Factory Contract" is in Last Call (deadline 1 Nov 2026) and now makes "the availability of a well-known `CREATE2` factory at `0x4e59b44847b379578588920cA78FbF26c0B4956C` … a formal requirement". It says the factory "has been used close to 25000 times on Ethereum Mainnet" and is "the default factory for deterministic deployments in developer tools". (10 Nov) https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-7997.md
- Fork inclusion is unclear: ACDE #227 (5 Jan 2026) declined it for Glamsterdam, a June 2026 testing call discussed a genesis-file route, and later lists tag it CFI. NOT VERIFIED which is current. (10 Nov, search) https://ethereum-magicians.org/t/all-core-devs-testing-acdt-82-june-8-2026/28681
- On mainnet: Arachnid proxy and Safe Singleton Factory both hold 69 bytes of code; CreateX holds 11,838 bytes, Sourcify-verified, deployed 21 Dec 2023.
- Practical answer: the Arachnid proxy is the canonical CREATE2 factory. The Safe Singleton Factory exists for chains where the Arachnid keyless transaction cannot be replayed, and is what Safe's own contracts use. CreateX adds CREATE3 and guarded salts when needed.

### 2j. ERC-8004 registries

- EIP status: Draft. (10 Nov) https://raw.githubusercontent.com/ethereum/ERCs/master/ERCS/erc-8004.md
- On-chain (9 Nov): both addresses are ERC-1967 proxies (130 bytes). Implementations `0x7274e874ca62410a93bd8bf61c69d8045e399c02` (IdentityRegistryUpgradeable) and `0x16e0fa7f7c56b9a767e34b192b51f921be31da34` (ReputationRegistryUpgradeable), deployed 29 Jan 2026, Sourcify exact match, solc 0.8.24. `getVersion()` returns "2.0.0". UUPS, `_authorizeUpgrade` is `onlyOwner`.
- Owner of both: `0x547289319C3e6aedB179C0b8e8aF0B5ACd062603`, which has no code and nonce 37, so an externally owned account. One key can upgrade both registries.
- Audit: none mentioned in the repo README. NOT VERIFIED that none exists. No ValidationRegistry address is listed for mainnet; the README says that part of the spec "is still under active update".
- Functions an agent owner (or approved operator) can call with no new contract: `register()`, `register(string agentURI)`, `register(string agentURI, MetadataEntry[] metadata)`, `setAgentURI(uint256 agentId, string newURI)`, `setMetadata(uint256 agentId, string metadataKey, bytes metadataValue)`, `setAgentWallet(uint256 agentId, address newWallet, uint256 deadline, bytes signature)` (EIP-712, falls back to ERC-1271, so the wallet can be a Safe), `unsetAgentWallet`. Reads: `getMetadata`, `getAgentWallet`, `tokenURI`. The key `agentWallet` is reserved and cleared on transfer. The agent is an ERC-721 token named "AgentIdentity" (AGENT).
- Reputation: `giveFeedback(uint256 agentId, int128 value, uint8 valueDecimals, string tag1, string tag2, string endpoint, string feedbackURI, bytes32 feedbackHash)`. Anyone can post except the agent's owner or approved operators. `getSummary` requires a non-empty list of client addresses, which is the only Sybil filter.
- Sources (9 Nov): https://raw.githubusercontent.com/erc-8004/erc-8004-contracts/main/contracts/IdentityRegistryUpgradeable.sol , https://raw.githubusercontent.com/erc-8004/erc-8004-contracts/main/contracts/ReputationRegistryUpgradeable.sol , https://raw.githubusercontent.com/erc-8004/erc-8004-contracts/main/README.md

Use: an operator can publish endpoint, role and key through `agentURI` plus `setMetadata` today. Treat the registry as a discovery layer only, because the EIP is a Draft, the code is unaudited as far as found, and a single key can upgrade it.

### 2k. EAS

- Mainnet is version 0.26 (L2 deployments are 1.x), deployed 4 Mar 2023, Sourcify match, MIT. `VERSION()` returns "0.26" on both contracts. (10 Nov) https://raw.githubusercontent.com/ethereum-attestation-service/eas-contracts/master/README.md
- Audit: none found in the README or by search. NOT VERIFIED.
- Gas, measured here by `eth_simulateV1`: registering a three-field schema with no resolver 136,259; one `attest` with a 96-byte payload 230,737 (233,774 for a second one), whole-transaction figures.
- Can panel-signed roots be EAS attestations? Yes for publication: the Safe calls `attest`, the attester recorded is the Safe address, and anyone can read `getAttestation(uid)`. Cost is the attestation plus Safe execution, roughly 320k gas with 7 signers (sum of the two measurements less one base fee; an estimate). A Safe-signed statement checked through ERC-1271 costs 64k and needs no storage, so EAS is worth it only for its indexing, timestamps and revocation. Whether mainnet v0.26 accepts ERC-1271 signatures for delegated or off-chain attestations is NOT VERIFIED.

### 2l. Waku RLN

No change from `cost_inputs.md`. The `logos-messaging` RLN v2 contract README documents Anvil and Linea Sepolia deployment only, with a `LinearPriceCalculator`; no mainnet or Linea mainnet address or live price was found. MIT. (10 Nov) https://raw.githubusercontent.com/logos-messaging/logos-delivery-rlnv2-contract/main/README.md

### 2m. Restaking slashing for a tiny operator set

Answer: no, not off the shelf.

- EigenLayer: an AVS "is defined as the `address` of the contract that implements ServiceManagerBase"; it must register metadata and create operator sets, and since v1.9.0 each operator set names a `slasher` address. The decision to slash is entirely the AVS's; EigenLayer supplies no slashing conditions. (10 Nov) https://raw.githubusercontent.com/Layr-Labs/eigenlayer-contracts/main/docs/core/AllocationManager.md
- Symbiotic: `slash()` (or `requestSlash()` / `executeSlash()`) must be called "from `NetworkMiddlewareService.middleware(network)`"; "the Slasher module does not decide whether a network should slash an operator". (10 Nov) https://docs.symbiotic.fi/integrate/networks/slashing
- Since `slasher` and `middleware` are plain addresses, a Safe could in principle hold that role, which would give committee-discretion slashing with no new contract. That path was not tested end to end (operator registration hooks, vault configuration) and is NOT VERIFIED. Objective, proof-triggered slashing needs custom code on either platform, and restakers would still have to allocate stake to a small unknown set.

---

## Part 3. Audit market: only what is new relative to `cost_inputs.md`

| Item | New datapoint | Source |
|---|---|---|
| Solidity audit, per engagement | "$5,000 to $250,000 per engagement"; most DeFi audits "between $25,000 and $100,000"; mid-complexity DeFi "$40,000 to $100,000"; recommended pre-launch budget "$60,000 to $120,000" including one remediation review; re-audit "$5,000 to $20,000" per pass. Vendor content, dated 18 Feb 2026. | (10 Nov) https://www.sherlock.xyz/post/smart-contract-audit-pricing-a-market-reference-for-2026 |
| Contest duration by size | about 500 nSLOC: 3 days; 3,000 nSLOC: 18 days; 6,000 nSLOC: 38 days. That is about 6 days per 1,000 nSLOC (derived). No price per nSLOC is published. | same |
| ZK circuit audits | Priced as a premium: "80 to 120 percent above EVM baseline". Rust/Solana 25–40%, Cairo/Move 30–45%, urgency 20–40%. No dollar rate from zkSecurity, Veridise, Nethermind or Zellic was found. | same |
| Contest pools | Hacken notes Sherlock's "$20,000 to $200,000+" figures are prize pools, not private audit prices. Consistent with `cost_inputs.md`. | (10 Nov, search) https://hacken.io/discover/smart-contract-audit-companies-compared-2026/ |
| Effort benchmark | Trail of Bits average effort per blockchain review about 4.5 person-weeks (Oct 2026). Search snippet only. | https://eco.com/support/en/articles/17593739-smart-contract-audits-process-cost-and-tools |
| Immunefi fee | 10% charged on top of the payout; Immunefi's programme page offers a subscription that "removes the 10% platform fee on all payouts". No platform minimum found. Secondary sources. | (10 Nov, search) https://immunefi.com/bug-bounty-program/ |
| Solo-auditor practice | Zodiac Roles v3 shipped with a single independent auditor's report (October 2026). No price. | Roles v3 README |
| Formal verification | Nothing new. | – |

Nothing found contradicts `cost_inputs.md`.

Budget implication: with the ERC-1271 Safe as the panel signer, ERC-8004 for operator metadata, Semaphore for anonymous signalling and no proving service, the novel on-chain surface can shrink to whatever consumes a Safe signature. By the Sherlock duration scale, a few hundred nSLOC is a contest window of days, and the ZK premium disappears if no new circuit is written.

---

## Could not verify

1. Any published Railgun / Railway proving time on phones or in browsers; internals of `@railgun-privacy/native-prover` (rapidsnark or other).
2. Privacy Pools v2 circuit source and constraint counts; the 90k–100k figure for a 5x5 is my estimate.
3. Peak RAM of native Groth16 proving on a mid-range phone; the figures are from an Apple M1 and from snarkjs on x86.
4. Device and memory behind Aztec's "1 second" claim; iPhone model behind Zcash's "~200 ms" (vendor benchmark).
5. Which local prover TACEO used on the Galaxy S23+; TACEO:Proof pricing; licence of the TACEO node (CSE) image.
6. mopro issue #44 figure (443k constraints, 4.5 s) at source; GitHub HTML is blocked in this session.
7. Dates of the Safe 1.4.0 and 1.5.0 audit reports; Safe owner-count limit (source not re-read).
8. Whether the Zodiac Roles v2 mastercopy deployed 12 Jun 2026 is covered by the 2023 audits.
9. Whether Semaphore 4.14.x differs materially from the audited v4.0.0-beta.1; who funds Semaphore after PSE's closure; `validateProof` gas on the mainnet deployment.
10. Whether ERC-8004 contracts have any audit; whether the owner key is held by more than one party off-chain.
11. Whether EAS has a published audit; ERC-1271 support for delegated or off-chain attestations on mainnet v0.26.
12. EIP-7997's Glamsterdam inclusion status; whether it moved past Last Call after 1 Nov 2026.
13. Any Waku RLN mainnet or Linea mainnet deployment and live price.
14. Whether a Safe can act as EigenLayer AVS/slasher or Symbiotic middleware end to end.
15. Dollar rates for ZK circuit audits and formal verification; any Immunefi minimum fee; primary confirmation of the 10% fee terms.
16. Etherscan verification pages (403); Sourcify was used instead. `codeload.github.com` and `github.com` HTML were blocked (403), so repo contents came from `raw.githubusercontent.com` and jsDelivr listings.
