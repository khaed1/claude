You're auditing **PLEA test run 3** before it is submitted to the IMD swarm (imd.fun) for launch on Sepolia, and later on Ethereum mainnet with the same code. IMD will run its own audit too; yours is an independent pre-audit. Explain simply, be concrete, and prove every finding with a test.

## What PLEA is
A sell-gated meme token on Uniswap v4. Buying is open. While "the Cabal" (a 30-judge IdentityMD oracle panel, quorum 17) lives, selling needs a plea: the panel scores it 0–45, and it passes if score ≥ 70 − an on-chain fact score. Approved → sell within 7 minutes through the gate; denied → one appeal; 4-hour cooldowns. The Cabal dies after 33h without a signed verdict, then trading is free forever. Seasons: approved pleas earn points; the top 10 with ≥ 60 points share the IMD prize pot and, in the first six seasons, 5,000,000 PLEA each. One hook (fork of POOL4's CappedBurnHook) takes 1.75% per trade (0.5% cashback staked as sIMD through imd/acc's Stacker, 0.5% owner, 0.25% prize pot, 0.25% locked liquidity, 0.25% PLEA burn).

**New in run 3** (on top of run 2, which IMD audited and deployed):
- **Letters + auto-sell:** a new ownerless `Letterbox`. Anyone pleads by sending a transaction whose input data is the plea text (fallback), or `letter(text)` from Etherscan's Write tab; commands `APPEAL`, `SELL`, `NAME`. A letter pleads 10% of the writer's PLEA, held in escrow; the oracle fee, a 0.25 IMD runner tip and an appeal's 0.35 IMD wall share are paid in the same transaction by the gate selling the writer's PLEA (exact-output swap, capped at the hourly snapshot value + 10%; on Sepolia the 0.5 test oracle fee is minted instead). Anyone `deliver`s an approved plea (≥ 95% of snapshot value) for the tip; `settle` refunds escrow + tip otherwise. `status`/`leaderboard` text views; display names (`setName` / `NAME`).
- The Letterbox is an **exempt sender** in PLEA and can move a wallet's PLEA with `PLEA.courtTake` (only the Letterbox may call it). It is **deployed after the launch** by anyone via `PleaLaunch.deployLetterbox(creationCode)`, which checks the code against a hash committed in launch.json; the Letterbox has no constructor arguments and reads its settings from PleaLaunch.
- **Laureates (season NFTs) removed**; Seasons no longer ranks pleas or mints.
- 1% minimum plea; the owner can't play (no points, prizes, bonus, keeper tip); six-season PLEA bonus (87/3/10 supply split); Cabal judging rules v2 (`CabalGate.DEFINITIONS`).
- A gas pass "with no behaviour change": the oracle body JSON-escapes only the plea texts (assembly `_escape`), `_validateText` reads bytes through an unchecked `_at`, `PleaHook.latestPrice`/`price24hAgo` read one checkpoint (`lastCheckpointHour`) and scan the ring only as a fallback, a one-slot Letterbox escrow (`uint88` amount).
- Launch = five contracts in one transaction (PLEA → CabalGate → Seasons → PleaDistributor → PleaLaunch); hook and Letterbox deployed after.

## The code
- **Audit target:** public repo `https://github.com/khaed1/plea`, branch `testnet3`, commit **`0325c53498ee9a939f734f954f523ab0502ed6b0`** (clone read-only; do not push to it).
- **Baseline (audited by IMD, live as run 2):** `https://github.com/identity-md-launches/launch-1311-launch-plea-test-run` commit `fb8c0ae5`. Review the diff first: `git diff fb8c0ae5 0325c53 -- src launch.json` (fetch both into one clone).
- Background (read, don't change): `khaed1/claude` branch `claude/adoring-goodall-pn3jyz`: `plea/letters-spec.md`, `plea/cabal-rules-review.md`, and `HANDOFF.md` from "Run 2 live test" to the end.

## Focus, in this order
1. **Selling without approval while the Cabal lives.** Any path that gets PLEA into the pool or to another wallet without an oracle-approved plea, beyond the capped fee sale: the Letterbox exemption, `courtTake`, the fee swap, escrow/`settle`/`deliver`, the fallback and `letter()` parsing, `PleaLaunch.deployLetterbox`, Cabal death mid-escrow.
2. **Theft or loss of escrows and tips.** Accounting of open escrows and the 0.25 IMD tips; double refund or double sale; reentrancy (transient `nonReentrant`); races between `deliver`, `SELL`, `settle`, a writer's next letter, appeals, Intake failures (`onPleaFailure`) and expiry; season closes; `uint88` amounts.
3. **The post-launch Letterbox.** Is the code-hash commitment sound; can `deployLetterbox` be front-run or griefed; can anything else become `PLEA.letterbox`; the constructor reading `msg.sender`; the Sepolia mint flag on chain id 1.
4. **Letter parsing and function IDs.** No external/public Letterbox function ID may be the start of valid control-free UTF-8 (a test checks the ABI; verify the rule itself). Edge cases: `APPEAL`/`SELL`/`NAME` with spaces, newlines, lower case, empty text, unicode, 280-byte limits.
5. **The gas pass.** `_escape` (assembly, memory safety, output identical to escaping the whole question), `_validateText` with `_at` (any out-of-bounds read, any accepted text the old rules refused), the hook's price views versus a full ring scan, the `uint88` escrow cast.
6. **Oracle path.** Body/JSON validity with hostile plea texts, `[PLEA]` markers, callback gas (200k on mainnet: `onOracleResult` and `onPleaFailure`), request-id consumption, appeals.
7. **Fee swap and auto-sell pricing.** Snapshot vs. spot manipulation, sandwiching the fee swap or `deliver`, the 10% cap and 95% minimum, runner incentives, the hook's gas reserve (`creditGas` + 1M) when called through the Letterbox.
8. **Seasons.** Owner exclusion everywhere (points, prizes, bonus, keeper tip), the six-season bonus paid/burned exactly once, `flushToWall`, closing with and without the Cabal.
9. **Launch.** launch.json vs. constructors; the five-contract transaction must fit Ethereum's 16,777,216-gas cap with ~22% gas-limit headroom (`test/LaunchManifest.t.sol` asserts it); `PLEA.setLauncher` deploy-tx/deploy-block rule.

Agreed numbers (report a bug, don't propose changes): fees 1.75% (0.5/0.5/0.25/0.25/0.25); panel 30, quorum 17; dead-man 33h; pending expiry 20 min; sell window 7 min; cooldown 4h; seasons 5h Sepolia / 15 days mainnet; 60-point minimum, shares 25/18/14/11/9/7/6/4/3/3; split 87/3/10; bonus 6 × 5,000,000 PLEA; minimum plea 1% (or 2.5M); letters 10%, tip 0.25 IMD, 95% sale minimum, fee cap +10%, letter minimum 1,000 PLEA, fees ≤ 10% of the balance; rules v2 text exactly as in `CabalGate.DEFINITIONS`.

## How to work
- Foundry 1.8.3: download `foundry_v1.8.3_linux_amd64.tar.gz` from the foundry-rs GitHub release into `~/.foundry/bin`. The first `forge build` takes ~15 minutes (via_ir). Expected: `forge test` → 339 passed, 2 skipped (the fork suites). Fork suites: `SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com forge test --match-path test/fork/ForkTestnet.t.sol` (21) and `MAINNET_RPC_URL=https://ethereum-rpc.publicnode.com forge test --match-path test/fork/ForkMainnet.t.sol` (5).
- For every finding, write a failing Foundry test in your local clone that demonstrates it (use `test/utils/Fixture.sol`; `test/Letterbox.t.sol` and `test/LetterboxInvariant.t.sol` show the patterns). Extend the invariant suite if it helps. Slither is optional.
- **Read only:** no pushes to `khaed1/plea`, no transactions on any chain, no keys, don't touch IMD job files.

## Report
Write `plea/audit-run3-0325c53.md` and push only that file to `khaed1/claude` branch `claude/adoring-goodall-pn3jyz` (attach the repo with push access if needed; `git fetch` first and merge, never rebase or force-push: another session pushes to this branch). If you can't push, give the whole report in your reply.

Contents:
1. **Verdict** in one line: ready to submit, or fix first.
2. **Findings**, most severe first: severity (critical/high/medium/low/info), `file:line`, what goes wrong in plain words, the exploit or failure path, the PoC test (name, and that it fails on `0325c53`), and the smallest fix as a diff. Note any fix that would change an agreed number or push CabalGate (24,292 B, 284 under EIP-170) over its limit.
3. **Checked and fine:** each focus area you cleared, with one line on how.
4. Any test you added, pasted in full so it can be committed.
