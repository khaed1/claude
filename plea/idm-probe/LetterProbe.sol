// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title LetterProbe — a stand-in for PLEA's Letterbox, to test sending letters from etherscan.io/idm
/// @notice Like the Letterbox, it has no functions: any input data is a letter. It records what arrived
/// (sender, the exact input bytes, the gas it was given) and then uses as much gas as a real letter
/// (1.6M), so a sender that does not estimate gas fails here as it would on the Letterbox. No ETH.
contract LetterProbe {
    event Letter(address indexed from, bytes data, uint256 gasAtEntry);

    uint256 internal constant LETTER_GAS = 1_600_000;

    fallback() external {
        uint256 g = gasleft();
        emit Letter(msg.sender, msg.data, g);
        while (g - gasleft() < LETTER_GAS) {}
    }
}
