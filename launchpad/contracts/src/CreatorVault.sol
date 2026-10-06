// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {TransientStateLibrary} from "v4-core/libraries/TransientStateLibrary.sol";

interface IHolderCoin {
    function distribute() external;
    function poolManager() external view returns (IPoolManager);
    function eligibleSupply() external view returns (uint256);
    function MIN_ELIGIBLE() external view returns (uint256);
}

interface IFeeFlusher {
    function flush(address coin) external;
}

/// @title CreatorVault
/// @notice Holds each coin's creator fees in IMD until the coin's fee recipient claims them.
/// @dev The bonding curve and the hook transfer IMD here first, then call `credit`. The recipient of a coin can
///      be changed by the current recipient, or by the CTO module after a swarm-approved takeover.
///      When the recipient is the coin itself (fees to holders, D-52), claimed fees, the swept swarm budget and
///      anything else sent with `fundHolders` are not paid to holders at once: they are released to the coin as
///      IMD dividends over about 7 days, at most one day's share per call (D-78, audit R1-A4-1). A lump paid in
///      one go would be credited to whoever holds at the moment the caller picks (buy, release, claim, sell).
contract CreatorVault is ReentrancyGuard {
    using SafeTransferLib for address;
    using TransientStateLibrary for IPoolManager;

    /// @notice A holder stream pays out over this long.
    uint256 public constant HOLDER_STREAM_PERIOD = 7 days;
    /// @notice One release pays at most this much time's share, however long since the last one.
    uint256 public constant MAX_RELEASE_GAP = 1 days;

    struct HolderStream {
        uint128 remaining; // IMD still to be released to the coin's holders
        uint128 ratePerSecond; // set when the stream is funded: remaining / HOLDER_STREAM_PERIOD, rounded up
        uint64 lastReleaseAt;
    }

    address public immutable imd;
    address internal immutable _deployer;
    address public curve;
    address public hook;
    address public ctoModule;

    mapping(address coin => address) public recipientOf;
    mapping(address coin => uint256) public balanceOf;
    mapping(address coin => HolderStream) public holderStreamOf;

    event Registered(address indexed coin, address indexed recipient);
    event Credited(address indexed coin, uint256 amount);
    event Claimed(address indexed coin, address indexed recipient, uint256 amount);
    event RecipientChanged(address indexed coin, address indexed previous, address indexed current, bool byCto);
    event HolderStreamFunded(address indexed coin, address indexed from, uint256 amount, uint256 remaining);
    event ReleasedToHolders(address indexed coin, uint256 amount);

    error Unauthorized();
    error AlreadyInitialized();
    error ZeroAddress();
    error UnknownCoin();
    error PoolManagerUnlocked();

    constructor(address imd_) {
        imd = imd_;
        _deployer = msg.sender;
    }

    /// @notice One-time wiring by the deployer.
    function initialize(address curve_, address hook_, address ctoModule_) external {
        if (msg.sender != _deployer) revert Unauthorized();
        if (curve != address(0)) revert AlreadyInitialized();
        curve = curve_;
        hook = hook_;
        ctoModule = ctoModule_;
    }

    function register(address coin, address recipient) external {
        if (msg.sender != curve) revert Unauthorized();
        if (recipient == address(0)) revert ZeroAddress();
        recipientOf[coin] = recipient;
        emit Registered(coin, recipient);
    }

    function credit(address coin, uint256 amount) external {
        if (msg.sender != curve && msg.sender != hook) revert Unauthorized();
        balanceOf[coin] += amount;
        emit Credited(coin, amount);
    }

    /// @notice Sends the coin's accrued creator fees to its current recipient. Anyone can trigger it. When the
    ///         recipient is the coin itself, the fees join its holder stream instead (released over ~7 days).
    function claim(address coin) external nonReentrant returns (uint256 amount) {
        amount = balanceOf[coin];
        if (amount == 0) return 0;
        balanceOf[coin] = 0;
        address to = recipientOf[coin];
        if (to == coin) {
            _fundHolders(coin, amount, address(this));
        } else {
            imd.safeTransfer(to, amount);
        }
        emit Claimed(coin, to, amount);
    }

    // ------------------------------------------------------------------ Holder streams (D-78, R1-A4-1)

    /// @notice Adds `amount` IMD (pulled from the caller) to `coin`'s holder stream. Used by SwarmBudget when it
    ///         sweeps a coin's budget to holders; anyone may add to a registered coin's stream.
    function fundHolders(address coin, uint256 amount) external nonReentrant {
        if (recipientOf[coin] == address(0)) revert UnknownCoin();
        if (amount == 0) return;
        imd.safeTransferFrom(msg.sender, address(this), amount);
        _fundHolders(coin, amount, msg.sender);
    }

    /// @notice Releases what the coin's holder stream owes now to its holders as IMD dividends. Anyone.
    function releaseToHolders(address coin) external nonReentrant returns (uint256 amount) {
        return _releaseToHolders(coin);
    }

    /// @notice IMD the next `releaseToHolders(coin)` would release.
    function releasableToHolders(address coin) public view returns (uint256 amount) {
        HolderStream memory st = holderStreamOf[coin];
        if (st.remaining == 0) return 0;
        uint256 elapsed = block.timestamp - st.lastReleaseAt;
        if (elapsed > MAX_RELEASE_GAP) elapsed = MAX_RELEASE_GAP;
        amount = uint256(st.ratePerSecond) * elapsed;
        if (amount > st.remaining) amount = st.remaining;
    }

    /// @dev Releases what is due, then adds `amount`. The rate becomes what pays the whole remainder over
    ///      `HOLDER_STREAM_PERIOD` from now, but never drops while the stream runs: a top-up (even 1 wei) can't
    ///      stretch a lump past ~7 days (audit R2-A4-3). Refused while an outside caller holds the PoolManager
    ///      unlock: the release is skipped there, and moving the clock would erase the time it was owed (audit
    ///      R2-A1-1 / R2-A4-2).
    function _fundHolders(address coin, uint256 amount, address from) internal {
        if (IHolderCoin(coin).poolManager().isUnlocked()) revert PoolManagerUnlocked();
        _releaseToHolders(coin);
        HolderStream storage st = holderStreamOf[coin];
        uint256 before = st.remaining;
        uint256 remaining = before + amount;
        uint256 rate = (remaining + HOLDER_STREAM_PERIOD - 1) / HOLDER_STREAM_PERIOD;
        if (before != 0 && st.ratePerSecond > rate) rate = st.ratePerSecond;
        st.remaining = uint128(remaining);
        st.ratePerSecond = uint128(rate);
        st.lastReleaseAt = uint64(block.timestamp);
        emit HolderStreamFunded(coin, from, amount, remaining);
    }

    /// @dev Waits (releases nothing) while an outside caller holds the PoolManager unlock: the coin skips its
    ///      dividend accounting then, so released IMD would be credited later to whoever holds at that moment.
    ///      Also waits while the coin has nobody eligible for dividends, so a release is never parked on the coin
    ///      for its next buyer (audit R2-A1-3).
    function _releaseToHolders(address coin) internal returns (uint256 amount) {
        amount = releasableToHolders(coin);
        if (amount == 0) return 0;
        if (IHolderCoin(coin).poolManager().isUnlocked()) return 0;
        if (IHolderCoin(coin).eligibleSupply() < IHolderCoin(coin).MIN_ELIGIBLE()) return 0;
        HolderStream storage st = holderStreamOf[coin];
        st.remaining -= uint128(amount);
        st.lastReleaseAt = uint64(block.timestamp);
        imd.safeTransfer(coin, amount);
        IHolderCoin(coin).distribute();
        emit ReleasedToHolders(coin, amount);
    }

    /// @notice The current recipient hands future fees to a new address. Accrued fees stay claimable to whoever
    ///         is the recipient at claim time, so claim first if needed.
    function setRecipient(address coin, address newRecipient) external {
        address current = recipientOf[coin];
        if (msg.sender != current) revert Unauthorized();
        if (newRecipient == address(0)) revert ZeroAddress();
        recipientOf[coin] = newRecipient;
        emit RecipientChanged(coin, current, newRecipient, false);
    }

    /// @notice Called by the CTO module once a swarm-approved takeover has passed its public notice.
    ///         Fees accrued before the takeover are paid to the old recipient first, including the ones still
    ///         pending in the hook from outside-router swaps (audit R1-A4-8). If the old recipient was the coin,
    ///         they join its holder stream.
    function ctoSetRecipient(address coin, address newRecipient) external nonReentrant {
        if (msg.sender != ctoModule || ctoModule == address(0)) revert Unauthorized();
        if (newRecipient == address(0)) revert ZeroAddress();
        // Inside an outside caller's unlock the hook flush would do nothing, and fees pending in the hook would go
        // to the new recipient (audit R2-A1-2 / R2-A4-1): refused there, so the executor can't pick that moment.
        if (IHolderCoin(coin).poolManager().isUnlocked()) revert PoolManagerUnlocked();
        if (hook.code.length != 0) IFeeFlusher(hook).flush(coin); // credits this vault before the switch
        address current = recipientOf[coin];
        uint256 amount = balanceOf[coin];
        if (amount != 0) {
            balanceOf[coin] = 0;
            if (current == coin) _fundHolders(coin, amount, address(this));
            else imd.safeTransfer(current, amount);
            emit Claimed(coin, current, amount);
        }
        recipientOf[coin] = newRecipient;
        emit RecipientChanged(coin, current, newRecipient, true);
    }
}
