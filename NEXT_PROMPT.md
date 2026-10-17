Pick up PLEA from khaed1/claude branch claude/adoring-goodall-pn3jyz. Read this prompt first. Then read HANDOFF.md from "New session: round 7 reports, run-8 pin, run-7 check-in (2026-10-16 05:48 UTC →)" to the end, and NEXT_SESSION.md (the agreed numbers, rules and versions).

Rules: agreed numbers in NEXT_SESSION never change without asking. Never ask for a mainnet key. Submit or pay IMD jobs (and One Dollar Audit jobs), and send anything from wallet A (key in env PONDPAD_TESTNET_KEY, never printed or committed), only with my go-ahead. Never the word mainnet or chain id 1 in a Sepolia job text. Explain simply; when I must choose, recommend one option. Keep HANDOFF.md, NEXT_SESSION.md and plea/hackathon-submission.md current and push after each step. Work only on branch claude/adoring-goodall-pn3jyz in the notes repo (fetch + merge before pushing; never rebase or force-push). In khaed1/plea, change `next`, then merge it into `main` and `mainnet` and make the same edit on `light-profile`; never touch the pinned `testnet8` @ dc3826b and `testnet8.5` @ af57f6d. Verify every audit finding against the code (and on chain or with an uncommitted scratch test when needed) before telling me, and record or fix only what I agree.

Where we stopped (Sat 2026-10-17 ~12:10 UTC):
- **Run 7 (launch #1843) is finished.** Its whole life ran on Sepolia: the Cabal died at Sat 01:25:12, then the free market, every season closed, and the pot went to the wall. Report: plea/live-run7/run7-live-test-report.md.
- **Run 8.5 (launch #1981, the final code, testnet8.5 @ af57f6d) is live on Sepolia** with Letterbox 0x993eb617a0d6ad72eD0727aA734c36241bf2448C, Tribunal 0x5b3aB1f9A461995f342e1aD7124B974FD52739F1 and PleaHook 0x48f607FbdBD955e283C57A28E57309b8Ec9028cC deployed. **It is not seeded.**
  - The seed waits until IMD answers Sepolia oracle requests again: GET https://api.imd.fun/requests/capabilities → `onchain.chains` listed only 4663 and 1 at 12:10. I asked IMD's dev (Adam) to turn Sepolia answers back on.
  - Anyone may seed from START, Sun 2026-10-18 15:00 UTC.
- **The run-8 launch job ce8dbe9d stays blocked** (IMD's build check runs out of memory); nothing to do.
- **One Dollar Audit** (onedollaraudit.com: $1 per job on Base, paid by x402 from wallet A; jobs in plea/onedollaraudit/jobs.json, reports and our checks in plea/onedollaraudit/reports/), all on run 8.5's code:
  - 1015 gate: done; ODA-1015-1 accepted, 2 Infos.
  - 1014 hook: done; 10 findings, none reachable; ODA-1014-1..10 recorded; three THREAT-MODEL passages reworded.
  - 1017 Tribunal + Seasons: done; 12 findings; ODA-1017-1..12 recorded; invariant 10 reworded. I skipped the IMD cross-check, because the manifest test covers it.
  - **1016 letters + launch: running since 09:08 UTC.**
  - **1018 hook re-review against the reworded docs: running since 11:38 UTC.**
- khaed1/plea: `next` @ 50e67b0, `main` @ 542a108, `mainnet` @ b53375d, `light-profile` @ eee6831. The full suite passed 847/847 with both forks on each branch at the last code change; only docs changed since.
- Wallet A:
  - Sepolia: nonce 271, 7.80 ETH.
  - Ethereum: 0.80 IMD, 0.00041 ETH, nonce 43.
  - Base: 0.111418 USDC, 0.00035 ETH. No new audit job without my funds and go-ahead.

Your tasks, in order:
1. **Set up the checkers** (the last session stopped its own):
   - The One Dollar Audit watcher: `python3 plea/tools/watch_oda.py 1016,1018` in the background. It exits when a job ends or after about 2 hours; pass its printed STATE back in to re-arm.
   - A safety send_later about 3 hours out for the same two jobs. Read a job any time with `node plea/tools/submit_onedollaraudit.mjs status <id>`, and never re-submit (re-pay) a job to check it.
   - A check of `onchain.chains` in /requests/capabilities a few times a day; tell me the moment 11155111 appears.
   - A send_later for Sun 2026-10-18 ~14:30 UTC to remind me that anyone may seed run 8.5 from 15:00 UTC.
2. **Follow jobs 1016 and 1018 to their reports.**
   - Save each report as plea/onedollaraudit/reports/<id>-<area>.md, with your check appended.
   - Verify every finding against the code: run 8.5 is testnet8.5 @ af57f6d, and the mainnet code is on next and mainnet.
   - Tell me simply, with one recommendation. For 1018, say plainly whether it agrees with the ODA-1014 resolutions.
   - After I agree, record ODA-<job>-<n> rows in audit/FINDINGS.md (and the "One Dollar Audit" row in the rounds table), plus any THREAT-MODEL rewording, on the four branches, then push.
3. **Owner fee 0.75% → 1%** (my decision, 2026-10-17 ~12:05 UTC, Option A): the total trade fee goes from 2.0% to 2.25%. Cashback 0.5%, prize 0.25%, wall 0.25% and the 0.25% PLEA burn stay. This is for mainnet, on next → main, mainnet and light-profile.
   - `src/PleaHook.sol`: `OWNER_BPS` 75 → 100 (`IMD_FEE_BPS` follows, 175 → 200), and the comments. Re-check that `PAYOUT_RESERVE` (2 IMD) still covers the payouts, now 1.75%, of the largest launch-window buy at the mainnet seed: 5M PLEA ≈ 70 IMD → about 1.2 IMD.
   - `src/Letterbox.sol`: `HOOK_SALE_FEE_BPS` 200 → 225, because the delivery floor is 95% after the hook's sale fees; plus its comments. Fix the "0.75%" comment in `src/Seasons.sol`.
   - `launch.json` on each branch: the new Letterbox creation-code hash (PleaLaunch's 12th argument; `test_launchJsonCommitsToThisLetterbox` tells you), and the notes (0.75% → 1%, 2.0% → 2.25%) within the 4,000-byte cap.
   - Tests: update every expectation of the 0.75% share or the 2.0% total (fee splits, fork tests, invariants), and add expectations for 1% and 2.25%.
   - Docs: README (fees, At a glance), audit/THREAT-MODEL.md (the bold agreed numbers and the opening-buy payout figure), OBJECTIONS.md where it states the fee, audit/FINDINGS.md "Changes after …", NEXT_SESSION.md agreed numbers, plea/hackathon-submission.md.
   - PleaHook is 24,402 B (174 under the limit) and must not grow.
   - Run the full suite on each branch with `bash plea/tools/run_suite.sh <repo> <logdir>`; expect 847+ passed and 0 failed. Then merge and push.
4. **When IMD answers Sepolia requests again, and with my go-ahead:** seed run 8.5 from wallet A (`PleaLaunch` 0x88a2d29c6ce265e1990252b33c60753d4018ad0f `seed()`), do the owner's 2 IMD opening buy, then the live test with verdicts: letters and pleas, approval → sale, denial → appeal, objection → ruling, `record`, and a season close. Follow run 7's procedure in HANDOFF; the scratchpad helpers from that session are gone, so write new ones.
5. **Later, with me, in order:**
   - merge light-profile into next, main and mainnet before the mainnet launch job;
   - the mainnet START and a fresh owner wallet (mine to choose);
   - the keeper bot;
   - the site job;
   - the promo video after the site (NEXT_SESSION task 5);
   - the hackathon entry.

Setup:
- Foundry 1.8.3 in /root/.local/bin (install it from the release tarball if missing).
- Attach khaed1/plea with add_repo (push access). Clone it with all heads into /home/user/plea, with worktrees for main, mainnet and light-profile.
- Node 22 for the x402 script: `npm install --prefix <dir> viem @x402/core @x402/evm @x402/fetch`, then run it with `NODE_PATH=<dir>/node_modules`.
