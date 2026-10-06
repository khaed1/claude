// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "solady/auth/Ownable.sol";
import {EIP712} from "solady/utils/EIP712.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {LibString} from "solady/utils/LibString.sol";

/// @notice An IMD oracle answer, exactly as the oracle signs it (EIP-712, domain "IdentityMD Oracle" version "2").
///         `chainId`, `fromBlock` and `toBlock` are the question's evidence chain and window; the signing domain's
///         chain and contract are the consumer's (this verifier on Robinhood Chain).
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

/// @title AttestationVerifier
/// @notice Checks IMD oracle attestations for PondPad's consumers (CTOModule, VersionRegistry): the signer is an
///         approved oracle signer, the panel was large enough and agreed strongly enough, the answer is still
///         valid, and the question is exactly the one the consumer expects.
/// @dev The oracle's `questionHash` is keccak256 of the canonical JSON of the question (sorted keys, no
///      whitespace): {"answerType","chainId","evidence","question","v":1,"window":{"fromBlock","toBlock"}}.
///      Checked against a live attestation (see `Governance.t.sol`). Consumers build their question text from
///      onchain data, so an attestation for another coin, recipient or version never matches. Consumers track used
///      request ids themselves. Owner: the 7-day timelock (signers, thresholds). Until a signer is set no
///      attestation verifies, and the consumers' fallback paths apply.
contract AttestationVerifier is Ownable, EIP712 {
    bytes32 public constant ATTESTATION_TYPEHASH = keccak256(
        "OracleAttestation(bytes32 requestId,uint256 chainId,bytes32 questionHash,uint8 answerType,bytes answer,uint256 figure,uint64 fromBlock,uint64 toBlock,bytes32 blockHash,bytes32 panelJobId,uint16 panelSize,uint16 quorum,uint16 agreed,uint64 issuedAt,uint64 expiresAt)"
    );
    uint8 public constant ANSWER_BOOL = 0;

    uint16 public constant MIN_PANEL_FLOOR = 5;
    uint16 public constant MIN_PANEL_CEILING = 100;
    uint16 public constant MIN_AGREEMENT_FLOOR_BPS = 5_001;

    mapping(address => bool) public isSigner;
    uint256 public signerCount;
    /// @notice Smallest panel accepted (user: more than 50).
    uint16 public minPanelSize = 51;
    /// @notice Members who gave the signed answer, as a share of the panel rounded up to whole bps (user: two
    ///         thirds).
    uint16 public minAgreementBps = 6_667;

    event SignerSet(address indexed signer, bool approved);
    event ThresholdsSet(uint16 minPanelSize, uint16 minAgreementBps);

    error UnknownSigner();
    error WrongQuestion();
    error NotBool();
    error PanelTooSmall();
    error NotEnoughAgreement();
    error NotYetValid();
    error Expired();
    error InvalidSetting();
    error BadQuestionText();
    error BadWindow();

    constructor(address owner_) {
        _initializeOwner(owner_);
    }

    function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
        return ("IdentityMD Oracle", "2");
    }

    // ------------------------------------------------------------------ Verification

    /// @notice Verifies a bool attestation answering `question` and returns its answer. Reverts if anything is off.
    function verifyBool(OracleAttestation calldata att, bytes calldata signature, string memory question)
        external
        view
        returns (bool)
    {
        if (!isSigner[ECDSA.recoverCalldata(_hashTypedData(hashAttestation(att)), signature)]) revert UnknownSigner();
        if (att.questionHash != questionHash(question, att.chainId, att.fromBlock, att.toBlock)) revert WrongQuestion();
        // The evidence window the panel was given must be a real range (audit R2-A4-4); consumers log it.
        if (att.fromBlock > att.toBlock) revert BadWindow();
        if (att.answerType != ANSWER_BOOL || att.answer.length != 32) revert NotBool();
        if (att.panelSize < minPanelSize) revert PanelTooSmall();
        // The agreeing share is rounded up to whole bps, so exactly two thirds (34 of 51, 50 of 75) meets 6,667
        // (audit R1-A4-13); without rounding, 6,667 bps would be slightly more than two thirds.
        if (
            att.agreed < att.quorum
                || uint256(att.agreed) * 10_000 + att.panelSize - 1 < uint256(att.panelSize) * minAgreementBps
        ) {
            revert NotEnoughAgreement();
        }
        if (block.timestamp < att.issuedAt) revert NotYetValid();
        if (block.timestamp > att.expiresAt) revert Expired();
        uint256 word = abi.decode(att.answer, (uint256));
        if (word > 1) revert NotBool();
        return word == 1;
    }

    /// @notice EIP-712 struct hash of an attestation.
    function hashAttestation(OracleAttestation calldata att) public pure returns (bytes32) {
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
    ///         `question` must be printable ASCII without `"` or `\`, so its JSON form needs no escaping.
    function questionHash(string memory question, uint256 chainId, uint64 fromBlock, uint64 toBlock)
        public
        pure
        returns (bytes32)
    {
        return questionHashTyped(question, "bool", chainId, fromBlock, toBlock);
    }

    /// @notice Same for any answer type name (`bool`, `address`, `bytes32`, `uint256`, ...).
    function questionHashTyped(
        string memory question,
        string memory answerType,
        uint256 chainId,
        uint64 fromBlock,
        uint64 toBlock
    ) public pure returns (bytes32) {
        checkQuestionText(question);
        checkQuestionText(answerType);
        return keccak256(
            abi.encodePacked(
                '{"answerType":"',
                answerType,
                '","chainId":',
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

    /// @notice Reverts unless `s` is non-empty, at most 2,000 characters (the oracle's limit) and printable ASCII
    ///         without `"` or `\`.
    function checkQuestionText(string memory s) public pure {
        bytes memory b = bytes(s);
        if (b.length == 0 || b.length > 2_000) revert BadQuestionText();
        for (uint256 i; i < b.length; i++) {
            bytes1 c = b[i];
            if (c < 0x20 || c > 0x7e || c == '"' || c == "\\") revert BadQuestionText();
        }
    }

    /// @notice The EIP-712 domain separator signers must use: this contract on this chain.
    function domainSeparator() external view returns (bytes32) {
        return _domainSeparator();
    }

    // ------------------------------------------------------------------ Settings (7-day timelock)

    function setSigner(address signer, bool approved) external onlyOwner {
        if (signer == address(0) || isSigner[signer] == approved) revert InvalidSetting();
        isSigner[signer] = approved;
        if (approved) signerCount++;
        else signerCount--;
        emit SignerSet(signer, approved);
    }

    /// @notice Bounds: panel 5–100 (the oracle's own range today), agreement more than half.
    function setThresholds(uint16 minPanelSize_, uint16 minAgreementBps_) external onlyOwner {
        if (
            minPanelSize_ < MIN_PANEL_FLOOR || minPanelSize_ > MIN_PANEL_CEILING
                || minAgreementBps_ < MIN_AGREEMENT_FLOOR_BPS || minAgreementBps_ > 10_000
        ) revert InvalidSetting();
        minPanelSize = minPanelSize_;
        minAgreementBps = minAgreementBps_;
        emit ThresholdsSet(minPanelSize_, minAgreementBps_);
    }
}
