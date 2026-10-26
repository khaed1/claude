Pick up PLEA from khaed1/claude branch claude/adoring-goodall-pn3jyz. Read this prompt first. Then read HANDOFF.md from "New session: the run 9 live test (2026-10-21 13:04 UTC →)" to the end (the "Site design system session" section at the end belongs to another session), and NEXT_SESSION.md (the agreed numbers, rules and versions).

Rules: agreed numbers in NEXT_SESSION never change without asking. Never ask for a mainnet key. Submit or pay IMD jobs (and One Dollar Audit jobs), and send anything from wallet A (key in env PONDPAD_TESTNET_KEY, never printed or committed), only with my go-ahead. Never the word mainnet or chain id 1 in a Sepolia job text. Explain simply; when I must choose, recommend one option. Reports and reviews I ask for go in chat; save them to a repo only if I ask. Keep HANDOFF.md, NEXT_SESSION.md and plea/hackathon-submission.md current and push after each step. Work only on branch claude/adoring-goodall-pn3jyz in the notes repo (fetch + merge before pushing; never rebase or force-push). In khaed1/plea, change `next`, then merge it into `main` and `mainnet`; `light-profile` stays as it is; never touch the pinned `testnet8` @ dc3826b, `testnet8.5` @ af57f6d and `testnet9` @ 241c05e. imd/acc (khaed1/imd-acc) is read only. Verify every audit finding against the code (and on chain or with an uncommitted scratch test when needed) before telling me, and record or fix only what I agree.

**No go-ahead is open.** Run 9 is finished. Anything new (IMD jobs, Ethereum, Base or Sepolia transactions, mainnet) needs my go-ahead.

Where we stopped (Mon 2026-10-26 ~10:30 UTC):
- **Run 9 is finished** (launch #2234, `testnet9` @ 241c05e, Sepolia, imdTEST as pool token and oracle fee; records in `plea/live-run9/`, full story in HANDOFF):
  - Seeded Wed 2026-10-21 13:09 UTC; 25 pleas and letters and 3 objections judged by IMD's real panels (verdicts in 2–4 minutes); the Cabal died Mon 2026-10-26 07:28:12 UTC. No outside wallet ever touched it.
  - Proven live: buys and the exact fee split, cashback in plain imdTEST, the sell refusals, the seat mint, pleas, appeals, denials, four approvals sold inside the 7-minute window, raw, typed and `APPEAL` letters, settles, `expire`, Objection! sustained (twice) and overruled (once) with stakes settled both ways, the seat's 1.2× points, 22 seasons closed with rollover and bonus burns, the first live `PrizePaid` (p1, 79 points, rank 1), `NAME`, the wall (`rebalance`), and the whole end phase.
  - Not proven live on run 9 (live on runs 3–4 and on the fork): an approved letter delivered by a runner, a `SELL` letter, an approved site auto-sell plea, `onPleaFailure` (IMD never reported a failure; it stalled instead).
  - **Money:** of the dev's 50 imdTEST, 35.964774 are back in wallet A, 14.0 went to IMD as oracle fees (28 questions), and 0.035226 is dust left in the pool's last wall (below the 1-imdTEST rebalance threshold; nobody can withdraw pool liquidity). The test wallets' ETH was swept back to wallet A. Send the imdTEST nowhere without my go-ahead.
  - **Scores by holding time** (hand pleas on bought PLEA): day 0 (need 37) 0 of 5; day 1 (need 35) 1 of 6; day 2 (need 35) 0 of 3; day 3 (need 33) 3 of 4; letters 0 of 5. Good pleas score 32–35 at any age. **I decided to keep the pass mark 71 and the hold ladder 0/2/4/7 as they are.**
- **IMD:** imd.fun has been on a Namecheap `clientHold` since Fri 2026-10-23 05:45 UTC (NXDOMAIN for every imd.fun name, the run 9 site included). IMD's API answers at `https://api-imd.up.railway.app` (explorer `https://imd-explorer.up.railway.app`), and its oracle delivers on chain again. Check first whether the hold is lifted.
- **khaed1/plea:** `next` @ 3e64f29, `main` @ 16bf1f0 (tree = `next`), `mainnet` @ e61a832; `light-profile` @ 180b13b. Run 9's eight contracts are verified on Sourcify (match, creation and runtime).
- **Wallet A** (`0x4b91078b2374c956A65F7Af0999CaE0a935E6821`):
  - Sepolia: 7.795 ETH, 35.964774 imdTEST, nonce 302.
  - Ethereum: 0.80 IMD, 0.0021 ETH, nonce 97.
  - Other sessions (imd/acc, the site design) also use wallet A: check that nonce latest = pending before every send.
- **Nothing is scheduled** (no check-ins, no watchers).
- **Learned this week, for mainnet** (details in HANDOFF):
  - **Uniswap routing:** our hook uses return-delta flags, so the Uniswap app and Trading API route it only after manual allowlisting (form drafted in chat on 2026-10-22; the hook is verified on Sourcify). While the Cabal lives, no router or aggregator can buy PLEA (the hook delivers the PLEA to the buyer, so routers see 0 output; aggregators cannot name the buyer); after the death, the pool routes normally once each aggregator supports the hook (Uniswap form, 0x hook form, KyberSwap and Velora pull requests). No hook change: I agreed buys go through our site.
  - **The mainnet site's buy:** Universal Router `V4_SWAP` with `amountOutMinimum` 0 and hookData `abi.encode(buyer)`, then `BALANCE_CHECK_ERC20` on the buyer's PLEA for slippage protection. Rehearse it on a mainnet fork before the site job.
  - **Honeypot scanners** will likely flag PLEA while the Cabal lives (sell simulations revert): explain it on the site and X, and check the scanners after launch.
  - **The keeper bot** must also `expire` stale pleas and objections 20 minutes after they were sent (a late answer reverts `TooLate`) and `settle` stale letters.
  - **Glamsterdam:** the mainnet Intake's callback gas (200,000) is below our measured first denial and objection ruling; the dev said he will raise it when the time comes.
  - **The mainnet `launch.json` START placeholder** (1793016000 = 2026-10-26 12:00 UTC) has passed: set the real START with me before re-pinning.

Your tasks, in order:
1. **Check the state:** the imd.fun hold, IMD's API, wallet A's nonces. Tell me what changed.
2. **Hackathon:** help if I ask.
3. **Later, with me:**
   - The mainnet START and a fresh owner wallet; then re-pin `plea/job-mainnet-launch.json` (the `mainnet` commit) and run a free check. The launch job only with my go-ahead.
   - The keeper bot (deliveries, `record` after the hold, the `rebalance` rules in NEXT_SESSION task 3, expiring stale pleas and objections, settling stale letters).
   - The IMD Indexer job, then the site job (the design system is in `plea/site-design/`; add the Universal Router buy with the balance check, the honeypot explanation, and a "close (no verdict)" button after 20 minutes).
   - The Uniswap allowlist form (I submit it) and, after the mainnet Cabal dies, the aggregators.
   - The promo video: I do it in another session; the moments list is in HANDOFF.

Report to me in chat after each step, simply. Use send_later check-ins for timed steps instead of waiting.

Setup:
- Foundry 1.8.3 in /root/.local/bin (install it from the release tarball if missing).
- Attach khaed1/plea with add_repo (push access). Clone it with all heads into /home/user/plea, with worktrees for main and mainnet.
- **The live helper:** `ADDRS=plea/live-run9/addresses.json STATE_DIR=<scratch> python3 -I plea/tools/live85.py help`. It now has `derive-players` (keys derived from wallet A's key, never stored), `tree`, `set-root`, `claim`, `sell-free`, `flush`, `collect`, `pool`, `sweep-eth`; amounts are exact decimals. `plea/tools/watch_run9.py` is the read-only outsider watch.
- The suite: `bash plea/tools/run_suite.sh <repo> <logdir>`. It runs test/full with FOUNDRY_PROFILE=full, lists any group without a result and exits 1 if there is one.
- Node 22 for the x402 script, only if I ask for a One Dollar Audit job.
