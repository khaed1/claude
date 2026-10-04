// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {Ownable} from "solady/auth/Ownable.sol";

/// @title FeeSplitter
/// @notice Receives all protocol IMD and splits it between stakers, IMD workers, growth and the treasury.
///         Anyone can call `distribute()`. Shares can only move inside fixed ranges, through the owner (timelock).
contract FeeSplitter is Ownable {
    using SafeTransferLib for address;

    struct Shares {
        uint16 stakers;
        uint16 workers;
        uint16 growth;
        uint16 treasury;
    }

    struct Recipients {
        address stakers; // PadBuyer: buys $PONDPAD for the sPONDPAD vault
        address workers; // WorkerFund
        address growth; // GrowthFund
        address treasury; // team Safe
    }

    uint256 internal constant BPS = 10_000;

    address public immutable imd;
    Shares internal _shares;
    Recipients internal _recipients;

    event Distributed(uint256 stakers, uint256 workers, uint256 growth, uint256 treasury);
    event SharesUpdated(Shares shares);
    event RecipientsUpdated(Recipients recipients);

    error InvalidShares();
    error ZeroAddress();

    constructor(address owner_, address imd_, Shares memory shares_, Recipients memory recipients_) {
        _initializeOwner(owner_);
        imd = imd_;
        _setShares(shares_);
        _setRecipients(recipients_);
    }

    function shares() external view returns (Shares memory) {
        return _shares;
    }

    function recipients() external view returns (Recipients memory) {
        return _recipients;
    }

    function distribute() external {
        uint256 amount = SafeTransferLib.balanceOf(imd, address(this));
        if (amount == 0) return;
        Shares memory s = _shares;
        Recipients memory r = _recipients;
        uint256 toStakers = (amount * s.stakers) / BPS;
        uint256 toWorkers = (amount * s.workers) / BPS;
        uint256 toGrowth = (amount * s.growth) / BPS;
        uint256 toTreasury = amount - toStakers - toWorkers - toGrowth;
        if (toStakers != 0) imd.safeTransfer(r.stakers, toStakers);
        if (toWorkers != 0) imd.safeTransfer(r.workers, toWorkers);
        if (toGrowth != 0) imd.safeTransfer(r.growth, toGrowth);
        if (toTreasury != 0) imd.safeTransfer(r.treasury, toTreasury);
        emit Distributed(toStakers, toWorkers, toGrowth, toTreasury);
    }

    function setShares(Shares calldata s) external onlyOwner {
        _setShares(s);
    }

    function setRecipients(Recipients calldata r) external onlyOwner {
        _setRecipients(r);
    }

    /// @dev Ranges from the architecture: stakers 25–60%, workers 15–35%, growth 0–30%, treasury 5–20%.
    function _setShares(Shares memory s) internal {
        if (
            uint256(s.stakers) + s.workers + s.growth + s.treasury != BPS || s.stakers < 2_500 || s.stakers > 6_000
                || s.workers < 1_500 || s.workers > 3_500 || s.growth > 3_000 || s.treasury < 500 || s.treasury > 2_000
        ) revert InvalidShares();
        _shares = s;
        emit SharesUpdated(s);
    }

    function _setRecipients(Recipients memory r) internal {
        if (r.stakers == address(0) || r.workers == address(0) || r.growth == address(0) || r.treasury == address(0)) {
            revert ZeroAddress();
        }
        _recipients = r;
        emit RecipientsUpdated(r);
    }
}
