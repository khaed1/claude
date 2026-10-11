Repos: `khaed1/claude` (notes, prompts, HANDOFF; work and push only on branch **`claude/adoring-goodall-pn3jyz`**), `khaed1/plea` (public, PLEA code; `main` = the code submitted for Sepolia, branch `mainnet` = next-version work) and `khaed1/plea-site` (public, empty; for GitHub Pages hosting of the PLEA site). If a repo isn't in your session, attach it with `add_repo` (push access). The IMD-delivered code of the live launch is public at https://github.com/identity-md-launches/launch-1242-launch-plea-sepolia-foundry (commit `7d247e8a`).

You're picking up **PLEA** on the IMD swarm (imd.fun). **imd/acc** (below) is now handled by a separate session on my other account (its repository and prompt: `khaed1/imd-acc`, `NEXT_SESSION.md`): use its live contracts, but don't change imd/acc files or jobs. **HANDOFF.md is the source of truth**: read its last sections first, from "PLEA v10 LIVE on Sepolia" down to "Intake v2". Sections about moods, eras, ransom and relics are superseded.

## The two projects in brief
- **imd/acc (other session):** trading cashback in staked IMD. A shared, ownerless `Stacker.credit(trader, imdAmount)` deposits IMD into the sIMD staking vault in the trader's name; projects fund the 0.5% from fees they already charge, so traders pay nothing extra. **Live on Sepolia** (launch #1129: TestIMD `0x2b69099e59b05901faa1dd164fabf098bf831e82` with `faucet()`, TestSIMD `0xf9e2eec3b610ec6781f7438ac5fb4bc049d81cc1`, Stacker `0x293c7134ab8f6bf1d8ff44ed806575f8f1baf477`). PLEA is its first integration and stacks cashback in every swap. Planned v2: ETH-fee projects batched through POOL4 (`flush()`). Spec: `khaed1/imd-acc` (`README.md`, `docs/design.md`).
- **PLEA (v10):** a sell-gated meme token on Uniswap v4, inspired by TokenWorks' CabalCoin. Buying is open; **selling needs a plea scored 0–45 by "the Cabal"** (IMD oracle panel, 30 judges, quorum 17); pass if score ≥ need = 70 − on-chain fact score (0–55). One hook, a fork of POOL4's CappedBurnHook (IMD side, only LP, liquidity locked forever, trims burn, IMD buy wall). Fees 1.75%: 0.5% sIMD cashback, 0.5% owner, 0.25% season prize pot, 0.25% liquidity, 0.25% PLEA burn. The Cabal dies for good after 33h without a signed verdict, then trading is free forever. **Seasons:** back to back from launch (5h on Sepolia, 15 days on mainnet), each wallet's best 3 scores count, top 10 with ≥60 points paid 25/18/14/11/9/7/6/4/3/3 %, unpaid shares roll over, top 5 pleas become on-chain Laureate NFTs, display names.

## Where we stopped (2026-10-11 ~04:15 UTC)
- **PLEA v10 live on Sepolia, launch #1242** (job `3593725e`, all admission checks passed). PLEA `0x9b8d9aae44e81b1205e227911db279bde6edead9`, CabalGate `0x758b8300c62563591950f32717be44a5140a20f9`, Seasons `0x178481ac37e68a5c6ef95336db4616ba0169a17a`, Laureates `0xd2311b6d4c42a6dc3900a0a74a364b2775dd61c1`, PleaDistributor `0xabaecde2b71f0e3fa5d1b70f9a2bb9c24d6f3a7f`, PleaLaunch `0x29aa568f93d7d4d8255ba54b6201bbe1abd01ab4`, **PleaHook `0x3d4CcAc329010b8beA3b14498d9a45EAB00c68Cc`** (deployed by us, verified), seeded 2026-10-10 17:02 UTC.
- **IMD's adapter changed our code** (delivered repo above is the truth): lapsed approvals start the 4h cooldown; every buy needs a recipient in hookData (even after death); each season pays its own fees + rollover; oracle request ids consumed once. Details in HANDOFF.
- **Live test done:** buys with cashback, denied plea + appeal, a no-verdict plea (judges zero any line that tells them how to score), approved pleas #4 and #5 (score 38) with sells, `record`, `rebalance`, and the real season 0 closed with Laureate #1 minted. A full Seasons lifecycle fork test passed (`plea/tests/ForkSeasons.t.sol`).
- **Cabal clock:** last verdict 2026-10-11 03:54 UTC → **dies Mon 2026-10-12 12:54 UTC** unless another plea gets a verdict (approved or denied). Keep it alive with a plea before then if the test should continue.
- **Site:** job `d456a90e-3839-4e7d-9942-4b2b25409ec7` (continuation of blocked `11d73554`) is building; no IMD hosting on this one. When it delivers: review the code against the live contracts, make it work under `/plea-site/`, push the static build to `khaed1/plea-site` main (+ `.nojekyll`), and ask me to enable GitHub Pages (Settings → Pages → main / root → https://khaed1.github.io/plea-site/). For the official IMD link afterwards: a small `job.continue` with `ipfs: "plea-test"` and **no hosting words in the text** (our earlier block came from the prompt asking the agent to host). Prompt: `plea/job-v10-site.md`.
- **Gas on Sepolia is much higher now** (deployHook 35.3M, buy 1.5–2.6M, plea ~2.5M, sell 0.75–1.25M, approvals 100–130k): always use estimate ×1.3.
- **Next version** (branch `mainnet` in khaed1/plea, decided): 25-day cap decay + POOL4-style wall placement guard (written, 115 tests pass), then rebase onto the delivered code, switch to **Intake v2 `0xa43e6f75ee006411f79ac1c84120606c2330de82`** with `requestWithFailure` + an `onPleaFailure` that clears our own pending plea (never moves value), mainnet addresses, then import + `/requests/check`.
- **Routines:** the hourly site check-in `trig_01UuuHnB3PzF7vgo1rsEoQ3b` fires into the previous session. Delete it (`delete_trigger`) and create your own hourly check-in for job `d456a90e` (same steps as in "Your tasks" 1).

## Your tasks, in order
1. **Site job `d456a90e`** (at 04:20 UTC `build_website` was still working, `design_critic` waiting). Check `GET https://api.imd.fun/jobs/d456a90e-3839-4e7d-9942-4b2b25409ec7`. When it delivers:
   - clone the delivered repo at the delivery commit;
   - review the site against the live contracts: addresses, pool key, buys always pass hookData, swap gas estimate ×1.3 (floor 2.6M), Seasons `record`/`closeSeason`/`flushToWall`, `setName`, no killCabal/claim buttons;
   - make it work under `/plea-site/` (relative base or `/plea-site/`, hash routing or a 404.html), rebuild if needed;
   - push the static build to `khaed1/plea-site` main with `.nojekyll`;
   - test it in Chromium (Playwright, `/opt/pw-browsers`) at 360 and 1280 px against the live contracts;
   - tell me to enable Pages and give me a short ranked list of issues.
   If it blocks, explain plainly and propose a fix (pay nothing).
2. **Start the next version on branch `mainnet`** in `khaed1/plea` (already has the 25-day cap decay + wall guard, commit `7ab3d6c`, 115 tests pass):
   - bring in the delivered launch-1242 code (`7d247e8a`) so the adapter's changes are kept, then re-apply the decay and the guard; all tests must pass;
   - switch to **Intake v2** `0xa43e6f75ee006411f79ac1c84120606c2330de82` with `requestWithFailure` and an `onPleaFailure(bytes32 requestId, uint8 status, bytes32 reason, uint16 agreed, uint16 answered, bytes signature)` that only clears our own still-pending plea when `msg.sender == intake` (never moves value; keep the 20-minute `_stale` fallback); add tests;
   - mainnet values for `launch.json`: real IMD `0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7`, the oracle fee in IMD, the mainnet Stacker (to come from the imd/acc session, leave a clear placeholder), 15-day seasons, 33h dead-man; ask me before choosing START or the owner;
   - then Slither, `POST /requests/import` + `/requests/check`, and show me the plan before anything is paid.
3. **Keep the Cabal alive** if the live test should continue: a plea from the test wallet before the death time (any verdict resets the clock; never write lines that tell the judges how to score).
4. Fill `plea/hackathon-submission.md` (`{…}` placeholders) once the site is up.

## Files to read
- `HANDOFF.md` (last sections first), `plea/job-v10-launch.json`, `plea/job-v10-site.md`, `plea/dev-feedback.md` (items for the IMD dev; 11 is resolved), `plea/hackathon-submission.md` (v10 draft, `{…}` to fill), `plea/tests/ForkSeasons.t.sol` (runs inside the delivered launch repo), `khaed1/imd-acc` `README.md` (for context only).
- Code: `khaed1/plea` README (contracts, fees, fact score, seasons), `src/` and `test/`; the delivered launch repo above for what is actually deployed.
- IMD: docs https://imd.fun/docs/llms.txt (contracts, Intake v2, "When no answer comes") · API https://api.imd.fun · results `GET /intake/11155111/{tx}` → `GET /oracle/requests/{id}` · my orders `GET /requests/paid-by/0xf8ad3f88b0e0d177aa8c5e6be1e13410fd41cdc7`.

## Useful facts
- Sepolia RPC `https://ethereum-sepolia-rpc.publicnode.com`; Uniswap v4 PoolManager `0xE03A1074c86CFeDd5C142C4F04F1a1536e203543`, PoolSwapTest `0x9b6b46e2c869aa39918db7f52f5557fe577b6eee`; pool key (TestIMD currency0, PLEA currency1, fee 0, spacing 60, hook). Oracle-fee token `0x44a1cd38474fb1748400e7deb5f8d786cce3f89a` (open `mint`).
- Foundry: download `foundry_v1.8.3_linux_amd64.tar.gz` from the GitHub release into `~/.foundry/bin` (`foundryup` is blocked). Keep `[lint] lint_on_build = false`. In tests use `vm.getBlockTimestamp()` / `vm.getBlockNumber()` (via_ir caches them).
- Test wallet `0x4b91078b2374c956a65f7af0999cae0a935e6821` (owner): key in env `TESTNET_KEY` (~0.05 Sepolia ETH). Throwaway wallet B `0x0C85…7b7b` had a session-only key, now lost; make a new one if you need a second wallet.

## Rules
- **Explain simply.** When I need to choose, recommend one option.
- **Don't change agreed numbers** (fees, caps, timings, quorum 17, dead-man 33h, expiry 20 min, season numbers, 25-day decay) without asking me.
- **Keys:** never print or commit `TESTNET_KEY`; never ask me for a mainnet key.
- **`khaed1/plea` is public:** only code, tests and the README there; no notes, keys or HANDOFF.
- **imd/acc** files and jobs belong to the other session; read only.
- **PondPad** (branch `claude/bold-gauss-qhlw86`) is read-only. Never commit its code.
