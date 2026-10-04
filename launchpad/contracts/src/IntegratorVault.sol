// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";

/// @title IntegratorVault
/// @notice Holds the IMD earned by registered integrators (apps, bots, wallets) for trades they route through
///         PadRouter: a share of the protocol fee, carved off before the fee splitter. Integrators claim anytime.
/// @dev The bonding curve and the hook transfer IMD here first, then call `credit`.
contract IntegratorVault is ReentrancyGuard {
    using SafeTransferLib for address;

    address public immutable imd;
    address internal immutable _deployer;
    address public curve;
    address public hook;

    mapping(address integrator => uint256) public balanceOf;
    mapping(address integrator => uint256) public totalEarned;

    event Credited(address indexed integrator, address indexed coin, uint256 amount);
    event Claimed(address indexed integrator, uint256 amount);

    error Unauthorized();
    error AlreadyInitialized();

    constructor(address imd_) {
        imd = imd_;
        _deployer = msg.sender;
    }

    function initialize(address curve_, address hook_) external {
        if (msg.sender != _deployer) revert Unauthorized();
        if (curve != address(0)) revert AlreadyInitialized();
        curve = curve_;
        hook = hook_;
    }

    function credit(address integrator, address coin, uint256 amount) external {
        if (msg.sender != curve && msg.sender != hook) revert Unauthorized();
        balanceOf[integrator] += amount;
        totalEarned[integrator] += amount;
        emit Credited(integrator, coin, amount);
    }

    /// @notice Sends `integrator`'s earnings to it. Anyone can trigger it; funds only go to the integrator.
    function claim(address integrator) external nonReentrant returns (uint256 amount) {
        amount = balanceOf[integrator];
        if (amount == 0) return 0;
        balanceOf[integrator] = 0;
        imd.safeTransfer(integrator, amount);
        emit Claimed(integrator, amount);
    }
}
