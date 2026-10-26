Pick up PLEA from khaed1/claude branch claude/adoring-goodall-pn3jyz. Read this prompt first. Then read HANDOFF.md from "New session: the run 9 live test (2026-10-21 13:04 UTC →)" to the end (the "Site design system session" section at the end belongs to another session), and NEXT_SESSION.md (the agreed numbers, rules and versions).

Rules: agreed numbers in NEXT_SESSION never change without asking. Never ask for a mainnet key (the owner's or the keeper's). Submit or pay IMD jobs (and One Dollar Audit jobs), and send anything from wallet A (key in env PONDPAD_TESTNET_KEY, never printed or committed), only with my go-ahead. Never the word mainnet or chain id 1 in a Sepolia job text. Explain simply; when I must choose, recommend one option. Reports and reviews I ask for go in chat; save them to a repo only if I ask. Keep HANDOFF.md, NEXT_SESSION.md and plea/hackathon-submission.md current and push after each step. Work only on branch claude/adoring-goodall-pn3jyz in the notes repo (fetch + merge before pushing; never rebase or force-push). In khaed1/plea, change `next`, then merge it into `main` and `mainnet` (chain-1-only settings — launch.json, README settings, `MARKET_CAP_IMD`, LaunchManifest constants — live on `mainnet` only); `light-profile` stays as it is; never touch the pinned `testnet8` @ dc3826b, `testnet8.5` @ af57f6d and `testnet9` @ 241c05e. The keeper bot lives on branch `keeper` (folder `keeper/`) until the mainnet launch job is submitted, then merge it into `next`, `main` and `mainnet`. imd/acc (khaed1/imd-acc) is read only. Verify every audit finding against the code (and on chain or with an uncommitted scratch test when needed) before telling me, and record or fix only what I agree.

**No go-ahead is open.** Anything new (IMD jobs, Ethereum, Base or Sepolia transactions, mainnet) needs my go-ahead.

Where we stopped (Mon 2026-10-26 ~17:45 UTC):
- **Run 9 is finished** (Sepolia, launch #2234; full story and records in HANDOFF and `plea/live-run9/`).
- **Mainnet decisions (2026-10-26):** START = **1795532400 = Tue 2026-11-24 15:00 UTC** (only the time from which anyone may seed; the owner may seed earlier, once the site, keeper and imd/acc listing are ready); the opening market cap stays **14,000 IMD**; seasons are 15 days on mainnet.
- **Owner wallet set:** `0x5BF3597216f9019Cf10CF680783289Efc8639Bf0` (mine, fresh) is in the `mainnet` README's Owner row and launch.json notes; `mainnet` @ 21bb640, **852/852**.
- **The mainnet launch job is ready but NOT submitted:** `plea/job-mainnet-launch.json` (`launch.open`, `evm_contracts`, chain 1, `baseCommit` 21bb640, owner `0x5bf3…9bf0`, a fresh objective of 5,049 characters; text to read in `plea/job-mainnet-form.md`); the free `/requests/check` came back clean. It costs 0.5 IMD from wallet A and needs my go-ahead.
- **Videos are done** (code in `plea/promo-video/`, pipeline in its README and HANDOFF; the MP4s were sent to me in chat and are not committed):
  - the promo, 78 s, 16:9 and 9:16 ("The Builder" by Kevin MacLeod, CC BY 4.0);
  - the explainer series "How PLEA works · 1–7 of 7" (Plead, Your bar, Appeal, Objection!, Letters, Seasons, Dead-man), ~21 s each, 16:9, its own dark look and "Spy Glass" music, real run 9 data checked on chain; draft tweets were given in chat;
  - a Bonus clip "Run a keeper": post it only after the launch job is submitted and `keeper` is merged into `main` (its guide link is github.com/khaed1/plea/tree/main/keeper; its end card says "On Ethereum").
- **The keeper bot is built** (`keeper/` on branch `keeper`): planner 15/15 unit tests, mainnet-fork rehearsal 45/45; not tested yet: real Telegram sends, the Flashbots relay, the gas-cap wait. Setup guide `keeper/VPS.md`; I install it on my VPS after the launch (dry run until trading opens).
- **khaed1/plea:** `next` @ 1673478, `main` @ 4595a33 (tree = `next`), `mainnet` @ 21bb640, `keeper` @ 08bbe5a, `light-profile` @ 180b13b.
- **Wallet A** (`0x4b91078b2374c956A65F7Af0999CaE0a935E6821`): Sepolia 7.795 ETH, 35.964774 imdTEST, nonce 302; Ethereum 0.80 IMD, 0.0021 ETH, nonce 97 (checked 17:40 UTC). Other sessions also use it: check latest = pending before every send.
- **The site has its own session** (design system in `plea/site-design/`). **Nothing is scheduled** (no check-ins, no watchers).

Your tasks, in order:
1. **Check the state:** IMD's API, wallet A's nonces and balances, anything new on `khaed1/plea`. Tell me what changed.
2. **The mainnet launch job, when I say go:** confirm `mainnet` is still at the pinned commit (re-pin and re-check if not), run the free `/requests/check` again, then submit and pay the 0.5 IMD from wallet A (check that its ETH covers the gas first). Follow the job to the end and report each step simply.
3. **Right after the launch job is submitted:** merge `keeper` into `next`, then `next` into `main` and `mainnet`; run the suite; in `keeper/VPS.md` switch the clone to `--branch main`. Then the keeper clip can be posted.
4. **Then, with me, in this order:** the IMD Indexer job → the site job (with the site session) → the owner steps (deploys, distributor root, the imd/acc application, the 2 IMD opening buy) → the keeper on my VPS (`keeper/VPS.md`) → the seed when everything is ready. Also: rehearse the Universal Router buy (`V4_SWAP` with hookData `abi.encode(buyer)`, `amountOutMinimum` 0, then `BALANCE_CHECK_ERC20` on the buyer's PLEA) on a mainnet fork before the site job; the Uniswap allowlist form (I submit it); after the mainnet Cabal dies, the aggregators.
5. **Hackathon and videos:** help if I ask (a clip changes by editing `src/series/<name>.js` or `data/clips.json`, then re-rendering; the README has the commands).

Report to me in chat after each step, simply. Use send_later check-ins for timed steps instead of waiting.

Setup:
- Foundry 1.8.3: download `foundry_v1.8.3_linux_amd64.tar.gz` from the GitHub release into `~/.foundry/bin` and link it into `/root/.local/bin` (each container starts without it).
- Attach khaed1/plea with add_repo (push access). Clone it with all heads (`--no-single-branch`) into /home/user/plea, with worktrees for `next`, `mainnet` and `keeper` (fetch `--depth=60` before merging).
- The suite: `bash plea/tools/run_suite.sh <repo> <logdir>` (test/full with FOUNDRY_PROFILE=full; exits 1 on a group without a result; ~20 min with a cold build).
- The keeper: `cd keeper && npm ci && npm test`; the rehearsal `ARTIFACTS=<mainnet worktree>/out node rehearsal/run.mjs` after a full build of `mainnet`.
- imd/acc read only: `GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 https://github.com/khaed1/imd-acc /home/user/khaed1/imd-acc`.
- The videos (`plea/promo-video/README.md`): Playwright and Chromium are preinstalled; the clips need "Spy Glass" from incompetech.com (`tools/make_clips_music.py`); the promo also needs the fork captures (`capture/capture.mjs`).
- The run 9 live helper: `ADDRS=plea/live-run9/addresses.json STATE_DIR=<scratch> python3 -I plea/tools/live85.py help`.
