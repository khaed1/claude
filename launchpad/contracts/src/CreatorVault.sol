// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";

/// @title CreatorVault
/// @notice Holds each coin's creator fees in IMD until the coin's fee recipient claims them.
/// @dev The bonding curve and the hook transfer IMD here first, then call `credit`. The recipient of a coin can
///      be changed by the current recipient, or by the CTO module after a swarm-approved takeover.
contract CreatorVault is ReentrancyGuard {
    using SafeTransferLib for address;

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

    error Unauthorized();
    error AlreadyInitialized();
    error ZeroAddress();

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

    /// @notice Sends the coin's accrued creator fees to its current recipient. Anyone can trigger it.
    function claim(address coin) external nonReentrant returns (uint256 amount) {
        amount = balanceOf[coin];
        if (amount == 0) return 0;
        balanceOf[coin] = 0;
        address to = recipientOf[coin];
        imd.safeTransfer(to, amount);
        emit Claimed(coin, to, amount);
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
    ///         Fees accrued before the takeover are paid to the old recipient first.
    function ctoSetRecipient(address coin, address newRecipient) external nonReentrant {
        if (msg.sender != ctoModule || ctoModule == address(0)) revert Unauthorized();
        if (newRecipient == address(0)) revert ZeroAddress();
        address current = recipientOf[coin];
        uint256 amount = balanceOf[coin];
        if (amount != 0) {
            balanceOf[coin] = 0;
            imd.safeTransfer(current, amount);
            emit Claimed(coin, current, amount);
        }
        recipientOf[coin] = newRecipient;
        emit RecipientChanged(coin, current, newRecipient, true);
    }
}
