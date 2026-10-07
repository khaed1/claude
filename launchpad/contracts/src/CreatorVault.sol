// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {TransientStateLibrary} from "v4-core/libraries/TransientStateLibrary.sol";

interface IHolderCoin {
    function fundHolderStream(uint256 amount) external;
    function poolManager() external view returns (IPoolManager);
}

interface IFeeFlusher {
    function flush(address coin) external;
}

/// @title CreatorVault
/// @notice Holds each coin's creator fees in IMD until the coin's fee recipient claims them.
/// @dev The bonding curve and the hook transfer IMD here first, then call `credit`. The recipient of a coin can
///      be changed by the current recipient, or by the CTO module after a swarm-approved takeover.
///      When the recipient is the coin itself (fees to holders, D-52), claimed fees, the swept swarm budget and
///      anything else sent with `fundHolders` are not paid to holders at once: they join the coin's own holder
///      stream, which pays them out second by second over about 7 days to the balances held during each second
///      (D-78, D-80; audits R1-A4-1, R3-A4-1). A lump paid in one go, or a day's share released at a moment the
///      caller picks, would be credited to whoever holds at that moment (buy, release, claim, sell).
contract CreatorVault is ReentrancyGuard {
    using SafeTransferLib for address;
    using TransientStateLibrary for IPoolManager;

    address public immutable imd;
    address internal immutable _deployer;
    address public curve;
    address public hook;
    address public ctoModule;

    mapping(address coin => address) public recipientOf;
    mapping(address coin => uint256) public balanceOf;

    event Registered(address indexed coin, address indexed recipient);
    event Credited(address indexed coin, uint256 amount);
    event Claimed(address indexed coin, address indexed recipient, uint256 amount);
    event RecipientChanged(address indexed coin, address indexed previous, address indexed current, bool byCto);
    event HolderStreamFunded(address indexed coin, address indexed from, uint256 amount);

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
    ///         recipient is the coin itself, the fees join its holder stream instead (paid over ~7 days).
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

    // ------------------------------------------------------------------ Holder streams (D-78, D-80)

    /// @notice Adds `amount` IMD (pulled from the caller) to `coin`'s holder stream. Used by SwarmBudget when it
    ///         sweeps a coin's budget to holders; anyone may add to a registered coin's stream. The stream itself
    ///         lives in the coin (`PadToken.fundHolderStream`), which pays it out second by second.
    function fundHolders(address coin, uint256 amount) external nonReentrant {
        if (recipientOf[coin] == address(0)) revert UnknownCoin();
        if (amount == 0) return;
        imd.safeTransferFrom(msg.sender, address(this), amount);
        _fundHolders(coin, amount, msg.sender);
    }

    /// @dev Hands `amount` IMD held here to the coin's holder stream. The stream settles by time on every balance
    ///      change, inside a PoolManager unlock too, so nothing about the moment of funding can be exploited.
    function _fundHolders(address coin, uint256 amount, address from) internal {
        imd.safeApprove(coin, amount);
        IHolderCoin(coin).fundHolderStream(amount);
        emit HolderStreamFunded(coin, from, amount);
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
