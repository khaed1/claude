// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "solady/tokens/ERC20.sol";
import {Vm} from "forge-std/Vm.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {CustomRevert} from "v4-core/libraries/CustomRevert.sol";
import {PadHook} from "../src/PadHook.sol";
import {Base} from "./Base.t.sol";
import {BondingCurve} from "../src/BondingCurve.sol";
import {PadToken} from "../src/PadToken.sol";
import {PadConfig} from "../src/PadConfig.sol";
import {CoinFees} from "../src/FeeLib.sol";
import {Hop} from "../src/Route.sol";
import {PadRouter} from "../src/PadRouter.sol";
import {PaymentSwapper} from "../src/PaymentSwapper.sol";

/// @dev Wraps a curve buy in its own PoolManager unlock (audit R1-A1-1).
contract UnlockWrapper {
    IPoolManager internal immutable pm;
    PadRouter internal immutable router;
    address internal immutable imd;

    constructor(IPoolManager pm_, PadRouter router_, address imd_) {
        pm = pm_;
        router = router_;
        imd = imd_;
    }

    function wrappedBuy(address coin, uint256 amount) external {
        ERC20(imd).approve(address(router), amount);
        pm.unlock(abi.encode(coin, amount));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        (address coin, uint256 amount) = abi.decode(data, (address, uint256));
        router.buyWith(coin, imd, amount, 0, 0, block.timestamp, address(0));
        return "";
    }
}

contract PondPadTest is Base {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    // ------------------------------------------------------------------ Launch and curve

    function test_launch_chargesFeeAndOpensCurveAtStartPrice() public {
        uint256 before = imd.balanceOf(address(splitter));
        address coin = _launch(_noTax(), 0);
        assertEq(imd.balanceOf(address(splitter)) - before, 1e18, "launch fee");
        assertEq(PadToken(coin).balanceOf(address(curve)), 1_000_000_000e18);
        assertEq(uint8(curve.statusOf(coin)), uint8(BondingCurve.Status.Trading));
        assertEq(vault.recipientOf(coin), creator);
        assertEq(PadToken(coin).owner(), address(0));

        // Start market cap ≈ 0.3125 × target ≈ 643.75 IMD.
        uint256 mcap = curve.priceOf(coin) * 1e9;
        assertApproxEqRel(mcap, (TARGET * 3125) / 10_000, 1e15);
    }

    function test_devBuy_isExemptFromSnipeTaxAndMaxBuy() public {
        vm.prank(creator);
        (address coin, uint256 out) =
            router.launchWith(_params("FROG", _noTax(), 0), address(imd), 201e18, true, 0, 0, address(0));
        assertGt(out, 20_000_000e18, "dev buy above the 2% window cap");
        assertEq(imd.balanceOf(growth), 0, "no snipe tax on dev buy");
        assertEq(PadToken(coin).balanceOf(creator), out);
    }

    function test_snipeTax_decaysAndGoesToGrowth() public {
        uint256 t0 = block.timestamp;
        address coin = _launch(_noTax(), 0);
        assertEq(curve.snipeTaxBps(coin), 5_000);
        _buy(alice, coin, 4e18);
        assertEq(imd.balanceOf(growth), 2e18, "50% snipe tax at launch");

        vm.warp(t0 + 10);
        assertEq(curve.snipeTaxBps(coin), 2_500);
        vm.warp(t0 + 20);
        assertEq(curve.snipeTaxBps(coin), 0);
    }

    function test_maxBuy_capsWalletsDuringWindow() public {
        address coin = _launch(_noTax(), 0);
        uint256 t0 = block.timestamp;
        vm.warp(t0 + 30); // snipe tax over, max-buy window still on
        vm.prank(alice);
        vm.expectRevert(BondingCurve.MaxBuyExceeded.selector);
        router.buyWith(coin, address(imd), 200e18, 0, 0, block.timestamp, address(0));

        vm.warp(t0 + 61);
        _buy(alice, coin, 200e18);
    }

    function test_buy_splitsFees() public {
        address coin = _launch(_holderTax(50), 0);
        vm.warp(block.timestamp + 1 hours);
        _buy(bob, coin, 10e18); // a first holder (the first buy's own holder tax goes to growth, audit R2-A1-3)
        uint256 splitterBefore = imd.balanceOf(address(splitter));
        uint256 vaultBefore = vault.balanceOf(coin);
        _buy(alice, coin, 100e18);
        assertEq(imd.balanceOf(address(splitter)) - splitterBefore, 1e18, "protocol 1%");
        assertEq(vault.balanceOf(coin) - vaultBefore, 0.5e18, "creator 0.5%");
        assertEq(imd.balanceOf(coin), 0.5e18, "holders 0.5%");
    }

    function test_swarmBudgetTax() public {
        address coin = _launch(CoinFees(100, 5_000, 0, 5_000), 0);
        vm.warp(block.timestamp + 1 hours);
        _buy(alice, coin, 100e18);
        assertEq(budget.balanceOf(coin), 0.5e18, "half of 1% tax to the swarm budget");
        assertEq(vault.balanceOf(coin), 0.5e18 + 0.5e18, "creator base + half of tax");

        vm.prank(creator);
        uint256 id = budget.requestSpend(coin, 0.4e18, keccak256("site update"));
        vm.prank(relay);
        budget.release(id, "job-123");
        assertEq(imd.balanceOf(relay), 0.4e18);
    }

    function test_sell_returnsLessThanPaid() public {
        address coin = _launch(_noTax(), 0);
        vm.warp(block.timestamp + 1 hours);
        uint256 out = _buy(alice, coin, 100e18);
        uint256 back = _sell(alice, coin, out);
        assertLt(back, 100e18);
        assertApproxEqRel(back, 97.0225e18, 1e15, "two 1.5% fees");
    }

    function test_creatorClaims() public {
        address coin = _launch(_noTax(), 0);
        vm.warp(block.timestamp + 1 hours);
        _buy(alice, coin, 100e18);
        uint256 before = imd.balanceOf(creator);
        vault.claim(coin);
        assertEq(imd.balanceOf(creator) - before, 0.5e18);
    }

    function test_dividends_paidToHoldersNotMarket() public {
        address coin = _launch(_holderTax(100), 0);
        vm.warp(block.timestamp + 1 hours);
        _buy(alice, coin, 100e18);
        _buy(bob, coin, 100e18);
        uint256 aliceDiv = PadToken(coin).withdrawableDividendOf(alice);
        assertGt(aliceDiv, 0);
        assertEq(PadToken(coin).withdrawableDividendOf(address(curve)), 0);

        uint256 before = imd.balanceOf(alice);
        vm.prank(alice);
        PadToken(coin).claim();
        assertEq(imd.balanceOf(alice) - before, aliceDiv);
    }

    // ------------------------------------------------------------------ Graduation

    function test_graduation_seedsLockedPoolAtCurvePrice_imdFirst() public {
        _graduationFlow(true);
    }

    function test_graduation_seedsLockedPoolAtCurvePrice_coinFirst() public {
        _graduationFlow(false);
    }

    function _graduationFlow(bool imdFirst) internal {
        address coin = _launchOrdered(_holderTax(50), imdFirst);
        uint256 growthBefore = imd.balanceOf(growth);
        uint256 pmImdBefore = imd.balanceOf(address(pm));
        _fillCurve(coin);
        assertEq(uint8(curve.statusOf(coin)), uint8(BondingCurve.Status.Graduated));

        // The curve keeps nothing; the pool holds ~99% of the target and 198M tokens.
        assertEq(imd.balanceOf(address(curve)), 0, "curve empty");
        assertEq(PadToken(coin).balanceOf(address(curve)), 0, "curve has no tokens");
        assertApproxEqRel(imd.balanceOf(address(pm)) - pmImdBefore, (TARGET * 99) / 100, 1e14, "pool IMD");
        assertApproxEqRel(PadToken(coin).balanceOf(address(pm)), 198_000_000e18, 1e14, "pool tokens");
        assertGt(imd.balanceOf(growth) - growthBefore, (TARGET * 99) / 10_000, "graduation fee to growth");
        assertApproxEqAbs(PadToken(coin).totalSupply(), 998_000_000e18, 1e6, "1% of reserve (plus rounding dust) burned");

        // Pool price equals the curve's final price E/R.
        PoolKey memory key = hook.poolKey(coin);
        (uint160 sqrtP,,,) = IPoolManager(address(pm)).getSlot0(key.toId());
        uint256 p = uint256(sqrtP) * uint256(sqrtP) >> 96; // currency1 per currency0, Q96
        uint256 imdPerToken = imdFirst ? (1 << 96) * 1e18 / p : p * 1e18 / (1 << 96);
        assertApproxEqRel(imdPerToken, TARGET * 1e18 / 200_000_000e18, 1e15, "pool price");

        _postGraduationTrading(coin, key, imdFirst);
    }

    function _postGraduationTrading(address coin, PoolKey memory key, bool imdFirst) internal {
        // Router buy and sell through the pool, with fees flushed to their destinations.
        uint256 splitterBefore = imd.balanceOf(address(splitter));
        uint256 vaultBefore = vault.balanceOf(coin);
        uint256 out = _buy(alice, coin, 100e18);
        assertGt(out, 0);
        assertEq(imd.balanceOf(address(splitter)) - splitterBefore, 1e18, "protocol 1% after graduation");
        assertEq(vault.balanceOf(coin) - vaultBefore, 0.5e18, "creator 0.5% after graduation");

        uint256 back = _sell(alice, coin, out);
        assertApproxEqRel(back, 96.04e18, 2e15, "round trip pays 2% twice");

        // A third-party router trades the pool and still pays the fee.
        PoolSwapTest swapper = new PoolSwapTest(IPoolManager(address(pm)));
        imd.mint(address(this), 1_000e18);
        imd.approve(address(swapper), type(uint256).max);
        splitterBefore = imd.balanceOf(address(splitter));
        swapper.swap(
            key,
            SwapParams({
                zeroForOne: imdFirst,
                amountSpecified: -10e18,
                sqrtPriceLimitX96: imdFirst ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
        hook.flush(coin);
        assertEq(imd.balanceOf(address(splitter)) - splitterBefore, 0.1e18, "fee through third-party router");

        // A partial fill (tight price limit) reverts instead of overcharging.
        (uint160 sqrtP,,,) = IPoolManager(address(pm)).getSlot0(key.toId());
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                IHooks.afterSwap.selector,
                abi.encodeWithSelector(PadHook.PartialFill.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        swapper.swap(
            key,
            SwapParams({
                zeroForOne: imdFirst,
                amountSpecified: -100e18,
                sqrtPriceLimitX96: imdFirst ? sqrtP - sqrtP / 100_000 : sqrtP + sqrtP / 100_000
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );

        // Nobody else can add liquidity, and the hook's position can never be removed.
        PoolModifyLiquidityTest lp = new PoolModifyLiquidityTest(IPoolManager(address(pm)));
        imd.approve(address(lp), type(uint256).max);
        vm.expectRevert();
        lp.modifyLiquidity(key, ModifyLiquidityParams(-887200, 887200, 1e18, 0), "");
        vm.expectRevert();
        lp.modifyLiquidity(key, ModifyLiquidityParams(-887200, 887200, -1e18, 0), "");

        // Nobody can create another pool with this hook.
        PoolKey memory other = key;
        other.tickSpacing = 60;
        vm.expectRevert();
        pm.initialize(other, uint160(1 << 96));
    }

    function test_graduation_refundsOvershoot() public {
        address coin = _launch(_noTax(), 0);
        vm.warp(block.timestamp + 1 hours);
        uint256 before = imd.balanceOf(alice);
        _buy(alice, coin, 5_000e18);
        assertEq(uint8(curve.statusOf(coin)), uint8(BondingCurve.Status.Graduated));
        uint256 spent = before - imd.balanceOf(alice);
        // Net raise ≈ target; gross ≈ target / (1 - 1.5%).
        assertApproxEqRel(spent, (TARGET * 10_000) / 9_850, 1e14, "only the curve's cost was taken");
        assertEq(PadToken(coin).balanceOf(alice), 800_000_000e18);
    }

    /// @dev Audit R1-A1-1 (and R1-A1-2): a curve buy wrapped in an outside PoolManager unlock is refused, so the
    ///      buyer can't hold its tokens before its own holder tax is credited (and a curve can't be left Full).
    function test_curve_refusesTradesInsideOutsideUnlock() public {
        address coin = _launch(CoinFees(300, 0, 10_000, 0), 0);
        vm.warp(block.timestamp + 1 hours);
        _buy(alice, coin, 100e18);
        UnlockWrapper w = new UnlockWrapper(IPoolManager(address(pm)), router, address(imd));
        imd.mint(address(w), 1_000e18);
        vm.expectRevert();
        w.wrappedBuy(coin, 1_000e18);
        assertEq(PadToken(coin).balanceOf(address(w)), 0);
        assertEq(PadToken(coin).withdrawableDividendOf(address(w)), 0);
    }

    /// @dev Audit R1-A1-4: the quote for a buy that completes the curve shows the fee actually charged.
    function test_quoteBuy_completingBuyChargesOnlyWhatItNeeds() public {
        address coin = _launch(CoinFees(100, 0, 10_000, 0), 0);
        vm.warp(block.timestamp + 1 hours);
        (uint256 qOut, uint256 qFee,) = curve.quoteBuy(coin, 5_000e18);
        uint256 before = imd.balanceOf(alice);
        uint256 out = _buy(alice, coin, 5_000e18);
        uint256 spent = before - imd.balanceOf(alice);
        assertEq(qOut, out);
        assertEq(qFee, (spent * 250) / 10_000, "quoted fee = fee on the IMD actually taken");
    }

    /// @dev Audit R1-A1-8: the curve gives the hook no standing IMD allowance (graduation transfers).
    function test_curve_noStandingAllowanceToHook() public view {
        assertEq(imd.allowance(address(curve), address(hook)), 0);
    }

    /// @dev Audit R1-A4-4 (D-78): the fee splitter and growth fund can't be changed, even by the owner, so live
    ///      coins' fee routing only changes through the FeeSplitter's own 7-day settings.
    function test_config_feeSplitterAndGrowthFundAreFixed() public {
        (bool ok,) = address(config).call(abi.encodeWithSignature("setFeeSplitter(address)", alice));
        assertFalse(ok, "no setFeeSplitter");
        (ok,) = address(config).call(abi.encodeWithSignature("setGrowthFund(address)", alice));
        assertFalse(ok, "no setGrowthFund");
        assertEq(config.feeSplitter(), address(splitter));
    }

    /// @dev Audit R1-A4-11: once a coin's fees go to its holders, anyone can cancel open swarm requests, so requests the
    ///      recipient opened before routing the fees to the holders can't lock the budget the holders should receive.
    function test_swarmBudget_anyoneCancelsOnceFeesGoToHolders() public {
        address coin = _launch(CoinFees(100, 0, 0, 10_000), 0);
        vm.warp(block.timestamp + 1 hours);
        _buy(alice, coin, 100e18);
        vm.startPrank(creator);
        uint256 id = budget.requestSpend(coin, 0.5e18, keccak256("site"));
        vault.setRecipient(coin, coin);
        vm.stopPrank();
        vm.prank(bob);
        budget.cancel(id);
        assertEq(budget.reservedOf(coin), 0);
    }

    function test_curveClosedAfterGraduation() public {
        address coin = _launch(_noTax(), 0);
        _fillCurve(coin);
        vm.prank(address(router));
        vm.expectRevert(BondingCurve.NotTrading.selector);
        curve.sell(coin, 1e18, 0, alice, alice, address(0));
    }

    /// @dev Audit R3-A1-4: a requested dev buy that buys nothing (only the launch fee arrived) honours `minTokensOut`.
    function test_launch_devBuyThatBuysNothingHonoursMinTokensOut() public {
        vm.prank(creator);
        vm.expectRevert(PadRouter.Slippage.selector);
        router.launchWith(_params("FROG", _noTax(), bytes32(0)), address(imd), 1e18, true, 0, 1, address(0));
    }

    /// @dev Audit R3-A1-5: when the dev buy completes the curve and part of it is refunded, `Launched` reports the IMD
    ///      the dev buy kept.
    function test_launch_eventReportsWhatTheDevBuyKept() public {
        uint256 before = imd.balanceOf(creator);
        vm.recordLogs();
        vm.prank(creator);
        (address coin,) =
            router.launchWith(_params("FROG", _noTax(), bytes32(0)), address(imd), 3_001e18, true, 0, 0, address(0));
        assertEq(uint8(curve.statusOf(coin)), uint8(BondingCurve.Status.Graduated));
        uint256 kept = before - imd.balanceOf(creator) - 1e18; // less the launch fee
        assertLt(kept, 3_000e18, "part of the dev buy was refunded");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 sig = keccak256("Launched(address,address,uint256,uint256)");
        bool seen;
        for (uint256 i; i < logs.length; i++) {
            if (logs[i].emitter == address(router) && logs[i].topics[0] == sig) {
                (uint256 devBuyImd,) = abi.decode(logs[i].data, (uint256, uint256));
                assertEq(devBuyImd, kept);
                seen = true;
            }
        }
        assertTrue(seen);
    }

    // ------------------------------------------------------------------ ETH payments

    function test_launchWithEth_paysFeeAndDevBuys() public {
        uint256 splitterBefore = imd.balanceOf(address(splitter));
        vm.prank(creator);
        (address coin, uint256 out) =
            router.launchWith{value: 0.1 ether}(_params("FROG", _noTax(), 0), address(0), 0.1 ether, true, 0, 0, address(0));
        // 1 IMD launch fee + the dev buy's own 1% protocol fee (~0.1 ETH ≈ 41 IMD).
        uint256 toSplitter = imd.balanceOf(address(splitter)) - splitterBefore;
        assertGt(toSplitter, 1e18, "launch fee in IMD");
        assertApproxEqRel(toSplitter, 1e18 + 0.41e18, 5e16);
        assertGt(out, 0);
        assertEq(PadToken(coin).balanceOf(creator), out);
        assertEq(imd.balanceOf(address(router)), 0, "router keeps nothing");
    }

    function test_launchWithEth_withoutDevBuyReturnsImd() public {
        uint256 before = imd.balanceOf(creator);
        uint256 splitterBefore = imd.balanceOf(address(splitter));
        vm.prank(creator);
        router.launchWith{value: 0.1 ether}(_params("FROG", _noTax(), 0), address(0), 0.1 ether, false, 0, 0, address(0));
        assertGt(imd.balanceOf(creator), before, "unused IMD returned");
        assertEq(imd.balanceOf(address(splitter)) - splitterBefore, 1e18, "exactly the launch fee");
    }

    function test_ethRoundTrip_onCurve() public {
        address coin = _launch(_noTax(), 0);
        vm.warp(block.timestamp + 1 hours);
        uint256 ethBefore = alice.balance;
        vm.prank(alice);
        uint256 out = router.buyWith{value: 0.2 ether}(coin, address(0), 0.2 ether, 0, 0, block.timestamp, address(0));
        assertGt(out, 0);
        // ~0.2 ETH × 423 IMD, minus the 1% IMD/ETH pool fee and price impact, minus 1.5%.
        assertApproxEqRel(curve.coinInfo(coin).raised, 0.2e18 * 423 * 99 / 100 * 9850 / 10_000, 2e16);

        vm.startPrank(alice);
        ERC20(coin).approve(address(router), out);
        uint256 ethOut = router.sellFor(coin, address(0), out, 0, block.timestamp, address(0));
        vm.stopPrank();
        assertApproxEqRel(alice.balance, ethBefore - 0.2 ether + ethOut, 0);
        assertApproxEqRel(ethOut, 0.2 ether * 9600 / 10_000, 1e16, "two pool fees + two curve fees");
        assertEq(imd.balanceOf(address(router)), 0);
        assertEq(address(router).balance, 0);
    }

    function test_ethRoundTrip_afterGraduation() public {
        address coin = _launch(_holderTax(50), 0);
        _fillCurve(coin);
        uint256 splitterBefore = imd.balanceOf(address(splitter));
        vm.prank(alice);
        uint256 out = router.buyWith{value: 0.2 ether}(coin, address(0), 0.2 ether, 0, 0, block.timestamp, address(0));
        assertGt(out, 0);
        assertGt(imd.balanceOf(address(splitter)), splitterBefore, "coin fee charged and flushed");

        uint256 ethBefore = alice.balance;
        vm.startPrank(alice);
        ERC20(coin).approve(address(router), out);
        uint256 ethOut = router.sellFor(coin, address(0), out, 0, block.timestamp, address(0));
        vm.stopPrank();
        assertEq(alice.balance - ethBefore, ethOut);
        assertApproxEqRel(ethOut, 0.2 ether * 9400 / 10_000, 1e16, "two pool fees + two 2% coin fees");
        assertEq(address(router).balance, 0);
    }

    function test_buyWithEth_slippageReverts() public {
        address coin = _launch(_noTax(), 0);
        vm.warp(block.timestamp + 1 hours);
        vm.prank(alice);
        vm.expectRevert();
        router.buyWith{value: 0.2 ether}(coin, address(0), 0.2 ether, 0, type(uint256).max, block.timestamp, address(0));
    }

    // ------------------------------------------------------------------ USDG payments (two hops: USDG → ETH → IMD)

    function test_usdg_launchBuyAndSellOnCurve() public {
        vm.prank(creator);
        (address coin, uint256 devOut) =
            router.launchWith(_params("FROG", _noTax(), 0), address(usdg), 100e6, true, 0, 0, address(0));
        assertGt(devOut, 0, "dev buy paid in USDG");

        vm.warp(block.timestamp + 1 hours);
        uint256 usdgBefore = usdg.balanceOf(alice);
        uint256 raisedBefore = curve.coinInfo(coin).raised;
        vm.prank(alice);
        uint256 out = router.buyWith(coin, address(usdg), 500e6, 0, 0, block.timestamp, address(0));
        assertEq(usdgBefore - usdg.balanceOf(alice), 500e6);
        // 500 USDG ≈ 0.1875 ETH ≈ 79 IMD, minus pool fees and 1.5%.
        assertApproxEqRel(curve.coinInfo(coin).raised - raisedBefore, 79.3e18 * 99 / 100 * 9850 / 10_000, 3e16);

        vm.startPrank(alice);
        ERC20(coin).approve(address(router), out);
        uint256 usdgOut = router.sellFor(coin, address(usdg), out, 0, block.timestamp, address(0));
        vm.stopPrank();
        assertApproxEqRel(usdgOut, 500e6 * 9500 / 10_000, 2e16, "round trip through both pools and the curve");
        assertEq(usdg.balanceOf(address(router)), 0);
        assertEq(imd.balanceOf(address(router)), 0);
    }

    function test_usdg_afterGraduation() public {
        address coin = _launch(_noTax(), 0);
        _fillCurve(coin);
        vm.prank(alice);
        uint256 out = router.buyWith(coin, address(usdg), 500e6, 0, 0, block.timestamp, address(0));
        assertGt(out, 0);
        vm.startPrank(alice);
        ERC20(coin).approve(address(router), out);
        uint256 usdgOut = router.sellFor(coin, address(usdg), out, 0, block.timestamp, address(0));
        vm.stopPrank();
        assertApproxEqRel(usdgOut, 500e6 * 9500 / 10_000, 2e16);
    }

    function test_unsupportedPaymentTokenReverts() public {
        address coin = _launch(_noTax(), 0);
        vm.prank(alice);
        vm.expectRevert(PaymentSwapper.UnsupportedToken.selector);
        router.buyWith(coin, address(0xdead), 1e18, 0, 0, block.timestamp, address(0));
    }

    function test_ethAmountMustMatchValue() public {
        address coin = _launch(_noTax(), 0);
        vm.prank(alice);
        vm.expectRevert(PaymentSwapper.WrongEthAmount.selector);
        router.buyWith{value: 0.1 ether}(coin, address(0), 0.2 ether, 0, 0, block.timestamp, address(0));
        vm.prank(alice);
        vm.expectRevert(PaymentSwapper.WrongEthAmount.selector);
        router.buyWith{value: 0.1 ether}(coin, address(imd), 1e18, 0, 0, block.timestamp, address(0));
    }

    function test_paymentRoutes_validatedAndRemovable() public {
        address[] memory tokens = config.paymentTokens();
        assertEq(tokens.length, 2);
        // A route that doesn't end in IMD is rejected.
        Hop[] memory bad = new Hop[](1);
        bad[0] = Hop(ethUsdgKey, true); // ETH → USDG
        vm.expectRevert(PadConfig.InvalidSetting.selector);
        config.setPaymentRoute(address(0), bad);
        // Only the owner (timelock) can change routes.
        vm.prank(alice);
        vm.expectRevert();
        config.removePaymentRoute(address(usdg));
        config.removePaymentRoute(address(usdg));
        assertFalse(config.isPaymentToken(address(usdg)));
        assertEq(config.paymentTokens().length, 1);
    }

    // ------------------------------------------------------------------ Integrator share

    function test_integrator_earnsShareOnCurveTrades() public {
        address app = makeAddr("app");
        config.setIntegrator(app, true);
        address coin = _launch(_noTax(), 0);
        vm.warp(block.timestamp + 1 hours);

        uint256 splitterBefore = imd.balanceOf(address(splitter));
        vm.prank(alice);
        router.buyWith(coin, address(imd), 100e18, 0, 0, block.timestamp, app);
        assertEq(integrators.balanceOf(app), 0.15e18, "15% of the 1% protocol fee");
        assertEq(imd.balanceOf(address(splitter)) - splitterBefore, 0.85e18, "splitter gets the rest");
        assertEq(vault.balanceOf(coin), 0.5e18, "creator untouched");

        integrators.claim(app);
        assertEq(imd.balanceOf(app), 0.15e18);
    }

    function test_integrator_unregisteredReferrerEarnsNothing() public {
        address coin = _launch(_noTax(), 0);
        vm.warp(block.timestamp + 1 hours);
        uint256 splitterBefore = imd.balanceOf(address(splitter));
        vm.prank(alice);
        router.buyWith(coin, address(imd), 100e18, 0, 0, block.timestamp, makeAddr("stranger"));
        assertEq(imd.balanceOf(address(splitter)) - splitterBefore, 1e18);
        assertEq(imd.balanceOf(address(integrators)), 0);
    }

    function test_integrator_earnsShareAfterGraduation() public {
        address app = makeAddr("app");
        config.setIntegrator(app, true);
        address coin = _launch(_holderTax(50), 0);
        _fillCurve(coin);

        uint256 splitterBefore = imd.balanceOf(address(splitter));
        vm.prank(alice);
        router.buyWith(coin, address(imd), 100e18, 0, 0, block.timestamp, app);
        assertEq(integrators.balanceOf(app), 0.15e18, "flushed to the vault after the pool trade");
        assertEq(imd.balanceOf(address(splitter)) - splitterBefore, 0.85e18);
        assertEq(hook.pendingIntegrator(app), 0);
    }

    function test_integrator_cannotBeSpoofedThroughOtherRouters() public {
        address app = makeAddr("app");
        config.setIntegrator(app, true);
        address coin = _launch(_noTax(), 0);
        _fillCurve(coin);
        PoolKey memory key = hook.poolKey(coin);
        bool imdIs0 = Currency.unwrap(key.currency0) == address(imd);
        PoolSwapTest swapper = new PoolSwapTest(IPoolManager(address(pm)));
        imd.mint(address(this), 100e18);
        imd.approve(address(swapper), type(uint256).max);
        swapper.swap(
            key,
            SwapParams({
                zeroForOne: imdIs0,
                amountSpecified: -10e18,
                sqrtPriceLimitX96: imdIs0 ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            abi.encode(address(this), app)
        );
        assertEq(hook.pendingIntegrator(app), 0, "hook data from other routers is ignored");
    }

    function test_integrator_shareIsBoundedAndOnlyGuardianRegisters() public {
        vm.expectRevert(PadConfig.InvalidSetting.selector);
        config.setIntegratorShareBps(2_600);
        vm.prank(alice);
        vm.expectRevert(PadConfig.NotGuardian.selector);
        config.setIntegrator(alice, true);
    }

    // ------------------------------------------------------------------ Config bounds

    function test_config_rejectsOutOfRangeSettings() public {
        PadConfig.LaunchSettings memory s = config.launchSettings();
        s.launchFee = 11e18;
        vm.expectRevert(PadConfig.InvalidSetting.selector);
        config.setLaunchSettings(s);
    }

    function test_pausedLaunches() public {
        config.setLaunchesPaused(true);
        vm.prank(creator);
        vm.expectRevert();
        router.launchWith(_params("FROG", _noTax(), 0), address(imd), 1e18, false, 0, 0, address(0));
    }

    // ------------------------------------------------------------------ Fuzz

    /// @notice Random buys and sells keep the curve solvent: its IMD always equals the coin's recorded raise.
    function testFuzz_curveStaysSolvent(uint256 seed) public {
        address coin = _launch(_holderTax(100), 0);
        vm.warp(block.timestamp + 1 hours);
        for (uint256 i; i < 12; i++) {
            seed = uint256(keccak256(abi.encode(seed, i)));
            address who = seed % 2 == 0 ? alice : bob;
            if (curve.statusOf(coin) != BondingCurve.Status.Trading) break;
            uint256 held = PadToken(coin).balanceOf(who);
            if (seed % 3 == 0 && held > 0) {
                _sell(who, coin, (held * (seed % 100 + 1)) / 100);
            } else {
                _buy(who, coin, (seed % 400e18) + 1e15);
            }
            BondingCurve.Coin memory c = curve.coinInfo(coin);
            if (c.status == BondingCurve.Status.Trading) {
                assertEq(imd.balanceOf(address(curve)), c.raised, "curve IMD == raised");
                assertGe(uint256(c.x) * c.y, c.k, "x*y >= k");
            }
        }
    }

    /// @dev Audit R2-A2-2 (router side): a curve buy paid in ETH can bound what the payment swap delivers, because a
    ///      buy that completes the curve gets the same tokens whatever IMD arrives and refunds the rest.
    function test_router_minImdBoundsThePaymentSwap() public {
        address coin = _launch(_noTax(), 0);
        vm.warp(block.timestamp + 1 hours);
        vm.prank(alice);
        vm.expectRevert(PadRouter.Slippage.selector);
        router.buyWith{value: 0.2 ether}(coin, address(0), 0.2 ether, 1_000e18, 0, block.timestamp, address(0));
        vm.prank(alice);
        uint256 out = router.buyWith{value: 0.2 ether}(coin, address(0), 0.2 ether, 80e18, 0, block.timestamp, address(0));
        assertGt(out, 0);
    }

    /// @dev Audit R2-A1-3: the first buy of a holder-tax coin (here the creator's dev buy) can't get its own holder
    ///      tax back: with nobody eligible yet it goes to the growth fund instead of waiting for the next trade.
    function test_holderTax_firstBuyDoesNotPayItsOwnTaxBack() public {
        uint256 growthBefore = imd.balanceOf(growth);
        address coin = _launch(_holderTax(300), 1_000e18);
        assertEq(imd.balanceOf(coin), 0, "nothing parked on the coin");
        assertApproxEqAbs(imd.balanceOf(growth) - growthBefore, 30e18, 1e6, "the dev buy's holder tax went to growth");
        vm.warp(block.timestamp + 1 hours);
        _buy(alice, coin, 1e18);
        vm.prank(creator);
        uint256 got = PadToken(coin).claim();
        assertLt(got, 0.1e18, "the creator earns only from the later buy");
    }

    /// @dev Audit R1-A1-10: exact-output swaps through an outside router, both directions and both currency orderings:
    ///      the trader gets exactly what it asked for and the fee is charged on the IMD side.
    function test_outsideRouter_exactOutputSwaps_imdFirst() public {
        _exactOutputSwaps(true);
    }

    function test_outsideRouter_exactOutputSwaps_coinFirst() public {
        _exactOutputSwaps(false);
    }

    function _exactOutputSwaps(bool imdFirst) internal {
        address coin = _launchOrdered(_noTax(), imdFirst);
        _fillCurve(coin);
        PoolKey memory key = hook.poolKey(coin);
        PoolSwapTest swapper = new PoolSwapTest(IPoolManager(address(pm)));
        imd.mint(address(this), 1_000e18);
        imd.approve(address(swapper), type(uint256).max);
        ERC20(coin).approve(address(swapper), type(uint256).max);
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});

        // Exact-output buy: exactly 1M tokens; 1.5% of what the buyer pays in total is the fee (1% protocol).
        uint256 imdBefore = imd.balanceOf(address(this));
        uint256 splitterBefore = imd.balanceOf(address(splitter));
        swapper.swap(
            key,
            SwapParams({
                zeroForOne: imdFirst,
                amountSpecified: int256(1_000_000e18),
                sqrtPriceLimitX96: imdFirst ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            settings,
            ""
        );
        assertEq(ERC20(coin).balanceOf(address(this)), 1_000_000e18, "exactly the tokens asked for");
        uint256 paid = imdBefore - imd.balanceOf(address(this));
        hook.flush(coin);
        assertApproxEqRel(imd.balanceOf(address(splitter)) - splitterBefore, paid / 100, 1e15, "protocol 1% of what was paid");
        assertEq(imd.balanceOf(address(hook)), 0);

        // Exact-output sell: exactly 1 IMD out; the fee is 1.5% of the gross the pool pays out.
        imdBefore = imd.balanceOf(address(this));
        splitterBefore = imd.balanceOf(address(splitter));
        uint256 tokensBefore = ERC20(coin).balanceOf(address(this));
        swapper.swap(
            key,
            SwapParams({
                zeroForOne: !imdFirst,
                amountSpecified: int256(1e18),
                sqrtPriceLimitX96: imdFirst ? TickMath.MAX_SQRT_PRICE - 1 : TickMath.MIN_SQRT_PRICE + 1
            }),
            settings,
            ""
        );
        assertEq(imd.balanceOf(address(this)) - imdBefore, 1e18, "exactly the IMD asked for");
        assertLt(ERC20(coin).balanceOf(address(this)), tokensBefore);
        hook.flush(coin);
        assertApproxEqRel(
            imd.balanceOf(address(splitter)) - splitterBefore, uint256(1e18) * 100 / 9_850, 1e15, "protocol 1% of the gross"
        );
        assertEq(imd.balanceOf(address(hook)), 0);
    }

    // ------------------------------------------------------------------ Audit round 5 (coverage, R5-A1-3)

    function _permitSig(uint256 key, address coin, uint256 value, uint256 deadline)
        internal
        view
        returns (uint8 v, bytes32 r, bytes32 s_)
    {
        address owner_ = vm.addr(key);
        bytes32 typehash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                ERC20(coin).DOMAIN_SEPARATOR(),
                keccak256(abi.encode(typehash, owner_, address(router), value, ERC20(coin).nonces(owner_), deadline))
            )
        );
        (v, r, s_) = vm.sign(key, digest);
    }

    /// @dev `PadRouter.sellForWithPermit` sells with a signed permit instead of an approval, on the curve and in the
    ///      pool, also when someone else submitted the permit first (the router's own permit call is in a try).
    function test_router_sellForWithPermit() public {
        uint256 key = 0xC0FFEE;
        address seller = vm.addr(key);
        uint256 deadline = 1e10;
        address coin = _launch(_noTax(), 0);
        vm.warp(2 hours);
        imd.mint(seller, 100e18);
        vm.prank(seller);
        imd.approve(address(router), type(uint256).max);
        uint256 got = _buy(seller, coin, 100e18);

        // On the curve, with the permit front-run by someone else.
        (uint8 v, bytes32 r, bytes32 s_) = _permitSig(key, coin, got, deadline);
        ERC20(coin).permit(seller, address(router), got, deadline, v, r, s_);
        uint256 imdBefore = imd.balanceOf(seller);
        vm.prank(seller);
        uint256 out = router.sellForWithPermit(coin, address(imd), got / 2, 1, deadline, address(0), got, v, r, s_);
        assertGt(out, 0);
        assertEq(imd.balanceOf(seller) - imdBefore, out);

        // In the pool after the Leap, with a fresh permit the router submits itself.
        _fillCurve(coin);
        assertEq(uint8(curve.statusOf(coin)), uint8(BondingCurve.Status.Graduated));
        uint256 rest = ERC20(coin).balanceOf(seller);
        (v, r, s_) = _permitSig(key, coin, rest, deadline);
        imdBefore = imd.balanceOf(seller);
        vm.prank(seller);
        out = router.sellForWithPermit(coin, address(imd), rest, 1, deadline, address(0), rest, v, r, s_);
        assertGt(out, 0);
        assertEq(imd.balanceOf(seller) - imdBefore, out);
        assertEq(ERC20(coin).balanceOf(seller), 0);
        assertEq(ERC20(coin).allowance(seller, address(router)), 0);
    }

    function _pendingFees(address coin) internal view returns (uint256) {
        (uint128 protocol, uint128 creatorFee, uint128 holders, uint128 swarm) = hook.pending(coin);
        return uint256(protocol) + creatorFee + holders + swarm;
    }

    function _hookImdClaims() internal view returns (uint256) {
        return IPoolManager(address(pm)).balanceOf(address(hook), uint256(uint160(address(imd))));
    }

    /// @dev Through an outside router, an exact-output sell (IMD specified) that hits a tight price limit reverts
    ///      `PartialFill` (invariant 4), while an exact-input sell (the coin specified) that hits it fills partly and pays
    ///      the fee on the IMD actually filled; the hook's ERC-6909 IMD claims grow by exactly what it books.
    function test_outsideRouter_partialSells_imdFirst() public {
        _partialSells(true);
    }

    function test_outsideRouter_partialSells_coinFirst() public {
        _partialSells(false);
    }

    function _partialSells(bool imdFirst) internal {
        address coin = _launchOrdered(_noTax(), imdFirst);
        _fillCurve(coin);
        PoolKey memory key = hook.poolKey(coin);
        PoolSwapTest swapper = new PoolSwapTest(IPoolManager(address(pm)));
        imd.mint(address(this), 1_000e18);
        imd.approve(address(swapper), type(uint256).max);
        ERC20(coin).approve(address(swapper), type(uint256).max);
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});
        swapper.swap(
            key,
            SwapParams({
                zeroForOne: imdFirst,
                amountSpecified: -100e18,
                sqrtPriceLimitX96: imdFirst ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            settings,
            ""
        );
        hook.flush(coin);

        // A sell moves the price toward more IMD per coin; the limit allows only a sliver of that.
        (uint160 sqrtP,,,) = IPoolManager(address(pm)).getSlot0(key.toId());
        uint160 tight = imdFirst ? sqrtP + sqrtP / 100_000 : sqrtP - sqrtP / 100_000;
        vm.expectRevert(
            abi.encodeWithSelector(
                CustomRevert.WrappedError.selector,
                address(hook),
                IHooks.afterSwap.selector,
                abi.encodeWithSelector(PadHook.PartialFill.selector),
                abi.encodeWithSelector(Hooks.HookCallFailed.selector)
            )
        );
        swapper.swap(key, SwapParams({zeroForOne: !imdFirst, amountSpecified: 10e18, sqrtPriceLimitX96: tight}), settings, "");

        uint256 tokensBefore = ERC20(coin).balanceOf(address(this));
        uint256 imdBefore = imd.balanceOf(address(this));
        uint256 claimsBefore = _hookImdClaims();
        swapper.swap(
            key,
            SwapParams({zeroForOne: !imdFirst, amountSpecified: -int256(tokensBefore), sqrtPriceLimitX96: tight}),
            settings,
            ""
        );
        uint256 sold = tokensBefore - ERC20(coin).balanceOf(address(this));
        assertGt(sold, 0);
        assertLt(sold, tokensBefore, "filled only partly");
        uint256 imdOut = imd.balanceOf(address(this)) - imdBefore;
        uint256 fee = _pendingFees(coin);
        assertEq(fee, (imdOut + fee) * 150 / 10_000, "1.5% of the IMD the pool actually paid");
        assertEq(_hookImdClaims() - claimsBefore, fee, "claims equal the books");
        hook.flush(coin);
        assertEq(_hookImdClaims(), 0);
    }

    /// @dev Exact-output trades through an outside router on a coin with the full 3% tax (4.5% in all), both currency
    ///      orderings: the buy's fee is 4.5% of what the buyer paid in total, the sell's 4.5% of the gross the pool paid
    ///      out, and the hook's ERC-6909 IMD claims grow by exactly what it books.
    function test_outsideRouter_exactOutputFeesOnATaxedCoin_imdFirst() public {
        _exactOutputTaxed(true);
    }

    function test_outsideRouter_exactOutputFeesOnATaxedCoin_coinFirst() public {
        _exactOutputTaxed(false);
    }

    function _exactOutputTaxed(bool imdFirst) internal {
        address coin = _launchOrdered(CoinFees(300, 3_334, 3_333, 3_333), imdFirst);
        _fillCurve(coin);
        hook.flush(coin);
        PoolKey memory key = hook.poolKey(coin);
        PoolSwapTest swapper = new PoolSwapTest(IPoolManager(address(pm)));
        imd.mint(address(this), 1_000e18);
        imd.approve(address(swapper), type(uint256).max);
        ERC20(coin).approve(address(swapper), type(uint256).max);
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});

        uint256 imdBefore = imd.balanceOf(address(this));
        uint256 claimsBefore = _hookImdClaims();
        swapper.swap(
            key,
            SwapParams({
                zeroForOne: imdFirst,
                amountSpecified: int256(1_000_000e18),
                sqrtPriceLimitX96: imdFirst ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            settings,
            ""
        );
        assertEq(ERC20(coin).balanceOf(address(this)), 1_000_000e18, "exactly the coins asked for");
        uint256 paid = imdBefore - imd.balanceOf(address(this));
        uint256 fee = _pendingFees(coin);
        assertApproxEqAbs(fee, paid * 450 / 10_000, 2, "4.5% of what the buyer paid");
        assertEq(_hookImdClaims() - claimsBefore, fee, "buy: claims equal the books");
        hook.flush(coin);

        imdBefore = imd.balanceOf(address(this));
        claimsBefore = _hookImdClaims();
        swapper.swap(
            key,
            SwapParams({
                zeroForOne: !imdFirst,
                amountSpecified: int256(1e18),
                sqrtPriceLimitX96: imdFirst ? TickMath.MAX_SQRT_PRICE - 1 : TickMath.MIN_SQRT_PRICE + 1
            }),
            settings,
            ""
        );
        assertEq(imd.balanceOf(address(this)) - imdBefore, 1e18, "exactly the IMD asked for");
        fee = _pendingFees(coin);
        assertEq(fee, uint256(1e18) * 450 / 9_550, "4.5% of the gross the pool paid out");
        assertEq(_hookImdClaims() - claimsBefore, fee, "sell: claims equal the books");
        hook.flush(coin);
        assertEq(_hookImdClaims(), 0);
        assertEq(imd.balanceOf(address(hook)), 0);
    }
}
