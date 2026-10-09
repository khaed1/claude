// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @notice Fee schedule of a coin, copied from its launch parameters and never changed afterwards.
struct CoinFees {
    uint16 taxBps; // optional coin tax, 0..300
    uint16 taxToCreatorBps; // shares of the tax, summing to 10_000 when taxBps > 0
    uint16 taxToHoldersBps;
    uint16 taxToSwarmBps;
}

/// @notice How one fee amount splits between its destinations.
struct FeeParts {
    uint256 protocol;
    uint256 creator;
    uint256 holders;
    uint256 swarm;
}

/// @title FeeLib
/// @notice The PondPad fee schedule, shared by the bonding curve and the hook so both phases charge the same.
library FeeLib {
    uint256 internal constant BPS = 10_000;
    uint256 internal constant PROTOCOL_BPS = 100; // 1.0% of every trade
    uint256 internal constant CREATOR_BPS = 50; // 0.5% of every trade
    uint256 internal constant BASE_BPS = PROTOCOL_BPS + CREATOR_BPS;
    uint256 internal constant MAX_TAX_BPS = 300;

    error InvalidFees();

    function validate(CoinFees memory f) internal pure {
        if (f.taxBps > MAX_TAX_BPS) revert InvalidFees();
        uint256 sum = uint256(f.taxToCreatorBps) + f.taxToHoldersBps + f.taxToSwarmBps;
        if (f.taxBps == 0 ? sum != 0 : sum != BPS) revert InvalidFees();
    }

    function totalBps(CoinFees memory f) internal pure returns (uint256) {
        return BASE_BPS + f.taxBps;
    }

    /// @notice Splits `fee`, charged at `totalBps(f)`, into its parts. Rounding dust goes to the protocol.
    function split(CoinFees memory f, uint256 fee) internal pure returns (FeeParts memory p) {
        uint256 total = totalBps(f);
        uint256 tax = (fee * f.taxBps) / total;
        p.creator = (fee * CREATOR_BPS) / total + (tax * f.taxToCreatorBps) / BPS;
        p.holders = (tax * f.taxToHoldersBps) / BPS;
        p.swarm = (tax * f.taxToSwarmBps) / BPS;
        p.protocol = fee - p.creator - p.holders - p.swarm;
    }
}
