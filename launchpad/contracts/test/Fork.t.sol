// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {PadConfig} from "../src/PadConfig.sol";
import {PadToken} from "../src/PadToken.sol";
import {BondingCurve} from "../src/BondingCurve.sol";
import {PadHook} from "../src/PadHook.sol";
import {PadFactory, LaunchParams} from "../src/PadFactory.sol";
import {PadRouter} from "../src/PadRouter.sol";
import {CreatorVault} from "../src/CreatorVault.sol";
import {SwarmBudget} from "../src/SwarmBudget.sol";
import {FeeSplitter} from "../src/FeeSplitter.sol";
import {CoinFees} from "../src/FeeLib.sol";
import {Hop} from "../src/Route.sol";

/// @notice Runs PondPad against live Robinhood Chain state: the real Uniswap v4 PoolManager, the real IMD token and
///         the real hookless IMD/ETH pool. Skipped unless FORK_RPC is set:
///         FORK_RPC=https://rpc.mainnet.chain.robinhood.com forge test --match-contract Fork -vv
contract ForkTest is Test {
    IPoolManager internal constant PM = IPoolManager(0x8366a39CC670B4001A1121B8F6A443A643e40951);
    address internal constant IMD = 0x5F7Bb59365ce557C26dbcAa4EE9d39A4b95B7127;
    address internal constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    /// @dev The ETH/USDG pool PepesFamily prices against: dynamic fee, tick spacing 10, with its own hook.
    address internal constant ETH_USDG_HOOK = 0x06a889870C8f83640D6816319f72e2aA579b6080;
    uint160 internal constant HOOK_FLAGS = Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
        | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
        | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;

    PoolKey internal imdEth;
    PadConfig internal config;
    FeeSplitter internal splitter;
    BondingCurve internal curve;
    PadHook internal hook;
    PadRouter internal router;
    address internal growth = makeAddr("growth");
    address internal creator = makeAddr("creator");
    bool internal forked;

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC", string(""));
        if (bytes(rpc).length == 0) return;
        vm.createSelectFork(rpc);
        forked = true;

        imdEth = PoolKey(Currency.wrap(address(0)), Currency.wrap(IMD), 10_000, 100, IHooks(address(0)));
        splitter = new FeeSplitter(
            address(this),
            IMD,
            FeeSplitter.Shares(4_000, 2_500, 2_000, 1_500),
            FeeSplitter.Recipients(makeAddr("stakers"), makeAddr("workers"), growth, makeAddr("treasury"))
        );
        config = new PadConfig(
            address(this),
            IMD,
            address(splitter),
            growth,
            address(this),
            PadConfig.LaunchSettings(1e18, 2_060e18, 100, 5_000, 20, 60, 200)
        );
        Hop[] memory ethRoute = new Hop[](1);
        ethRoute[0] = Hop(imdEth, true);
        config.setPaymentRoute(address(0), ethRoute);
        PoolKey memory ethUsdg =
            PoolKey(Currency.wrap(address(0)), Currency.wrap(USDG), 0x800000, 10, IHooks(ETH_USDG_HOOK));
        Hop[] memory usdgRoute = new Hop[](2);
        usdgRoute[0] = Hop(ethUsdg, false);
        usdgRoute[1] = Hop(imdEth, true);
        config.setPaymentRoute(USDG, usdgRoute);
        CreatorVault vault = new CreatorVault(IMD);
        SwarmBudget budget = new SwarmBudget(address(this), IMD, address(vault), address(this), 100e18);
        curve = new BondingCurve(IMD, address(config), address(PM));
        address hookAddr = address(uint160(HOOK_FLAGS) | (uint160(0x5050) << 144));
        deployCodeTo(
            "PadHook.sol:PadHook",
            abi.encode(PM, IMD, address(config), address(vault), address(budget), address(this)),
            hookAddr
        );
        hook = PadHook(hookAddr);
        PadFactory factory = new PadFactory(address(curve), address(hook), address(PM), IMD);
        router = new PadRouter(IMD, address(PM), address(config), address(curve), address(hook), address(factory));
        vault.initialize(address(curve), address(hook), address(0));
        budget.initialize(address(curve), address(hook));
        curve.initialize(address(factory), address(router), address(hook), address(vault), address(budget));
        hook.initialize(address(curve), address(router));
        factory.initialize(address(router));
    }

    function test_fork_fullLifecycleWithEth() public {
        if (!forked) return;
        vm.deal(creator, 10 ether);
        vm.prank(creator);
        (address coin, uint256 devTokens) = router.launchWith{value: 0.05 ether}(
            LaunchParams("Fork Frog", "FFROG", "ipfs://x", address(0), CoinFees(50, 0, 10_000, 0), 0),
            address(0),
            0.05 ether,
            true,
            0,
            0
        );
        assertGt(devTokens, 0);
        vm.warp(block.timestamp + 1 hours);

        // Buyers pay ETH until the curve graduates; measure what graduation costs in ETH on the real pool.
        uint256 ethSpent;
        for (uint256 i; curve.statusOf(coin) == BondingCurve.Status.Trading; i++) {
            address buyer = address(uint160(0xF0000 + i));
            vm.deal(buyer, 2 ether);
            vm.prank(buyer);
            router.buyWith{value: 1 ether}(coin, address(0), 1 ether, 0, block.timestamp, bytes32(0));
            ethSpent += 1 ether;
        }
        console2.log("ETH spent by buyers to graduate one coin (incl. refund in IMD):", ethSpent);
        assertEq(uint8(curve.statusOf(coin)), uint8(BondingCurve.Status.Graduated));

        // After graduation: buy and sell through the coin's pool, paying and receiving ETH.
        address alice = makeAddr("alice");
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        uint256 tokens = router.buyWith{value: 0.1 ether}(coin, address(0), 0.1 ether, 0, block.timestamp, bytes32(0));
        vm.startPrank(alice);
        ERC20(coin).approve(address(router), tokens);
        uint256 ethBack = router.sellFor(coin, address(0), tokens, 0, block.timestamp, bytes32(0));
        vm.stopPrank();
        console2.log("0.1 ETH round trip after graduation returns:", ethBack);
        assertApproxEqRel(ethBack, 0.094 ether, 2e16);
        assertEq(address(router).balance, 0);
        assertEq(ERC20(IMD).balanceOf(address(router)), 0);

        // USDG through the real ETH/USDG and IMD/ETH pools, into the graduated coin's pool and back.
        deal(USDG, alice, 1_000e6);
        vm.startPrank(alice);
        ERC20(USDG).approve(address(router), type(uint256).max);
        tokens = router.buyWith(coin, USDG, 300e6, 0, block.timestamp, bytes32(0));
        ERC20(coin).approve(address(router), tokens);
        uint256 usdgBack = router.sellFor(coin, USDG, tokens, 0, block.timestamp, bytes32(0));
        vm.stopPrank();
        console2.log("300 USDG round trip after graduation returns (6 decimals):", usdgBack);
        assertApproxEqRel(usdgBack, 300e6 * 94 / 100, 3e16);
        assertEq(ERC20(USDG).balanceOf(address(router)), 0);
    }

    function test_fork_usdgOnCurve() public {
        if (!forked) return;
        address alice = makeAddr("alice");
        deal(USDG, alice, 1_000e6);
        vm.startPrank(alice);
        ERC20(USDG).approve(address(router), type(uint256).max);
        (address coin,) = router.launchWith(
            LaunchParams("Usdg Frog", "UFROG", "ipfs://x", address(0), CoinFees(0, 0, 0, 0), 0), USDG, 50e6, true, 0, 0
        );
        vm.warp(block.timestamp + 1 hours);
        uint256 tokens = router.buyWith(coin, USDG, 200e6, 0, block.timestamp, bytes32(0));
        ERC20(coin).approve(address(router), tokens);
        uint256 usdgBack = router.sellFor(coin, USDG, tokens, 0, block.timestamp, bytes32(0));
        vm.stopPrank();
        console2.log("200 USDG round trip on the curve returns (6 decimals):", usdgBack);
        assertApproxEqRel(usdgBack, 200e6 * 95 / 100, 3e16);
    }

    /// @notice How much ETH it takes to buy IMD amounts the protocol will pull from the live IMD/ETH pool.
    function test_fork_imdDepthReport() public {
        if (!forked) return;
        PoolSwapTest swapper = new PoolSwapTest(PM);
        vm.deal(address(this), 1_000 ether);
        uint256[3] memory amounts = [uint256(2_091e18), 8_590e18, 15_000e18];
        for (uint256 i; i < amounts.length; i++) {
            uint256 snap = vm.snapshotState();
            uint256 before = address(this).balance;
            swapper.swap{value: 500 ether}(
                imdEth,
                SwapParams(true, int256(amounts[i]), TickMath.MIN_SQRT_PRICE + 1),
                PoolSwapTest.TestSettings(false, false),
                ""
            );
            console2.log("IMD bought:", amounts[i] / 1e18, "ETH paid (wei):", before - address(this).balance);
            vm.revertToState(snap);
        }
    }

    receive() external payable {}
}
