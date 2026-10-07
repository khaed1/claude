// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {FixedOwnable} from "./FixedOwnable.sol";

interface ICreatorVault {
    function recipientOf(address coin) external view returns (address);
    function fundHolders(address coin, uint256 amount) external;
}

/// @title SwarmBudget
/// @notice Per-coin escrow funded by the "swarm budget" share of a coin's tax. It can only pay for IMD swarm jobs
///         for that coin: the coin's fee recipient requests a job, and the Swarm Relay releases the IMD to pay it.
/// @dev The owner (timelock) sets the relay and the per-request cap. Every release names its job.
contract SwarmBudget is FixedOwnable, ReentrancyGuard {
    using SafeTransferLib for address;

    struct Request {
        address coin;
        uint96 amount;
        bool released;
        bool cancelled;
        bytes32 specHash; // hash of the structured job spec the relay will submit
    }

    address public immutable imd;
    ICreatorVault public immutable creatorVault;
    address internal immutable _deployer;
    address public curve;
    address public hook;
    address public relay;
    uint96 public maxRequest;

    mapping(address coin => uint256) public balanceOf;
    mapping(address coin => uint256) public reservedOf;
    Request[] public requests;

    event Credited(address indexed coin, uint256 amount);
    event SpendRequested(uint256 indexed id, address indexed coin, uint256 amount, bytes32 specHash);
    event SpendReleased(uint256 indexed id, address indexed coin, uint256 amount, string jobId);
    event SpendCancelled(uint256 indexed id);
    event SweptToHolders(address indexed coin, uint256 amount);
    event RelayUpdated(address relay);
    event MaxRequestUpdated(uint96 maxRequest);

    error InsufficientBudget();
    error AboveMaxRequest();
    error RequestClosed();

    constructor(address owner_, address imd_, address creatorVault_, address relay_, uint96 maxRequest_) {
        _initializeOwner(owner_);
        imd = imd_;
        creatorVault = ICreatorVault(creatorVault_);
        _deployer = msg.sender;
        relay = relay_;
        maxRequest = maxRequest_;
    }

    function initialize(address curve_, address hook_) external {
        if (msg.sender != _deployer) revert Unauthorized();
        if (curve != address(0)) revert AlreadyInitialized();
        curve = curve_;
        hook = hook_;
    }

    function credit(address coin, uint256 amount) external {
        if (msg.sender != curve && msg.sender != hook) revert Unauthorized();
        balanceOf[coin] += amount;
        emit Credited(coin, amount);
    }

    function available(address coin) public view returns (uint256) {
        return balanceOf[coin] - reservedOf[coin];
    }

    /// @notice The coin's fee recipient asks the relay to run a swarm job, reserving its IMD.
    function requestSpend(address coin, uint96 amount, bytes32 specHash) external returns (uint256 id) {
        if (msg.sender != creatorVault.recipientOf(coin)) revert Unauthorized();
        if (amount > maxRequest) revert AboveMaxRequest();
        if (amount > available(coin)) revert InsufficientBudget();
        reservedOf[coin] += amount;
        id = requests.length;
        requests.push(Request(coin, amount, false, false, specHash));
        emit SpendRequested(id, coin, amount, specHash);
    }

    /// @notice The relay takes the reserved IMD to pay the job and records the swarm job id.
    function release(uint256 id, string calldata jobId) external nonReentrant {
        if (msg.sender != relay) revert Unauthorized();
        Request storage r = requests[id];
        if (r.released || r.cancelled) revert RequestClosed();
        r.released = true;
        reservedOf[r.coin] -= r.amount;
        balanceOf[r.coin] -= r.amount;
        imd.safeTransfer(relay, r.amount);
        emit SpendReleased(id, r.coin, r.amount, jobId);
    }

    /// @notice The requester or the relay can cancel an unreleased request, freeing its reservation. Once the
    ///         coin's fees go to its holders, anyone can (audit R1-A4-11): an ousted recipient's open requests
    ///         would otherwise lock the budget the holders should receive.
    function cancel(uint256 id) external {
        Request storage r = requests[id];
        address recipient = creatorVault.recipientOf(r.coin);
        if (msg.sender != relay && msg.sender != recipient && recipient != r.coin) revert Unauthorized();
        if (r.released || r.cancelled) revert RequestClosed();
        r.cancelled = true;
        reservedOf[r.coin] -= r.amount;
        emit SpendCancelled(id);
    }

    /// @notice When a coin's fees were routed to its holders (fee recipient = the coin itself, set by the recipient),
    ///         no one can request swarm jobs for it any more, so its unreserved budget goes to holders as IMD
    ///         dividends, through the coin's holder stream (paid second by second over ~7 days, D-78, D-80).
    ///         Anyone can call it.
    function sweepToHolders(address coin) external nonReentrant returns (uint256 amount) {
        if (creatorVault.recipientOf(coin) != coin) revert Unauthorized();
        amount = available(coin);
        if (amount == 0) return 0;
        balanceOf[coin] -= amount;
        imd.safeApprove(address(creatorVault), amount);
        creatorVault.fundHolders(coin, amount);
        emit SweptToHolders(coin, amount);
    }

    function setRelay(address relay_) external onlyOwner {
        relay = relay_;
        emit RelayUpdated(relay_);
    }

    function setMaxRequest(uint96 maxRequest_) external onlyOwner {
        maxRequest = maxRequest_;
        emit MaxRequestUpdated(maxRequest_);
    }
}
