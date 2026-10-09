// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

interface IBurnable {
    function burn(uint256 amount) external;
}

/// @title PadBurner
/// @notice The `burnSink` of the $PONDPAD market: receives the $PONDPAD that PadMarketHook trims and burns it,
///         so total supply really drops instead of tokens sitting in a dead address. Anyone can call `burn()`.
///         It has no owner and no way to send tokens anywhere else.
contract PadBurner {
    address public immutable token;
    uint256 public totalBurned;

    event Burned(uint256 amount);

    constructor(address token_) {
        token = token_;
    }

    /// @notice Burns every $PONDPAD this contract holds.
    function burn() external returns (uint256 amount) {
        amount = SafeTransferLib.balanceOf(token, address(this));
        if (amount == 0) return 0;
        totalBurned += amount;
        IBurnable(token).burn(amount);
        emit Burned(amount);
    }
}
