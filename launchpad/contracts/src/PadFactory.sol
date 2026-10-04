// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {PadToken} from "./PadToken.sol";
import {CoinFees} from "./FeeLib.sol";

interface ICurveRegistry {
    function register(address coin, address feeRecipient, CoinFees calldata fees) external;
}

/// @notice What a creator chooses at launch. Everything here is fixed for the coin's lifetime, except the fee
///         recipient, which the recipient itself (or a swarm-approved takeover) can change later.
struct LaunchParams {
    string name;
    string symbol;
    string metadataURI; // ipfs:// or https:// JSON with logo, description and socials
    address feeRecipient; // creator fee recipient; defaults to the creator
    CoinFees fees;
    bytes32 salt;
}

/// @title PadFactory
/// @notice Deploys PondPad coins. Each coin is a full PadToken contract (not a proxy), deployed with CREATE2 so
///         its address is predictable, with the whole supply minted to the bonding curve.
contract PadFactory {
    address public immutable curve;
    address public immutable hook;
    address public immutable poolManager;
    address public immutable imd;
    address internal immutable _deployer;
    address public router;

    event CoinLaunched(
        address indexed coin,
        address indexed creator,
        string name,
        string symbol,
        string metadataURI,
        address feeRecipient,
        CoinFees fees
    );

    error Unauthorized();
    error AlreadyInitialized();
    error InvalidName();

    constructor(address curve_, address hook_, address poolManager_, address imd_) {
        curve = curve_;
        hook = hook_;
        poolManager = poolManager_;
        imd = imd_;
        _deployer = msg.sender;
    }

    function initialize(address router_) external {
        if (msg.sender != _deployer) revert Unauthorized();
        if (router != address(0)) revert AlreadyInitialized();
        router = router_;
    }

    function create(LaunchParams calldata p, address creator) external returns (address coin) {
        if (msg.sender != router) revert Unauthorized();
        uint256 nameLen = bytes(p.name).length;
        uint256 symbolLen = bytes(p.symbol).length;
        if (nameLen == 0 || nameLen > 32 || symbolLen == 0 || symbolLen > 12) revert InvalidName();

        bytes32 salt = keccak256(abi.encode(creator, p.salt));
        coin = address(new PadToken{salt: salt}(p.name, p.symbol, curve, hook, poolManager, imd));
        address recipient = p.feeRecipient == address(0) ? creator : p.feeRecipient;
        ICurveRegistry(curve).register(coin, recipient, p.fees);
        emit CoinLaunched(coin, creator, p.name, p.symbol, p.metadataURI, recipient, p.fees);
    }

    /// @notice The address a coin will get for a given creator and salt.
    function predictAddress(LaunchParams calldata p, address creator) external view returns (address) {
        bytes32 salt = keccak256(abi.encode(creator, p.salt));
        bytes32 initHash = keccak256(
            abi.encodePacked(type(PadToken).creationCode, abi.encode(p.name, p.symbol, curve, hook, poolManager, imd))
        );
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, initHash)))));
    }
}
