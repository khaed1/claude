# IMD hackathon submission: PLEA v10 (draft, 2026-10-10)

Draft for the IMD hackathon (proposed build period 5–19 Oct; check the final rules, form fields and length limits before submitting). `{…}` marks what to fill in once PLEA v10 is live (launch job `3593725e`) and the site is hosted.

---

## PLEA + imd/acc

**One line:** a meme token you can always buy but can only sell by convincing a panel of 30 IMD oracle judges. The best pleas win IMD prizes each season, and every trade pays 0.5% back to the trader as staked IMD.

**Links**
- PLEA site: {PLEA v10 site URL (IPFS label plea-test)}
- Code: https://github.com/khaed1/plea · imd/acc: https://github.com/identity-md-launches/launch-1129-build-imd-acc-sepolia-test
- imd/acc test page: https://imd-acc-sepolia-test-run.site.identitymd.eth.limo
- Demo video: {link}
- X: {project account} · {lead developer account}
- Network: Sepolia (chain 11155111)

### The problem
Meme tokens are a race to dump. Holders sell at the first green candle, nothing rewards them for staying, and the trading around a token does nothing for IMD holders.

### What we built
**PLEA** is a sell-gated meme token inspired by TokenWorks' CabalCoin (2025), rebuilt on IMD.
- **Buying is open.** Anyone buys PLEA in the PLEA/IMD Uniswap v4 pool.
- **Selling needs a plea.** A holder writes up to 280 bytes explaining why they should be allowed to sell. The contract computes a fact score (0–55: share sold, buy-weighted hold time, profit or loss, 24h price), and the Cabal, a panel of 30 IMD oracle judges, scores the plea 0–45. The sell passes when the judges' score reaches the seller's need (70 − fact score) with 17 of 30 agreeing. An approval opens a 7-minute sell window; a denial starts a 4-hour wait with one appeal. A plea that can't pass is refused before it is paid for.
- **Seasons.** 15-day seasons run back to back while the Cabal lives. Every approved plea earns its score as points (each wallet's best three count). At the end of a season the top 10 wallets with at least 60 points split the prize pot 25/18/14/11/9/7/6/4/3/3 % in IMD, and the five best pleas are minted as **Laureate** NFTs, rendered fully on chain. Players can set a display name.
- **The Wall** shows every plea, its verdict stamp, score and points.
- **Dead-man.** If the Cabal gives no verdict for 33 hours it dies for good, and PLEA trades freely forever. Nobody has to trigger it: "alive" is computed on chain. The last season ends at the death, and what is left in the prize pot goes to the buy wall.

**imd/acc** is trading cashback paid in staked IMD, for any IMD project. A shared, ownerless `Stacker.credit(trader, amount)` deposits IMD into the sIMD vault in the trader's name. Projects fund it from fees they already charge, so traders pay nothing extra. PLEA is its first integration.

### How it uses IMD
1. **The IMD oracle is the game.** Every plea is a paid IMD oracle request through the Intake (0.5 IMD), with a numeric answer. The signed score comes back through the Intake callback and is checked on chain (EIP-712 signature, panel size, quorum, score range). The signer and Intake are immutable. Every sell attempt and every shot at the leaderboard is IMD demand.
2. **IMD is the pool's pair and the prize.** PLEA trades only against IMD, the hook keeps an IMD buy wall, and season prizes are paid in IMD.
3. **Cashback in sIMD.** 0.5% of every PLEA trade is deposited into the IMD staking vault for the trader through imd/acc, in the same swap.
4. **Launched through IMD from our own repository.** PLEA v10 was written in a public Foundry repo and launched with `launch.open` + `repoUrl`/`baseCommit`: IMD's swarm audited the imported code, adapted and tested it, ran four specialist audits and a judge, then deployed it. imd/acc and PLEA v2 were IMD swarm launches too (#1129, #1148).

**Fees per trade (1.75%, all paid in the same swap):** 0.5% sIMD cashback to the trader · 0.5% owner · 0.25% season prize pot · 0.25% pool liquidity · 0.25% of the PLEA burned.

### Evidence (Sepolia)
- **imd/acc live** (launch #1129, tx `0x9512b5df…c0f0`): Stacker `0x293c7134ab8f6bf1d8ff44ed806575f8f1baf477`, TestIMD `0x2b69099e59b05901faa1dd164fabf098bf831e82`, TestSIMD `0xf9e2eec3b610ec6781f7438ac5fb4bc049d81cc1`. Credit tx `0xaabe6a70…3252` minted sIMD to the trader with the correct `Stacked` event.
- **PLEA v2 live** (launch #1148, tx `0x655579bd…9525`): buys, cashback stacked through the hook, every transfer restriction tested (direct sells, other pools, routers and claims all blocked), and a signed oracle verdict delivered end to end.
- **PLEA v10 live:** {launch #, tx; PLEA / CabalGate / Seasons / Laureates / PleaDistributor / PleaLaunch / PleaHook addresses} · buy with cashback stacked in the same swap {tx} · approved plea and executed sell {tx} · denied plea and appeal {tx} · points recorded {tx} · season closed, prizes paid and Laureates minted {tx}.
- **Before launch:** 105 Foundry tests (both pool orientations, isolated launch rehearsal, oracle conformance); a Sepolia fork run (deploy 10.73M gas, 8/8 buys with plain gas estimates stacking sIMD through the live Stacker, a plea paid through the real Intake, approved via the callback, sold and recorded on the leaderboard); Slither clean of high-severity findings.
- **Oracle calibration:** test pleas through the Sepolia Intake set the scoring wording (strong ≈ 35–40, plain ≈ 25–30, weak or abusive under 15; prompt injections signed 0). Real panels signed numeric scores for v10's exact request body (35 and 21).

### Reproduce
- Build and test: `forge build && forge test` in https://github.com/khaed1/plea (Foundry 1.8.3).
- Try it: get test IMD from the imd/acc faucet, buy PLEA on the site, write a plea, watch the Wall and the season leaderboard.

### Known risks and admin powers
- **Selling may be refused.** That's the game; the dead-man guarantees an exit if the Cabal goes quiet for 33 hours.
- **Judges are AI agents.** Scores are subjective. A split panel gives no verdict; the plea expires after 20 minutes and the wallet can try again.
- **Points must be recorded.** The oracle callback only stores the score (it has 200k gas on mainnet), so points are recorded by a separate call that anyone can make (`record`, or `closeSeason` with a list of pleas).
- **Owner powers:** an add-only transfer allowlist (empty today), a one-time Merkle root for the 10% distributor, and opening trading early with `seed()` (anyone can once START passes). The owner can't change the oracle signer, the Intake, fees, timings or prizes.
- **Testnet only:** seasons last 5 hours on Sepolia so a full cycle can be shown (15 days on mainnet; the contracts refuse shorter timings on chain id 1). TestSIMD's owner can pause it to test the cashback fallback. The test owner wallet is testnet-only; mainnet will use a fresh wallet.
- IMD's audit reports are in the launch repository; agent reviews are not a full security audit.

### Reused work (disclosed)
- **Concept:** CabalCoin by TokenWorks (sell-gating by plea); btc/acc by TokenWorks (cashback idea).
- **Code:** the hook is a fork of POOL4's `CappedBurnHook` (IMD side); TestSIMD is the verified StakedIMD source renamed; OpenZeppelin v5, Uniswap v4-core, forge-std, Solmate.
- **New during the event:** the oracle gate (Intake payment, callback verification, numeric score, fact score, appeals, expiry, dead-man), seasons, prizes and on-chain Laureates, same-swap fees and gas-safe cashback, the imd/acc Stacker and its points, the sites, and the calibration runs.

### What's next
- **Mainnet:** imd/acc's Stacker against the real IMD and sIMD, then PLEA pointing at it.
- **imd/acc v2:** cashback for ETH-fee projects, batched through POOL4 (`flush()`), so any IMD project can add it.
- **More Cabals:** themed judging moods (Rekt, Jester's, Loyal) were designed and calibrated on Sepolia; a proven rug scored 39, an FTX deposit 31, a story with no proof 21.
