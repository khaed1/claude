// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {PadConfig} from "./PadConfig.sol";
import {BondingCurve} from "./BondingCurve.sol";
import {PadHook} from "./PadHook.sol";
import {PadFactory, LaunchParams} from "./PadFactory.sol";

/// @title PadRouter
/// @notice The website's single entry point: launch (with an optional atomic dev buy), buy and sell. It routes to
///         the bonding curve before graduation and to the coin's Uniswap v4 pool after, and only ever moves the
///         caller's own funds. It holds no funds between transactions.
/// @dev This version trades in IMD. Paying and receiving ETH (ETH ⇄ IMD through the IMD/ETH pool) comes next.
contract PadRouter is IUnlockCallback, ReentrancyGuard {
    using SafeTransferLib for address;

    address public immutable imd;
    IPoolManager public immutable poolManager;
    PadConfig public immutable config;
    BondingCurve public immutable curve;
    PadHook public immutable hook;
    PadFactory public immutable factory;

    struct SwapData {
        PoolKey key;
        bool zeroForOne;
        int256 amountSpecified;
        address payer;
        address recipient;
    }

    event Launched(address indexed coin, address indexed creator, uint256 devBuyImd, uint256 devBuyTokens);
    event Referral(address indexed coin, address indexed trader, bytes32 indexed ref, bool isBuy, uint256 imdAmount);

    error Expired();
    error Slippage();
    error NotPoolManager();
    error LaunchesPaused();

    constructor(address imd_, address poolManager_, address config_, address curve_, address hook_, address factory_) {
        imd = imd_;
        poolManager = IPoolManager(poolManager_);
        config = PadConfig(config_);
        curve = BondingCurve(curve_);
        hook = PadHook(hook_);
        factory = PadFactory(factory_);
    }

    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert Expired();
        _;
    }

    // ------------------------------------------------------------------ Launch

    /// @notice Launches a coin. Pays the launch fee in IMD and optionally buys first, in the same transaction.
    function launch(LaunchParams calldata p, uint256 devBuyImd, uint256 minTokensOut)
        external
        nonReentrant
        returns (address coin, uint256 tokensOut)
    {
        if (config.launchesPaused()) revert LaunchesPaused();
        uint256 fee = config.launchSettings().launchFee;
        if (fee != 0) imd.safeTransferFrom(msg.sender, config.feeSplitter(), fee);
        coin = factory.create(p, msg.sender);
        if (devBuyImd != 0) {
            imd.safeTransferFrom(msg.sender, address(curve), devBuyImd);
            (tokensOut,) = curve.buy(coin, devBuyImd, minTokensOut, msg.sender, msg.sender, true);
        }
        emit Launched(coin, msg.sender, devBuyImd, tokensOut);
    }

    // ------------------------------------------------------------------ Trading

    function buy(address coin, uint256 imdIn, uint256 minTokensOut, uint256 deadline, bytes32 ref)
        external
        nonReentrant
        checkDeadline(deadline)
        returns (uint256 tokensOut)
    {
        if (curve.statusOf(coin) == BondingCurve.Status.Graduated) {
            PoolKey memory key = hook.poolKey(coin);
            bool imdIs0 = Currency.unwrap(key.currency0) == imd;
            tokensOut = _swap(key, imdIs0, -int256(imdIn), msg.sender, msg.sender);
            hook.flush(coin);
        } else {
            imd.safeTransferFrom(msg.sender, address(curve), imdIn);
            (tokensOut,) = curve.buy(coin, imdIn, minTokensOut, msg.sender, msg.sender, false);
        }
        if (tokensOut < minTokensOut) revert Slippage();
        if (ref != bytes32(0)) emit Referral(coin, msg.sender, ref, true, imdIn);
    }

    function sell(address coin, uint256 tokensIn, uint256 minImdOut, uint256 deadline, bytes32 ref)
        public
        nonReentrant
        checkDeadline(deadline)
        returns (uint256 imdOut)
    {
        imdOut = _sell(coin, tokensIn, minImdOut, ref);
    }

    /// @notice Sell with an EIP-2612 permit instead of a prior approval. A permit that was already used (for
    ///         example by a front-runner) is ignored, and the sell proceeds if the allowance is in place.
    function sellWithPermit(
        address coin,
        uint256 tokensIn,
        uint256 minImdOut,
        uint256 deadline,
        bytes32 ref,
        uint256 permitValue,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant checkDeadline(deadline) returns (uint256 imdOut) {
        try ERC20(coin).permit(msg.sender, address(this), permitValue, deadline, v, r, s) {} catch {}
        imdOut = _sell(coin, tokensIn, minImdOut, ref);
    }

    function _sell(address coin, uint256 tokensIn, uint256 minImdOut, bytes32 ref) internal returns (uint256 imdOut) {
        if (curve.statusOf(coin) == BondingCurve.Status.Graduated) {
            PoolKey memory key = hook.poolKey(coin);
            bool imdIs0 = Currency.unwrap(key.currency0) == imd;
            imdOut = _swap(key, !imdIs0, -int256(tokensIn), msg.sender, msg.sender);
            hook.flush(coin);
        } else {
            coin.safeTransferFrom(msg.sender, address(curve), tokensIn);
            imdOut = curve.sell(coin, tokensIn, minImdOut, msg.sender);
        }
        if (imdOut < minImdOut) revert Slippage();
        if (ref != bytes32(0)) emit Referral(coin, msg.sender, ref, false, imdOut);
    }

    // ------------------------------------------------------------------ v4 swaps

    function _swap(PoolKey memory key, bool zeroForOne, int256 amountSpecified, address payer, address recipient)
        internal
        returns (uint256 amountOut)
    {
        bytes memory result =
            poolManager.unlock(abi.encode(SwapData(key, zeroForOne, amountSpecified, payer, recipient)));
        amountOut = abi.decode(result, (uint256));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        SwapData memory d = abi.decode(data, (SwapData));
        BalanceDelta delta = poolManager.swap(
            d.key,
            SwapParams({
                zeroForOne: d.zeroForOne,
                amountSpecified: d.amountSpecified,
                sqrtPriceLimitX96: d.zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            abi.encode(d.payer)
        );
        (Currency input, Currency output) = d.zeroForOne ? (d.key.currency0, d.key.currency1) : (d.key.currency1, d.key.currency0);
        int128 inDelta = d.zeroForOne ? delta.amount0() : delta.amount1();
        int128 outDelta = d.zeroForOne ? delta.amount1() : delta.amount0();

        uint256 amountIn = uint256(int256(-inDelta));
        poolManager.sync(input);
        Currency.unwrap(input).safeTransferFrom(d.payer, address(poolManager), amountIn);
        poolManager.settle();

        uint256 amountOut = uint256(int256(outDelta));
        poolManager.take(output, d.recipient, amountOut);
        return abi.encode(amountOut);
    }
}
