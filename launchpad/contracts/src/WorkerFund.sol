// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";

/// @title WorkerFund
/// @notice The IMD workers' bucket of the fee splitter (25%). It holds the IMD from coin and sale fees and the
///         $PONDPAD from the market's sell-side fees (D-38), and `release()` sends both, as they are, to the IMD
///         worker rewards address (D-45). Anyone can call it.
/// @dev Until the IMD developer gives the worker rewards address, funds accrue here and `release` reverts. The
///      owner (7-day timelock) sets or changes the address; nothing else can move funds, and they can only go to
///      that address.
contract WorkerFund is Ownable, ReentrancyGuard {
    using SafeTransferLib for address;

    address public immutable imd;
    address public immutable pondpad;
    address public workerRewards;
    mapping(address token => uint256) public totalReleased;

    event Released(address indexed token, address indexed to, uint256 amount);
    event WorkerRewardsUpdated(address workerRewards);

    error RecipientNotSet();
    error ZeroAddress();

    constructor(address owner_, address imd_, address pondpad_, address workerRewards_) {
        _initializeOwner(owner_);
        imd = imd_;
        pondpad = pondpad_;
        workerRewards = workerRewards_;
        emit WorkerRewardsUpdated(workerRewards_);
    }

    /// @notice Sends the whole IMD and $PONDPAD balance to the worker rewards address.
    function release() external returns (uint256 imdAmount, uint256 pondpadAmount) {
        imdAmount = releaseToken(imd);
        pondpadAmount = releaseToken(pondpad);
    }

    /// @notice Sends the whole balance of `token` to the worker rewards address (any token sent here by mistake
    ///         or by a future fee route goes the same way).
    function releaseToken(address token) public nonReentrant returns (uint256 amount) {
        address to = workerRewards;
        if (to == address(0)) revert RecipientNotSet();
        amount = token.balanceOf(address(this));
        if (amount == 0) return 0;
        totalReleased[token] += amount;
        token.safeTransfer(to, amount);
        emit Released(token, to, amount);
    }

    function setWorkerRewards(address workerRewards_) external onlyOwner {
        if (workerRewards_ == address(0)) revert ZeroAddress();
        workerRewards = workerRewards_;
        emit WorkerRewardsUpdated(workerRewards_);
    }
}
