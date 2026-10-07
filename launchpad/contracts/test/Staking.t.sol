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

    /// @dev Audit R3-A3-5: moving held shares to address(0) still goes through the hold bookkeeping, so the holder's
    ///      next transfer in the same block works instead of underflowing.
    function test_vault_transferToZeroKeepsHoldBookkeeping() public {
        uint256 shares = _stake(2e18); // all held this block
        vm.startPrank(staker);
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
}
