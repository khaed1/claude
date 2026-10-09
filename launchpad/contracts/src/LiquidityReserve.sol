// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IMarketClock} from "./AirdropDistributor.sol";

/// @title LiquidityReserve
/// @notice Holds the 3% $PONDPAD liquidity reserve (30M, D-57) until the $PONDPAD market opens, then hands all of it
///         to the 48 h timelock, which adds it to the market's inventory (`MarketController.fundInventory`) or uses
///         it as the Safe proposes. While the sale runs nobody can move it, so it can never be sold back into the
///         sale's curve and pull IMD out of the raise (audit R1-A2-4); once the market is open the sale is closed.
/// @dev No owner. `release()` is permissionless and always pays the fixed beneficiary.
contract LiquidityReserve {
    using SafeTransferLib for address;

    address public immutable token;
    IMarketClock public immutable market;
    address public immutable beneficiary;

    event Released(address indexed to, uint256 amount);

    error MarketNotOpen();
    error ZeroAddress();

    constructor(address token_, address market_, address beneficiary_) {
        if (token_ == address(0) || market_ == address(0) || beneficiary_ == address(0)) revert ZeroAddress();
        token = token_;
        market = IMarketClock(market_);
        beneficiary = beneficiary_;
    }

    /// @notice Sends the whole reserve to the beneficiary once the market is open. Anyone can call it.
    function release() external returns (uint256 amount) {
        if (market.openedAt() == 0) revert MarketNotOpen();
        amount = token.balanceOf(address(this));
        if (amount == 0) return 0;
        token.safeTransfer(beneficiary, amount);
        emit Released(beneficiary, amount);
    }
}
