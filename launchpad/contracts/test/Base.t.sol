// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
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

    function setUp() public virtual {
        pm = new PoolManager(address(this));
        imd = new MockIMD();

        splitter = new FeeSplitter(
            address(this),
            address(imd),
            FeeSplitter.Shares({stakers: 4_000, workers: 2_500, growth: 2_000, treasury: 1_500}),
            FeeSplitter.Recipients({stakers: stakers, workers: workers, growth: growth, treasury: treasury})
        );
        config = new PadConfig(
            address(this),
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
        vault = new CreatorVault(address(imd));
        budget = new SwarmBudget(address(this), address(imd), address(vault), relay, 100e18);
        curve = new BondingCurve(address(imd), address(config), address(pm));

        address hookAddr = address(uint160(HOOK_FLAGS) | (uint160(0x4444) << 144));
        deployCodeTo(
            "PadHook.sol:PadHook",
            abi.encode(IPoolManager(address(pm)), address(imd), address(config), address(vault), address(budget), address(this)),
            hookAddr
        );
        hook = PadHook(hookAddr);

        factory = new PadFactory(address(curve), address(hook), address(pm), address(imd));
        router = new PadRouter(address(imd), address(pm), address(config), address(curve), address(hook), address(factory));

        vault.initialize(address(curve), address(hook), address(0));
        budget.initialize(address(curve), address(hook));
        curve.initialize(address(factory), address(router), address(hook), address(vault), address(budget));
        hook.initialize(address(curve), address(router));
        factory.initialize(address(router));

        address[3] memory users = [creator, alice, bob];
        for (uint256 i; i < users.length; i++) {
            imd.mint(users[i], 1_000_000e18);
            vm.prank(users[i]);
            imd.approve(address(router), type(uint256).max);
        }
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
        (coin,) = router.launch(_params("FROG", fees, bytes32(0)), devBuy, 0);
    }

    /// @dev Launches coins with increasing salts until the IMD/coin address ordering matches `imdFirst`.
    function _launchOrdered(CoinFees memory fees, bool imdFirst) internal returns (address coin) {
        for (uint256 i; i < 64; i++) {
            LaunchParams memory p = _params("FROG", fees, bytes32(i));
            address predicted = factory.predictAddress(p, creator);
            if ((address(imd) < predicted) == imdFirst) {
                vm.prank(creator);
                (coin,) = router.launch(p, 0, 0);
                return coin;
            }
        }
        revert("no salt found");
    }

    function _buy(address who, address coin, uint256 imdIn) internal returns (uint256 out) {
        vm.prank(who);
        out = router.buy(coin, imdIn, 0, block.timestamp, bytes32(0));
    }

    function _sell(address who, address coin, uint256 tokensIn) internal returns (uint256 out) {
        vm.startPrank(who);
        ERC20(coin).approve(address(router), tokensIn);
        out = router.sell(coin, tokensIn, 0, block.timestamp, bytes32(0));
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
            router.buy(coin, 1_000e18, 0, block.timestamp, bytes32(0));
            vm.stopPrank();
        }
    }
}
