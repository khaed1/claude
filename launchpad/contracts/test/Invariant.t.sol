// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {CommonBase} from "forge-std/Base.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {Base, MockIMD} from "./Base.t.sol";
import {BondingCurve} from "../src/BondingCurve.sol";
import {PadRouter} from "../src/PadRouter.sol";
import {PadToken} from "../src/PadToken.sol";
import {CoinFees} from "../src/FeeLib.sol";

/// @dev Random buys, sells and time steps through PadRouter on two coins (one IMD-first, one coin-first), across
///      the curve, the Leap and the pool.
contract CoinHandler is CommonBase, StdUtils {
    PadRouter internal immutable router;
    MockIMD internal immutable imd;
    address[] internal coins;
    address[] internal actors;

    constructor(PadRouter router_, MockIMD imd_, address[] memory coins_, address[] memory actors_) {
        router = router_;
        imd = imd_;
        coins = coins_;
        actors = actors_;
    }

    function buy(uint256 actorSeed, uint256 coinSeed, uint256 amount) external {
        address a = actors[actorSeed % actors.length];
        address coin = coins[coinSeed % coins.length];
        amount = bound(amount, 1e15, 800e18);
        vm.prank(a);
        try router.buyWith(coin, address(imd), amount, 0, 0, block.timestamp, address(0)) {} catch {}
    }

    function sell(uint256 actorSeed, uint256 coinSeed, uint256 percent) external {
        address a = actors[actorSeed % actors.length];
        address coin = coins[coinSeed % coins.length];
        uint256 bal = ERC20(coin).balanceOf(a);
        if (bal == 0) return;
        uint256 amount = (bal * bound(percent, 1, 100)) / 100;
        vm.startPrank(a);
        ERC20(coin).approve(address(router), amount);
        try router.sellFor(coin, address(imd), amount, 0, block.timestamp, address(0)) {} catch {}
        vm.stopPrank();
    }

    function wait(uint256 secs) external {
        vm.warp(block.timestamp + bound(secs, 1, 1 hours));
    }
}

/// @dev Audit R1-A1-10: stateful invariants of the coin core (THREAT-MODEL invariants 1, 2 and 9) under random
///      trading: the curve can always pay what it owes, its token books balance, supply never grows, and the
///      router and hook hold nothing between transactions.
/// forge-config: default.invariant.runs = 48
/// forge-config: default.invariant.depth = 40
contract CoinInvariantTest is Base {
    CoinHandler internal handler;
    address[] internal coins;

    function setUp() public override {
        super.setUp();
        coins.push(_launchOrdered(_holderTax(100), true));
        coins.push(_launchOrdered(CoinFees(200, 5_000, 2_500, 2_500), false));
        address[] memory actors = new address[](3);
        actors[0] = creator;
        actors[1] = alice;
        actors[2] = bob;
        handler = new CoinHandler(router, imd, coins, actors);
        targetContract(address(handler));
    }

    function invariant_coreBooksBalance() public view {
        uint256 owed;
        for (uint256 i; i < coins.length; i++) {
            address coin = coins[i];
            BondingCurve.Coin memory c = curve.coinInfo(coin);
            owed += c.raised;
            assertLe(PadToken(coin).totalSupply(), 1_000_000_000e18, "supply never grows");
            if (c.status != BondingCurve.Status.Graduated) {
                assertEq(PadToken(coin).balanceOf(address(curve)) + c.sold, 1_000_000_000e18, "curve token books");
            } else {
                assertEq(c.raised, 0);
                assertEq(PadToken(coin).balanceOf(address(curve)), 0);
            }
            // Dividends owed to holders are always backed by IMD on the coin.
            assertGe(imd.balanceOf(coin), PadToken(coin).accountedImd(), "dividends backed");
        }
        assertGe(imd.balanceOf(address(curve)), owed, "the curve can pay everyone back");
        assertEq(imd.balanceOf(address(router)), 0, "router keeps no IMD");
        assertEq(address(router).balance, 0, "router keeps no ETH");
        assertEq(imd.balanceOf(address(hook)), 0, "hook keeps no IMD between transactions");
    }
}
