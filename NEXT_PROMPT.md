Pick up PLEA from khaed1/claude branch claude/adoring-goodall-pn3jyz. Read this prompt first. Then read HANDOFF.md from "New session: the run 9 live test (2026-10-21 13:04 UTC →)" to the end (the "Site design system session" section at the end belongs to another session), and NEXT_SESSION.md (the agreed numbers, rules and versions).

Rules: agreed numbers in NEXT_SESSION never change without asking. Never ask for a mainnet key (the owner's or the keeper's). Submit or pay IMD jobs (and One Dollar Audit jobs), and send anything from wallet A (key in env PONDPAD_TESTNET_KEY, never printed or committed), only with my go-ahead. Never the word mainnet or chain id 1 in a Sepolia job text. Explain simply; when I must choose, recommend one option. Reports and reviews I ask for go in chat; save them to a repo only if I ask. Keep HANDOFF.md, NEXT_SESSION.md and plea/hackathon-submission.md current and push after each step. Work only on branch claude/adoring-goodall-pn3jyz in the notes repo (fetch + merge before pushing; never rebase or force-push). In khaed1/plea, change `next`, then merge it into `main` and `mainnet` (chain-1-only settings — launch.json, README settings, `MARKET_CAP_IMD`, LaunchManifest constants — live on `mainnet` only); `light-profile` stays as it is; never touch the pinned `testnet8` @ dc3826b, `testnet8.5` @ af57f6d and `testnet9` @ 241c05e. The keeper bot lives on branch `keeper` (folder `keeper/`) until the mainnet launch job is submitted, then merge it into `next`, `main` and `mainnet`. imd/acc (khaed1/imd-acc) is read only. Verify every audit finding against the code (and on chain or with an uncommitted scratch test when needed) before telling me, and record or fix only what I agree.

**No go-ahead is open.** Anything new (IMD jobs, Ethereum, Base or Sepolia transactions, mainnet) needs my go-ahead.

Where we stopped (Mon 2026-10-26 ~12:25 UTC):
- **Run 9 is finished** (Sepolia, launch #2234; full story and records in HANDOFF and `plea/live-run9/`). Of the 50 imdTEST: 35.964774 back in wallet A, 14.0 to IMD as oracle fees, 0.035226 dust in the pool. I kept the pass mark 71 and the hold ladder 0/2/4/7.
- **IMD is back:** the Namecheap hold on imd.fun was lifted Mon 02:25 UTC (name servers now Cloudflare); `api.imd.fun` and `api-imd.up.railway.app` both answer (version `a375dd80`); Sepolia oracle questions are still sold in imdTEST.
- **Mainnet decisions (2026-10-26):** START = **1795532400 = Tue 2026-11-24 15:00 UTC** (only the time from which anyone may seed; the owner seeds when the site, keeper and imd/acc listing are ready); the opening market cap stays **14,000 IMD** (≈ $60k at IMD $4.29); seasons are 15 days on mainnet (`seed` refuses less on chain 1).
- **khaed1/plea:** `next` @ 1673478 (a Sepolia fork test fix: run 9's dust in the shared PoolManager), `main` @ 4595a33 (tree = `next`), `mainnet` @ c96672f (START set; **852/852 with both forks**), `keeper` @ 08bbe5a, `light-profile` @ 180b13b.
- **Owner wallet: waiting for me.** I create a brand-new wallet (a hardware-wallet account recommended) and send you **only its address**. It is permanent: the hook pays its 1% owner fee to it forever. It also sets the distributor root, applies to imd/acc's mainnet registry `0x7f53…7faa` (0.5 IMD), makes the 2 IMD opening buy and may seed early. Fund it with ~0.02 ETH + 2.5 IMD. Wallet A can send the three permissionless deploys (needs ETH on Ethereum) and pay the 0.5 IMD launch job, with my go-ahead.
- **The keeper bot is built** (`keeper/` on branch `keeper`; Node.js + viem, Telegram alerts, my choices): deliveries in the 7-minute window (0.25 IMD tip), expiries, settles, objection stakes, records after the hold, season closes with unrecorded ids, `flushToWall`, `rebalance` by the agreed rules; every send simulated, sends through Flashbots Protect, dry-run mode. Planner 15/15 unit tests; **rehearsal on an anvil mainnet fork 45/45 checks** (`keeper/rehearsal/run.mjs`, our mainnet build, the real Intake with a test oracle key). Not tested yet: real Telegram sends, the Flashbots relay, the gas-cap wait. Setup guide `keeper/VPS.md`; I install it on my VPS after the launch is live (dry run until trading opens).
- **Wallet A** (`0x4b91078b2374c956A65F7Af0999CaE0a935E6821`): Sepolia 7.795 ETH, 35.964774 imdTEST, nonce 302; Ethereum 0.80 IMD, 0.0021 ETH, nonce 97. Other sessions also use it: check latest = pending before every send.
- **Nothing is scheduled** (no check-ins, no watchers).

Your tasks, in order:
1. **Check the state:** IMD's API, wallet A's nonces, anything new on `khaed1/plea`. Tell me what changed.
2. **When I send the owner address:** put it in the `mainnet` README's Owner row (and launch.json notes if useful), run the suite, then re-pin `plea/job-mainnet-launch.json` to the `mainnet` commit with `owner` = that address. The old objective is from run 4: write a fresh one from `plea/job-testnet9-launch.json`'s (the final code), with mainnet's settings and numbers, under 5,500 characters. Then the free `/requests/check`. The launch job only with my go-ahead (0.5 IMD from wallet A).
3. **Hackathon:** help if I ask.
4. **Later, with me:**
   - The owner steps after the launch (deploys, root, the imd/acc application, seed at the agreed time, the 2 IMD opening buy).
   - The keeper on my VPS (`keeper/VPS.md`); merge `keeper` into next/main/mainnet once the launch job is submitted.
   - The Universal Router buy (`V4_SWAP` with hookData `abi.encode(buyer)`, `amountOutMinimum` 0, then `BALANCE_CHECK_ERC20` on the buyer's PLEA) rehearsed on a mainnet fork before the site job.
   - The IMD Indexer job, then the site job (design system in `plea/site-design/`; the Universal Router buy, the honeypot explanation, a "close (no verdict)" button after 20 minutes).
   - The Uniswap allowlist form (I submit it) and, after the mainnet Cabal dies, the aggregators.
   - The promo video: I do it in another session; the moments list is in HANDOFF.

Report to me in chat after each step, simply. Use send_later check-ins for timed steps instead of waiting.

Setup:
- Foundry 1.8.3: download `foundry_v1.8.3_linux_amd64.tar.gz` from the GitHub release into `~/.foundry/bin` and link it into `/root/.local/bin` (each container starts without it).
- Attach khaed1/plea with add_repo (push access). Clone it with all heads (`--no-single-branch`) into /home/user/plea, with worktrees for `next`, `mainnet` and `keeper` (fetch `--depth=60` before merging).
- The suite: `bash plea/tools/run_suite.sh <repo> <logdir>` (test/full with FOUNDRY_PROFILE=full; exits 1 on a group without a result; ~20 min with a cold build).
- The keeper: `cd keeper && npm ci && npm test`; the rehearsal `ARTIFACTS=<mainnet worktree>/out node rehearsal/run.mjs` after a full build of `mainnet`.
- imd/acc read only: `GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 https://github.com/khaed1/imd-acc /home/user/khaed1/imd-acc`.
- The run 9 live helper: `ADDRS=plea/live-run9/addresses.json STATE_DIR=<scratch> python3 -I plea/tools/live85.py help`.
