// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {TransientStateLibrary} from "v4-core/libraries/TransientStateLibrary.sol";
import {PadConfig} from "./PadConfig.sol";
import {PadToken} from "./PadToken.sol";
import {CoinFees, FeeParts, FeeLib} from "./FeeLib.sol";

interface IFeeSink {
    function credit(address coin, uint256 amount) external;
}

interface IIntegratorSink {
    function credit(address integrator, address coin, uint256 amount) external;
}

interface ICreatorRegistry {
    function register(address coin, address recipient) external;
}

interface IPadHookGraduation {
    function graduate(address coin, uint256 imdAmount, uint256 tokenAmount, CoinFees calldata fees) external;
}

/// @title BondingCurve
/// @notice The pre-graduation market for every PondPad coin. Each coin trades against IMD on a constant-product
///         curve with virtual reserves. 800M tokens are sold on the curve; the remaining 200M seed the coin's
///         Uniswap v4 pool at graduation, at exactly the curve's final price.
/// @dev Only PadRouter may trade, so the snipe tax and the early max-buy apply cleanly. Selling is never
///      restricted while the coin is on the curve. The curve's real IMD for a coin always equals `x - x0`.
contract BondingCurve is ReentrancyGuard {
    using SafeTransferLib for address;
    using TransientStateLibrary for IPoolManager;

    uint256 public constant TOTAL_SUPPLY = 1_000_000_000e18;
    uint256 public constant CURVE_SUPPLY = 800_000_000e18; // S
    uint256 public constant POOL_SUPPLY = 200_000_000e18; // R
    /// @dev Virtual tokens left on the curve when it completes: S·R/(S−R). Chosen so the curve ends at price E/R.
    uint256 public constant VIRTUAL_TOKENS_AT_END = (CURVE_SUPPLY * POOL_SUPPLY) / (CURVE_SUPPLY - POOL_SUPPLY);
    uint256 internal constant BPS = 10_000;
    /// @dev `PadToken.MIN_ELIGIBLE`: below it a coin can't distribute dividends (audit R2-A1-3).
    uint256 internal constant MIN_ELIGIBLE_HOLDERS = 1e18;

    enum Status {
        None,
        Trading,
        Full,
        Graduated
    }

    struct Coin {
        uint128 x; // virtual IMD reserve
        uint128 y; // virtual token reserve
        uint256 k;
        uint128 raised; // real IMD held for this coin (net of fees)
        uint128 sold; // tokens sold and not sold back
        uint64 launchedAt;
        Status status;
        uint96 target;
        uint16 graduationFeeBps;
        uint16 snipeTaxStartBps;
        uint32 snipeTaxDuration;
        uint32 maxBuyWindow;
        uint128 maxBuyTokens;
        CoinFees fees;
    }

    address public immutable imd;
    PadConfig public immutable config;
    IPoolManager public immutable poolManager;
    address internal immutable _deployer;

    address public factory;
    address public router;
    address public hook;
    address public creatorVault;
    address public swarmBudget;
    address public integratorVault;

    mapping(address coin => Coin) internal _coins;
    mapping(address coin => mapping(address wallet => uint256)) public boughtInWindow;
    /// @dev Every coin launched on this curve, in launch order (for PadLens pagination).
    address[] internal _allCoins;

    event CurveTrade(
        address indexed coin,
        address indexed trader,
        bool isBuy,
        uint256 imdAmount,
        uint256 tokenAmount,
        uint256 fee,
        uint256 snipeTax,
        uint256 raised
    );
    event CurveFull(address indexed coin);
    event Graduated(address indexed coin, uint256 poolImd, uint256 poolTokens, uint256 graduationFee);

    error Unauthorized();
    error AlreadyInitialized();
    error NotTrading();
    error NotFull();
    error Slippage();
    error ZeroAmount();
    error MaxBuyExceeded();
    error LaunchesPaused();
    error UnknownCoin();
    error PoolManagerUnlocked();

    constructor(address imd_, address config_, address poolManager_) {
        imd = imd_;
        config = PadConfig(config_);
        poolManager = IPoolManager(poolManager_);
        _deployer = msg.sender;
    }

    function initialize(
        address factory_,
        address router_,
        address hook_,
        address creatorVault_,
        address swarmBudget_,
        address integratorVault_
    ) external {
        if (msg.sender != _deployer) revert Unauthorized();
        if (factory != address(0)) revert AlreadyInitialized();
        factory = factory_;
        router = router_;
        hook = hook_;
        creatorVault = creatorVault_;
        swarmBudget = swarmBudget_;
        integratorVault = integratorVault_;
    }

    // ------------------------------------------------------------------ Launch

    /// @notice Registers a freshly deployed coin and opens its curve. Called by PadFactory.
    function register(address coin, address feeRecipient, CoinFees calldata fees) external {
        if (msg.sender != factory) revert Unauthorized();
        if (config.launchesPaused()) revert LaunchesPaused();
        FeeLib.validate(fees);
        PadConfig.LaunchSettings memory s = config.launchSettings();

        uint256 target = s.graduationTarget;
        uint256 y0 = CURVE_SUPPLY + VIRTUAL_TOKENS_AT_END;
        uint256 x0 = FixedPointMathLib.fullMulDiv(target, VIRTUAL_TOKENS_AT_END, POOL_SUPPLY) - target;

        Coin storage c = _coins[coin];
        c.x = uint128(x0);
        c.y = uint128(y0);
        c.k = x0 * y0;
        c.launchedAt = uint64(block.timestamp);
        c.status = Status.Trading;
        c.target = uint96(target);
        c.graduationFeeBps = s.graduationFeeBps;
        c.snipeTaxStartBps = s.snipeTaxStartBps;
        c.snipeTaxDuration = s.snipeTaxDuration;
        c.maxBuyWindow = s.maxBuyWindow;
        c.maxBuyTokens = uint128((TOTAL_SUPPLY * s.maxBuyBps) / BPS);
        c.fees = fees;
        _allCoins.push(coin);

        ICreatorRegistry(creatorVault).register(coin, feeRecipient);
    }

    // ------------------------------------------------------------------ Trading

    /// @notice Buys `coin` with `grossIn` IMD that the router has already sent here.
    /// @param exempt True only for the creator's dev buy in the launch transaction (no snipe tax, no max-buy).
    /// @param referrer Integrator that routed the trade; earns its share of the protocol fee if registered.
    /// @return out Tokens sent to `recipient`.
    /// @return refund IMD returned to `refundTo` when the buy completes the curve.
    function buy(
        address coin,
        uint256 grossIn,
        uint256 minOut,
        address recipient,
        address refundTo,
        bool exempt,
        address referrer
    )
        external
        nonReentrant
        returns (uint256 out, uint256 refund)
    {
        if (msg.sender != router) revert Unauthorized();
        _checkLocked();
        if (grossIn == 0) revert ZeroAmount();
        Coin storage c = _coins[coin];
        if (c.status != Status.Trading) revert NotTrading();

        uint256 feeBps = FeeLib.totalBps(c.fees);
        uint256 snipeBps = exempt ? 0 : snipeTaxBps(coin);
        uint256 gross = grossIn;
        uint256 net = gross - (gross * feeBps) / BPS - (gross * snipeBps) / BPS;

        uint256 remaining = CURVE_SUPPLY - c.sold;
        out = c.y - FixedPointMathLib.divUp(c.k, c.x + net);
        if (out >= remaining) {
            // Completing buy: take only what the last tokens cost and refund the rest.
            out = remaining;
            uint256 netNeeded = FixedPointMathLib.divUp(c.k, c.y - remaining) - c.x;
            uint256 grossNeeded = FixedPointMathLib.divUp(netNeeded * BPS, BPS - feeBps - snipeBps);
            if (grossNeeded < gross) {
                refund = gross - grossNeeded;
                gross = grossNeeded;
            }
            net = gross - (gross * feeBps) / BPS - (gross * snipeBps) / BPS;
        }
        if (out == 0) revert ZeroAmount();
        if (out < minOut) revert Slippage();

        if (!exempt && block.timestamp < uint256(c.launchedAt) + c.maxBuyWindow) {
            uint256 bought = boughtInWindow[coin][recipient] + out;
            if (bought > c.maxBuyTokens) revert MaxBuyExceeded();
            boughtInWindow[coin][recipient] = bought;
        }

        c.x += uint128(net);
        c.y -= uint128(out);
        c.raised += uint128(net);
        c.sold += uint128(out);

        uint256 fee = (gross * feeBps) / BPS;
        uint256 snipe = gross - net - fee;
        // Holders are credited before the buyer receives tokens, and the holder tax goes to growth when the buyer
        // already holds all of the eligible supply (audit R3-A1-1), so a buyer never earns from their own buy
        // beyond its pro-rata share of a balance it already held (accepted, R1-A1-3).
        _routeFees(coin, c.fees, fee, referrer, recipient);
        if (snipe != 0) imd.safeTransfer(config.growthFund(), snipe);
        if (refund != 0) imd.safeTransfer(refundTo, refund);
        coin.safeTransfer(recipient, out);

        emit CurveTrade(coin, recipient, true, gross, out, fee, snipe, c.raised);

        if (c.sold == CURVE_SUPPLY) {
            c.status = Status.Full;
            emit CurveFull(coin);
            // Curve trades never run inside a PoolManager unlock (`_checkLocked`), so the pool opens inline.
            // `graduate` stays as a safety valve for a coin left Full.
            _graduate(coin, c);
        }
    }

    /// @notice Sells `tokensIn` of `coin` that the router has already sent here.
    /// @param trader The seller (the router's caller), left out when checking who else would receive the holder tax.
    function sell(address coin, uint256 tokensIn, uint256 minOut, address recipient, address trader, address referrer)
        external
        nonReentrant
        returns (uint256 out)
    {
        if (msg.sender != router) revert Unauthorized();
        _checkLocked();
        if (tokensIn == 0) revert ZeroAmount();
        Coin storage c = _coins[coin];
        if (c.status != Status.Trading) revert NotTrading();

        uint256 gross = c.x - FixedPointMathLib.divUp(c.k, c.y + tokensIn);
        uint256 fee = (gross * FeeLib.totalBps(c.fees)) / BPS;
        out = gross - fee;
        if (out == 0) revert ZeroAmount();
        if (out < minOut) revert Slippage();

        c.x -= uint128(gross);
        c.y += uint128(tokensIn);
        c.raised -= uint128(gross);
        c.sold -= uint128(tokensIn);

        // The seller's tokens already left their wallet, so they don't share in their own sell's holder fee beyond
        // what they still hold; with nobody else eligible it goes to growth (audit R3-A1-1).
        _routeFees(coin, c.fees, fee, referrer, trader);
        imd.safeTransfer(recipient, out);
        emit CurveTrade(coin, trader, false, gross, tokensIn, fee, 0, c.raised); // the seller, not the payout (R4-A1-2)
    }

    /// @dev Curve trades revert while anyone holds the PoolManager unlock (audit R1-A1-1). PadToken skips dividend
    ///      distribution inside an outside unlock, so a wrapped buy would get its tokens before its own holder tax
    ///      was credited, and later share in it. The router's own payment swaps finish their unlock before the
    ///      curve is called, so no PondPad path trades the curve while unlocked.
    function _checkLocked() internal view {
        if (poolManager.isUnlocked()) revert PoolManagerUnlocked();
    }

    /// @notice Finishes a graduation that could not run inside the completing buy. Anyone can call it.
    function graduate(address coin) external nonReentrant {
        Coin storage c = _coins[coin];
        if (c.status != Status.Full) revert NotFull();
        _graduate(coin, c);
    }

    function _graduate(address coin, Coin storage c) internal {
        c.status = Status.Graduated;
        uint256 raised = c.raised;
        c.raised = 0;
        uint256 graduationFee = (raised * c.graduationFeeBps) / BPS;
        uint256 poolImd = raised - graduationFee;
        uint256 poolTokens = (POOL_SUPPLY * (BPS - c.graduationFeeBps)) / BPS;

        if (graduationFee != 0) imd.safeTransfer(config.growthFund(), graduationFee);
        // Burn the reserved tokens matching the graduation fee, so the pool opens at the curve's final price.
        if (POOL_SUPPLY > poolTokens) PadToken(coin).burn(POOL_SUPPLY - poolTokens);
        coin.safeTransfer(hook, poolTokens);
        imd.safeTransfer(hook, poolImd);
        IPadHookGraduation(hook).graduate(coin, poolImd, poolTokens, c.fees);
        emit Graduated(coin, poolImd, poolTokens, graduationFee);
    }

    function _routeFees(address coin, CoinFees memory fees, uint256 fee, address referrer, address trader)
        internal
    {
        if (fee == 0) return;
        FeeParts memory p = FeeLib.split(fees, fee);
        uint256 integratorCut = (p.protocol * config.integratorShareFor(referrer)) / BPS;
        if (integratorCut != 0) {
            p.protocol -= integratorCut;
            imd.safeTransfer(integratorVault, integratorCut);
            IIntegratorSink(integratorVault).credit(referrer, coin, integratorCut);
        }
        if (p.protocol != 0) imd.safeTransfer(config.feeSplitter(), p.protocol);
        if (p.creator != 0) {
            imd.safeTransfer(creatorVault, p.creator);
            IFeeSink(creatorVault).credit(coin, p.creator);
        }
        if (p.swarm != 0) {
            imd.safeTransfer(swarmBudget, p.swarm);
            IFeeSink(swarmBudget).credit(coin, p.swarm);
        }
        if (p.holders != 0) {
            // Nobody eligible apart from the trader (the coin's first buy, or a sole holder trading again): the
            // holder tax would be credited back to the trader (audits R2-A1-3, R3-A1-1), so it goes to growth.
            if (PadToken(coin).eligibleSupplyExcept(trader) < MIN_ELIGIBLE_HOLDERS) {
                imd.safeTransfer(config.growthFund(), p.holders);
            } else {
                imd.safeTransfer(coin, p.holders);
                PadToken(coin).distribute();
            }
        }
    }

    // ------------------------------------------------------------------ Views

    function coinInfo(address coin) external view returns (Coin memory) {
        return _coins[coin];
    }

    function coinLaunchedAt(address coin) external view returns (uint64) {
        return _coins[coin].launchedAt;
    }

    function coinCount() external view returns (uint256) {
        return _allCoins.length;
    }

    function coinAt(uint256 index) external view returns (address) {
        return _allCoins[index];
    }

    function statusOf(address coin) external view returns (Status) {
        return _coins[coin].status;
    }

    function feesOf(address coin) external view returns (CoinFees memory) {
        return _coins[coin].fees;
    }

    /// @notice Current snipe tax in bps for buys of `coin` (linear decay from launch).
    function snipeTaxBps(address coin) public view returns (uint256) {
        Coin storage c = _coins[coin];
        uint256 elapsed = block.timestamp - c.launchedAt;
        if (elapsed >= c.snipeTaxDuration) return 0;
        return (uint256(c.snipeTaxStartBps) * (c.snipeTaxDuration - elapsed)) / c.snipeTaxDuration;
    }

    /// @notice Current price in IMD per token, scaled by 1e18.
    function priceOf(address coin) external view returns (uint256) {
        Coin storage c = _coins[coin];
        return FixedPointMathLib.fullMulDiv(c.x, 1e18, c.y);
    }

    /// @notice Tokens out, fee and snipe tax for a buy of `grossIn` IMD, exactly as `buy` charges them. A buy that
    ///         completes the curve is charged on the IMD it needs (audit R1-A1-4); the rest is refunded.
    function quoteBuy(address coin, uint256 grossIn) external view returns (uint256 out, uint256 fee, uint256 snipe) {
        Coin storage c = _coins[coin];
        if (c.status != Status.Trading) return (0, 0, 0);
        uint256 feeBps = FeeLib.totalBps(c.fees);
        uint256 snipeBps = snipeTaxBps(coin);
        uint256 gross = grossIn;
        uint256 net = gross - (gross * feeBps) / BPS - (gross * snipeBps) / BPS;
        out = c.y - FixedPointMathLib.divUp(c.k, c.x + net);
        uint256 remaining = CURVE_SUPPLY - c.sold;
        if (out >= remaining) {
            out = remaining;
            uint256 netNeeded = FixedPointMathLib.divUp(c.k, c.y - remaining) - c.x;
            uint256 grossNeeded = FixedPointMathLib.divUp(netNeeded * BPS, BPS - feeBps - snipeBps);
            if (grossNeeded < gross) gross = grossNeeded;
            net = gross - (gross * feeBps) / BPS - (gross * snipeBps) / BPS;
        }
        fee = (gross * feeBps) / BPS;
        snipe = gross - net - fee;
    }

    function quoteSell(address coin, uint256 tokensIn) external view returns (uint256 out, uint256 fee) {
        Coin storage c = _coins[coin];
        if (c.status != Status.Trading) return (0, 0);
        uint256 gross = c.x - FixedPointMathLib.divUp(c.k, c.y + tokensIn);
        fee = (gross * FeeLib.totalBps(c.fees)) / BPS;
        out = gross - fee;
    }
}
