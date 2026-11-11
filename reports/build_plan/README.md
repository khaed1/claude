# Murmuration build plan

Draft job briefs for the IMD swarm, written against the build specification in `reports/Murmuration v4 specification.html`. **None has been submitted, and none should be without the owner's decision.** Everything in a brief becomes public for good once it is.

The briefs were regenerated on 11 November 2026 for revision 4.2 of the specification, which answers an independent review. Two reviews in two days each found faults in the fixes for the one before, so no brief should be submitted until a reviewer who has seen neither has read revision 4.2.

There are 50 briefs. Each is sized for one IMD request under the limits IMD publishes (read 10 November 2026): an objective of at most 8,000 characters, at most six steps of one skill each, at most eight acceptance criteria per step of 500 characters each, at most 16 writable paths, at most four contracts named, and a request body of at most 16 KiB. `generate.py` writes these files and fails if a brief breaks a limit.

## What IMD checks, and what it does not

- A request costs 0.5 IMD whatever its size. There are no refunds and no buyer acceptance step: IMD's own verifier accepts or rejects.
- For Solidity the verifier runs `forge build`, `forge test` and Slither. Those briefs carry their acceptance tests as Foundry tests.
- For everything else (Lean, Circom, TypeScript, scripts) the verifier checks only structure and paths. Those briefs name a `make` target, and a later review job, or anyone, re-runs it. Treat an accepted non-Solidity job as unverified until that has happened.
- IMD's audit template is for Solidity: four specialists and a judge. Nothing public shows IMD has reviewed a zero-knowledge circuit. R03 supplies a circuit checklist and P01 to P04 put the weight on machine-checked proofs.
- A job gets its inputs from a public GitHub repository at a pinned commit. The project needs one public repository that every job builds on.

## Order

1. B00, then C00 and R01. The owner reads R01 and signs off the frozen statements. Nothing in the proof track starts before that.
2. Contracts B10 to B41 and the circuit C01 to C07 in parallel. Each contract's fuzz job follows it.
3. Proofs P01 to P05, reviews R02 and R03, audits A01 to A05. Fixes go through `fix-findings` and the changed contract is audited again.
4. B50, B51, B60, the node and wallet S01 to S03, R05.
5. L01 and L02, then R04 on the real ceremony output. The lawyer's review comes before the canary runs.

## Budget

50 requests are 25.0 IMD, about $66 at $2.64. Rejected attempts, fix rounds and second audits will multiply that several times. A plan of 300 to 600 requests, 150 to 300 IMD, is a reasonable working figure.

## Foundation and contracts

| Id | Brief | Kind | Template | Depends on |
|---|---|---|---|---|
| B00 | [Repository scaffold and parameter files](B00-repository-scaffold-and-parameter-files.md) | Build | `single` | none |
| B10 | [Token](B10-token.md) | Build | `impl_tests` | B00 |
| B11 | [Hash adapter and note tree](B11-hash-adapter-and-note-tree.md) | Build | `impl_tests` | B00 |
| B12 | [Pool: deposit, activate, refund](B12-pool-deposit-activate-refund.md) | Build | `impl_tests_review` | B11 |
| B13 | [Reward index library](B13-reward-index-library.md) | Build | `impl_tests` | B00 |
| B14 | [Pool: spend and roll](B14-pool-spend-and-roll.md) | Build | `impl_tests_review` | B12, B13 |
| B15 | [Pool: fees, key announcements, size and gas report](B15-pool-fees-key-announcements-size-and-gas-report.md) | Build | `impl_tests` | B14 |
| B20 | [ScreenerRegistry: membership and stake](B20-screenerregistry-membership-and-stake.md) | Build | `impl_tests_review` | B10 |
| B21 | [ScreenerRegistry: commit, reveal, accept, apply](B21-screenerregistry-commit-reveal-accept-apply.md) | Build | `impl_tests_review` | B20 |
| B22 | [ScreenerRegistry: pay](B22-screenerregistry-pay.md) | Build | `impl_tests` | B21 |
| B30 | [FeeDistributor: split and staking streams](B30-feedistributor-split-and-staking-streams.md) | Build | `impl_tests_review` | B10, B22 |
| B31 | [FeeDistributor: basket auction](B31-feedistributor-basket-auction.md) | Build | `impl_tests` | B30 |
| B32 | [FeeDistributor: buyback through the locked pool](B32-feedistributor-buyback-through-the-locked-pool.md) | Build | `impl_tests_review` | B31, B40 |
| B40 | [Distribution: launch and the locked position](B40-distribution-launch-and-the-locked-position.md) | Build | `impl_tests_review` | B10 |
| B41 | [Distribution: vesting, swarm claims, fee collection](B41-distribution-vesting-swarm-claims-fee-collection.md) | Build | `impl_tests` | B40 |
| B50 | [Deployer and deployment script](B50-deployer-and-deployment-script.md) | Build | `impl_tests` | B15, B22, B32, B41, B51 |
| B51 | [Verifier and verification-key checks](B51-verifier-and-verification-key-checks.md) | Build | `impl_tests` | C06 |
| B60 | [End-to-end tests with real proofs](B60-end-to-end-tests-with-real-proofs.md) | Build | `single` | B50, C06, S03 |

## Fuzzing

| Id | Brief | Kind | Template | Depends on |
|---|---|---|---|---|
| F01 | [Fuzz: pool accounting](F01-fuzz-pool-accounting.md) | Build | `fuzz` | B15 |
| F02 | [Fuzz: reward budget](F02-fuzz-reward-budget.md) | Build | `fuzz` | B14 |
| F03 | [Fuzz: registry](F03-fuzz-registry.md) | Build | `fuzz` | B22 |
| F04 | [Fuzz: distributor](F04-fuzz-distributor.md) | Build | `fuzz` | B32 |

## Circuit

| Id | Brief | Kind | Template | Depends on |
|---|---|---|---|---|
| C00 | [Formal specification of Spend, frozen](C00-formal-specification-of-spend-frozen.md) | Build | `single` | B00 |
| C01 | [Circuit gadgets in clean: ranges, division, selection](C01-circuit-gadgets-in-clean-ranges-division-selection.md) | Build | `single` | C00 |
| C02 | [Poseidon at widths 3, 4 and 5 in clean](C02-poseidon-at-widths-3-4-and-5-in-clean.md) | Build | `single` | C00 |
| C03 | [Merkle membership and bundle gadgets](C03-merkle-membership-and-bundle-gadgets.md) | Build | `single` | C02 |
| C04 | [Spend circuit: composition and export](C04-spend-circuit-composition-and-export.md) | Build | `single` | C01, C03 |
| C05 | [Independent Circom implementation as a test oracle](C05-independent-circom-implementation-as-a-test-oracle.md) | Build | `single` | C00 |
| C06 | [Proof fixtures and development setup](C06-proof-fixtures-and-development-setup.md) | Build | `single` | C04 |
| C07 | [Wallet cryptography library](C07-wallet-cryptography-library.md) | Build | `single` | C00 |

## Proofs

| Id | Brief | Kind | Template | Depends on |
|---|---|---|---|---|
| P01 | [Proofs: range, division, selection and packing gadgets](P01-proofs-range-division-selection-and-packing-gadgets.md) | Proof | `single` | C01, R01 |
| P02 | [Proofs: Poseidon at widths 3, 4 and 5](P02-proofs-poseidon-at-widths-3-4-and-5.md) | Proof | `single` | C02, R01 |
| P03 | [Proofs: Merkle membership and bundle](P03-proofs-merkle-membership-and-bundle.md) | Proof | `single` | C03, P02, R01 |
| P04 | [Proofs: the top statement and its ten lemmas](P04-proofs-the-top-statement-and-its-ten-lemmas.md) | Proof | `single` | C04, P01, P03 |
| P05 | [Automatic checkers on the Circom oracle](P05-automatic-checkers-on-the-circom-oracle.md) | Proof | `single` | C05 |

## Reviews

| Id | Brief | Kind | Template | Depends on |
|---|---|---|---|---|
| R01 | [Review: are the frozen statements the right ones](R01-review-are-the-frozen-statements-the-right-ones.md) | Review | `research` | C00 |
| R02 | [Review: circuit and contract interface](R02-review-circuit-and-contract-interface.md) | Review | `single` | B14, C04 |
| R03 | [Review: zero-knowledge circuit checklist](R03-review-zero-knowledge-circuit-checklist.md) | Review | `research` | C04, C05 |
| R04 | [Review: ceremony transcript and verification key](R04-review-ceremony-transcript-and-verification-key.md) | Review | `single` | L02, B51 |
| R05 | [Review: launch, auction and buyback on a fork](R05-review-launch-auction-and-buyback-on-a-fork.md) | Review | `single` | B32, B41 |

## Audits

| Id | Brief | Kind | Template | Depends on |
|---|---|---|---|---|
| A01 | [Audit: Token, Distribution, Deployer](A01-audit-token-distribution-deployer.md) | Audit | `audit` | B41, B50 |
| A02 | [Audit: Pool](A02-audit-pool.md) | Audit | `audit` | B15 |
| A03 | [Audit: ScreenerRegistry](A03-audit-screenerregistry.md) | Audit | `audit` | B22 |
| A04 | [Audit: FeeDistributor](A04-audit-feedistributor.md) | Audit | `audit` | B32 |
| A05 | [Audit: Verifier](A05-audit-verifier.md) | Audit | `audit` | B51 |

## Node and wallet

| Id | Brief | Kind | Template | Depends on |
|---|---|---|---|---|
| S01 | [Deterministic screening program](S01-deterministic-screening-program.md) | Build | `single` | B21 |
| S02 | [Node duty: commit, reveal, apply](S02-node-duty-commit-reveal-apply.md) | Build | `single` | S01 |
| S03 | [Wallet flows for the pool](S03-wallet-flows-for-the-pool.md) | Build | `single` | C06, C07 |

## Canary and ceremony

| Id | Brief | Kind | Template | Depends on |
|---|---|---|---|---|
| L01 | [Canary script and record](L01-canary-script-and-record.md) | Build | `single` | B60, S02, S03 |
| L02 | [Ceremony tooling](L02-ceremony-tooling.md) | Build | `single` | C04, P04 |
