// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BondingCurve} from "./BondingCurve.sol";
import {PadHook} from "./PadHook.sol";
import {PadFactory, LaunchParams} from "./PadFactory.sol";
import {PaymentSwapper} from "./PaymentSwapper.sol";
import {Hop} from "./Route.sol";

/// @title PadRouter
/// @notice The website's single entry point: launch (with an optional atomic dev buy), buy and sell. Users pay or
///         receive IMD or any payment token approved in PadConfig (ETH and USDG at launch), which is swapped to or
///         from IMD in the same transaction along its configured route. The router sends trades to the bonding
///         curve before graduation and to the coin's Uniswap v4 pool after. It only moves the caller's own funds
///         and holds nothing between transactions.
contract PadRouter is PaymentSwapper, ReentrancyGuard {
    using SafeTransferLib for address;

    BondingCurve public immutable curve;
    PadHook public immutable hook;
    PadFactory public immutable factory;

    event Launched(address indexed coin, address indexed creator, uint256 devBuyImd, uint256 devBuyTokens);

    error Expired();
    error Slippage();
    error LaunchesPaused();
    error InsufficientForFee();

    constructor(address imd_, address poolManager_, address config_, address curve_, address hook_, address factory_)
        PaymentSwapper(imd_, poolManager_, config_)
    {
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
        uint256 devBuyImd;
        if (rest != 0) {
            if (devBuy) {
                imd.safeTransfer(address(curve), rest);
                uint256 refund;
                (tokensOut, refund) = curve.buy(coin, rest, minTokensOut, msg.sender, msg.sender, true, referrer);
                devBuyImd = rest - refund; // what the dev buy kept, after a completing buy's refund (audit R3-A1-5)
            } else {
                imd.safeTransfer(msg.sender, rest);
            }
        } else if (devBuy && minTokensOut != 0) {
            revert Slippage(); // a requested dev buy that buys nothing honours minTokensOut (audit R3-A1-4)
        }
        emit Launched(coin, msg.sender, devBuyImd, tokensOut);
    }

    function _launchFee() internal view returns (uint256) {
        if (config.launchesPaused()) revert LaunchesPaused();
        return config.launchSettings().launchFee;
    }

    // ------------------------------------------------------------------ Buy

    /// @notice Buys `coin` paying `amountIn` of `tokenIn` (IMD, ETH or another payment token). If the buy completes
    ///         the bonding curve, the unused part is refunded in IMD.
    /// @param minImd Minimum IMD the payment must convert to on a curve buy (0 for IMD payments). A buy that completes
    ///        the curve gets the same tokens whatever IMD arrives and refunds the rest, so `minTokensOut` alone can't
    ///        bound the payment swap there (audit R2-A2-2). After graduation every IMD buys tokens in the pool, so
    ///        `minTokensOut` bounds the whole route and `minImd` is not used.
    function buyWith(
        address coin,
        address tokenIn,
        uint256 amountIn,
        uint256 minImd,
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
            _flushOthers(coin);
            tokensOut = _execute(Path(hops, amountIn, _payer(tokenIn, amountIn), msg.sender, msg.sender, referrer));
            _flushFees(coin, referrer);
        } else {
            uint256 imdIn = _collectImd(tokenIn, amountIn, address(curve), referrer);
            if (imdIn < minImd) revert Slippage();
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
            _flushOthers(coin);
            out = _execute(Path(hops, tokensIn, msg.sender, msg.sender, msg.sender, referrer));
            _flushFees(coin, referrer);
        } else {
            coin.safeTransferFrom(msg.sender, address(curve), tokensIn);
            if (back.length == 0) {
                out = curve.sell(coin, tokensIn, minOut, msg.sender, msg.sender, referrer);
            } else {
                uint256 imdOut = curve.sell(coin, tokensIn, 0, address(this), msg.sender, referrer);
                out = _payOut(tokenOut, imdOut, msg.sender, referrer);
            }
        }
        if (out < minOut) revert Slippage();
    }

    // ------------------------------------------------------------------ Payment conversion

    /// @dev Before a pool trade: holder tax still pending from other traders' swaps (outside routers since the last
    ///      flush) is paid out as `flush` pays it, to whoever holds now, so the `flushFor` after this trade applies the
    ///      sole-holder rule to this trade's own tax only (audit R4-A1-1).
    function _flushOthers(address coin) internal {
        (,, uint128 holders,) = hook.pending(coin);
        if (holders != 0) hook.flush(coin);
    }

    /// @dev Flushes a graduated coin's pending fees (leaving the trader out of the holder-tax check, audit R3-A1-1),
    ///      and the integrator's earnings when there is one.
    function _flushFees(address coin, address referrer) internal {
        hook.flushFor(coin, msg.sender);
        if (config.integratorShareFor(referrer) != 0) hook.flushIntegrator(referrer);
    }

    /// @dev The hop through a graduated coin's pool. `isBuy` = IMD in, coin out.
    function _coinHop(address coin, bool isBuy) internal view returns (Hop memory) {
        PoolKey memory key = hook.poolKey(coin);
        bool imdIs0 = Currency.unwrap(key.currency0) == imd;
        return Hop(key, isBuy == imdIs0);
    }
}
