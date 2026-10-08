// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";

interface IHolderCoin {
    function fundHolderStream(uint256 amount) external;
}

interface IPoolManagerOf {
    function poolManager() external view returns (address);
}

/// @title CreatorVault
/// @notice Holds each coin's creator fees in IMD until the coin's fee recipient claims them.
/// @dev The bonding curve and the hook transfer IMD here first, then call `credit`. Only a coin's current recipient
///      can change its recipient; there is no takeover path (D-82). The recipient may route the fees to the coin's
///      holders by naming the coin itself, which is final: the coin can never call `setRecipient`.
///      When the recipient is the coin itself (fees to holders, D-52), claimed fees, the swept swarm budget and
///      anything else sent with `fundHolders` are not paid to holders at once: they join the coin's own holder
///      stream, which pays them out second by second over about 7 days to the balances held during each second
///      (D-78, D-80; audits R1-A4-1, R3-A4-1). A lump paid in one go, or a day's share released at a moment the
///      caller picks, would be credited to whoever holds at that moment (buy, release, claim, sell).
///      A recipient can't be this vault, the curve, the hook, the hook's PoolManager or another registered coin: anyone
///      may `claim`, which would hand the fees to a contract that never counts them (or to the other coin's holders)
///      before the recipient could correct the mistake, and the coin's swarm budget could never be spent, cancelled or
///      swept (audit R5-A1-1). Any other address is the recipient's own choice.
contract CreatorVault is ReentrancyGuard {
    using SafeTransferLib for address;

    address public immutable imd;
    address internal immutable _deployer;
    address public curve;
    address public hook;

    mapping(address coin => address) public recipientOf;
    mapping(address coin => uint256) public balanceOf;

    event Registered(address indexed coin, address indexed recipient);
    event Credited(address indexed coin, uint256 amount);
    event Claimed(address indexed coin, address indexed recipient, uint256 amount);
    event RecipientChanged(address indexed coin, address indexed previous, address indexed current);
    event HolderStreamFunded(address indexed coin, address indexed from, uint256 amount);

    error Unauthorized();
    error AlreadyInitialized();
    error ZeroAddress();
    error UnknownCoin();
    error InvalidRecipient();

    constructor(address imd_) {
        imd = imd_;
        _deployer = msg.sender;
    }

    /// @notice One-time wiring by the deployer.
    function initialize(address curve_, address hook_) external {
        if (msg.sender != _deployer) revert Unauthorized();
        if (curve != address(0)) revert AlreadyInitialized();
        curve = curve_;
        hook = hook_;
    }

    function register(address coin, address recipient) external {
        if (msg.sender != curve) revert Unauthorized();
        if (recipient == address(0)) revert ZeroAddress();
        _checkRecipient(coin, recipient);
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
    ///         is the recipient at claim time, so claim first if needed. Naming the coin itself sends the fees to its
    ///         holders for good: nobody can change the recipient after that.
    function setRecipient(address coin, address newRecipient) external {
        address current = recipientOf[coin];
        if (msg.sender != current) revert Unauthorized();
        if (newRecipient == address(0)) revert ZeroAddress();
        _checkRecipient(coin, newRecipient);
        recipientOf[coin] = newRecipient;
        emit RecipientChanged(coin, current, newRecipient);
    }

    /// @dev Refuses the system contracts that would strand a permissionless `claim`, and any registered coin other than
    ///      `coin` itself (naming the coin itself routes the fees to its holders) (audit R5-A1-1).
    function _checkRecipient(address coin, address recipient) internal view {
        if (
            recipient == address(this) || recipient == curve || recipient == hook
                || recipient == IPoolManagerOf(hook).poolManager()
                || (recipient != coin && recipientOf[recipient] != address(0))
        ) revert InvalidRecipient();
    }
}
