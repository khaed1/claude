Repo `khaed1/claude`, branch **`claude/adoring-goodall-pn3jyz`**. Work and push only on this branch.

You're picking up two projects I'm building on the IMD swarm (imd.fun). The previous session ran out of context. **HANDOFF.md is the source of truth** (addresses, tx hashes, decisions, bugs, test results); read it first, then the files below as needed.

## The two projects in brief
- **imd/acc:** 0.5% trading cashback, paid to traders as staked IMD (sIMD) out of a project's existing fees.
  - A shared, ownerless `Stacker.credit(trader, imdAmount)` deposits into the sIMD vault in the trader's name.
  - Points are counted only for listed projects (`projects.json`), from their listing block onward.
  - **Live on Sepolia** (TestIMD, TestSIMD, Stacker, test site) and tested end to end.
- **PLEA:** a sell-gated meme token, a relaunch of TokenWorks' CabalCoin. Buying is open; **selling needs a plea approved by "the Cabal"**, an IMD oracle panel of 30 judges.
  - **Hook:** one Uniswap v4 hook (a POOL4 CappedBurnHook fork, IMD side). Fees: 0.5% imd/acc cashback, 0.5% owner, 0.25% liquidity, plus a 0.25% PLEA burn.
  - **v2 is live on Sepolia** (launch #1148) and was tested; its problems are listed in `plea/v4-plan.md`.
  - **v4, meant as the last testnet version, is being built now.** v4 rules:
    - quorum 17/30; a 7-min sell window; a 4h denial wait with one appeal within it
    - pending pleas expire after 20 min, or as soon as the Intake marks the request completed with no verdict
    - a 33h dead-man switch
    - fees paid in the same swap, and cashback that stacks with normal wallet gas
    - the Gate pays the Sepolia Intake itself and gets verdicts through the callback; signer and Intake are immutable
    - the hook salt is mined off-chain and the hook is deployed after launch (`deployHook`)
    - trading opens via `seed()`: the owner any time, anyone after START (1791689340 = 2026-10-11 03:29 UTC)

## Files to read
- `HANDOFF.md`: everything. The newest sections are at the end. **Start here.**
- `plea/v4-plan.md`: the 14 v2 problems, the decisions, the calibration results (12 pleas through the Sepolia oracle) and the changes after review.
- `plea/job-sepolia.md`: the **v4 prompt as submitted** (except the BUILD line, fixed afterwards; see "Where we stopped").
- `plea/job-v4-site.md`: the **v4 site prompt**, ready. Submit it as a `job.continue` once the v4 contracts are live (wordmark logo, bordered grid Wall, a single Connect button, Impeccable rules plus `npx impeccable detect`, all v2 site fixes).
- `plea/dev-feedback.md`: our message to the IMD dev (an `onFailure` hook with an `OracleFailure` struct, and more).
- `plea/brainstorm-seasons.md`: seasons ideas for later (ransom revival plus tradable NFTs). Not in v4.
- `plea/launch-spec.md`: the original full spec; later sections override earlier ones.
- `imd-acc/README.md` and `imd-acc/job-*.md`: the imd/acc spec and prompts.
- **Code:**
  - PLEA v2: https://github.com/identity-md-launches/launch-1148-build-plea-sepolia-test (contracts `33c75a5c`, site `1ef27b46`)
  - imd/acc: https://github.com/identity-md-launches/launch-1129-build-imd-acc-sepolia-test
- **IMD:** docs https://imd.fun/docs/ (see "Pay on chain" for the Intake and callback) · API https://api.imd.fun

## Where we stopped (2026-10-10 ~06:00 UTC)
- **The PLEA v4 job is running:** `d1ff706d-208e-4e98-98ca-b229bc7cd0e6`. Check it with `GET https://api.imd.fun/jobs/d1ff706d-208e-4e98-98ca-b229bc7cd0e6`.
  - The build is on attempt 3 of 3.
  - Attempt 2 failed because tests called `vm.getCode` for PoolManager, which IMD's verifier never compiled. The likely cause is our prompt's "no via_ir for v4-core" line; v2 passed with via_ir, 200 runs and `new PoolManager`.
  - `plea/job-sepolia.md` now has the corrected BUILD line. If the job blocks, resubmit with it, after moving START so it's still in the future.
- **An hourly check-in routine is running:** `trig_0133Hp825v6D4v6vMkR8ApFY` (at :39 each hour). It reports the job state. When the job goes live it records the addresses, mines the salt and calls `deployHook` from the test wallet, then deletes itself. If you take over that work yourself, delete or update the routine.
- **After v4 is live:**
  1. deployHook and verify it (flag bits, init, 90/10 mint).
  2. I `seed()`, or it opens after START.
  3. I submit `plea/job-v4-site.md`.
  4. Test the site the way v2's was tested: anvil fork of Sepolia, Playwright, an injected wallet with MetaMask's 1.5× gas buffer, warping time. Then test live.
  5. Add PLEA's hook to imd/acc's `projects.json`.
- **Waiting on the IMD dev:** a reply to `plea/dev-feedback.md`.

## Useful facts
- **Sepolia oracle tests are free:**
  - Intake `0x1397434cd35e8a9c8ac312a61d3a285eb31dea56`; test IMD `0x44a1cd38474fb1748400e7deb5f8d786cce3f89a` (anyone can mint).
  - Requests paid on Sepolia **must name a testnet `consumer`** or they're refused `testnet_only`.
  - `POST /requests/check` is the free validation. `/requests/quote` now needs a request token.
- **Foundry:** `foundryup` is blocked; download `foundry_v1.8.3_linux_amd64.tar.gz` from the GitHub release.
- **Prompt size:** measure with `POST /requests/check` (`action: launch.open`, `input.objective`). The limit is about 7,280 characters; `objective_too_large` means it's over. The v4 prompt is 7,251.

## Rules
- **Explain simply.** When I need to choose, recommend one option.
- **Don't change agreed numbers** (fees, caps, timings, supply split, quorum 17, dead-man 33h, expiry 20 min) without asking me.
- **Keys:** the Sepolia test wallet `0x4b91…6821` (testnet only) has its key in env `TESTNET_KEY`. Never print or commit it, and never ask me to paste a mainnet key.
- **PondPad** (branch `claude/bold-gauss-qhlw86`) is read-only. Never commit its code.
