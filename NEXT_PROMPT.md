Pick up PLEA from khaed1/claude branch claude/adoring-goodall-pn3jyz. Read this prompt first. Then read HANDOFF.md from "New session: watches moved, run 8.5 waiting for Sepolia answers (2026-10-18 07:50 UTC →)" to the end (the "Site design system session" section at the end belongs to another session), and NEXT_SESSION.md (the agreed numbers, rules and versions).

Rules: agreed numbers in NEXT_SESSION never change without asking. Never ask for a mainnet key. Submit or pay IMD jobs (and One Dollar Audit jobs), and send anything from wallet A (key in env PONDPAD_TESTNET_KEY, never printed or committed), only with my go-ahead. Never the word mainnet or chain id 1 in a Sepolia job text. Explain simply; when I must choose, recommend one option. Reports and reviews I ask for go in chat; save them to a repo only if I ask. Keep HANDOFF.md, NEXT_SESSION.md and plea/hackathon-submission.md current and push after each step. Work only on branch claude/adoring-goodall-pn3jyz in the notes repo (fetch + merge before pushing; never rebase or force-push). In khaed1/plea, change `next`, then merge it into `main` and `mainnet`; `light-profile` stays as it is (it was merged into all three on 2026-10-17); never touch the pinned `testnet8` @ dc3826b, `testnet8.5` @ af57f6d and `testnet9` @ 241c05e. imd/acc (khaed1/imd-acc) is read only. Verify every audit finding against the code (and on chain or with an uncommitted scratch test when needed) before telling me, and record or fix only what I agree.

**My go-ahead (Tue 2026-10-20):** the run 9 live test below, on Sepolia, from wallet A and test wallets, with the 50 imdTEST. Anything else (IMD jobs, Ethereum or Base transactions, mainnet) still needs my go-ahead.

Where we stopped (Tue 2026-10-20 ~19:00 UTC):
- **Run 9** is launch #2234 (`testnet9` @ 241c05e). It is the final code, with imdTEST as both the pool token and the oracle fee.
  - It is live on Sepolia and **not seeded**. Addresses are in `plea/live-run9/addresses.json`. Wallet A deployed the Letterbox, Tribunal and PleaHook.
  - START is Wed 2026-10-21 15:00 UTC. Wallet A may seed any time; anyone may seed from START.
- **imdTEST** is `0x56bcf2a5F47710649A4091219Ef0b56e2d1B58BF`. IMD's Sepolia oracle is sold only in it, at 0.5 a question, and only the dev mints it.
  - Wallet A holds 50 (the dev's mint, block 11,955,606).
  - Other holders: `0xff3cbe2385d56960bbad93c1d5378fef2e1f8390` (another project's oracle consumer, 1,000), and 10 each at `0xdea11b3a70b77134424d436f6eb455f1abbd4449`, `0x3c587eff6c96eacf7e3dcc2cff6416161386e48c` and `0xabd06aa2679444959e96a799f297f3a8e89be2aa`.
- **The dev's concern:** he asked us not to use imdTEST as the pool token, in case outsiders buy in and use the oracles. I decided to test anyway, with little imdTEST in the pool, and to take it back out at the end.
- **IMD's Sepolia oracle is answering:** another project's request on 2026-10-20 at 15:34 UTC got its panel's result in about 2 minutes.
- **The run 9 site:** https://plea-test-run-9.sites.imd.fun/ (IMD's site job, submitted by the design session).
- **khaed1/plea:** `next` = `testnet9` @ 241c05e, `main` @ 46bd23a, `mainnet` @ 3d0976a (852/852 on each, with both forks); `light-profile` @ 180b13b.
- **Wallet A** (`0x4b91078b2374c956A65F7Af0999CaE0a935E6821`):
  - Sepolia: 7.79 ETH, nonce 274, 50 imdTEST.
  - Ethereum: 0.80 IMD, nonce 57.
  - The imd/acc session shares it, so check that nonce latest = pending before every send.
- **Last session's check-in** `trig_01U3M24dECwSxDhMcsH4FF7t` (send_later, Wed 15:05 UTC) fires into the old session. It checks whether someone else seeded run 9.

Your tasks, in order:
1. **Delete that check-in.** Before seeding, check `PleaLaunch.opened()`. If someone else seeded first, tell me at once.
2. **The run 9 live test** (below).
3. **Hackathon:** help if I ask.
4. **Later, with me:**
   - The mainnet START and a fresh owner wallet; then re-pin `plea/job-mainnet-launch.json` and run a free check.
   - The keeper bot.
   - The IMD Indexer job, then the site job (the design system is in `plea/site-design/`).
   - The promo video.

## The run 9 live test

**Goal:** a full live test of the final code against IMD's real Sepolia oracle.
- Above all, the oracle parts: pleas, verdicts, appeals, letters, objections and rulings, records and season closes.
- Also the pool and trades, more lightly: earlier runs already tested them.
- Then take the imdTEST back out of the pool.

**Limits:**
- **imdTEST into the pool:** the owner's 2 opening buy plus at most 5 of test buys. Appeal wall shares (0.35 each) also land in the pool. Ask me before going over.
- **Oracle fees** (0.5 a question, paid to IMD) come from each test wallet's own imdTEST, which wallet A sends. Plan for about 20 questions.
- **Stop and tell me** if the oracle stops answering (pleas expiring), or if any wallet that isn't ours buys, pleads, objects or delivers a letter.

**What I checked in the code and on chain (2026-10-20)** — plan with it:
- **The pool:**
  - Nobody can withdraw its liquidity, not even the owner. imdTEST leaves the pool only through PLEA sales and fees.
  - While the Cabal lives, sells go only through approved pleas, and PLEA can't move between ordinary wallets (`CabalIsWatching`). Each test wallet gets PLEA by buying or by claiming from the distributor.
- **Ways someone outside could get imdTEST (only two):**
  - The 0.25 tip for delivering an approved letter goes to whoever calls `deliver` first, so deliver ours at once.
  - Wallets that already hold imdTEST can play like anyone.
- **Run 9's clocks:**
  - Seasons are 5 h. A season can be closed 1 h after it ends, in order.
  - The Cabal dies 33 h after the last plea verdict. Denials count; objection rulings don't.
  - Sale window 7 min. Cooldown 4 h after a sale, a denial or a lapse.
  - An appeal must come within 4 h of the denial. Objections are open for 20 min after an approval.
  - A plea or objection with no answer can be expired after 20 min.
  - Buys in the first 90 min pay an extra fee, falling from 70% to 0, into the wall.
- **Approvals:**
  - need = 71 − the fact score. Read the fact score with `gate.factScore(wallet, amount)`.
  - The fact score adds four parts:
    - Share of the balance: at most 20% gives 16.
    - Holding time: 1 / 3 / 7 days give 2 / 4 / 7.
    - Profit: at a loss gives 13 (a fresh buyer is at a loss through the fees). Received PLEA (the airdrop, prizes) follows the agreed rule of 2026-10-15: held since the seed, at profit 10.
    - The 24h trend: flat gives 5, and our volumes keep it flat.
  - So the need is:

    | PLEA held | fresh | after 1 day | after 3 days |
    |---|---|---|---|
    | bought | 37 | 35 | 33 |
    | airdrop only | 40 | 38 | 36 |

  - Earlier live verdicts were 29–36; approvals came at 33–36 with a need of 33.
  - Expect denials first, and approvals once the wallets have held for 1–3 days. Plan for 3–4 days, and keep the Cabal alive with a verdict at least every 33 h.
- **Plea amounts:**
  - The gate allows 1–50% of the balance, at most 2.5M PLEA.
  - Keep a plea at most 20% of the balance and no bigger than the PLEA the wallet bought; then the "at a loss" 13 counts.
  - A sale must fill completely from the pool's imdTEST, so keep sales small.
- **Letters:**
  - A letter pleads 20% of the writer's PLEA. A letter or the site's auto-sell plea must be worth at least 0.70 imdTEST.
  - A letter pays its fee by selling the writer's PLEA into the pool: 0.5 oracle + 0.25 tip, plus 0.35 for an appeal.
  - That takes about 0.75 imdTEST out of the pool per letter (about 130k PLEA at the opening price). An approved letter's sale takes about 0.7 more.
- **The owner:** wallet A can't earn points or prizes and can't object. The test wallets do the court.
- **Points:**
  - A wallet's best 3 approved scores in a season count.
  - A prize needs 60 points and a place in the top 25; each place gets 4.5% down to 3.5% of the pot.
  - The first six seasons also pay a 10M PLEA bonus; if nobody qualifies, it burns.
  - A seat gives 1.2x points. The Sepolia seat NFT has an open mint.
- **The distributor:**
  - Its root can be set only once, by wallet A.
  - Anyone may claim for a listed wallet; the PLEA always goes to that wallet.

**Steps.** Rehearse every new kind of step on an anvil fork of Sepolia first (`plea/tools/live85.py` with `fork-init` / `fork-answer`). Then do one live step at a time: check nonce latest = pending, use gas = estimate × 1.3, and log every tx in `plea/live-run9/`.

1. **Prep (nothing sent):**
   - A `STATE_DIR` outside git.
   - 4 test wallets whose keys are derived from wallet A's key (e.g. keccak256 of the key and "plea-run9-p1"), so a container restart can't strand their funds. Never print or save the keys.
   - A Merkle tree for the distributor:
     - about 500k–1M PLEA to each test wallet, so a letter's 20% is worth at least 0.70 imdTEST;
     - 20M to wallet A for the end (claim that one only at the end).
   - Check that IMD's `/requests/capabilities` still sells `oracle.request` on 11155111 for 0.5 imdTEST.
2. **Open:**
   - Seed from wallet A, then at once the owner's 2 imdTEST opening buy (agreed). Expect `PayoutsToPool`, and the launch fee kept for the wall.
   - Set the distributor root, then claim for the test wallets. This tests the claim flow too.
3. **Players and trades:**
   - Send each test wallet Sepolia ETH for gas and about 4 imdTEST for fees; top them up later from wallet A.
   - After the 90-minute window, each test wallet buys once, about 1.25 imdTEST (5 in total).
   - Check the fee split: 1% to wallet A, 0.25% to the prize, 0.25% to the wall, 0.25% of the PLEA burned.
   - Check the cashback is paid in plain imdTEST (imd/acc's Stacker can't take imdTEST), any ERC-6909 claims, and `rebalance` → the wall.
   - By `eth_call` only, check these are refused: a buy without a recipient, an exact-output buy, a direct sell and a PLEA transfer.
   - One test wallet mints a seat.
4. **The court, with real verdicts.**
   - Check `gate.factScore` and the need first.
   - Write honest, specific texts of at most 280 bytes. Never tell the judges how to score: on an earlier live run, "Score my honesty, not my timing" got zeros. Never use the word mainnet or chain id 1.
   - **Cases to cover:**
     - A direct plea → denial → appeal (0.5 + 0.35 to the wall).
     - A direct plea → approval → `executeSell` inside 7 minutes; then `record` after the 20-minute objection window.
     - An approval left to lapse.
     - An objection by another test wallet on an approval → ruling → Tribunal `settle` (the stake goes back if sustained or void, and to the prize pot if overruled). Then see what `record` does: no points if sustained, the lower score if overruled. If possible, a second objection from another wallet.
     - Letters:
       - a plain-text letter sent as a transaction's data (like Etherscan's message page), and `letter(text)`;
       - a denied letter → `settle` (PLEA and tip back) → an `APPEAL <text>` letter;
       - an approved letter → `deliver` at once;
       - a `SELL` letter and `NAME <name>`;
       - the site's auto-sell `plead` (0.35 fee to the prize pot).
     - Failure paths when they happen: `expire` after 20 min, and `onPleaFailure`. Check text checks and cooldowns by `eth_call`.
5. **Seasons:**
   - `record` each approval, and close each ended season (`closeSeason`, after its end + 1 h).
   - Check the rollover; `PrizePaid` and `BonusPaid` if a wallet reaches 60; the seat's 1.2x; an overruled stake landing in the pot.
6. **The end — take the imdTEST back out:**
   - Stop pleading. 33 h after the last verdict the Cabal dies and trading is free.
   - Close the remaining seasons and call `flushToWall`.
   - Claim wallet A's 20M. Sell every wallet's PLEA back into the pool with PoolSwapTest; `rebalance` and sell into the wall again; redeem any ERC-6909 imdTEST claims. Repeat until the pool holds (almost) no imdTEST.
   - Gather all the imdTEST in wallet A.
   - Tell me how much came back, how much went to IMD as oracle fees, and what is left in the pool and why. Send it nowhere else without my go-ahead.
7. **Optional:** look at the run 9 site with the live data and list what it shows wrong, for the later site work. Change nothing there.

Report to me in chat after each phase, simply. Use send_later check-ins for the timed steps instead of waiting.

Setup:
- Foundry 1.8.3 in /root/.local/bin (install it from the release tarball if missing).
- Attach khaed1/plea with add_repo (push access). Clone it with all heads into /home/user/plea, with worktrees for main and mainnet.
- **The live helper:** `ADDRS=plea/live-run9/addresses.json STATE_DIR=<scratch> python3 -I plea/tools/live85.py help`.
  - Run 9 has IMD = ORACLE = imdTEST, so there is no faucet; wallet A hands imdTEST out with `give`.
  - Still to write: player keys derived from wallet A's key, the distributor tree and claims, selling with free trading, and redeeming claims.
- The suite: `bash plea/tools/run_suite.sh <repo> <logdir>`. It runs test/full with FOUNDRY_PROFILE=full, lists any group without a result and exits 1 if there is one.
- Node 22 for the x402 script, only if I ask for a One Dollar Audit job.
