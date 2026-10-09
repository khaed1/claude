// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "solady/auth/Ownable.sol";
import {ERC4626} from "solady/tokens/ERC4626.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {MarketBase} from "./Market.t.sol";
import {MockIMD} from "./Base.t.sol";
import {StakedPONDPAD} from "../src/StakedPONDPAD.sol";
import {RewardDripper} from "../src/RewardDripper.sol";
import {PadBuyer} from "../src/PadBuyer.sol";
import {FeeSplitter} from "../src/FeeSplitter.sol";
import {FixedOwnable} from "../src/FixedOwnable.sol";
import {PadMarketHook} from "../src/PadMarketHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

contract StakingTest is MarketBase {
    StakedPONDPAD internal sVault;
    RewardDripper internal rewards;
    PadBuyer internal buyer;
    uint256 internal expiry;

    address internal staker = makeAddr("staker");
    address internal keeper = makeAddr("keeper");

    function setUp() public override {
        super.setUp();
        expiry = block.timestamp + 365 days;
        sVault = new StakedPONDPAD(address(pondpad), slowTimelock, expiry);
        rewards = new RewardDripper(address(pondpad), address(sVault), timelock, 7 days, 1 days, 10e18, 1_000e18, expiry);
        buyer = new PadBuyer(timelock, address(imd), address(pondpad), address(pm), address(controller), address(rewards));
        // Wire the stakers' paths: the market's trim share and the splitter's 40% both reach the dripper.
        vm.prank(slowTimelock);
        controller.setRewardsRecipient(address(rewards));
        splitter.setRecipients(
            FeeSplitter.Recipients({stakers: address(buyer), workers: workers, growth: growth, treasury: treasury})
        );
        pondpad.transfer(staker, 10_000_000e18);
        vm.prank(staker);
        pondpad.approve(address(sVault), type(uint256).max);
    }

    function _stake(uint256 amount) internal returns (uint256 shares) {
        vm.prank(staker);
        shares = sVault.deposit(amount, staker);
    }

    // ------------------------------------------------------------------ Vault

    function test_vault_depositHoldAndRedeem() public {
        assertEq(sVault.symbol(), "sPONDPAD");
        uint256 shares = _stake(1_000_000e18);
        vm.prank(staker);
        vm.expectRevert(ERC4626.RedeemMoreThanMax.selector); // maxRedeem is 0 in the deposit block
        sVault.redeem(shares, staker, staker);
        _nextBlock();
        vm.prank(staker);
        uint256 back = sVault.redeem(shares, staker, staker);
        assertApproxEqAbs(back, 1_000_000e18, 1);
    }

    /// @dev Audit R1-A3-2: a stranger's dust deposit or 1-share transfer must not hold the staker's older shares;
    ///      a fresh deposit stays fully held wherever it is transferred.
    function test_vault_strangerDustHoldsOnlyTheDust() public {
        address griefer = makeAddr("griefer");
        address fresh = makeAddr("fresh");
        pondpad.transfer(griefer, 1_000e18);
        uint256 shares = _stake(1_000_000e18);
        _nextBlock();
        vm.startPrank(griefer);
        pondpad.approve(address(sVault), type(uint256).max);
        sVault.deposit(1, staker); // dust minted to the staker
        uint256 gShares = sVault.deposit(100e18, griefer);
        sVault.transfer(staker, 1); // a held share sent to the staker
        sVault.transfer(fresh, gShares - 1); // the rest of a fresh deposit moved to a clean wallet
        vm.stopPrank();
        assertEq(sVault.maxRedeem(staker), shares, "older shares stay redeemable");
        vm.prank(staker);
        sVault.redeem(shares, staker, staker);
        assertEq(sVault.maxRedeem(fresh), 0, "a fresh deposit is held wherever it goes");
        vm.prank(fresh);
        vm.expectRevert(ERC4626.RedeemMoreThanMax.selector);
        sVault.redeem(1, fresh, fresh);
        _nextBlock();
        assertEq(sVault.maxRedeem(fresh), gShares - 1);
    }

    /// @dev Audit R1-A3-7: a pause started just before the powers expire ends when they do.
    function test_vault_pauseNeverOutlivesPowers() public {
        _stake(1_000e18);
        vm.warp(expiry - 1);
        vm.prank(slowTimelock);
        sVault.setPaused(true);
        assertTrue(sVault.paused());
        vm.warp(expiry);
        assertFalse(sVault.paused(), "pause ends with the owner's powers");
    }

    function test_vault_pauseIsShortAndCannotRepeatAtOnce() public {
        _stake(1_000e18);
        vm.prank(slowTimelock);
        sVault.setPaused(true);
        assertTrue(sVault.paused());
        _nextBlock();
        vm.prank(staker);
        vm.expectRevert(ERC4626.RedeemMoreThanMax.selector); // maxRedeem is 0 while paused
        sVault.redeem(1, staker, staker);

        // Ends by itself after 3 days; a new pause needs 4 more days.
        vm.warp(block.timestamp + 3 days);
        assertFalse(sVault.paused());
        vm.prank(slowTimelock);
        vm.expectRevert(StakedPONDPAD.PauseCooldown.selector);
        sVault.setPaused(true);
        vm.warp(block.timestamp + 4 days);
        vm.prank(slowTimelock);
        sVault.setPaused(true);
        vm.prank(slowTimelock);
        sVault.setPaused(false); // resuming early is always allowed
        assertFalse(sVault.paused());
    }

    function test_vault_rescueNeverTouchesStakeAndPowersExpire() public {
        _stake(1_000e18);
        vm.prank(slowTimelock);
        vm.expectRevert(StakedPONDPAD.CannotRescueStake.selector);
        sVault.rescueERC20(address(pondpad), slowTimelock, 1);

        MockIMD stray = new MockIMD();
        stray.mint(address(sVault), 5e18);
        vm.prank(slowTimelock);
        sVault.rescueERC20(address(stray), slowTimelock, 5e18);
        assertEq(stray.balanceOf(slowTimelock), 5e18);

        vm.expectRevert(Ownable.Unauthorized.selector);
        sVault.setPaused(true);
        vm.warp(expiry);
        vm.prank(slowTimelock);
        vm.expectRevert(StakedPONDPAD.PowersExpired.selector);
        sVault.setPaused(true);
    }

    // ------------------------------------------------------------------ Dripper

    function test_dripper_streamsTrimRewardsIntoVault() public {
        _graduate();
        _swap(false, 10_000_000e18); // trim: 15% to the dripper
        _nextBlock();
        market.settleClaims();
        uint256 buffered = pondpad.balanceOf(address(rewards));
        assertGt(buffered, 1_000_000e18);

        // Never into an empty vault.
        uint256 t0 = START + 30 minutes; // constant: a saved block.timestamp can be re-read under via-IR
        assertEq(block.timestamp, t0);
        vm.warp(t0 + 1 hours);
        vm.expectRevert(RewardDripper.VaultEmpty.selector);
        rewards.drip();

        _stake(1_000_000e18);
        // The hour before anyone staked is forfeited, not banked (audit R2-A3-3): the stream starts now.
        assertFalse(rewards.canDrip());
        vm.warp(t0 + 2 hours);
        uint256 assetsBefore = sVault.totalAssets();
        vm.prank(keeper);
        (uint256 toVault, uint256 tip) = rewards.drip();
        assertEq(toVault + tip, buffered * 1 hours / 7 days, "1/168 of the buffer per hour");
        assertEq(tip, 10e18);
        assertEq(sVault.totalAssets() - assetsBefore, toVault);
        assertGt(sVault.convertToAssets(sVault.balanceOf(staker)), 1_000_000e18);

        // A long gap releases at most one day's share (1/7 of the buffer), never the whole buffer.
        uint256 left = pondpad.balanceOf(address(rewards));
        vm.warp(t0 + 30 days);
        (toVault, tip) = rewards.drip();
        assertEq(toVault + tip, left * 1 days / 7 days);
    }

    function test_dripper_lumpDrainsOverAboutAWeek() public {
        _stake(1_000_000e18);
        pondpad.transfer(address(rewards), 7_000_000e18);
        uint256 t0 = START + 1 hours; // a constant: under via-IR a saved block.timestamp can be re-read after warps
        vm.warp(t0);
        rewards.drip(); // starts the clock at t0 (pays out ~1/168 of the lump)
        for (uint256 h = 1; h <= 21 * 24; h++) {
            vm.warp(t0 + h * 1 hours);
            if (rewards.canDrip()) rewards.drip();
            if (h == 7 * 24) {
                // ~e^-1 = 36.8% still waiting after one smoothing period
                assertApproxEqRel(pondpad.balanceOf(address(rewards)), 7_000_000e18 * 368 / 1000, 0.03e18);
            }
        }
        // ~5% left after three weeks
        assertApproxEqRel(pondpad.balanceOf(address(rewards)), 7_000_000e18 * 50 / 1000, 0.05e18);
    }

    function test_dripper_smallBufferStillSweeps() public {
        _stake(1_000e18);
        pondpad.transfer(address(rewards), 500e18); // below the 1,000 minimum
        uint256 t0 = START + 30 minutes; // constant: a saved block.timestamp can be re-read under via-IR
        assertEq(block.timestamp, t0);
        vm.warp(t0 + 1 hours);
        assertFalse(rewards.canDrip());
        vm.expectRevert(RewardDripper.BelowMinDrip.selector);
        rewards.drip();
        vm.warp(t0 + 1 days);
        vm.prank(keeper);
        (uint256 toVault, uint256 tip) = rewards.drip();
        assertEq(toVault, uint256(500e18) / 7, "a full window drips a seventh, never the whole buffer (audit R3-A3-1)");
        assertEq(tip, 0, "no tip below the minimum");
        // It keeps draining a seventh per window, and a remainder under one $PONDPAD is swept in full.
        for (uint256 d = 2; d <= 60; d++) {
            vm.warp(t0 + d * 1 days);
            if (rewards.canDrip()) rewards.drip();
        }
        assertEq(pondpad.balanceOf(address(rewards)), 0);
    }

    /// @dev Audit R1-A3-1: a 1-wei first stake is not a real staker; rewards wait instead of leaking half of every
    ///      drip to the vault's virtual shares.
    function test_dripper_waitsForRealStakeNotDust() public {
        address dust = makeAddr("dust");
        pondpad.transfer(dust, 1e18);
        pondpad.transfer(address(rewards), 70_000e18);
        vm.startPrank(dust);
        pondpad.approve(address(sVault), type(uint256).max);
        sVault.deposit(1, dust);
        vm.stopPrank();
        vm.warp(START + 30 minutes + 1 days);
        _nextBlock();
        assertFalse(rewards.canDrip());
        vm.expectRevert(RewardDripper.VaultEmpty.selector);
        rewards.drip();
        _stake(1e18); // one whole $PONDPAD: real stake
        assertFalse(rewards.canDrip(), "the day before the stake is not banked (R2-A3-3)");
        vm.warp(START + 30 minutes + 2 days);
        assertTrue(rewards.canDrip());
        rewards.drip();
        _nextBlock();
        // The virtual shares (1e6 of ~1e24) got next to nothing: what the stakers can redeem ~ the vault's assets.
        uint256 redeemable = sVault.convertToAssets(sVault.balanceOf(staker)) + sVault.convertToAssets(sVault.balanceOf(dust));
        assertApproxEqRel(redeemable, sVault.totalAssets(), 1e6); // within 1e-12
    }

    function test_dripper_settingsBoundedAndRewardsCantBeRescued() public {
        vm.startPrank(timelock);
        vm.expectRevert(RewardDripper.InvalidSmoothing.selector);
        rewards.setSmoothingPeriod(12 hours);
        vm.expectRevert(RewardDripper.InvalidSmoothing.selector);
        rewards.setSmoothingPeriod(31 days);
        vm.expectRevert(RewardDripper.CatchupTooHigh.selector);
        rewards.setMaxCatchup(8 days);
        vm.expectRevert(RewardDripper.CannotRescueRewards.selector);
        rewards.rescueERC20(address(pondpad), timelock, 1);
        rewards.setSmoothingPeriod(14 days);
        assertEq(rewards.smoothingPeriod(), 14 days);
        vm.stopPrank();
        assertEq(rewards.vault(), address(sVault));

        vm.warp(expiry);
        vm.prank(timelock);
        vm.expectRevert(RewardDripper.PowersExpired.selector);
        rewards.setSmoothingPeriod(7 days);
    }

    /// @dev Audit R2-A3-1: dust sent to the empty vault must not move the share price, so a real stake still opens
    ///      the reward stream (the dripper's gate used to become unreachable for ever).
    function test_vault_dustDonationCannotFreezeRewards() public {
        address griefer = makeAddr("griefer");
        pondpad.transfer(griefer, 1e18);
        vm.prank(griefer);
        pondpad.transfer(address(sVault), 1e12); // one millionth of a $PONDPAD into the empty vault
        pondpad.transfer(address(rewards), 1_000_000e18);
        uint256 shares = _stake(1_000_000e18);
        assertEq(shares, 1_000_000e18 * 1e6, "the dust did not change the starting price");
        vm.warp(START + 30 minutes + 1 days);
        _nextBlock();
        assertTrue(rewards.canDrip(), "a real stake opens the stream");
        (uint256 toVault, uint256 tip) = rewards.drip();
        assertEq(toVault + tip, uint256(1_000_000e18) / 7);
        assertGt(sVault.convertToAssets(shares), 1_000_000e18 + toVault - 1e18);
    }

    /// @dev Audit R2-A3-3: time without stakers is forfeited, so a 1-$PONDPAD first staker can't drip a banked
    ///      catch-up window (1/7 of the buffer) to itself.
    function test_dripper_firstStakerGetsNoBankedWindow() public {
        pondpad.transfer(address(rewards), 7_000_000e18);
        vm.warp(START + 30 minutes + 10 days); // nobody staked for 10 days
        _stake(1e18);
        assertEq(rewards.drippable(), 0, "nothing banked for the first staker");
        vm.expectRevert(RewardDripper.BelowMinDrip.selector);
        rewards.drip();
        vm.warp(START + 30 minutes + 10 days + 1 hours);
        (uint256 toVault, uint256 tip) = rewards.drip();
        assertEq(toVault + tip, uint256(7_000_000e18) * 1 hours / 7 days, "only the hour since the vault opened");
    }

    /// @dev Audits R2-A3-2, R2-A3-4, R1-A3-8: one drip releases at most 1/7 of the buffer (catch-up <= smoothing / 7),
    ///      the min-drip floor fires at most hourly (catch-up >= 1 hour) and the floor itself is at most 100,000.
    function test_dripper_catchupAndMinDripBounded() public {
        bytes4 tooLow = bytes4(keccak256("CatchupTooLow()"));
        bytes4 minTooHigh = bytes4(keccak256("MinDripTooHigh()"));
        vm.startPrank(timelock);
        vm.expectRevert(tooLow);
        rewards.setMaxCatchup(1);
        vm.expectRevert(tooLow);
        rewards.setMaxCatchup(1 hours - 1);
        rewards.setMaxCatchup(1 hours);
        vm.expectRevert(RewardDripper.CatchupTooHigh.selector);
        rewards.setMaxCatchup(1 days + 1); // above smoothing / 7
        rewards.setMaxCatchup(1 days);
        vm.expectRevert(RewardDripper.CatchupTooHigh.selector);
        rewards.setSmoothingPeriod(1 days); // a 1-day catch-up would release the whole buffer in one drip
        vm.expectRevert(minTooHigh);
        rewards.setMinDripAmount(100_001e18);
        rewards.setMinDripAmount(100_000e18);
        vm.stopPrank();
        vm.expectRevert(tooLow);
        new RewardDripper(address(pondpad), address(sVault), timelock, 7 days, 59 minutes, 10e18, 1_000e18, expiry);
        vm.expectRevert(RewardDripper.CatchupTooHigh.selector);
        new RewardDripper(address(pondpad), address(sVault), timelock, 1 days, 1 days, 10e18, 1_000e18, expiry);
        vm.expectRevert(minTooHigh);
        new RewardDripper(address(pondpad), address(sVault), timelock, 7 days, 1 days, 10e18, 100_001e18, expiry);
    }

    /// @dev Audit R2-A3-5: an over-balance transfer reverts with Solady's InsufficientBalance(), not an underflow
    ///      in the hold bookkeeping.
    function test_vault_overBalanceTransferRevertsWithSoladyError() public {
        uint256 shares = _stake(100e18);
        _nextBlock();
        vm.prank(staker);
        vm.expectRevert(ERC20.InsufficientBalance.selector);
        sVault.transfer(bob, shares + 1);
        vm.prank(staker);
        sVault.approve(bob, type(uint256).max);
        vm.prank(bob);
        vm.expectRevert(ERC20.InsufficientBalance.selector);
        sVault.transferFrom(staker, bob, shares + 1);
    }

    // ------------------------------------------------------------------ Buyer

    function test_buyer_turnsStakersImdIntoPondpadForDripper() public {
        _graduate();
        // Protocol IMD reaches the splitter; its 40% goes to the buyer.
        imd.mint(address(splitter), 100e18);
        uint256 inSplitter = imd.balanceOf(address(splitter)); // includes the sale's fees
        splitter.distribute();
        assertEq(imd.balanceOf(address(buyer)), inSplitter * 40 / 100);
        uint256 held = imd.balanceOf(address(buyer));

        _nextBlock();
        uint256 before = pondpad.balanceOf(address(rewards));
        vm.prank(keeper);
        uint256 out = buyer.buy();
        assertGt(out, 0);
        assertEq(pondpad.balanceOf(address(rewards)) - before, out);
        assertEq(imd.balanceOf(keeper), 25e18 * 50 / 10_000); // 0.5% tip on a 25 IMD chunk
        assertEq(imd.balanceOf(address(buyer)), held - 25e18);

        vm.expectRevert(PadBuyer.TooSoon.selector);
        buyer.buy();
        vm.warp(block.timestamp + 10 minutes);
        _nextBlock();
        buyer.buy();
        assertEq(imd.balanceOf(address(buyer)), held - 50e18);
    }

    /// @dev Audit R1-A3-6: a whole-balance chunk of 199 mod 200 wei used to fail paying a tip 1 wei above the
    ///      IMD reserved for it.
    function test_buyer_tipNeverExceedsWhatWasReserved() public {
        _graduate();
        imd.mint(address(buyer), 1e18 + 199);
        _nextBlock();
        vm.prank(keeper);
        buyer.buy();
        assertEq(imd.balanceOf(keeper), (uint256(1e18) + 199) * 50 / 10_000);
        assertEq(imd.balanceOf(address(buyer)), 0);
    }

    function test_buyer_refusesAfterPricePump() public {
        _graduate();
        imd.mint(address(buyer), 100e18);
        _nextBlock();
        _swap(true, 500e18); // pushes $PONDPAD up ~10% in this block
        vm.expectRevert(PadBuyer.PriceOutOfRange.selector);
        buyer.buy();

        // The reference catches up over following blocks (at most maxRefStep per block), then buying resumes.
        for (uint256 i; i < 12; i++) {
            _nextBlock();
            _swap(true, 1e15);
        }
        assertGe(market.currentTick(), market.refTick() - buyer.maxDeviationTicks());
        buyer.buy();
    }

    function test_buyer_forwardsPondpadFeeShare() public {
        _graduate();
        _swap(false, 2_000_000e18);
        _nextBlock();
        controller.collectFees(); // $PONDPAD fees: 40% to the buyer
        uint256 share = pondpad.balanceOf(address(buyer));
        assertGt(share, 0);
        uint256 before = pondpad.balanceOf(address(rewards));
        buyer.forward();
        assertEq(pondpad.balanceOf(address(rewards)) - before, share);
    }

    function test_buyer_settingsBounded() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        buyer.setSettings(10e18, 1e18, 10 minutes, 100, 100, 50);
        vm.startPrank(timelock);
        vm.expectRevert(PadBuyer.InvalidSetting.selector);
        buyer.setSettings(1_000e18, 1e18, 10 minutes, 100, 100, 50);
        vm.expectRevert(PadBuyer.InvalidSetting.selector);
        buyer.setSettings(10e18, 1e18, 10 minutes, 100, 100, 500);
        buyer.setSettings(10e18, 1e18, 5 minutes, 50, 50, 20);
        vm.stopPrank();
        assertEq(buyer.maxChunk(), 10e18);
    }

    // ------------------------------------------------------------------ Audit round 3

    /// @dev Audit R3-A3-1: the `minDripAmount` floor never releases more than 1/7 of the buffer in one drip, at the
    ///      default floor or the highest one the owner may set.
    function test_dripper_floorNeverReleasesMoreThanASeventh() public {
        _stake(100_000e18);
        pondpad.transfer(address(rewards), 1_000e18); // at the default 1,000 floor
        uint256 t0 = START + 30 minutes;
        vm.warp(t0 + 1 days);
        (uint256 toVault, uint256 tip) = rewards.drip();
        assertLe(toVault + tip, uint256(1_000e18) / 7, "default floor");

        vm.prank(timelock);
        rewards.setMinDripAmount(100_000e18); // the highest allowed
        pondpad.transfer(address(rewards), 100_000e18);
        uint256 buffer = pondpad.balanceOf(address(rewards));
        vm.warp(t0 + 2 days);
        (toVault, tip) = rewards.drip();
        assertLe(toVault + tip, buffer / 7, "highest floor");
    }

    /// @dev Audits R3-A3-5 / R4-A3-1: held shares can't be sent to address(0) any more, and the holder's next transfer
    ///      in the same block works with the hold bookkeeping intact.
    function test_vault_transferToZeroKeepsHoldBookkeeping() public {
        uint256 shares = _stake(2e18); // all held this block
        vm.startPrank(staker);
        vm.expectRevert(StakedPONDPAD.InvalidReceiver.selector);
        sVault.transfer(address(0), shares / 2);
        sVault.transfer(bob, 1);
        vm.stopPrank();
        assertLe(sVault.heldShares(staker), sVault.balanceOf(staker));
    }

    /// @dev Audit R3-A3-2: after a crash and blocks without swaps, the reference catches up with the price the market
    ///      held, so a pump-buy-dump in one block can't make PadBuyer pay the pre-crash price.
    function test_buyer_staleReferenceCatchesUpAfterQuietBlocks() public {
        _graduate();
        imd.mint(address(buyer), 25e18);
        _nextBlock();
        _swap(false, 40_000_000e18); // a large sell: $PONDPAD much cheaper
        int24 crashTick = market.currentTick();
        assertGt(crashTick, market.refTick() + 2_000);
        for (uint256 i; i < 50; i++) {
            _nextBlock(); // nobody trades
        }
        _swap(true, 845e18); // the attacker pumps back toward the old reference, first swap after the quiet blocks
        assertEq(market.refTick(), crashTick, "the reference caught up with the price that stood");
        vm.expectRevert(PadBuyer.PriceOutOfRange.selector);
        buyer.buy();
    }

    /// @dev Audits R3-A2-2 / R3-A4-4: the staking contracts' owners can't hand over, transfer or renounce their powers.
    function test_staking_ownersAreFixed() public {
        address undelayed = makeAddr("undelayed");
        vm.startPrank(slowTimelock);
        vm.expectRevert(FixedOwnable.OwnerIsFixed.selector);
        sVault.transferOwnership(undelayed);
        vm.expectRevert(FixedOwnable.OwnerIsFixed.selector);
        sVault.renounceOwnership();
        vm.stopPrank();
        vm.startPrank(timelock);
        vm.expectRevert(FixedOwnable.OwnerIsFixed.selector);
        rewards.transferOwnership(undelayed);
        vm.expectRevert(FixedOwnable.OwnerIsFixed.selector);
        rewards.renounceOwnership();
        vm.expectRevert(FixedOwnable.OwnerIsFixed.selector);
        buyer.transferOwnership(undelayed);
        vm.expectRevert(FixedOwnable.OwnerIsFixed.selector);
        buyer.renounceOwnership();
        vm.stopPrank();
        vm.prank(undelayed);
        vm.expectRevert(FixedOwnable.OwnerIsFixed.selector);
        sVault.requestOwnershipHandover();
        assertEq(sVault.owner(), slowTimelock);
        assertEq(rewards.owner(), timelock);
        assertEq(buyer.owner(), timelock);
    }

    /// @dev Audit R3-A3-9 (coverage): a PadBuyer chunk that hits its price limit spends less, keeps the rest and
    ///      pays a smaller tip.
    function test_buyer_partialFillStopsAtTheLimit() public {
        _graduate();
        vm.prank(timelock);
        buyer.setSettings(500e18, 1e18, 10 minutes, 100, 100, 50);
        imd.mint(address(buyer), 500e18);
        _nextBlock();
        _swap(true, 1e15); // sets the reference at the current price
        _nextBlock();
        _swap(true, 30e18); // a small pump, still inside the guard band
        vm.prank(keeper);
        buyer.buy();
        int24 limit = market.refTick() - 200;
        assertLe(market.currentTick(), limit + 1);
        assertGe(market.currentTick(), limit - 1, "stopped at the price limit");
        uint256 tip = imd.balanceOf(keeper);
        uint256 left = imd.balanceOf(address(buyer));
        assertGt(left, 0, "unspent IMD stays in the buyer");
        assertLt(tip, uint256(500e18) * 50 / 10_000, "a smaller tip for a smaller fill");
        assertEq(500e18 - left - tip > 0, true);
    }

    /// @dev Audit R3-A3-9 (coverage): `mint` and `withdraw`, a partial same-block hold, and a held `transferFrom`.
    function test_vault_mintWithdrawAndHeldTransferFrom() public {
        _stake(1_000e18);
        _nextBlock();
        vm.prank(staker);
        sVault.mint(333e24, staker); // 333 $PONDPAD worth of shares, held this block
        uint256 maxW = sVault.maxWithdraw(staker);
        assertApproxEqAbs(maxW, 1_000e18, 1e6, "only the older stake can leave");
        vm.prank(staker);
        sVault.withdraw(maxW, staker, staker);
        assertApproxEqAbs(sVault.balanceOf(staker), 333e24, 1e12);
        // A held part travels with a transferFrom.
        vm.prank(staker);
        sVault.approve(bob, type(uint256).max);
        vm.prank(bob);
        sVault.transferFrom(staker, bob, 100e24);
        assertEq(sVault.maxRedeem(bob), 0, "the moved shares are still held this block");
        _nextBlock();
        assertEq(sVault.maxRedeem(bob), 100e24);
    }

    /// @dev Audit R3-A3-9 (coverage): after every staker leaves, the vault closes for rewards and the dripper waits;
    ///      a new staker reopens it and drips resume.
    function test_vault_fullExitThenReopen() public {
        uint256 shares = _stake(1_000e18);
        pondpad.transfer(address(rewards), 7_000e18);
        uint256 t0 = START + 30 minutes;
        vm.warp(t0 + 1 days);
        rewards.drip();
        _nextBlock();
        vm.prank(staker);
        sVault.redeem(shares, staker, staker);
        assertEq(sVault.totalSupply(), 0);
        assertEq(sVault.rewardsOpenSince(), 0);
        vm.warp(t0 + 2 days);
        vm.expectRevert(RewardDripper.VaultEmpty.selector);
        rewards.drip();
        uint256 again = _stake(2e18);
        assertGt(again, 0);
        assertGt(sVault.rewardsOpenSince(), 0);
        vm.warp(t0 + 3 days);
        rewards.drip(); // a full window from the reopening
        assertGt(sVault.totalAssets(), 2e18);
    }

    // ------------------------------------------------------------------ Audit round 4

    /// @dev Audit R4-A3-1: shares can't be minted or sent to address(0) or to the vault itself, where nobody could ever
    ///      redeem them; so one $PONDPAD parked there can't open the vault and set the dripper streaming into it.
    function test_vault_noSharesForAddressZeroOrTheVault() public {
        pondpad.transfer(address(rewards), 7_000_000e18);
        vm.startPrank(staker);
        vm.expectRevert(StakedPONDPAD.InvalidReceiver.selector);
        sVault.deposit(1e18, address(0));
        vm.expectRevert(StakedPONDPAD.InvalidReceiver.selector);
        sVault.mint(1e24, address(0));
        vm.expectRevert(StakedPONDPAD.InvalidReceiver.selector);
        sVault.deposit(1e18, address(sVault));
        vm.stopPrank();
        assertEq(sVault.rewardsOpenSince(), 0, "still closed for rewards");
        vm.warp(START + 30 minutes + 1 days);
        assertEq(rewards.drippable(), 0, "the buffer waits for a real staker");

        uint256 shares = _stake(10e18);
        vm.startPrank(staker);
        vm.expectRevert(StakedPONDPAD.InvalidReceiver.selector);
        sVault.transfer(address(0), shares);
        vm.expectRevert(StakedPONDPAD.InvalidReceiver.selector);
        sVault.transfer(address(sVault), shares);
        sVault.approve(bob, shares);
        vm.stopPrank();
        vm.startPrank(bob);
        vm.expectRevert(StakedPONDPAD.InvalidReceiver.selector);
        sVault.transferFrom(staker, address(0), shares);
        vm.expectRevert(StakedPONDPAD.InvalidReceiver.selector);
        sVault.transferFrom(staker, address(sVault), shares);
        vm.stopPrank();
        assertEq(sVault.balanceOf(staker), shares);
        assertEq(sVault.balanceOf(address(0)) + sVault.balanceOf(address(sVault)), 0);
    }

    /// @dev Audit R4-A3-5: the owner can't rescue sPONDPAD itself, whose shares stand for staked $PONDPAD.
    function test_vault_cantRescueItsOwnShares() public {
        _stake(1_000e18);
        vm.prank(slowTimelock);
        vm.expectRevert(StakedPONDPAD.CannotRescueStake.selector);
        sVault.rescueERC20(address(sVault), slowTimelock, 0);
    }

    /// @dev Audit R4-A3-3: after a genuine rise and blocks without swaps, PadBuyer reads the reference caught up to this
    ///      block (`referenceTick()`), not the stored `refTick`, which only moves at the next swap; so it buys without
    ///      waiting for someone else to trade.
    function test_buyer_buysAfterAGenuineRiseAndQuietBlocks() public {
        _graduate();
        imd.mint(address(buyer), 25e18);
        _nextBlock();
        _swap(true, 1e15); // the reference stands at the current price
        _nextBlock();
        _swap(true, 80e18); // $PONDPAD rises past the 1% guard
        int24 rose = market.currentTick();
        assertLt(rose, market.refTick() - buyer.maxDeviationTicks());
        for (uint256 i; i < 20; i++) {
            _nextBlock(); // nobody trades
        }
        assertGt(market.refTick(), rose, "the stored reference still sits before the rise");
        vm.prank(keeper);
        assertGt(buyer.buy(), 0, "buys without waiting for another trade");
        assertEq(market.refTick(), rose, "its own swap applied the catch-up it read");
    }

    /// @dev Audit R4-A3-3: `referenceTick()` is exactly what the next swap writes into `refTick`, after quiet blocks and
    ///      within the block of a swap, and a pump in the current block doesn't move it.
    function test_market_referenceTickIsWhatTheNextSwapSets() public {
        _graduate();
        _nextBlock();
        _swap(false, 20_000_000e18); // $PONDPAD cheaper
        for (uint256 i; i < 3; i++) {
            _nextBlock();
        }
        int24 expected = market.referenceTick();
        assertTrue(expected != market.refTick(), "a catch-up is pending");
        _swap(true, 500e18); // the first swap of this block: a pump
        assertEq(market.refTick(), expected, "the swap set what the view reported");
        assertEq(market.referenceTick(), expected, "the pump in this block doesn't move it");
    }

    /// @dev Audit R4-A3-7: `minChunk` can't be 0, so an empty buyer reverts `NothingToBuy`, not inside the PoolManager.
    function test_buyer_minChunkCantBeZero() public {
        vm.prank(timelock);
        vm.expectRevert(PadBuyer.InvalidSetting.selector);
        buyer.setSettings(25e18, 0, 10 minutes, 100, 100, 50);
        _graduate();
        _nextBlock();
        vm.expectRevert(PadBuyer.NothingToBuy.selector);
        buyer.buy();
    }

    /// @dev Audit R4-A3-9 (coverage): `syncRewards` refuses while the vault is closed, and while it is open it takes in
    ///      $PONDPAD sent straight to the vault as one lump (documented, R4-A3-2: only the dripper should send here).
    function test_vault_syncRewardsClosedAndStrayLump() public {
        pondpad.transfer(address(sVault), 100e18);
        vm.expectRevert(StakedPONDPAD.RewardsClosed.selector);
        sVault.syncRewards();
        uint256 shares = _stake(1_000e18);
        assertEq(sVault.totalAssets(), 1_000e18, "the stray transfer isn't counted on its own");
        assertEq(sVault.syncRewards(), 100e18);
        assertApproxEqAbs(sVault.convertToAssets(shares), 1_100e18, 1e6);
    }

    /// @dev Audit R4-A3-9 (coverage): while paused, `deposit` and `mint` revert with ERC-4626's max errors (the max views
    ///      report 0); a drip into a paused vault still works, and a `minDripAmount` of 0 drips every second untipped.
    function test_vault_pausedDepositMintAndDripWhilePaused() public {
        _stake(1_000e18);
        pondpad.transfer(address(rewards), 7_000e18);
        vm.prank(slowTimelock);
        sVault.setPaused(true);
        vm.startPrank(staker);
        vm.expectRevert(ERC4626.DepositMoreThanMax.selector);
        sVault.deposit(1e18, staker);
        vm.expectRevert(ERC4626.MintMoreThanMax.selector);
        sVault.mint(1e24, staker);
        vm.stopPrank();
        vm.warp(START + 30 minutes + 1 days);
        (uint256 toVault,) = rewards.drip();
        assertGt(toVault, 0, "rewards still reach the paused vault");

        vm.prank(timelock);
        rewards.setKeeperReward(0);
        vm.prank(timelock);
        rewards.setMinDripAmount(0);
        vm.warp(START + 30 minutes + 1 days + 1);
        (uint256 again, uint256 tip) = rewards.drip();
        assertGt(again, 0);
        assertEq(tip, 0);
    }

    /// @dev Audit R4-A3-9 (coverage): the keeper tip can't exceed the minimum drip's share, from either setter.
    function test_dripper_keeperRewardBoundFromBothSetters() public {
        vm.startPrank(timelock);
        vm.expectRevert(RewardDripper.KeeperRewardExceedsMin.selector);
        rewards.setKeeperReward(1_000e18);
        vm.expectRevert(RewardDripper.KeeperRewardExceedsMin.selector);
        rewards.setMinDripAmount(1e18);
        vm.stopPrank();
    }

    /// @dev Audit R4-A3-9 (coverage): PadBuyer's buy can be the first swap after a sell-side trim: the matured claims
    ///      are realised inside its unlock (it swaps before it pays) and the buy goes through.
    function test_buyer_buysFirstAfterATrim() public {
        _graduate();
        imd.mint(address(buyer), 25e18);
        _nextBlock();
        _swap(false, 40_000_000e18); // a trim
        assertGt(market.burnClaims(), 0);
        for (uint256 i; i < 50; i++) {
            _nextBlock(); // the reference catches up with the cheaper price
        }
        uint256 rewardShare = market.rewardClaims();
        uint256 before = pondpad.balanceOf(address(rewards));
        vm.prank(keeper);
        uint256 out = buyer.buy(); // the first swap after the trim
        assertGt(out, 0);
        assertEq(pondpad.balanceOf(address(rewards)) - before, out + rewardShare, "the buy plus the trim's reward share");
        assertEq(market.burnClaims(), 0, "the matured claims were realised");
    }

    // ------------------------------------------------------------------ Check before round 5, D-84

    /// @dev P5-2 (R4-A3-9 coverage): `PadBuyer.buy()` through a hook reached by `MarketController.migrate`. It reads
    ///      `controller.hook()` live and the new hook's `referenceTick()`: the inherited `refTick` in the migration
    ///      block, its catch-up after quiet blocks, which its own swap then writes.
    function test_buyer_buysThroughAMigratedHook() public {
        _graduate();
        imd.mint(address(buyer), 100e18);
        _nextBlock();
        _swap(true, 1e15);
        _nextBlock();
        address addr = address(uint160(MARKET_FLAGS) | (uint160(0x8888) << 144));
        deployCodeTo(
            "PadMarketHook.sol:PadMarketHook",
            abi.encode(
                address(controller), IPoolManager(address(pm)), address(imd), address(pondpad), address(burner),
                address(rewards), uint256(1_500), uint256(1_000e18), int24(200)
            ),
            addr
        );
        vm.prank(slowTimelock);
        controller.approveMigration(addr);
        vm.prank(migrator);
        controller.migrate(addr);
        PadMarketHook next = PadMarketHook(addr);
        assertEq(address(controller.hook()), addr);
        assertFalse(market.marketOpen(), "old hook closed");
        assertEq(next.referenceTick(), next.refTick(), "migration block: the inherited reference");

        uint256 dripBefore = pondpad.balanceOf(address(rewards));
        vm.prank(keeper);
        assertGt(buyer.buy(), 0, "buys through the new hook in the migration block");
        assertGt(pondpad.balanceOf(address(rewards)), dripBefore);

        vm.warp(START + 30 minutes + 1 hours);
        for (uint256 i; i < 5; i++) {
            _nextBlock();
        }
        int24 expected = next.referenceTick();
        vm.prank(keeper);
        assertGt(buyer.buy(), 0, "and after quiet blocks");
        assertEq(next.refTick(), expected, "its swap set what it read");
    }

    /// @dev Audit R2-A3-6 (D-84): the market's reference moves at most 100 ticks per Ethereum block by default (POOL4:
    ///      200), no more than PadBuyer's 100-tick guard. Against the price before a pump held across a block, PadBuyer
    ///      then pays at most maxRefStep + maxDeviation + maxSlippage = 300 ticks (~3%) more per block.
    function test_buyer_overpayBoundAtTheDefaultRefStep() public {
        assertEq(market.maxRefStep(), 100, "default step");
        assertLe(market.maxRefStep(), buyer.maxDeviationTicks(), "step within PadBuyer's guard");
        _graduate();
        vm.prank(timelock);
        buyer.setSettings(500e18, 1e18, 10 minutes, 100, 100, 50); // a large chunk, so it runs into its limit
        imd.mint(address(buyer), 500e18);
        _nextBlock();
        int24 prePump = market.currentTick();
        _swap(true, 500e18); // the attacker pumps $PONDPAD ~10% and holds it as this block's close
        assertEq(market.refTick(), prePump);
        assertLt(market.currentTick(), prePump - 900);
        _nextBlock();
        assertEq(market.referenceTick(), prePump - 100, "one step per block");
        vm.expectRevert(PadBuyer.PriceOutOfRange.selector);
        buyer.buy();

        // The attacker sells back to just inside PadBuyer's band; PadBuyer then buys as far as its swap limit.
        PoolKey memory key = market.poolKey();
        vm.prank(trader);
        swapper.swap(
            key,
            SwapParams({
                zeroForOne: false,
                amountSpecified: -int256(30_000_000e18),
                sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(prePump - 190)
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
        assertEq(market.currentTick(), prePump - 190);
        vm.prank(keeper);
        assertGt(buyer.buy(), 0);
        assertGe(market.currentTick(), prePump - 301, "never dearer than 300 ticks above the pre-pump price");
        assertLe(market.currentTick(), prePump - 299, "its limit stopped the fill there");
        assertGt(imd.balanceOf(address(buyer)), 0, "the rest of the chunk waits");
    }

    // ------------------------------------------------------------------ End to end

    function test_staking_endToEnd_coinFeesReachStakers() public {
        _graduate();
        _stake(1_000_000e18);
        uint256 valueBefore = sVault.convertToAssets(sVault.balanceOf(staker));

        // A coin launch and trades on PondPad send protocol IMD to the splitter.
        address coin = _launch(_noTax(), 0);
        vm.warp(block.timestamp + 1 hours);
        _buy(alice, coin, 1_000e18);
        splitter.distribute();
        _nextBlock();
        buyer.buy();
        vm.warp(block.timestamp + 1 hours);
        _nextBlock();
        rewards.drip();

        assertGt(sVault.convertToAssets(sVault.balanceOf(staker)), valueBefore);
    }

    // ------------------------------------------------------------------ Audit round 5

    /// @dev A fresh market hook owned by the controller, approved by the 7-day timelock and migrated into by the Safe.
    function _migrate() internal returns (PadMarketHook next) {
        address addr = address(uint160(MARKET_FLAGS) | (uint160(0x8888) << 144));
        deployCodeTo(
            "PadMarketHook.sol:PadMarketHook",
            abi.encode(
                address(controller), IPoolManager(address(pm)), address(imd), address(pondpad), address(burner),
                address(rewards), uint256(1_500), uint256(1_000e18), int24(200)
            ),
            addr
        );
        vm.prank(slowTimelock);
        controller.approveMigration(addr);
        vm.prank(migrator);
        controller.migrate(addr);
        next = PadMarketHook(addr);
        assertEq(address(controller.hook()), addr);
    }

    /// @dev Audits R5-A2-2 / R5-A3-1: a migration carries the old market's reference as caught up to its block
    ///      (`referenceTick()`), not the stored `refTick`, which only catches up at the next swap. After a 40M dump and
    ///      40 quiet blocks the stored one still sat at the price before the dump; inherited, it let a pump to just
    ///      inside it make PadBuyer pay far above invariant 14's bound (the judge: 2,487 bps on one chunk), where the
    ///      old market refused. Now the new market starts from the caught-up reference and PadBuyer refuses that pump.
    function test_buyer_migrationCarriesTheCaughtUpReference() public {
        _graduate();
        imd.mint(address(buyer), 25e18);
        _nextBlock();
        _swap(true, 1e18); // the reference stands at the current price
        _nextBlock();
        _swap(false, 40_000_000e18); // a dump: $PONDPAD much cheaper (a higher tick)
        int24 staleRef = market.refTick();
        int24 dumped = market.currentTick();
        assertGt(dumped, staleRef + 2_000);
        for (uint256 i; i < 40; i++) {
            _nextBlock(); // nobody trades
        }
        int24 caughtUp = market.referenceTick();
        assertEq(caughtUp, dumped, "the old market's reference caught up with the price that stood");
        assertEq(market.refTick(), staleRef, "its stored one still sits before the dump");

        PadMarketHook next = _migrate();
        assertEq(next.referenceTick(), caughtUp, "the new market keeps the caught-up reference");
        assertEq(next.refTick(), caughtUp);

        // A pump in the migration block to just inside the stale reference's band: refused, as on the old market.
        PoolKey memory key = next.poolKey();
        vm.prank(trader);
        swapper.swap(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -int256(5_000e18),
                sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(staleRef - 99)
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
        assertGe(next.currentTick(), staleRef - 100);
        assertLe(next.currentTick(), staleRef - 99);
        vm.prank(keeper);
        vm.expectRevert(PadBuyer.PriceOutOfRange.selector);
        buyer.buy();
    }

    /// @dev Audit R5-A3-2: sPONDPAD parked at the dripper can't be rescued by the dripper's owner (the 48 h timelock):
    ///      its shares stand for staked $PONDPAD, as the vault's own rescue already says (R4-A3-5); parked there they
    ///      act like a staker that never exits (THREAT-MODEL §3). Stray tokens can still be rescued.
    function test_dripper_cantRescueParkedShares() public {
        vm.prank(staker);
        uint256 shares = sVault.deposit(5e18, address(rewards)); // parked at the dripper
        _nextBlock();
        vm.prank(timelock);
        vm.expectRevert(RewardDripper.CannotRescueRewards.selector);
        rewards.rescueERC20(address(sVault), timelock, shares);
        assertEq(sVault.balanceOf(address(rewards)), shares);

        MockIMD stray = new MockIMD();
        stray.mint(address(rewards), 1e18);
        vm.prank(timelock);
        rewards.rescueERC20(address(stray), timelock, 1e18);
        assertEq(stray.balanceOf(timelock), 1e18);
    }

    /// @dev Audit R5-A3-3: no exit pays address(0) (the staker's $PONDPAD would end up there) or the vault itself (it
    ///      would sit uncounted until the next `syncRewards`), as deposits already refuse both (R4-A3-1).
    function test_vault_noExitToAddressZeroOrTheVault() public {
        uint256 shares = _stake(10e18);
        _nextBlock();
        vm.startPrank(staker);
        vm.expectRevert(StakedPONDPAD.InvalidReceiver.selector);
        sVault.redeem(shares, address(0), staker);
        vm.expectRevert(StakedPONDPAD.InvalidReceiver.selector);
        sVault.redeem(shares, address(sVault), staker);
        vm.expectRevert(StakedPONDPAD.InvalidReceiver.selector);
        sVault.withdraw(5e18, address(0), staker);
        vm.expectRevert(StakedPONDPAD.InvalidReceiver.selector);
        sVault.withdraw(5e18, address(sVault), staker);
        uint256 back = sVault.redeem(shares, staker, staker);
        vm.stopPrank();
        assertApproxEqAbs(back, 10e18, 1);
        assertEq(pondpad.balanceOf(address(0)), 0);
        assertEq(sVault.totalAssets(), 0);
    }

    /// @dev Audit R5-A3-4: with the reference within PadBuyer's band of `MIN_TICK`, its clamped limit must be one v4
    ///      accepts, `MIN_TICK + 1`: `MIN_TICK`'s sqrt price is `MIN_SQRT_PRICE`, which v4 refuses
    ///      (`PriceLimitOutOfBounds`). Such a price can't be reached (about 1e25 IMD from the opening state), so the
    ///      market's reference and tick are mocked there; the swap runs in the real pool, where the limit doesn't bind.
    function test_buyer_clampsItsLimitToATickV4Accepts() public {
        _graduate();
        imd.mint(address(buyer), 25e18);
        _nextBlock();
        int24 nearMin = TickMath.MIN_TICK + 150;
        int24 limit = nearMin - buyer.maxDeviationTicks() - buyer.maxSlippageTicks();
        assertLt(limit, TickMath.MIN_TICK, "the clamp applies");
        vm.mockCall(address(market), abi.encodeWithSelector(PadMarketHook.referenceTick.selector), abi.encode(nearMin));
        vm.mockCall(address(market), abi.encodeWithSelector(PadMarketHook.currentTick.selector), abi.encode(nearMin));
        uint256 before = pondpad.balanceOf(address(rewards));
        vm.prank(keeper);
        uint256 out = buyer.buy();
        vm.clearMockedCalls();
        assertGt(out, 0, "buys with the lowest limit v4 accepts");
        assertEq(pondpad.balanceOf(address(rewards)) - before, out);
    }

    /// @dev Audit R5-A3-5: the generated dripper and vault (`upstream/make_staking.py`) no longer promise powers the
    ///      fork removed (a rescue of the reward buffer, a renounce) nor keep declarations nothing uses.
    function test_staking_generatedSourcesKeepNoStaleUpstreamPowers() public view {
        string memory dripperSrc = vm.readFile("src/RewardDripper.sol");
        string[5] memory gone = [
            "can rescue the buffer", "renouncing (blocked", "RenounceWouldFreeze", "MAX_CATCHUP =", "function totalSupply()"
        ];
        for (uint256 i; i < gone.length; i++) {
            assertEq(vm.indexOf(dripperSrc, gone[i]), type(uint256).max, gone[i]);
        }
        assertEq(vm.indexOf(vm.readFile("src/StakedPONDPAD.sol"), "RenounceWhilePaused"), type(uint256).max);
    }

    // ------------------------------------------------------------------ Audit round 6 (D-88): coverage and documented behaviour

    /// @dev Audit R6-A3-6 (coverage): an approved operator exits for the owner (`by != owner`) through `redeem` and
    ///      `withdraw`; the one-block hold applies to the owner's shares that arrived this block, whoever exits them.
    function test_vault_operatorExitsHonourTheHold() public {
        address op = makeAddr("operator");
        uint256 shares = _stake(1_000e18);
        vm.prank(staker);
        sVault.approve(op, type(uint256).max);
        vm.prank(op);
        vm.expectRevert(ERC4626.RedeemMoreThanMax.selector); // held in the deposit block
        sVault.redeem(shares, op, staker);
        _nextBlock();
        vm.prank(op);
        uint256 assets = sVault.redeem(shares / 2, op, staker);
        assertEq(pondpad.balanceOf(op), assets);
        vm.prank(op);
        sVault.withdraw(100e18, op, staker);
        assertEq(pondpad.balanceOf(op), assets + 100e18);
        uint256 fresh = _stake(10e18);
        uint256 unheld = sVault.maxRedeem(staker);
        assertEq(unheld, sVault.balanceOf(staker) - fresh, "the fresh shares are held");
        vm.prank(op);
        sVault.redeem(unheld, op, staker);
        vm.prank(op);
        vm.expectRevert(ERC4626.RedeemMoreThanMax.selector);
        sVault.redeem(1, op, staker);
        address stranger = makeAddr("stranger");
        _nextBlock();
        vm.prank(stranger);
        vm.expectRevert(ERC20.InsufficientAllowance.selector);
        sVault.redeem(1, stranger, staker);
    }

    /// @dev Audit R6-A3-6 (coverage): `rescueETH` on the vault and the dripper is their owners' only, and ends with the
    ///      other powers at `powersExpireAt`.
    function test_staking_rescueEthOnlyByTheOwnerUntilExpiry() public {
        address to = makeAddr("ethTo");
        vm.deal(address(sVault), 2 ether);
        vm.deal(address(rewards), 2 ether);
        vm.prank(staker);
        vm.expectRevert(Ownable.Unauthorized.selector);
        sVault.rescueETH(to, 1 ether);
        vm.prank(staker);
        vm.expectRevert(Ownable.Unauthorized.selector);
        rewards.rescueETH(to, 1 ether);
        vm.prank(slowTimelock);
        sVault.rescueETH(to, 1 ether);
        vm.prank(timelock);
        rewards.rescueETH(to, 1 ether);
        assertEq(to.balance, 2 ether);
        vm.warp(expiry);
        vm.prank(slowTimelock);
        vm.expectRevert(StakedPONDPAD.PowersExpired.selector);
        sVault.rescueETH(to, 1 ether);
        vm.prank(timelock);
        vm.expectRevert(RewardDripper.PowersExpired.selector);
        rewards.rescueETH(to, 1 ether);
        assertEq(to.balance, 2 ether);
    }

    /// @dev Audit R6-A3-1 (documented): sPONDPAD keeps Solady's fixed infinite allowance for the canonical Permit2, as
    ///      $PONDPAD does (D-77) and POOL4's `StakedIMD` does; `PadToken` turns it off. Permit2 moves shares only on the
    ///      holder's own Permit2 signature or approval; the one-block hold travels with the shares as usual.
    function test_vault_permit2HasAFixedInfiniteAllowance() public {
        address permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
        uint256 shares = _stake(10e18);
        assertEq(sVault.allowance(staker, permit2), type(uint256).max);
        assertEq(pondpad.allowance(staker, permit2), type(uint256).max);
        vm.prank(staker);
        vm.expectRevert(ERC20.Permit2AllowanceIsFixedAtInfinity.selector);
        sVault.approve(permit2, 0);
        address receiver = makeAddr("permit2Receiver");
        vm.prank(permit2);
        sVault.transferFrom(staker, receiver, shares); // no approval given
        assertEq(sVault.balanceOf(receiver), shares);
        assertEq(sVault.maxRedeem(receiver), 0, "the hold travels with the shares");
        _nextBlock();
        assertEq(sVault.maxRedeem(receiver), shares);
    }

    /// @dev Audit R6-A3-3 (documented): `maxDeposit` / `maxMint` don't single out address(0) and the vault, which
    ///      `deposit` / `mint` always refuse (R4-A3-1).
    function test_vault_maxViewsDontSingleOutRefusedReceivers() public {
        assertEq(sVault.maxDeposit(address(0)), type(uint256).max);
        assertEq(sVault.maxMint(address(sVault)), type(uint256).max);
        vm.prank(staker);
        vm.expectRevert(StakedPONDPAD.InvalidReceiver.selector);
        sVault.deposit(1e18, address(0));
        vm.prank(staker);
        vm.expectRevert(StakedPONDPAD.InvalidReceiver.selector);
        sVault.mint(1e24, address(sVault));
    }

    /// @dev Audit R6-A3-2 (keeper): a `buy()` that reverts (`NothingToBuy`, `TooSoon`) undoes its own `forward()`, so
    ///      $PONDPAD fee shares wait in PadBuyer until someone calls `forward()`, which the keeper now does whenever
    ///      PadBuyer holds $PONDPAD.
    function test_buyer_aRevertedBuyLeavesTheFeeShareForForward() public {
        pondpad.transfer(address(buyer), 50e18);
        assertEq(imd.balanceOf(address(buyer)), 0);
        vm.expectRevert(PadBuyer.NothingToBuy.selector);
        buyer.buy();
        assertEq(pondpad.balanceOf(address(buyer)), 50e18, "rolled back with the buy");
        vm.prank(keeper);
        assertEq(buyer.forward(), 50e18);
        assertEq(pondpad.balanceOf(address(buyer)), 0);
        assertEq(pondpad.balanceOf(address(rewards)), 50e18, "the dripper has it");
    }
}
