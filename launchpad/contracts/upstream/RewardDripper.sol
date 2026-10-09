// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

interface IERC20Min {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

/// @notice Smooths the market's lumpy 10% reward share into a bounded stream for the staking vault.
///
/// @dev The `CappedBurnHook` accrues its reward share and, on the permissionless `settleClaims()`,
/// pushes the WHOLE accumulated buffer to its (immutable) `rewardsRecipient` in one shot. Point that
/// `rewardsRecipient` at this contract and the lump lands here instead of the vault. This contract
/// then releases IMD to the vault at a bounded rate, so the vault's share price only ever steps up in
/// small increments — leaving nothing large enough for a just-in-time staker to farm.
///
/// The guarantee: a single `drip()` transfers at most `dripRatePerSecond * maxCatchupSeconds` (the
/// per-call lump ceiling), and the sustained throughput never exceeds `dripRatePerSecond` (the rate
/// ceiling). Idle time beyond `maxCatchupSeconds` is forfeited, not banked — so a long gap followed by
/// one `drip()` can NEVER dump the accumulated buffer at once; a large buffer only drains through many
/// small drips across many blocks. Size the knobs so `dripRatePerSecond * maxCatchupSeconds` stays
/// under ~0.1–0.5% of vault TVL.
///
/// `drip()` is permissionless and pays its caller `keeperReward` IMD (out of the released amount) so a
/// keeper/bot is compensated for gas. To keep that fee a tiny fraction of each drip, `drip()` only
/// fires once at least `minDripAmount` is releasable (`keeperReward <= minDripAmount` is enforced, so
/// the keeper can never take more than the drip). Both are owner-tunable. The owner also tunes the
/// rate/target and can rescue the buffer; renouncing (blocked if it would freeze the stream) leaves an
/// autonomous, immutable stream.
contract RewardDripper is Ownable {
    using SafeTransferLib for address;

    /// @notice The reward asset that is streamed to the vault (IMD).
    address public immutable imd;

    /// @notice The staking vault that receives the stream. A plain transfer raises its `totalAssets`.
    address public vault;
    /// @notice Sustained ceiling on throughput to the vault, in IMD wei per second.
    uint256 public dripRatePerSecond;
    /// @notice Cap on the elapsed time a single `drip()` may account for — bounds the per-call lump.
    uint256 public maxCatchupSeconds;
    /// @notice Timestamp the release clock was last advanced.
    uint256 public lastDripAt;
    /// @notice IMD paid to whoever calls `drip()`, taken out of the released amount (gas compensation).
    uint256 public keeperReward;
    /// @notice `drip()` only fires once at least this much is releasable — keeps `keeperReward` a small
    /// fraction of each drip and stops keepers spamming dust drips to farm the fee.
    uint256 public minDripAmount;

    /// @dev Bounds keep `elapsed * dripRatePerSecond` far below 2^256, so `drip()` can never
    /// overflow-revert (a self-inflicted DoS) no matter how the knobs are set.
    uint256 internal constant MAX_CATCHUP = 30 days;
    uint256 internal constant MAX_RATE = type(uint128).max;
    /// @dev The keeper reward may be at most `minDripAmount / KEEPER_REWARD_DIVISOR` (≤ 1% of a drip),
    /// so the vault always receives the dominant share — even at the smallest drip. Equality of the two
    /// knobs (which would let a keeper take a whole drip) is thereby impossible.
    uint256 internal constant KEEPER_REWARD_DIVISOR = 100;

    event Dripped(uint256 toVault, uint256 keeperReward, address indexed keeper);
    event VaultSet(address indexed vault);
    event DripRateSet(uint256 dripRatePerSecond);
    event MaxCatchupSet(uint256 maxCatchupSeconds);
    event KeeperRewardSet(uint256 keeperReward);
    event MinDripAmountSet(uint256 minDripAmount);
    event EmergencyRescue(address indexed token, address indexed to, uint256 amount);

    error ZeroAddress();
    error RateTooHigh();
    error CatchupTooHigh();
    error KeeperRewardExceedsMin();
    error BelowMinDrip();
    error RenounceWouldFreeze();
    error VaultEmpty();

    constructor(
        address imd_,
        address vault_,
        address owner_,
        uint256 dripRatePerSecond_,
        uint256 maxCatchupSeconds_,
        uint256 keeperReward_,
        uint256 minDripAmount_
    ) {
        if (imd_ == address(0) || vault_ == address(0) || owner_ == address(0)) revert ZeroAddress();
        if (dripRatePerSecond_ > MAX_RATE) revert RateTooHigh();
        if (maxCatchupSeconds_ == 0 || maxCatchupSeconds_ > MAX_CATCHUP) revert CatchupTooHigh();
        if (keeperReward_ > minDripAmount_ / KEEPER_REWARD_DIVISOR) revert KeeperRewardExceedsMin();
        imd = imd_;
        vault = vault_;
        dripRatePerSecond = dripRatePerSecond_;
        maxCatchupSeconds = maxCatchupSeconds_;
        keeperReward = keeperReward_;
        minDripAmount = minDripAmount_;
        lastDripAt = block.timestamp;
        _initializeOwner(owner_);
    }

    // ─────────────────────────────── Stream ───────────────────────────────

    /// @notice IMD releasable right now: `min(rate * min(elapsed, maxCatchup), balance)`. This is the
    /// total that leaves the dripper on the next `drip()` (vault share + keeper reward combined).
    function drippable() public view returns (uint256) {
        uint256 elapsed = block.timestamp - lastDripAt;
        uint256 cap = maxCatchupSeconds;
        if (elapsed > cap) elapsed = cap;
        uint256 allowed = elapsed * dripRatePerSecond;
        uint256 bal = IERC20Min(imd).balanceOf(address(this));
        return allowed < bal ? allowed : bal;
    }

    /// @notice Whether `drip()` would succeed right now (releasable has reached `minDripAmount` and the
    /// vault has stakers to receive it).
    function canDrip() external view returns (bool) {
        return drippable() >= minDripAmount && IERC20Min(vault).totalSupply() != 0;
    }

    /// @notice Permissionless: push the releasable IMD to the vault, pay the caller `keeperReward`, and
    /// advance the clock. Reverts until at least `minDripAmount` is releasable.
    /// @dev The clock resets to `now` even when the balance capped the release, so unused idle time is
    /// forfeited rather than banked into a future burst. `keeperReward <= minDripAmount <= amount`, so
    /// the vault share can't underflow.
    /// @dev Never streams into a vault with no shares: assets that land in an empty ERC-4626 are captured
    /// by its virtual shares (nobody can redeem them) and leave the first real depositor with a tiny share
    /// count, so a slice of every later drip keeps leaking to those virtual shares. A 15-day mainnet-fork
    /// replay stranded 14% of the rewards this way. Rewards wait here until someone stakes.
    function drip() external returns (uint256 toVault, uint256 paidKeeper) {
        if (IERC20Min(vault).totalSupply() == 0) revert VaultEmpty();
        uint256 amount = drippable();
        if (amount < minDripAmount) revert BelowMinDrip();
        lastDripAt = block.timestamp;

        paidKeeper = keeperReward;
        toVault = amount - paidKeeper;
        if (toVault != 0) imd.safeTransfer(vault, toVault);
        if (paidKeeper != 0) imd.safeTransfer(msg.sender, paidKeeper);
        emit Dripped(toVault, paidKeeper, msg.sender);
    }

    // ─────────────────────────────── Owner config ───────────────────────────────

    function setVault(address vault_) external onlyOwner {
        if (vault_ == address(0)) revert ZeroAddress();
        vault = vault_;
        emit VaultSet(vault_);
    }

    function setDripRate(uint256 dripRatePerSecond_) external onlyOwner {
        if (dripRatePerSecond_ > MAX_RATE) revert RateTooHigh();
        dripRatePerSecond = dripRatePerSecond_;
        emit DripRateSet(dripRatePerSecond_);
    }

    function setMaxCatchup(uint256 maxCatchupSeconds_) external onlyOwner {
        if (maxCatchupSeconds_ == 0 || maxCatchupSeconds_ > MAX_CATCHUP) revert CatchupTooHigh();
        maxCatchupSeconds = maxCatchupSeconds_;
        emit MaxCatchupSet(maxCatchupSeconds_);
    }

    function setKeeperReward(uint256 keeperReward_) external onlyOwner {
        if (keeperReward_ > minDripAmount / KEEPER_REWARD_DIVISOR) revert KeeperRewardExceedsMin();
        keeperReward = keeperReward_;
        emit KeeperRewardSet(keeperReward_);
    }

    function setMinDripAmount(uint256 minDripAmount_) external onlyOwner {
        if (keeperReward > minDripAmount_ / KEEPER_REWARD_DIVISOR) revert KeeperRewardExceedsMin();
        minDripAmount = minDripAmount_;
        emit MinDripAmountSet(minDripAmount_);
    }

    // ─────────────────────────────── Emergency ───────────────────────────────

    /// @notice Owner sweeps a balance — including the reward IMD buffer — to `to`. Trusted power,
    /// removed on `renounceOwnership()`.
    function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
        token.safeTransfer(to, amount);
        emit EmergencyRescue(token, to, amount);
    }

    function rescueETH(address to, uint256 amount) external onlyOwner {
        to.safeTransferETH(amount);
        emit EmergencyRescue(address(0), to, amount);
    }

    /// @dev Don't let ownership be dropped into a config that can never drain the buffer to stakers:
    /// rate 0 (no stream) or a `minDripAmount` above the per-call ceiling (`drip()` could never fire)
    /// would strand rewards here forever with no owner left to fix it.
    function renounceOwnership() public payable override onlyOwner {
        if (dripRatePerSecond == 0 || vault == address(0)) revert RenounceWouldFreeze();
        if (minDripAmount > dripRatePerSecond * maxCatchupSeconds) revert RenounceWouldFreeze();
        super.renounceOwnership();
    }
}
