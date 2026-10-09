# PondPad testnet run: 5 October 2026

Robinhood Chain Testnet (46630), 09:20 → 12:20 UTC. Deployment `contracts/deployments/46630.json` (commit `554da9e`), contract code unchanged from `b23fdc0` (the audit round 1 commit) apart from `Deploy.s.sol` taking chain values (D-62). Run by Claude from the testnet wallet `0x4b91…6821` (10 ETH from the user).

## 1. Health report

**Verdict: healthy. No contract bug found.** Every invariant held in all 111 snapshots; all 46 attacks were refused or bounded; all 12 POOL4 mechanics behaved as designed; the 2 unexpected reverts were both test-tool problems (§4), fixed during the run.

| Check | Result | Evidence |
|---|---|---|
| Curve solvency (I1) | OK | curve holds 109,828.01 IMD = exactly what the 122 coins still trading raised; checked every round at one pinned block |
| Coin supply, quotes (I4) | OK | no coin above 1B; curve quote = trade output on every IMD curve buy |
| Router keeps nothing (I9) | OK | 0 IMD, 0 USDG, 0 ETH after 2,693 transactions |
| Sale (I10) | OK | solvent throughout; sold exactly 600M; per-wallet 15M cap held; handed everything to the market (sale holds 0) |
| Market opened once (I11) | OK | `openedAt` 11:44:31 UTC, never moved; fee 3% falling on schedule |
| POOL4 mechanics (I12) | OK | 12/12 (§3) |
| Staking (I13, I14) | OK | value per share ×1.0455 since staking opened, never fell; holds and owner limits held |
| $PONDPAD supply (I22) | OK | 899.5M (100.5M burned by trims); deployer holds 0 |
| Fee split (I15) | OK | splitter emptied into PadBuyer 1,520 / WorkerFund 997 / GrowthFund 8,407 (incl. sale snipe tax and graduation fees) / treasury 598 IMD |
| Timelocks | OK | 600 s / 1,800 s; Safe-only proposals; nothing early; anyone executes after the delay |
| Attack suites | OK | 46 refused or bounded, 0 succeeded, 0 left unexercised (§2) |

## 2. Activity

| | |
|---|---|
| Bot rounds | 110 (24 trader bots in 8 behaviours + an 80-wallet sale crowd) |
| Transactions | 2,693 sent, 498 expected reverts (max-buy windows, sale not started, wallet cap), 2 unexpected (§4) |
| Coins | 167 launched (107 paid in IMD, 60 in ETH), **45 graduated**, 122 on the curve; buys in IMD 946, USDG 256, ETH 221; sells 332 |
| $PONDPAD sale | opened 11:20:55, filled and graduated at 11:44:31 (≈ 24 min, during the snipe-tax window); paid in IMD, ETH and USDG |
| Market | 36 min of trading; 100.5M $PONDPAD burned and 17.7M to stakers by trims; backstop deployed, filled and settled |
| Staking | 67 stakes; 44.7M staked at the end; drips raised the value per share by 4.5% |
| Keeper | collectFees, distribute, PadBuyer.buy ×3, drip ×2, rebalance ×3 (1 failed, §4), settleClaims, burn ×2 |
| Governance | a `PadConfig` change scheduled by the Safe, refused early, executed by another wallet after 10 minutes |
| ETH used | ≈ 2.7 ETH into the two pools, < 0.01 ETH of gas for everything else; 3.23 ETH left in the wallet, 4.82 ETH with the bots |

## 3. POOL4 mechanics (`pool4.mjs`, the $PONDPAD market)

| # | Mechanism | Result |
|---|---|---|
| A | Fee 3% → 1% over 7 days | 2.9986% at 435 s, exactly on the line |
| B | Cap follows buys down, at most 500k/day (D-21), never below the 150M floor | a 17M-token buy lowered the cap by 272 tokens (the allowance for that time) |
| C | Sells above the cap trimmed, 85% burn / 15% stakers | a 68M sell: 22.95M trimmed, split 19.51M / 3.44M (14.99%); 555 IMD kept for the backstop |
| D | Trim claims settle on a swap in a later block | burner +19.51M, dripper +3.44M one Ethereum block later |
| E | PadBurner burns what it holds | supply 999.2M → 979.7M (−19.51M exactly) |
| F | Retained IMD → keeper `rebalance` deploys a single-sided band above spot; tip ≤ 1 IMD | 581 IMD band at ticks 106,400+ above spot 106,187; tip 1 IMD |
| G | A dump fills the band; rebalance settles it | settled: 2.25M burned, 0.40M to stakers, 523 IMD back |
| H | `collectFees` empties both fee ledgers into the split | 189 IMD + 7.45M $PONDPAD |
| I | Outsiders can't add liquidity or open a pool on the hook | both refused by the hook |

## 4. Attack suites

| Group | Attacks | Result |
|---|---|---|
| Coins (K1–K7) | buy straight from the curve with the exemption flag; front-run graduation by initializing the pool; outside liquidity; partial fill with IMD specified; outside-router fee; self-referral; ETH amount mismatch | all refused (`Unauthorized`, `OnlySelf`, `PartialFill`, `WrongEthAmount`); outside router paid exactly 150 bps; self-referral earned 0 |
| Sale (S1–S3) | free the wallet cap by moving tokens away; force early graduation; open the market without the sale | cap unchanged after moving 12.25M out; `NotFull`; `Unauthorized` |
| Governance (G1–G8) | stranger changes settings, migrates the market, withdraws backstop IMD, rescues stake or rewards, fake airdrop claim, pays itself from GrowthFund, closes the backstop | all refused |
| Market (M1–M5) | sandwich PadBuyer after a pump; drag spot down then place the backstop; farm keeper tips; dust sells under the trim minimum at the cap; outside-router fee | `PriceOutOfRange`; band placed at 111,400 ≥ floor 111,246 (spot dragged to 105,635); tip 1 IMD against 48.6 IMD + 0.9M $PONDPAD of fees paid; largest untrimmed excess 606 < 1,000; fee exactly the current 2.9957% |
| Staking (ST1–ST7) | flash stake (same-block redeem); hand shares to a fresh wallet and redeem; round trip; stake 35.6M just before a drip; donate into the vault; owner calls; reward flow | refused (`RedeemMoreThanMax`: maxRedeem is 0 in the hold block); refused; no loss; profit = exactly the fair share of one drip (0.08% of the stake); donor kept only its 0.43% share; all `Unauthorized`; ×1.045 |
| Airdrop (AD1–AD14), on a test-only distributor with a real 104-wallet list | claim before activation; unlisted wallet; voucher not from the checker; stranger initiates; leaked checker key initiates; expired voucher; reused X account / tweet / wallet; 99 initiators; 100th; 101st; vesting; inflated amount; stranger claims; gasless claim wallet and replay; early sweep; stranger replaces the checker | all refused; 99 activate nothing, the 100th activates, the 101st is refused; a non-initiator claimed exactly amount × 23 s / 30 days; claim wallet paid without the listed wallet transacting, replay refused |

## 5. Findings

No contract bug. Things to act on, in order:

1. **`block.number` is Ethereum's block on Robinhood Chain** (Arbitrum Orbit: contracts see the parent chain's block, ~12 s, while Robinhood makes several blocks a second; checked on testnet and mainnet). Every "one block" rule is therefore one Ethereum block: the staking hold lasts ≥ ~12 s (stricter, fine), the market's reference tick and claim settlement lag per Ethereum block (as POOL4 does on Ethereum, fine), PadBuyer's guard compares against that lag (worked: M1). Nothing breaks, but **auditors should know**: proposed for `audit/THREAT-MODEL.md` (not edited without the user's go-ahead), and the fork tests' `vm.roll` doesn't model it.
2. **Market swaps and keeper calls need gas headroom.** The hook's `afterSwap` / `rebalance` work depends on state that changes between estimate and inclusion: a bot's market buy and a keeper rebalance ran out of gas at the estimate (98% used). Fixed in the keeper (+50%, commit with this report) and the bots; **the frontend and any integrator docs must add ~50% gas on $PONDPAD market swaps.**
3. **Thin ETH route.** The testnet IMD/ETH pool (2 ETH) moved from 411 to ~1,820 IMD per ETH because bots sold coins for ETH one way and no arbitrage exists on the testnet. Mainnet has ~70 ETH and arbitrage, but it confirms D-32: deepen IMD liquidity before the sale, and show route price impact in the UI.
4. **The sale needs ≥ 40 buyers** (600M at 15M per wallet). As designed (D-35); the UI should show the remaining allowance, and launch messaging should expect many wallets.
5. **Trims start only above the opening inventory.** The cap falls at most 500k/day (D-21), so in the first days sells are trimmed only when the price returns above where the market opened. Correct POOL4 behaviour; worth a line in the site's market explainer so "burns on sells" isn't over-promised.
6. **Testnet deploy has a placeholder airdrop root**, so the airdrop was tested on a separate distributor. Mainnet uses the real root from `airdrop/snapshot.py`.

Test-tool problems found and fixed during the run (not contract issues): invariant reads across several blocks gave one false curve-solvency alarm (now pinned to one block); a coin-list race at the pinned block; a bot ran out of test IMD (`TransferFromFailed`; bots now top up); master-nonce clashes between processes (keeper and airdrop test on their own wallets); a timelock call encoded with `uint256` instead of `uint16` (rescheduled, passed); a staking check expecting `SameBlockRedeem` where the vault refuses earlier with `RedeemMoreThanMax`.

## 6. Files

`onchain-report.md` (generated by `report.mjs` at block 129,267,779), and the raw results: `pool4-*.json`, `attacks-*.json`, `staking-*.json`, `airdrop-*.json`. Rerun everything with the commands in `launchpad/HANDOFF.md` §5b.
