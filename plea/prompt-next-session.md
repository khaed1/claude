# Prompt for the next PLEA session (2026-10-12 13:10 UTC)

You're picking up **PLEA**, a sell-gated meme token launched through the IMD swarm (imd.fun), and its neighbour **imd/acc** (read only). Work in `khaed1/claude` on branch **`claude/adoring-goodall-pn3jyz`** only (attach repos with `add_repo`, push access; `git fetch` and merge before pushing, never rebase or force-push: another session may push to this branch). **`HANDOFF.md` is the source of truth; `NEXT_SESSION.md` is the short version.** Explain simply; when I have to choose, recommend one option.

## The two projects in a paragraph each
- **PLEA** (`khaed1/plea`, public, code + README only): buying is open on a Uniswap v4 pool; **selling needs a plea**: the holder writes up to 280 bytes, "the Cabal" (an IMD oracle panel, 30 judges, quorum 17) scores it 0-45, and it passes if score ≥ 70 − an on-chain fact score (holding time, P&L, share sold, price trend). Approved → sell within 7 minutes; denied → one appeal within 4 hours; 4-hour cooldowns. The Cabal dies after 33 hours without a signed verdict, then trading is free forever. One hook (fork of POOL4's CappedBurnHook) takes 1.75% per trade: 0.5% cashback staked as sIMD through imd/acc's Stacker, 0.5% owner, 0.25% season prize pot, 0.25% locked liquidity, 0.25% PLEA burn. Seasons (5 h on Sepolia, 15 days on mainnet): best three scores count, top 10 with ≥ 60 points share the IMD pot 25/18/14/11/9/7/6/4/3/3 and, in the first six seasons, 5,000,000 PLEA each; the owner cannot play. **Run 3 adds letters:** anyone pleads by sending a text transaction to the ownerless Letterbox (Etherscan's IDM page on mainnet, or `letter(text)` on its Write Contract tab); a letter pleads 20% of the balance, pays the oracle fee and a 0.25 IMD runner tip by selling the writer's PLEA in the same transaction, and anyone delivers an approved plea for the tip; 0.35 IMD of every delivered sale goes to the season pot (only when a sale happens).
- **imd/acc** (`khaed1/imd-acc`, belongs to another session on my other account: read `README.md`, `docs/`, `NEXT_SESSION.md`, `jobs/`; **never change its files or jobs**): trading cashback in staked IMD. Projects pay 0.25-1% of each trade out of their fees through the ownerless `Stacker.credit(trader, imd)`, which stakes it as sIMD for the trader; listing is decided by an ownerless ProjectRegistry (oracle panel of 15, 11 must agree). PLEA credits through imd/acc's Sepolia Stacker `0x0457276d7b036818b3eddc1a4a3fceda61e9314d`. The imd/acc session uses the **same test wallet A** as PLEA: check `cast nonce` latest = pending before sending anything.

## Where we are (read these first, in this order)
1. `NEXT_SESSION.md` (all of it), then `HANDOFF.md` from "Run 2 live test" to the end.
2. `plea/audit-run3-0325c53.md` (the independent pre-audit of run 3 and its addendum: what shipped), `plea/letters-spec.md`, `plea/cabal-rules-review.md`, `plea/job-testnet3-form.md` (the exact text I paste into the imd.fun form), `plea/site-next-fixes.md`, `plea/hackathon-submission.md`.
3. Code: `khaed1/plea` branch **`testnet3` @ `f57da56f6c6f76e64902b3363edb3dd2a372b75f`** (run 3, ready to submit): `README.md`, `src/Letterbox.sol`, `src/CabalGate.sol`, `src/PleaHook.sol`, `src/Seasons.sol`, `src/PLEA.sol`, `src/PleaLaunch.sol`, `launch.json`, `test/Letterbox.t.sol`, `test/AuditRun3.t.sol`, `test/fork/ForkTestnet.t.sol`. Branch **`mainnet` @ `8a2019db4870c262707cd34a9e3a211170588c5e`** is the same code with chain-1 settings (draft: Stacker, START and owner still open). Run 2 (live on Sepolia, launch #1311) is IMD's delivered repo `identity-md-launches/launch-1311-launch-plea-test-run` @ `fb8c0ae5`.
4. IMD: docs https://imd.fun/docs/llms.txt, API https://api.imd.fun (`/jobs/{id}`, `/jobs/{id}/submissions`, `/launches/{id}`, free `/requests/import` and `/requests/check`).

## State at hand-over
- **Run 3 is ready and not submitted**: `testnet3` @ `f57da56`, job text `plea/job-testnet3-form.md`, `/requests/check` clean. I submit it myself through the imd.fun form; never pay or submit a job for me.
- Run 2 is still live on Sepolia (addresses in NEXT_SESSION): its Cabal dies Tue 2026-10-13 19:57 UTC without another verdict; the other session closes season 3 at 16:52 UTC today.
- The site (https://plea-make-your-case-0c37.sites.imd.fun/) is run 2's: none of run 3's changes (letters, auto-sell fee, 20%, 50%) are on it yet.

## What to do next
1. After I submit run 3: follow the job, read the judge's findings, diff the delivered `src/` against `testnet3`, build and test the delivered code (Foundry 1.8.3; first build ~9 min). With my go-ahead: mine the hook salt, `deployHook`, `deployLetterbox` (`script/DeployLetterbox.s.sol`, anyone), `seed`, then the live test with fresh throwaway wallets as players (buys, a raw-calldata letter, `deliver` by another wallet, `SELL`, `APPEAL`, `NAME`, `settle` after a denial and after no verdict, `status` / `leaderboard`, a site plea, the 0.35 fee reaching Seasons). Port any fix IMD makes to `mainnet`.
2. Then the site job for run 3 (letters page, auto-sell box with the fee shown, status page, `plea/site-next-fixes.md`); I submit it.
3. Mainnet: open items are imd/acc's mainnet Stacker, START and a fresh owner wallet; the gas cap is settled (launch ≈ 12.7M through IMD's real factory, ≤ 15.5M with headroom).
4. Keep `HANDOFF.md`, `NEXT_SESSION.md` and `plea/hackathon-submission.md` current.

## Rules
- Agreed numbers are in NEXT_SESSION ("Agreed numbers"): don't change them without asking.
- Keys: the test wallet's key is in env `PONDPAD_TESTNET_KEY`; never print or commit it; never ask for a mainnet key.
- `khaed1/plea` is public: only code, tests and README there. imd/acc files and jobs are read only.
