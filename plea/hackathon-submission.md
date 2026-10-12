# IMD hackathon submission: PLEA (draft, updated 2026-10-12)

Draft for the IMD hackathon (proposed build period 5–19 Oct; check the final rules, form fields and length limits before submitting). `{…}` marks what is still open: demo video, X accounts, the season-3 result of run 2 (closes 16:49 UTC today) and run 3 once it is live.

---

## PLEA + imd/acc

**One line:** a meme token you can always buy but can only sell by convincing a panel of 30 IMD oracle judges. The best pleas win IMD prizes each season, and every trade pays 0.5% back to the trader as staked IMD.

**Links**
- PLEA site (test run 2, live): https://plea-make-your-case-0c37.sites.imd.fun/
- Code: https://github.com/khaed1/plea (branch `testnet3` = the next version with letters; `mainnet` = the mainnet draft) · delivered run 2: https://github.com/identity-md-launches/launch-1311-launch-plea-test-run
- imd/acc: https://github.com/khaed1/imd-acc · test site https://imd-acc-sepolia-test-run-2.sites.imd.fun/
- Demo video: {link}
- X: {project account} · {lead developer account}
- Network: Sepolia (chain 11155111)

### The problem
Meme tokens are a race to dump. Holders sell at the first green candle, nothing rewards them for staying, and the trading around a token does nothing for IMD holders.

### What we built
**PLEA** is a sell-gated meme token inspired by TokenWorks' CabalCoin (2025), rebuilt on IMD.
- **Buying is open.** Anyone buys PLEA in the PLEA/IMD Uniswap v4 pool.
- **Selling needs a plea.** A holder writes up to 280 bytes explaining why they should be allowed to sell. The contract computes a fact score (0–55: share sold, buy-weighted hold time, profit or loss, 24h price), and the Cabal, a panel of 30 IMD oracle judges, scores the plea 0–45. The sell passes when the judges' score reaches the seller's need (70 − fact score) with 17 of 30 agreeing. An approval opens a 7-minute sell window; a denial starts a 4-hour wait with one appeal. A plea that can't pass is refused before it is paid for.
- **Seasons.** 15-day seasons run back to back while the Cabal lives. Every approved plea earns its score as points (each wallet's best three count). At the end of a season the top 10 wallets with at least 60 points split the prize pot 25/18/14/11/9/7/6/4/3/3 % in IMD, plus a **PLEA bonus** (5,000,000 PLEA per season for the first seasons, held by the Seasons contract from launch, the unpaid rest burned). Players can set a display name (by letter too). The owner can't play (no points, prizes or bonus; next version).
- **Pleading by letter (next version, `testnet3`).** Anyone can plead straight from a wallet or Etherscan by sending a transaction whose input data is the plea text to the ownerless **Letterbox**. `APPEAL <text>`, `SELL` and `NAME <name>` are commands. A letter pleads 10% of the writer's PLEA, held in escrow; the fees are paid in PLEA in the same transaction (the gate sells just enough PLEA for the 0.5 IMD oracle fee and a 0.25 IMD runner tip, at most the hourly price snapshot +10%). An approved letter **sells itself**: anyone calls `deliver` (at least 95% of the snapshot value), the IMD goes to the writer, the points are recorded and the caller earns the tip; every other ending returns the escrow and the tip. `status(address)` and `leaderboard()` answer in plain sentences on Etherscan. No Letterbox function ID can be the start of valid text (a test checks the ABI), so a letter can never call a function by accident.
- **A real stake in every plea.** A plea must be at least 1% of the seller's balance (or 2.5M PLEA), so a plea for a few wei can't farm season points (next version).
- **The Wall** shows every plea, its verdict stamp, score and points.
- **Dead-man.** If the Cabal gives no verdict for 33 hours it dies for good, and PLEA trades freely forever. Nobody has to trigger it: "alive" is computed on chain. The last season ends at the death, and what is left in the prize pot goes to the buy wall.

**imd/acc** is trading cashback paid in staked IMD, for any IMD project. A shared, ownerless `Stacker.credit(trader, amount)` deposits IMD into the sIMD vault in the trader's name. Projects fund it from fees they already charge, so traders pay nothing extra. PLEA is its first integration.

### How it uses IMD
1. **The IMD oracle is the game.** Every plea is a paid IMD oracle request through Intake v2 (0.5 IMD), with a numeric answer. The signed score comes back through the Intake callback and is checked on chain (EIP-712 signature, panel size, quorum, score range); a refused or split panel is cleared at once through Intake v2's failure callback. The signer and Intake are immutable. Every sell attempt and every shot at the leaderboard is IMD demand.
   - **The Cabal's rules, version 2**, were calibrated with 13 live 30-seat panels on Sepolia: an honest "weigh my honesty, not my timing" went from a signed 0 (version 1 read it as manipulation) to 33; a threat is a unanimous 0; jokes, poems and other languages score on craft; a shill scores 20; content rules for hate, harassment and doxxing, while the writer's own hardship is allowed.
2. **IMD is the pool's pair and the prize.** PLEA trades only against IMD, the hook keeps an IMD buy wall, and season prizes are paid in IMD.
3. **Cashback in sIMD.** 0.5% of every PLEA trade is deposited into the IMD staking vault for the trader through imd/acc, in the same swap.
4. **Launched through IMD from our own repository.** PLEA v10 and test run 2 were written in a public Foundry repo and launched with `launch.open` + `repoUrl`/`baseCommit`: IMD's swarm audited the imported code, adapted and tested it, ran four specialist audits and a judge, then deployed it. In run 2 the audit found a real high-severity bug in our wall guard (it adopted the pool's extreme tick after a draining sell after the Cabal's death) and fixed it before deploying. imd/acc and PLEA v2 were IMD swarm launches too (#1129, #1294, #1148).

**Fees per trade (1.75%, all paid in the same swap):** 0.5% sIMD cashback to the trader · 0.5% owner · 0.25% season prize pot · 0.25% pool liquidity · 0.25% of the PLEA burned.

### Evidence (Sepolia)
- **PLEA test run 2 live** (launch #1311, IMD job `4aca2460`, deploy tx `0x2a68ba654318661a7922474d26719db715300db42481dc6e6558a364e02ca47d`; all 7 contracts verified on Sourcify): PLEA `0x2f4ad5c8b4cd47a80356e07ef47d8ae875e9c795` · CabalGate `0xe3717b69977d73b68aa2af798ddd4eec3609a4ed` · Seasons `0xde8334d251c65a9007f290a7cb71f0c98887bc54` · Laureates `0xd03e3fb2e916f8614891f68e2976c1481a6dc306` · PleaHook `0x2d5A03d5bAb98a4a435edad11813373963bcA8cC`. Cashback through imd/acc's Stacker `0x0457276d7b036818b3eddc1a4a3fceda61e9314d` (launch #1294).
  - Hook deployed `0x459b88c535915221918e4946a640cbac0ad055b428b98ab713761a761241e97e`, trading opened (`seed`) `0x5672d2f2c9aa9f4e9afca3f924e2aae245780f59c77824dbb05c001f7bbe864c`.
  - Buys with cashback stacked as sIMD in the same swap: `0x5adba10c753092e662f4ded21370cf27b97f5c43c5f6217d6c0f85fcc0f3a478`, `0xc53a65440cb3b9d517273b0bc4dc292189d284b03101cefcc0dff405f3a4699f`, and one from the site with a connected wallet `0xdfacd9ce6a591cae5c9f2d1297be2d5d89f2070e6ad3ef755fd4322c57e684e5`.
  - Approved plea (34 ≥ 33) `0x73778fe89d37b18acaadf19021cdcbe3f935156a243cf661e2ba1bce86ffc72b`, verdict `0x87311611ca8fae17786c81f9cf3c7392d3daa7df764e4ddd167e92ed1f77f52b`, sale `0xf83a2448d3bc4c210f2477b1e5a59328352baf3712d1ab621c155ddfd74946be` (exactly the previewed IMD), points `0x4b2d5cbce06274a4b8c585b2aa996e91c7bf70cb3f98abf75f878003f165a54d`. A second approval (34) `0x688f4d301a12f7f1968a51492610f06a9ea3b45606d2ff126c0b5d54cbe479f8` was sold by a watcher script 18 s after the verdict: `0x6a4eae4a3b9ba88fb742022b8a635b6d3dc06c048e065402ffaede027e82ca35`.
  - Plea and appeal through the site, both denied (32, then upheld 31): `0xb8ffb546f14f37e9f46a4a62f7a033882e9e79aee22a19912c3d95b326306cfa`, `0x210f4083de5b960480015e2e89bd6c16eed7eaf148fc03d7065eef147c29a6a3`.
  - Seasons closed: `0x5332df2d5d5ca53b8e73ebe690b02769f015e1da4db13f335b51155f3331074b` and `0xd9c704dd185c76c96674fc1e5472e7b8d71d91a0214f4dfbf5fcbac552b59282`: Laureates #1 and #2 minted on chain; nobody reached 60 points, so the IMD pot rolled over and each season's 5,000,000 PLEA bonus was burned, as designed. {Season 3: a wallet's two approvals in one season → IMD prize + 1,250,000 PLEA bonus, or burned}
- **PLEA v10 (launch #1242), the first full version:**
- **imd/acc live** (launch #1129, tx `0x9512b5df…c0f0`): Stacker `0x293c7134ab8f6bf1d8ff44ed806575f8f1baf477`, TestIMD `0x2b69099e59b05901faa1dd164fabf098bf831e82`, TestSIMD `0xf9e2eec3b610ec6781f7438ac5fb4bc049d81cc1`. Credit tx `0xaabe6a70…3252` minted sIMD to the trader with the correct `Stacked` event.
- **PLEA v2 live** (launch #1148, tx `0x655579bd…9525`): buys, cashback stacked through the hook, every transfer restriction tested (direct sells, other pools, routers and claims all blocked), and a signed oracle verdict delivered end to end.
- **v10 contracts:** launch #1242, deploy tx `0x9de8d4a7b24b04f2ee52fea389572341844d1a27d5a131f50194af83db833be8` (all IMD admission checks passed). PLEA `0x9b8d9aae44e81b1205e227911db279bde6edead9` · CabalGate `0x758b8300c62563591950f32717be44a5140a20f9` · Seasons `0x178481ac37e68a5c6ef95336db4616ba0169a17a` · Laureates `0xd2311b6d4c42a6dc3900a0a74a364b2775dd61c1` · PleaDistributor `0xabaecde2b71f0e3fa5d1b70f9a2bb9c24d6f3a7f` · PleaLaunch `0x29aa568f93d7d4d8255ba54b6201bbe1abd01ab4` · PleaHook `0x3d4CcAc329010b8beA3b14498d9a45EAB00c68Cc`.
  - Buy with cashback stacked as sIMD in the same swap: `0xdd664ab6768fe9e0f36c291ab440b198db15325c8c5b148d3c9e909ac2df1a8f`.
  - Denied plea (32 vs need 33) `0xae2a3742827b867f0e49fa1bebecfc7c0a888c7123f992fb7d6153e537c52335` and its appeal (31, denied) `0xa9e013c006a78a2c56b5ad22620b26b408ccd9eb177b975446500bee84736d0a`.
  - Approved plea (38 ≥ 33) `0xb63c5036ccb56271b60a2eb6c0c1c6b8dab14f77bc813d912107611034d8649f`, verdict `0x2fba5e0783d7367cabbb6998df5d9951cd5fe191c336d93d3c181a93d0bb28e3`, executed sell `0x3ad0bafcebbba2f333c432f14735bad2eab15557cc10de7b2f349485b074fcb8`.
  - Points recorded `0xf36682ce96343898e4104a605b5a23e58beb9b69daaba2acf282c15aa4073a59`.
  - Season 1 closed `0x8a7d608974019fca52a4d84774aa60b5556c60dac486dabd33e6ef8cd1a48914`: Laureate #1 minted on chain (full plea text in the SVG); no prize was due (38 < the 60-point minimum), so the pot rolled over as designed.
  - A plea that told the judges how to score got no verdict (13 of 28 judges zeroed it for manipulation): `0xfa20e8982619c87a939201bd79d360b8aaa69bd283a65f8eff14903ca0050a39`.
- **Next version (`testnet3`, ready for IMD test run 3):** 351 unit tests (incl. a Letterbox invariant suite and gas-pass equivalence tests), a 21-test Sepolia fork rehearsal (a letter sent as raw calldata through the live Intake v2, delivered by a runner; denial → appeal letter → no verdict → settle) and a 5-test mainnet fork rehearsal against the real IMD, sIMD, PoolManager and Intake v2. An independent pre-audit found no critical, high or medium issue; its three low findings are fixed. The launch was measured through IMD's real mainnet factory on a fork: 12.6M gas, under the 16.78M per-transaction cap with IMD's headroom. {Run 3 launch and live letters once deployed.}
- **v10, before launch:** 105 Foundry tests (both pool orientations, isolated launch rehearsal, oracle conformance); a Sepolia fork run (deploy 10.73M gas, 8/8 buys with plain gas estimates stacking sIMD through the live Stacker, a plea paid through the real Intake, approved via the callback, sold and recorded on the leaderboard); Slither clean of high-severity findings.
- **Oracle calibration:** test pleas through the Sepolia Intake set the scoring wording (strong ≈ 35–40, plain ≈ 25–30, weak or abusive under 15; prompt injections signed 0). Real panels signed numeric scores for v10's exact request body (35 and 21).

### Reproduce
- Build and test: `forge build && forge test` in https://github.com/khaed1/plea (Foundry 1.8.3).
- Try it: get test IMD from the imd/acc faucet, buy PLEA on the site, write a plea, watch the Wall and the season leaderboard.

### Known risks and admin powers
- **Selling may be refused.** That's the game; the dead-man guarantees an exit if the Cabal goes quiet for 33 hours.
- **Judges are AI agents.** Scores are subjective. A split panel gives no verdict; the plea expires after 20 minutes and the wallet can try again.
- **Points must be recorded.** The oracle callback only stores the score (it has 200k gas on mainnet), so points are recorded by a separate call that anyone can make (`record`, or `closeSeason` with a list of pleas); a letter's `deliver` records them in the same transaction.
- **Owner powers:** an add-only transfer allowlist (empty today), a one-time Merkle root for the 10% distributor, and opening trading early with `seed()` (anyone can once START passes). The owner can't change the oracle signer, the Intake, fees, timings or prizes, and from the next version can't win anything.
- **Testnet only:** seasons last 5 hours on Sepolia so a full cycle can be shown (15 days on mainnet; the contracts refuse shorter timings on chain id 1). TestSIMD's owner can pause it to test the cashback fallback. The test owner wallet is testnet-only; mainnet will use a fresh wallet.
- IMD's audit reports are in the launch repository; agent reviews are not a full security audit.

### Reused work (disclosed)
- **Concept:** CabalCoin by TokenWorks (sell-gating by plea); btc/acc by TokenWorks (cashback idea).
- **Code:** the hook is a fork of POOL4's `CappedBurnHook` (IMD side); TestSIMD is the verified StakedIMD source renamed; OpenZeppelin v5, Uniswap v4-core, forge-std, Solmate.
- **New during the event:** the oracle gate (Intake payment, callback verification, numeric score, fact score, appeals, expiry, dead-man), seasons, prizes and on-chain Laureates, same-swap fees and gas-safe cashback, the imd/acc Stacker and its points, the sites, and the calibration runs.

### What's next
- **Test run 3** (letters, auto-sell, 1% minimum, owner rule, six-season PLEA bonus, rules v2; the run-2 Laureate NFTs removed so the launch fits one mainnet transaction: 12.6M gas through IMD's factory), then **mainnet**: imd/acc's Stacker against the real IMD and sIMD, then PLEA pointing at it.
- **imd/acc listing:** PLEA's hook applied to imd/acc's oracle-run ProjectRegistry; the panel split on version 1 of its rules and said yes 11/13 in a version-2 rehearsal.
- **imd/acc v2:** cashback for ETH-fee projects, batched through POOL4 (`flush()`), so any IMD project can add it.
- **More Cabals:** themed judging moods (Rekt, Jester's, Loyal) were designed and calibrated on Sepolia; a proven rug scored 39, an FTX deposit 31, a story with no proof 21.
