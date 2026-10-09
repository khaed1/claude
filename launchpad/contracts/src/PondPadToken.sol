// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "solady/tokens/ERC20.sol";

/// @title PondPadToken ($PONDPAD)
/// @notice PondPad's platform token: fixed supply of 1,000,000,000, no owner, no mint, no admin, with EIP-2612
///         permit. Anyone can burn their own tokens; PadBurner uses this so trimmed $PONDPAD really leaves supply.
/// @dev The whole supply is minted to `holder` (the deployer's distribution step), which funds PadSale with 90%
///      and the airdrop, team vesting and liquidity reserve with the rest. Deployed with CREATE2 at an address
///      above IMD's, so IMD is `currency0` in the $PONDPAD/IMD pool (D-19).
contract PondPadToken is ERC20 {
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000e18;

    constructor(address holder) {
        _mint(holder, TOTAL_SUPPLY);
    }

    function name() public pure override returns (string memory) {
        return "PondPad";
    }

    function symbol() public pure override returns (string memory) {
        return "PONDPAD";
    }

    /// @notice Always zero: the token has no owner and no admin functions.
    function owner() external pure returns (address) {
        return address(0);
    }

    /// @notice Burns the caller's own tokens.
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
