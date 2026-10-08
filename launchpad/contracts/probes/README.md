# Probes

Test-only contracts deployed to learn how outside services behave. **Not part of PondPad**, outside the audit scope (`audit/make_jobs.py` covers `src/`, `script/`, `upstream/`), never used by any PondPad contract. Run their local tests with `FOUNDRY_TEST=probes forge test --match-path probes/OracleProbe.t.sol -vv`.

## OracleProbe: a live IMD oracle test on Robinhood (8 Oct 2026)

`OracleProbe.sol` buys one IMD oracle question through IMD's Intake (`0x1397…ea56`) with a callback to itself and checks the delivered answer with PondPad's own `AttestationVerifier`, deployed unchanged. It records whether the answer verifies against the exact question, what it says, the gas the check took inside Intake's 200,000-gas callback, and the delivery time against the answer's `issuedAt`. `submit()` hands an answer over by hand if the callback failed. User's go-ahead and funding (1 IMD, a little ETH on Robinhood) for the questions in HANDOFF §6b.

Deployed from the testnet wallet (`0x4b91…6821`) on Robinhood Chain (4663):

| Contract | Address | Notes |
|---|---|---|
| `AttestationVerifier` (from `src/`, unchanged) | `0x4aA80e829d8035564f8eb8a880A6a040898382A6` | owner: the testnet wallet; IMD's attester `0x5598…2982` approved; panel ≥ 51, agreement ≥ 2/3 (defaults) |
| `OracleProbe` | `0x79D37ad408ae028eDDaF31B3828Dc53C811860f5` | intake `0x1397…ea56`, IMD `0x5F7B…7127`, the verifier above; holds no IMD now |

Both questions: evidence `panel`, chain 4663, window 24 hours, panel 51, quorum 34, valid 7 days, `allowAmbiguous: true`, consumer = the verifier above (lowercase). Each body passed IMD's free quote (`POST /requests/quote`, not paid) before it was sent; IMD's free check flagged both `not_answerable`.

| | Question | Correct answer | Outcome |
|---|---|---|---|
| Q1 | The exact `VersionRegistry.question(1, "25284cb4-…")` of the live testnet registry (529 characters: "PondPad version 1 on chain id 46630: does IMD swarm audit job 25284cb4-… cover the contracts with code hash 0xdc51… (factory …, router …, curve …, hook …, lens …) and report no open high or critical findings? Answer true only if both hold.") | **false**: the testnet runs pre-D-78 code, the job audited `3cd764f` | **No answer** (`disagreed`): 25 of 35 answers said **true**, 10 false, 34 needed. The "true" members matched the five contract names to the job's file list and checked neither the code hash nor the addresses; a few "false" members saw the chain (46630 vs 4663) or commit mismatch, others found no source. Fee spent, nothing refunded. Intake tx `0xb262…292e`, oracle request `9b26a345-e2dc-4ffb-aaa7-eb3ff4cf49b9` |
| Q2 | "Does the IMD swarm audit report at https://api.imd.fun/jobs/25284cb4-…/report.md list no finding of high or critical severity? Answer true only if the report lists no finding rated high or critical." | **true** (1 Low, 2 Info) | **Attested true**, 35 of 36 answers (51 seats, quorum 34), 74 s after the request; delivered by callback 16 s after `issuedAt`; our verifier accepted it inside the callback (`verifyBool` 81,093 gas for a 224-character question). Intake tx `0x3a86…2f27`, oracle request `15e37a04-953b-4119-9e04-f55216ddc237` |

Local test (`OracleProbe.t.sol`, a mock Intake with the same 200,000-gas call): the callback selector is IMD's `0x510379c7`; the 7 Oct live answer verifies in the callback (52k gas, 140 characters); a ~560-character question's check costs ~161k gas on its own (`checkQuestionText` ~250 gas per character), so it runs out inside the callback (the probe records the delivery first, then `submit` checks it).
