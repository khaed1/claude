// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {PadConfig} from "./PadConfig.sol";
import {BondingCurve} from "./BondingCurve.sol";
import {PadHook} from "./PadHook.sol";
import {PadFactory, LaunchParams} from "./PadFactory.sol";

/// @title PadRouter
/// @notice The website's single entry point: launch (with an optional atomic dev buy), buy and sell, paying or
///         receiving IMD or ETH. It routes to the bonding curve before graduation and to the coin's Uniswap v4
///         pool after. ETH is swapped to or from IMD in the same transaction through the IMD/ETH pool set in
///         PadConfig. The router only moves the caller's own funds and holds nothing between transactions.
contract PadRouter is IUnlockCallback, ReentrancyGuard {
    using SafeTransferLib for address;

    address public immutable imd;
    IPoolManager public immutable poolManager;
    PadConfig public immutable config;
    BondingCurve public immutable curve;
    PadHook public immutable hook;
    PadFactory public immutable factory;

    struct Hop {
        PoolKey key;
        bool zeroForOne;
    }

    /// @dev Exact-input path through one or more v4 pools inside a single unlock.
    struct Path {
        Hop[] hops;
        uint256 amountIn;
        address payer; // pays the first hop's input; address(this) = the router's own balance
        address recipient; // receives the last hop's output
        address trader; // reported to the hook for trade attribution
    }

    event Launched(address indexed coin, address indexed creator, uint256 devBuyImd, uint256 devBuyTokens);
    event Referral(address indexed coin, address indexed trader, bytes32 indexed ref, bool isBuy, uint256 imdAmount);

    error Expired();
    error Slippage();
    error NotPoolManager();
    error LaunchesPaused();
    error InsufficientForFee();

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

    /// @notice Launches a coin, paying the launch fee in IMD, with an optional dev buy in the same transaction.
    function launch(LaunchParams calldata p, uint256 devBuyImd, uint256 minTokensOut)
        external
        nonReentrant
        returns (address coin, uint256 tokensOut)
    {
        uint256 fee = _launchFee();
        if (fee != 0) imd.safeTransferFrom(msg.sender, config.feeSplitter(), fee);
        coin = factory.create(p, msg.sender);
        if (devBuyImd != 0) {
            imd.safeTransferFrom(msg.sender, address(curve), devBuyImd);
            (tokensOut,) = curve.buy(coin, devBuyImd, minTokensOut, msg.sender, msg.sender, true);
        }
        emit Launched(coin, msg.sender, devBuyImd, tokensOut);
    }

    /// @notice Launches a coin paying with ETH. All of `msg.value` is swapped to IMD; the launch fee comes out of
    ///         it, and the rest is either used as the dev buy or returned as IMD.
    function launchWithEth(LaunchParams calldata p, bool devBuy, uint256 minImdFromEth, uint256 minTokensOut)
        external
        payable
        nonReentrant
        returns (address coin, uint256 tokensOut)
    {
        uint256 imdIn = _swapEthToImd(msg.value, address(this), msg.sender);
        if (imdIn < minImdFromEth) revert Slippage();
        uint256 fee = _launchFee();
        if (imdIn < fee) revert InsufficientForFee();
        if (fee != 0) imd.safeTransfer(config.feeSplitter(), fee);
        coin = factory.create(p, msg.sender);
        uint256 rest = imdIn - fee;
        if (rest != 0) {
            if (devBuy) {
                imd.safeTransfer(address(curve), rest);
                (tokensOut,) = curve.buy(coin, rest, minTokensOut, msg.sender, msg.sender, true);
            } else {
                imd.safeTransfer(msg.sender, rest);
            }
        }
        emit Launched(coin, msg.sender, devBuy ? rest : 0, tokensOut);
    }

    function _launchFee() internal view returns (uint256) {
        if (config.launchesPaused()) revert LaunchesPaused();
        return config.launchSettings().launchFee;
    }

    // ------------------------------------------------------------------ Buy

    function buy(address coin, uint256 imdIn, uint256 minTokensOut, uint256 deadline, bytes32 ref)
        external
        nonReentrant
        checkDeadline(deadline)
        returns (uint256 tokensOut)
    {
        if (_graduated(coin)) {
            Hop[] memory hops = new Hop[](1);
            hops[0] = _coinHop(coin, true);
            tokensOut = _execute(Path(hops, imdIn, msg.sender, msg.sender, msg.sender));
            hook.flush(coin);
        } else {
            imd.safeTransferFrom(msg.sender, address(curve), imdIn);
            (tokensOut,) = curve.buy(coin, imdIn, minTokensOut, msg.sender, msg.sender, false);
        }
        if (tokensOut < minTokensOut) revert Slippage();
        if (ref != bytes32(0)) emit Referral(coin, msg.sender, ref, true, imdIn);
    }

    /// @notice Buys with ETH: ETH → IMD → coin in one transaction. If this buy completes the bonding curve, the
    ///         unused part is refunded in IMD.
    function buyWithEth(address coin, uint256 minTokensOut, uint256 deadline, bytes32 ref)
        external
        payable
        nonReentrant
        checkDeadline(deadline)
        returns (uint256 tokensOut)
    {
        uint256 imdIn;
        if (_graduated(coin)) {
            Hop[] memory hops = new Hop[](2);
            hops[0] = Hop(config.imdEthPoolKey(), true);
            hops[1] = _coinHop(coin, true);
            tokensOut = _execute(Path(hops, msg.value, address(this), msg.sender, msg.sender));
            hook.flush(coin);
        } else {
            imdIn = _swapEthToImd(msg.value, address(curve), msg.sender);
            (tokensOut,) = curve.buy(coin, imdIn, minTokensOut, msg.sender, msg.sender, false);
        }
        if (tokensOut < minTokensOut) revert Slippage();
        if (ref != bytes32(0)) emit Referral(coin, msg.sender, ref, true, imdIn);
    }

    // ------------------------------------------------------------------ Sell

    function sell(address coin, uint256 tokensIn, uint256 minImdOut, uint256 deadline, bytes32 ref)
        external
        nonReentrant
        checkDeadline(deadline)
        returns (uint256 imdOut)
    {
        imdOut = _sell(coin, tokensIn, minImdOut, ref, false);
    }

    function sellForEth(address coin, uint256 tokensIn, uint256 minEthOut, uint256 deadline, bytes32 ref)
        external
        nonReentrant
        checkDeadline(deadline)
        returns (uint256 ethOut)
    {
        ethOut = _sell(coin, tokensIn, minEthOut, ref, true);
    }

    /// @notice Sell with an EIP-2612 permit instead of a prior approval. A permit that was already used (for
    ///         example by a front-runner) is ignored, and the sell proceeds if the allowance is in place.
    function sellWithPermit(
        address coin,
        uint256 tokensIn,
        uint256 minOut,
        bool receiveEth,
        uint256 deadline,
        bytes32 ref,
        uint256 permitValue,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant checkDeadline(deadline) returns (uint256 out) {
        try ERC20(coin).permit(msg.sender, address(this), permitValue, deadline, v, r, s) {} catch {}
        out = _sell(coin, tokensIn, minOut, ref, receiveEth);
    }

    function _sell(address coin, uint256 tokensIn, uint256 minOut, bytes32 ref, bool receiveEth)
        internal
        returns (uint256 out)
    {
        uint256 imdOut;
        if (_graduated(coin)) {
            Hop[] memory hops = new Hop[](receiveEth ? 2 : 1);
            hops[0] = _coinHop(coin, false);
            if (receiveEth) hops[1] = Hop(config.imdEthPoolKey(), false);
            out = _execute(Path(hops, tokensIn, msg.sender, msg.sender, msg.sender));
            hook.flush(coin);
        } else {
            coin.safeTransferFrom(msg.sender, address(curve), tokensIn);
            if (receiveEth) {
                imdOut = curve.sell(coin, tokensIn, 0, address(this));
                Hop[] memory hops = new Hop[](1);
                hops[0] = Hop(config.imdEthPoolKey(), false);
                out = _execute(Path(hops, imdOut, address(this), msg.sender, msg.sender));
            } else {
                out = curve.sell(coin, tokensIn, minOut, msg.sender);
            }
        }
        if (out < minOut) revert Slippage();
        if (ref != bytes32(0)) emit Referral(coin, msg.sender, ref, false, receiveEth ? imdOut : out);
    }

    // ------------------------------------------------------------------ Helpers

    function _graduated(address coin) internal view returns (bool) {
        return curve.statusOf(coin) == BondingCurve.Status.Graduated;
    }

    /// @dev The hop through a graduated coin's pool. `buy` = IMD in, coin out.
    function _coinHop(address coin, bool isBuy) internal view returns (Hop memory) {
        PoolKey memory key = hook.poolKey(coin);
        bool imdIs0 = Currency.unwrap(key.currency0) == imd;
        return Hop(key, isBuy == imdIs0);
    }

    function _swapEthToImd(uint256 ethIn, address recipient, address trader) internal returns (uint256) {
        Hop[] memory hops = new Hop[](1);
        hops[0] = Hop(config.imdEthPoolKey(), true);
        return _execute(Path(hops, ethIn, address(this), recipient, trader));
    }

    function _execute(Path memory path) internal returns (uint256 amountOut) {
        amountOut = abi.decode(poolManager.unlock(abi.encode(path)), (uint256));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        Path memory path = abi.decode(data, (Path));
        bytes memory hookData = abi.encode(path.trader);

        uint256 amount = path.amountIn;
        for (uint256 i; i < path.hops.length; i++) {
            Hop memory h = path.hops[i];
            BalanceDelta delta = poolManager.swap(
                h.key,
                SwapParams({
                    zeroForOne: h.zeroForOne,
                    amountSpecified: -int256(amount),
                    sqrtPriceLimitX96: h.zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
                }),
                hookData
            );
            int128 outDelta = h.zeroForOne ? delta.amount1() : delta.amount0();
            amount = uint256(int256(outDelta));
        }

        Hop memory first = path.hops[0];
        Currency input = first.zeroForOne ? first.key.currency0 : first.key.currency1;
        Hop memory last = path.hops[path.hops.length - 1];
        Currency output = last.zeroForOne ? last.key.currency1 : last.key.currency0;

        if (input.isAddressZero()) {
            poolManager.settle{value: path.amountIn}();
        } else {
            poolManager.sync(input);
            if (path.payer == address(this)) {
                Currency.unwrap(input).safeTransfer(address(poolManager), path.amountIn);
            } else {
                Currency.unwrap(input).safeTransferFrom(path.payer, address(poolManager), path.amountIn);
            }
            poolManager.settle();
        }
        poolManager.take(output, path.recipient, amount);
        return abi.encode(amount);
    }
}
