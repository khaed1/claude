// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {CommonBase} from "forge-std/Base.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console2} from "forge-std/console2.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Base, MockIMD} from "./Base.t.sol";
import {BondingCurve} from "../src/BondingCurve.sol";
import {PadRouter} from "../src/PadRouter.sol";
import {PadToken} from "../src/PadToken.sol";
import {PadHook} from "../src/PadHook.sol";
import {CreatorVault} from "../src/CreatorVault.sol";
import {SwarmBudget} from "../src/SwarmBudget.sol";
import {CoinFees} from "../src/FeeLib.sol";

/// @dev Random buys, sells and time steps through PadRouter on two coins (one IMD-first, one coin-first), across
///      the curve, the Leap and the pool; since audit R6-A1-3 also swaps through an outside router (exact-in and
///      exact-out, both directions, partial fills refused), flushes, dividend and creator-fee claims, holder-stream
///      funding and swarm-budget sweeps.
contract CoinHandler is CommonBase, StdUtils {
    PadRouter internal immutable router;
    MockIMD internal immutable imd;
    PadHook internal immutable hook;
    CreatorVault internal immutable vault;
    SwarmBudget internal immutable budget;
    PoolSwapTest internal immutable swapper;
    address[] internal coins;
    address[] internal actors;

    uint256 public outsideSwaps;
    uint256 public streamFundings;
    uint256 public dividendClaims;

    constructor(
        PadRouter router_,
        MockIMD imd_,
        PadHook hook_,
        CreatorVault vault_,
        SwarmBudget budget_,
        PoolSwapTest swapper_,
        address[] memory coins_,
        address[] memory actors_
    ) {
        router = router_;
        imd = imd_;
        hook = hook_;
        vault = vault_;
        budget = budget_;
        swapper = swapper_;
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

    /// @dev A swap through an outside router on a coin past the Leap (the first from `coinSeed` on; the third coin
    ///      always is): IMD in or out, exact-in or exact-out.
    function outsideSwap(uint256 actorSeed, uint256 coinSeed, uint256 amount, bool imdIn, bool exactOut) external {
        address a = actors[actorSeed % actors.length];
        address coin;
        PoolKey memory key;
        for (uint256 i; i < coins.length && coin == address(0); i++) {
            address c = coins[(coinSeed % coins.length + i) % coins.length];
            try hook.poolKey(c) returns (PoolKey memory k) {
                (coin, key) = (c, k);
            } catch {} // still on the curve
        }
        bool zeroForOne = imdIn == (Currency.unwrap(key.currency0) == address(imd));
        if (imdIn == !exactOut) {
            amount = bound(amount, 1e15, 300e18); // IMD specified
        } else if (exactOut) {
            amount = bound(amount, 1e18, 50_000_000e18); // tokens out
        } else {
            uint256 bal = ERC20(coin).balanceOf(a);
            if (bal == 0) return;
            amount = (bal * bound(amount, 1, 100)) / 100; // tokens in
        }
        vm.startPrank(a);
        imd.approve(address(swapper), type(uint256).max);
        ERC20(coin).approve(address(swapper), type(uint256).max);
        try swapper.swap(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: exactOut ? int256(amount) : -int256(amount),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        ) {
            outsideSwaps++;
        } catch {}
        vm.stopPrank();
    }

    function flush(uint256 coinSeed) external {
        hook.flush(coins[coinSeed % coins.length]);
    }

    function claimDividends(uint256 actorSeed, uint256 coinSeed) external {
        address a = actors[actorSeed % actors.length];
        vm.prank(a);
        try PadToken(coins[coinSeed % coins.length]).claim() returns (uint256 got) {
            if (got != 0) dividendClaims++;
        } catch {}
    }

    function claimCreatorFees(uint256 coinSeed) external {
        vault.claim(coins[coinSeed % coins.length]);
    }

    function sweepBudget(uint256 coinSeed) external {
        try budget.sweepToHolders(coins[coinSeed % coins.length]) {} catch {}
    }

    /// @dev Anyone may add IMD to a coin's holder stream.
    function fundStream(uint256 actorSeed, uint256 coinSeed, uint256 amount) external {
        address a = actors[actorSeed % actors.length];
        amount = bound(amount, 1, 50e18);
        vm.startPrank(a);
        imd.approve(address(vault), amount);
        vault.fundHolders(coins[coinSeed % coins.length], amount);
        vm.stopPrank();
        streamFundings++;
    }
}

/// @dev Audit R1-A1-10: stateful invariants of the coin core (THREAT-MODEL invariants 1, 2 and 9) under random
///      trading: the curve can always pay what it owes, its token books balance, supply never grows, and the
///      router and hook hold nothing between transactions. Audit R6-A1-3: the coin's IMD backs both the dividends
///      credited and the holder stream still to pay, no holder is owed more than is credited, and the hook's IMD
///      claims equal the fees it has pending (invariants 4 and 6). The coin-first coin routes its fees to its holders; a
///      third coin starts in its pool.
/// forge-config: default.invariant.runs = 48
/// forge-config: default.invariant.depth = 40
contract CoinInvariantTest is Base {
    CoinHandler internal handler;
    address[] internal coins;

    function setUp() public override {
        super.setUp();
        coins.push(_launchOrdered(_holderTax(100), true));
        coins.push(_launchOrdered(CoinFees(200, 5_000, 2_500, 2_500), false));
        vm.prank(creator);
        vault.setRecipient(coins[1], coins[1]); // fees and swarm budget to the holders, through the holder stream
        // A third coin already in its pool, so outside-router swaps run from the first call (audit R6-A1-3).
        vm.prank(creator);
        (address toad,) = router.launchWith(
            _params("TOAD", CoinFees(300, 0, 5_000, 5_000), bytes32(0)), address(imd), 1e18, false, 0, 0, address(0)
        );
        _fillCurve(toad);
        coins.push(toad);
        actors.push(creator);
        actors.push(alice);
        actors.push(bob);
        handler = new CoinHandler(
            router, imd, hook, vault, budget, new PoolSwapTest(IPoolManager(address(pm))), coins, actors
        );
        targetContract(address(handler));
    }

    address[] internal actors;

    function invariant_coreBooksBalance() public view {
        uint256 owed;
        uint256 pendingFees;
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
            // Dividends credited and the holder stream still to pay are backed by IMD on the coin (audit R6-A1-3:
            // the stream's remaining IMD counts too), and no holder is owed more than is credited.
            (uint256 remaining,, uint256 due) = PadToken(coin).holderStream();
            assertGe(imd.balanceOf(coin), PadToken(coin).accountedImd() + remaining, "dividends and stream backed");
            uint256 owedToHolders;
            for (uint256 k; k < actors.length; k++) {
                owedToHolders += PadToken(coin).withdrawableDividendOf(actors[k]);
            }
            assertLe(owedToHolders, PadToken(coin).accountedImd() + due, "holders owed no more than credited");
            (uint128 pProtocol, uint128 pCreator, uint128 pHolders, uint128 pSwarm) = hook.pending(coin);
            pendingFees += uint256(pProtocol) + pCreator + pHolders + pSwarm;
        }
        assertEq(
            IPoolManager(address(pm)).balanceOf(address(hook), uint256(uint160(address(imd)))),
            pendingFees,
            "the hook's IMD claims back its pending fees"
        );
        assertGe(imd.balanceOf(address(curve)), owed, "the curve can pay everyone back");
        assertEq(imd.balanceOf(address(router)), 0, "router keeps no IMD");
        assertEq(address(router).balance, 0, "router keeps no ETH");
        assertEq(imd.balanceOf(address(hook)), 0, "hook keeps no IMD between transactions");
    }

    function afterInvariant() public view {
        console2.log("outside swaps", handler.outsideSwaps());
        console2.log("stream fundings", handler.streamFundings());
        console2.log("dividend claims", handler.dividendClaims());
    }
}
