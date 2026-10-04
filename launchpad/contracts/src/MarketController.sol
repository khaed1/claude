// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PadMarketHook} from "./PadMarketHook.sol";
import {IPadMarketLauncher} from "./PadSale.sol";

interface IFeeDistributor {
    function distribute() external;
    function distributeToken(address token) external;
}

interface IPadBurner {
    function burn() external returns (uint256);
}

/// @title MarketController
/// @notice The permanent owner of PadMarketHook (the $PONDPAD/IMD market). It narrows the hook's owner powers
///         (D-18): the market is opened exactly once, by PadSale at graduation; trading fees can only go to the
///         fee splitter, and anyone can push them there; policy settings sit behind the timelock; and the
///         hook's `closeMarket`, `withdrawRetainedQuote` and ownership transfer are not reachable at all, so no
///         one can withdraw the locked market position.
/// @dev Roles: `owner` is the 48-hour timelock (policy, extra inventory, backstop close); `sinkAdmin` is the
///      7-day timelock (burn sink and rewards recipient). Neither can move the position or the retained IMD.
contract MarketController is Ownable, IPadMarketLauncher {
    using SafeTransferLib for address;

    address public immutable imd;
    address public immutable token;
    address public immutable feeSplitter;
    address public immutable burner;
    uint256 public immutable initialCapFloor;
    uint256 public immutable initialCapDecayPerDay;
    address internal immutable _deployer;

    PadMarketHook public hook;
    address public sale;
    address public sinkAdmin;
    bool public launched;

    event Launched(uint160 sqrtPriceX96, uint128 liquidity, uint256 imdDeposited, uint256 tokensDeposited);
    event FeesCollected(uint256 imd, uint256 token);
    event SinkAdminUpdated(address sinkAdmin);

    error AlreadyLaunched(); // Unauthorized and AlreadyInitialized come from Ownable
    error InvalidSetup();

    modifier onlySinkAdmin() {
        if (msg.sender != sinkAdmin) revert Unauthorized();
        _;
    }

    constructor(
        address owner_,
        address sinkAdmin_,
        address imd_,
        address token_,
        address feeSplitter_,
        address burner_,
        uint256 capFloor_,
        uint256 capDecayPerDay_
    ) {
        if (owner_ == address(0) || sinkAdmin_ == address(0) || feeSplitter_ == address(0) || burner_ == address(0)) {
            revert InvalidSetup();
        }
        _initializeOwner(owner_);
        sinkAdmin = sinkAdmin_;
        imd = imd_;
        token = token_;
        feeSplitter = feeSplitter_;
        burner = burner_;
        initialCapFloor = capFloor_;
        initialCapDecayPerDay = capDecayPerDay_;
        _deployer = msg.sender;
    }

    /// @notice Connects the hook (deployed with this contract as its owner) and the sale. Deployer, once.
    function initialize(address hook_, address sale_) external {
        if (msg.sender != _deployer) revert Unauthorized();
        if (address(hook) != address(0)) revert AlreadyInitialized();
        PadMarketHook h = PadMarketHook(hook_);
        if (h.owner() != address(this) || h.quote() != imd || h.token() != token || sale_ == address(0)) {
            revert InvalidSetup();
        }
        hook = h;
        sale = sale_;
        imd.safeApprove(hook_, type(uint256).max);
        token.safeApprove(hook_, type(uint256).max);
    }

    // ------------------------------------------------------------------ Launch (PadSale, once)

    /// @inheritdoc IPadMarketLauncher
    function launch(uint160 sqrtPriceX96, uint256 imdAmount, uint256 tokenAmount) external {
        if (msg.sender != sale) revert Unauthorized();
        if (launched) revert AlreadyLaunched();
        launched = true;

        PadMarketHook h = hook;
        h.initializePool(sqrtPriceX96);
        uint128 liquidity = fullRangeLiquidity(sqrtPriceX96, imdAmount, tokenAmount, h.tickSpacing());
        h.openMarket(liquidity, tokenAmount, imdAmount, initialCapFloor, initialCapDecayPerDay);

        // Rounding dust: leftover IMD joins the protocol fees, leftover $PONDPAD is burned.
        uint256 imdLeft = imd.balanceOf(address(this));
        if (imdLeft != 0) imd.safeTransfer(feeSplitter, imdLeft);
        uint256 tokenLeft = token.balanceOf(address(this));
        if (tokenLeft != 0) {
            token.safeTransfer(burner, tokenLeft);
            IPadBurner(burner).burn();
        }
        emit Launched(sqrtPriceX96, liquidity, imdAmount - imdLeft, tokenAmount - tokenLeft);
    }

    /// @notice Full-range liquidity that `imdAmount` IMD (currency0) and `tokenAmount` $PONDPAD (currency1) buy at
    ///         `sqrtPriceX96`, less 1 ppm so v4's round-up never asks for more than was sent.
    function fullRangeLiquidity(uint160 sqrtPriceX96, uint256 imdAmount, uint256 tokenAmount, int24 tickSpacing)
        public
        pure
        returns (uint128)
    {
        uint256 sqrtLower = TickMath.getSqrtPriceAtTick(TickMath.minUsableTick(tickSpacing));
        uint256 sqrtUpper = TickMath.getSqrtPriceAtTick(TickMath.maxUsableTick(tickSpacing));
        uint256 p = sqrtPriceX96;
        if (p <= sqrtLower || p >= sqrtUpper) revert InvalidSetup();
        // amount0 = L · (sqrtU − sqrtP) · 2^96 / (sqrtP · sqrtU);  amount1 = L · (sqrtP − sqrtL) / 2^96
        uint256 l0 = FixedPointMathLib.fullMulDiv(
            imdAmount, FixedPointMathLib.fullMulDiv(p, sqrtUpper, 1 << 96), sqrtUpper - p
        );
        uint256 l1 = FixedPointMathLib.fullMulDiv(tokenAmount, 1 << 96, p - sqrtLower);
        uint256 l = l0 < l1 ? l0 : l1;
        l -= l / 1_000_000 + 1;
        if (l > type(uint128).max) revert InvalidSetup();
        return uint128(l);
    }

    // ------------------------------------------------------------------ Fees (permissionless)

    /// @notice Sends the market's trading fees to the fee splitter and splits them: IMD with the usual 40/25/20/15,
    ///         the $PONDPAD that sellers paid with the same shares in $PONDPAD (D-38). Anyone can call it.
    function collectFees() external {
        PadMarketHook h = hook;
        uint256 imdFee = h.feeQuoteClaims();
        uint256 tokenFee = h.feeTokenClaims();
        h.withdrawFees(feeSplitter);
        IFeeDistributor(feeSplitter).distribute();
        IFeeDistributor(feeSplitter).distributeToken(token);
        emit FeesCollected(imdFee, tokenFee);
    }

    // ------------------------------------------------------------------ Policy (48 h timelock)

    function setCapFloor(uint256 newFloor) external onlyOwner {
        hook.setCapFloor(newFloor);
    }

    function setCapDecay(uint256 tokensPerDay) external onlyOwner {
        hook.setCapDecay(tokensPerDay);
    }

    function setRatchetBps(uint256 bps) external onlyOwner {
        hook.setRatchetBps(bps);
    }

    function setRebalance(bool enabled, uint256 quoteThreshold) external onlyOwner {
        hook.setRebalance(enabled, quoteThreshold);
    }

    function setKeeperReward(uint256 reward) external onlyOwner {
        hook.setKeeperReward(reward);
    }

    function setMaxRefStep(int24 maxStep) external onlyOwner {
        hook.setMaxRefStep(maxStep);
    }

    function setFloorDecay(uint256 ticksPerDay) external onlyOwner {
        hook.setFloorDecay(ticksPerDay);
    }

    /// @notice Share of trims sent to stakers instead of burned; the hook caps it at 30%.
    function setRewardShareBps(uint256 bps) external onlyOwner {
        hook.setRewardShareBps(bps);
    }

    /// @notice Burns what the backstop bought and returns its IMD to the retained balance. Moves nothing out.
    function closeBackstop() external onlyOwner {
        hook.closeBackstop();
    }

    /// @notice Adds inventory (from the liquidity reserve and treasury): pulls up to the maxima from the caller,
    ///         adds it to the market position, raises the cap, and returns what was not used.
    function fundInventory(uint128 liquidity, uint256 maximumTokenAmount, uint256 maximumImdAmount)
        external
        onlyOwner
    {
        token.safeTransferFrom(msg.sender, address(this), maximumTokenAmount);
        imd.safeTransferFrom(msg.sender, address(this), maximumImdAmount);
        hook.fundInventory(liquidity, maximumTokenAmount, maximumImdAmount);
        uint256 tokenLeft = token.balanceOf(address(this));
        if (tokenLeft != 0) token.safeTransfer(msg.sender, tokenLeft);
        uint256 imdLeft = imd.balanceOf(address(this));
        if (imdLeft != 0) imd.safeTransfer(msg.sender, imdLeft);
    }

    // ------------------------------------------------------------------ Sinks (7-day timelock)

    function setBurnSink(address newBurnSink) external onlySinkAdmin {
        hook.setBurnSink(newBurnSink);
    }

    function setRewardsRecipient(address newRewardsRecipient) external onlySinkAdmin {
        hook.setRewardsRecipient(newRewardsRecipient);
    }

    function setSinkAdmin(address newSinkAdmin) external onlySinkAdmin {
        if (newSinkAdmin == address(0)) revert InvalidSetup();
        sinkAdmin = newSinkAdmin;
        emit SinkAdminUpdated(newSinkAdmin);
    }
}
