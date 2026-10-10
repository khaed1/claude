Repos: `khaed1/claude` (notes, prompts, HANDOFF; work and push only on branch **`claude/adoring-goodall-pn3jyz`**) and `khaed1/plea` (public, the PLEA code; branch `main`). If `khaed1/plea` isn't in your session, attach it with `add_repo` (push access).

You're picking up two projects I'm building on the IMD swarm (imd.fun). The previous session ran out of context. **HANDOFF.md is the source of truth**; read the last sections first ("Simplified: one Cabal + seasons", "v4 delivered but launch PARKED", "v10 ready to submit"). Sections about moods, eras, ransom and relics are **superseded**.

## The two projects in brief
- **imd/acc:** 0.5% trading cashback, paid to traders as staked IMD (sIMD) from a project's existing fees, through a shared ownerless `Stacker.credit(trader, imdAmount)`. **Live on Sepolia** (TestIMD `0x2b69…1e82`, TestSIMD `0xf9e2…1cc1`, Stacker `0x293c…f477`) and tested end to end. Spec: `imd-acc/README.md`.
- **PLEA:** a sell-gated meme token, inspired by TokenWorks' CabalCoin. Buying is open; **selling needs a plea scored by "the Cabal"** (IMD oracle panel, 30 judges, quorum 17, numeric score 0–45; pass if score ≥ need = 70 − on-chain fact score). One Uniswap v4 hook (POOL4 CappedBurnHook fork, IMD side). Fees 1.75%: 0.5% sIMD cashback, 0.5% owner, 0.25% prize pot, 0.25% liquidity, 0.25% PLEA burn.
  - **The version we launch now ("v10", decided 2026-10-10):** v4's rules (one Cabal; it dies after 33h with no signed verdict and then trading is free forever, no comeback) **plus seasons**: 15-day seasons back to back from launch (last one ends at the death), each wallet's best 3 scores count, top 10 paid 25/18/14/11/9/7/6/4/3/3 % (60-point minimum, roll-over), top 5 pleas become Laureate NFTs, usernames. After death the prize fee goes to liquidity and leftovers flush to the buy wall. No moods, eras, ransom, relics or exit pools.
  - v2 is live on Sepolia (launch #1148). v4 (job `8686f9e4`, launch #1226) delivered but was **parked** by IMD's `protected_invariants` check (its `setLauncher` lacks the deploy-block fallback). The user chose to **skip v4 and launch v10**.

## Where we stopped (2026-10-10 ~13:10 UTC)
- **Code:** `khaed1/plea` `main` commit **`e08cd34`**: PLEA, CabalGate, Seasons, Laureates, PleaDistributor, PleaLaunch (launch.json, 6 contracts), PleaHook (deployed after launch via `deployHook`), scripts `Deploy.s.sol` and `MineSalt.s.sol`, 105 Foundry tests. README credits TokenWorks.
- **Sepolia settings (agreed):** season 5h (18000 s), **real 33h dead-man** (118800 s), plea timings real, **START = 1791817200 (Mon 2026-10-12 15:00 UTC)**, credit gas 1.3M, owner `0x4b91078b2374c956a65f7af0999cae0a935e6821`.
- **Verified last session:** all tests pass (also `forge test --isolate` for the launch tests); clean build fits in memory only with `[lint] lint_on_build = false` (forge's linter used 13.6 GB on the hook; keep that line); Sepolia fork run: deploy 10.73M gas, 8/8 buys with plain gas estimates stacking sIMD through the live Stacker, a plea paid through the real Intake approved via the callback, sell and leaderboard record OK; real Sepolia oracle panels signed numeric scores (35 and 21) for our exact body format; Slither has no `arbitrary-send-erc20`.
- **Free IMD checks:** `POST /requests/import` resolves `e08cd34`; `POST /requests/check` with `plea/job-v10-launch.json` → **no blockers**.
- The hourly v4 routine `trig_01HpY7DMNkPaKhaFgLeW43MG` is paused; delete it.

## Your tasks, in order
1. **Re-verify `khaed1/plea` at `e08cd34`:** install Foundry, clean `forge build` and `forge test` (and `forge test --isolate --match-path test/Launch.t.sol`), read the contracts for errors, run Slither if you can. Fix anything real, commit, and if the commit changes, re-run import + check and update `baseCommit` in `plea/job-v10-launch.json`. Don't change agreed numbers without asking me.
2. **Give me the job to submit** on the IMD launch form (it has "Start from: My GitHub repository"): the plain-English description for the text box, the repository URL to paste (commit URL `https://github.com/khaed1/plea/commit/<sha>`, then READ), "With a token" off, Owner, **Chain = Sepolia** (the form defaults to mainnet). Tell me what plan to expect before paying (starts "Audit your contracts as they are", ends "Deploy on Sepolia").
3. **After I submit and give you the job id:** create an hourly check-in routine for it. On go-live: ping me, record addresses in HANDOFF, mine the salt (`script/MineSalt.s.sol`, env LAUNCH, POOL_MANAGER, IMD, STACKER, SEASONS, CREDIT_GAS), `deployHook` from the test wallet, verify (flag bits, 90/10 mint), ping again. If it parks or blocks: explain plainly, propose a fix, ping me.
4. Then: seed (owner any time, anyone from START), live test, site job, hackathon entry (`plea/hackathon-submission.md`).

## Files to read
- `HANDOFF.md` (last sections first), `plea/job-v10-launch.json` (the launch request), `plea/dev-feedback.md` (items 1–10 for the IMD dev), `plea/v4-plan.md` (v4's 14 fixes, mostly in v10), `imd-acc/README.md`, `plea/hackathon-submission.md`.
- Code: `khaed1/plea` (README explains the contracts); v4 for reference https://github.com/identity-md-launches/launch-1226-build-plea-v4-sepolia ; v2 https://github.com/identity-md-launches/launch-1148-build-plea-sepolia-test .
- IMD: docs https://imd.fun/docs/llms.txt · API https://api.imd.fun

## Useful facts
- Sepolia Intake `0x1397434cd35e8a9c8ac312a61d3a285eb31dea56` (gives callbacks 1M gas; mainnet 200k); test IMD for the oracle fee `0x44a1cd38474fb1748400e7deb5f8d786cce3f89a` (anyone can `mint`). Results: `GET /intake/11155111/{tx}` → oracle request → `GET /oracle/requests/{id}`.
- Sepolia RPC `https://ethereum-sepolia-rpc.publicnode.com`; Ethereum logs `https://eth.drpc.org`.
- Foundry: `foundryup` is blocked; download `foundry_v1.8.3_linux_amd64.tar.gz` from the GitHub release into `~/.foundry/bin`. In forge tests use `vm.getBlockTimestamp()`, not `block.timestamp` (via_ir caches it).
- The anvil test key `0x7099…79C8` has an EIP-7702 delegation on Sepolia (our signature check handles it).

## Rules
- **Explain simply.** When I need to choose, recommend one option.
- **Don't change agreed numbers** (fees, caps, timings, quorum 17, dead-man 33h, expiry 20 min, season numbers) without asking me.
- **Keys:** the Sepolia test wallet `0x4b91…6821` has its key in env `TESTNET_KEY`. Never print or commit it; never ask me for a mainnet key.
- **`khaed1/plea` is public:** only code, tests and the README there; no notes, keys or HANDOFF.
- **PondPad** (branch `claude/bold-gauss-qhlw86`) is read-only. Never commit its code.
