// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {OracleAttestation} from "./OracleAttestation.sol";

/// @title IOracleGovernor
/// @notice Docket's per-project module. A project's Safe enables it with a list of mandates (bounded powers). Anyone
///         proposes an action under a mandate with a bond; an IMD oracle panel answers a question the module builds
///         itself; a "yes" queues the action behind a timelock in which the guardian or locked holder tokens can
///         veto it; then anyone executes it through the Safe. See `swarm-steward/SPEC.md`.
interface IOracleGovernor {
    // ------------------------------------------------------------------ Types

    /// @notice What one argument of a mandate's function is and where its value comes from.
    /// - `Uint`, `Address`, `Bytes32`, `Bool`: a static value the proposer supplies, checked by the rule.
    /// - `ProposalId`: filled in by the module with the action id (as a `uint256`/`bytes32` word).
    /// - `Evidence`: filled in by the module with the proposal's evidence link (as a `string`). At most one.
    enum ArgKind {
        Uint,
        Address,
        Bytes32,
        Bool,
        ProposalId,
        Evidence
    }

    /// @notice How a proposer-supplied value is bounded. `Range` is for `Uint` only (min ≤ value ≤ max);
    ///         `Equal` means value == min.
    enum Check {
        Any,
        Equal,
        Range
    }

    struct ArgRule {
        ArgKind kind;
        Check check;
        uint256 min;
        uint256 max;
        /// @notice Name shown in the question, e.g. "amount_wei".
        string label;
    }

    /// @notice A bounded power. Immutable once added: to change one, add a new mandate and disable the old one.
    struct Mandate {
        /// @notice Contract the Safe calls.
        address target;
        /// @notice Canonical function signature, e.g. "grant(address,address,uint256,bytes32,string)". The
        ///         selector is computed from it, and it is quoted in the question.
        string signature;
        /// @notice Short name quoted in the question, e.g. "growth grant".
        string name;
        /// @notice Where the rules for this decision are in the charter, e.g. "section Grants".
        string ruleRef;
        /// @notice Index of the `Uint` argument that counts against `capPerEpoch`, or `NO_CAP`.
        uint8 capArg;
        uint256 capPerEpoch;
        uint32 epochLength;
        /// @notice Minimum time between two executions of this mandate (0 = no limit).
        uint32 minInterval;
        /// @notice Time after proposing in which a "yes" must be submitted.
        uint32 answerWindow;
        /// @notice Timelock after the "yes", during which the action can be vetoed.
        uint32 delay;
        /// @notice Window after the timelock in which anyone can execute.
        uint32 executionWindow;
        /// @notice Smallest accepted panel, and the share of the panel that must give the answer (bps).
        uint16 minPanel;
        uint16 minAgreementBps;
        /// @notice Holder veto quorum: locked weight needed to cancel, in bps of the veto base token's total supply.
        ///         0 = holders can't veto this mandate (the guardian still can).
        uint16 vetoBps;
        /// @notice Proposer bond in the bond token.
        uint256 bond;
    }

    enum Kind {
        Mandate,
        Config
    }

    enum Status {
        None,
        Proposed, // waiting for the panel's answer (mandate actions only)
        Queued, // in the timelock, or executable
        Executed,
        Cancelled, // by the guardian, a holder veto, the Safe (config only) or an earlier "no"
        Rejected, // the panel answered "no"
        Expired // no answer in time, or not executed in time
    }

    struct Action {
        Kind kind;
        Status status;
        uint32 mandateId;
        address proposer;
        uint64 createdAt;
        uint64 answerBy;
        uint64 executableAt;
        uint64 expiresAt;
        /// @notice `issuedAt` of the accepted "yes".
        uint64 yesIssuedAt;
        uint16 vetoBps;
        uint256 bond;
        /// @notice Locked weight needed to cancel (fixed when queued; 0 = no holder veto).
        uint256 vetoQuorum;
        uint256 vetoWeight;
        /// @notice Charter link in force when proposed; the question names this one.
        string charter;
        string evidence;
        uint256[] words;
        /// @notice For config actions: the call to this module.
        bytes configCall;
    }

    enum VetoKind {
        None,
        Base, // counts 1:1
        Vault // an ERC-4626 vault of the base token; counts its shares' assets
    }

    // ------------------------------------------------------------------ Events

    event Proposed(uint256 indexed id, uint32 indexed mandateId, address indexed proposer, string question);
    event Answered(uint256 indexed id, bytes32 indexed requestId, bool yes);
    event Queued(uint256 indexed id, uint256 executableAt, uint256 expiresAt, uint256 vetoQuorum);
    event ConfigProposed(uint256 indexed id, bytes call, uint256 executableAt);
    event VetoLocked(uint256 indexed id, address indexed holder, address indexed token, uint256 amount, uint256 weight);
    event VetoUnlocked(uint256 indexed id, address indexed holder, address indexed token, uint256 amount);
    event Cancelled(uint256 indexed id, address indexed by);
    event Vetoed(uint256 indexed id, uint256 weight);
    event Executed(uint256 indexed id);
    event Expired(uint256 indexed id);
    event MandateAdded(uint32 indexed mandateId, address indexed target, bytes4 selector, string name);
    event MandateDisabled(uint32 indexed mandateId);
    event GuardianSet(address guardian);
    event SignerSet(address indexed signer, bool approved);
    event VetoTokenSet(address indexed token, VetoKind kind);
    event CharterSet(string charter);
    event ConfigRulesSet(uint32 delay, uint32 executionWindow, uint16 vetoBps);

    // ------------------------------------------------------------------ Errors

    error Unauthorized();
    error InvalidSetting();
    error InvalidMandate();
    error MandateInactive();
    error BadArgs();
    error OutOfBounds(uint256 index);
    error AboveCap();
    error TooSoon();
    error WrongStatus();
    error NotYet();
    error TooLate();
    error UnknownSigner();
    error WrongQuestion();
    error NotBool();
    error PanelTooSmall();
    error NotEnoughAgreement();
    error StaleAnswer();
    error RequestUsed();
    error NoVeto();
    error SafeCallFailed(bytes reason);

    // ------------------------------------------------------------------ Mandate actions (anyone)

    /// @notice Proposes an action under `mandateId`, posting the mandate's bond. `words` has one entry per argument
    ///         (0 for `ProposalId` and `Evidence`). `evidence` is an `ipfs://` link. Returns the action id.
    function propose(uint32 mandateId, uint256[] calldata words, string calldata evidence) external returns (uint256);

    /// @notice Submits the panel's answer to `question(id)`. Anyone can submit any valid answer:
    ///         - while proposed: "yes" queues the action, "no" rejects it; the bond is refunded either way;
    ///         - while queued: a "no" issued no later than the accepted "yes" cancels it (answer shopping).
    function submitAnswer(uint256 id, OracleAttestation calldata att, bytes calldata signature) external;

    /// @notice Executes a queued action after its timelock, within its execution window. Anyone.
    function execute(uint256 id) external;

    /// @notice Marks an action expired: unanswered after `answerBy` (the bond goes to the Safe), or not executed by
    ///         `expiresAt`. Anyone.
    function expire(uint256 id) external;

    // ------------------------------------------------------------------ Veto

    /// @notice Locks `amount` of a veto token against a queued action until its timelock ends. When the locked weight
    ///         reaches the action's quorum it is cancelled at once. Locks only come back after the timelock.
    function lockVeto(uint256 id, address token, uint256 amount) external;

    /// @notice Returns the caller's locked `token` for `id`, once the action's timelock has ended.
    function unlockVeto(uint256 id, address token) external;

    /// @notice The guardian cancels any proposed or queued action; the Safe cancels its own config changes.
    function cancel(uint256 id) external;

    // ------------------------------------------------------------------ Safe

    /// @notice The Safe proposes a change to this module (`call` is one of the config functions below). It waits the
    ///         config timelock, can be vetoed like any action, then anyone executes it.
    function proposeConfig(bytes calldata call) external returns (uint256);

    /// @notice The Safe or the guardian switches a mandate off at once. Queued actions under it can't execute.
    function disableMandate(uint32 mandateId) external;

    // ------------------------------------------------------------------ Config (only through `proposeConfig`)

    function addMandate(Mandate calldata m, ArgRule[] calldata args) external returns (uint32);
    function setGuardian(address guardian) external;
    function setSigner(address signer, bool approved) external;
    function setVetoToken(address token, VetoKind kind) external;
    function setCharter(string calldata charter) external;
    function setConfigRules(uint32 delay, uint32 executionWindow, uint16 vetoBps) external;

    // ------------------------------------------------------------------ Views

    /// @notice The exact yes/no question the panel must answer for action `id`.
    function question(uint256 id) external view returns (string memory);

    /// @notice The call the Safe will make for action `id`.
    function callData(uint256 id) external view returns (address target, bytes memory data);

    function actionOf(uint256 id) external view returns (Action memory);
    function mandateOf(uint32 mandateId) external view returns (Mandate memory, ArgRule[] memory, bool active);
}
