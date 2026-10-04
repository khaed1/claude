// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {SwapMath} from "v4-core/libraries/SwapMath.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {BondingCurve} from "./BondingCurve.sol";
import {PadHook} from "./PadHook.sol";
import {PadToken} from "./PadToken.sol";
import {CoinFees, FeeLib} from "./FeeLib.sol";

interface ILensCreatorVault {
    function recipientOf(address coin) external view returns (address);
    function balanceOf(address coin) external view returns (uint256);
}

interface ILensSwarmBudget {
    function available(address coin) external view returns (uint256);
}

/// @title PadLens
/// @notice Read-only views for the website and integrators: coin lists with pagination, one coin's full state,
///         buy and sell quotes in IMD on the curve or in the pool (whichever the coin is in), and a wallet's
///         balances and pending dividends. Holds no funds and changes nothing.
/// @dev Pool quotes are exact for PadHook pools: each pool holds a single full-range position, so a swap is one
///      `SwapMath` step at the pool's liquidity, with the hook's fee on the IMD side (pool LP fee is 0). A quote
///      reports `fullFill = false` when the trade would run past the full range (the hook rejects partial fills of
///      exact-in buys). Quotes are in IMD; the router's ETH / USDG legs are quoted with the v4 Quoter.
contract PadLens {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    uint256 internal constant BPS = 10_000;
    uint256 internal constant Q96 = 1 << 96;

    BondingCurve public immutable curve;
    PadHook public immutable hook;
    IPoolManager public immutable poolManager;
    ILensCreatorVault public immutable creatorVault;
    ILensSwarmBudget public immutable swarmBudget;

    struct CoinView {
        address coin;
        string name;
        string symbol;
        BondingCurve.Status status;
        CoinFees fees;
        uint256 totalFeeBps;
        address feeRecipient;
        uint256 creatorFeesUnclaimed;
        uint256 swarmBudgetAvailable;
        uint64 launchedAt;
        uint256 raised; // curve phase: net IMD raised so far
        uint256 target; // graduation target in IMD
        uint256 sold; // curve phase: tokens sold
        uint256 snipeTaxBps;
        uint256 priceE18; // IMD per token, 1e18 scale (curve price, or pool spot after graduation)
        uint160 sqrtPriceX96; // pool spot (graduated only)
        uint128 poolLiquidity; // graduated only
        uint256 dividendsDistributed; // IMD paid to holders so far
    }

    struct Position {
        address coin;
        uint256 balance;
        uint256 pendingDividends;
    }

    constructor(address curve_, address hook_, address creatorVault_, address swarmBudget_) {
        curve = BondingCurve(curve_);
        hook = PadHook(hook_);
        poolManager = curve.poolManager();
        creatorVault = ILensCreatorVault(creatorVault_);
        swarmBudget = ILensSwarmBudget(swarmBudget_);
    }

    // ------------------------------------------------------------------ Lists

    function coinCount() external view returns (uint256) {
        return curve.coinCount();
    }

    /// @notice Up to `limit` coins starting at `offset`, oldest first or newest first.
    function coins(uint256 offset, uint256 limit, bool newestFirst) external view returns (CoinView[] memory out) {
        uint256 n = curve.coinCount();
        if (offset >= n) return out;
        uint256 len = n - offset < limit ? n - offset : limit;
        out = new CoinView[](len);
        for (uint256 i; i < len; i++) {
            uint256 idx = newestFirst ? n - 1 - offset - i : offset + i;
            out[i] = coinView(curve.coinAt(idx));
        }
    }

    // ------------------------------------------------------------------ One coin

    function coinView(address coin) public view returns (CoinView memory v) {
        BondingCurve.Coin memory c = curve.coinInfo(coin);
        v.coin = coin;
        v.status = c.status;
        if (c.status == BondingCurve.Status.None) return v;
        v.name = PadToken(coin).name();
        v.symbol = PadToken(coin).symbol();
        v.fees = c.fees;
        v.totalFeeBps = FeeLib.totalBps(c.fees);
        v.feeRecipient = creatorVault.recipientOf(coin);
        v.creatorFeesUnclaimed = creatorVault.balanceOf(coin);
        v.swarmBudgetAvailable = swarmBudget.available(coin);
        v.launchedAt = c.launchedAt;
        v.target = c.target;
        v.dividendsDistributed = PadToken(coin).totalDividendsDistributed();
        if (c.status == BondingCurve.Status.Graduated) {
            v.raised = c.target;
            v.sold = c.sold;
            (PoolKey memory key, bool imdIs0) = _pool(coin);
            PoolId id = key.toId();
            (v.sqrtPriceX96,,,) = poolManager.getSlot0(id);
            v.poolLiquidity = poolManager.getLiquidity(id);
            v.priceE18 = _priceE18(v.sqrtPriceX96, imdIs0);
        } else {
            v.raised = c.raised;
            v.sold = c.sold;
            v.snipeTaxBps = curve.snipeTaxBps(coin);
            v.priceE18 = curve.priceOf(coin);
        }
    }

    // ------------------------------------------------------------------ Quotes (IMD)

    /// @notice Tokens out for `imdIn` IMD (fees included), on the curve or in the pool.
    function quoteBuy(address coin, uint256 imdIn)
        external
        view
        returns (uint256 tokensOut, uint256 fee, uint256 snipeTax, bool graduated, bool fullFill)
    {
        BondingCurve.Status s = curve.statusOf(coin);
        if (s != BondingCurve.Status.Graduated) {
            (tokensOut, fee, snipeTax) = curve.quoteBuy(coin, imdIn);
            return (tokensOut, fee, snipeTax, false, s == BondingCurve.Status.Trading);
        }
        graduated = true;
        fee = (imdIn * FeeLib.totalBps(curve.feesOf(coin))) / BPS;
        uint256 swapIn = imdIn - fee;
        (PoolKey memory key, bool imdIs0) = _pool(coin);
        uint256 amountIn;
        (amountIn, tokensOut) = _step(key, imdIs0, swapIn);
        fullFill = amountIn == swapIn;
    }

    /// @notice IMD out for selling `tokensIn` (fees included), on the curve or in the pool.
    function quoteSell(address coin, uint256 tokensIn)
        external
        view
        returns (uint256 imdOut, uint256 fee, bool graduated, bool fullFill)
    {
        BondingCurve.Status s = curve.statusOf(coin);
        if (s != BondingCurve.Status.Graduated) {
            (imdOut, fee) = curve.quoteSell(coin, tokensIn);
            return (imdOut, fee, false, s == BondingCurve.Status.Trading);
        }
        graduated = true;
        (PoolKey memory key, bool imdIs0) = _pool(coin);
        (uint256 amountIn, uint256 gross) = _step(key, !imdIs0, tokensIn);
        fee = (gross * FeeLib.totalBps(curve.feesOf(coin))) / BPS;
        imdOut = gross - fee;
        fullFill = amountIn == tokensIn;
    }

    // ------------------------------------------------------------------ Wallets

    /// @notice `wallet`'s balance and unclaimed IMD dividends for each coin in `coinList`.
    function positions(address wallet, address[] calldata coinList) external view returns (Position[] memory out) {
        out = new Position[](coinList.length);
        for (uint256 i; i < coinList.length; i++) {
            PadToken t = PadToken(coinList[i]);
            out[i] = Position(coinList[i], t.balanceOf(wallet), t.withdrawableDividendOf(wallet));
        }
    }

    // ------------------------------------------------------------------ Internals

    function _pool(address coin) internal view returns (PoolKey memory key, bool imdIs0) {
        key = hook.poolKey(coin);
        imdIs0 = hook.marketOf(coin).imdIsCurrency0;
    }

    /// @dev One exact-in swap step across the pool's full-range position, as the PoolManager computes it.
    function _step(PoolKey memory key, bool zeroForOne, uint256 amountIn)
        internal
        view
        returns (uint256 used, uint256 out)
    {
        PoolId id = key.toId();
        (uint160 sqrtP,,,) = poolManager.getSlot0(id);
        uint128 liquidity = poolManager.getLiquidity(id);
        if (liquidity == 0 || amountIn == 0) return (0, 0);
        int24 edge = zeroForOne ? TickMath.minUsableTick(key.tickSpacing) : TickMath.maxUsableTick(key.tickSpacing);
        (, used, out,) =
            SwapMath.computeSwapStep(sqrtP, TickMath.getSqrtPriceAtTick(edge), liquidity, -int256(amountIn), 0);
    }

    /// @dev IMD per token, 1e18 scale, from the pool's sqrt price (token1 per token0, Q96).
    function _priceE18(uint160 sqrtP, bool imdIs0) internal pure returns (uint256) {
        if (sqrtP == 0) return 0;
        // imd = currency0: price = tokens per IMD, so IMD per token = 2^192 / sqrtP^2.
        if (imdIs0) return FullMath.mulDiv(FullMath.mulDiv(1e18, Q96, sqrtP), Q96, sqrtP);
        return FullMath.mulDiv(FullMath.mulDiv(1e18, sqrtP, Q96), sqrtP, Q96);
    }
}
