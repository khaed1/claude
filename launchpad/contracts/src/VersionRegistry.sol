// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {FixedOwnable} from "./FixedOwnable.sol";
import {LibString} from "solady/utils/LibString.sol";
import {AttestationVerifier, OracleAttestation} from "./AttestationVerifier.sol";

/// @title VersionRegistry
/// @notice Lists every PondPad version (factory, router, curve, hook, lens) and which one new launches use.
///         Contracts are never upgraded: a new version is a new set of contracts, and coins from older versions
///         trade forever on their own hook. A version goes live only with a swarm audit: an IMD oracle attestation
///         answering "yes" to this registry's question naming the audit job and the version's code hash.
/// @dev The code hash is computed here from the deployed bytecode of the five contracts, so a version can't be
///      registered with a hash that doesn't match its code. Fallback until oracle attestations work on Robinhood
///      Chain: the owner activates a version citing the audit job link; it retires that path once attestations
///      work, one-way (D-46). The owner can switch back to an earlier activated version (rollback). Owner: the
///      7-day timelock, the same delay as oracle signer changes, since it can also swap the verifier.
///      v1 approves no oracle signer in its `AttestationVerifier` (D-86): panels answered the activation question by
///      the contracts' names, not their code (HANDOFF §6b), so v1 versions are activated manually only (`activate`
///      always reverts and the manual fallback can't be retired). The verifier and the five addresses of a version
///      must have code (audits R5-A4-5, R5-A4-7).
contract VersionRegistry is FixedOwnable {
    using LibString for address;

    struct Version {
        address factory;
        address router;
        address curve;
        address hook;
        address lens;
        bytes32 codeHash;
        uint64 registeredAt;
        uint64 activatedAt;
        string auditRef; // IMD audit job id (attested) or link (manual)
    }

    AttestationVerifier public verifier;
    bool public manualActivationRetired;
    /// @notice Version number of the current version (versions start at 1; 0 means none yet).
    uint256 public currentVersion;
    /// @notice The highest version ever activated. Only an activation above it moves `currentVersion`, so after an
    ///         owner rollback an attested activation of a version in between can't move it again (audit R3-A4-6).
    uint256 public highestActivated;
    Version[] internal _versions;
    mapping(bytes32 requestId => bool) public usedRequest;

    event Registered(uint256 indexed version, bytes32 codeHash, address factory, address router, address curve, address hook, address lens);
    event Activated(uint256 indexed version, bytes32 requestId, string auditRef);
    /// @notice The evidence chain and block window of the attestation behind an activation (audit R2-A4-4).
    event AttestationWindow(bytes32 indexed requestId, uint256 chainId, uint64 fromBlock, uint64 toBlock);
    event CurrentSet(uint256 indexed version);
    event VerifierUpdated(address verifier);
    event ManualActivationRetired();

    error UnknownVersion();
    error AlreadyActive();
    error NotActivated();
    error ZeroAddress();
    error AnswerNo();
    error RequestUsed();
    error Retired();
    error CannotRetire();
    error BadAuditJob();
    error NoCode();

    constructor(address owner_, address verifier_) {
        if (verifier_.code.length == 0) revert NoCode(); // audit R5-A4-5
        _initializeOwner(owner_);
        verifier = AttestationVerifier(verifier_);
    }

    /// @notice Registers a new version.
    function register(address factory, address router, address curve, address hook, address lens)
        external
        onlyOwner
        returns (uint256 version)
    {
        if (
            factory == address(0) || router == address(0) || curve == address(0) || hook == address(0)
                || lens == address(0)
        ) revert ZeroAddress();
        // A version commits to deployed code, never to the hash of an empty account (audit R5-A4-7).
        if (
            factory.code.length == 0 || router.code.length == 0 || curve.code.length == 0 || hook.code.length == 0
                || lens.code.length == 0
        ) revert NoCode();
        bytes32 h = codeHashOf(factory, router, curve, hook, lens);
        _versions.push(Version(factory, router, curve, hook, lens, h, uint64(block.timestamp), 0, ""));
        version = _versions.length;
        emit Registered(version, h, factory, router, curve, hook, lens);
    }

    /// @notice Hash of the five contracts' deployed bytecode, in order.
    function codeHashOf(address factory, address router, address curve, address hook, address lens)
        public
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(factory.codehash, router.codehash, curve.codehash, hook.codehash, lens.codehash));
    }

    /// @notice The yes/no question the oracle panel must answer to activate `version` with `auditJobId`.
    function question(uint256 version, string memory auditJobId) public view returns (string memory) {
        Version storage v = _get(version);
        return string.concat(
            "PondPad version ",
            LibString.toString(version),
            " on chain id ",
            LibString.toString(block.chainid),
            ": does IMD swarm audit job ",
            auditJobId,
            " cover the contracts with code hash ",
            LibString.toHexString(uint256(v.codeHash), 32),
            " (factory ",
            v.factory.toHexString(),
            ", router ",
            v.router.toHexString(),
            ", curve ",
            v.curve.toHexString(),
            ", hook ",
            v.hook.toHexString(),
            ", lens ",
            v.lens.toHexString(),
            ") and report no open high or critical findings? Answer true only if both hold."
        );
    }

    /// @notice Activates `version` with an IMD oracle "yes" to `question(version, auditJobId)`. Anyone can submit.
    function activate(uint256 version, string calldata auditJobId, OracleAttestation calldata att, bytes calldata signature)
        external
    {
        _checkJobId(auditJobId);
        if (usedRequest[att.requestId]) revert RequestUsed();
        usedRequest[att.requestId] = true;
        if (!verifier.verifyBool(att, signature, question(version, auditJobId))) revert AnswerNo();
        emit AttestationWindow(att.requestId, att.chainId, att.fromBlock, att.toBlock);
        _activate(version, att.requestId, auditJobId);
    }

    /// @notice Fallback: the owner activates `version` citing the audit job link.
    function activateManually(uint256 version, string calldata auditLink) external onlyOwner {
        if (manualActivationRetired) revert Retired();
        _activate(version, bytes32(0), auditLink);
    }

    function _activate(uint256 version, bytes32 requestId, string memory auditRef) internal {
        Version storage v = _get(version);
        if (v.activatedAt != 0) revert AlreadyActive();
        v.activatedAt = uint64(block.timestamp);
        v.auditRef = auditRef;
        emit Activated(version, requestId, auditRef);
        // Activation only moves new launches forward (audits R1-A4-6, R3-A4-6): activating a version no newer than
        // the newest ever activated (anyone can submit an attestation) marks it activated, but only the owner's
        // `setCurrent` chooses among those.
        if (version > highestActivated) {
            highestActivated = version;
            currentVersion = version;
            emit CurrentSet(version);
        }
    }

    /// @notice Points new launches at an earlier activated version (rollback).
    function setCurrent(uint256 version) external onlyOwner {
        if (_get(version).activatedAt == 0) revert NotActivated();
        currentVersion = version;
        emit CurrentSet(version);
    }

    /// @notice Only a contract (audit R5-A4-5): an address without code would make `activate` and
    ///         `retireManualActivation` revert until another 7-day change.
    function setVerifier(address verifier_) external onlyOwner {
        if (verifier_.code.length == 0) revert NoCode();
        verifier = AttestationVerifier(verifier_);
        emit VerifierUpdated(verifier_);
    }

    /// @notice Ends manual activation forever. Only once the verifier has a signer.
    function retireManualActivation() external onlyOwner {
        if (verifier.signerCount() == 0) revert CannotRetire();
        manualActivationRetired = true;
        emit ManualActivationRetired();
    }

    // ------------------------------------------------------------------ Views

    function current() external view returns (Version memory) {
        return _get(currentVersion);
    }

    function versionInfo(uint256 version) external view returns (Version memory) {
        return _get(version);
    }

    function count() external view returns (uint256) {
        return _versions.length;
    }

    function all() external view returns (Version[] memory) {
        return _versions;
    }

    function _get(uint256 version) internal view returns (Version storage) {
        if (version == 0 || version > _versions.length) revert UnknownVersion();
        return _versions[version - 1];
    }

    /// @dev Job ids are UUIDs: letters, digits and hyphens, at most 64 characters.
    function _checkJobId(string calldata id) internal pure {
        bytes calldata b = bytes(id);
        if (b.length == 0 || b.length > 64) revert BadAuditJob();
        for (uint256 i; i < b.length; i++) {
            bytes1 c = b[i];
            bool ok = (c >= "0" && c <= "9") || (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c == "-";
            if (!ok) revert BadAuditJob();
        }
    }
}
