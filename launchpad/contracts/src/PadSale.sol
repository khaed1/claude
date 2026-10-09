// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {TransientStateLibrary} from "v4-core/libraries/TransientStateLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PaymentSwapper} from "./PaymentSwapper.sol";

interface IIntegratorCredit {
    function credit(address integrator, address coin, uint256 amount) external;
}

/// @notice Opens the $PONDPAD/IMD market (MarketController in production).
interface IPadMarketLauncher {
    /// @notice Called once by PadSale at graduation, after it sent `imdAmount` IMD and `tokenAmount` $PONDPAD.
    /// @param sqrtPriceX96 Opening price with IMD as currency0 and $PONDPAD as currency1 (the curve's final price).
    function launch(uint160 sqrtPriceX96, uint256 imdAmount, uint256 tokenAmount) external;
}

/// @title PadSale
/// @notice The one-time $PONDPAD sale: an IMD bonding curve (same constant-product math as coin curves) selling
///         600M $PONDPAD. When it has raised its target, the raised IMD and the 300M reserved $PONDPAD open the
///         $PONDPAD/IMD market at exactly the curve's final price. Buyers pay in IMD, ETH or any payment token
///         approved in PadConfig; sellers can sell back to the curve at any time until it completes.
/// @dev Fees: 1% of every trade (IMD side) to the fee splitter, with the registered integrator's share carved off
///      the top (D-31). Anti-bot (D-35): an 80% snipe tax on buys decaying linearly to 0 over the first 30 minutes
///      (to the growth fund), and a per-wallet cap of 15M $PONDPAD bought for the whole sale. Sells don't free up
///      cap. The curve's real IMD always equals `x - x0`.
contract PadSale is PaymentSwapper, ReentrancyGuard {
    using SafeTransferLib for address;
    using TransientStateLibrary for IPoolManager;

    uint256 public constant CURVE_SUPPLY = 600_000_000e18; // S
    uint256 public constant POOL_SUPPLY = 300_000_000e18; // R
    /// @dev Virtual tokens left on the curve when it completes: S·R/(S−R) = 600M. The curve ends at price E/R.
    uint256 public constant VIRTUAL_TOKENS_AT_END = (CURVE_SUPPLY * POOL_SUPPLY) / (CURVE_SUPPLY - POOL_SUPPLY);
    uint256 public constant FEE_BPS = 100;
    uint256 public constant SNIPE_TAX_START_BPS = 8_000;
    uint256 public constant SNIPE_TAX_DURATION = 30 minutes;
    uint256 public constant MAX_PER_WALLET = 15_000_000e18; // 1.5% of supply
    uint256 public constant MIN_TARGET = 1_000e18;
    uint256 public constant MAX_TARGET = 50_000e18;
    uint256 internal constant BPS = 10_000;

    enum Status {
        Unfunded,
        Trading,
        Full,
        Graduated
    }

    address public immutable token;
    IPadMarketLauncher public immutable market;
    address public immutable integratorVault;
    /// @notice Net IMD the curve raises before it completes (fixed at deploy).
    uint256 public immutable target;
    uint256 public immutable startTime;
    uint256 public immutable x0;
    uint256 public immutable k;

    Status public status;
    uint256 public x; // virtual IMD reserve
    uint256 public y; // virtual token reserve
    uint256 public raised; // real IMD held for the curve (net of fees)
    uint256 public sold; // tokens sold and not sold back
    mapping(address wallet => uint256) public bought;

    event Funded(address indexed from);
    event SaleTrade(
        address indexed trader,
        address indexed referrer,
        bool isBuy,
        uint256 imdAmount,
        uint256 tokenAmount,
        uint256 fee,
        uint256 snipeTax,
        uint256 raised
    );
    event SaleFull();
    event Graduated(uint256 poolImd, uint256 poolTokens, uint160 sqrtPriceX96);

    error InvalidSetup();
    error NotTrading();
    error NotStarted();
    error NotFull();
    error AlreadyFunded();
    error Expired();
    error Slippage();
    error ZeroAmount();
    error MaxPerWalletExceeded();

    constructor(
        address imd_,
        address poolManager_,
        address config_,
        address token_,
        address market_,
        address integratorVault_,
        uint256 target_,
        uint256 startTime_
    ) PaymentSwapper(imd_, poolManager_, config_) {
        // IMD must sort first, so it is currency0 of the $PONDPAD/IMD pool (D-19).
        if (token_ <= imd_ || market_ == address(0) || integratorVault_ == address(0)) revert InvalidSetup();
        if (target_ < MIN_TARGET || target_ > MAX_TARGET) revert InvalidSetup();
        token = token_;
        market = IPadMarketLauncher(market_);
        integratorVault = integratorVault_;
        target = target_;
        startTime = startTime_;
        uint256 y0 = CURVE_SUPPLY + VIRTUAL_TOKENS_AT_END;
        uint256 x0_ = FixedPointMathLib.fullMulDiv(target_, VIRTUAL_TOKENS_AT_END, POOL_SUPPLY) - target_;
        x0 = x0_;
        k = x0_ * y0;
        x = x0_;
        y = y0;
    }

    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert Expired();
        _;
    }

    /// @notice Pulls the 900M $PONDPAD (curve + pool) from the caller and opens the sale. Callable once.
    function fund() external {
        if (status != Status.Unfunded) revert AlreadyFunded();
        status = Status.Trading;
        token.safeTransferFrom(msg.sender, address(this), CURVE_SUPPLY + POOL_SUPPLY);
        emit Funded(msg.sender);
    }

    // ------------------------------------------------------------------ Trading

    /// @notice Buys $PONDPAD paying `amountIn` of `tokenIn` (IMD, ETH or another payment token). If the buy
    ///         completes the curve, the unused part is refunded in IMD and the market opens in the same call.
    /// @param minImd Minimum IMD the payment must convert to (0 for IMD payments). The completing buy gets the same
    ///        tokens whatever IMD arrives and refunds the rest, so `minTokensOut` alone can't bound the payment swap
    ///        there (audit R2-A2-2: a sandwich took the unused payment).
    /// @param referrer Registered integrator that routed the trade (earns its share of the fee), or address(0).
    function buyWith(
        address tokenIn,
        uint256 amountIn,
        uint256 minImd,
        uint256 minTokensOut,
        uint256 deadline,
        address referrer
    ) external payable nonReentrant checkDeadline(deadline) returns (uint256 out) {
        if (status != Status.Trading) revert NotTrading();
        if (block.timestamp < startTime) revert NotStarted();
        uint256 imdIn = _collectImd(tokenIn, amountIn, address(this), referrer);
        if (imdIn < minImd) revert Slippage();
        out = _buy(imdIn, minTokensOut, msg.sender, referrer);
    }

    /// @notice Sells `tokensIn` $PONDPAD back to the curve and pays out in `tokenOut`.
    function sellFor(address tokenOut, uint256 tokensIn, uint256 minOut, uint256 deadline, address referrer)
        external
        nonReentrant
        checkDeadline(deadline)
        returns (uint256 out)
    {
        out = _sellFor(tokenOut, tokensIn, minOut, referrer);
    }

    /// @notice Sell with an EIP-2612 permit. A permit that was already used is ignored if the allowance is in place.
    function sellForWithPermit(
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
        try ERC20(token).permit(msg.sender, address(this), permitValue, deadline, v, r, s) {} catch {}
        out = _sellFor(tokenOut, tokensIn, minOut, referrer);
    }

    /// @notice Opens the market if the completing buy could not (the PoolManager was unlocked by an outside
    ///         caller). Anyone can call it.
    function graduate() external nonReentrant {
        if (status != Status.Full) revert NotFull();
        _graduate();
    }

    function _buy(uint256 gross, uint256 minOut, address buyer, address referrer) internal returns (uint256 out) {
        if (gross == 0) revert ZeroAmount();
        uint256 snipeBps = snipeTaxBps();
        uint256 net = gross - (gross * FEE_BPS) / BPS - (gross * snipeBps) / BPS;

        uint256 remaining = CURVE_SUPPLY - sold;
        uint256 refund;
        out = y - FixedPointMathLib.divUp(k, x + net);
        if (out >= remaining) {
            // Completing buy: take only what the last tokens cost and refund the rest.
            out = remaining;
            uint256 netNeeded = FixedPointMathLib.divUp(k, y - remaining) - x;
            uint256 grossNeeded = FixedPointMathLib.divUp(netNeeded * BPS, BPS - FEE_BPS - snipeBps);
            if (grossNeeded < gross) {
                refund = gross - grossNeeded;
                gross = grossNeeded;
            }
            net = gross - (gross * FEE_BPS) / BPS - (gross * snipeBps) / BPS;
        }
        if (out == 0) revert ZeroAmount();
        if (out < minOut) revert Slippage();

        uint256 total = bought[buyer] + out;
        if (total > MAX_PER_WALLET) revert MaxPerWalletExceeded();
        bought[buyer] = total;

        x += net;
        y -= out;
        raised += net;
        sold += out;

        uint256 fee = (gross * FEE_BPS) / BPS;
        uint256 snipe = gross - net - fee;
        _routeFee(fee, referrer);
        if (snipe != 0) imd.safeTransfer(config.growthFund(), snipe);
        if (refund != 0) imd.safeTransfer(buyer, refund);
        token.safeTransfer(buyer, out);
        emit SaleTrade(buyer, referrer, true, gross, out, fee, snipe, raised);

        if (sold == CURVE_SUPPLY) {
            status = Status.Full;
            emit SaleFull();
            // Open the market inline unless an outside caller holds the PoolManager unlock; then anyone can.
            if (!poolManager.isUnlocked()) _graduate();
        }
    }

    function _sellFor(address tokenOut, uint256 tokensIn, uint256 minOut, address referrer)
        internal
        returns (uint256 out)
    {
        if (status != Status.Trading) revert NotTrading();
        if (tokensIn == 0) revert ZeroAmount();
        token.safeTransferFrom(msg.sender, address(this), tokensIn);

        uint256 gross = x - FixedPointMathLib.divUp(k, y + tokensIn);
        uint256 fee = (gross * FEE_BPS) / BPS;
        uint256 imdOut = gross - fee;
        if (imdOut == 0) revert ZeroAmount();

        x -= gross;
        y += tokensIn;
        raised -= gross;
        sold -= tokensIn;

        _routeFee(fee, referrer);
        emit SaleTrade(msg.sender, referrer, false, gross, tokensIn, fee, 0, raised);
        out = _payOut(tokenOut, imdOut, msg.sender, referrer);
        if (out < minOut) revert Slippage();
    }

    function _graduate() internal {
        status = Status.Graduated;
        uint256 poolImd = raised;
        raised = 0;
        uint160 sqrtPriceX96 = openingSqrtPriceX96(poolImd);
        imd.safeTransfer(address(market), poolImd);
        // Anything sent here outside buyWith / fund (audit R2-A2-4) goes to the market too, which sends leftover
        // IMD to the fee splitter and burns leftover $PONDPAD, as it does with its own dust (R1-A2-1).
        uint256 imdLeft = imd.balanceOf(address(this));
        if (imdLeft != 0) imd.safeTransfer(address(market), imdLeft);
        token.safeTransfer(address(market), token.balanceOf(address(this)));
        market.launch(sqrtPriceX96, poolImd, POOL_SUPPLY);
        emit Graduated(poolImd, POOL_SUPPLY, sqrtPriceX96);
    }

    function _routeFee(uint256 fee, address referrer) internal {
        if (fee == 0) return;
        uint256 cut = (fee * config.integratorShareFor(referrer)) / BPS;
        if (cut != 0) {
            imd.safeTransfer(integratorVault, cut);
            IIntegratorCredit(integratorVault).credit(referrer, token, cut);
        }
        imd.safeTransfer(config.feeSplitter(), fee - cut);
    }

    // ------------------------------------------------------------------ Views

    /// @notice Current snipe tax in bps on buys (linear decay from the sale start).
    function snipeTaxBps() public view returns (uint256) {
        if (block.timestamp < startTime) return SNIPE_TAX_START_BPS;
        uint256 elapsed = block.timestamp - startTime;
        if (elapsed >= SNIPE_TAX_DURATION) return 0;
        return (SNIPE_TAX_START_BPS * (SNIPE_TAX_DURATION - elapsed)) / SNIPE_TAX_DURATION;
    }

    /// @notice Current price in IMD per $PONDPAD, scaled by 1e18.
    function price() external view returns (uint256) {
        return FixedPointMathLib.fullMulDiv(x, 1e18, y);
    }

    /// @notice v4 sqrt price (IMD = currency0, $PONDPAD = currency1) for a pool of `poolImd` IMD and POOL_SUPPLY.
    function openingSqrtPriceX96(uint256 poolImd) public pure returns (uint160) {
        uint256 sqrtPrice = FixedPointMathLib.sqrt(FixedPointMathLib.fullMulDiv(POOL_SUPPLY, 1 << 192, poolImd));
        if (sqrtPrice < TickMath.MIN_SQRT_PRICE || sqrtPrice >= TickMath.MAX_SQRT_PRICE) revert InvalidSetup();
        return uint160(sqrtPrice);
    }

    /// @notice Tokens out, fee and snipe tax for a buy of `grossIn` IMD right now (before the wallet cap). For a buy
    ///         that completes the curve, fee and snipe tax are on the IMD it needs, as `buyWith` charges them; the
    ///         rest is refunded (audit R2-A2-3, as R1-A1-4 for coin curves).
    function quoteBuy(uint256 grossIn) external view returns (uint256 out, uint256 fee, uint256 snipe) {
        if (status != Status.Trading) return (0, 0, 0);
        uint256 snipeBps = snipeTaxBps();
        uint256 gross = grossIn;
        out = y - FixedPointMathLib.divUp(k, x + gross - (gross * FEE_BPS) / BPS - (gross * snipeBps) / BPS);
        uint256 remaining = CURVE_SUPPLY - sold;
        if (out >= remaining) {
            out = remaining;
            uint256 netNeeded = FixedPointMathLib.divUp(k, y - remaining) - x;
            uint256 grossNeeded = FixedPointMathLib.divUp(netNeeded * BPS, BPS - FEE_BPS - snipeBps);
            if (grossNeeded < gross) gross = grossNeeded;
        }
        fee = (gross * FEE_BPS) / BPS;
        snipe = (gross * snipeBps) / BPS;
    }

    /// @notice IMD out and fee for selling `tokensIn` right now.
    function quoteSell(uint256 tokensIn) external view returns (uint256 out, uint256 fee) {
        if (status != Status.Trading) return (0, 0);
        uint256 gross = x - FixedPointMathLib.divUp(k, y + tokensIn);
        fee = (gross * FEE_BPS) / BPS;
        out = gross - fee;
    }

    /// @notice $PONDPAD a wallet can still buy under the per-wallet cap.
    function remainingAllowance(address wallet) external view returns (uint256) {
        uint256 b = bought[wallet];
        return b >= MAX_PER_WALLET ? 0 : MAX_PER_WALLET - b;
    }
}
