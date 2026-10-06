// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {PadSale} from "../src/PadSale.sol";
import {PadConfig} from "../src/PadConfig.sol";
import {FeeSplitter} from "../src/FeeSplitter.sol";
import {BondingCurve} from "../src/BondingCurve.sol";
import {LaunchParams} from "../src/PadFactory.sol";
import {CoinFees} from "../src/FeeLib.sol";
import {LiquidityReserve} from "../src/LiquidityReserve.sol";
import {AirdropDistributor} from "../src/AirdropDistributor.sol";

/// @notice Full deployment rehearsal on live Robinhood Chain: runs `Deploy.deploy` exactly as the broadcast does,
///         then checks the wiring, a timelocked change by the Safe, and a lifecycle from coin launch through the
///         $PONDPAD sale's graduation to stakers' buys and team vesting. Skipped unless FORK_RPC is set.
contract DeployForkTest is Test {
    address internal constant IMD = 0x5F7Bb59365ce557C26dbcAa4EE9d39A4b95B7127;
    IPoolManager internal constant PM = IPoolManager(0x8366a39CC670B4001A1121B8F6A443A643e40951);

    Deploy internal script;
    Deploy.Deployment internal d;
    address internal safe = makeAddr("teamSafe");
    address internal relay = makeAddr("relay");
    uint256 internal saleStart;
    uint256 internal bn; // block number kept in storage: under via-IR a local can be re-read after vm.roll
    bool internal forked;

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC", string(""));
        if (bytes(rpc).length == 0) return;
        vm.createSelectFork(rpc);
        forked = true;
        saleStart = block.timestamp + 3 days;
        script = new Deploy();
        Deploy.Params memory p = Deploy.Params({
            chain: script.robinhood(),
            deployer: address(script),
            safe: safe,
            relay: relay,
            xLinkKey: makeAddr("xLinkKey"),
            tweetChecker: makeAddr("tweetChecker"),
            workerRewards: address(0),
            airdropRoot: keccak256("rehearsal root"),
            saleStart: saleStart,
            powersExpireAt: saleStart + 365 days,
            ctoRules: "ipfs://bafyrehearsalrules",
            auditLink: "https://imd.fun/jobs/rehearsal-audit"
        });
        d = script.deploy(p);
    }

    function test_deployFork_wiringAndOwners() public view {
        if (!forked) return;
        address fast = address(d.fastTimelock);
        address slow = address(d.slowTimelock);
        assertEq(d.fastTimelock.getMinDelay(), 48 hours);
        assertEq(d.slowTimelock.getMinDelay(), 7 days);
        assertTrue(d.fastTimelock.hasRole(d.fastTimelock.PROPOSER_ROLE(), safe));
        assertTrue(d.fastTimelock.hasRole(d.fastTimelock.EXECUTOR_ROLE(), address(0))); // anyone executes
        assertFalse(d.fastTimelock.hasRole(d.fastTimelock.DEFAULT_ADMIN_ROLE(), address(script)));

        // Coin launch settings (D-76): 0.35 IMD, Leap at 4,000 IMD, tax 70% over 80 s, max-buy 2% for 80 s.
        PadConfig.LaunchSettings memory ls = d.config.launchSettings();
        assertEq(ls.launchFee, 0.35e18);
        assertEq(ls.graduationTarget, 4_000e18);
        assertEq(ls.graduationFeeBps, 100);
        assertEq(ls.snipeTaxStartBps, 7_000);
        assertEq(ls.snipeTaxDuration, 80);
        assertEq(ls.maxBuyWindow, 80);
        assertEq(ls.maxBuyBps, 200);

        // Owners (HANDOFF §5): nothing is left with the deployer.
        assertEq(d.config.owner(), fast);
        assertEq(d.splitter.owner(), slow);
        assertEq(d.swarmBudget.owner(), fast);
        assertEq(d.verifier.owner(), slow);
        assertEq(d.social.owner(), fast);
        assertEq(d.cto.owner(), slow);
        assertEq(d.versions.owner(), slow);
        assertEq(d.workerFund.owner(), slow);
        assertEq(d.growthFund.owner(), fast);
        assertEq(d.controller.owner(), fast);
        assertEq(d.controller.sinkAdmin(), slow);
        assertEq(d.market.owner(), address(d.controller));
        assertEq(d.sVault.owner(), slow);
        assertEq(d.dripper.owner(), fast);
        assertEq(d.buyer.owner(), fast);
        assertEq(d.airdrop.owner(), fast);
        assertEq(d.config.guardian(), safe);
        assertEq(d.cto.council(), safe);
        assertEq(d.vesting.beneficiary(), safe);

        // Fee routing.
        FeeSplitter.Recipients memory r = d.splitter.recipients();
        assertEq(r.stakers, address(d.buyer));
        assertEq(r.workers, address(d.workerFund));
        assertEq(r.growth, address(d.growthFund));
        assertEq(r.treasury, safe);
        assertEq(d.config.growthFund(), address(d.growthFund));
        assertEq(d.market.rewardsRecipient(), address(d.dripper));
        assertEq(d.market.burnSink(), address(d.burner));

        // Mined addresses.
        assertGt(uint160(address(d.pondpad)), uint160(IMD));
        assertEq(uint160(address(d.hook)) & Hooks.ALL_HOOK_MASK, _padFlags());
        assertEq(uint160(address(d.market)) & Hooks.ALL_HOOK_MASK, _marketFlags());

        // Supply: 90% sale, 5% airdrop, 2% team, 3% liquidity reserve (for the 48 h timelock once the market opens,
        // audit R1-A2-4), none with the deployer.
        assertEq(d.pondpad.balanceOf(address(d.sale)), 900_000_000e18);
        assertEq(d.pondpad.balanceOf(address(d.airdrop)), 50_000_000e18);
        assertEq(d.pondpad.balanceOf(address(d.vesting)), 20_000_000e18);
        assertEq(d.pondpad.balanceOf(address(d.reserve)), 30_000_000e18);
        assertEq(d.pondpad.balanceOf(fast), 0);
        assertEq(d.reserve.beneficiary(), fast);
        assertEq(address(d.reserve.market()), address(d.controller));
        assertEq(d.pondpad.balanceOf(address(script)), 0);

        // Version 1 registered and activated with the audit link.
        assertEq(d.versions.current().router, address(d.router));
    }

    function _tinySwap(PoolSwapTest swapper, PoolKey memory key) internal {
        swapper.swap(
            key,
            SwapParams(true, -1e15, TickMath.MIN_SQRT_PRICE + 1),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
    }

    function _padFlags() internal pure returns (uint160) {
        return Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
    }

    function _marketFlags() internal pure returns (uint160) {
        return Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG
            | Hooks.AFTER_SWAP_FLAG;
    }

    function test_deployFork_safeChangesSettingsOnlyThroughTimelock() public {
        if (!forked) return;
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(safe);
        d.config.setIntegratorShareBps(2_000);

        bytes memory call_ = abi.encodeCall(PadConfig.setIntegratorShareBps, (2_000));
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(); // only the Safe proposes
        d.fastTimelock.schedule(address(d.config), 0, call_, bytes32(0), bytes32(0), 48 hours);
        vm.prank(safe);
        d.fastTimelock.schedule(address(d.config), 0, call_, bytes32(0), bytes32(0), 48 hours);
        vm.expectRevert(); // not ready
        d.fastTimelock.execute(address(d.config), 0, call_, bytes32(0), bytes32(0));
        vm.warp(block.timestamp + 48 hours);
        vm.prank(makeAddr("anyone"));
        d.fastTimelock.execute(address(d.config), 0, call_, bytes32(0), bytes32(0));
        assertEq(d.config.integratorShareBps(), 2_000);

        // Splitter shares sit behind the 7-day timelock.
        FeeSplitter.Shares memory s = FeeSplitter.Shares({stakers: 4_500, workers: 2_500, growth: 1_500, treasury: 1_500});
        bytes memory shares_ = abi.encodeCall(FeeSplitter.setShares, (s));
        vm.prank(safe);
        vm.expectRevert(); // below the 7-day minimum
        d.slowTimelock.schedule(address(d.splitter), 0, shares_, bytes32(0), bytes32(0), 48 hours);
    }

    function test_deployFork_lifecycle() public {
        if (!forked) return;
        // A coin launches and trades on its curve, paid in ETH.
        address creator = makeAddr("creator");
        vm.deal(creator, 1 ether);
        vm.prank(creator);
        (address coin,) = d.router.launchWith{value: 0.05 ether}(
            LaunchParams("Rehearsal Frog", "RFROG", "ipfs://x", address(0), CoinFees(50, 0, 10_000, 0), 0),
            address(0),
            0.05 ether,
            true,
            0,
            0,
            address(0)
        );
        assertEq(uint8(d.curve.statusOf(coin)), uint8(BondingCurve.Status.Trading));

        // The liquidity reserve can't move while the sale runs (audit R1-A2-4).
        vm.expectRevert(LiquidityReserve.MarketNotOpen.selector);
        d.reserve.release();

        // The sale is closed until its start, then graduates into the market.
        vm.expectRevert();
        d.sale.buyWith(IMD, 100e18, 0, 0, block.timestamp, address(0));
        uint256 t = saleStart + 30 minutes;
        vm.warp(t);
        for (uint256 i; d.sale.status() == PadSale.Status.Trading; i++) {
            address b = address(uint160(0x60000 + i));
            deal(IMD, b, 100e18);
            vm.startPrank(b);
            ERC20(IMD).approve(address(d.sale), type(uint256).max);
            d.sale.buyWith(IMD, 100e18, 0, 0, t, address(0));
            vm.stopPrank();
        }
        assertTrue(d.market.marketOpen());
        assertEq(d.controller.openedAt(), t);
        assertEq(d.reserve.release(), 30_000_000e18, "reserve to the 48 h timelock once the market is open");
        assertEq(d.pondpad.balanceOf(address(d.fastTimelock)), 30_000_000e18);
        assertEq(d.market.currentFee(), 30_000);

        // A market buy pays fees; they reach the splitter and the stakers' buyer turns IMD into $PONDPAD.
        PoolSwapTest swapper = new PoolSwapTest(PM);
        deal(IMD, address(this), 501e18);
        ERC20(IMD).approve(address(swapper), type(uint256).max);
        PoolKey memory key = d.market.poolKey();
        swapper.swap(
            key,
            SwapParams(true, -500e18, TickMath.MIN_SQRT_PRICE + 1),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
        // The buyer's price guard waits for the hook's lagged reference to catch up with the pump.
        bn = block.number;
        for (uint256 i = 1; i <= 12; i++) {
            vm.roll(bn + i);
            _tinySwap(swapper, key);
        }
        vm.roll(bn + 13);
        vm.warp(t + 1 hours);
        d.controller.collectFees();
        d.splitter.distribute();
        assertGt(ERC20(IMD).balanceOf(address(d.buyer)), 0);
        assertGt(ERC20(IMD).balanceOf(address(d.workerFund)), 0);
        assertGt(ERC20(IMD).balanceOf(safe), 0); // treasury
        uint256 bought = d.buyer.buy();
        assertGt(bought, 0);
        assertGt(d.pondpad.balanceOf(address(d.dripper)), 0);

        // The airdrop waits for its 100 initiators; team vesting starts at the market's open.
        vm.expectRevert(AirdropDistributor.NotActive.selector);
        d.airdrop.claim(address(this), 1, new bytes32[](0));
        assertEq(d.vesting.release(), 0);
        vm.warp(t + 30 days);
        assertEq(d.vesting.release(), uint256(20_000_000e18) / 6);
        assertEq(d.pondpad.balanceOf(safe), uint256(20_000_000e18) / 6);
    }
}
