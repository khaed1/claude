# PLEA v10 (Seasons): testnet build plan (2026-10-10)

Naming (user, 2026-10-10): the Seasons version is **v10**; later iterations or jobs are v11, v12, … v4 keeps its name.

Goal: PLEA with Seasons live on Sepolia and tested before the hackathon deadline (19 Oct), in parallel with v4. If it works, PLEA launches with Seasons.

## Route: our own code, launched through IMD
IMD can launch a **Foundry repository we write** ("From your repository" in the docs): `launch.open` with `repoUrl` + `baseCommit` (a **public** GitHub repo, `bytecode_hash = "none"` in foundry.toml). It runs IMD's `audit-imported-code`, `adapt-contract-project` and the audit panel, then deploys like any launch. So:
- no 7,280-character prompt limit (Seasons won't fit in one prompt);
- we control the code and test it fully (Foundry, fast clock) before paying for anything;
- it's still launched by the IMD swarm, as the hackathon requires.

## Contracts (v4 + Seasons)
| Contract | Role |
|---|---|
| PLEA | v4 token; the restriction reads `gate.cabalAlive()` (switches on and off) instead of a one-way flag; `registerExit(pool)` for genuine Uniswap v2/v3 pools |
| CabalGate | v4 gate + numeric plea score from the oracle, the current mood's wording, reports approved pleas to Seasons, era retirement, revival |
| PleaHook | v4 hook (deployed after launch) + 0.25% prize fee in IMD to Seasons |
| Seasons | 15-day seasons, best-3 points, relic bonus, top-10 list, `closeSeason()` payout 25/18/14/11/9/7/6/4/3/3, 60-point minimum, roll-over; eras of 2 seasons; break 72h → ransom (500 IMD, 72h refund) → warning 24h → revival with the next mood |
| Laureates | ERC-721, top 5 pleas per season, on-chain text |
| Relics + names | soulbound relic per ransom wallet per season (≥6 IMD); `setName` usernames |
| PleaLaunch, PleaDistributor | as v4 |

Timings are constructor arguments (immutables) with the mainnet guard; Sepolia uses 1 day = 20 min.

## Steps
1. **Numeric score test (running):** can the oracle sign a plea *score* (uint256 with `toleranceBps`), not just true/false? The leaderboard needs it. Fallback if not: points = the plea's `need` (the bar it cleared), computed on chain.
2. **Public repo** for the code (needs the user's OK and a name).
3. **Write the contracts and Foundry tests**, starting from v2's public code and merging v4's fixes when v4 delivers.
4. **Fork test** (Sepolia fork, time jumps, real Intake replies faked), then **`POST /requests/import`** and a free `/requests/check`.
5. **Launch** (`launch.open` with repoUrl/baseCommit, `evm_contracts`, Sepolia). Mine the hook salt, `deployHook`, `seed()`.
6. **Live fast-clock test:** a full season and era in about 12 hours, with real judges.
7. **Site** (`job.continue` on the launch) and the hackathon submission.

## Risks
- **Deploy gas:** more contracts. Keep each launch tx under 16.7M gas; deploy extras (hook, mood wording) after launch like `deployHook`.
- **Audit panel findings** can block the launch; fix and re-import.
- **Time:** 9 days. Cut order if late: usernames → Laureate art → ransom refunds UI; never cut the mainnet guard or tests.
