// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {FixedOwnable} from "./FixedOwnable.sol";
import {EIP712} from "solady/utils/EIP712.sol";
import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {LibString} from "solady/utils/LibString.sol";

interface ICoinRecipients {
    function recipientOf(address coin) external view returns (address);
}

/// @title SocialRegistry
/// @notice X badge, level 1. A coin's fee recipient links the coin's X account by submitting a voucher that
///         PondPad's X link service signs after X OAuth and a wallet signature. One handle per coin; a handle linked
///         to more than one coin is flagged (the badge shows a warning), never blocked. Wallets can also link their
///         own X account the same way (`linkWallet`), which the site shows on their profile.
/// @dev Handles are stored as hashes (keccak256 of the lowercased handle). The verifier (service key) or the owner
///      (48 h timelock) can revoke a link; the fee recipient can unlink. Vouchers are bound to the coin, account,
///      a per-coin nonce and a deadline; a revocation uses up the nonce, so a voucher signed before it is void
///      (audit R3-A4-5). A coin's link counts only while the account that made it is still the coin's fee
///      recipient: after any recipient change the old badge is gone and anyone can clear it (audit R3-A4-9), without
///      using up the nonce (R4-A4-6), the new recipient included (R5-A4-3). Signatures: the signer's own key first,
///      then ERC-1271 (R4-A3-8). The verifier is never address(0) (R5-A4-6).
///      `linkCount` (and so `duplicate` in `badgeOf` and `Linked`) counts a coin's link until it is cleared, a stale
///      one included (audit R5-A4-1): anyone can clear a stale link, so the site clears them and computes its
///      duplicate warning from live links. A coin whose fees go to its holders (recipient = the coin) has no badge and
///      can never link one, since the coin never calls `link`; the creator's wallet link (`linkWallet`) stays on its
///      profile (R5-A4-2).
contract SocialRegistry is FixedOwnable, EIP712 {
    bytes32 public constant LINK_TYPEHASH =
        keccak256("Link(address coin,bytes32 handleHash,address account,uint256 nonce,uint256 deadline)");

    bytes32 public constant WALLET_LINK_TYPEHASH =
        keccak256("WalletLink(address account,bytes32 handleHash,uint256 nonce,uint256 deadline)");

    ICoinRecipients public immutable creatorVault;
    address public verifier;

    mapping(address coin => bytes32) internal _handleOf;
    /// @notice The fee recipient that linked the coin's handle (audit R3-A4-9).
    mapping(address coin => address) public linkedBy;
    mapping(address coin => uint256) public nonces;
    /// @notice How many coins currently link each handle.
    mapping(bytes32 handleHash => uint256) public linkCount;
    /// @notice A wallet's own verified X handle, as typed (shown on the wallet's profile).
    mapping(address account => string) public walletHandle;
    mapping(address account => uint256) public walletNonces;

    event Linked(address indexed coin, bytes32 indexed handleHash, address indexed account, bool duplicate);
    event Unlinked(address indexed coin, bytes32 indexed handleHash, address by);
    event VerifierUpdated(address verifier);
    event WalletLinked(address indexed account, string handle);
    event WalletUnlinked(address indexed account, address by);

    error Expired();
    error BadVoucher();
    error NotLinked();
    error BadHandle();
    error ZeroAddress();

    constructor(address owner_, address creatorVault_, address verifier_) {
        if (verifier_ == address(0)) revert ZeroAddress(); // audit R5-A4-6: it would refuse every voucher
        _initializeOwner(owner_);
        creatorVault = ICoinRecipients(creatorVault_);
        verifier = verifier_;
        emit VerifierUpdated(verifier_);
    }

    function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
        return ("PondPad SocialRegistry", "1");
    }

    /// @dev The signer's plain ECDSA signature first, then ERC-1271, as OpenZeppelin's SignatureChecker does. Solady's
    ///      checker asks only ERC-1271 once the signer has code, which refused the own-key signature of an EOA carrying
    ///      an EIP-7702 delegation whose delegate doesn't implement it (audit R4-A3-8).
    function _validSignature(address signer, bytes32 digest, bytes calldata signature) internal view returns (bool) {
        if (signer == address(0)) return false;
        return ECDSA.tryRecoverCalldata(digest, signature) == signer
            || SignatureCheckerLib.isValidERC1271SignatureNowCalldata(signer, digest, signature);
    }

    /// @notice Links `handleHash` to `coin`, replacing any previous link. Only the coin's fee recipient.
    function link(address coin, bytes32 handleHash, uint256 deadline, bytes calldata signature) external {
        if (msg.sender != creatorVault.recipientOf(coin) || msg.sender == address(0)) revert Unauthorized();
        if (block.timestamp > deadline) revert Expired();
        if (handleHash == bytes32(0)) revert BadVoucher();
        bytes32 digest =
            _hashTypedData(keccak256(abi.encode(LINK_TYPEHASH, coin, handleHash, msg.sender, nonces[coin]++, deadline)));
        if (!_validSignature(verifier, digest, signature)) revert BadVoucher();

        bytes32 old = _handleOf[coin];
        if (old != bytes32(0)) linkCount[old]--;
        _handleOf[coin] = handleHash;
        linkedBy[coin] = msg.sender;
        uint256 n = ++linkCount[handleHash];
        emit Linked(coin, handleHash, msg.sender, n > 1);
    }

    /// @notice Removes a coin's link. The coin's fee recipient, the verifier or the owner; anyone once the account that
    ///         linked it is no longer the fee recipient (audit R3-A4-9). When the verifier or the owner removes it, or
    ///         the recipient removes its own live link, vouchers signed before are void (R3-A4-5); a clear of a stale
    ///         link leaves them, whoever clears it: a stranger (R4-A4-6), the new recipient or the old one (R5-A4-3).
    function unlink(address coin) external {
        address recipient = creatorVault.recipientOf(coin);
        if (
            msg.sender != recipient && msg.sender != verifier && msg.sender != owner() && linkedBy[coin] == recipient
        ) revert Unauthorized();
        bytes32 h = _handleOf[coin];
        if (h == bytes32(0)) revert NotLinked();
        bool live = linkedBy[coin] == recipient;
        delete _handleOf[coin];
        delete linkedBy[coin];
        linkCount[h]--;
        // A revocation by the verifier or the owner, or by the recipient of its own live link, voids every voucher
        // signed before it (R3-A4-5). Clearing a stale link revokes nothing (the account that made it isn't the
        // recipient, so its vouchers can't be used), so it leaves the nonce alone and can't void the voucher the new
        // recipient already holds, whoever clears it: a stranger (audit R4-A4-6), the new recipient (R5-A4-3) or the
        // old one.
        if (msg.sender == verifier || msg.sender == owner() || (msg.sender == recipient && live)) nonces[coin]++;
        emit Unlinked(coin, h, msg.sender);
    }

    /// @notice The coin's linked handle hash, while the account that linked it is still the coin's fee recipient.
    function handleOf(address coin) public view returns (bytes32) {
        if (linkedBy[coin] != creatorVault.recipientOf(coin)) return bytes32(0);
        return _handleOf[coin];
    }

    /// @notice Links the caller's wallet to X account `handle` (without the @). The voucher signs
    ///         keccak256 of the lowercased handle.
    function linkWallet(string calldata handle, uint256 deadline, bytes calldata signature) external {
        if (block.timestamp > deadline) revert Expired();
        _checkHandle(handle);
        bytes32 h = keccak256(bytes(LibString.lower(handle)));
        bytes32 digest = _hashTypedData(
            keccak256(abi.encode(WALLET_LINK_TYPEHASH, msg.sender, h, walletNonces[msg.sender]++, deadline))
        );
        if (!_validSignature(verifier, digest, signature)) revert BadVoucher();
        walletHandle[msg.sender] = handle;
        emit WalletLinked(msg.sender, handle);
    }

    /// @notice Removes a wallet's X link. The wallet itself, the verifier or the owner. Vouchers signed before it are
    ///         void (audit R3-A4-5).
    function unlinkWallet(address account) external {
        if (msg.sender != account && msg.sender != verifier && msg.sender != owner()) revert Unauthorized();
        if (bytes(walletHandle[account]).length == 0) revert NotLinked();
        delete walletHandle[account];
        walletNonces[account]++;
        emit WalletUnlinked(account, msg.sender);
    }

    /// @dev X handles: 1–15 letters, digits or underscores.
    function _checkHandle(string calldata handle) internal pure {
        bytes calldata b = bytes(handle);
        if (b.length == 0 || b.length > 15) revert BadHandle();
        for (uint256 i; i < b.length; i++) {
            bytes1 c = b[i];
            bool ok = (c >= "0" && c <= "9") || (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c == "_";
            if (!ok) revert BadHandle();
        }
    }

    /// @notice The coin's badge: its handle hash and whether another coin links the same handle. Nothing once the
    ///         account that linked it is no longer the coin's fee recipient (audit R3-A4-9), so nothing for a coin
    ///         whose fees go to its holders (R5-A4-2). `duplicate` counts every link not yet cleared, stale ones
    ///         included (R5-A4-1): the site computes its warning from live links and clears stale ones (anyone may).
    function badgeOf(address coin) external view returns (bytes32 handleHash, bool duplicate) {
        handleHash = handleOf(coin);
        duplicate = handleHash != bytes32(0) && linkCount[handleHash] > 1;
    }

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparator();
    }

    function setVerifier(address verifier_) external onlyOwner {
        if (verifier_ == address(0)) revert ZeroAddress(); // audit R5-A4-6
        verifier = verifier_;
        emit VerifierUpdated(verifier_);
    }
}
