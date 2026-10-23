# One Dollar Audit for PLEA run 8.5 (submitted 2026-10-17 06:11 UTC)

[onedollaraudit.com](https://www.onedollaraudit.com/) is an AI audit service run by LeftClaw Services. Each job costs **$1 USDC on Base** (live price confirmed from the endpoint's 402 reply: 1,000,000 USDC units, payTo `0xCfB32a7d01Ca2B4B538C83B2b38656D3502D76EA`). You send a description, either a source link or a short paste of under ~12,000 characters. It is stored **publicly on chain**. The report comes back within about 8 hours, with severity ratings and fixes.

Their rule is "one contract (or one tight system) per $1 engagement", so PLEA went in as **four jobs, $4 in all**, on **run 8.5's code**: `khaed1/plea` `testnet8.5` @ `af57f6df709acdf7fe754a58482ee35eef9e2178`. That is byte-identical `src/` to launch #1981 live on Sepolia, and the user asked for exactly this version. The spec and the ledger links point at the latest docs, `mainnet` @ `54da76b`. Each job also tells the auditor that the two run-8.5 launch-audit findings are known and fixed after it:

| Job | File | Scope (run 8.5) | nSLOC | Characters |
|---|---|---|---|---|
| [1014](https://onedollaraudit.com/audit/1014) | `job1-hook.txt` | `PleaHook.sol`: the v4 hook (fees, launch window, cap and trim, wall, claims) | 863 | 4,030 |
| [1015](https://onedollaraudit.com/audit/1015) | `job2-gate.txt` | `CabalGate.sol` + `OracleAttestation.sol`: pleas, the fact score, oracle answers, the text filter | 819 | 3,902 |
| [1016](https://onedollaraudit.com/audit/1016) | `job3-letters-launch.txt` | `Letterbox.sol` + `PLEA.sol` + `PleaLaunch.sol` + `PleaDistributor.sol` + `launch.json` | 861 | 5,030 |
| [1017](https://onedollaraudit.com/audit/1017) | `job4-tribunal-seasons.txt` | `Tribunal.sol` + `Seasons.sol`: objections, stakes, seasons, prizes, flush | 786 | 3,876 |
| [1018](https://onedollaraudit.com/audit/1018) | `job1-hook-rerun.txt` | `PleaHook.sol` again, after the THREAT-MODEL rewording of job 1014 (submitted 10:50 UTC; the user added $1) | 863 | 4,817 |

Each description links the public repo at the pinned commit and its spec (`audit/THREAT-MODEL.md`), so agreed numbers are not reported as bugs. It also links the findings ledger (`audit/FINDINGS.md`), so fixed or accepted items are not re-reported. Each one names the files in scope and the areas to look at hardest. Nothing secret is in them.

## Payment (done)

The user funded wallet A on Base with 4.000270 USDC. The session paid the four jobs through x402 on 2026-10-17 between 06:11 and 06:12 UTC, $1.00 each, as gasless USDC signatures; 0.000270 USDC is left. The job ids are in `jobs.json`. Each job was "Open" right after, with an estimate of about 8 hours. Status: `node plea/tools/submit_onedollaraudit.mjs status <id>` or `https://www.onedollaraudit.com/api/jobs/<id>`.

Job 1018 was paid the same way at 10:50 UTC from the $1 the user added later; wallet A then held 0.111418 USDC on Base.

## Script

```
npm install --prefix <dir> viem @x402/core @x402/evm @x402/fetch
NODE_PATH=<dir>/node_modules PAYER_KEY="$PONDPAD_TESTNET_KEY" node plea/tools/submit_onedollaraudit.mjs check  plea/onedollaraudit/job1-hook.txt   # loads, shows the payer, sends nothing
NODE_PATH=<dir>/node_modules PAYER_KEY="$PONDPAD_TESTNET_KEY" node plea/tools/submit_onedollaraudit.mjs submit plea/onedollaraudit/job1-hook.txt   # pays $1, saves the job id
node plea/tools/submit_onedollaraudit.mjs status <jobId>                                                                                        # free, read-only
```

`check` was run on 2026-10-17: the libraries load and the payer is wallet A. Never re-submit to "check" a job; read its status instead.

## Results (all five done, 2026-10-17)

| Job | Done (UTC) | Claimed | Our check (`reports/`) | Ledger |
|---|---|---|---|---|
| 1015 gate | 09:07 | 1 Low, 2 Info | the Low is by design (buying more PLEA first moves a plea into a better band) | ODA-1015-1 accepted by the owner, -2/-3 noted |
| 1014 hook | 10:25 | 1 High, 2 Medium, 4 Low, 3 Info | none reachable (checked on chain and tested) | ODA-1014-1 to -10; three THREAT-MODEL passages reworded |
| 1017 Tribunal + Seasons | 11:33 | 1 High, 2 Medium described (3 in the header), 3 Low, 6 Info | none reachable; the IMD wiring gap is covered by the manifest test | ODA-1017-1 to -12; invariant 10 reworded |
| 1018 hook again | 14:33 | 4 Low, 8 Info (9 in the header) | upholds ODA-1014-1 to -3; nothing needs code | ODA-1018-1 to -12; invariant 22 and the keeper paragraph reworded |
| 1016 letters + launch | 14:47 | 1 Low, 2 Info | the Low (PLEA's registration window) is closed by IMD's atomic factory | ODA-1016-1 to -3; the window named in THREAT-MODEL §3 |

No Critical anywhere; no code change. Recorded on `next` @ `8de5d46`, `main` @ `b103be1`, `mainnet` @ `085394d`, `light-profile` @ `180b13b`.

## After the reports

Record each finding in `audit/FINDINGS.md` as `ODA-<job>-<n>` with its status. Verify it against the code and tests before believing it. Fix what is real only with the owner's OK, on `next` → `main`, `mainnet` and `light-profile`, never on the pinned `testnet8` or `testnet8.5`. This is a fast AI first pass, not a manual audit; the site says so too.
