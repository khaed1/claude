Pick up PLEA from khaed1/claude branch claude/adoring-goodall-pn3jyz. Read this prompt first. Then read HANDOFF.md from "New session: round 7 reports, run-8 pin, run-7 check-in (2026-10-16 05:48 UTC →)" to the end, and NEXT_SESSION.md (the agreed numbers, rules and versions).

Rules: agreed numbers in NEXT_SESSION never change without asking. Never ask for a mainnet key. Submit or pay IMD jobs (and One Dollar Audit jobs), and send anything from wallet A (key in env PONDPAD_TESTNET_KEY, never printed or committed), only with my go-ahead. Never the word mainnet or chain id 1 in a Sepolia job text. Explain simply; when I must choose, recommend one option. Reports and reviews I ask for go in chat; save them to a repo only if I ask. Keep HANDOFF.md, NEXT_SESSION.md and plea/hackathon-submission.md current and push after each step. Work only on branch claude/adoring-goodall-pn3jyz in the notes repo (fetch + merge before pushing; never rebase or force-push). In khaed1/plea, change `next`, then merge it into `main` and `mainnet`; `light-profile` stays as it is (it was merged into all three on 2026-10-17); never touch the pinned `testnet8` @ dc3826b and `testnet8.5` @ af57f6d. imd/acc (khaed1/imd-acc) is read only. Verify every audit finding against the code (and on chain or with an uncommitted scratch test when needed) before telling me, and record or fix only what I agree.

Where we stopped (Sun 2026-10-18 ~07:50 UTC):
- **Done last session** (details in HANDOFF):
  - One Dollar Audit 1016 and 1018 recorded (ODA-1016-1..3, ODA-1018-1..12, no code needed). All five One Dollar Audit jobs are finished.
  - The owner fee is 1% (2.25% in all) on next, main, mainnet and light-profile.
  - light-profile is merged into next, main and mainnet.
  - The wall guard is 700 ticks a day (~7.25%), a fixed constant with no owner setting.
  - The keeper's rebalance rules are written (NEXT_SESSION task 3).
  - IMD's new Indexer job is reviewed: an Indexer job comes first, then the site job (NEXT_SESSION task 4).
  - The hackathon entries are written (plea/hackathon-submission.md): PLEA 992 characters and imd/acc 936, both with a payout line. I submit them myself on imdradar.site/hackathon (deadline likely Mon 2026-10-19 00:00 UTC). Still open: my personal X handle and the real payout wallets.
- **khaed1/plea:**
  - `next` @ 0c891ae, `main` @ 825d1a5, `mainnet` @ bcecb90; 852/852 in 91 suites with both forks on each.
  - `light-profile` @ 180b13b.
  - PleaHook is 24,402 B.
- **Run 8.5** (launch #1981, testnet8.5 @ af57f6d) is live on Sepolia and **not seeded**.
  - IMD answers oracle requests on chains 4663 and 1 only (checked 07:44 UTC).
  - Anyone may seed from START, Sun 2026-10-18 15:00 UTC.
- **Three copies of PLEA on Ethereum mainnet:** launches #1609, #1728 and #2090. They are plain ERC-20s, all paid by 0xee2aaa315cf7ed169f93148d30d24af9318dbb66, and not ours. Ignore them, but put the official addresses on every link at the real launch.
- **Wallet A** (0x4b91…6821):
  - Sepolia: 7.80 ETH, nonce 271.
  - Ethereum: 0.80 IMD, 0.00041 ETH, nonce 43.
  - Base: 0.111418 USDC, 0.00035 ETH.

Watches still running from the last session. They are scheduled tasks bound to that session, so they fire there, not in yours:
- `trig_012vCiEQSFZLBbYzpF61MbKw` "IMD Sepolia oracle check": every 6 h at :13 UTC.
- `trig_01VeoAQiWo34BqG9xSxZTKGt` "Run 8.5: anyone may seed from 15:00": once, Sun 2026-10-18 14:30 UTC.

Your tasks, in order:
1. **Move the watches into your session.** Delete the two above if they still exist, then create your own:
   - A check of `onchain.chains` in https://api.imd.fun/requests/capabilities every 6 h. Tell me the moment 11155111 appears; otherwise one line only.
   - If it is still before Sun 14:30 UTC, a send_later at 14:30 UTC reminding me that anyone may seed run 8.5 from 15:00 UTC, and whether IMD answers Sepolia yet.
2. **Hackathon:** if I ask, help me finish the two entries (handles, payout wallets, at most 1,000 characters each).
3. **When IMD answers Sepolia requests again, and with my go-ahead:**
   - Seed run 8.5 from wallet A (`PleaLaunch` 0x88a2d29c6ce265e1990252b33c60753d4018ad0f `seed()`).
   - Do the owner's 2 IMD opening buy.
   - Run the live test with verdicts: letters and pleas, approval → sale, denial → appeal, objection → ruling, `record`, and a season close. Follow run 7's procedure in HANDOFF; the scratchpad helpers are gone, so write new ones.
   - If someone else seeds first, the 90-minute window and the 33-hour dead-man start without us: tell me at once.
4. **Later, with me, in order:**
   - The mainnet START and a fresh owner wallet (mine to choose); then re-pin plea/job-mainnet-launch.json to the mainnet commit and run a free check.
   - The keeper bot: deliveries, `Seasons.record`, and the rebalance rules in NEXT_SESSION task 3.
   - The IMD Indexer job, then the site job (label `plea` → plea.sites.imd.fun).
   - The promo video, after the site.

Setup:
- Foundry 1.8.3 in /root/.local/bin (install it from the release tarball if missing).
- Attach khaed1/plea with add_repo (push access). Clone it with all heads into /home/user/plea, with worktrees for main and mainnet.
- The suite: `bash plea/tools/run_suite.sh <repo> <logdir>`. It runs test/full with FOUNDRY_PROFILE=full, lists any group without a result and exits 1 if there is one.
- Node 22 for the x402 script, only if I ask for a One Dollar Audit job: `npm install --prefix <dir> viem @x402/core @x402/evm @x402/fetch`, then run it with `NODE_PATH=<dir>/node_modules`.
