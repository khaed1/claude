// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

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
/// @notice The 5% $PONDPAD airdrop (50M) to IMD seat holders and sIMD stakers (D-17, D-53). Eligibility is a
///         Merkle root fixed at deploy (snapshot published in advance). Claims open when the $PONDPAD market
///         opens and each allocation vests linearly over 30 days from then. A wallet can name a separate claim
///         wallet with a gasless signature; claims then always pay that wallet. After 180 days anyone sweeps what
///         is left to the RewardDripper, so unclaimed tokens go to sPONDPAD stakers.
/// @dev No owner and no admin. Leaves are OpenZeppelin `StandardMerkleTree` leaves for `(address, uint256)`:
///      `keccak256(bytes.concat(keccak256(abi.encode(account, amount))))`. There is no gate beyond the list
///      (no X link or purchase required).
contract AirdropDistributor is EIP712, ReentrancyGuard {
    using SafeTransferLib for address;

    bytes32 public constant DELEGATE_TYPEHASH =
        keccak256("Delegate(address account,address claimWallet,uint256 nonce,uint256 deadline)");
    uint256 public constant VESTING = 30 days;
    uint256 public constant CLAIM_WINDOW = 180 days;

    address public immutable token;
    bytes32 public immutable merkleRoot;
    IMarketClock public immutable market;
    /// @notice Where unclaimed tokens go after the claim window: the RewardDripper.
    address public immutable unclaimedSink;

    mapping(address account => uint256) public claimed;
    mapping(address account => address) internal _claimWallet;
    mapping(address account => uint256) public nonces;
    uint256 public totalClaimed;

    event Claimed(address indexed account, address indexed to, uint256 amount);
    event ClaimWalletSet(address indexed account, address indexed claimWallet);
    event Swept(address indexed to, uint256 amount);

    error NotOpen();
    error ClaimWindowOver();
    error ClaimWindowNotOver();
    error InvalidProof();
    error NotAuthorized();
    error BadSignature();
    error Expired();
    error ZeroAddress();

    constructor(address token_, bytes32 merkleRoot_, address market_, address unclaimedSink_) {
        if (token_ == address(0) || market_ == address(0) || unclaimedSink_ == address(0)) revert ZeroAddress();
        token = token_;
        merkleRoot = merkleRoot_;
        market = IMarketClock(market_);
        unclaimedSink = unclaimedSink_;
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

    /// @notice How much of an allocation of `amount` has vested by now (zero before the market opens).
    function vested(uint256 amount) public view returns (uint256) {
        uint256 opened = market.openedAt();
        if (opened == 0) return 0;
        uint256 elapsed = block.timestamp - opened;
        return elapsed >= VESTING ? amount : amount * elapsed / VESTING;
    }

    /// @notice What `account` can claim now, given its allocation `amount` (unchecked against the root).
    function claimable(address account, uint256 amount) external view returns (uint256) {
        if (_windowOver()) return 0;
        uint256 v = vested(amount);
        uint256 c = claimed[account];
        return v > c ? v - c : 0;
    }

    /// @notice End of the claim window; zero before the market opens.
    function claimDeadline() public view returns (uint256) {
        uint256 opened = market.openedAt();
        return opened == 0 ? 0 : opened + CLAIM_WINDOW;
    }

    // ------------------------------------------------------------------ Claim wallet (delegation)

    /// @notice Names the wallet that will claim and receive the caller's airdrop.
    function setClaimWallet(address claimWallet) external {
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
        uint256 opened = market.openedAt();
        if (opened == 0) revert NotOpen();
        if (block.timestamp >= opened + CLAIM_WINDOW) revert ClaimWindowOver();
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProofLib.verifyCalldata(proof, merkleRoot, leaf)) revert InvalidProof();

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
        setClaimWalletBySig(account, msg.sender, deadline, signature);
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

    // ------------------------------------------------------------------ Internal

    function _windowOver() internal view returns (bool) {
        uint256 opened = market.openedAt();
        return opened != 0 && block.timestamp >= opened + CLAIM_WINDOW;
    }

    function _setClaimWallet(address account, address claimWallet) internal {
        if (claimWallet == address(0)) revert ZeroAddress();
        _claimWallet[account] = claimWallet;
        emit ClaimWalletSet(account, claimWallet);
    }
}
