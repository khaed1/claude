// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {EIP712} from "solady/utils/EIP712.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {LibString} from "solady/utils/LibString.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {IOracleGovernor} from "./IOracleGovernor.sol";
import {OracleAttestation, OracleAttestationLib} from "./OracleAttestation.sol";

interface ISafe {
    function execTransactionFromModuleReturnData(address to, uint256 value, bytes calldata data, uint8 operation)
        external
        returns (bool success, bytes memory returnData);
}

interface IERC20Supply {
    function totalSupply() external view returns (uint256);
}

interface IERC4626Assets {
    function asset() external view returns (address);
    function convertToAssets(uint256 shares) external view returns (uint256);
}

/// @title OracleGovernor
/// @notice Docket's module for one project. The project's Safe enables it; it can only make the calls its mandates
///         allow, within their bounds, caps and rate limits, after an IMD panel "yes" and a timelock. It never uses
///         delegatecall and never sends ETH. See `IOracleGovernor` and `swarm-steward/SPEC.md`.
/// @dev Verifies IMD attestations itself: the EIP-712 domain is {"IdentityMD Oracle", "2", chainId, this module}, so
///      oracle requests name this module as their `consumer`. Signers and everything else change only through
///      `proposeConfig` (Safe proposes, config timelock, veto, anyone executes). Immutable, no proxy.
contract OracleGovernor is IOracleGovernor, EIP712, ReentrancyGuard {
    using LibString for uint256;
    using LibString for address;

    uint8 public constant NO_CAP = type(uint8).max;
    uint256 public constant MAX_ARGS = 12;
    uint256 public constant MAX_LABEL = 64;
    uint256 public constant MAX_NAME = 200;
    uint256 public constant MAX_EVIDENCE = 200;
    uint16 public constant MIN_AGREEMENT_FLOOR_BPS = 5_001;

    address public immutable safe;
    address public immutable bondToken;
    address public immutable vetoBase;
    /// @notice Project name quoted in every question.
    string public projectName;

    address public guardian;
    /// @notice Current charter (`ipfs://`). Each action keeps the one in force when it was proposed.
    string public charter;
    uint32 public configDelay;
    uint32 public configExecutionWindow;
    uint16 public configVetoBps;

    mapping(address => bool) public isSigner;
    uint256 public signerCount;
    mapping(address token => VetoKind) public vetoKind;

    uint32 public mandateCount;
    mapping(uint32 => Mandate) internal _mandates;
    mapping(uint32 => ArgRule[]) internal _args;
    mapping(uint32 => bool) public mandateActive;
    mapping(uint32 mandateId => mapping(uint256 epoch => uint256)) public spent;
    mapping(uint32 mandateId => uint256) public lastExecutedAt;

    uint256 public actionCount;
    mapping(uint256 => Action) internal _actions;
    mapping(bytes32 requestId => bool) public usedRequest;
    mapping(uint256 id => mapping(address holder => mapping(address token => uint256))) public locked;

    modifier onlySelf() {
        if (msg.sender != address(this)) revert Unauthorized();
        _;
    }

    constructor(
        address safe_,
        address guardian_,
        address bondToken_,
        address vetoBase_,
        string memory projectName_,
        string memory charter_,
        address signer_,
        uint32 configDelay_,
        uint32 configExecutionWindow_,
        uint16 configVetoBps_
    ) {
        if (safe_ == address(0) || bondToken_ == address(0) || vetoBase_ == address(0)) revert InvalidSetting();
        OracleAttestationLib.checkText(projectName_, MAX_NAME);
        safe = safe_;
        bondToken = bondToken_;
        vetoBase = vetoBase_;
        projectName = projectName_;
        _setGuardian(guardian_);
        _setCharter(charter_);
        _setSigner(signer_, true);
        _setConfigRules(configDelay_, configExecutionWindow_, configVetoBps_);
        vetoKind[vetoBase_] = VetoKind.Base;
        emit VetoTokenSet(vetoBase_, VetoKind.Base);
    }

    function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
        return ("IdentityMD Oracle", "2");
    }

    // ------------------------------------------------------------------ Mandate actions

    /// @inheritdoc IOracleGovernor
    function propose(uint32 mandateId, uint256[] calldata words, string calldata evidence)
        external
        nonReentrant
        returns (uint256 id)
    {
        if (!mandateActive[mandateId]) revert MandateInactive();
        Mandate storage m = _mandates[mandateId];
        _checkLink(evidence, MAX_EVIDENCE);
        _checkWords(mandateId, words);
        if (m.capArg != NO_CAP && words[m.capArg] > m.capPerEpoch) revert AboveCap();

        id = ++actionCount;
        Action storage a = _actions[id];
        a.kind = Kind.Mandate;
        a.status = Status.Proposed;
        a.mandateId = mandateId;
        a.proposer = msg.sender;
        a.createdAt = uint64(block.timestamp);
        a.answerBy = uint64(block.timestamp + m.answerWindow);
        a.vetoBps = m.vetoBps;
        a.bond = m.bond;
        a.charter = charter;
        a.evidence = evidence;
        a.words = words;
        if (m.bond != 0) SafeTransferLib.safeTransferFrom(bondToken, msg.sender, address(this), m.bond);
        emit Proposed(id, mandateId, msg.sender, question(id));
    }

    /// @inheritdoc IOracleGovernor
    function submitAnswer(uint256 id, OracleAttestation calldata att, bytes calldata signature)
        external
        nonReentrant
    {
        Action storage a = _actions[id];
        if (a.kind != Kind.Mandate || a.status == Status.None) revert WrongStatus();
        bool yes = _verify(id, a, att, signature);
        if (usedRequest[att.requestId]) revert RequestUsed();
        usedRequest[att.requestId] = true;

        if (a.status == Status.Proposed) {
            if (block.timestamp > a.answerBy) revert TooLate();
            emit Answered(id, att.requestId, yes);
            if (yes) {
                Mandate storage m = _mandates[a.mandateId];
                a.status = Status.Queued;
                a.yesIssuedAt = att.issuedAt;
                a.executableAt = uint64(block.timestamp + m.delay);
                a.expiresAt = uint64(block.timestamp + m.delay + m.executionWindow);
                a.vetoQuorum = _vetoQuorum(a.vetoBps);
                emit Queued(id, a.executableAt, a.expiresAt, a.vetoQuorum);
            } else {
                a.status = Status.Rejected;
            }
            _refundBond(a);
        } else if (a.status == Status.Queued && !yes && att.issuedAt <= a.yesIssuedAt) {
            // A panel said "no" to the same question before the accepted "yes": the proposer shopped for answers.
            emit Answered(id, att.requestId, false);
            a.status = Status.Cancelled;
            emit Cancelled(id, msg.sender);
        } else {
            revert WrongStatus();
        }
    }

    /// @inheritdoc IOracleGovernor
    function execute(uint256 id) external nonReentrant {
        Action storage a = _actions[id];
        if (a.status != Status.Queued) revert WrongStatus();
        if (block.timestamp < a.executableAt) revert NotYet();
        if (block.timestamp >= a.expiresAt) revert TooLate();
        a.status = Status.Executed;

        if (a.kind == Kind.Config) {
            (bool ok, bytes memory ret) = address(this).call(a.configCall);
            if (!ok) revert SafeCallFailed(ret);
        } else {
            uint32 mid = a.mandateId;
            if (!mandateActive[mid]) revert MandateInactive();
            Mandate storage m = _mandates[mid];
            uint256 last = lastExecutedAt[mid];
            if (last != 0 && block.timestamp < last + m.minInterval) revert TooSoon();
            lastExecutedAt[mid] = block.timestamp;
            if (m.capArg != NO_CAP) {
                uint256 epoch = block.timestamp / m.epochLength;
                uint256 total = spent[mid][epoch] + a.words[m.capArg];
                if (total > m.capPerEpoch) revert AboveCap();
                spent[mid][epoch] = total;
            }
            (bool ok, bytes memory ret) =
                ISafe(safe).execTransactionFromModuleReturnData(m.target, 0, _callData(id), 0);
            if (!ok) revert SafeCallFailed(ret);
        }
        emit Executed(id);
    }

    /// @inheritdoc IOracleGovernor
    function expire(uint256 id) external nonReentrant {
        Action storage a = _actions[id];
        if (a.status == Status.Proposed) {
            if (block.timestamp <= a.answerBy) revert NotYet();
            a.status = Status.Expired;
            uint256 bond = a.bond;
            a.bond = 0;
            if (bond != 0) SafeTransferLib.safeTransfer(bondToken, safe, bond);
        } else if (a.status == Status.Queued) {
            if (block.timestamp < a.expiresAt) revert NotYet();
            a.status = Status.Expired;
        } else {
            revert WrongStatus();
        }
        emit Expired(id);
    }

    // ------------------------------------------------------------------ Veto

    /// @inheritdoc IOracleGovernor
    function lockVeto(uint256 id, address token, uint256 amount) external nonReentrant {
        Action storage a = _actions[id];
        if (a.status != Status.Queued || block.timestamp >= a.executableAt) revert WrongStatus();
        if (a.vetoQuorum == 0) revert NoVeto();
        VetoKind kind = vetoKind[token];
        if (kind == VetoKind.None || amount == 0) revert NoVeto();

        uint256 before = _balance(token);
        SafeTransferLib.safeTransferFrom(token, msg.sender, address(this), amount);
        uint256 received = _balance(token) - before;
        locked[id][msg.sender][token] += received;
        uint256 weight = kind == VetoKind.Base ? received : IERC4626Assets(token).convertToAssets(received);
        a.vetoWeight += weight;
        emit VetoLocked(id, msg.sender, token, received, weight);

        if (a.vetoWeight >= a.vetoQuorum) {
            a.status = Status.Cancelled;
            emit Vetoed(id, a.vetoWeight);
            emit Cancelled(id, address(0));
        }
    }

    /// @inheritdoc IOracleGovernor
    function unlockVeto(uint256 id, address token) external nonReentrant {
        Action storage a = _actions[id];
        // Locks stay until the timelock ends even if the action is cancelled, so a flash loan can't veto.
        if (a.executableAt == 0 || block.timestamp < a.executableAt) revert NotYet();
        uint256 amount = locked[id][msg.sender][token];
        if (amount == 0) revert NoVeto();
        locked[id][msg.sender][token] = 0;
        SafeTransferLib.safeTransfer(token, msg.sender, amount);
        emit VetoUnlocked(id, msg.sender, token, amount);
    }

    /// @inheritdoc IOracleGovernor
    function cancel(uint256 id) external nonReentrant {
        Action storage a = _actions[id];
        if (a.status != Status.Proposed && a.status != Status.Queued) revert WrongStatus();
        bool bySafe = msg.sender == safe && a.kind == Kind.Config;
        if (msg.sender != guardian && !bySafe) revert Unauthorized();
        a.status = Status.Cancelled;
        _refundBond(a);
        emit Cancelled(id, msg.sender);
    }

    // ------------------------------------------------------------------ Safe

    /// @inheritdoc IOracleGovernor
    function proposeConfig(bytes calldata call) external returns (uint256 id) {
        if (msg.sender != safe) revert Unauthorized();
        if (call.length < 4) revert InvalidSetting();
        bytes4 sel = bytes4(call[:4]);
        if (
            sel != this.addMandate.selector && sel != this.setGuardian.selector && sel != this.setSigner.selector
                && sel != this.setVetoToken.selector && sel != this.setCharter.selector
                && sel != this.setConfigRules.selector
        ) revert InvalidSetting();

        id = ++actionCount;
        Action storage a = _actions[id];
        a.kind = Kind.Config;
        a.status = Status.Queued;
        a.proposer = msg.sender;
        a.createdAt = uint64(block.timestamp);
        a.executableAt = uint64(block.timestamp + configDelay);
        a.expiresAt = uint64(block.timestamp + configDelay + configExecutionWindow);
        a.vetoBps = configVetoBps;
        a.vetoQuorum = _vetoQuorum(configVetoBps);
        a.configCall = call;
        emit ConfigProposed(id, call, a.executableAt);
        emit Queued(id, a.executableAt, a.expiresAt, a.vetoQuorum);
    }

    /// @inheritdoc IOracleGovernor
    function disableMandate(uint32 mandateId) external {
        if (msg.sender != safe && msg.sender != guardian) revert Unauthorized();
        if (!mandateActive[mandateId]) revert MandateInactive();
        mandateActive[mandateId] = false;
        emit MandateDisabled(mandateId);
    }

    // ------------------------------------------------------------------ Config (through proposeConfig only)

    /// @inheritdoc IOracleGovernor
    function addMandate(Mandate calldata m, ArgRule[] calldata args) external onlySelf returns (uint32 mandateId) {
        _checkMandate(m, args);
        mandateId = ++mandateCount;
        _mandates[mandateId] = m;
        ArgRule[] storage stored = _args[mandateId];
        for (uint256 i; i < args.length; i++) {
            stored.push(args[i]);
        }
        mandateActive[mandateId] = true;
        emit MandateAdded(mandateId, m.target, bytes4(keccak256(bytes(m.signature))), m.name);
    }

    function setGuardian(address guardian_) external onlySelf {
        _setGuardian(guardian_);
    }

    function setSigner(address signer, bool approved) external onlySelf {
        _setSigner(signer, approved);
    }

    function setVetoToken(address token, VetoKind kind) external onlySelf {
        if (token == vetoBase || token == address(0)) revert InvalidSetting();
        if (kind == VetoKind.Base) revert InvalidSetting();
        if (kind == VetoKind.Vault && IERC4626Assets(token).asset() != vetoBase) revert InvalidSetting();
        vetoKind[token] = kind;
        emit VetoTokenSet(token, kind);
    }

    function setCharter(string calldata charter_) external onlySelf {
        _setCharter(charter_);
    }

    function setConfigRules(uint32 delay, uint32 executionWindow, uint16 vetoBps) external onlySelf {
        _setConfigRules(delay, executionWindow, vetoBps);
    }

    // ------------------------------------------------------------------ Views

    /// @inheritdoc IOracleGovernor
    function question(uint256 id) public view returns (string memory) {
        Action storage a = _actions[id];
        if (a.kind != Kind.Mandate || a.status == Status.None) revert WrongStatus();
        Mandate storage m = _mandates[a.mandateId];
        return string.concat(
            "Docket proposal ",
            id.toString(),
            " for ",
            projectName,
            " on chain id ",
            block.chainid.toString(),
            ", module ",
            address(this).toHexString(),
            ": under the charter at ",
            a.charter,
            ", ",
            m.ruleRef,
            ", should the ",
            m.name,
            " mandate make the Safe ",
            safe.toHexString(),
            " call ",
            m.signature,
            " on ",
            m.target.toHexString(),
            " with ",
            _renderArgs(id, a),
            "? Evidence: ",
            a.evidence,
            ". Answer true only if every rule that applies is met."
        );
    }

    /// @inheritdoc IOracleGovernor
    function callData(uint256 id) external view returns (address target, bytes memory data) {
        Action storage a = _actions[id];
        if (a.kind != Kind.Mandate || a.status == Status.None) revert WrongStatus();
        return (_mandates[a.mandateId].target, _callData(id));
    }

    function actionOf(uint256 id) external view returns (Action memory) {
        return _actions[id];
    }

    function mandateOf(uint32 mandateId) external view returns (Mandate memory, ArgRule[] memory, bool) {
        return (_mandates[mandateId], _args[mandateId], mandateActive[mandateId]);
    }

    /// @notice The EIP-712 domain separator the oracle signs for: this module on this chain.
    function domainSeparator() external view returns (bytes32) {
        return _domainSeparator();
    }

    /// @notice EIP-712 digest of an attestation for this module (for tooling and tests).
    function attestationDigest(OracleAttestation calldata att) external view returns (bytes32) {
        return _hashTypedData(OracleAttestationLib.hash(att));
    }

    // ------------------------------------------------------------------ Internals

    function _verify(uint256 id, Action storage a, OracleAttestation calldata att, bytes calldata signature)
        internal
        view
        returns (bool)
    {
        Mandate storage m = _mandates[a.mandateId];
        bytes32 digest = _hashTypedData(OracleAttestationLib.hash(att));
        if (!isSigner[ECDSA.recoverCalldata(digest, signature)]) revert UnknownSigner();
        if (att.answerType != OracleAttestationLib.ANSWER_BOOL || att.answer.length != 32) revert NotBool();
        uint256 word = abi.decode(att.answer, (uint256));
        if (word > 1) revert NotBool();
        bytes32 qh = OracleAttestationLib.boolQuestionHash(question(id), att.chainId, att.fromBlock, att.toBlock);
        if (att.questionHash != qh) revert WrongQuestion();
        if (att.panelSize < m.minPanel) revert PanelTooSmall();
        if (att.agreed < att.quorum || uint256(att.agreed) * 10_000 < uint256(att.panelSize) * m.minAgreementBps) {
            revert NotEnoughAgreement();
        }
        // The panel must have answered after the proposal was public, and the answer must still be valid.
        if (att.issuedAt < a.createdAt || att.issuedAt > block.timestamp) revert StaleAnswer();
        if (block.timestamp > att.expiresAt) revert StaleAnswer();
        return word == 1;
    }

    function _checkWords(uint32 mandateId, uint256[] calldata words) internal view {
        ArgRule[] storage rules = _args[mandateId];
        if (words.length != rules.length) revert BadArgs();
        for (uint256 i; i < words.length; i++) {
            ArgRule storage r = rules[i];
            uint256 w = words[i];
            ArgKind k = r.kind;
            if (k == ArgKind.ProposalId || k == ArgKind.Evidence) {
                if (w != 0) revert OutOfBounds(i);
                continue;
            }
            if (k == ArgKind.Address && w > type(uint160).max) revert OutOfBounds(i);
            if (k == ArgKind.Bool && w > 1) revert OutOfBounds(i);
            if (r.check == Check.Equal && w != r.min) revert OutOfBounds(i);
            if (r.check == Check.Range && (w < r.min || w > r.max)) revert OutOfBounds(i);
        }
    }

    function _checkMandate(Mandate calldata m, ArgRule[] calldata args) internal view {
        if (m.target == address(0) || m.target == address(this) || m.target == safe) revert InvalidMandate();
        OracleAttestationLib.checkText(m.signature, MAX_NAME);
        OracleAttestationLib.checkText(m.name, MAX_NAME);
        OracleAttestationLib.checkText(m.ruleRef, MAX_NAME);
        if (args.length > MAX_ARGS || args.length != _paramCount(m.signature)) revert InvalidMandate();
        bool evidenceSeen;
        for (uint256 i; i < args.length; i++) {
            ArgRule calldata r = args[i];
            OracleAttestationLib.checkText(r.label, MAX_LABEL);
            if (r.kind == ArgKind.ProposalId || r.kind == ArgKind.Evidence) {
                if (r.check != Check.Any) revert InvalidMandate();
                if (r.kind == ArgKind.Evidence) {
                    if (evidenceSeen) revert InvalidMandate();
                    evidenceSeen = true;
                }
            }
            if (r.check == Check.Range && (r.kind != ArgKind.Uint || r.min > r.max)) revert InvalidMandate();
        }
        if (m.capArg != NO_CAP) {
            if (m.capArg >= args.length || args[m.capArg].kind != ArgKind.Uint || m.epochLength == 0) {
                revert InvalidMandate();
            }
        }
        if (m.answerWindow == 0 || m.executionWindow == 0) revert InvalidMandate();
        if (m.minPanel == 0 || m.minAgreementBps < MIN_AGREEMENT_FLOOR_BPS || m.minAgreementBps > 10_000) {
            revert InvalidMandate();
        }
        if (m.vetoBps > 10_000) revert InvalidMandate();
    }

    /// @dev Number of parameters in a canonical signature "name(t1,t2,...)" (no tuples).
    function _paramCount(string calldata sig) internal pure returns (uint256 n) {
        bytes calldata b = bytes(sig);
        uint256 open = type(uint256).max;
        for (uint256 i; i < b.length; i++) {
            if (b[i] == "(") {
                if (open != type(uint256).max) revert InvalidMandate();
                open = i;
            } else if (b[i] == ",") {
                n++;
            } else if (b[i] == ")" && i != b.length - 1) {
                revert InvalidMandate();
            }
        }
        if (open == type(uint256).max || b.length < open + 2 || b[b.length - 1] != ")") revert InvalidMandate();
        if (b.length > open + 2) n++;
    }

    function _callData(uint256 id) internal view returns (bytes memory data) {
        Action storage a = _actions[id];
        Mandate storage m = _mandates[a.mandateId];
        ArgRule[] storage rules = _args[a.mandateId];
        uint256 n = rules.length;
        data = abi.encodePacked(bytes4(keccak256(bytes(m.signature))));
        bool hasEvidence;
        for (uint256 i; i < n; i++) {
            ArgKind k = rules[i].kind;
            uint256 w;
            if (k == ArgKind.ProposalId) {
                w = id;
            } else if (k == ArgKind.Evidence) {
                w = 32 * n; // offset of the only dynamic argument: right after the head
                hasEvidence = true;
            } else {
                w = a.words[i];
            }
            data = bytes.concat(data, bytes32(w));
        }
        if (hasEvidence) {
            bytes memory e = bytes(a.evidence);
            data = bytes.concat(data, bytes32(e.length), e, new bytes((32 - (e.length % 32)) % 32));
        }
    }

    function _renderArgs(uint256 id, Action storage a) internal view returns (string memory s) {
        ArgRule[] storage rules = _args[a.mandateId];
        for (uint256 i; i < rules.length; i++) {
            ArgRule storage r = rules[i];
            uint256 w = a.words[i];
            string memory v;
            if (r.kind == ArgKind.Uint) v = w.toString();
            else if (r.kind == ArgKind.Address) v = address(uint160(w)).toHexString();
            else if (r.kind == ArgKind.Bytes32) v = LibString.toHexString(abi.encodePacked(bytes32(w)));
            else if (r.kind == ArgKind.Bool) v = w == 1 ? "true" : "false";
            else if (r.kind == ArgKind.ProposalId) v = id.toString();
            else v = a.evidence;
            s = string.concat(s, i == 0 ? "" : ", ", r.label, "=", v);
        }
        if (rules.length == 0) s = "no arguments";
    }

    function _vetoQuorum(uint16 bps) internal view returns (uint256) {
        if (bps == 0) return 0;
        uint256 q = (IERC20Supply(vetoBase).totalSupply() * bps + 9_999) / 10_000;
        return q == 0 ? 1 : q;
    }

    function _refundBond(Action storage a) internal {
        uint256 bond = a.bond;
        if (bond == 0) return;
        a.bond = 0;
        SafeTransferLib.safeTransfer(bondToken, a.proposer, bond);
    }

    function _balance(address token) internal view returns (uint256) {
        return SafeTransferLib.balanceOf(token, address(this));
    }

    function _checkLink(string memory link, uint256 maxLength) internal pure {
        OracleAttestationLib.checkText(link, maxLength);
        if (!LibString.startsWith(link, "ipfs://") || bytes(link).length < 10) revert InvalidSetting();
    }

    function _setGuardian(address guardian_) internal {
        guardian = guardian_;
        emit GuardianSet(guardian_);
    }

    function _setSigner(address signer, bool approved) internal {
        if (signer == address(0) || isSigner[signer] == approved) revert InvalidSetting();
        isSigner[signer] = approved;
        if (approved) signerCount++;
        else signerCount--;
        emit SignerSet(signer, approved);
    }

    function _setCharter(string memory charter_) internal {
        _checkLink(charter_, MAX_NAME);
        charter = charter_;
        emit CharterSet(charter_);
    }

    function _setConfigRules(uint32 delay, uint32 executionWindow, uint16 vetoBps) internal {
        if (executionWindow == 0 || vetoBps > 10_000) revert InvalidSetting();
        configDelay = delay;
        configExecutionWindow = executionWindow;
        configVetoBps = vetoBps;
        emit ConfigRulesSet(delay, executionWindow, vetoBps);
    }
}
