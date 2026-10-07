// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedOwnable} from "./FixedOwnable.sol";

/// @title FeeSplitter
/// @notice Receives all protocol IMD and splits it between stakers, IMD workers, growth and the treasury.
///         Anyone can call `distribute()`. The $PONDPAD that sellers pay as fees in the $PONDPAD/IMD pool is
///         split the same way, in $PONDPAD, with `distributeToken` (D-38). Shares can only move inside fixed ranges, through the owner (timelock).
contract FeeSplitter is FixedOwnable {
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
    /// @notice $PONDPAD, the only other token `distributeToken` splits (audit R3-A3-8).
    address public immutable token;
    Shares internal _shares;
    Recipients internal _recipients;

    event Distributed(uint256 stakers, uint256 workers, uint256 growth, uint256 treasury);
    event TokenDistributed(address indexed token, uint256 stakers, uint256 workers, uint256 growth, uint256 treasury);
    event SharesUpdated(Shares shares);
    event RecipientsUpdated(Recipients recipients);

    error InvalidShares();
    error ZeroAddress();
    error NotPondpad();

    constructor(address owner_, address imd_, address token_, Shares memory shares_, Recipients memory recipients_) {
        _initializeOwner(owner_);
        imd = imd_;
        token = token_;
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
        (uint256 a, uint256 b, uint256 c, uint256 d) = _distribute(imd);
        if (a + b + c + d != 0) emit Distributed(a, b, c, d);
    }

    /// @notice Splits this contract's $PONDPAD (the market's sell-side fees) with the same shares and recipients.
    ///         Only $PONDPAD: the stakers' recipient (PadBuyer) can forward nothing else, so another token's 40%
    ///         would be stuck there (audit R3-A3-8).
    function distributeToken(address token_) external {
        if (token_ != token) revert NotPondpad();
        (uint256 a, uint256 b, uint256 c, uint256 d) = _distribute(token_);
        if (a + b + c + d != 0) emit TokenDistributed(token_, a, b, c, d);
    }

    function _distribute(address asset)
        internal
        returns (uint256 toStakers, uint256 toWorkers, uint256 toGrowth, uint256 toTreasury)
    {
        uint256 amount = SafeTransferLib.balanceOf(asset, address(this));
        if (amount == 0) return (0, 0, 0, 0);
        Shares memory s = _shares;
        Recipients memory r = _recipients;
        toStakers = (amount * s.stakers) / BPS;
        toWorkers = (amount * s.workers) / BPS;
        toGrowth = (amount * s.growth) / BPS;
        toTreasury = amount - toStakers - toWorkers - toGrowth;
        if (toStakers != 0) asset.safeTransfer(r.stakers, toStakers);
        if (toWorkers != 0) asset.safeTransfer(r.workers, toWorkers);
        if (toGrowth != 0) asset.safeTransfer(r.growth, toGrowth);
        if (toTreasury != 0) asset.safeTransfer(r.treasury, toTreasury);
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
