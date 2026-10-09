// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {IMarketClock} from "./AirdropDistributor.sol";

/// @title TeamVesting
/// @notice The team's 2% of $PONDPAD (20M, D-17), vesting from the moment the $PONDPAD market opens: linear over
///         6 months, with nothing releasable during the first month (D-54). At the 1-month cliff 1/6 unlocks at
///         once; everything is vested at month 6.
/// @dev Not revocable, no owner. `release()` is permissionless and always pays the beneficiary (the team Safe),
///      which only the beneficiary itself can change. The allocation is whatever $PONDPAD this contract holds
///      plus what it has released.
contract TeamVesting is ReentrancyGuard {
    using SafeTransferLib for address;

    uint256 public constant CLIFF = 30 days;
    uint256 public constant DURATION = 180 days;

    address public immutable token;
    IMarketClock public immutable market;
    address public beneficiary;
    uint256 public released;

    event Released(address indexed to, uint256 amount);
    event BeneficiaryUpdated(address beneficiary);

    error NotBeneficiary();
    error ZeroAddress();

    constructor(address token_, address market_, address beneficiary_) {
        if (token_ == address(0) || market_ == address(0) || beneficiary_ == address(0)) revert ZeroAddress();
        token = token_;
        market = IMarketClock(market_);
        beneficiary = beneficiary_;
        emit BeneficiaryUpdated(beneficiary_);
    }

    /// @notice Total vested by now, released or not.
    function vestedAmount() public view returns (uint256) {
        uint256 start = market.openedAt();
        if (start == 0 || block.timestamp < start + CLIFF) return 0;
        uint256 total = token.balanceOf(address(this)) + released;
        uint256 elapsed = block.timestamp - start;
        return elapsed >= DURATION ? total : total * elapsed / DURATION;
    }

    /// @notice Vested and not yet released.
    function releasable() public view returns (uint256) {
        return vestedAmount() - released;
    }

    /// @notice Sends everything releasable to the beneficiary. Anyone can call it.
    function release() external nonReentrant returns (uint256 amount) {
        amount = releasable();
        if (amount == 0) return 0;
        released += amount;
        address to = beneficiary;
        token.safeTransfer(to, amount);
        emit Released(to, amount);
    }

    /// @notice The beneficiary hands its future releases to a new address (for example a new Safe).
    function setBeneficiary(address beneficiary_) external {
        if (msg.sender != beneficiary) revert NotBeneficiary();
        if (beneficiary_ == address(0)) revert ZeroAddress();
        beneficiary = beneficiary_;
        emit BeneficiaryUpdated(beneficiary_);
    }
}
