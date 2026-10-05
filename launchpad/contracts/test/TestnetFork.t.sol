// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {TestnetSetup} from "../testnet/TestnetSetup.s.sol";
import {TestToken} from "../testnet/TestToken.sol";
import {PadSale} from "../src/PadSale.sol";
import {PadConfig} from "../src/PadConfig.sol";
import {BondingCurve} from "../src/BondingCurve.sol";
import {LaunchParams} from "../src/PadFactory.sol";
import {CoinFees} from "../src/FeeLib.sol";

/// @notice Testnet rehearsal on live Robinhood Chain Testnet (46630): runs `TestnetSetup.setup` (test IMD / USDG,
///         IMD/ETH and ETH/USDG pools) and then `Deploy.deploy` with the testnet chain values, exactly as the two
///         broadcasts do, and drives a coin and the $PONDPAD sale through graduation. Skipped unless TESTNET_RPC is
///         set: TESTNET_RPC=https://rpc.testnet.chain.robinhood.com forge test --match-contract TestnetFork
contract TestnetForkTest is Test {
    TestnetSetup internal setupScript;
    TestnetSetup.Setup internal s;
    Deploy internal script;
    Deploy.Deployment internal d;
    address internal safe = makeAddr("teamSafe");
    uint256 internal saleStart;
    bool internal forked;

    function setUp() public {
        string memory rpc = vm.envOr("TESTNET_RPC", string(""));
        if (bytes(rpc).length == 0) return;
        vm.createSelectFork(rpc);
        forked = true;
        assertEq(block.chainid, 46630);

        setupScript = new TestnetSetup();
        vm.deal(address(setupScript), 1 ether);
        s = setupScript.setup(address(setupScript), 0.5 ether, 0.2 ether);

        saleStart = block.timestamp + 1 hours;
        script = new Deploy();
        Deploy.Params memory p = Deploy.Params({
            chain: Deploy.Network({
                poolManager: address(s.liquidityRouter.manager()),
                imd: address(s.imd),
                usdg: address(s.usdg),
                ethUsdgFee: 500,
                ethUsdgTickSpacing: 10,
                ethUsdgHook: address(0),
                fastDelay: 10 minutes,
                slowDelay: 30 minutes
            }),
            deployer: address(script),
            safe: safe,
            relay: makeAddr("relay"),
            xLinkKey: makeAddr("xLinkKey"),
            tweetChecker: makeAddr("tweetChecker"),
            workerRewards: address(0),
            airdropRoot: keccak256("testnet root"),
            saleStart: saleStart,
            powersExpireAt: saleStart + 365 days,
            ctoRules: "ipfs://bafytestnetrules",
            auditLink: "https://imd.fun/jobs/testnet"
        });
        d = script.deploy(p);
    }

    function test_testnetFork_setupAndWiring() public {
        if (!forked) return;
        // Test tokens: IMD sits low so $PONDPAD is above it; public faucet once per hour.
        assertLt(uint160(address(s.imd)), uint160(1) << 152);
        assertGt(uint160(address(d.pondpad)), uint160(address(s.imd)));
        assertEq(s.usdg.decimals(), 6);
        address user = makeAddr("faucetUser");
        vm.startPrank(user);
        s.imd.faucet();
        vm.expectRevert();
        s.imd.faucet();
        vm.stopPrank();
        assertEq(s.imd.balanceOf(user), 500e18);
        vm.expectRevert(); // only the setup wallet mints
        vm.prank(user);
        s.imd.mint(user, 1);

        // The IMD/ETH pool quotes ~411 IMD per ETH (1% fee, small price impact).
        vm.deal(user, 1 ether);
        vm.prank(user);
        s.swapRouter.swap{value: 0.001 ether}(
            s.imdEth,
            SwapParams(true, -0.001 ether, TickMath.MIN_SQRT_PRICE + 1),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
        uint256 got = s.imd.balanceOf(user) - 500e18;
        assertApproxEqRel(got, 0.411e18 * 99 / 100, 0.01e18);

        // Short testnet delays, same owners as mainnet.
        assertEq(d.fastTimelock.getMinDelay(), 10 minutes);
        assertEq(d.slowTimelock.getMinDelay(), 30 minutes);
        assertEq(d.config.owner(), address(d.fastTimelock));
        assertEq(d.splitter.owner(), address(d.slowTimelock));
        assertEq(d.pondpad.balanceOf(address(script)), 0);

        // The Safe changes a setting through the 10-minute timelock.
        bytes memory call_ = abi.encodeCall(PadConfig.setIntegratorShareBps, (2_000));
        vm.prank(safe);
        d.fastTimelock.schedule(address(d.config), 0, call_, bytes32(0), bytes32(0), 10 minutes);
        vm.warp(saleStart - 50 minutes);
        d.fastTimelock.execute(address(d.config), 0, call_, bytes32(0), bytes32(0));
        assertEq(d.config.integratorShareBps(), 2_000);
    }

    function test_testnetFork_lifecycle() public {
        if (!forked) return;
        // Launch with ETH, buy with USDG, then fill the curve with faucet IMD: the coin leaps.
        address creator = makeAddr("creator");
        vm.deal(creator, 1 ether);
        vm.prank(creator);
        (address coin,) = d.router.launchWith{value: 0.01 ether}(
            LaunchParams("Testnet Frog", "TFROG", "ipfs://x", address(0), CoinFees(50, 0, 10_000, 0), 0),
            address(0),
            0.01 ether,
            true,
            0,
            0,
            address(0)
        );
        address usdgBuyer = makeAddr("usdgBuyer");
        vm.prank(address(setupScript));
        s.usdg.mint(usdgBuyer, 20e6);
        vm.warp(saleStart - 55 minutes); // past the coin's snipe and max-buy windows
        vm.startPrank(usdgBuyer);
        s.usdg.approve(address(d.router), type(uint256).max);
        assertGt(d.router.buyWith(coin, address(s.usdg), 20e6, 1, saleStart, address(0)), 0);
        vm.stopPrank();

        for (uint256 i; d.curve.statusOf(coin) == BondingCurve.Status.Trading; i++) {
            address b = address(uint160(0x70000 + i));
            _mintImd(b, 1_000e18);
            vm.startPrank(b);
            s.imd.approve(address(d.router), type(uint256).max);
            d.router.buyWith(coin, address(s.imd), 1_000e18, 0, saleStart, address(0));
            vm.stopPrank();
        }
        assertEq(uint8(d.curve.statusOf(coin)), uint8(BondingCurve.Status.Graduated));
        // After the Leap the same router trades in the pool, paid in ETH.
        vm.prank(creator);
        assertGt(d.router.buyWith{value: 0.001 ether}(coin, address(0), 0.001 ether, 1, saleStart, address(0)), 0);

        // The $PONDPAD sale opens at its start and graduates into the market.
        uint256 t = saleStart + 30 minutes;
        vm.warp(t);
        for (uint256 i; d.sale.status() == PadSale.Status.Trading; i++) {
            address b = address(uint160(0x80000 + i));
            _mintImd(b, 100e18);
            vm.startPrank(b);
            s.imd.approve(address(d.sale), type(uint256).max);
            d.sale.buyWith(address(s.imd), 100e18, 0, t, address(0));
            vm.stopPrank();
        }
        assertTrue(d.market.marketOpen());
        assertEq(d.controller.openedAt(), t);

        // A market buy, then fees through the splitter to the stakers' buyer.
        _mintImd(address(this), 500e18);
        s.imd.approve(address(s.swapRouter), type(uint256).max);
        PoolKey memory key = d.market.poolKey();
        s.swapRouter.swap(
            key,
            SwapParams(true, -500e18, TickMath.MIN_SQRT_PRICE + 1),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
        vm.warp(t + 1 hours);
        d.controller.collectFees();
        d.splitter.distribute();
        assertGt(s.imd.balanceOf(address(d.buyer)), 0);
        assertGt(s.imd.balanceOf(safe), 0); // treasury
    }

    function _mintImd(address to, uint256 amount) internal {
        vm.prank(address(setupScript));
        s.imd.mint(to, amount);
    }

    receive() external payable {}
}
