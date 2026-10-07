// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "solady/tokens/ERC20.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {Base} from "./Base.t.sol";
import {PadSale, IPadMarketLauncher} from "../src/PadSale.sol";
import {PondPadToken} from "../src/PondPadToken.sol";
import {PaymentSwapper} from "../src/PaymentSwapper.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

/// @dev Stands in for MarketController: records what the sale hands over at graduation.
contract MockMarket is IPadMarketLauncher {
    uint160 public sqrtPriceX96;
    uint256 public imdAmount;
    uint256 public tokenAmount;
    uint256 public calls;

    function launch(uint160 sqrtPriceX96_, uint256 imdAmount_, uint256 tokenAmount_) external {
        sqrtPriceX96 = sqrtPriceX96_;
        imdAmount = imdAmount_;
        tokenAmount = tokenAmount_;
        calls++;
    }
}

/// @dev Buys from the sale inside its own PoolManager unlock, as an outside contract could: the completing buy then
///      can't graduate inline and leaves the sale Full.
contract UnlockedSaleBuyer {
    IPoolManager internal immutable pm;
    PadSale internal immutable sale;
    address internal immutable imd;

    constructor(IPoolManager pm_, PadSale sale_, address imd_) {
        pm = pm_;
        sale = sale_;
        imd = imd_;
    }

    function buy(uint256 imdIn) external {
        pm.unlock(abi.encode(imdIn));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        uint256 imdIn = abi.decode(data, (uint256));
        ERC20(imd).approve(address(sale), imdIn);
        sale.buyWith(imd, imdIn, 0, 0, block.timestamp, address(0));
        return "";
    }
}

contract PadSaleTest is Base {
    uint256 internal constant SALE_TARGET = 8_460e18;
    uint256 internal constant START = 1_000_000;

    PondPadToken internal pondpad;
    PadSale internal sale;
    MockMarket internal market;
    address internal app = makeAddr("app");

    function setUp() public override {
        super.setUp();
        // Mine a salt so $PONDPAD sorts above IMD, as the deploy script will (D-19).
        for (uint256 i;; i++) {
            pondpad = new PondPadToken{salt: bytes32(i)}(address(this));
            if (address(pondpad) > address(imd)) break;
        }
        market = new MockMarket();
        sale = new PadSale(
            address(imd), address(pm), address(config), address(pondpad), address(market), address(integrators),
            SALE_TARGET, START
        );
        integrators.setSale(address(sale));
        pondpad.approve(address(sale), type(uint256).max);
        sale.fund();

        address[3] memory users = [creator, alice, bob];
        for (uint256 i; i < users.length; i++) {
            vm.startPrank(users[i]);
            imd.approve(address(sale), type(uint256).max);
            usdg.approve(address(sale), type(uint256).max);
            pondpad.approve(address(sale), type(uint256).max);
            vm.stopPrank();
        }
        vm.warp(START);
    }

    function _saleBuy(address who, uint256 imdIn) internal returns (uint256 out) {
        vm.prank(who);
        out = sale.buyWith(address(imd), imdIn, 0, 0, block.timestamp, address(0));
    }

    function _saleSell(address who, uint256 tokensIn) internal returns (uint256 out) {
        vm.prank(who);
        out = sale.sellFor(address(imd), tokensIn, 0, block.timestamp, address(0));
    }

    /// @dev Buys from fresh wallets until the curve completes.
    function _fillSale() internal {
        uint256 i;
        while (sale.status() == PadSale.Status.Trading) {
            address buyer = address(uint160(0x20000 + i++));
            imd.mint(buyer, 100e18);
            vm.startPrank(buyer);
            imd.approve(address(sale), type(uint256).max);
            sale.buyWith(address(imd), 100e18, 0, 0, block.timestamp, address(0));
            vm.stopPrank();
        }
    }

    function test_sale_setupAndStartPrice() public view {
        assertGt(uint160(address(pondpad)), uint160(address(imd)));
        assertEq(pondpad.balanceOf(address(sale)), 900_000_000e18);
        assertEq(pondpad.balanceOf(address(this)), 100_000_000e18);
        // x0 = E, y0 = 1.2B: start market cap = 1B · E / 1.2B ≈ 7,050 IMD; final = 1B · E / 300M ≈ 28,200 IMD.
        assertEq(sale.x0(), SALE_TARGET);
        uint256 startMcap = (sale.price() * 1_000_000_000e18) / 1e18;
        assertApproxEqRel(startMcap, 7_050e18, 0.001e18);
        assertEq(pondpad.owner(), address(0));
    }

    function test_sale_rejectsBadSetup() public {
        vm.expectRevert(PadSale.InvalidSetup.selector);
        new PadSale(address(imd), address(pm), address(config), address(pondpad), address(market), address(integrators), 500e18, START);
        // A token sorting below IMD would make IMD currency1; refused.
        vm.expectRevert(PadSale.InvalidSetup.selector);
        new PadSale(address(pondpad), address(pm), address(config), address(imd), address(market), address(integrators), SALE_TARGET, START);
        vm.expectRevert(PadSale.AlreadyFunded.selector);
        sale.fund();
    }

    function test_sale_closedBeforeStartAndUntilFunded() public {
        PadSale unfunded = new PadSale(
            address(imd), address(pm), address(config), address(pondpad), address(market), address(integrators),
            SALE_TARGET, START
        );
        vm.prank(alice);
        imd.approve(address(unfunded), type(uint256).max);
        vm.prank(alice);
        vm.expectRevert(PadSale.NotTrading.selector);
        unfunded.buyWith(address(imd), 10e18, 0, 0, block.timestamp, address(0));

        vm.warp(START - 1);
        vm.prank(alice);
        vm.expectRevert(PadSale.NotStarted.selector);
        sale.buyWith(address(imd), 10e18, 0, 0, block.timestamp, address(0));
    }

    function test_sale_snipeTaxDecaysOverThirtyMinutesToGrowth() public {
        assertEq(sale.snipeTaxBps(), 8_000);
        uint256 growthBefore = imd.balanceOf(growth);
        _saleBuy(alice, 100e18);
        assertEq(imd.balanceOf(growth) - growthBefore, 80e18);

        vm.warp(START + 15 minutes);
        assertEq(sale.snipeTaxBps(), 4_000);
        vm.warp(START + 30 minutes);
        assertEq(sale.snipeTaxBps(), 0);
        growthBefore = imd.balanceOf(growth);
        _saleBuy(bob, 100e18);
        assertEq(imd.balanceOf(growth), growthBefore);
    }

    function test_sale_feeToSplitterAndIntegratorShare() public {
        vm.warp(START + 30 minutes);
        uint256 splitterBefore = imd.balanceOf(address(splitter));
        _saleBuy(alice, 100e18);
        assertEq(imd.balanceOf(address(splitter)) - splitterBefore, 1e18);
        assertEq(sale.raised(), 99e18);

        config.setIntegrator(app, true);
        splitterBefore = imd.balanceOf(address(splitter));
        vm.prank(bob);
        sale.buyWith(address(imd), 50e18, 0, 0, block.timestamp, app);
        assertEq(integrators.balanceOf(app), 0.075e18);
        assertEq(imd.balanceOf(address(splitter)) - splitterBefore, 0.425e18);

        // Unregistered referrers earn nothing and don't revert.
        address stranger = makeAddr("stranger");
        vm.prank(bob);
        sale.buyWith(address(imd), 10e18, 0, 0, block.timestamp, stranger);
        assertEq(integrators.balanceOf(stranger), 0);
    }

    function test_sale_walletCapForWholeSale() public {
        vm.warp(START + 1 days);
        // ~300 IMD buys well over 15M at the start price.
        vm.prank(alice);
        vm.expectRevert(PadSale.MaxPerWalletExceeded.selector);
        sale.buyWith(address(imd), 300e18, 0, 0, block.timestamp, address(0));

        uint256 out = _saleBuy(alice, 50e18);
        assertEq(sale.bought(alice), out);
        assertEq(sale.remainingAllowance(alice), sale.MAX_PER_WALLET() - out);
        // Selling doesn't free up cap.
        _saleSell(alice, out);
        assertEq(sale.bought(alice), out);
        // Still capped a week later.
        vm.warp(START + 7 days);
        (uint256 quoted,,) = sale.quoteBuy(100e18);
        assertGt(out + quoted, sale.MAX_PER_WALLET());
        vm.prank(alice);
        vm.expectRevert(PadSale.MaxPerWalletExceeded.selector);
        sale.buyWith(address(imd), 100e18, 0, 0, block.timestamp, address(0));
    }

    function test_sale_sellReturnsLessThanPaid() public {
        vm.warp(START + 30 minutes);
        uint256 before = imd.balanceOf(alice);
        uint256 out = _saleBuy(alice, 50e18);
        (uint256 quoted,) = sale.quoteSell(out);
        uint256 back = _saleSell(alice, out);
        assertEq(back, quoted);
        assertLt(imd.balanceOf(alice), before);
        assertApproxEqRel(before - imd.balanceOf(alice), 1e18, 0.01e18); // ~1% each way
        assertEq(sale.sold(), 0);
        assertEq(sale.raised(), sale.x() - sale.x0());
    }

    function test_sale_ethAndUsdgRoundTrips() public {
        vm.warp(START + 30 minutes);
        uint256 ethBefore = alice.balance;
        vm.prank(alice);
        uint256 out = sale.buyWith{value: 0.05 ether}(address(0), 0.05 ether, 0, 1, block.timestamp, address(0));
        assertGt(out, 0);
        vm.prank(alice);
        uint256 ethBack = sale.sellFor(address(0), out, 1, block.timestamp, address(0));
        assertLt(alice.balance, ethBefore);
        assertEq(alice.balance, ethBefore - 0.05 ether + ethBack);

        vm.prank(bob);
        vm.expectRevert(PaymentSwapper.WrongEthAmount.selector);
        sale.buyWith{value: 1 ether}(address(0), 0.5 ether, 0, 0, block.timestamp, address(0));

        vm.prank(bob);
        out = sale.buyWith(address(usdg), 100e6, 0, 1, block.timestamp, address(0));
        assertGt(out, 0);
        vm.prank(bob);
        uint256 usdgBack = sale.sellFor(address(usdg), out, 1, block.timestamp, address(0));
        assertGt(usdgBack, 90e6);
        assertLt(usdgBack, 100e6);
        assertEq(pondpad.balanceOf(address(sale)), 900_000_000e18);
    }

    function test_sale_graduatesAtFinalPrice() public {
        vm.warp(START + 30 minutes);
        uint256 splitterBefore = imd.balanceOf(address(splitter));
        _fillSale();

        assertEq(uint8(sale.status()), uint8(PadSale.Status.Graduated));
        assertEq(market.calls(), 1);
        assertEq(market.tokenAmount(), 300_000_000e18);
        assertEq(pondpad.balanceOf(address(market)), 300_000_000e18);
        assertEq(pondpad.balanceOf(address(sale)), 0);
        // The whole net raise opens the pool; the sale keeps nothing.
        assertEq(imd.balanceOf(address(market)), market.imdAmount());
        assertEq(imd.balanceOf(address(sale)), 0);
        assertApproxEqRel(market.imdAmount(), SALE_TARGET, 0.0001e18);
        // 1% of gross volume went to the splitter.
        assertApproxEqRel(imd.balanceOf(address(splitter)) - splitterBefore, (SALE_TARGET * 100) / 9_900, 0.001e18);

        // Pool opens at the curve's final price: (sqrtP / 2^96)^2 = tokens per IMD = 300M / raised.
        uint256 sqrtP = market.sqrtPriceX96();
        uint256 tokensPerImd = FixedPointMathLib.fullMulDiv(sqrtP * sqrtP, 1e18, 1 << 192);
        uint256 curveFinal = FixedPointMathLib.fullMulDiv(sale.y(), 1e18, sale.x());
        assertApproxEqRel(tokensPerImd, curveFinal, 1e12); // 1e-6 relative
        assertApproxEqRel(tokensPerImd, (300_000_000e18 * 1e18) / SALE_TARGET, 0.0001e18);

        vm.prank(alice);
        vm.expectRevert(PadSale.NotTrading.selector);
        sale.buyWith(address(imd), 10e18, 0, 0, block.timestamp, address(0));
        vm.expectRevert(PadSale.NotFull.selector);
        sale.graduate();
    }

    function test_sale_completingBuyRefundsOvershoot() public {
        vm.warp(START + 30 minutes);
        // Fill until the next 100 IMD buy would complete the curve.
        uint256 i;
        while (true) {
            (uint256 q,,) = sale.quoteBuy(100e18);
            if (q == sale.CURVE_SUPPLY() - sale.sold()) break;
            address buyer = address(uint160(0x30000 + i++));
            imd.mint(buyer, 100e18);
            vm.startPrank(buyer);
            imd.approve(address(sale), type(uint256).max);
            sale.buyWith(address(imd), 100e18, 0, 0, block.timestamp, address(0));
            vm.stopPrank();
        }
        uint256 remaining = sale.CURVE_SUPPLY() - sale.sold();
        uint256 before = imd.balanceOf(alice);
        uint256 out = _saleBuy(alice, 100e18);
        assertEq(out, remaining);
        assertLt(before - imd.balanceOf(alice), 100e18); // refunded the unused IMD
        assertEq(uint8(sale.status()), uint8(PadSale.Status.Graduated));
    }

    /// @dev Random buys and sells never leave the curve owing more IMD than it holds.
    function testFuzz_saleStaysSolvent(uint256 seed) public {
        vm.warp(START + 30 minutes);
        address[3] memory users = [creator, alice, bob];
        for (uint256 i; i < 12; i++) {
            seed = uint256(keccak256(abi.encode(seed, i)));
            address who = users[seed % 3];
            if (seed % 5 < 3 || pondpad.balanceOf(who) == 0) {
                uint256 amt = 1e15 + (seed >> 8) % 60e18;
                uint256 allowance = sale.remainingAllowance(who);
                (uint256 q,,) = sale.quoteBuy(amt);
                if (q == 0 || q > allowance) continue;
                _saleBuy(who, amt);
            } else {
                uint256 bal = pondpad.balanceOf(who);
                uint256 amt = 1 + (seed >> 8) % bal;
                (uint256 q,) = sale.quoteSell(amt);
                if (q == 0) continue;
                _saleSell(who, amt);
            }
            assertGe(imd.balanceOf(address(sale)), sale.raised());
            assertEq(sale.raised(), sale.x() - sale.x0());
        }
        // Everyone sells everything back: the curve can always pay.
        for (uint256 j; j < 3; j++) {
            uint256 bal = pondpad.balanceOf(users[j]);
            (uint256 q,) = sale.quoteSell(bal);
            if (bal != 0 && q != 0) _saleSell(users[j], bal);
        }
        assertGe(imd.balanceOf(address(sale)), sale.raised());
    }

    /// @dev Buys 100 IMD from fresh wallets until a buy of `completing` IMD would complete the curve.
    function _fillUntilCompletes(uint256 completing) internal {
        uint256 i;
        while (true) {
            (uint256 q,,) = sale.quoteBuy(completing);
            if (q == sale.CURVE_SUPPLY() - sale.sold()) break;
            address buyer = address(uint160(0x30000 + i++));
            imd.mint(buyer, 100e18);
            vm.startPrank(buyer);
            imd.approve(address(sale), type(uint256).max);
            sale.buyWith(address(imd), 100e18, 0, 0, block.timestamp, address(0));
            vm.stopPrank();
        }
    }

    /// @dev Audit R2-A2-2: on the buy that completes the sale, a payment in ETH gets the same tokens whatever IMD the
    ///      swap delivers (the rest is refunded), so `minTokensOut` alone let a sandwich take the unused payment.
    ///      `minImd` bounds the swap: the sandwiched buy reverts; the same buy without the sandwich goes through.
    function test_sale_completingEthBuyBoundsThePaymentSwap() public {
        vm.warp(START + 30 minutes);
        _fillUntilCompletes(300e18);
        uint256 minImd = 1_100e18; // 3 ETH at ~423 IMD/ETH, less fee and impact, is ~1,200 IMD
        uint256 snap = vm.snapshotState();

        // Front-run: 80 ETH -> IMD on the IMD/ETH pool makes ETH buy far less IMD.
        PoolSwapTest swapper = new PoolSwapTest(IPoolManager(address(pm)));
        vm.deal(address(this), address(this).balance + 100 ether);
        swapper.swap{value: 80 ether}(
            imdEthKey,
            SwapParams({zeroForOne: true, amountSpecified: -80e18, sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
        vm.prank(alice);
        vm.expectRevert(PadSale.Slippage.selector);
        sale.buyWith{value: 3 ether}(address(0), 3 ether, minImd, 1, block.timestamp, address(0));

        vm.revertToState(snap);
        uint256 imdBefore = imd.balanceOf(alice);
        vm.prank(alice);
        sale.buyWith{value: 3 ether}(address(0), 3 ether, minImd, 1, block.timestamp, address(0));
        assertEq(uint8(sale.status()), uint8(PadSale.Status.Graduated));
        assertGt(imd.balanceOf(alice) - imdBefore, 800e18, "the unused payment comes back as IMD");
    }

    /// @dev Audit R2-A2-3: the quote for a buy that completes the curve reports the fee and snipe tax the buy actually
    ///      charges (on the IMD it needs), not on the whole input. Checked inside the snipe window.
    function test_sale_completingBuyQuoteMatchesCharges() public {
        vm.warp(START + 15 minutes); // snipe tax 40%
        _fillUntilCompletes(100e18);
        (uint256 out, uint256 fee, uint256 snipe) = sale.quoteBuy(100e18);
        uint256 splitterBefore = imd.balanceOf(address(splitter));
        uint256 growthBefore = imd.balanceOf(growth);
        imd.mint(alice, 100e18);
        uint256 got = _saleBuy(alice, 100e18);
        assertEq(got, out);
        assertEq(imd.balanceOf(address(splitter)) - splitterBefore, fee, "quoted fee = fee charged");
        assertEq(imd.balanceOf(growth) - growthBefore, snipe, "quoted snipe tax = snipe tax charged");
        assertLt(fee, 1e18, "only the IMD the last tokens need pays the fee");
    }

    /// @dev Audit R2-A2-4: IMD and $PONDPAD sent straight to the sale are not stranded: graduation hands them to the
    ///      market (MarketController sends leftover IMD to the fee splitter and burns leftover $PONDPAD).
    function test_sale_strayTokensGoToTheMarketAtGraduation() public {
        imd.mint(address(this), 1e18);
        imd.transfer(address(sale), 1e18);
        pondpad.transfer(address(sale), 5e18);
        vm.warp(START + 30 minutes);
        _fillSale();
        assertEq(uint8(sale.status()), uint8(PadSale.Status.Graduated));
        assertEq(imd.balanceOf(address(sale)), 0, "no IMD left in the sale");
        assertEq(pondpad.balanceOf(address(sale)), 0, "no $PONDPAD left in the sale");
        assertEq(imd.balanceOf(address(market)), market.imdAmount() + 1e18);
        assertEq(pondpad.balanceOf(address(market)), sale.POOL_SUPPLY() + 5e18);
    }

    /// @dev Audit R3-A2-6 (coverage): a completing buy made inside an outside PoolManager unlock leaves the sale Full;
    ///      anyone then finishes the graduation with `graduate()`, once.
    function test_sale_fullSaleGraduatesThroughGraduate() public {
        vm.warp(START + 30 minutes);
        _fillUntilCompletes(300e18); // small enough for the 15M per-wallet cap
        UnlockedSaleBuyer b = new UnlockedSaleBuyer(IPoolManager(address(pm)), sale, address(imd));
        imd.mint(address(b), 300e18);
        b.buy(300e18);
        assertEq(uint8(sale.status()), uint8(PadSale.Status.Full));
        assertEq(market.calls(), 0);
        vm.prank(alice);
        sale.graduate();
        assertEq(uint8(sale.status()), uint8(PadSale.Status.Graduated));
        assertEq(market.calls(), 1);
        assertEq(market.tokenAmount(), 300_000_000e18);
        assertApproxEqRel(market.imdAmount(), SALE_TARGET, 0.0001e18);
        vm.expectRevert(PadSale.NotFull.selector);
        sale.graduate();
    }
}
