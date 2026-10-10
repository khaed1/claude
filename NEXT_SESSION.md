Repos: `khaed1/claude` (notes, prompts, HANDOFF; work and push only on branch **`claude/adoring-goodall-pn3jyz`**) and `khaed1/plea` (public, PLEA v10 code; branch `main`). If `khaed1/plea` isn't in your session, attach it with `add_repo` (push access).

You're picking up two projects I'm building on the IMD swarm (imd.fun). The previous session ran out of context. **HANDOFF.md is the source of truth** (addresses, tx hashes, decisions, bugs, test results); read it first, newest sections at the end, then the files below as needed.

## The two projects in brief
- **imd/acc:** 0.5% trading cashback, paid to traders as staked IMD (sIMD) out of a project's existing fees. A shared, ownerless `Stacker.credit(trader, imdAmount)` deposits into the sIMD vault in the trader's name. Points count only for listed projects (`projects.json`). **Live on Sepolia** (TestIMD, TestSIMD, Stacker, test site) and tested end to end.
- **PLEA:** a sell-gated meme token, a relaunch of TokenWorks' CabalCoin. Buying is open; **selling needs a plea approved by "the Cabal"**, an IMD oracle panel of 30 judges (quorum 17). One Uniswap v4 hook (POOL4 CappedBurnHook fork, IMD side). Fees: 0.5% sIMD cashback, 0.5% owner, 0.25% liquidity, plus a 0.25% PLEA burn.
  - **v2** is live on Sepolia (launch #1148), tested.
  - **v4** (fixes for v2's 14 problems) is being built by IMD now: job **`8686f9e4-7725-4043-b465-67908c5c4b46`** (START 1791775740 = 2026-10-12 03:29 UTC). Prompt: `plea/job-sepolia.md`.
  - **v10 = Seasons** (decided 2026-10-10): 15-day seasons with a top-10 leaderboard (new 0.25% prize fee, total 1.75%), 30-day eras (2 seasons) each with a Cabal mood (Classic, Rekt, Jester's, Loyal), then 72h free trading, a 500 IMD ransom to revive the next Cabal (72h refund), 24h warning; Laureate NFTs for the top 5 pleas; soulbound relics (≥6 IMD) worth +10% next season; `registerExit` for outside Uniswap v2/v3 pools; usernames. **We write the code ourselves in `khaed1/plea`** and launch it through IMD with `launch.open` + `repoUrl`/`baseCommit`. It's built in parallel with v4; if it works, PLEA launches with v10. Later versions are v11, v12, …

## Files to read
- `HANDOFF.md`: everything; start with the last sections ("Numeric plea score can be signed", "PLEA v10 (Seasons): where we stopped").
- `plea/v10-build-plan.md`: route, contracts, steps, risks.
- `plea/brainstorm-seasons.md`: every Seasons decision (summary table, rounds 2–7, the Rekt Cabal wording v2 = final, calibration results, fast-clock testing).
- `plea/seasons-ux.md`: the user experience, phase by phase.
- `plea/v4-plan.md`, `plea/job-sepolia.md`: v4's problems, decisions and prompt.
- `plea/job-v4-site.md`: the v4 site prompt (submit as `job.continue` once v4 is live).
- `plea/hackathon-submission.md`: draft entry for the proposed IMD hackathon (PLEA + imd/acc; `{…}` placeholders for v4/v10 links).
- `plea/dev-feedback.md`: our message to the IMD dev (items 1–7; item 7 = chain mode can't sign transaction-level checks).
- `imd-acc/README.md`: the imd/acc spec.
- **Code:** `khaed1/plea` (v10 base = v2 code, commit `a40a756`); PLEA v2 https://github.com/identity-md-launches/launch-1148-build-plea-sepolia-test ; imd/acc https://github.com/identity-md-launches/launch-1129-build-imd-acc-sepolia-test ; v4's repo appears when job `8686f9e4` delivers.
- **IMD:** docs https://imd.fun/docs/ ("Pay on chain", "Ask the oracle", "From your repository") · API https://api.imd.fun

## Where we stopped (2026-10-10 ~09:30 UTC)
1. **Take over the hourly v4 check-in:** routine `trig_017xZjHXdR24qGEezWuyUoyn` fires into the old session. Create the same routine for your session (prompt is in the routine; read it with `get_trigger`), then delete the old one. On go-live: ping me, record addresses, mine the salt, `deployHook` from the test wallet, verify, ping again.
2. **v4 status:** build attempt 1 was rejected by Slither (`arbitrary-send-erc20` in `CabalGate.unlockCallback`); the build was re-queued. If it blocks, propose the one-line fix in HANDOFF and a resubmit (I submit; move START if needed).
3. **Write v10 in `khaed1/plea`.** Nothing is written yet beyond the v2 base. Follow the design notes in HANDOFF (oracle callback 200k gas → store only the score; lazy "alive"; MoodBook; Laureates via text hash; registerExit; deploy-time timings with the mainnet guard). The oracle can sign a numeric score: use `answerType: "uint256"`, `toleranceBps: 1500`. Merge v4's fixes once its repo delivers. Then: Foundry tests incl. full cycles with `vm.warp`, a Sepolia fork test, `POST /requests/import`, launch, `deployHook`, a live fast-clock run (1 day = 20 min), the site, the hackathon entry.
4. **Waiting on the IMD dev:** reply to `plea/dev-feedback.md`, and the hackathon's dates/network.

## Useful facts
- **Sepolia oracle tests are free:** Intake `0x1397434cd35e8a9c8ac312a61d3a285eb31dea56`; test IMD `0x44a1cd38474fb1748400e7deb5f8d786cce3f89a` (anyone can `mint`). Body must name a testnet `consumer` `{chainId: 11155111, verifyingContract}`. Results: `GET /intake/11155111/{tx}` → `admission.result.requestId` → `GET /oracle/requests/{id}`. Each definition ≤ 512 chars, question ≤ 2,000.
- **Ethereum data:** `https://eth.drpc.org` for logs (≤100 blocks per call, archive ok); publicnode refuses old logs.
- **Foundry:** `foundryup` is blocked; download `foundry_v1.8.3_linux_amd64.tar.gz` from the GitHub release into `~/.foundry/bin`.
- **Prompt size** (prompt-based jobs only): about 7,280 characters, check with `POST /requests/check`.

## Rules
- **Explain simply.** When I need to choose, recommend one option.
- **Don't change agreed numbers** (fees, caps, timings, supply split, quorum 17, dead-man 33h, expiry 20 min, and the Seasons numbers in `plea/brainstorm-seasons.md`) without asking me.
- **Keys:** the Sepolia test wallet `0x4b91…6821` (testnet only) has its key in env `TESTNET_KEY`. Never print or commit it, and never ask me to paste a mainnet key.
- **`khaed1/plea` is public:** only code, tests and a README there; no notes, keys or HANDOFF.
- **PondPad** (branch `claude/bold-gauss-qhlw86`) is read-only. Never commit its code.
