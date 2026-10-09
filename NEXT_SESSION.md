Repo `khaed1/claude`, branch **`claude/adoring-goodall-pn3jyz`**. Work and push only on this branch.

You're picking up two projects I'm building on the IMD swarm (imd.fun). The previous session ran out of context. Everything it learned is in **HANDOFF.md**; read it first, since it's the source of truth (addresses, tx hashes, decisions, bugs, test results). Then read the files below as needed.

## The two projects in brief
- **imd/acc:** 0.5% trading cashback paid to traders as staked IMD (sIMD), funded from a project's existing fees. A shared, ownerless `Stacker.credit(trader, imdAmount)` deposits into the sIMD vault in the trader's name and records points per trader and project. Only listed projects earn points, from their listing block onward. **Live on Sepolia** with TestIMD, TestSIMD and Stacker, plus a test site. Already tested end to end.
- **PLEA:** a sell-gated meme token, a relaunch of TokenWorks' CabalCoin. Buying is open; **selling needs a plea approved by "the Cabal"**, an IMD oracle panel of 30 judges.
  - It has one Uniswap v4 hook (a POOL4 CappedBurnHook fork, IMD side) with fees of 0.5% imd/acc cashback, 0.5% owner, 0.25% liquidity, and a 0.25% PLEA burn.
  - Gate rules: 7-minute sell window, 4h denial wait with one appeal, and a 48h dead-man switch.
  - **Live on Sepolia** (launch #1148). It's imd/acc's first integration.

## Files to read
- `HANDOFF.md`: state, addresses, decisions, the test log, "Mainnet readiness", and "Decided after the first oracle test". **Start here.**
- `plea/launch-spec.md`: the full PLEA spec; later sections override earlier ones.
- `plea/job-sepolia.md`: the next-version PLEA prompt (not yet resubmitted; it needs the mainnet fixes).
- `plea/job-continue-site.md`: the prompt that built the PLEA test site (with Impeccable design rules).
- `imd-acc/README.md`, `imd-acc/job-sepolia.md`, `imd-acc/job-continue-site.md`: imd/acc spec and prompts.
- Deployed PLEA code: https://github.com/identity-md-launches/launch-1148-build-plea-sepolia-test. Contracts are at commit `33c75a5c`; the site is at commit `1ef27b46` (PR #2), with its static build in the repo.
- imd/acc code: https://github.com/identity-md-launches/launch-1129-build-imd-acc-sepolia-test
- IMD docs: https://imd.fun/docs/ · API: https://api.imd.fun

## Where we stopped
- **PLEA on Sepolia works:**
  - buys deliver real PLEA, and transfer restrictions hold (all tested)
  - fees, burn and cashback work, but cashback goes through settle-then-claim
- **The oracle path is proven end to end on real IMD** (Gate body → mainnet Intake → panel → signature → `deliverVerdict`):
  - **Plea #1:** the panel split 17/13 and nothing was signed. It stays Pending until `cancel(1)`, allowed after 17:13 UTC on 2026-10-09.
  - **Plea #2:** a manipulative plea got a signed FALSE (20/0), delivered on-chain and now DENIED. Replay protection was confirmed.
- **Two bugs in the live Gate, both fixed in `plea/job-sepolia.md`:**
  - **Question logic:** it says "fact + plea ≥ need" where it should be plea alone.
  - **Consumer key:** the body emits `consumer.address` where IMD requires `verifyingContract`. Rename it before paying.
- **Decided:** quorum **16 of 30** for the next version.
- **The PLEA test site was just delivered and is NOT tested yet:** https://plea-sepolia-test.site.identitymd.eth.limo (IPFS CID `bafybeihu55zn6tidzq55um7jo7mab7bsqrsozuu3j6sz5io4o4o7fdssce`).

## Your first task: test the PLEA site end to end, then report
1. Get the site's build from the repo above (commit `1ef27b46`). From this cloud container the `.eth.limo` link fails TLS and public IPFS gateways return 429, so test the repo build.
2. Read its config and check that every address, block and selector matches HANDOFF.md.
3. Serve it locally and drive it with Playwright (Chromium is preinstalled). Use an injected `window.ethereum` that forwards to an **anvil fork of Sepolia**, with an unlocked test account, so nothing real is spent. Point the site's RPC list at the fork for the test.
   - **Getting Foundry:** `foundryup` is blocked; download the release tarball `foundry_v1.8.3_linux_amd64.tar.gz` from github.com/foundry-rs/foundry.
4. Test these flows:
   - faucet
   - buy (PoolSwapTest with hookData = buyer)
   - settle claims, then claim cashback (tsIMD goes up)
   - plead up to Pending (also check the fact score and need shown)
   - cancel after the timeout (warp time on the fork)
   - the Wall shows plea #1 PENDING and #2 DENIED with the right stamps
   - status page values
   - an appeal on a denied plea (warp time on the fork; to test approval paths, set a test signer **on the fork only**)
5. Check no page errors and no horizontal scroll at 360/768/1280 px, light and dark. Also check against the Impeccable rules in `plea/job-continue-site.md`: no eyebrow labels, gradient text, emoji icons and so on.
6. Write the results into HANDOFF.md, commit and push, and report to me in plain language with a recommendation.

## Rules
- **Explain simply.** When I need to choose, recommend one option.
- **Don't change agreed numbers** (fees, caps, timings, supply split, quorum) without asking me.
- **Keys:** never ask me to paste a mainnet key into chat. If you need the Sepolia test wallet (`0x4b91…6821`, testnet only), ask me. Keep keys in your scratchpad, delete them after use, and never commit them.
- **PondPad** (branch `claude/bold-gauss-qhlw86`) is read-only. Never commit its code.
- **Launch page:** a prompt must stay under about 7,280 characters (measured with `/requests/check`). IMD's free quote (`POST /requests/quote` with any Bearer token) validates an oracle body without paying.
- **After the site test, the next steps are** (see HANDOFF "Mainnet readiness"):
  - fold the mainnet fixes into the next PLEA prompt: automatic cashback, a permanent oracle signer, Intake callback, announced trading start, quorum 16
  - ask the IMD dev for the Sepolia Intake address and hook-salt support
  - list PLEA's hook on the imd/acc site
