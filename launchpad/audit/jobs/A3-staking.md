ID: A3
TITLE: Staking, funds and distribution
FILES:
contracts/src/StakedPONDPAD.sol
contracts/src/RewardDripper.sol
contracts/upstream/StakedIMD.sol
contracts/upstream/RewardDripper.sol
contracts/upstream/make_staking.py
contracts/src/PadBuyer.sol
contracts/src/FeeSplitter.sol
contracts/src/WorkerFund.sol
contracts/src/GrowthFund.sol
contracts/src/AirdropDistributor.sol
contracts/src/TeamVesting.sol
contracts/src/MarketController.sol
FOCUS:
Stakers' 40% of protocol IMD goes to PadBuyer, which buys $PONDPAD on the market in small price-guarded chunks and forwards it (plus the $PONDPAD fee share) to RewardDripper, which streams it into StakedPONDPAD (ERC-4626, sPONDPAD). Vault and dripper are generated from POOL4's StakedIMD and RewardDripper by upstream/make_staking.py with changes: limited, expiring owner powers (pause <= 3 days, no rescue of stake or reward buffer, all powers end at powersExpireAt) and a self-adjusting drip (buffer x elapsed / smoothing period). Airdrop: 50M by Merkle root, activated after market open by 100 listed wallets with a coded X post and a tweet-checker voucher, 30-day vesting, gasless claim-wallet delegation, sweep to the dripper after 180 days. Team vesting: 20M, cliff 30 days, linear to 180 days from MarketController.openedAt.
Changed since round 1 (D-78): StakedPONDPAD holds only the shares that arrived in the current block (heldShares; transfers move unheld shares first); RewardDripper waits for 1e24 real vault shares; a pause ends by powersExpireAt; PadBuyer tip clamp; AirdropDistributor setClaimWallet uses up the nonce and setClaimWalletAndClaim skips a delegation already in place.
Changed since round 2 (D-79): StakedPONDPAD counts its own assets (trackedAssets; plain transfers count only through syncRewards, which works only while rewards are open: >= 1e18 shares and 1 $PONDPAD staked; rewardsOpenSince); RewardDripper drips only while the vault is open, forfeits closed time, takes each drip in with syncRewards; bounds 1 h <= maxCatchup <= smoothing / 7 and minDripAmount <= 100,000 (make_staking.py); over-balance sPONDPAD transfers revert InsufficientBalance; Deploy checks the airdrop claims total <= 50M.
Changed since round 3 (D-80): the dripper's minimum-drip floor is capped at 1/7 of the buffer and a remainder under 1 $PONDPAD is swept; the vault's hold bookkeeping runs for transfers to address(0); vault, dripper and PadBuyer owners are fixed (FixedOwnable via make_staking.py); PadBuyer's reference tick catches up over blocks without swaps (make_fork.py); FeeSplitter.distributeToken only $PONDPAD; Deploy adds up the airdrop claims and rebuilds the root.
Changed since round 4 (D-83): make_staking.py: no sPONDPAD minted or sent to address(0) or to the vault itself (InvalidReceiver in _deposit and transfer / transferFrom overrides; burns unaffected), rescueERC20 refuses sPONDPAD itself, the upstream "sweep the staked asset" text replaced, syncRewards documents that only the dripper should send $PONDPAD (a stray transfer is one lump, accepted); PadBuyer reads market.referenceTick() instead of refTick and refuses minChunk 0; AirdropDistributor checks the signer's own key first, then ERC-1271 (EIP-7702 wallets); Deploy refuses an airdrop list under 100 wallets; invariant 13 says PadBuyer's settings don't expire (D-43).
Look hardest at:
- Vault: inflation/donation attacks (6-decimal offset), one-block hold and share transfers, reward capture by depositing just before a drip, rounding in deposit/mint/withdraw/redeem.
- Dripper: can drip() be gamed (timing, empty vault, tiny buffer, catch-up), can a setter or rescue reach the buffer, do powers really expire?
- PadBuyer: price guard vs. manipulated refTick, sandwich bounds, keeper tip, can IMD or $PONDPAD go anywhere but the dripper?
- FeeSplitter / WorkerFund / GrowthFund: sums, ranges, epoch caps, uncapped tokens.
- AirdropDistributor: leaf/proof format (OZ StandardMerkleTree, double-hashed), initiation voucher binding (wallet, X account, tweet, code, deadline), counting 100 distinct listed wallets, claim-wallet EIP-712/ERC-1271 signatures and nonces, vesting math, sweep timing; TeamVesting schedule.
