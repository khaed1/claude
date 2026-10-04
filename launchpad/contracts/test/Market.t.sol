// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";
import {Base} from "./Base.t.sol";
import {PadSale} from "../src/PadSale.sol";
import {PondPadToken} from "../src/PondPadToken.sol";
import {PadBurner} from "../src/PadBurner.sol";
import {PadMarketHook} from "../src/PadMarketHook.sol";
import {MarketController} from "../src/MarketController.sol";

/// @dev Shared setup: $PONDPAD, sale, market hook, controller and burner on a real PoolManager.
abstract contract MarketBase is Base {
    using StateLibrary for IPoolManager;

    uint256 internal constant SALE_TARGET = 8_460e18;
    uint256 internal constant START = 1_000_000;
    uint256 internal constant CAP_FLOOR = 150_000_000e18;
    uint256 internal constant CAP_DECAY = 500_000e18;
    uint160 internal constant MARKET_FLAGS = Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
        | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG;

    PondPadToken internal pondpad;
    PadBurner internal burner;
    MarketController internal controller;
    PadMarketHook internal market;
    PadSale internal sale;
    PoolSwapTest internal swapper;

    address internal timelock = makeAddr("timelock");
    address internal slowTimelock = makeAddr("slowTimelock");
    address internal dripper = makeAddr("dripper");
    address internal trader = makeAddr("trader");

    function setUp() public virtual override {
        super.setUp();
        for (uint256 i;; i++) {
            pondpad = new PondPadToken{salt: bytes32(i)}(address(this));
            if (address(pondpad) > address(imd)) break;
        }
        burner = new PadBurner(address(pondpad));
        controller = new MarketController(
            timelock, slowTimelock, address(imd), address(pondpad), address(splitter), address(burner), CAP_FLOOR, CAP_DECAY
        );
        address hookAddr = address(uint160(MARKET_FLAGS) | (uint160(0x7777) << 144));
        deployCodeTo(
            "PadMarketHook.sol:PadMarketHook",
            abi.encode(
                address(controller),
                IPoolManager(address(pm)),
                address(imd),
                address(pondpad),
                address(burner),
                dripper,
                uint256(1_500),
                uint256(1_000e18),
                int24(200)
            ),
            hookAddr
        );
        market = PadMarketHook(hookAddr);
        sale = new PadSale(
            address(imd), address(pm), address(config), address(pondpad), address(controller), address(integrators),
            SALE_TARGET, START
        );
        integrators.setSale(address(sale));
        controller.initialize(address(market), address(sale));
        pondpad.approve(address(sale), type(uint256).max);
        sale.fund();

        swapper = new PoolSwapTest(IPoolManager(address(pm)));
        imd.mint(trader, 1_000_000e18);
        pondpad.transfer(trader, 50_000_000e18);
        vm.startPrank(trader);
        imd.approve(address(swapper), type(uint256).max);
        pondpad.approve(address(swapper), type(uint256).max);
        vm.stopPrank();
        vm.warp(START + 30 minutes);
    }

    function _graduate() internal {
        uint256 i;
        while (sale.status() == PadSale.Status.Trading) {
            address buyer = address(uint160(0x40000 + i++));
            imd.mint(buyer, 100e18);
            vm.startPrank(buyer);
            imd.approve(address(sale), type(uint256).max);
            sale.buyWith(address(imd), 100e18, 0, block.timestamp, address(0));
            vm.stopPrank();
        }
    }

    /// @dev Exact-input swap by `trader`. buy = IMD in, $PONDPAD out (IMD is currency0).
    function _swap(bool buy, uint256 amountIn) internal {
        PoolKey memory key = market.poolKey();
        vm.prank(trader);
        swapper.swap(
            key,
            SwapParams({
                zeroForOne: buy,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: buy ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
    }
}

contract MarketTest is MarketBase {
    using StateLibrary for IPoolManager;

    function test_market_opensAtSalePriceWhenSaleGraduates() public {
        uint256 supplyBefore = pondpad.totalSupply();
        _graduate();
        assertTrue(controller.launched());
        assertTrue(market.marketOpen());
        (uint160 sqrtP,,,) = IPoolManager(address(pm)).getSlot0(market.poolId());
        uint256 tokensPerImd = FixedPointMathLib.fullMulDiv(uint256(sqrtP) * sqrtP, 1e18, 1 << 192);
        uint256 curveFinal = FixedPointMathLib.fullMulDiv(sale.y(), 1e18, sale.x());
        assertApproxEqRel(tokensPerImd, curveFinal, 1e12);

        assertApproxEqRel(market.inventoryCap(), 300_000_000e18, 0.00001e18);
        assertApproxEqRel(market.tokensInPool(), 300_000_000e18, 0.00001e18);
        assertApproxEqRel(market.quoteInPool(), SALE_TARGET, 0.0001e18);
        assertEq(market.capFloor(), CAP_FLOOR);
        assertEq(market.capDecayTokensPerDay(), CAP_DECAY);
        assertEq(market.currentFee(), 30_000);
        // The controller keeps nothing: rounding dust went to the splitter (IMD) and was burned ($PONDPAD).
        assertEq(imd.balanceOf(address(controller)), 0);
        assertEq(pondpad.balanceOf(address(controller)), 0);
        assertEq(supplyBefore - pondpad.totalSupply(), burner.totalBurned());
        assertLt(burner.totalBurned(), 1_000e18);
    }

    function test_market_feeFallsFromThreeToOnePercentOverSevenDays() public {
        assertEq(market.currentFee(), 30_000); // before open
        _graduate();
        uint256 t0 = block.timestamp;

        uint256 before = market.totalFeeQuote();
        _swap(true, 100e18);
        assertApproxEqRel(market.totalFeeQuote() - before, 3e18, 1e12, "3% at open");

        vm.warp(t0 + 3.5 days);
        assertEq(market.currentFee(), 20_000);
        before = market.totalFeeQuote();
        _swap(true, 100e18);
        assertApproxEqRel(market.totalFeeQuote() - before, 2e18, 1e12, "2% halfway");

        vm.warp(t0 + 7 days);
        assertEq(market.currentFee(), 10_000);
        uint256 tokenFeeBefore = market.totalFeeToken();
        _swap(false, 1_000_000e18);
        assertApproxEqRel(market.totalFeeToken() - tokenFeeBefore, 10_000e18, 1e12, "1% from day 7, sells pay in $PONDPAD");

        vm.warp(t0 + 365 days);
        assertEq(market.currentFee(), 10_000);
    }

    function test_market_sellsAboveCapAreTrimmedBurnedAndShared() public {
        _graduate();
        uint256 supplyBefore = pondpad.totalSupply();
        uint256 cap = market.inventoryCap();

        _swap(false, 5_000_000e18);
        // The pool holds no more than the cap after the sell; the rest left at an unchanged price.
        assertLe(market.tokensInPool(), cap + 1e18);
        uint256 trimmed = market.totalBurned() + market.totalRewarded();
        assertApproxEqRel(trimmed, 5_000_000e18 * 97 / 100, 0.001e18); // sell minus the 3% fee
        assertApproxEqRel(market.totalRewarded(), trimmed * 15 / 100, 1e12);
        assertGt(market.retainedQuote(), 0); // the IMD removed alongside funds the backstop

        // Claims settle from the next block; then the burner really burns.
        _nextBlock();
        market.settleClaims();
        assertEq(pondpad.balanceOf(dripper), market.totalRewarded());
        burner.burn();
        assertApproxEqAbs(supplyBefore - pondpad.totalSupply(), market.totalBurned(), 1);
    }

    function test_market_buysRatchetCapNoFasterThanDecay() public {
        _graduate();
        uint256 t0 = block.timestamp;
        uint256 cap0 = market.inventoryCap();

        // A large buy right away: no decay allowance yet, so the cap holds.
        _swap(true, 1_000e18);
        assertEq(market.inventoryCap(), cap0);

        // A day later the cap can follow the pool down by at most 500k.
        vm.warp(t0 + 1 days);
        _swap(true, 10e18);
        assertApproxEqAbs(market.inventoryCap(), cap0 - CAP_DECAY, 1e18);

        // The buys took ~30M out, far more than the cap may follow, so a 20M sell only refills: nothing burns.
        uint256 burnedBefore = market.totalBurned();
        _swap(false, 20_000_000e18);
        assertEq(market.totalBurned(), burnedBefore);
        // Selling past the cap trims everything above it.
        _swap(false, 20_000_000e18);
        assertGt(market.totalBurned(), burnedBefore);
        assertLe(market.tokensInPool(), market.inventoryCap() + 1e18);
    }

    function test_market_feesSplitFortyTwentyFiveTwentyFifteenInBothTokens() public {
        _graduate();
        _swap(true, 200e18);
        _swap(false, 2_000_000e18);
        uint256 imdFee = market.feeQuoteClaims();
        uint256 tokenFee = market.feeTokenClaims();
        assertGt(imdFee, 0);
        assertGt(tokenFee, 0);

        _nextBlock();
        uint256 stakersImd = imd.balanceOf(stakers);
        uint256 treasuryImd = imd.balanceOf(treasury);
        controller.collectFees(); // permissionless
        assertEq(market.feeQuoteClaims(), 0);
        assertEq(market.feeTokenClaims(), 0);
        // Splitter may hold other IMD too (sale fees), so check the $PONDPAD side exactly.
        assertEq(pondpad.balanceOf(stakers), tokenFee * 40 / 100);
        assertEq(pondpad.balanceOf(workers), tokenFee * 25 / 100);
        assertEq(pondpad.balanceOf(growth), tokenFee * 20 / 100);
        assertEq(pondpad.balanceOf(treasury), tokenFee - tokenFee * 40 / 100 - tokenFee * 25 / 100 - tokenFee * 20 / 100);
        assertGe(imd.balanceOf(stakers) - stakersImd, imdFee * 40 / 100);
        assertGe(imd.balanceOf(treasury) - treasuryImd, imdFee * 15 / 100);
        assertEq(pondpad.balanceOf(address(splitter)), 0);
    }

    function test_market_controllerLimitsOwnerPowers() public {
        // Only the sale opens the market, once.
        vm.expectRevert(Ownable.Unauthorized.selector);
        controller.launch(1 << 96, 1e18, 1e18);
        vm.expectRevert(Ownable.AlreadyInitialized.selector);
        controller.initialize(address(market), address(sale));
        _graduate();
        vm.prank(address(sale));
        vm.expectRevert(MarketController.AlreadyLaunched.selector);
        controller.launch(1 << 96, 1e18, 1e18);

        // The hook only answers to the controller; the controller has no close / withdraw / transfer path.
        assertEq(market.owner(), address(controller));
        vm.expectRevert(Ownable.Unauthorized.selector);
        market.closeMarket(address(this));
        vm.expectRevert(Ownable.Unauthorized.selector);
        market.withdrawRetainedQuote(address(this), 1);
        vm.expectRevert(Ownable.Unauthorized.selector);
        market.withdrawFees(address(this));

        // Policy: the 48 h timelock. Sinks: the 7-day timelock only.
        vm.expectRevert(Ownable.Unauthorized.selector);
        controller.setCapFloor(100_000_000e18);
        vm.prank(timelock);
        controller.setCapFloor(100_000_000e18);
        assertEq(market.capFloor(), 100_000_000e18);
        vm.prank(timelock);
        vm.expectRevert(Ownable.Unauthorized.selector);
        controller.setBurnSink(address(this));
        vm.prank(slowTimelock);
        controller.setRewardsRecipient(address(0xBEEF));
        assertEq(market.rewardsRecipient(), address(0xBEEF));
        // Reward share stays capped at 30% by the hook itself.
        vm.prank(timelock);
        vm.expectRevert(PadMarketHook.InvalidConfiguration.selector);
        controller.setRewardShareBps(3_001);
    }

    function test_market_outsidersCannotInitializeOrAddLiquidity() public {
        PoolKey memory key = market.poolKey();
        vm.expectRevert();
        IPoolManager(address(pm)).initialize(key, 1 << 96);
        _graduate();
        PoolModifyLiquidityTest lp = new PoolModifyLiquidityTest(IPoolManager(address(pm)));
        imd.approve(address(lp), type(uint256).max);
        pondpad.approve(address(lp), type(uint256).max);
        vm.expectRevert();
        lp.modifyLiquidity(key, ModifyLiquidityParams(-887200, 887200, 1e18, 0), "");
    }

    function test_market_keeperRebalanceDeploysBackstop() public {
        _graduate();
        _swap(false, 10_000_000e18);
        assertGe(market.retainedQuote(), market.rebalanceQuoteThreshold());
        _nextBlock();
        assertTrue(market.pendingRebalance());
        address keeper = makeAddr("keeper");
        market.rebalance();
        (,, uint128 bandLiquidity) = market.backstop();
        assertGt(bandLiquidity, 0);
        assertGt(market.backstopQuotePrincipal(), 0);
        vm.prank(keeper);
        vm.expectRevert(PadMarketHook.RebalanceNotNeeded.selector);
        market.rebalance();
    }

    function _newHook(uint160 prefix, address owner_, address burnSink_) internal returns (PadMarketHook) {
        address addr = address(uint160(MARKET_FLAGS) | (prefix << 144));
        deployCodeTo(
            "PadMarketHook.sol:PadMarketHook",
            abi.encode(
                owner_, IPoolManager(address(pm)), address(imd), address(pondpad), burnSink_, dripper, uint256(1_500),
                uint256(1_000e18), int24(200)
            ),
            addr
        );
        return PadMarketHook(addr);
    }

    function test_market_migrateMovesEverythingIntoNewHook() public {
        _graduate();
        uint256 t0 = block.timestamp;
        _swap(true, 300e18);
        _swap(false, 15_000_000e18); // trims, builds retained IMD
        _nextBlock();
        market.rebalance(); // retained IMD becomes a backstop band
        vm.warp(t0 + 3 days);
        _nextBlock();
        vm.prank(slowTimelock);
        vm.expectRevert(Ownable.Unauthorized.selector); // policy is the 48 h timelock's, not the 7-day one's
        controller.setCapDecay(400_000e18);
        vm.prank(timelock);
        controller.setCapDecay(400_000e18);

        (uint160 priceBefore,,,) = IPoolManager(address(pm)).getSlot0(market.poolId());
        uint256 tokensBefore = market.tokensInPool();
        (,, uint128 band) = market.backstop();
        assertGt(band, 0);
        uint256 feeBefore = market.currentFee();
        uint256 capFloorBefore = market.capFloor();

        PadMarketHook next = _newHook(0x8888, address(controller), address(burner));
        vm.prank(timelock); // the 48 h timelock can't migrate
        vm.expectRevert(Ownable.Unauthorized.selector);
        controller.migrate(address(next));
        vm.prank(slowTimelock);
        controller.migrate(address(next));

        assertEq(address(controller.hook()), address(next));
        assertFalse(market.marketOpen());
        assertTrue(next.marketOpen());
        (uint160 priceAfter,,,) = IPoolManager(address(pm)).getSlot0(next.poolId());
        assertEq(priceAfter, priceBefore, "same price");
        assertApproxEqRel(next.tokensInPool(), tokensBefore, 0.0001e18, "same inventory");
        assertGt(next.retainedQuote(), 0, "backstop IMD carried over");
        assertEq(next.currentFee(), feeBefore, "fee clock continues");
        assertEq(next.capFloor(), capFloorBefore);
        assertEq(next.capDecayTokensPerDay(), 400_000e18);
        assertEq(next.rewardShareBps(), 1_500);
        // The controller kept nothing.
        assertEq(imd.balanceOf(address(controller)), 0);
        assertEq(pondpad.balanceOf(address(controller)), 0);
        // Nothing is left behind in the old hook except settled-claim dust.
        assertLe(imd.balanceOf(address(market)), 1);

        // The new market trades, trims and pays fees as before.
        _swap(true, 50e18);
        _swap(false, 5_000_000e18);
        assertLe(next.tokensInPool(), next.inventoryCap() + next.minTrimTokens());
        _nextBlock();
        controller.collectFees();
        assertEq(next.feeQuoteClaims(), 0);
        next.rebalance();
        (,, uint128 newBand) = next.backstop();
        assertGt(newBand, 0);
    }

    function test_market_migrateGuards() public {
        PadMarketHook next = _newHook(0x8888, address(controller), address(burner));
        vm.prank(slowTimelock);
        vm.expectRevert(MarketController.MigrationClosed.selector); // not launched yet
        controller.migrate(address(next));

        _graduate();
        // Wrong owner, wrong burn sink, the current hook itself: refused.
        PadMarketHook foreign = _newHook(0x9999, address(this), address(burner));
        PadMarketHook badSink = _newHook(0xAAAA, address(controller), address(0xBAD));
        vm.startPrank(slowTimelock);
        vm.expectRevert(MarketController.InvalidSetup.selector);
        controller.migrate(address(foreign));
        vm.expectRevert(MarketController.InvalidSetup.selector);
        controller.migrate(address(badSink));
        vm.expectRevert(MarketController.InvalidSetup.selector);
        controller.migrate(address(market));
        vm.stopPrank();

        // After 12 months the market is locked for good.
        vm.warp(controller.migrationDeadline());
        vm.prank(slowTimelock);
        vm.expectRevert(MarketController.MigrationClosed.selector);
        controller.migrate(address(next));
    }

    function test_market_feeScheduleCanOnlyMoveEarlier() public {
        _graduate();
        uint256 opened = market.marketOpenedAt();
        vm.prank(address(controller));
        vm.expectRevert(PadMarketHook.InvalidConfiguration.selector);
        market.inheritFeeSchedule(opened + 1); // later start = higher fee: refused
        vm.expectRevert(Ownable.Unauthorized.selector);
        market.inheritFeeSchedule(opened - 1 days);
    }

    /// @dev Random trades at either fee level keep POOL4's invariants: the position never holds more than the cap
    ///      (beyond the trim threshold), and the cap never drops below the floor.
    function testFuzz_market_capInvariantAtBothFeeLevels(uint256 seed, bool late) public {
        _graduate();
        if (late) vm.warp(block.timestamp + 8 days);
        assertEq(market.currentFee(), late ? 10_000 : 30_000);
        for (uint256 i; i < 10; i++) {
            seed = uint256(keccak256(abi.encode(seed, i)));
            vm.warp(block.timestamp + (seed % 2 days));
            _nextBlock();
            if (seed % 2 == 0) _swap(true, 1e18 + (seed >> 8) % 500e18);
            else _swap(false, 1e18 + (seed >> 8) % 8_000_000e18);
            assertLe(market.tokensInPool(), market.inventoryCap() + market.minTrimTokens());
            assertGe(market.inventoryCap(), market.capFloor());
        }
    }
}
