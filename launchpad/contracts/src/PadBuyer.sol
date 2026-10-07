// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {FixedOwnable} from "./FixedOwnable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {PadMarketHook} from "./PadMarketHook.sol";

interface IMarketControllerView {
    function hook() external view returns (PadMarketHook);
}

/// @title PadBuyer
/// @notice The stakers' bucket of the fee splitter (40%). It turns the IMD it receives into $PONDPAD on the
///         $PONDPAD/IMD market and sends the $PONDPAD to the RewardDripper, which streams it into sPONDPAD. The
///         $PONDPAD it receives directly (the stakers' share of the market's sell-side fees, D-38) is forwarded
///         as is. `buy()` is permissionless and pays its caller a small IMD tip.
/// @dev Buys are small and spaced out: at most `maxChunk` IMD per call, at most one call per `interval`. Each buy
///      is price-guarded against the market hook's block-lagged, rate-limited reference tick (`referenceTick()`:
///      `refTick` caught up to the current block, which the current transaction cannot move; audit R4-A3-3): it
///      refuses to buy when spot is already more than `maxDeviationTicks` above the reference in $PONDPAD's price,
///      and its swap limit stops the fill at reference + deviation + slippage. A sandwich can therefore cost the
///      stakers at most about 2% on one small chunk (defaults).
///      IMD is currency0, so buying $PONDPAD moves the tick down.
contract PadBuyer is FixedOwnable, IUnlockCallback {
    using SafeTransferLib for address;

    address public immutable imd;
    address public immutable token;
    IPoolManager public immutable poolManager;
    IMarketControllerView public immutable controller;
    address public immutable dripper;

    uint256 public maxChunk = 25e18;
    uint256 public minChunk = 1e18;
    uint256 public interval = 10 minutes;
    int24 public maxDeviationTicks = 100; // ~1%
    int24 public maxSlippageTicks = 100; // ~1%
    uint16 public keeperTipBps = 50; // 0.5% of the IMD spent
    uint256 public lastBuyAt;

    uint256 public constant MAX_CHUNK = 500e18;
    int24 public constant MAX_TICKS = 500; // ~5%
    uint16 public constant MAX_TIP_BPS = 100;
    uint256 public constant MIN_INTERVAL = 1 minutes;

    event Bought(uint256 imdSpent, uint256 tokensOut, uint256 tip, address indexed keeper);
    event Forwarded(uint256 tokens);
    event SettingsUpdated(
        uint256 maxChunk, uint256 minChunk, uint256 interval, int24 maxDeviation, int24 maxSlippage, uint16 tipBps
    );

    error TooSoon();
    error NothingToBuy();
    error MarketClosed();
    error PriceOutOfRange();
    error NotPoolManager();
    error InvalidSetting();

    constructor(address owner_, address imd_, address token_, address poolManager_, address controller_, address dripper_) {
        _initializeOwner(owner_);
        imd = imd_;
        token = token_;
        poolManager = IPoolManager(poolManager_);
        controller = IMarketControllerView(controller_);
        dripper = dripper_;
    }

    /// @notice Forwards any $PONDPAD held to the dripper, then buys $PONDPAD with up to `maxChunk` IMD if the
    ///         interval has passed and the price is near its reference. Anyone can call it.
    function buy() external returns (uint256 tokensOut) {
        forward();
        if (block.timestamp < lastBuyAt + interval) revert TooSoon();
        uint256 bal = imd.balanceOf(address(this));
        uint256 chunk = bal < maxChunk ? bal : maxChunk;
        if (chunk < minChunk) revert NothingToBuy();

        PadMarketHook market = controller.hook();
        if (!market.marketOpen()) revert MarketClosed();
        // The reference caught up to this block, not the stored `refTick`, which only moves at the next swap: after a
        // genuine rise and quiet blocks the stored one still sat before the rise and refused every buy (R4-A3-3).
        int24 ref = market.referenceTick();
        int24 spot = market.currentTick();
        // A lower tick = $PONDPAD dearer. Refuse when someone already pushed it up past the guard band.
        if (spot < ref - maxDeviationTicks) revert PriceOutOfRange();
        // Below spot by construction (spot >= ref - maxDeviation), so the swap always has room.
        int24 limitTick = ref - maxDeviationTicks - maxSlippageTicks;
        if (limitTick < TickMath.MIN_TICK) limitTick = TickMath.MIN_TICK;

        lastBuyAt = block.timestamp;
        uint256 tip = (chunk * keeperTipBps) / 10_000;
        uint256 spend = chunk - tip;
        (uint256 spent, uint256 out) = abi.decode(
            poolManager.unlock(abi.encode(market.poolKey(), spend, TickMath.getSqrtPriceAtTick(limitTick))),
            (uint256, uint256)
        );
        tokensOut = out;
        // A partial fill (price limit hit) spends less; the tip shrinks with it, and never exceeds what was
        // reserved for it (audit R1-A3-6: the recomputed tip could round 1 wei above it).
        uint256 reserved = tip;
        tip = (spent * keeperTipBps) / (10_000 - keeperTipBps);
        if (tip > reserved) tip = reserved;
        if (tip != 0) imd.safeTransfer(msg.sender, tip);
        emit Bought(spent, out, tip, msg.sender);
    }

    /// @notice Sends every $PONDPAD this contract holds to the dripper. Anyone can call it.
    function forward() public returns (uint256 amount) {
        amount = token.balanceOf(address(this));
        if (amount != 0) {
            token.safeTransfer(dripper, amount);
            emit Forwarded(amount);
        }
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        (PoolKey memory key, uint256 amountIn, uint160 limit) = abi.decode(data, (PoolKey, uint256, uint160));
        BalanceDelta delta = poolManager.swap(
            key, SwapParams({zeroForOne: true, amountSpecified: -int256(amountIn), sqrtPriceLimitX96: limit}), ""
        );
        uint256 spent = uint256(int256(-delta.amount0()));
        uint256 out = uint256(int256(delta.amount1()));
        if (spent != 0) {
            poolManager.sync(key.currency0);
            imd.safeTransfer(address(poolManager), spent);
            poolManager.settle();
        }
        if (out != 0) poolManager.take(key.currency1, dripper, out);
        return abi.encode(spent, out);
    }

    /// @notice Tunes buying, within hard bounds. Owner: the 48 h timelock; unlike the vault's and the dripper's, this
    ///         power doesn't expire (D-43, audit R4-A3-6). The buyer can only ever send $PONDPAD to the dripper and tips
    ///         to keepers, whatever the settings. `minChunk` is at least 1 wei, so an empty buyer reverts
    ///         `NothingToBuy` (audit R4-A3-7).
    function setSettings(
        uint256 maxChunk_,
        uint256 minChunk_,
        uint256 interval_,
        int24 maxDeviation_,
        int24 maxSlippage_,
        uint16 tipBps_
    ) external onlyOwner {
        if (
            maxChunk_ == 0 || maxChunk_ > MAX_CHUNK || minChunk_ == 0 || minChunk_ > maxChunk_ || interval_ < MIN_INTERVAL
                || maxDeviation_ <= 0 || maxDeviation_ > MAX_TICKS || maxSlippage_ <= 0 || maxSlippage_ > MAX_TICKS
                || tipBps_ > MAX_TIP_BPS
        ) revert InvalidSetting();
        maxChunk = maxChunk_;
        minChunk = minChunk_;
        interval = interval_;
        maxDeviationTicks = maxDeviation_;
        maxSlippageTicks = maxSlippage_;
        keeperTipBps = tipBps_;
        emit SettingsUpdated(maxChunk_, minChunk_, interval_, maxDeviation_, maxSlippage_, tipBps_);
    }
}
