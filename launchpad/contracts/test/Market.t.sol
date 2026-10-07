// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";
import {Base, MockIMD} from "./Base.t.sol";
import {PadSale} from "../src/PadSale.sol";
import {PondPadToken} from "../src/PondPadToken.sol";
import {PadBurner} from "../src/PadBurner.sol";
import {PadMarketHook} from "../src/PadMarketHook.sol";
import {MarketController} from "../src/MarketController.sol";
import {FixedOwnable} from "../src/FixedOwnable.sol";
import {FeeSplitter} from "../src/FeeSplitter.sol";

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
    address internal migrator = makeAddr("migrator"); // the team Safe runs approved migrations

    function setUp() public virtual override {
        super.setUp();
        for (uint256 i;; i++) {
            pondpad = new PondPadToken{salt: bytes32(i)}(address(this));
            if (address(pondpad) > address(imd)) break;
        }
        burner = new PadBurner(address(pondpad));
        controller = new MarketController(
            timelock,
            slowTimelock,
            address(imd),
            address(pondpad),
            address(splitter),
            address(burner),
            migrator,
            CAP_FLOOR,
            CAP_DECAY
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
            sale.buyWith(address(imd), 100e18, 0, 0, block.timestamp, address(0));
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

/// @dev A v4-legal router that pays before it swaps: sync IMD, transfer, swap, settle, take (audit R3-A2-3).
contract PayFirstRouter is IUnlockCallback {
    IPoolManager internal immutable pm;

    constructor(IPoolManager pm_) {
        pm = pm_;
    }

    function buy(PoolKey memory key, uint256 imdIn) external returns (uint256 out) {
        out = abi.decode(pm.unlock(abi.encode(key, imdIn, msg.sender)), (uint256));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        (PoolKey memory key, uint256 imdIn, address to) = abi.decode(data, (PoolKey, uint256, address));
        pm.sync(key.currency0);
        ERC20(Currency.unwrap(key.currency0)).transfer(address(pm), imdIn);
        BalanceDelta d = pm.swap(key, SwapParams(true, -int256(imdIn), TickMath.MIN_SQRT_PRICE + 1), "");
        pm.settle();
        uint256 out = uint256(uint128(d.amount1()));
        pm.take(key.currency1, to, out);
        return abi.encode(out);
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
        uint256 t0 = START + 30 minutes; // constant: a saved block.timestamp can be re-read under via-IR
        assertEq(block.timestamp, t0);

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
        uint256 t0 = START + 30 minutes; // constant: a saved block.timestamp can be re-read under via-IR
        assertEq(block.timestamp, t0);
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
        controller.setCapFloor(200_000_000e18);
        vm.prank(timelock);
        controller.setCapFloor(200_000_000e18);
        assertEq(market.capFloor(), 200_000_000e18);
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
        uint256 t0 = START + 30 minutes; // constant: a saved block.timestamp can be re-read under via-IR
        assertEq(block.timestamp, t0);
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

        (int24 floorBefore, int24 refBefore, uint256 capBefore) =
            (market.deploymentFloorTick(), market.refTick(), market.inventoryCap());
        PadMarketHook next = _newHook(0x8888, address(controller), address(burner));
        vm.prank(timelock); // the 48 h timelock can't approve a migration
        vm.expectRevert(Ownable.Unauthorized.selector);
        controller.approveMigration(address(next));
        vm.prank(migrator); // nor can the migrator run one that wasn't approved
        vm.expectRevert(MarketController.InvalidSetup.selector);
        controller.migrate(address(next));
        vm.prank(slowTimelock);
        controller.approveMigration(address(next));
        vm.prank(slowTimelock); // the timelock approves; only the migrator (Safe) runs it
        vm.expectRevert(Ownable.Unauthorized.selector);
        controller.migrate(address(next));
        vm.prank(migrator);
        controller.migrate(address(next));
        assertEq(controller.approvedMigration(), address(0)); // one approval, one migration
        assertEq(controller.openedAt(), t0); // airdrop and team vesting clocks don't move (D-53, D-54)

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
        // The guards carry over instead of being reseeded from the price in the migration block (R1-A2-2/3).
        assertGe(next.deploymentFloorTick(), floorBefore);
        assertEq(next.refTick(), refBefore);
        assertGe(next.inventoryCap(), capBefore);
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

    function _approveAndMigrate(address newHook_) internal {
        vm.prank(slowTimelock);
        controller.approveMigration(newHook_);
        vm.prank(migrator);
        controller.migrate(newHook_);
    }

    /// @dev Approves `newHook_` (never reverts), then expects the migrator's `migrate` to revert with `err`.
    function _approveAndExpectMigrateRevert(address newHook_, bytes4 err) internal {
        vm.prank(slowTimelock);
        controller.approveMigration(newHook_);
        vm.prank(migrator);
        vm.expectRevert(err);
        controller.migrate(newHook_);
    }

    function test_market_migrateGuards() public {
        PadMarketHook next = _newHook(0x8888, address(controller), address(burner));
        _approveAndExpectMigrateRevert(address(next), MarketController.MigrationClosed.selector); // not launched

        _graduate();
        // Only the migrator, only the approved hook, only by the sink admin's approval.
        vm.prank(slowTimelock);
        controller.approveMigration(address(next));
        vm.prank(slowTimelock);
        vm.expectRevert(Ownable.Unauthorized.selector);
        controller.migrate(address(next));
        vm.prank(migrator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        controller.approveMigration(address(0x1234));
        PadMarketHook other = _newHook(0xBBBB, address(controller), address(burner));
        vm.prank(migrator);
        vm.expectRevert(MarketController.InvalidSetup.selector);
        controller.migrate(address(other)); // not the approved one

        // Wrong owner, wrong burn sink, the current hook itself: refused.
        PadMarketHook foreign = _newHook(0x9999, address(this), address(burner));
        PadMarketHook badSink = _newHook(0xAAAA, address(controller), address(0xBAD));
        _approveAndExpectMigrateRevert(address(foreign), MarketController.InvalidSetup.selector);
        _approveAndExpectMigrateRevert(address(badSink), MarketController.InvalidSetup.selector);
        _approveAndExpectMigrateRevert(address(market), MarketController.InvalidSetup.selector);

        // After 12 months the market is locked for good.
        vm.warp(controller.migrationDeadline());
        _approveAndExpectMigrateRevert(address(next), MarketController.MigrationClosed.selector);
    }

    /// @dev Audit R1-A2-1: IMD sent to the controller before the Leap (here more than the whole raise) must not
    ///      stop the launch; it joins the protocol fees with the rounding dust.
    function test_market_donationBeforeLaunchCannotBlockIt() public {
        uint256 donation = sale.target() + 1e18;
        imd.mint(address(controller), donation);
        uint256 splitterBefore = imd.balanceOf(address(splitter));
        _graduate();
        assertTrue(controller.launched());
        assertTrue(market.marketOpen());
        assertGe(imd.balanceOf(address(splitter)) - splitterBefore, donation);
        assertEq(imd.balanceOf(address(controller)), 0);
    }

    /// @dev Audit R1-A2-2: pumping $PONDPAD right before a migration must not let the new backstop be placed at the
    ///      pumped price. The new market keeps the old placement floor, so the band starts no lower than before.
    function test_market_migrationKeepsBackstopFloorAfterPump() public {
        _graduate();
        uint256 t0 = START + 30 minutes;
        _swap(false, 40_000_000e18); // sells above the cap: trims build retained IMD
        _nextBlock();
        market.rebalance();
        vm.warp(t0 + 1 days);
        _nextBlock();
        PadMarketHook next = _newHook(0x8888, address(controller), address(burner));
        vm.prank(slowTimelock);
        controller.approveMigration(address(next));

        _swap(true, 2_000e18); // pump $PONDPAD (tick down) in the migration block
        // The floor legitimately decays with time (400 ticks/day, applied on the swap above), so compare with
        // the floor the old market holds right before `migrate`.
        int24 floorBefore = market.deploymentFloorTick();
        assertLt(market.currentTick(), floorBefore);
        vm.prank(migrator);
        controller.migrate(address(next));
        assertGe(next.deploymentFloorTick(), floorBefore, "floor carried over");
        if (next.retainedQuote() >= next.rebalanceQuoteThreshold()) {
            next.rebalance();
            (int24 lower,,) = next.backstop();
            assertGe(lower, floorBefore, "band no lower than the floor the market held");
        }
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

    /// @dev Audit R2-A2-1: IMD that an owner `closeBackstop` returns to the retained balance earns no keeper tip, so
    ///      the 48 h owner can't pay the backstop out to itself with closeBackstop + rebalance in a loop, even with
    ///      the largest tip and lowest threshold its powers allow.
    function test_market_ownerBackstopCloseEarnsNoTip() public {
        _graduate();
        _swap(false, 40_000_000e18); // trims: retained IMD
        _nextBlock();
        market.rebalance(); // real work by a keeper
        uint256 held = market.retainedQuote() + market.backstopQuotePrincipal();
        assertGt(held, 100e18);
        vm.startPrank(timelock);
        controller.setRebalance(true, 40e18 + 1);
        controller.setKeeperReward(40e18);
        uint256 before = imd.balanceOf(timelock);
        for (uint256 i; i < 10; i++) {
            controller.closeBackstop();
            market.rebalance();
        }
        vm.stopPrank();
        assertEq(imd.balanceOf(timelock), before, "no tip for IMD an owner close returned");
        assertApproxEqRel(market.retainedQuote() + market.backstopQuotePrincipal(), held, 1e12, "backstop kept");
    }

    /// @dev Audits R2-A2-1 (migration instance) and R2-A2-5: IMD seeded into the new market earns no keeper tip, and
    ///      the closed hook keeps no allowance on the controller.
    function test_market_migrationSeedEarnsNoTipAndOldHookLosesAllowances() public {
        _graduate();
        _swap(false, 40_000_000e18);
        _nextBlock();
        market.rebalance();
        PadMarketHook next = _newHook(0x8888, address(controller), address(burner));
        _approveAndMigrate(address(next));
        assertEq(imd.allowance(address(controller), address(market)), 0, "old hook: no IMD allowance");
        assertEq(pondpad.allowance(address(controller), address(market)), 0, "old hook: no $PONDPAD allowance");
        assertGe(next.retainedQuote(), next.rebalanceQuoteThreshold(), "backstop IMD seeded");
        uint256 before = imd.balanceOf(migrator);
        vm.prank(migrator);
        next.rebalance();
        assertEq(imd.balanceOf(migrator), before, "seeded IMD earns no tip");
        (,, uint128 band) = next.backstop();
        assertGt(band, 0, "the seed is deployed as the new backstop");
    }

    /// @dev Audit R2-A2-7: a closed market hook can never be opened again (the fee clock and guards would restart).
    function test_market_closedHookNeverReopens() public {
        PadMarketHook h = _newHook(0x9999, address(this), address(burner));
        uint160 p = sale.openingSqrtPriceX96(SALE_TARGET);
        h.initializePool(p);
        imd.mint(address(this), 10_000e18);
        imd.approve(address(h), type(uint256).max);
        pondpad.approve(address(h), type(uint256).max);
        uint128 liquidity = controller.fullRangeLiquidity(p, 1_000e18, 10_000_000e18, 200);
        h.openMarket(liquidity, 10_000_000e18, 1_000e18, CAP_FLOOR, CAP_DECAY);
        h.closeMarket(address(this));
        assertFalse(h.marketOpen());
        vm.expectRevert(PadMarketHook.AlreadyOpen.selector);
        h.openMarket(liquidity, 10_000_000e18, 1_000e18, CAP_FLOOR, CAP_DECAY);
    }

    /// @dev Audit R1-A2-5: the sink admin (7-day timelock) is fixed; it can't hand the sink and migration-approval
    ///      powers to an undelayed address.
    function test_market_sinkAdminIsFixed() public {
        vm.prank(slowTimelock);
        (bool ok,) = address(controller).call(abi.encodeWithSignature("setSinkAdmin(address)", address(this)));
        assertFalse(ok, "no setSinkAdmin");
        assertEq(controller.sinkAdmin(), slowTimelock);
    }

    /// @dev Audit R3-A2-1: the 48 h owner can't remove the cap floor or the decay pace, so ordinary trading can't trim
    ///      the market position away. Both stay adjustable inside the bounds.
    function test_market_capFloorAndDecayAreBounded() public {
        _graduate();
        vm.startPrank(timelock);
        vm.expectRevert(MarketController.PolicyOutOfBounds.selector);
        controller.setCapFloor(0);
        vm.expectRevert(MarketController.PolicyOutOfBounds.selector);
        controller.setCapFloor(CAP_FLOOR - 1);
        vm.expectRevert(MarketController.PolicyOutOfBounds.selector);
        controller.setCapDecay(type(uint128).max);
        vm.expectRevert(MarketController.PolicyOutOfBounds.selector);
        controller.setCapDecay(CAP_DECAY * 5 + 1);
        controller.setCapFloor(CAP_FLOOR * 2); // raising is fine
        controller.setCapFloor(CAP_FLOOR); // and back down to the deploy floor
        controller.setCapDecay(CAP_DECAY * 5);
        controller.setCapDecay(0);
        vm.stopPrank();
        assertEq(market.capFloor(), CAP_FLOOR);
        assertEq(market.capDecayTokensPerDay(), 0);
    }

    /// @dev Audit R3-A2-2: the controller's owner (48 h timelock) and the splitter's (7-day timelock) can't hand their
    ///      powers to an undelayed address, renounce them, or start a handover.
    function test_market_ownersAreFixed() public {
        address undelayed = makeAddr("undelayed");
        vm.startPrank(timelock);
        vm.expectRevert(FixedOwnable.OwnerIsFixed.selector);
        controller.transferOwnership(undelayed);
        vm.expectRevert(FixedOwnable.OwnerIsFixed.selector);
        controller.renounceOwnership();
        vm.stopPrank();
        vm.prank(undelayed);
        vm.expectRevert(FixedOwnable.OwnerIsFixed.selector);
        controller.requestOwnershipHandover();
        assertEq(controller.owner(), timelock);

        // The splitter is built by its deployer, which hands it to the timelock once; after that it is fixed.
        splitter.transferOwnership(slowTimelock);
        vm.prank(slowTimelock);
        vm.expectRevert(FixedOwnable.OwnerIsFixed.selector);
        splitter.transferOwnership(undelayed);
        vm.expectRevert(Ownable.Unauthorized.selector);
        splitter.transferOwnership(address(this)); // nor back by the deployer, which no longer owns it
        assertEq(splitter.owner(), slowTimelock);
    }

    /// @dev Audit R3-A2-3: a router that pays IMD before it swaps (sync, transfer, swap, settle) still works in the
    ///      first swap of a block after a trim, when the hook's matured IMD claims are waiting to be realised.
    function test_market_payFirstRouterWorksWhileClaimsMature() public {
        _graduate();
        _swap(false, 40_000_000e18); // trims: IMD claims wait for a later block
        assertGt(market.quoteClaims(), 0);
        _nextBlock();
        PayFirstRouter r = new PayFirstRouter(IPoolManager(address(pm)));
        imd.mint(address(r), 100e18);
        uint256 before = pondpad.balanceOf(address(this));
        uint256 got = r.buy(market.poolKey(), 100e18);
        assertGt(got, 0);
        assertEq(pondpad.balanceOf(address(this)) - before, got);
        // The claims are realised by any later swap or settle call.
        _swap(true, 1e18);
        market.settleClaims();
        assertEq(market.quoteClaims(), 0);
    }

    /// @dev Audits R3-A2-5 / R3-A2-6: `fundInventory` adds liquidity and raises the cap, refunds only what it pulled and
    ///      didn't use, and sends what others left on the controller to the splitter / burner, not to the owner.
    function test_market_fundInventoryRefundsOnlyItsOwnLeftovers() public {
        _graduate();
        imd.mint(address(controller), 5e18); // someone else's tokens on the controller
        pondpad.transfer(address(controller), 7e18);
        imd.mint(timelock, 10_000e18);
        pondpad.transfer(timelock, 30_000_000e18);
        uint256 splitterBefore = imd.balanceOf(address(splitter));
        uint256 supplyBefore = pondpad.totalSupply();
        uint256 capBefore = market.inventoryCap();
        uint128 liqBefore = market.positionLiquidity();
        uint256 imdBefore = imd.balanceOf(timelock);
        uint256 tokBefore = pondpad.balanceOf(timelock);
        vm.startPrank(timelock);
        imd.approve(address(controller), type(uint256).max);
        pondpad.approve(address(controller), type(uint256).max);
        uint128 liq = liqBefore / 100; // 1% more liquidity
        controller.fundInventory(liq, 30_000_000e18, 10_000e18);
        vm.stopPrank();
        assertEq(market.positionLiquidity(), liqBefore + liq);
        uint256 tokensAdded = market.inventoryCap() - capBefore;
        assertGt(tokensAdded, 0);
        uint256 imdUsed = imdBefore - imd.balanceOf(timelock);
        assertEq(tokBefore - pondpad.balanceOf(timelock), tokensAdded, "the owner paid exactly what was added");
        assertGt(imdUsed, 0);
        assertLt(imdUsed, 10_000e18, "unused IMD came back");
        assertEq(imd.balanceOf(address(splitter)) - splitterBefore, 5e18, "the donation joined the fees");
        assertEq(supplyBefore - pondpad.totalSupply(), 7e18, "the donated $PONDPAD was burned");
        assertEq(imd.balanceOf(address(controller)), 0);
        assertEq(pondpad.balanceOf(address(controller)), 0);
    }

    /// @dev Audit R3-A2-6 (coverage): a rebalance in the same Ethereum block as the trim that funded it.
    function test_market_sameBlockRebalanceAfterTrim() public {
        _graduate();
        _swap(false, 10_000_000e18);
        assertGe(market.retainedQuote(), market.rebalanceQuoteThreshold());
        market.rebalance(); // same block as the trim
        (,, uint128 bandLiquidity) = market.backstop();
        assertGt(bandLiquidity, 0);
        _nextBlock();
        _swap(true, 1e18); // the next block's first swap realises the claims
        assertEq(market.quoteClaims(), 0);
    }

    /// @dev Audit R3-A3-8: the splitter splits only $PONDPAD besides IMD; another token's 40% would be stuck at
    ///      PadBuyer, which can only forward $PONDPAD.
    function test_splitter_distributesOnlyPondpad() public {
        MockIMD stray = new MockIMD();
        stray.mint(address(splitter), 100e18);
        vm.expectRevert(FeeSplitter.NotPondpad.selector);
        splitter.distributeToken(address(stray));
        pondpad.transfer(address(splitter), 100e18);
        splitter.distributeToken(address(pondpad));
        assertEq(pondpad.balanceOf(stakers), 40e18);
    }
}
