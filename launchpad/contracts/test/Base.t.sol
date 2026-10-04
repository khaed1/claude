// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";
import {PadConfig} from "../src/PadConfig.sol";
import {PadToken} from "../src/PadToken.sol";
import {BondingCurve} from "../src/BondingCurve.sol";
import {PadHook} from "../src/PadHook.sol";
import {PadFactory, LaunchParams} from "../src/PadFactory.sol";
import {PadRouter} from "../src/PadRouter.sol";
import {CreatorVault} from "../src/CreatorVault.sol";
import {SwarmBudget} from "../src/SwarmBudget.sol";
import {FeeSplitter} from "../src/FeeSplitter.sol";
import {IntegratorVault} from "../src/IntegratorVault.sol";
import {CoinFees} from "../src/FeeLib.sol";
import {Hop} from "../src/Route.sol";

contract MockUSDG is ERC20 {
    function name() public pure override returns (string memory) {
        return "Global Dollar";
    }

    function symbol() public pure override returns (string memory) {
        return "USDG";
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockIMD is ERC20 {
    function name() public pure override returns (string memory) {
        return "IMD";
    }

    function symbol() public pure override returns (string memory) {
        return "IMD";
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

abstract contract Base is Test {
    uint256 internal constant TARGET = 2_060e18;
    uint160 internal constant HOOK_FLAGS = Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
        | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
        | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;

    PoolManager internal pm;
    MockIMD internal imd;
    PadConfig internal config;
    FeeSplitter internal splitter;
    CreatorVault internal vault;
    SwarmBudget internal budget;
    IntegratorVault internal integrators;
    BondingCurve internal curve;
    PadHook internal hook;
    PadFactory internal factory;
    PadRouter internal router;

    address internal stakers = makeAddr("stakers");
    address internal workers = makeAddr("workers");
    address internal growth = makeAddr("growth");
    address internal treasury = makeAddr("treasury");
    address internal relay = makeAddr("relay");
    address internal creator = makeAddr("creator");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    PoolKey internal imdEthKey;
    PoolKey internal ethUsdgKey;
    MockUSDG internal usdg;

    receive() external payable {}

    uint256 internal _bn;

    /// @dev Moves to the next block. Under via-IR, `block.number` read after `vm.roll` can be stale, so
    ///      `vm.roll(block.number + 1)` twice in one test may land on the same block; this keeps its own count.
    function _nextBlock() internal {
        if (_bn < block.number) _bn = block.number;
        vm.roll(++_bn);
    }

    /// @dev Address the creator vault trusts as its CTO module; tests that need one deploy it there.
    function _ctoModuleAddress() internal virtual returns (address) {
        return address(0);
    }

    function setUp() public virtual {
        pm = new PoolManager(address(this));
        imd = new MockIMD();
        imdEthKey = _seedImdEthPool();
        usdg = new MockUSDG();
        ethUsdgKey = _seedEthUsdgPool();

        splitter = new FeeSplitter(
            address(this),
            address(imd),
            FeeSplitter.Shares({stakers: 4_000, workers: 2_500, growth: 2_000, treasury: 1_500}),
            FeeSplitter.Recipients({stakers: stakers, workers: workers, growth: growth, treasury: treasury})
        );
        config = new PadConfig(
            address(this),
            address(imd),
            address(splitter),
            growth,
            address(this),
            PadConfig.LaunchSettings({
                launchFee: 1e18,
                graduationTarget: uint96(TARGET),
                graduationFeeBps: 100,
                snipeTaxStartBps: 5_000,
                snipeTaxDuration: 20,
                maxBuyWindow: 60,
                maxBuyBps: 200
            })
        );
        Hop[] memory ethRoute = new Hop[](1);
        ethRoute[0] = Hop(imdEthKey, true);
        config.setPaymentRoute(address(0), ethRoute);
        Hop[] memory usdgRoute = new Hop[](2);
        usdgRoute[0] = Hop(ethUsdgKey, false); // USDG → ETH
        usdgRoute[1] = Hop(imdEthKey, true); // ETH → IMD
        config.setPaymentRoute(address(usdg), usdgRoute);
        vault = new CreatorVault(address(imd));
        budget = new SwarmBudget(address(this), address(imd), address(vault), relay, 100e18);
        integrators = new IntegratorVault(address(imd));
        curve = new BondingCurve(address(imd), address(config), address(pm));

        address hookAddr = address(uint160(HOOK_FLAGS) | (uint160(0x4444) << 144));
        deployCodeTo(
            "PadHook.sol:PadHook",
            abi.encode(IPoolManager(address(pm)), address(imd), address(config), address(vault), address(budget), address(integrators), address(this)),
            hookAddr
        );
        hook = PadHook(hookAddr);

        factory = new PadFactory(address(curve), address(hook), address(pm), address(imd));
        router = new PadRouter(address(imd), address(pm), address(config), address(curve), address(hook), address(factory));

        vault.initialize(address(curve), address(hook), _ctoModuleAddress());
        budget.initialize(address(curve), address(hook));
        curve.initialize(
            address(factory), address(router), address(hook), address(vault), address(budget), address(integrators)
        );
        integrators.initialize(address(curve), address(hook));
        hook.initialize(address(curve), address(router));
        factory.initialize(address(router));

        address[3] memory users = [creator, alice, bob];
        for (uint256 i; i < users.length; i++) {
            vm.deal(users[i], 1_000 ether);
            imd.mint(users[i], 1_000_000e18);
            usdg.mint(users[i], 1_000_000e6);
            vm.prank(users[i]);
            usdg.approve(address(router), type(uint256).max);
            vm.prank(users[i]);
            imd.approve(address(router), type(uint256).max);
        }
    }

    /// @dev A hookless native-ETH/IMD pool like the one on Robinhood: 1% fee, tick spacing 100, ~423 IMD per ETH,
    ///      seeded with 100 ETH of full-range liquidity.
    function _seedImdEthPool() internal returns (PoolKey memory key) {
        key = PoolKey(Currency.wrap(address(0)), Currency.wrap(address(imd)), 10_000, 100, IHooks(address(0)));
        // sqrt(423) * 2^96
        pm.initialize(key, 1629482750466713582234828002375);
        PoolModifyLiquidityTest lp = new PoolModifyLiquidityTest(IPoolManager(address(pm)));
        imd.mint(address(this), 100_000e18);
        imd.approve(address(lp), type(uint256).max);
        vm.deal(address(this), 200 ether);
        lp.modifyLiquidity{value: 120 ether}(
            key,
            ModifyLiquidityParams(TickMath.minUsableTick(100), TickMath.maxUsableTick(100), 2_000e18, 0),
            ""
        );
    }

    /// @dev A hookless native-ETH/USDG pool: 0.05% fee, tick spacing 10, ~2,667 USDG per ETH, ~200k USDG deep.
    function _seedEthUsdgPool() internal returns (PoolKey memory key) {
        key = PoolKey(Currency.wrap(address(0)), Currency.wrap(address(usdg)), 500, 10, IHooks(address(0)));
        // sqrt(2667e6 / 1e18) * 2^96
        pm.initialize(key, 4091587813935018962591680);
        PoolModifyLiquidityTest lp = new PoolModifyLiquidityTest(IPoolManager(address(pm)));
        usdg.mint(address(this), 1_000_000e6);
        usdg.approve(address(lp), type(uint256).max);
        vm.deal(address(this), address(this).balance + 200 ether);
        lp.modifyLiquidity{value: 150 ether}(
            key,
            ModifyLiquidityParams(TickMath.minUsableTick(10), TickMath.maxUsableTick(10), 5_000_000_000_000_000, 0),
            ""
        );
    }

    function _params(string memory sym, CoinFees memory fees, bytes32 salt) internal pure returns (LaunchParams memory) {
        return LaunchParams({
            name: string.concat(sym, " coin"),
            symbol: sym,
            metadataURI: "ipfs://meta",
            feeRecipient: address(0),
            fees: fees,
            salt: salt
        });
    }

    function _noTax() internal pure returns (CoinFees memory) {
        return CoinFees(0, 0, 0, 0);
    }

    function _holderTax(uint16 bps) internal pure returns (CoinFees memory) {
        return CoinFees(bps, 0, 10_000, 0);
    }

    function _launch(CoinFees memory fees, uint256 devBuy) internal returns (address coin) {
        vm.prank(creator);
        (coin,) = router.launchWith(_params("FROG", fees, bytes32(0)), address(imd), 1e18 + devBuy, devBuy != 0, 0, 0, address(0));
    }

    /// @dev Launches coins with increasing salts until the IMD/coin address ordering matches `imdFirst`.
    function _launchOrdered(CoinFees memory fees, bool imdFirst) internal returns (address coin) {
        for (uint256 i; i < 64; i++) {
            LaunchParams memory p = _params("FROG", fees, bytes32(i));
            address predicted = factory.predictAddress(p, creator);
            if ((address(imd) < predicted) == imdFirst) {
                vm.prank(creator);
                (coin,) = router.launchWith(p, address(imd), 1e18, false, 0, 0, address(0));
                return coin;
            }
        }
        revert("no salt found");
    }

    function _buy(address who, address coin, uint256 imdIn) internal returns (uint256 out) {
        vm.prank(who);
        out = router.buyWith(coin, address(imd), imdIn, 0, block.timestamp, address(0));
    }

    function _sell(address who, address coin, uint256 tokensIn) internal returns (uint256 out) {
        vm.startPrank(who);
        ERC20(coin).approve(address(router), tokensIn);
        out = router.sellFor(coin, address(imd), tokensIn, 0, block.timestamp, address(0));
        vm.stopPrank();
    }

    /// @dev Buys from fresh wallets after the launch windows until the curve completes.
    function _fillCurve(address coin) internal {
        vm.warp(block.timestamp + 1 hours);
        uint256 i;
        while (curve.statusOf(coin) == BondingCurve.Status.Trading) {
            address buyer = address(uint160(0x10000 + i++));
            imd.mint(buyer, 1_000e18);
            vm.startPrank(buyer);
            imd.approve(address(router), type(uint256).max);
            router.buyWith(coin, address(imd), 1_000e18, 0, block.timestamp, address(0));
            vm.stopPrank();
        }
    }
}
