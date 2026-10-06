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
///         hook's `withdrawRetainedQuote` and ownership transfer are not reachable at all. The only way the
///         position ever leaves a hook is `migrate` (D-40): during the first 12 months, approved by the 7-day
///         timelock and then run by the migrator (the team Safe), everything moves into a new market hook owned
///         by this same controller, at the same price, keeping the old market's guards. No path sends the
///         position or the retained IMD to any wallet.
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
    /// @notice The only account that can run an approved migration (the team Safe). Splitting approval (7-day
    ///         timelock) from execution stops an outsider from choosing the block and price of a migration
    ///         (audit R1-A2-2).
    address public immutable migrator;

    PadMarketHook public hook;
    address public sale;
    address public sinkAdmin;
    bool public launched;
    /// @notice When the market opened (PadSale graduated). Zero before launch. Starts the airdrop and team vesting
    ///         clocks (D-53, D-54); unlike the hook's fee clock it never changes, even after a migration.
    uint256 public openedAt;
    /// @notice Migration is possible only before this time (12 months after the market opened). Zero before launch.
    uint256 public migrationDeadline;
    uint256 public constant MIGRATION_WINDOW = 365 days;
    /// @notice The new hook the 7-day timelock approved for `migrate`; zero when none.
    address public approvedMigration;

    event Launched(uint160 sqrtPriceX96, uint128 liquidity, uint256 imdDeposited, uint256 tokensDeposited);
    event FeesCollected(uint256 imd, uint256 token);
    event SinkAdminUpdated(address sinkAdmin);
    event MigrationApproved(address indexed newHook);
    event Migrated(
        address indexed oldHook, address indexed newHook, uint160 sqrtPriceX96, uint256 imdMoved, uint256 tokensMoved
    );

    error AlreadyLaunched(); // Unauthorized and AlreadyInitialized come from Ownable
    error InvalidSetup();
    error MigrationClosed();

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
        address migrator_,
        uint256 capFloor_,
        uint256 capDecayPerDay_
    ) {
        if (
            owner_ == address(0) || sinkAdmin_ == address(0) || feeSplitter_ == address(0) || burner_ == address(0)
                || migrator_ == address(0)
        ) {
            revert InvalidSetup();
        }
        _initializeOwner(owner_);
        sinkAdmin = sinkAdmin_;
        imd = imd_;
        token = token_;
        feeSplitter = feeSplitter_;
        burner = burner_;
        migrator = migrator_;
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
        openedAt = block.timestamp;
        migrationDeadline = block.timestamp + MIGRATION_WINDOW;

        PadMarketHook h = hook;
        h.initializePool(sqrtPriceX96);
        uint128 liquidity = fullRangeLiquidity(sqrtPriceX96, imdAmount, tokenAmount, h.tickSpacing());
        // What the hook takes is measured around `openMarket`, never from the live balance, which anyone can
        // add to (audit R1-A2-1: a donation larger than the raise made `launch` underflow forever).
        uint256 imdBefore = imd.balanceOf(address(this));
        uint256 tokenBefore = token.balanceOf(address(this));
        h.openMarket(liquidity, tokenAmount, imdAmount, initialCapFloor, initialCapDecayPerDay);
        uint256 imdUsed = imdBefore - imd.balanceOf(address(this));
        uint256 tokenUsed = tokenBefore - token.balanceOf(address(this));

        // Rounding dust and anything sent here before launch: IMD joins the protocol fees, $PONDPAD is burned.
        uint256 imdLeft = imd.balanceOf(address(this));
        if (imdLeft != 0) imd.safeTransfer(feeSplitter, imdLeft);
        uint256 tokenLeft = token.balanceOf(address(this));
        if (tokenLeft != 0) {
            token.safeTransfer(burner, tokenLeft);
            IPadBurner(burner).burn();
        }
        emit Launched(sqrtPriceX96, liquidity, imdUsed, tokenUsed);
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
        _collectFees(hook);
    }

    function _collectFees(PadMarketHook h) internal {
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

    // ------------------------------------------------------------------ Migration (7-day timelock, first 12 months)

    /// @notice The 7-day timelock approves a migration into `newHook_` (zero clears it). Approval moves nothing;
    ///         the migrator (team Safe) runs it with `migrate`.
    function approveMigration(address newHook_) external onlySinkAdmin {
        approvedMigration = newHook_;
        emit MigrationApproved(newHook_);
    }

    /// @notice Moves the whole market into `newHook` (D-40): for fixing a defect or moving to a better version
    ///         while the code is young. Only the migrator (team Safe), only into the hook the 7-day timelock
    ///         approved, only before `migrationDeadline`. `newHook` must be an unopened market for the same
    ///         IMD/$PONDPAD pair, owned by this controller, with the same burn sink and rewards recipient. The old
    ///         market's fees go to the splitter; its position and retained IMD reopen the new market at the old
    ///         market's current price, with the same cap floor, decay and policy, and with the old market's
    ///         backstop placement floor, reference tick and cap (so a price pushed just before the migration
    ///         can't decide where the backstop goes, audit R1-A2-2); IMD that doesn't fit the full-range
    ///         position becomes the new market's backstop IMD. The controller keeps nothing and pays no one.
    function migrate(address newHook_) external {
        if (msg.sender != migrator) revert Unauthorized();
        if (newHook_ == address(0) || newHook_ != approvedMigration) revert InvalidSetup();
        if (!launched || block.timestamp >= migrationDeadline) revert MigrationClosed();
        approvedMigration = address(0);
        PadMarketHook old = hook;
        PadMarketHook nh = PadMarketHook(newHook_);
        if (
            newHook_ == address(old) || nh.owner() != address(this) || nh.quote() != imd || nh.token() != token
                || nh.marketOpen() || nh.burnSink() != old.burnSink() || nh.rewardsRecipient() != old.rewardsRecipient()
        ) revert InvalidSetup();

        uint160 sqrtPriceX96 = old.currentSqrtPriceX96();
        (int24 oldFloor, int24 oldRef, uint256 oldCap) = (old.deploymentFloorTick(), old.refTick(), old.inventoryCap());
        old.closeMarket(address(this)); // settles claims, closes the backstop, returns position + retained IMD
        _collectFees(old); // fees realised by the close go to the splitter, as always

        hook = nh;
        imd.safeApprove(newHook_, type(uint256).max);
        token.safeApprove(newHook_, type(uint256).max);
        uint256 imdBal = imd.balanceOf(address(this));
        uint256 tokenBal = token.balanceOf(address(this));
        nh.initializePool(sqrtPriceX96);
        uint128 liquidity = fullRangeLiquidity(sqrtPriceX96, imdBal, tokenBal, nh.tickSpacing());
        nh.openMarket(liquidity, tokenBal, imdBal, old.capFloor(), old.capDecayTokensPerDay());
        nh.inheritFeeSchedule(old.marketOpenedAt());
        nh.inheritGuards(oldFloor, oldRef, oldCap);
        _copyPolicy(old, nh);

        uint256 imdLeft = imd.balanceOf(address(this));
        if (imdLeft != 0) nh.seedRetainedQuote(imdLeft);
        uint256 tokenLeft = token.balanceOf(address(this));
        if (tokenLeft != 0) {
            token.safeTransfer(burner, tokenLeft);
            IPadBurner(burner).burn();
        }
        emit Migrated(address(old), newHook_, sqrtPriceX96, imdBal, tokenBal - tokenLeft);
    }

    function _copyPolicy(PadMarketHook old, PadMarketHook nh) internal {
        nh.setRatchetBps(old.ratchetBps());
        nh.setRewardShareBps(old.rewardShareBps());
        nh.setMaxRefStep(old.maxRefStep());
        nh.setFloorDecay(old.floorDecayTicksPerDay());
        nh.setKeeperReward(0); // keeper tip must stay below the threshold while both change
        nh.setRebalance(old.rebalanceEnabled(), old.rebalanceQuoteThreshold());
        nh.setKeeperReward(old.keeperReward());
    }

    function setSinkAdmin(address newSinkAdmin) external onlySinkAdmin {
        if (newSinkAdmin == address(0)) revert InvalidSetup();
        sinkAdmin = newSinkAdmin;
        emit SinkAdminUpdated(newSinkAdmin);
    }
}
