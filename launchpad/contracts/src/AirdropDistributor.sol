// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {FixedOwnable} from "./FixedOwnable.sol";
import {EIP712} from "solady/utils/EIP712.sol";
import {MerkleProofLib} from "solady/utils/MerkleProofLib.sol";
import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";

/// @notice The $PONDPAD market's opening time (MarketController): zero until PadSale graduates.
interface IMarketClock {
    function openedAt() external view returns (uint256);
}

/// @title AirdropDistributor
/// @notice The 5% $PONDPAD airdrop (50M) to IMD seat holders and sIMD stakers (D-17, D-53, D-55). Eligibility is
///         a Merkle root fixed at deploy (snapshot published in advance).
///
///         1. Initiation: once the $PONDPAD market is open, wallets on the list post "Initiating the airdrop phase
///            for $PondPad" on X with their own code (`initiationCode`) and register it here with a voucher from
///            PondPad's tweet checker. Each wallet and each X account counts once.
///         2. When the 100th wallet initiates, the airdrop is active for everyone on the list (not only the
///            initiators; no bonus). There is no fallback date: until 100 wallets initiate, nothing is claimable.
///         3. Each allocation vests linearly over 30 days from activation. A wallet can name a separate claim
///            wallet with a gasless signature; claims then always pay that wallet. No X link is needed to claim.
///         4. 180 days after activation anyone sweeps what is left to the RewardDripper (sPONDPAD stakers).
/// @dev Leaves are OpenZeppelin `StandardMerkleTree` leaves for `(address, uint256)`:
///      `keccak256(bytes.concat(keccak256(abi.encode(account, amount))))`. The owner (48 h timelock) can only
///      replace the tweet checker's key; an initiation also needs the eligible wallet itself (or its claim wallet),
///      so the key alone can't initiate. No one can move tokens except through claims and the sweep.
contract AirdropDistributor is FixedOwnable, EIP712, ReentrancyGuard {
    using SafeTransferLib for address;

    bytes32 public constant DELEGATE_TYPEHASH =
        keccak256("Delegate(address account,address claimWallet,uint256 nonce,uint256 deadline)");
    /// @notice The tweet checker's voucher. `handleHash` is keccak256 of the X account's numeric user id (which never
    ///         changes, unlike the handle) and `tweetHash` keccak256 of the tweet id, so one X account counts once even
    ///         if it is renamed between posts (audit R3-A3-7).
    bytes32 public constant INITIATION_TYPEHASH =
        keccak256("Initiation(address account,bytes32 handleHash,bytes32 tweetHash,uint256 deadline)");
    uint256 public constant INITIATORS_NEEDED = 100;
    uint256 public constant VESTING = 30 days;
    uint256 public constant CLAIM_WINDOW = 180 days;

    address public immutable token;
    bytes32 public immutable merkleRoot;
    IMarketClock public immutable market;
    /// @notice Where unclaimed tokens go after the claim window: the RewardDripper.
    address public immutable unclaimedSink;

    /// @notice Key of PondPad's tweet checker, which signs a voucher once it has seen a wallet's initiation post.
    address public verifier;
    uint256 public initiatorCount;
    /// @notice When the 100th wallet initiated: claims and vesting start here. Zero until then.
    uint256 public activatedAt;
    mapping(address account => bool) public initiated;
    mapping(bytes32 handleHash => bool) public handleUsed;
    mapping(bytes32 tweetHash => bool) public tweetUsed;

    mapping(address account => uint256) public claimed;
    mapping(address account => address) internal _claimWallet;
    mapping(address account => uint256) public nonces;
    uint256 public totalClaimed;

    event Initiated(address indexed account, bytes32 indexed handleHash, bytes32 tweetHash, uint256 count);
    event Activated(uint256 timestamp);
    event Claimed(address indexed account, address indexed to, uint256 amount);
    event ClaimWalletSet(address indexed account, address indexed claimWallet);
    event Swept(address indexed to, uint256 amount);
    event VerifierUpdated(address verifier);

    error MarketNotOpen();
    error AlreadyActive();
    error AlreadyInitiated();
    error HandleUsed();
    error TweetUsed();
    error BadVoucher();
    error NotActive();
    error ClaimWindowOver();
    error ClaimWindowNotOver();
    error InvalidProof();
    error NotAuthorized();
    error BadSignature();
    error Expired();
    error ZeroAddress();

    constructor(
        address owner_,
        address token_,
        bytes32 merkleRoot_,
        address market_,
        address unclaimedSink_,
        address verifier_
    ) {
        if (
            token_ == address(0) || market_ == address(0) || unclaimedSink_ == address(0)
                || verifier_ == address(0)
        ) revert ZeroAddress();
        _initializeOwner(owner_);
        token = token_;
        merkleRoot = merkleRoot_;
        market = IMarketClock(market_);
        unclaimedSink = unclaimedSink_;
        verifier = verifier_;
        emit VerifierUpdated(verifier_);
    }

    function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
        return ("PondPad Airdrop", "1");
    }

    // ------------------------------------------------------------------ Views

    /// @notice The wallet that receives `account`'s claims: its claim wallet if set, else itself.
    function claimWalletOf(address account) public view returns (address) {
        address w = _claimWallet[account];
        return w == address(0) ? account : w;
    }

    /// @notice The code `account` puts in its initiation post: 6 bytes (12 hex characters) derived from this
    ///         contract and the account, so anyone can check a post against the wallet that registered it.
    function initiationCode(address account) public view returns (bytes6) {
        return bytes6(keccak256(abi.encode(address(this), account)));
    }

    /// @notice How much of an allocation of `amount` has vested by now (zero before activation).
    function vested(uint256 amount) public view returns (uint256) {
        uint256 start = activatedAt;
        if (start == 0) return 0;
        uint256 elapsed = block.timestamp - start;
        return elapsed >= VESTING ? amount : amount * elapsed / VESTING;
    }

    /// @notice What `account` can claim now, given its allocation `amount` (unchecked against the root).
    function claimable(address account, uint256 amount) external view returns (uint256) {
        if (_windowOver()) return 0;
        uint256 v = vested(amount);
        uint256 c = claimed[account];
        return v > c ? v - c : 0;
    }

    /// @notice End of the claim window; zero before activation.
    function claimDeadline() public view returns (uint256) {
        uint256 start = activatedAt;
        return start == 0 ? 0 : start + CLAIM_WINDOW;
    }

    // ------------------------------------------------------------------ Initiation

    /// @notice Registers `account`'s initiation post. Callable by the account or its claim wallet, once the market
    ///         is open and until the airdrop is active. `voucher` is the tweet checker's EIP-712 signature over
    ///         (account, X handle hash, tweet hash, deadline), given after it found the phrase and
    ///         `initiationCode(account)` in a post by that X account.
    function initiate(
        address account,
        uint256 amount,
        bytes32[] calldata proof,
        bytes32 handleHash,
        bytes32 tweetHash,
        uint256 deadline,
        bytes calldata voucher
    ) external {
        if (msg.sender != account && msg.sender != claimWalletOf(account)) revert NotAuthorized();
        if (market.openedAt() == 0) revert MarketNotOpen();
        if (activatedAt != 0) revert AlreadyActive();
        if (initiated[account]) revert AlreadyInitiated();
        if (handleUsed[handleHash]) revert HandleUsed();
        if (tweetUsed[tweetHash]) revert TweetUsed();
        if (block.timestamp > deadline) revert Expired();
        _verifyLeaf(account, amount, proof);
        bytes32 digest =
            _hashTypedData(keccak256(abi.encode(INITIATION_TYPEHASH, account, handleHash, tweetHash, deadline)));
        if (!SignatureCheckerLib.isValidSignatureNowCalldata(verifier, digest, voucher)) revert BadVoucher();

        initiated[account] = true;
        handleUsed[handleHash] = true;
        tweetUsed[tweetHash] = true;
        uint256 count = ++initiatorCount;
        emit Initiated(account, handleHash, tweetHash, count);
        if (count == INITIATORS_NEEDED) {
            activatedAt = block.timestamp;
            emit Activated(block.timestamp);
        }
    }

    // ------------------------------------------------------------------ Claim wallet (delegation)

    /// @notice Names the wallet that will claim and receive the caller's airdrop. Also voids any delegation the
    ///         caller signed but nobody submitted yet (it uses the next nonce; audit R1-A3-4).
    function setClaimWallet(address claimWallet) external {
        nonces[msg.sender]++;
        _setClaimWallet(msg.sender, claimWallet);
    }

    /// @notice Same, with `account`'s EIP-712 signature (EOA or ERC-1271), so the eligible wallet never sends a
    ///         transaction. Anyone can submit it, usually the claim wallet itself.
    function setClaimWalletBySig(address account, address claimWallet, uint256 deadline, bytes calldata signature)
        public
    {
        if (block.timestamp > deadline) revert Expired();
        bytes32 digest =
            _hashTypedData(keccak256(abi.encode(DELEGATE_TYPEHASH, account, claimWallet, nonces[account]++, deadline)));
        if (!SignatureCheckerLib.isValidSignatureNowCalldata(account, digest, signature)) revert BadSignature();
        _setClaimWallet(account, claimWallet);
    }

    // ------------------------------------------------------------------ Claim and sweep

    /// @notice Pays `account`'s vested, unclaimed airdrop to its claim wallet. Callable by the account or its claim
    ///         wallet. `amount` is the account's whole allocation in the Merkle tree.
    function claim(address account, uint256 amount, bytes32[] calldata proof)
        public
        nonReentrant
        returns (uint256 paid)
    {
        address to = claimWalletOf(account);
        if (msg.sender != account && msg.sender != to) revert NotAuthorized();
        uint256 start = activatedAt;
        if (start == 0) revert NotActive();
        if (block.timestamp >= start + CLAIM_WINDOW) revert ClaimWindowOver();
        _verifyLeaf(account, amount, proof);

        uint256 v = vested(amount);
        uint256 c = claimed[account];
        if (v <= c) return 0;
        paid = v - c;
        claimed[account] = v;
        totalClaimed += paid;
        token.safeTransfer(to, paid);
        emit Claimed(account, to, paid);
    }

    /// @notice One transaction for a claim wallet: records `account`'s signature naming it, then claims.
    function setClaimWalletAndClaim(
        address account,
        uint256 deadline,
        bytes calldata signature,
        uint256 amount,
        bytes32[] calldata proof
    ) external returns (uint256) {
        // If someone already submitted this delegation, it is in place: just claim (audit R1-A3-5).
        if (claimWalletOf(account) != msg.sender) setClaimWalletBySig(account, msg.sender, deadline, signature);
        return claim(account, amount, proof);
    }

    /// @notice After the claim window, sends everything left to the RewardDripper (stakers). Permissionless.
    function sweep() external nonReentrant returns (uint256 amount) {
        if (!_windowOver()) revert ClaimWindowNotOver();
        amount = token.balanceOf(address(this));
        if (amount == 0) return 0;
        token.safeTransfer(unclaimedSink, amount);
        emit Swept(unclaimedSink, amount);
    }

    // ------------------------------------------------------------------ Owner (48 h timelock)

    /// @notice Replaces the tweet checker's key (lost or leaked key, new service).
    function setVerifier(address verifier_) external onlyOwner {
        if (verifier_ == address(0)) revert ZeroAddress();
        verifier = verifier_;
        emit VerifierUpdated(verifier_);
    }

    // ------------------------------------------------------------------ Internal

    function _verifyLeaf(address account, uint256 amount, bytes32[] calldata proof) internal view {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProofLib.verifyCalldata(proof, merkleRoot, leaf)) revert InvalidProof();
    }

    function _windowOver() internal view returns (bool) {
        uint256 start = activatedAt;
        return start != 0 && block.timestamp >= start + CLAIM_WINDOW;
    }

    function _setClaimWallet(address account, address claimWallet) internal {
        if (claimWallet == address(0)) revert ZeroAddress();
        _claimWallet[account] = claimWallet;
        emit ClaimWalletSet(account, claimWallet);
    }
}
