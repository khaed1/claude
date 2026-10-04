// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "solady/auth/Ownable.sol";
import {LibString} from "solady/utils/LibString.sol";
import {AttestationVerifier, OracleAttestation} from "./AttestationVerifier.sol";

interface ICTOVault {
    function recipientOf(address coin) external view returns (address);
    function ctoSetRecipient(address coin, address newRecipient) external;
}

/// @title CTOModule
/// @notice Community takeovers (CTO) of a coin's creator fees, decided by the IMD swarm. A takeover is proposed
///         with an IMD oracle attestation answering "yes" to this module's question for that exact coin and new
///         recipient. A 3-day public notice follows, then a 3-day window in which anyone executes it. The creator
///         moving fees during the notice does not cancel it. Fees accrued before execution go to the old recipient.
/// @dev Fallback until oracle attestations work on Robinhood Chain: the `council` (team Safe) can propose a
///      takeover without an attestation, with the same notice, and can cancel its own proposals. The owner (7-day
///      timelock) retires the council path once attestations work; that is one-way (D-46). Nobody can cancel an
///      attested takeover.
contract CTOModule is Ownable {
    using LibString for address;

    uint256 public constant NOTICE = 3 days;
    uint256 public constant EXECUTION_WINDOW = 3 days;

    struct Takeover {
        address newRecipient;
        uint64 executableAt;
        uint64 expiresAt;
        bool byCouncil;
    }

    ICTOVault public immutable creatorVault;
    /// @notice Public rules the oracle panel applies, named in every question.
    string public rulesURI;
    AttestationVerifier public verifier;
    address public council;
    bool public councilRetired;

    mapping(address coin => Takeover) internal _pending;
    mapping(bytes32 requestId => bool) public usedRequest;

    event Proposed(
        address indexed coin, address indexed newRecipient, uint256 executableAt, bytes32 requestId, string evidence
    );
    event Cancelled(address indexed coin);
    event Executed(address indexed coin, address indexed newRecipient);
    event VerifierUpdated(address verifier);
    event CouncilUpdated(address council);
    event CouncilRetired();

    error Pending();
    error NotPending();
    error NotYet();
    error WindowClosed();
    error UnknownCoin();
    error InvalidRecipient();
    error AnswerNo();
    error RequestUsed();
    error NotCouncil();
    error CannotRetire();

    constructor(address owner_, address creatorVault_, address verifier_, address council_, string memory rulesURI_) {
        _initializeOwner(owner_);
        creatorVault = ICTOVault(creatorVault_);
        verifier = AttestationVerifier(verifier_);
        council = council_;
        verifier.checkQuestionText(rulesURI_);
        rulesURI = rulesURI_;
    }

    /// @notice The exact yes/no question the oracle panel must answer for this takeover.
    function question(address coin, address newRecipient) public view returns (string memory) {
        return string.concat(
            "PondPad community takeover on chain id ",
            LibString.toString(block.chainid),
            ": under the PondPad takeover rules at ",
            rulesURI,
            ", should the creator fee recipient of coin ",
            coin.toHexString(),
            " be changed to ",
            newRecipient.toHexString(),
            "? Answer true only if every rule is met."
        );
    }

    /// @notice Proposes a takeover backed by an IMD oracle "yes". Anyone can submit it.
    function propose(address coin, address newRecipient, OracleAttestation calldata att, bytes calldata signature)
        external
    {
        if (usedRequest[att.requestId]) revert RequestUsed();
        usedRequest[att.requestId] = true;
        if (!verifier.verifyBool(att, signature, question(coin, newRecipient))) revert AnswerNo();
        _propose(coin, newRecipient, false, att.requestId, "");
    }

    /// @notice Fallback: the council proposes a takeover without an attestation, citing its evidence.
    function proposeByCouncil(address coin, address newRecipient, string calldata evidence) external {
        if (msg.sender != council || councilRetired) revert NotCouncil();
        _propose(coin, newRecipient, true, bytes32(0), evidence);
    }

    function _propose(address coin, address newRecipient, bool byCouncil, bytes32 requestId, string memory evidence)
        internal
    {
        address current = creatorVault.recipientOf(coin);
        if (current == address(0)) revert UnknownCoin();
        if (newRecipient == address(0) || newRecipient == current) revert InvalidRecipient();
        Takeover storage t = _pending[coin];
        if (t.newRecipient != address(0) && block.timestamp < t.expiresAt) revert Pending();
        uint256 executableAt = block.timestamp + NOTICE;
        _pending[coin] = Takeover({
            newRecipient: newRecipient,
            executableAt: uint64(executableAt),
            expiresAt: uint64(executableAt + EXECUTION_WINDOW),
            byCouncil: byCouncil
        });
        emit Proposed(coin, newRecipient, executableAt, requestId, evidence);
    }

    /// @notice Executes a takeover after its notice. Anyone can call it during the execution window.
    function execute(address coin) external {
        Takeover memory t = _pending[coin];
        if (t.newRecipient == address(0)) revert NotPending();
        if (block.timestamp < t.executableAt) revert NotYet();
        if (block.timestamp >= t.expiresAt) revert WindowClosed();
        delete _pending[coin];
        creatorVault.ctoSetRecipient(coin, t.newRecipient);
        emit Executed(coin, t.newRecipient);
    }

    /// @notice The council withdraws a takeover it proposed itself. Attested takeovers can't be cancelled.
    function cancel(address coin) external {
        Takeover memory t = _pending[coin];
        if (t.newRecipient == address(0) || block.timestamp >= t.expiresAt) revert NotPending();
        if (!t.byCouncil || msg.sender != council) revert NotCouncil();
        delete _pending[coin];
        emit Cancelled(coin);
    }

    function pendingOf(address coin) external view returns (Takeover memory) {
        return _pending[coin];
    }

    // ------------------------------------------------------------------ Settings (7-day timelock)

    function setVerifier(address verifier_) external onlyOwner {
        verifier = AttestationVerifier(verifier_);
        emit VerifierUpdated(verifier_);
    }

    function setCouncil(address council_) external onlyOwner {
        council = council_;
        emit CouncilUpdated(council_);
    }

    /// @notice Ends the council fallback forever. Only once the verifier has a signer.
    function retireCouncil() external onlyOwner {
        if (verifier.signerCount() == 0) revert CannotRetire();
        councilRetired = true;
        emit CouncilRetired();
    }
}
