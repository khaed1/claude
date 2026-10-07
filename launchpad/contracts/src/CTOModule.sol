// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {FixedOwnable} from "./FixedOwnable.sol";
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
///         - A proposer with a verified X account (SocialRegistry) first announces the takeover onchain from its
///           wallet (`announce`: the coin, the new recipient and its X account, i.e. the whole question), then
///           submits an IMD oracle attestation answering "yes" to this module's question for that exact coin, new
///           recipient and proposer, issued at least 7 days after the announcement (CTO-RULES R1 / R5).
///           The X handle is lowercased in every question and key (X handles are case-insensitive), so another
///           casing is the same question (audit P4-2, D-81).
///         - The new recipient must be a contract: the community's multisig, or the coin itself, which routes the
///           creator fees to holders as IMD dividends (D-52). That choice is final: a coin whose fees go to its
///           holders can't be taken over again (audit R1-A4-12: nobody could contest it). The recipient is
///           checked again, code included, at execution (audit R2-A4-6).
///         - The coin must be at least 30 days old and not taken over in the last 90 days.
///         - A 3-day public notice follows. During it the current recipient can contest; a contested takeover then
///           needs a second "yes" from a panel of at least 75 members, and gets 7 more days.
///         - Then a 3-day window in which anyone executes it. Fees accrued before execution go to the old recipient.
/// @dev Fallback until oracle attestations work on Robinhood Chain: the `council` (team Safe) can propose without an
///      attestation, with a 7-day notice; it can cancel its own proposals, and confirms them itself if contested.
///      After a cancel the council waits 90 days before proposing for that coin again, and an attested proposal
///      replaces a pending council one (D-78, audit R1-A4-5); a contested council proposal that lapses unconfirmed
///      waits the same 90 days (audit R3-A4-7). The owner (7-day timelock) retires the council path
///      once attestations work, one-way (D-46); council proposals still pending then can't execute. Nobody can
///      cancel an attested takeover, but a "no" can end one: anyone records a valid "no" (same bar as a "yes"); a
///      "no" to the takeover question blocks every "yes" to it issued before it or in the 90 days after it (audit
///      P4-1) and ends a pending takeover whose "yes" was issued at or after it, within 90 days; a "no" to the
///      confirmation question ends a contested takeover unless an earlier "yes" already confirmed it (audit R3-A4-8:
///      otherwise the question could be re-asked until one panel said yes). Like a "yes", a "no" to the takeover
///      question counts only if issued at least 7 days after the announcement, so a "no" asked before the rules'
///      notice is over (which the panel must give) can't block or end anything (audit P4-3, D-81). A takeover ended
///      by a confirmation "no" blocks new proposals for that coin for 90 days. The rules link must be an `ipfs://`
///      link, so the rules can't change (D-51).
contract CTOModule is FixedOwnable {
    using LibString for address;

    uint256 public constant NOTICE = 3 days;
    uint256 public constant COUNCIL_NOTICE = 7 days;
    uint256 public constant EXECUTION_WINDOW = 3 days;
    uint256 public constant CONTEST_EXTENSION = 7 days;
    uint256 public constant COOLDOWN = 90 days;
    uint256 public constant MIN_COIN_AGE = 30 days;
    uint16 public constant CONFIRM_MIN_PANEL = 75;
    /// @notice A recorded "no" blocks "yes" answers to the same question issued before it or up to this long after
    ///         it (audits R3-A4-8, P4-1).
    uint256 public constant NO_ANSWER_HOLD = 90 days;
    /// @notice An answer to a takeover question counts only if issued this long after the question was announced
    ///         onchain (CTO-RULES R1 / R5; audit P4-3, D-81).
    uint256 public constant ANNOUNCE_NOTICE = 7 days;
    /// @notice Longest rules link: every takeover question must fit the verifier's 2,000-character limit (R2-A4-7).
    uint256 public constant MAX_RULES_URI = 256;

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
    /// @dev The proposer's X handle (lowercased) as it was at propose time; the confirmation question names it.
    mapping(address coin => string) internal _proposerX;
    mapping(bytes32 requestId => bool) public usedRequest;
    /// @dev The new recipient's code hash at propose; execute requires the same code (audit R2-A4-6).
    mapping(address coin => bytes32) internal _recipientCodehash;
    /// @notice Latest `issuedAt` of a valid "no" recorded for a takeover question (`questionKey`) (audit R3-A4-8).
    mapping(bytes32 questionKey => uint64) public answeredNoAt;
    /// @notice When the takeover question (`questionKey`) was announced onchain by the proposer's wallet; set once
    ///         (audit P4-3, D-81).
    mapping(bytes32 questionKey => uint64) public announcedAt;
    /// @notice When a takeover of the coin was last ended by a confirmation "no": no new proposal for 90 days (audit
    ///         R3-A4-8; only a confirmation "no" since D-81, as it can't be asked before the contest).
    mapping(address coin => uint256) public endedByNoAt;
    /// @dev `issuedAt` of the "yes" behind the coin's pending attested proposal, and of the "yes" that confirmed it.
    mapping(address coin => uint64) internal _yesIssuedAt;
    mapping(address coin => uint64) internal _confirmIssuedAt;

    event Proposed(
        address indexed coin,
        address indexed newRecipient,
        address indexed proposer,
        string proposerX,
        uint256 executableAt,
        bytes32 requestId,
        string evidence
    );
    event Announced(
        address indexed coin,
        address indexed newRecipient,
        address indexed proposer,
        string proposerX,
        bytes32 questionKey
    );
    event Contested(address indexed coin, address indexed by, uint256 executableAt);
    event Confirmed(address indexed coin, bytes32 requestId);
    event Cancelled(address indexed coin);
    event AnsweredNo(address indexed coin, bytes32 indexed requestId, address newRecipient, uint64 issuedAt, bool confirmation);
    event EndedByNo(address indexed coin);
    event Replaced(address indexed coin, address indexed councilRecipient);
    event Executed(address indexed coin, address indexed newRecipient, bool toHolders);
    event VerifierUpdated(address verifier);
    event CouncilUpdated(address council);
    event CouncilRetired();
    /// @notice The evidence chain and block window of an attestation used here (audit R2-A4-4).
    event AttestationWindow(address indexed coin, bytes32 indexed requestId, uint256 chainId, uint64 fromBlock, uint64 toBlock);

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
    error FeesGoToHolders();
    error AnswerYes();
    error BlockedByNo();
    error TooLate();
    error NotAnnounced();
    error AlreadyAnnounced();
    error AnswerBeforeNotice();

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
        if (
            !LibString.startsWith(rulesURI_, "ipfs://") || bytes(rulesURI_).length < 10
                || bytes(rulesURI_).length > MAX_RULES_URI
        ) revert BadRulesURI();
        rulesURI = rulesURI_;
    }

    // ------------------------------------------------------------------ Questions

    /// @notice The exact yes/no question the oracle panel must answer for this takeover. `proposerX` is lowercased,
    ///         so every casing of a handle gives the same question (audit P4-2).
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

    /// @notice The question a second, larger panel answers when the current recipient contests. It names the time
    ///         of the contest, so it can't be asked before the contest happens (audit R2-A4-5); reverts until then.
    function confirmQuestion(address coin, address newRecipient, string memory proposerX)
        public
        view
        returns (string memory)
    {
        uint256 contestedAt = _pending[coin].contestedAt;
        if (contestedAt == 0) revert NotContested();
        return string.concat(
            _subject(proposerX),
            ", contested by the current fee recipient at unix time ",
            LibString.toString(contestedAt),
            ": under the PondPad takeover rules at ",
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
            LibString.lower(proposerX)
        );
    }

    function _destination(address coin, address newRecipient) internal pure returns (string memory) {
        if (newRecipient == coin) return " be routed to the coin's holders as IMD dividends";
        return string.concat(" be routed to the community multisig ", newRecipient.toHexString());
    }

    // ------------------------------------------------------------------ Announce / propose

    /// @notice The proposer's wallet announces a takeover onchain: the coin, the new recipient and the caller's
    ///         linked X account, i.e. the whole takeover question (CTO-RULES R1 / R5). Recorded once per question; a
    ///         later call can't move it. A "yes" or a "no" to the question counts only if issued at least 7 days after
    ///         it, so a "no" asked before the notice is over can't block or end the takeover (audit P4-3, D-81).
    function announce(address coin, address newRecipient) external {
        string memory handle = LibString.lower(social.walletHandle(msg.sender));
        if (bytes(handle).length == 0) revert NoXAccount();
        if (creatorVault.recipientOf(coin) == address(0)) revert UnknownCoin();
        if (newRecipient.code.length == 0 || _isDelegatedAccount(newRecipient)) revert InvalidRecipient();
        bytes32 key = _questionKey(coin, newRecipient, handle);
        if (announcedAt[key] != 0) revert AlreadyAnnounced();
        announcedAt[key] = uint64(block.timestamp);
        emit Announced(coin, newRecipient, msg.sender, handle, key);
    }

    /// @notice Proposes a takeover backed by an IMD oracle "yes". The caller is the proposer and needs a verified
    ///         X account; the question names it. The "yes" must be issued at least 7 days after the caller's X account
    ///         announced this takeover (`announce`).
    function propose(address coin, address newRecipient, OracleAttestation calldata att, bytes calldata signature)
        external
    {
        string memory handle = LibString.lower(social.walletHandle(msg.sender));
        if (bytes(handle).length == 0) revert NoXAccount();
        _use(att.requestId);
        if (!verifier.verifyBool(att, signature, question(coin, newRecipient, handle))) revert AnswerNo();
        bytes32 key = _questionKey(coin, newRecipient, handle);
        _checkNotice(key, att.issuedAt);
        if (_blockedByNo(att.issuedAt, answeredNoAt[key])) revert BlockedByNo();
        emit AttestationWindow(coin, att.requestId, att.chainId, att.fromBlock, att.toBlock);
        _propose(coin, newRecipient, msg.sender, handle, false, NOTICE, att.requestId, "");
        _yesIssuedAt[coin] = att.issuedAt;
    }

    /// @notice Fallback: the council proposes a takeover without an attestation, citing its evidence.
    function proposeByCouncil(address coin, address newRecipient, string calldata evidence) external {
        if (msg.sender != council || councilRetired) revert NotCouncil();
        uint256 cancelled = councilCancelledAt[coin];
        if (cancelled != 0 && block.timestamp < cancelled + COOLDOWN) revert Cooldown();
        // A contested council proposal that lapsed unconfirmed waits like a cancel, so letting it lapse can't wipe
        // the contest sooner than withdrawing it would (audit R3-A4-7).
        Takeover storage last = _pending[coin];
        if (
            last.byCouncil && last.contested && !last.confirmed && block.timestamp >= last.expiresAt
                && block.timestamp < uint256(last.expiresAt) + COOLDOWN
        ) revert Cooldown();
        string memory handle = LibString.lower(social.walletHandle(msg.sender));
        _propose(coin, newRecipient, msg.sender, handle, true, COUNCIL_NOTICE, 0, evidence);
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
        if (current == coin) revert FeesGoToHolders(); // final (audit R1-A4-12)
        if (newRecipient == current || newRecipient.code.length == 0 || _isDelegatedAccount(newRecipient)) {
            revert InvalidRecipient();
        }
        if (block.timestamp < curve.coinLaunchedAt(coin) + MIN_COIN_AGE) revert TooYoung();
        uint256 last = lastTakeoverAt[coin];
        if (last != 0 && block.timestamp < last + COOLDOWN) revert Cooldown();
        uint256 ended = endedByNoAt[coin];
        if (ended != 0 && block.timestamp < ended + COOLDOWN) revert Cooldown(); // audit R3-A4-8 (confirmation "no")
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
        _recipientCodehash[coin] = newRecipient.codehash;
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
        emit AttestationWindow(coin, att.requestId, att.chainId, att.fromBlock, att.toBlock);
        t.confirmed = true;
        _confirmIssuedAt[coin] = att.issuedAt;
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

    // ------------------------------------------------------------------ "No" answers (audit R3-A4-8)

    /// @notice Key of a takeover question: the coin, the new recipient and the proposer's X handle it names
    ///         (lowercased, audit P4-2).
    function questionKey(address coin, address newRecipient, string memory proposerX) public pure returns (bytes32) {
        return _questionKey(coin, newRecipient, LibString.lower(proposerX));
    }

    function _questionKey(address coin, address newRecipient, string memory lowerX) internal pure returns (bytes32) {
        return keccak256(abi.encode(coin, newRecipient, lowerX));
    }

    /// @notice Anyone records a valid "no" (it must meet the same bar as a "yes") to the takeover question for `coin`,
    ///         `newRecipient` and `proposerX`, issued at least 7 days after the question was announced (a "no" asked
    ///         earlier is refused: the rules' notice wasn't over, audit P4-3). A "yes" to that question issued before
    ///         this "no" or in the 90 days after it can't be used (P4-1), and a pending attested takeover whose
    ///         "yes" was issued at or after this "no", within 90 days, ends. The coin itself isn't blocked (D-81).
    function recordNo(
        address coin,
        address newRecipient,
        string calldata proposerX,
        OracleAttestation calldata att,
        bytes calldata signature
    ) external {
        string memory handle = LibString.lower(proposerX);
        _use(att.requestId);
        if (verifier.verifyBool(att, signature, question(coin, newRecipient, handle))) revert AnswerYes();
        bytes32 key = _questionKey(coin, newRecipient, handle);
        _checkNotice(key, att.issuedAt);
        emit AttestationWindow(coin, att.requestId, att.chainId, att.fromBlock, att.toBlock);
        if (att.issuedAt > answeredNoAt[key]) answeredNoAt[key] = att.issuedAt;
        emit AnsweredNo(coin, att.requestId, newRecipient, att.issuedAt, false);
        Takeover storage t = _pending[coin];
        if (
            t.newRecipient == newRecipient && newRecipient != address(0) && !t.byCouncil
                && block.timestamp < t.expiresAt && keccak256(bytes(_proposerX[coin])) == keccak256(bytes(handle))
                && _endsByNo(_yesIssuedAt[coin], att.issuedAt)
        ) _endByNo(coin, false);
    }

    /// @notice Anyone records a valid "no" from a panel of at least 75, issued after the contest, to the pending
    ///         takeover's confirmation question: the takeover ends, unless a "yes" issued before this "no" already
    ///         confirmed it, and the coin can't be proposed again for 90 days.
    function recordConfirmNo(address coin, OracleAttestation calldata att, bytes calldata signature) external {
        Takeover storage t = _pending[coin];
        if (t.newRecipient == address(0) || block.timestamp >= t.expiresAt) revert NotPending();
        if (!t.contested) revert NotContested();
        if (t.byCouncil) revert NotCouncil();
        if (att.panelSize < CONFIRM_MIN_PANEL) revert PanelTooSmall();
        if (att.issuedAt < t.contestedAt) revert AnswerBeforeContest();
        _use(att.requestId);
        string memory q = confirmQuestion(coin, t.newRecipient, _proposerX[coin]);
        if (verifier.verifyBool(att, signature, q)) revert AnswerYes();
        emit AttestationWindow(coin, att.requestId, att.chainId, att.fromBlock, att.toBlock);
        if (t.confirmed && _confirmIssuedAt[coin] < att.issuedAt) revert TooLate();
        emit AnsweredNo(coin, att.requestId, t.newRecipient, att.issuedAt, true);
        _endByNo(coin, true);
    }

    /// @dev An answer to the takeover question counts only once the question was announced onchain at least
    ///      `ANNOUNCE_NOTICE` before it was issued (audit P4-3).
    function _checkNotice(bytes32 key, uint64 issuedAt) internal view {
        uint256 announced = announcedAt[key];
        if (announced == 0) revert NotAnnounced();
        if (issuedAt < announced + ANNOUNCE_NOTICE) revert AnswerBeforeNotice();
    }

    /// @dev A "yes" doesn't count while a recorded "no" to the same question was issued after it or less than
    ///      `NO_ANSWER_HOLD` before it (audit P4-1). Only the latest "no" is kept: an earlier one is older still, so if
    ///      the latest is 90 days older than the "yes", every one is.
    function _blockedByNo(uint64 yesAt, uint64 noAt) internal pure returns (bool) {
        return noAt != 0 && uint256(yesAt) < uint256(noAt) + NO_ANSWER_HOLD;
    }

    /// @dev A recorded "no" ends a pending takeover only if its "yes" was issued at or after the "no", within
    ///      `NO_ANSWER_HOLD` of it: a "no" issued after the "yes" doesn't undo a proposal (the creator contests).
    function _endsByNo(uint64 yesAt, uint64 noAt) internal pure returns (bool) {
        return yesAt >= noAt && uint256(yesAt) < uint256(noAt) + NO_ANSWER_HOLD;
    }

    /// @dev Only a confirmation "no" (asked after the contest, panel >= 75) blocks the coin for 90 days (D-81).
    function _endByNo(address coin, bool confirmation) internal {
        delete _pending[coin];
        if (confirmation) endedByNoAt[coin] = block.timestamp;
        emit EndedByNo(coin);
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
        // Fees routed to holders during the notice stay with the holders (audit R1-A4-12: final, nobody could contest).
        if (creatorVault.recipientOf(coin) == coin) revert FeesGoToHolders();
        // Still the same contract that was proposed: not emptied (EIP-6780 self-destruct in its creation
        // transaction), not redeployed with other code, not an EIP-7702 wallet (audit R2-A4-6).
        if (
            t.newRecipient.code.length == 0 || _isDelegatedAccount(t.newRecipient)
                || t.newRecipient.codehash != _recipientCodehash[coin]
        ) revert InvalidRecipient();
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
