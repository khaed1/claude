# IMD hackathon submission (draft, 2026-10-10)

Draft for the proposed IMD hackathon (build period 5–19 Oct, rules not yet announced). `{…}` marks what to fill in once PLEA v4 is live. Check the final rules for the network, the form fields and length limits before submitting.

---

## PLEA + imd/acc

**One line:** a meme token you can always buy but can only sell by convincing a panel of 30 IMD oracle judges, and every trade pays 0.5% back to the trader as staked IMD.

**Links**
- PLEA site: {PLEA v4 site URL}
- imd/acc test page: https://imd-acc-sepolia-test-run.site.identitymd.eth.limo
- Code: {PLEA v4 repo} · https://github.com/identity-md-launches/launch-1129-build-imd-acc-sepolia-test
- Demo video: {link}
- X: {project account} · {lead developer account}
- Network: Sepolia (chain 11155111)

### The problem
Meme tokens are a race to dump. Holders sell at the first green candle, and nothing rewards them for staying, or rewards IMD holders for the trading that happens around them.

### What we built
**PLEA** is a sell-gated meme token, a relaunch of TokenWorks' CabalCoin (2025), rebuilt on IMD.
- **Buying is open.** Anyone buys PLEA in the PLEA/IMD Uniswap v4 pool.
- **Selling needs a plea.** A holder writes up to 280 characters explaining why they should be allowed to sell. The contract computes a fact score (0–55: share sold, hold time, profit or loss, recent price), and the Cabal, a panel of 30 IMD oracle judges, scores the plea (0–45). The sell passes if the total reaches 70 and 17 of 30 judges agree. An approval opens a 7-minute sell window; a denial starts a 4h wait with one appeal.
- **The Wall** shows every plea, verdict and stamp (approved, denied, appealed, executed, lapsed).
- **Dead-man switch:** if the Cabal gives no verdict for 33 hours, anyone can retire it and PLEA trades freely forever.

**imd/acc** is trading cashback paid in staked IMD, for any IMD project. A shared, ownerless `Stacker.credit(trader, amount)` deposits IMD into the sIMD vault in the trader's name. Projects fund it from fees they already charge, so traders pay nothing extra. PLEA is its first integration.

### How it uses IMD
1. **The IMD oracle is the game.** Every plea is a paid IMD oracle request through the Intake, 0.5 IMD each. The verdict comes back through the Intake callback and is checked on chain (EIP-712 signature, panel size, quorum). The signer and Intake are immutable. Every sell attempt is IMD demand.
2. **IMD is the pool's pair.** PLEA trades only against IMD; the hook keeps an IMD buy wall.
3. **Cashback in sIMD.** 0.5% of every PLEA trade is deposited into the IMD staking vault for the trader, through imd/acc, in the same swap.
4. **Launched through IMD.** Both projects were built and launched by the IMD swarm (`evm_contracts` launches #1129 and #1148, plus v4), with IMD's audits and reproducible-bytecode checks.

**Fees per trade:** 0.5% sIMD cashback to the trader · 0.5% owner · 0.25% pool liquidity · 0.25% of the PLEA burned.

### Evidence (Sepolia)
- **imd/acc live** (launch #1129, tx `0x9512b5df…c0f0`): Stacker `0x293c7134ab8f6bf1d8ff44ed806575f8f1baf477`, TestIMD `0x2b69099e59b05901faa1dd164fabf098bf831e82`, TestSIMD `0xf9e2eec3b610ec6781f7438ac5fb4bc049d81cc1`. Credit tx `0xaabe6a70…3252` minted sIMD to the trader with the correct `Stacked` event.
- **PLEA v2 live** (launch #1148, tx `0x655579bd…9525`): buys, cashback stacked through the hook, every transfer restriction tested (direct sells, other pools, routers and claims all blocked), and a signed oracle verdict delivered end to end.
- **PLEA v4 live:** {launch #, tx, PLEA / CabalGate / PleaHook / PleaLaunch / PleaDistributor addresses} · buy with cashback stacked in the same swap {tx} · approved plea and executed sell {tx} · denied plea and appeal {tx}.
- **Oracle calibration:** 12 test pleas through the Sepolia Intake set the scoring wording (strong ≈ 35–40, plain ≈ 25–30, weak or abusive under 15). Both prompt-injection attempts were signed 0.

### Reproduce
- Build and test: `forge build && forge test` in each repo (Foundry 1.8.3).
- Try it: get test IMD from the imd/acc faucet, buy PLEA on the site, write a plea, watch the Wall.

### Known risks and admin powers
- **Selling may be refused.** That's the game; the dead-man switch guarantees an exit if the Cabal goes quiet for 33h.
- **Judges are AI agents.** Scores are subjective. A split panel gives no verdict, and the plea expires after 20 minutes so the wallet can try again.
- **Owner powers:** add-only transfer allowlist (allowlisted addresses can send PLEA freely; empty today), a one-time Merkle root for the 10% distributor, and opening trading early with `seed()` (anyone can after START). The owner can't change the oracle signer, the Intake, fees or timings.
- **Testnet only:** TestSIMD's owner can pause it to test the cashback fallback (traders then get plain test IMD). The test owner wallet is testnet-only; mainnet will use a fresh wallet.
- IMD's audit reports are in each repo; agent reviews are not a full security audit.

### Reused work (disclosed)
- **Concept:** CabalCoin by TokenWorks (sell-gating by plea); btc/acc by TokenWorks (cashback idea).
- **Code:** the hook is a fork of POOL4's `CappedBurnHook` (IMD side); TestSIMD is the verified StakedIMD source renamed; OpenZeppelin v5.1.0 and Solady.
- **New during the event:** the oracle gate (Intake payment, callback verification, fact score, appeals, expiry, dead-man), same-swap fees and cashback, the imd/acc Stacker and its points, both sites, and the calibration runs.

### What's next: Seasons
Designed and partly tested, not built yet:
- **15-day seasons with a top-10 leaderboard,** paid from a new 0.25% prize fee.
- **Eras of 30 days with a Cabal mood each:** Classic, Rekt, Jester's, Loyal. When an era ends, 72h of free trading, then holders pay a ransom (500 IMD) to bring back the next Cabal.
- **The Rekt Cabal:** pleas from people who lost money to rugs or collapses. Judges verify the claim on chain themselves. Calibration on Sepolia: a proven rug scored 39, an FTX deposit 31, an FTX story with no proof 21; fake claims and injections were signed 0.
- **Laureate NFTs** for each season's top 5 pleas, and soulbound relics for ransom contributors.
- **imd/acc on mainnet:** the Stacker against the real IMD and sIMD, so any IMD project can add cashback.
