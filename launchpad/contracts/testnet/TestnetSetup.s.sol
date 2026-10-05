// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {TestToken} from "./TestToken.sol";

/// @notice Prepares Robinhood Chain Testnet (46630) for `script/Deploy.s.sol`: test IMD and test USDG with public
///         faucets, then the two pools PondPad's payment routes use, shaped like mainnet's (HANDOFF §4):
///         - IMD/ETH: hookless, 1% fee, tick spacing 100, ~411 IMD per ETH (same key as mainnet);
///         - ETH/USDG: hookless, 0.05% fee, tick spacing 10, ~2,590 USDG per ETH (mainnet's has its own hook).
///         Writes deployments/<chainId>-setup.json, which Deploy.s.sol reads on any chain but 4663.
///
///   forge script testnet/TestnetSetup.s.sol --rpc-url robinhood_testnet --sender <wallet> --broadcast --account <ks>
///
/// Env (optional, in wei): IMD_POOL_ETH (default 0.5 ether), USDG_POOL_ETH (default 0.2 ether): ETH put in each pool.
/// Test IMD is mined to an address below 2^152 so $PONDPAD's mined address is always above it (D-19).
contract TestnetSetup is Script {
    IPoolManager internal constant PM = IPoolManager(0x8366a39CC670B4001A1121B8F6A443A643e40951); // same as mainnet
    uint256 internal constant IMD_PER_ETH = 411;
    uint256 internal constant USDG_PER_ETH = 2_590;
    uint24 internal constant ETH_USDG_FEE = 500;
    int24 internal constant ETH_USDG_SPACING = 10;

    struct Setup {
        TestToken imd;
        TestToken usdg;
        PoolModifyLiquidityTest liquidityRouter;
        PoolSwapTest swapRouter;
        PoolKey imdEth;
        PoolKey ethUsdg;
    }

    function run() external returns (Setup memory s) {
        require(block.chainid != 4663, "not on mainnet");
        uint256 imdPoolEth = vm.envOr("IMD_POOL_ETH", uint256(0.5 ether));
        uint256 usdgPoolEth = vm.envOr("USDG_POOL_ETH", uint256(0.2 ether));
        vm.startBroadcast(msg.sender);
        s = setup(msg.sender, imdPoolEth, usdgPoolEth);
        vm.stopBroadcast();
        _write(s);
        console2.log("test IMD         ", address(s.imd));
        console2.log("test USDG        ", address(s.usdg));
        console2.log("liquidity router ", address(s.liquidityRouter));
        console2.log("swap router      ", address(s.swapRouter));
    }

    /// @notice The whole setup. `owner` must be the account executing these calls (the broadcaster, or this
    ///         contract in a fork test) and must hold `imdPoolEth + usdgPoolEth` ETH.
    function setup(address owner, uint256 imdPoolEth, uint256 usdgPoolEth) public returns (Setup memory s) {
        s.imd = TestToken(_create2Below(_tokenCode("IMD (testnet)", "tIMD", 18, 500e18, owner), 1 << 152));
        s.usdg = TestToken(_create2(bytes32(0), _tokenCode("USDG (testnet)", "tUSDG", 6, 5_000e6, owner)));
        s.liquidityRouter = new PoolModifyLiquidityTest(PM);
        s.swapRouter = new PoolSwapTest(PM);

        s.imdEth = PoolKey(Currency.wrap(address(0)), Currency.wrap(address(s.imd)), 10_000, 100, IHooks(address(0)));
        s.ethUsdg = PoolKey(
            Currency.wrap(address(0)), Currency.wrap(address(s.usdg)), ETH_USDG_FEE, ETH_USDG_SPACING, IHooks(address(0))
        );
        _seed(owner, s.liquidityRouter, s.imdEth, s.imd, IMD_PER_ETH, 1, imdPoolEth);
        _seed(owner, s.liquidityRouter, s.ethUsdg, s.usdg, USDG_PER_ETH * 1e6, 1e18, usdgPoolEth);
    }

    /// @dev Opens `key` at `num / den` raw units of token per wei and adds ~`ethIn` ETH of full-range liquidity.
    function _seed(
        address owner,
        PoolModifyLiquidityTest lp,
        PoolKey memory key,
        TestToken token,
        uint256 num,
        uint256 den,
        uint256 ethIn
    ) internal {
        uint160 sqrtPrice = uint160(FixedPointMathLib.sqrt((num << 192) / den));
        PM.initialize(key, sqrtPrice);
        // Full range: amount0 ≈ L / sqrtP, amount1 ≈ L · sqrtP (Q96). 1% headroom on the ETH side.
        uint256 liquidity = FixedPointMathLib.mulDiv(ethIn, sqrtPrice, 1 << 96) * 99 / 100;
        token.mint(owner, FixedPointMathLib.mulDiv(ethIn, num, den) * 2);
        token.approve(address(lp), type(uint256).max);
        int24 spacing = key.tickSpacing;
        lp.modifyLiquidity{value: ethIn}(
            key,
            ModifyLiquidityParams(TickMath.minUsableTick(spacing), TickMath.maxUsableTick(spacing), int256(liquidity), 0),
            ""
        );
    }

    function _tokenCode(string memory name_, string memory symbol_, uint8 decimals_, uint256 faucetAmount, address owner)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(type(TestToken).creationCode, abi.encode(name_, symbol_, decimals_, faucetAmount, owner));
    }

    function _create2Below(bytes memory initCode, uint256 ceiling) internal returns (address) {
        bytes32 h = keccak256(initCode);
        uint256 i;
        while (uint160(vm.computeCreate2Address(bytes32(i), h, CREATE2_FACTORY)) >= ceiling) ++i;
        return _create2(bytes32(i), initCode);
    }

    function _create2(bytes32 salt, bytes memory initCode) internal returns (address addr) {
        (bool ok, bytes memory ret) = CREATE2_FACTORY.call(abi.encodePacked(salt, initCode));
        require(ok && ret.length == 20, "create2");
        addr = address(bytes20(ret));
    }

    /// @dev The liquidity router refunds spare ETH to the caller (this contract in a fork test).
    receive() external payable {}

    function _write(Setup memory s) internal {
        string memory k = "setup";
        vm.serializeAddress(k, "poolManager", address(PM));
        vm.serializeAddress(k, "imd", address(s.imd));
        vm.serializeAddress(k, "usdg", address(s.usdg));
        vm.serializeUint(k, "ethUsdgFee", ETH_USDG_FEE);
        vm.serializeUint(k, "ethUsdgTickSpacing", uint256(int256(ETH_USDG_SPACING)));
        vm.serializeAddress(k, "ethUsdgHook", address(0));
        vm.serializeAddress(k, "liquidityRouter", address(s.liquidityRouter));
        vm.serializeAddress(k, "swapRouter", address(s.swapRouter));
        string memory json = vm.serializeUint(k, "chainId", block.chainid);
        vm.writeJson(json, string.concat("deployments/", vm.toString(block.chainid), "-setup.json"));
    }
}
