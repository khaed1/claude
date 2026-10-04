// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "solady/tokens/ERC20.sol";
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
        (address coin, uint256 out) = router.launch(_params("FROG", _noTax(), 0), 200e18, 0);
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
        router.buy(coin, 200e18, 0, block.timestamp, bytes32(0));

        vm.warp(t0 + 61);
        _buy(alice, coin, 200e18);
    }

    function test_buy_splitsFees() public {
        address coin = _launch(_holderTax(50), 0);
        vm.warp(block.timestamp + 1 hours);
        uint256 splitterBefore = imd.balanceOf(address(splitter));
        _buy(alice, coin, 100e18);
        assertEq(imd.balanceOf(address(splitter)) - splitterBefore, 1e18, "protocol 1%");
        assertEq(vault.balanceOf(coin), 0.5e18, "creator 0.5%");
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
        _fillCurve(coin);
        assertEq(uint8(curve.statusOf(coin)), uint8(BondingCurve.Status.Graduated));

        // The curve keeps nothing; the pool holds ~99% of the target and 198M tokens.
        assertEq(imd.balanceOf(address(curve)), 0, "curve empty");
        assertEq(PadToken(coin).balanceOf(address(curve)), 0, "curve has no tokens");
        assertApproxEqRel(imd.balanceOf(address(pm)), (TARGET * 99) / 100, 1e14, "pool IMD");
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

    function test_curveClosedAfterGraduation() public {
        address coin = _launch(_noTax(), 0);
        _fillCurve(coin);
        vm.prank(address(router));
        vm.expectRevert(BondingCurve.NotTrading.selector);
        curve.sell(coin, 1e18, 0, alice);
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
        router.launch(_params("FROG", _noTax(), 0), 0, 0);
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
}
