// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {LibString} from "solady/utils/LibString.sol";

/// @notice An IMD oracle answer, exactly as the oracle signs it (EIP-712, domain "IdentityMD Oracle" version "2").
///         `chainId`, `fromBlock` and `toBlock` are the question's evidence chain and window; the signing domain's
///         chain and contract are the consumer's (the Docket module that checks it).
/// @dev Same format as PondPad's `AttestationVerifier` (launchpad D-49), checked there against a live attestation.
struct OracleAttestation {
    bytes32 requestId;
    uint256 chainId;
    bytes32 questionHash;
    uint8 answerType;
    bytes answer;
    uint256 figure;
    uint64 fromBlock;
    uint64 toBlock;
    bytes32 blockHash;
    bytes32 panelJobId;
    uint16 panelSize;
    uint16 quorum;
    uint16 agreed;
    uint64 issuedAt;
    uint64 expiresAt;
}

/// @title OracleAttestationLib
/// @notice Hashing helpers for IMD oracle attestations: the EIP-712 struct hash and the oracle's question hash.
/// @dev The oracle's `questionHash` is keccak256 of the canonical JSON of the question (sorted keys, no whitespace):
///      {"answerType","chainId","evidence","question","v":1,"window":{"fromBlock","toBlock"}}, for a panel question
///      with no definitions or guards.
library OracleAttestationLib {
    bytes32 internal constant ATTESTATION_TYPEHASH = keccak256(
        "OracleAttestation(bytes32 requestId,uint256 chainId,bytes32 questionHash,uint8 answerType,bytes answer,uint256 figure,uint64 fromBlock,uint64 toBlock,bytes32 blockHash,bytes32 panelJobId,uint16 panelSize,uint16 quorum,uint16 agreed,uint64 issuedAt,uint64 expiresAt)"
    );
    uint8 internal constant ANSWER_BOOL = 0;
    /// @dev The oracle's question limit.
    uint256 internal constant MAX_QUESTION = 2_000;

    error BadText();

    /// @notice EIP-712 struct hash of an attestation.
    function hash(OracleAttestation calldata att) internal pure returns (bytes32) {
        return keccak256(
            bytes.concat(
                abi.encode(
                    ATTESTATION_TYPEHASH,
                    att.requestId,
                    att.chainId,
                    att.questionHash,
                    att.answerType,
                    keccak256(att.answer),
                    att.figure,
                    att.fromBlock,
                    att.toBlock
                ),
                abi.encode(
                    att.blockHash, att.panelJobId, att.panelSize, att.quorum, att.agreed, att.issuedAt, att.expiresAt
                )
            )
        );
    }

    /// @notice The oracle's question hash for a yes/no panel question with no definitions or guards.
    function boolQuestionHash(string memory question, uint256 chainId, uint64 fromBlock, uint64 toBlock)
        internal
        pure
        returns (bytes32)
    {
        checkText(question, MAX_QUESTION);
        return keccak256(
            abi.encodePacked(
                '{"answerType":"bool","chainId":',
                LibString.toString(chainId),
                ',"evidence":"panel","question":"',
                question,
                '","v":1,"window":{"fromBlock":',
                LibString.toString(fromBlock),
                ',"toBlock":',
                LibString.toString(toBlock),
                "}}"
            )
        );
    }

    /// @notice Reverts unless `s` is 1 to `maxLength` characters of printable ASCII without `"` or `\`, so it can sit
    ///         in the question's JSON without escaping.
    function checkText(string memory s, uint256 maxLength) internal pure {
        bytes memory b = bytes(s);
        if (b.length == 0 || b.length > maxLength) revert BadText();
        for (uint256 i; i < b.length; i++) {
            bytes1 c = b[i];
            if (c < 0x20 || c > 0x7e || c == '"' || c == "\\") revert BadText();
        }
    }
}
