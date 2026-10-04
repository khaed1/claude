// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {PadConfig} from "./PadConfig.sol";
import {Hop} from "./Route.sol";

/// @title PaymentSwapper
/// @notice Shared payment plumbing for PadRouter and PadSale: takes IMD, native ETH or any payment token approved
///         in PadConfig and swaps it to or from IMD along its configured route, inside one PoolManager unlock.
///         Inheriting contracts only move the caller's own funds and hold nothing between transactions.
abstract contract PaymentSwapper is IUnlockCallback {
    using SafeTransferLib for address;

    address internal constant ETH = address(0);

    address public immutable imd;
    IPoolManager public immutable poolManager;
    PadConfig public immutable config;

    /// @dev Exact-input path through one or more v4 pools inside a single unlock.
    struct Path {
        Hop[] hops;
        uint256 amountIn;
        address payer; // pays the first hop's input; address(this) = the contract's own balance or msg.value
        address recipient; // receives the last hop's output
        address trader; // reported to the hook for trade attribution
        address referrer; // integrator that routed the trade (earns a share of the protocol fee if registered)
    }

    error NotPoolManager();
    error UnsupportedToken();
    error WrongEthAmount();

    constructor(address imd_, address poolManager_, address config_) {
        imd = imd_;
        poolManager = IPoolManager(poolManager_);
        config = PadConfig(config_);
    }

    /// @dev Takes `amountIn` of `tokenIn` from the caller and delivers it to `recipient` as IMD.
    function _collectImd(address tokenIn, uint256 amountIn, address recipient, address referrer)
        internal
        returns (uint256)
    {
        if (tokenIn == imd) {
            if (msg.value != 0) revert WrongEthAmount();
            imd.safeTransferFrom(msg.sender, recipient, amountIn);
            return amountIn;
        }
        Hop[] memory route = _routeToImd(tokenIn);
        return _execute(Path(route, amountIn, _payer(tokenIn, amountIn), recipient, msg.sender, referrer));
    }

    /// @dev Pays `imdAmount` IMD held by this contract to `recipient` in `tokenOut`. Returns the amount paid.
    function _payOut(address tokenOut, uint256 imdAmount, address recipient, address referrer)
        internal
        returns (uint256)
    {
        Hop[] memory back = _routeFromImd(tokenOut);
        if (back.length == 0) {
            imd.safeTransfer(recipient, imdAmount);
            return imdAmount;
        }
        return _execute(Path(back, imdAmount, address(this), recipient, recipient, referrer));
    }

    /// @dev ETH is paid from msg.value (payer = this); ERC-20s are pulled from the caller.
    function _payer(address tokenIn, uint256 amountIn) internal view returns (address) {
        if (tokenIn == ETH) {
            if (msg.value != amountIn) revert WrongEthAmount();
            return address(this);
        }
        if (msg.value != 0) revert WrongEthAmount();
        return msg.sender;
    }

    /// @dev Route from `token` to IMD; empty for IMD itself.
    function _routeToImd(address token) internal view returns (Hop[] memory route) {
        if (token == imd) return route;
        route = config.routeToImd(token);
        if (route.length == 0) revert UnsupportedToken();
    }

    /// @dev The reverse route, from IMD back to `token`; empty for IMD itself.
    function _routeFromImd(address token) internal view returns (Hop[] memory back) {
        Hop[] memory route = _routeToImd(token);
        uint256 n = route.length;
        back = new Hop[](n);
        for (uint256 i; i < n; i++) {
            back[i] = Hop(route[n - 1 - i].key, !route[n - 1 - i].zeroForOne);
        }
    }

    // ------------------------------------------------------------------ v4 execution

    function _execute(Path memory path) internal returns (uint256 amountOut) {
        amountOut = abi.decode(poolManager.unlock(abi.encode(path)), (uint256));
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        Path memory path = abi.decode(data, (Path));
        bytes memory hookData = abi.encode(path.trader, path.referrer);

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
