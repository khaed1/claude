# PondPad testnet report

Robinhood Chain Testnet (46630), state at block 129267779, generated 2026-10-05T12:20:47.760Z. Bot logs: 2026-10-05T09:23:36.882Z → 2026-10-05T12:19:26.372Z.

## Health: ATTENTION NEEDED

| Check | Result | Detail |
|---|---|---|
| Curve solvency (I1) | OK | curve holds 109,828.01 IMD, coins still trading raised 109,828.01 IMD |
| Router holds nothing (I9) | OK | IMD 0, USDG 0, ETH 0 |
| Sale solvency (I10) | OK | Graduated: holds 0 IMD, raised 0 IMD, sold 600,000,000 $PONDPAD |
| $PONDPAD supply (I22) | OK | supply 899,508,971, deployer holds 0 |
| Market opened once, at graduation (I11) | OK | open since 2026-10-05T11:44:31.000Z, fee 2.993% |
| Staking value per share (I13) | OK | 1.045462110812 $PONDPAD-units per sPONDPAD unit (starts at 1.0) |
| Timelocks | OK | 600 s / 1800 s |
| Bots: unexpected reverts | **FAIL** | 2 |
| Bots: invariant violations | OK | 0 in 111 checks |
| Attack suite | OK | 46 blocked, 0 succeeded, 0 not exercised |
| POOL4 mechanics (market) | OK | 12/12 checks |

## Activity

- Rounds: 110, invariant checks: 111, actions: 2693 sent, 498 expected reverts, 2 unexpected.
- Coins: 167 launched, 45 graduated, 122 still on the curve.
- Keeper calls: FeeSplitter.distribute ×1, MarketController.collectFees ×1, PadBuyer.buy ×3, RewardDripper.drip ×1, PadBurner.burn ×1, PadMarketHook.settleClaims ×1, PadMarketHook.rebalance ×3.

| Action | Count |
|---|---|
| buy imd | 946 |
| approve | 375 |
| buy usdg | 256 |
| buy eth | 221 |
| sell imd | 150 |
| sell eth | 109 |
| launch imd | 107 |
| sell usdg | 73 |
| refill crowd | 70 |
| stake | 67 |
| sale buy crowd | 63 |
| launch eth | 60 |
| mint to bot | 48 |
| market buy | 41 |
| market sell | 29 |
| sale buy | 19 |
| refill bot | 12 |
| sale buy eth | 12 |
| sale buy usdg | 11 |
| unstake | 10 |
| refill eth bot | 7 |
| sale sell | 5 |
| mint for liquidity | 1 |
| deepen IMD/ETH | 1 |
| buy imd → The contract function "buyWith" reverted with the following signature:
0x7939f424 | 1 |
| market buy → reverted onchain | 1 |

## $PONDPAD

| | |
|---|---|
| Sale | Graduated, raised 0 IMD, sold 600,000,000 |
| Market | open, fee 2.993%; burned 100,490,729, rewarded to stakers 17,733,658, backstop IMD 0; unclaimed fees 0 IMD + 0 $PONDPAD |
| Supply | 899,508,971 (sale 0, airdrop 50,000,000, vesting 20,000,000, reserve 30,000,000, dripper 26,820,919) |
| Staking | 44,743,935 $PONDPAD staked, value per share ×1.045462110812 |

## Fee flows (IMD held now)

| Splitter | PadBuyer (stakers) | WorkerFund | GrowthFund | Treasury (Safe) | CreatorVault | SwarmBudget | IntegratorVault |
|---|---|---|---|---|---|---|---|
| 0 | 1,520.11 | 996.94 | 8,407.27 | 598.17 | 2,046.52 | 831.71 | 0 |

## ETH

Testnet wallet 3.2308 ETH; bots 4.8211 ETH in total.

## POOL4 mechanics ($PONDPAD market, 2026-10-05T11:52:53.822Z)

12 of 12 checks passed (tester 0x99135dF51fA80a58764E8b3794CAbcfc0990d048).

| # | Mechanism | Result | Detail |
|---|---|---|---|
| A | Fee schedule 3% → 1% over 7 days | OK | 2.9986% at 435 s after open (expected 2.9986%) |
| B | Ratchet: cap follows buys down at most 500k/day, never below the floor | OK | inventory 273,971,594.2412 → 256,738,935.1655; cap 299,997,425.6944 → 299,997,153.7037 (allowed drop 284.5648), floor 150,000,000 |
| C1 | Trim: inventory back at the cap after a sell above it | OK | sold 68,258,218.5382; inventory 299,997,066.8981, cap 299,997,066.8981; trimmed 22,953,368.2735 $PONDPAD + 555.0564 IMD retained |
| C2 | Trim split 85% burn / 15% stakers (D-21) | OK | to burn 19,510,363.0325, to stakers 3,443,005.241 (14.99%) |
| D | Claims settle to the burner and the stakers' dripper | OK | burner 0 → 19,510,363.0325, dripper 982,726.4773 → 4,425,731.7183, open burn claims 0 |
| E | PadBurner burns: $PONDPAD supply falls by what it held | OK | burned 19,510,363.0325, supply 999,197,457.267 → 979,687,094.2346 |
| F1 | Trims retain IMD for the backstop (≥ 40 IMD → rebalance due) | OK | retained 581.5053 IMD, pendingRebalance true |
| F2 | rebalance() deploys a single-sided IMD band above spot | OK | band ticks 106400…887200 above spot 106187, 580.5053 IMD |
| F3 | Keeper tip ≤ 1 IMD and ≤ the fee on the work (D-41) | OK | 1 IMD |
| G | A dump fills the backstop; rebalance settles it (burns what it bought) | OK | settled: to burn 2,252,463.8393, to stakers 397,493.6187, IMD back 523.2899 |
| H | collectFees: both fee ledgers to the 40/25/20/15 split | OK | collected 189.2979 IMD + 7,447,526.4452 $PONDPAD |
| I | Outsiders can't add liquidity or open another pool on the hook | OK | addLiquidity → 0x90bfb865; initialize → 0x90bfb865 |

## Attack suites

Attacker wallets tried each attack on the live contracts. K = coin trading, S = sale, G = governance and owner powers, M = $PONDPAD market (POOL4 fork), ST = staking, AD = airdrop. OK = refused or bounded as THREAT-MODEL.md §2 requires.

| # | Attack | Result | Detail |
|---|---|---|---|
| K1 | Curve bypass: buy directly from BondingCurve with the exemption flag | OK | refused: Unauthorized |
| K2 | Graduation front-run: initialize a trading coin's pool | OK | refused: OnlySelf (via hook) |
| K3 | Outside liquidity in a graduated coin pool | OK | refused: OnlySelf (via hook) |
| K4 | Partial fill with IMD specified (D-26) | OK | refused: PartialFill (via hook) |
| K5 | Fee through an outside router (any router pays, D-26) | OK | fee 0.15 IMD on 10 IMD = 150 bps (coin: 150 bps) |
| K6 | Self-referral earns nothing (unregistered referrer, D-33) | OK | vault 0 IMD, pending 0 IMD |
| K7 | ETH amount mismatch | OK | refused: WrongEthAmount |
| S1 | Wallet cap not freed by moving tokens away | OK | allowance 2,747,083.1602 before and 2,747,083.1602 after moving 12,252,916.8398 $PONDPAD out |
| S2 | Force the sale to graduate early | OK | refused: NotFull |
| S3 | Open the market without the sale | OK | refused: Unauthorized |
| G1 | Stranger changes launch settings | OK | refused: Unauthorized |
| G2 | Stranger migrates the market (D-40) | OK | refused: Unauthorized |
| G3 | Stranger withdraws the market's retained IMD | OK | refused: Unauthorized |
| G4 | Stranger rescues staked $PONDPAD | OK | refused: Unauthorized |
| G5 | Stranger rescues the dripper's rewards | OK | refused: Unauthorized |
| G6 | Fake airdrop claim | OK | refused: NotActive |
| G7 | Stranger pays itself from GrowthFund | OK | refused: Unauthorized |
| G8 | Stranger closes the market backstop | OK | refused: Unauthorized |
| M1 | Sandwich PadBuyer after a pump (price guard, D-43) | OK | refused: PriceOutOfRange |
| M2 | Backstop placement can't be dragged below its floor | OK | spot dragged to tick 105635; band placed at 111400 ≥ floor 111246 |
| M3 | Keeper-tip farming doesn't pay (tip ≤ 1 IMD, below fees paid) | OK | tip 1 IMD; attacker paid 48.5871 IMD + 906,776.1602 $PONDPAD in fees (at 2.9956%) to create the work |
| M4 | Dust sells can't build up untrimmed inventory | OK | 10 sells of 900 at the cap: largest untrimmed excess 606.3033 (< min trim 1,000); inventory 299,992,001.9028, cap 299,991,395.6019 |
| M5 | Market fee through an outside router (D-34) | OK | fee ledger +2.9956 IMD on 100 IMD at 2.9957% (expected 2.9957; 0 means collectFees ran in between) |
| ST1 | Flash stake: redeem in the deposit's block | OK | refused: RedeemMoreThanMax (deposit at block.number 11848716, the Ethereum block; Robinhood block 129262729) — maxRedeem is 0 during the hold block, so the ERC-4626 check refuses before SameBlockRedeem (same protection) |
| ST2 | The one-block hold travels with transferred shares | OK | fresh wallet's redeem refused: RedeemMoreThanMax — maxRedeem is 0 during the hold block, so the ERC-4626 check refuses before SameBlockRedeem (same protection) |
| ST3 | Stake / redeem round trip loses nothing but rounding | OK | deposited 500,000 (kept half the shares), got back 500,000 |
| ST4 | Drip sniping is bounded to the stake's share of one drip (smoothed over 7 days, D-44) | OK | staked 35,638,139.6825 next to 28,156,614.7797; one drip added 52,738.929; profit 29,461.9414 vs fair share 29,461.9414 (0.0827% of the stake) |
| ST5 | Donation is a gift to all stakers (donor gets back only its own share) | OK | donated 1,000,000; donor's value +4,341.6409 (its 0.43% share of the gift), the rest went to other stakers |
| ST6 | Owner-only staking calls refused for strangers | OK | pause the vault: Unauthorized; rescue staked $PONDPAD: Unauthorized; shorten the drip smoothing: Unauthorized; rescue the dripper's rewards: Unauthorized; raise the keeper reward: Unauthorized |
| ST7 | Rewards reached stakers: value per share rose | OK | value per share ×1.044711 (×1 at open; ×1.000414 when this test started) |
| AD1 | Claim before activation | OK | refused: NotActive |
| AD2 | Initiation by a wallet not on the list | OK | refused: InvalidProof |
| AD3 | Voucher signed by someone else | OK | refused: BadVoucher |
| AD4 | A stranger initiates for a listed wallet | OK | refused: NotAuthorized |
| AD5 | Leaked checker key initiates by itself | OK | refused: NotAuthorized |
| AD6 | Each X account, tweet and wallet counts once | OK | reused X account: HandleUsed; reused tweet: TweetUsed; same wallet again: AlreadyInitiated |
| AD7a | Expired voucher | OK | refused: Expired |
| AD7b | 99 initiations activate nothing (no fallback, D-55) | OK | count 99, activatedAt 0 |
| AD7c | Still no claims at 99 | OK | refused: NotActive |
| AD8 | The 100th initiation activates the airdrop; later ones are refused | OK | activatedAt 1791202720 (the 100th's block); 101st: AlreadyActive |
| AD9 | A non-initiator claims exactly amount × elapsed / 30 days | OK | allocation 61,000; 23 s after activation got 0.5413 (expected 0.5413) |
| AD10 | Claim with an inflated amount | OK | refused: InvalidProof |
| AD11 | A stranger claims for someone else | OK | refused: NotAuthorized |
| AD12 | Gasless claim wallet works; its signature can't be replayed | OK | claim wallet received 0.6406, the listed wallet never sent a transaction; replay: BadSignature |
| AD13 | Sweep before the 180-day claim window ends | OK | refused: ClaimWindowNotOver |
| AD14 | Stranger can't replace the checker key; claims ≤ funding | OK | setVerifier: Unauthorized; claimed 1.1819 of 3,718,000 funded |

## Problems

- 2026-10-05T10:02:44.639Z UNEXPECTED-REVERT buy imd: The contract function "buyWith" reverted with the following signature:
0x7939f424
- 2026-10-05T11:47:56.532Z UNEXPECTED-REVERT market buy: reverted onchain
