// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "solady/auth/Ownable.sol";
import {EIP712} from "solady/utils/EIP712.sol";
import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";

interface ICoinRecipients {
    function recipientOf(address coin) external view returns (address);
}

/// @title SocialRegistry
/// @notice X badge, level 1. A coin's fee recipient links the coin's X account by submitting a voucher that
///         PondPad's X link service signs after X OAuth and a wallet signature. One handle per coin; a handle linked
///         to more than one coin is flagged (the badge shows a warning), never blocked.
/// @dev Handles are stored as hashes (keccak256 of the lowercased handle). The verifier (service key) or the owner
///      (48 h timelock) can revoke a link; the fee recipient can unlink. Vouchers are bound to the coin, account,
///      a per-coin nonce and a deadline.
contract SocialRegistry is Ownable, EIP712 {
    bytes32 public constant LINK_TYPEHASH =
        keccak256("Link(address coin,bytes32 handleHash,address account,uint256 nonce,uint256 deadline)");

    ICoinRecipients public immutable creatorVault;
    address public verifier;

    mapping(address coin => bytes32) public handleOf;
    mapping(address coin => uint256) public nonces;
    /// @notice How many coins currently link each handle.
    mapping(bytes32 handleHash => uint256) public linkCount;

    event Linked(address indexed coin, bytes32 indexed handleHash, address indexed account, bool duplicate);
    event Unlinked(address indexed coin, bytes32 indexed handleHash, address by);
    event VerifierUpdated(address verifier);

    error Expired();
    error BadVoucher();
    error NotLinked();

    constructor(address owner_, address creatorVault_, address verifier_) {
        _initializeOwner(owner_);
        creatorVault = ICoinRecipients(creatorVault_);
        verifier = verifier_;
        emit VerifierUpdated(verifier_);
    }

    function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
        return ("PondPad SocialRegistry", "1");
    }

    /// @notice Links `handleHash` to `coin`, replacing any previous link. Only the coin's fee recipient.
    function link(address coin, bytes32 handleHash, uint256 deadline, bytes calldata signature) external {
        if (msg.sender != creatorVault.recipientOf(coin) || msg.sender == address(0)) revert Unauthorized();
        if (block.timestamp > deadline) revert Expired();
        if (handleHash == bytes32(0)) revert BadVoucher();
        bytes32 digest =
            _hashTypedData(keccak256(abi.encode(LINK_TYPEHASH, coin, handleHash, msg.sender, nonces[coin]++, deadline)));
        if (!SignatureCheckerLib.isValidSignatureNowCalldata(verifier, digest, signature)) revert BadVoucher();

        bytes32 old = handleOf[coin];
        if (old != bytes32(0)) linkCount[old]--;
        handleOf[coin] = handleHash;
        uint256 n = ++linkCount[handleHash];
        emit Linked(coin, handleHash, msg.sender, n > 1);
    }

    /// @notice Removes a coin's link. The coin's fee recipient, the verifier or the owner.
    function unlink(address coin) external {
        if (msg.sender != creatorVault.recipientOf(coin) && msg.sender != verifier && msg.sender != owner()) {
            revert Unauthorized();
        }
        bytes32 h = handleOf[coin];
        if (h == bytes32(0)) revert NotLinked();
        delete handleOf[coin];
        linkCount[h]--;
        emit Unlinked(coin, h, msg.sender);
    }

    /// @notice The coin's badge: its handle hash and whether another coin links the same handle.
    function badgeOf(address coin) external view returns (bytes32 handleHash, bool duplicate) {
        handleHash = handleOf[coin];
        duplicate = handleHash != bytes32(0) && linkCount[handleHash] > 1;
    }

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparator();
    }

    function setVerifier(address verifier_) external onlyOwner {
        verifier = verifier_;
        emit VerifierUpdated(verifier_);
    }
}
