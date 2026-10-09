// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {FixedOwnable} from "./FixedOwnable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";

/// @title GrowthFund
/// @notice The growth bucket: 20% of the protocol fees, graduation fees and snipe taxes, in IMD, plus the growth
///         share of the market's sell-side fees in $PONDPAD (D-38). It pays IMD swarm jobs (free graduation
///         websites, oracle questions) through the Swarm Relay and grants through the team Safe. Every payment
///         names a reference and a reason, and both paths are capped per 7-day epoch (D-47).
/// @dev The relay is a hot wallet, so its cap bounds what a leaked key could take. Grant caps are per token; a
///      token with no cap can't be granted. Owner (48 h timelock): relay, granter and caps. There is no other way
///      to move funds out.
contract GrowthFund is FixedOwnable, ReentrancyGuard {
    using SafeTransferLib for address;

    uint256 public constant EPOCH = 7 days;

    address public immutable imd;
    address public immutable pondpad;
    uint256 public immutable startTime;

    address public relay;
    address public granter;
    /// @notice IMD the relay may take per epoch.
    uint256 public relayCap;
    /// @notice Amount of each token the granter may grant per epoch.
    mapping(address token => uint256) public grantCap;

    mapping(uint256 epoch => uint256) public relaySpent;
    mapping(uint256 epoch => mapping(address token => uint256)) public granted;

    event JobPaid(uint256 indexed epoch, uint256 amount, bytes32 indexed jobRef, string reason);
    event Granted(
        uint256 indexed epoch, address indexed token, address indexed to, uint256 amount, bytes32 ref, string reason
    );
    event RelayUpdated(address relay);
    event GranterUpdated(address granter);
    event RelayCapUpdated(uint256 cap);
    event GrantCapUpdated(address indexed token, uint256 cap);

    error AboveCap();
    error ZeroAddress();

    constructor(
        address owner_,
        address imd_,
        address pondpad_,
        address relay_,
        address granter_,
        uint256 relayCap_,
        uint256 imdGrantCap_,
        uint256 pondpadGrantCap_
    ) {
        _initializeOwner(owner_);
        imd = imd_;
        pondpad = pondpad_;
        startTime = block.timestamp;
        relay = relay_;
        granter = granter_;
        relayCap = relayCap_;
        grantCap[imd_] = imdGrantCap_;
        grantCap[pondpad_] = pondpadGrantCap_;
        emit RelayUpdated(relay_);
        emit GranterUpdated(granter_);
        emit RelayCapUpdated(relayCap_);
        emit GrantCapUpdated(imd_, imdGrantCap_);
        emit GrantCapUpdated(pondpad_, pondpadGrantCap_);
    }

    function currentEpoch() public view returns (uint256) {
        return (block.timestamp - startTime) / EPOCH;
    }

    /// @notice IMD the relay can still take this epoch.
    function relayAvailable() external view returns (uint256) {
        uint256 spent = relaySpent[currentEpoch()];
        return spent >= relayCap ? 0 : relayCap - spent;
    }

    /// @notice Amount of `token` the granter can still grant this epoch.
    function grantAvailable(address token) external view returns (uint256) {
        uint256 spent = granted[currentEpoch()][token];
        uint256 cap = grantCap[token];
        return spent >= cap ? 0 : cap - spent;
    }

    /// @notice The relay takes IMD to pay a swarm job (website, oracle question) and records it.
    function payJob(uint256 amount, bytes32 jobRef, string calldata reason) external nonReentrant {
        if (msg.sender != relay) revert Unauthorized();
        uint256 epoch = currentEpoch();
        uint256 spent = relaySpent[epoch] + amount;
        if (spent > relayCap) revert AboveCap();
        relaySpent[epoch] = spent;
        imd.safeTransfer(msg.sender, amount);
        emit JobPaid(epoch, amount, jobRef, reason);
    }

    /// @notice The granter (team Safe) pays a grant in a capped token.
    function grant(address token, address to, uint256 amount, bytes32 ref, string calldata reason)
        external
        nonReentrant
    {
        if (msg.sender != granter) revert Unauthorized();
        if (to == address(0)) revert ZeroAddress();
        uint256 epoch = currentEpoch();
        uint256 spent = granted[epoch][token] + amount;
        if (spent > grantCap[token]) revert AboveCap();
        granted[epoch][token] = spent;
        token.safeTransfer(to, amount);
        emit Granted(epoch, token, to, amount, ref, reason);
    }

    // ------------------------------------------------------------------ Settings (48 h timelock)

    function setRelay(address relay_) external onlyOwner {
        relay = relay_;
        emit RelayUpdated(relay_);
    }

    function setGranter(address granter_) external onlyOwner {
        granter = granter_;
        emit GranterUpdated(granter_);
    }

    function setRelayCap(uint256 cap) external onlyOwner {
        relayCap = cap;
        emit RelayCapUpdated(cap);
    }

    function setGrantCap(address token, uint256 cap) external onlyOwner {
        grantCap[token] = cap;
        emit GrantCapUpdated(token, cap);
    }
}
