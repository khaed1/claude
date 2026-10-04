// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "solady/auth/Ownable.sol";
import {ERC4626} from "solady/tokens/ERC4626.sol";
import {MarketBase} from "./Market.t.sol";
import {MockIMD} from "./Base.t.sol";
import {StakedPONDPAD} from "../src/StakedPONDPAD.sol";
import {RewardDripper} from "../src/RewardDripper.sol";
import {PadBuyer} from "../src/PadBuyer.sol";
import {FeeSplitter} from "../src/FeeSplitter.sol";

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
        rewards = new RewardDripper(address(pondpad), address(sVault), timelock, 20e18, 1 hours, 100e18, 10_000e18, expiry);
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

        // Never into an empty sVault.
        vm.warp(block.timestamp + 1 hours);
        vm.expectRevert(RewardDripper.VaultEmpty.selector);
        rewards.drip();

        _stake(1_000_000e18);
        uint256 assetsBefore = sVault.totalAssets();
        vm.warp(block.timestamp + 10 hours); // catch-up capped at 1 hour
        vm.prank(keeper);
        (uint256 toVault, uint256 tip) = rewards.drip();
        assertEq(toVault + tip, 20e18 * 1 hours);
        assertEq(tip, 100e18);
        assertEq(sVault.totalAssets() - assetsBefore, toVault);
        assertGt(sVault.convertToAssets(sVault.balanceOf(staker)), 1_000_000e18);
    }

    function test_dripper_settingsStayDrainableAndRewardsCantBeRescued() public {
        vm.startPrank(timelock);
        vm.expectRevert(RewardDripper.RenounceWouldFreeze.selector);
        rewards.setDripRate(0);
        vm.expectRevert(RewardDripper.RenounceWouldFreeze.selector);
        rewards.setMinDripAmount(1_000_000e18); // above one call's ceiling
        vm.expectRevert(RewardDripper.CannotRescueRewards.selector);
        rewards.rescueERC20(address(pondpad), timelock, 1);
        rewards.setDripRate(50e18);
        assertEq(rewards.dripRatePerSecond(), 50e18);
        vm.stopPrank();
        assertEq(rewards.vault(), address(sVault));

        vm.warp(expiry);
        vm.prank(timelock);
        vm.expectRevert(RewardDripper.PowersExpired.selector);
        rewards.setDripRate(10e18);
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
