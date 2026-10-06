// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "solady/auth/Ownable.sol";
import {LibString} from "solady/utils/LibString.sol";
import {AttestationVerifier, OracleAttestation} from "./AttestationVerifier.sol";

interface ICTOVault {
    function recipientOf(address coin) external view returns (address);
    function ctoSetRecipient(address coin, address newRecipient) external;
}

interface ICTOCurve {
    function coinLaunchedAt(address coin) external view returns (uint64);
}

interface ICTOSocial {
    function walletHandle(address account) external view returns (string memory);
}

/// @title CTOModule
/// @notice Community takeovers (CTO) of a coin's creator fees, decided by the IMD swarm under published rules.
///         - A proposer with a verified X account (SocialRegistry) submits an IMD oracle attestation answering "yes"
///           to this module's question for that exact coin, new recipient and proposer.
///         - The new recipient must be a contract: the community's multisig, or the coin itself, which routes the
///           creator fees to holders as IMD dividends (D-52).
///         - The coin must be at least 30 days old and not taken over in the last 90 days.
///         - A 3-day public notice follows. During it the current recipient can contest; a contested takeover then
///           needs a second "yes" from a panel of at least 75 members, and gets 7 more days.
///         - Then a 3-day window in which anyone executes it. Fees accrued before execution go to the old recipient.
/// @dev Fallback until oracle attestations work on Robinhood Chain: the `council` (team Safe) can propose without an
///      attestation, with a 7-day notice; it can cancel its own proposals, and confirms them itself if contested.
///      After a cancel the council waits 90 days before proposing for that coin again, and an attested proposal
///      replaces a pending council one (D-78, audit R1-A4-5). The owner (7-day timelock) retires the council path
///      once attestations work, one-way (D-46); council proposals still pending then can't execute. Nobody can
///      cancel an attested takeover. The rules link must be an `ipfs://` link, so the rules can't change (D-51).
contract CTOModule is Ownable {
    using LibString for address;

    uint256 public constant NOTICE = 3 days;
    uint256 public constant COUNCIL_NOTICE = 7 days;
    uint256 public constant EXECUTION_WINDOW = 3 days;
    uint256 public constant CONTEST_EXTENSION = 7 days;
    uint256 public constant COOLDOWN = 90 days;
    uint256 public constant MIN_COIN_AGE = 30 days;
    uint16 public constant CONFIRM_MIN_PANEL = 75;

    struct Takeover {
        address newRecipient;
        address proposer;
        uint64 executableAt;
        uint64 expiresAt;
        bool byCouncil;
        bool contested;
        bool confirmed;
        uint64 contestedAt;
    }

    ICTOVault public immutable creatorVault;
    ICTOCurve public immutable curve;
    ICTOSocial public immutable social;
    /// @notice Public rules the oracle panel applies (ipfs://), named in every question.
    string public rulesURI;
    AttestationVerifier public verifier;
    address public council;
    bool public councilRetired;

    mapping(address coin => Takeover) internal _pending;
    mapping(address coin => uint256) public lastTakeoverAt;
    /// @notice When the council last cancelled a proposal for the coin; it can't propose again for 90 days.
    mapping(address coin => uint256) public councilCancelledAt;
    /// @dev The proposer's X handle as it was at propose time; the confirmation question names the same one.
    mapping(address coin => string) internal _proposerX;
    mapping(bytes32 requestId => bool) public usedRequest;

    event Proposed(
        address indexed coin,
        address indexed newRecipient,
        address indexed proposer,
        string proposerX,
        uint256 executableAt,
        bytes32 requestId,
        string evidence
    );
    event Contested(address indexed coin, address indexed by, uint256 executableAt);
    event Confirmed(address indexed coin, bytes32 requestId);
    event Cancelled(address indexed coin);
    event Replaced(address indexed coin, address indexed councilRecipient);
    event Executed(address indexed coin, address indexed newRecipient, bool toHolders);
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
    error NoXAccount();
    error TooYoung();
    error Cooldown();
    error NotRecipient();
    error AlreadyContested();
    error NotContested();
    error PanelTooSmall();
    error BadRulesURI();
    error AnswerBeforeContest();

    constructor(
        address owner_,
        address creatorVault_,
        address curve_,
        address social_,
        address verifier_,
        address council_,
        string memory rulesURI_
    ) {
        _initializeOwner(owner_);
        creatorVault = ICTOVault(creatorVault_);
        curve = ICTOCurve(curve_);
        social = ICTOSocial(social_);
        verifier = AttestationVerifier(verifier_);
        council = council_;
        verifier.checkQuestionText(rulesURI_);
        if (!LibString.startsWith(rulesURI_, "ipfs://") || bytes(rulesURI_).length < 10) revert BadRulesURI();
        rulesURI = rulesURI_;
    }

    // ------------------------------------------------------------------ Questions

    /// @notice The exact yes/no question the oracle panel must answer for this takeover.
    function question(address coin, address newRecipient, string memory proposerX)
        public
        view
        returns (string memory)
    {
        return string.concat(
            _subject(proposerX),
            ": under the PondPad takeover rules at ",
            rulesURI,
            ", should the creator fees of coin ",
            coin.toHexString(),
            _destination(coin, newRecipient),
            "? Answer true only if every rule is met."
        );
    }

    /// @notice The question a second, larger panel answers when the current recipient contests.
    function confirmQuestion(address coin, address newRecipient, string memory proposerX)
        public
        view
        returns (string memory)
    {
        return string.concat(
            _subject(proposerX),
            ", contested by the current fee recipient: under the PondPad takeover rules at ",
            rulesURI,
            ", including the rules for contested takeovers, should the creator fees of coin ",
            coin.toHexString(),
            _destination(coin, newRecipient),
            "? Answer true only if every rule is met."
        );
    }

    function _subject(string memory proposerX) internal view returns (string memory) {
        return string.concat(
            "PondPad community takeover on chain id ",
            LibString.toString(block.chainid),
            " proposed by X account @",
            proposerX
        );
    }

    function _destination(address coin, address newRecipient) internal pure returns (string memory) {
        if (newRecipient == coin) return " be routed to the coin's holders as IMD dividends";
        return string.concat(" be routed to the community multisig ", newRecipient.toHexString());
    }

    // ------------------------------------------------------------------ Propose

    /// @notice Proposes a takeover backed by an IMD oracle "yes". The caller is the proposer and needs a verified
    ///         X account; the question names it.
    function propose(address coin, address newRecipient, OracleAttestation calldata att, bytes calldata signature)
        external
    {
        string memory handle = social.walletHandle(msg.sender);
        if (bytes(handle).length == 0) revert NoXAccount();
        _use(att.requestId);
        if (!verifier.verifyBool(att, signature, question(coin, newRecipient, handle))) revert AnswerNo();
        _propose(coin, newRecipient, msg.sender, handle, false, NOTICE, att.requestId, "");
    }

    /// @notice Fallback: the council proposes a takeover without an attestation, citing its evidence.
    function proposeByCouncil(address coin, address newRecipient, string calldata evidence) external {
        if (msg.sender != council || councilRetired) revert NotCouncil();
        uint256 cancelled = councilCancelledAt[coin];
        if (cancelled != 0 && block.timestamp < cancelled + COOLDOWN) revert Cooldown();
        _propose(coin, newRecipient, msg.sender, social.walletHandle(msg.sender), true, COUNCIL_NOTICE, 0, evidence);
    }

    function _propose(
        address coin,
        address newRecipient,
        address proposer,
        string memory handle,
        bool byCouncil,
        uint256 notice,
        bytes32 requestId,
        string memory evidence
    ) internal {
        address current = creatorVault.recipientOf(coin);
        if (current == address(0)) revert UnknownCoin();
        if (newRecipient == current || newRecipient.code.length == 0 || _isDelegatedAccount(newRecipient)) {
            revert InvalidRecipient();
        }
        if (block.timestamp < curve.coinLaunchedAt(coin) + MIN_COIN_AGE) revert TooYoung();
        uint256 last = lastTakeoverAt[coin];
        if (last != 0 && block.timestamp < last + COOLDOWN) revert Cooldown();
        Takeover storage t = _pending[coin];
        if (t.newRecipient != address(0) && block.timestamp < t.expiresAt) {
            // An attested proposal replaces a pending council one (audit R1-A4-5); anything else waits.
            if (byCouncil || !t.byCouncil) revert Pending();
            emit Replaced(coin, t.newRecipient);
        }
        uint256 executableAt = block.timestamp + notice;
        _pending[coin] = Takeover({
            newRecipient: newRecipient,
            proposer: proposer,
            executableAt: uint64(executableAt),
            expiresAt: uint64(executableAt + EXECUTION_WINDOW),
            byCouncil: byCouncil,
            contested: false,
            confirmed: false,
            contestedAt: 0
        });
        _proposerX[coin] = handle;
        emit Proposed(coin, newRecipient, proposer, handle, executableAt, requestId, evidence);
    }

    // ------------------------------------------------------------------ Contest

    /// @notice The current fee recipient contests a takeover during its notice. It then needs a confirming "yes"
    ///         from a larger panel (or the council, for its own proposals) and waits 7 more days.
    function contest(address coin) external {
        Takeover storage t = _pending[coin];
        if (t.newRecipient == address(0) || block.timestamp >= t.executableAt) revert NotPending();
        if (msg.sender != creatorVault.recipientOf(coin)) revert NotRecipient();
        if (t.contested) revert AlreadyContested();
        t.contested = true;
        t.contestedAt = uint64(block.timestamp);
        t.executableAt += uint64(CONTEST_EXTENSION);
        t.expiresAt += uint64(CONTEST_EXTENSION);
        emit Contested(coin, msg.sender, t.executableAt);
    }

    /// @notice Confirms a contested attested takeover with a second "yes" from a panel of at least 75. Anyone.
    ///         The answer must be issued after the contest (audit R1-A4-3) and names the X account the takeover
    ///         was proposed under, whatever the proposer's link says now (R1-A4-2).
    function confirm(address coin, OracleAttestation calldata att, bytes calldata signature) external {
        Takeover storage t = _pending[coin];
        _checkConfirmable(t);
        if (t.byCouncil) revert NotCouncil();
        if (att.panelSize < CONFIRM_MIN_PANEL) revert PanelTooSmall();
        if (att.issuedAt < t.contestedAt) revert AnswerBeforeContest();
        _use(att.requestId);
        string memory q = confirmQuestion(coin, t.newRecipient, _proposerX[coin]);
        if (!verifier.verifyBool(att, signature, q)) revert AnswerNo();
        t.confirmed = true;
        emit Confirmed(coin, att.requestId);
    }

    /// @notice Fallback: the council confirms its own contested proposal, while the council path is open.
    function confirmByCouncil(address coin) external {
        Takeover storage t = _pending[coin];
        _checkConfirmable(t);
        if (!t.byCouncil || msg.sender != council || councilRetired) revert NotCouncil();
        t.confirmed = true;
        emit Confirmed(coin, bytes32(0));
    }

    function _checkConfirmable(Takeover storage t) internal view {
        if (t.newRecipient == address(0) || block.timestamp >= t.expiresAt) revert NotPending();
        if (!t.contested || t.confirmed) revert NotContested();
    }

    // ------------------------------------------------------------------ Execute / cancel

    /// @notice Executes a takeover after its notice (and confirmation, if contested). Anyone, during the window.
    function execute(address coin) external {
        Takeover memory t = _pending[coin];
        if (t.newRecipient == address(0)) revert NotPending();
        if (block.timestamp < t.executableAt) revert NotYet();
        if (block.timestamp >= t.expiresAt) revert WindowClosed();
        if (t.contested && !t.confirmed) revert NotContested();
        // A retired council path can't land a proposal made before retirement (audit R1-A4-9).
        if (t.byCouncil && councilRetired) revert NotCouncil();
        delete _pending[coin];
        lastTakeoverAt[coin] = block.timestamp;
        creatorVault.ctoSetRecipient(coin, t.newRecipient);
        emit Executed(coin, t.newRecipient, t.newRecipient == coin);
    }

    /// @notice The council withdraws a takeover it proposed itself. Attested takeovers can't be cancelled.
    function cancel(address coin) external {
        Takeover memory t = _pending[coin];
        if (t.newRecipient == address(0) || block.timestamp >= t.expiresAt) revert NotPending();
        if (!t.byCouncil || msg.sender != council) revert NotCouncil();
        delete _pending[coin];
        councilCancelledAt[coin] = block.timestamp;
        emit Cancelled(coin);
    }

    function pendingOf(address coin) external view returns (Takeover memory) {
        return _pending[coin];
    }

    /// @notice The X account the pending takeover was proposed under (named by its confirmation question).
    function proposerXOf(address coin) external view returns (string memory) {
        return _proposerX[coin];
    }

    /// @dev A wallet carrying an EIP-7702 delegation has 23 bytes of code (0xef0100 + target) but is still one key
    ///      (audit R1-A4-10). It is not a contract recipient.
    function _isDelegatedAccount(address a) internal view returns (bool) {
        if (a.code.length != 23) return false;
        bytes memory c = a.code;
        return c[0] == 0xef && c[1] == 0x01 && c[2] == 0x00;
    }

    function _use(bytes32 requestId) internal {
        if (usedRequest[requestId]) revert RequestUsed();
        usedRequest[requestId] = true;
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
