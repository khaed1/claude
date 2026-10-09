// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "solady/auth/Ownable.sol";
import {MarketBase} from "./Market.t.sol";
import {MockIMD} from "./Base.t.sol";
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

    // ------------------------------------------------------------------ Audit round 4 (coverage, R4-A3-9)

    /// @dev Audit R4-A3-9 (coverage): the splitter's shares stay in their ranges and add up to 100%; only its owner sets
    ///      them.
    function test_splitter_sharesStayInTheirRanges() public {
        FeeSplitter.Shares[6] memory bad = [
            FeeSplitter.Shares({stakers: 4_000, workers: 2_500, growth: 2_000, treasury: 1_400}), // 99.9%
            FeeSplitter.Shares({stakers: 2_400, workers: 3_500, growth: 3_000, treasury: 1_100}), // stakers < 25%
            FeeSplitter.Shares({stakers: 6_100, workers: 1_500, growth: 1_400, treasury: 1_000}), // stakers > 60%
            FeeSplitter.Shares({stakers: 4_500, workers: 1_400, growth: 2_100, treasury: 2_000}), // workers < 15%
            FeeSplitter.Shares({stakers: 3_000, workers: 2_500, growth: 3_100, treasury: 1_400}), // growth > 30%
            FeeSplitter.Shares({stakers: 4_000, workers: 2_500, growth: 1_400, treasury: 2_100}) // treasury > 20%
        ];
        for (uint256 i; i < bad.length; i++) {
            vm.expectRevert(FeeSplitter.InvalidShares.selector);
            splitter.setShares(bad[i]);
        }
        vm.prank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        splitter.setShares(FeeSplitter.Shares({stakers: 6_000, workers: 1_500, growth: 1_500, treasury: 1_000}));
        splitter.setShares(FeeSplitter.Shares({stakers: 6_000, workers: 1_500, growth: 1_500, treasury: 1_000}));
        FeeSplitter.Shares memory s = splitter.shares();
        assertEq(s.stakers, 6_000);
    }

    /// @dev Audit R4-A3-9 (coverage): the 48 h timelock replaces the relay and the granter (zero switches a path off);
    ///      the old keys lose their power at once.
    function test_growthFund_relayAndGranterReplaced() public {
        imd.mint(address(growthFund), 1_000e18);
        address newRelay = makeAddr("newRelay");
        vm.prank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        growthFund.setRelay(newRelay);
        vm.startPrank(timelock);
        growthFund.setRelay(newRelay);
        growthFund.setGranter(address(0));
        vm.stopPrank();
        vm.prank(relay);
        vm.expectRevert(Ownable.Unauthorized.selector);
        growthFund.payJob(1e18, bytes32("old"), "old relay");
        vm.prank(newRelay);
        growthFund.payJob(1e18, bytes32("new"), "new relay");
        assertEq(imd.balanceOf(newRelay), 1e18);
        vm.prank(safe);
        vm.expectRevert(Ownable.Unauthorized.selector);
        growthFund.grant(address(imd), grantee, 1e18, bytes32("g"), "granter switched off");
    }

    /// @dev Audit R4-A3-9 (coverage): `WorkerFund.releaseToken` forwards a third token sent there to the worker rewards
    ///      address, only once that address is set.
    function test_workerFund_releasesAThirdToken() public {
        MockIMD other = new MockIMD();
        other.mint(address(workerFund), 7e18);
        vm.expectRevert(WorkerFund.RecipientNotSet.selector);
        workerFund.releaseToken(address(other));
        vm.prank(slowTimelock);
        workerFund.setWorkerRewards(workerRewards);
        assertEq(workerFund.releaseToken(address(other)), 7e18);
        assertEq(other.balanceOf(workerRewards), 7e18);
        assertEq(workerFund.releaseToken(address(other)), 0);
    }

    /// @dev Audits R6-A3-6 (coverage), R6-A3-4 and R6-A4-3 (accepted): a grant to address(0) is refused; a zero grant or
    ///      job payment passes, even in a token without a cap, and moves nothing; the relay can be set to address(0)
    ///      (the 48 h owner sets it again).
    function test_growthFund_zeroAddressesAndZeroAmounts() public {
        vm.prank(safe);
        vm.expectRevert(GrowthFund.ZeroAddress.selector);
        growthFund.grant(address(imd), address(0), 1, bytes32(0), "to nobody");
        MockIMD uncapped = new MockIMD();
        assertEq(growthFund.grantCap(address(uncapped)), 0);
        vm.prank(safe);
        growthFund.grant(address(uncapped), grantee, 0, bytes32(0), "zero");
        vm.prank(safe);
        vm.expectRevert(GrowthFund.AboveCap.selector);
        growthFund.grant(address(uncapped), grantee, 1, bytes32(0), "one wei");
        vm.prank(relay);
        growthFund.payJob(0, bytes32(0), "zero job");
        assertEq(uncapped.balanceOf(grantee), 0);
        vm.prank(timelock);
        growthFund.setRelay(address(0));
        assertEq(growthFund.relay(), address(0));
        vm.prank(timelock);
        growthFund.setRelay(relay);
    }
}
