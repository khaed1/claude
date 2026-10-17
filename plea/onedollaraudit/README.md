# One Dollar Audit for PLEA (prepared 2026-10-17, not submitted)

[onedollaraudit.com](https://www.onedollaraudit.com/) is an AI audit service run by LeftClaw Services. Each job costs **$1 USDC on Base** (live price confirmed from the endpoint's 402 reply: 1,000,000 USDC units, payTo `0xCfB32a7d01Ca2B4B538C83B2b38656D3502D76EA`). You send a description, either a source link or a short paste of under ~12,000 characters. It is stored **publicly on chain**. The report comes back within about 8 hours, with severity ratings and fixes.

Their rule is "one contract (or one tight system) per $1 engagement", so PLEA goes in as **four jobs, $4 in all**. They follow our IMD audit areas, with the hook and the game split up:

| File | Scope (mainnet branch @ `54da76be64c6f01764e27e6cc5b65811475d5e77`) | nSLOC | Characters |
|---|---|---|---|
| `job1-hook.txt` | `PleaHook.sol`: the v4 hook (fees, launch window, cap and trim, wall, claims) | 863 | 3,138 |
| `job2-gate.txt` | `CabalGate.sol` + `OracleAttestation.sol`: pleas, the fact score, oracle answers, the text filter | 822 | 3,053 |
| `job3-letters-launch.txt` | `Letterbox.sol` + `PLEA.sol` + `PleaLaunch.sol` + `PleaDistributor.sol` + `launch.json`: letters, the token's transfer rule, the launch, the airdrop | 861 | 3,954 |
| `job4-tribunal-seasons.txt` | `Tribunal.sol` + `Seasons.sol`: objections, stakes, seasons, prizes, flush | 786 | 2,940 |

Each description links the public repo at the pinned commit and its spec (`audit/THREAT-MODEL.md`), so agreed numbers are not reported as bugs. It also links the findings ledger (`audit/FINDINGS.md`), so fixed or accepted items are not re-reported. Each one names the files in scope and the areas to look at hardest. Nothing secret is in them.

## How to pay

**Wallet A is funded on Base:** the user sent USDC on 2026-10-17. Wallet A `0x4b91078b2374c956A65F7Af0999CaE0a935E6821` holds 4.000270 USDC and 0.00035 ETH on Base. x402 is a gasless USDC signature, so no ETH is needed. With the owner's go-ahead the session submits the four jobs with `plea/tools/submit_onedollaraudit.mjs`, saves the job ids in `jobs.json`, follows them and reads the reports. (Alternative: paste each `jobN-*.txt` into "Subject of engagement" on the site and pay from any Base wallet.)

## Script

```
npm install --prefix <dir> viem @x402/core @x402/evm @x402/fetch
NODE_PATH=<dir>/node_modules PAYER_KEY="$PONDPAD_TESTNET_KEY" node plea/tools/submit_onedollaraudit.mjs check  plea/onedollaraudit/job1-hook.txt   # loads, shows the payer, sends nothing
NODE_PATH=<dir>/node_modules PAYER_KEY="$PONDPAD_TESTNET_KEY" node plea/tools/submit_onedollaraudit.mjs submit plea/onedollaraudit/job1-hook.txt   # pays $1, saves the job id
node plea/tools/submit_onedollaraudit.mjs status <jobId>                                                                                        # free, read-only
```

`check` was run on 2026-10-17: the libraries load and the payer is wallet A. Never re-submit to "check" a job; read its status instead.

## After the reports

Record each finding in `audit/FINDINGS.md` as `ODA-<job>-<n>` with its status. Verify it against the code and tests before believing it. Fix what is real only with the owner's OK, on `next` → `main`, `mainnet` and `light-profile`, never on the pinned `testnet8` or `testnet8.5`. This is a fast AI first pass, not a manual audit; the site says so too.
