// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {PadConfig} from "./PadConfig.sol";
import {BondingCurve} from "./BondingCurve.sol";
import {PadHook} from "./PadHook.sol";
import {PadFactory, LaunchParams} from "./PadFactory.sol";
import {Hop} from "./Route.sol";

/// @title PadRouter
/// @notice The website's single entry point: launch (with an optional atomic dev buy), buy and sell. Users pay or
///         receive IMD or any payment token approved in PadConfig (ETH and USDG at launch), which is swapped to or
///         from IMD in the same transaction along its configured route. The router sends trades to the bonding
///         curve before graduation and to the coin's Uniswap v4 pool after. It only moves the caller's own funds
///         and holds nothing between transactions.
contract PadRouter is IUnlockCallback, ReentrancyGuard {
    using SafeTransferLib for address;

    address internal constant ETH = address(0);

    address public immutable imd;
    IPoolManager public immutable poolManager;
    PadConfig public immutable config;
    BondingCurve public immutable curve;
    PadHook public immutable hook;
    PadFactory public immutable factory;

    /// @dev Exact-input path through one or more v4 pools inside a single unlock.
    struct Path {
        Hop[] hops;
        uint256 amountIn;
        address payer; // pays the first hop's input; address(this) = the router's own balance or msg.value
        address recipient; // receives the last hop's output
        address trader; // reported to the hook for trade attribution
        address referrer; // integrator that routed the trade (earns a share of the protocol fee if registered)
    }

    event Launched(address indexed coin, address indexed creator, uint256 devBuyImd, uint256 devBuyTokens);

    error Expired();
    error Slippage();
    error NotPoolManager();
    error LaunchesPaused();
    error InsufficientForFee();
    error UnsupportedToken();
    error WrongEthAmount();

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

    /// @notice Launches a coin paying in `tokenIn` (IMD, ETH or another payment token). Everything paid is turned
    ///         into IMD; the launch fee comes out of it, and the rest is either the creator's dev buy (exempt from
    ///         the snipe tax and max-buy) or returned as IMD.
    /// @param minImd Minimum IMD the payment must convert to (slippage on the conversion).
    /// @param referrer Integrator (app, bot) that brought the launch; earns its share on the dev buy's protocol fee.
    function launchWith(
        LaunchParams calldata p,
        address tokenIn,
        uint256 amountIn,
        bool devBuy,
        uint256 minImd,
        uint256 minTokensOut,
        address referrer
    ) external payable nonReentrant returns (address coin, uint256 tokensOut) {
        uint256 fee = _launchFee();
        uint256 imdIn = _collectImd(tokenIn, amountIn, address(this), referrer);
        if (imdIn < minImd) revert Slippage();
        if (imdIn < fee) revert InsufficientForFee();
        if (fee != 0) imd.safeTransfer(config.feeSplitter(), fee);
        coin = factory.create(p, msg.sender);
        uint256 rest = imdIn - fee;
        if (rest != 0) {
            if (devBuy) {
                imd.safeTransfer(address(curve), rest);
                (tokensOut,) = curve.buy(coin, rest, minTokensOut, msg.sender, msg.sender, true, referrer);
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

    /// @notice Buys `coin` paying `amountIn` of `tokenIn` (IMD, ETH or another payment token). If the buy completes
    ///         the bonding curve, the unused part is refunded in IMD.
    function buyWith(
        address coin,
        address tokenIn,
        uint256 amountIn,
        uint256 minTokensOut,
        uint256 deadline,
        address referrer
    ) external payable nonReentrant checkDeadline(deadline) returns (uint256 tokensOut) {
        if (curve.statusOf(coin) == BondingCurve.Status.Graduated) {
            // One unlock: [payment route →] IMD → coin.
            Hop[] memory route = _routeToImd(tokenIn);
            Hop[] memory hops = new Hop[](route.length + 1);
            for (uint256 i; i < route.length; i++) {
                hops[i] = route[i];
            }
            hops[route.length] = _coinHop(coin, true);
            tokensOut = _execute(Path(hops, amountIn, _payer(tokenIn, amountIn), msg.sender, msg.sender, referrer));
            _flushFees(coin, referrer);
        } else {
            uint256 imdIn = _collectImd(tokenIn, amountIn, address(curve), referrer);
            (tokensOut,) = curve.buy(coin, imdIn, minTokensOut, msg.sender, msg.sender, false, referrer);
        }
        if (tokensOut < minTokensOut) revert Slippage();
    }

    // ------------------------------------------------------------------ Sell

    /// @notice Sells `tokensIn` of `coin` and pays out in `tokenOut` (IMD, ETH or another payment token).
    function sellFor(
        address coin,
        address tokenOut,
        uint256 tokensIn,
        uint256 minOut,
        uint256 deadline,
        address referrer
    ) external nonReentrant checkDeadline(deadline) returns (uint256 out) {
        out = _sell(coin, tokenOut, tokensIn, minOut, referrer);
    }

    /// @notice Sell with an EIP-2612 permit instead of a prior approval. A permit that was already used (for
    ///         example by a front-runner) is ignored, and the sell proceeds if the allowance is in place.
    function sellForWithPermit(
        address coin,
        address tokenOut,
        uint256 tokensIn,
        uint256 minOut,
        uint256 deadline,
        address referrer,
        uint256 permitValue,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant checkDeadline(deadline) returns (uint256 out) {
        try ERC20(coin).permit(msg.sender, address(this), permitValue, deadline, v, r, s) {} catch {}
        out = _sell(coin, tokenOut, tokensIn, minOut, referrer);
    }

    function _sell(address coin, address tokenOut, uint256 tokensIn, uint256 minOut, address referrer)
        internal
        returns (uint256 out)
    {
        Hop[] memory back = _routeFromImd(tokenOut);
        if (curve.statusOf(coin) == BondingCurve.Status.Graduated) {
            // One unlock: coin → IMD [→ payment route back].
            Hop[] memory hops = new Hop[](back.length + 1);
            hops[0] = _coinHop(coin, false);
            for (uint256 i; i < back.length; i++) {
                hops[i + 1] = back[i];
            }
            out = _execute(Path(hops, tokensIn, msg.sender, msg.sender, msg.sender, referrer));
            _flushFees(coin, referrer);
        } else {
            coin.safeTransferFrom(msg.sender, address(curve), tokensIn);
            if (back.length == 0) {
                out = curve.sell(coin, tokensIn, minOut, msg.sender, referrer);
            } else {
                uint256 imdOut = curve.sell(coin, tokensIn, 0, address(this), referrer);
                out = _execute(Path(back, imdOut, address(this), msg.sender, msg.sender, referrer));
            }
        }
        if (out < minOut) revert Slippage();
    }

    // ------------------------------------------------------------------ Payment conversion

    /// @dev Flushes a graduated coin's pending fees, and the integrator's earnings when there is one.
    function _flushFees(address coin, address referrer) internal {
        hook.flush(coin);
        if (config.integratorShareFor(referrer) != 0) hook.flushIntegrator(referrer);
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

    /// @dev The hop through a graduated coin's pool. `isBuy` = IMD in, coin out.
    function _coinHop(address coin, bool isBuy) internal view returns (Hop memory) {
        PoolKey memory key = hook.poolKey(coin);
        bool imdIs0 = Currency.unwrap(key.currency0) == imd;
        return Hop(key, isBuy == imdIs0);
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
