// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "solady/auth/Ownable.sol";
import {MarketBase} from "./Market.t.sol";
import {WorkerFund} from "../src/WorkerFund.sol";
import {GrowthFund} from "../src/GrowthFund.sol";
import {FeeSplitter} from "../src/FeeSplitter.sol";

contract FundsTest is MarketBase {
    WorkerFund internal workerFund;
    GrowthFund internal growthFund;

    address internal safe = makeAddr("safe");
    address internal workerRewards = makeAddr("workerRewards");
    address internal grantee = makeAddr("grantee");

    function setUp() public override {
        super.setUp();
        workerFund = new WorkerFund(slowTimelock, address(imd), address(pondpad), address(0));
        growthFund = new GrowthFund(
            timelock, address(imd), address(pondpad), relay, safe, 100e18, 1_000e18, 10_000_000e18
        );
        splitter.setRecipients(
            FeeSplitter.Recipients({
                stakers: stakers,
                workers: address(workerFund),
                growth: address(growthFund),
                treasury: treasury
            })
        );
        config.setGrowthFund(address(growthFund));
    }

    /// @dev Coin trades and $PONDPAD market sells, then the splitter pays the funds in both tokens.
    function _generateFees() internal {
        _graduate();
        _swap(true, 200e18);
        _swap(false, 3_000_000e18);
        _nextBlock();
        controller.collectFees();
        splitter.distribute();
    }

    function test_workerFund_accruesUntilSetThenReleasesBoth() public {
        _generateFees();
        uint256 imdHeld = imd.balanceOf(address(workerFund));
        uint256 tokenHeld = pondpad.balanceOf(address(workerFund));
        assertGt(imdHeld, 0);
        assertGt(tokenHeld, 0); // workers' 25% of the market's $PONDPAD fees (D-38)

        vm.expectRevert(WorkerFund.RecipientNotSet.selector);
        workerFund.release();

        vm.expectRevert(Ownable.Unauthorized.selector);
        workerFund.setWorkerRewards(workerRewards);
        vm.prank(slowTimelock);
        workerFund.setWorkerRewards(workerRewards);

        vm.prank(alice); // permissionless
        (uint256 i, uint256 t) = workerFund.release();
        assertEq(i, imdHeld);
        assertEq(t, tokenHeld);
        assertEq(imd.balanceOf(workerRewards), imdHeld);
        assertEq(pondpad.balanceOf(workerRewards), tokenHeld); // forwarded as $PONDPAD (D-45)
        assertEq(workerFund.totalReleased(address(pondpad)), tokenHeld);
        (i, t) = workerFund.release(); // nothing left: no-op
        assertEq(i + t, 0);
    }

    function test_growthFund_relayAndGrantsCappedPerEpoch() public {
        _generateFees();
        imd.mint(address(growthFund), 5_000e18); // e.g. graduation fees and snipe tax
        pondpad.transfer(address(growthFund), 20_000_000e18);

        vm.expectRevert(Ownable.Unauthorized.selector);
        growthFund.payJob(1e18, bytes32("job"), "website");
        vm.startPrank(relay);
        growthFund.payJob(60e18, bytes32("job-1"), "graduation website FROG");
        vm.expectRevert(GrowthFund.AboveCap.selector);
        growthFund.payJob(41e18, bytes32("job-2"), "oracle question");
        growthFund.payJob(40e18, bytes32("job-2"), "oracle question");
        vm.stopPrank();
        assertEq(imd.balanceOf(relay), 100e18);
        assertEq(growthFund.relayAvailable(), 0);

        vm.startPrank(safe);
        growthFund.grant(address(pondpad), grantee, 10_000_000e18, bytes32("g-1"), "creator grant");
        vm.expectRevert(GrowthFund.AboveCap.selector);
        growthFund.grant(address(pondpad), grantee, 1, bytes32("g-2"), "creator grant");
        growthFund.grant(address(imd), grantee, 1_000e18, bytes32("g-3"), "creator grant");
        vm.expectRevert(GrowthFund.AboveCap.selector); // a token with no cap can't be granted
        growthFund.grant(address(usdg), grantee, 1, bytes32("g-4"), "x");
        vm.stopPrank();

        // A new epoch resets both caps.
        vm.warp(START + 30 minutes + 7 days);
        vm.prank(relay);
        growthFund.payJob(100e18, bytes32("job-3"), "graduation website TOAD");
        vm.prank(safe);
        growthFund.grant(address(imd), grantee, 1_000e18, bytes32("g-5"), "creator grant");
        assertEq(imd.balanceOf(grantee), 2_000e18);

        vm.prank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        growthFund.setRelayCap(1_000e18);
        vm.prank(timelock);
        growthFund.setGrantCap(address(usdg), 5e6);
        assertEq(growthFund.grantAvailable(address(usdg)), 5e6);
    }
}
