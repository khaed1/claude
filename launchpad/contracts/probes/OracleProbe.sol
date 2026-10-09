// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {AttestationVerifier, OracleAttestation} from "../src/AttestationVerifier.sol";

interface IIntake {
    struct Callback {
        address target;
        bytes4 selector;
    }

    function request(bytes32 action, bytes calldata body, Callback calldata callback, address asset, uint256 amount)
        external
        payable
        returns (bytes32 requestId);
}

interface IERC20Min {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @title OracleProbe
/// @notice Test-only, not part of PondPad and outside the audit scope (HANDOFF §6b, 8 Oct 2026). Buys one IMD oracle
///         question through IMD's Intake on Robinhood with a callback to itself, and checks each delivered answer with
///         PondPad's own `AttestationVerifier` (deployed unchanged, approving IMD's attester): whether the answer
///         verifies against the exact question, what it says, the gas the check took inside Intake's 200,000-gas
///         callback, and how far `issuedAt` was behind the block that delivered it. It holds at most one question's
///         fee between the owner's transfer and `ask`; anything left can be swept back by the owner.
contract OracleProbe {
    bytes32 public constant ACTION = "oracle.request@oracle-1";

    IIntake public immutable intake;
    address public immutable imd;
    AttestationVerifier public immutable verifier;
    address public immutable owner;

    struct Result {
        uint64 deliveredAt; // block.timestamp of Intake's callback (0 if it never arrived)
        uint64 issuedAt; // the attestation's
        uint32 verifyGas; // gas used by the last verifier.verifyBool, success or not
        bytes4 err; // the verifier's revert selector if it refused; 0xffffffff if it ran out of gas
        bool delivered;
        bool checked;
        bool verified;
        bool answer;
    }

    /// @dev Kept back in the callback for the bookkeeping after the check.
    uint256 internal constant CALLBACK_RESERVE = 40_000;

    mapping(bytes32 requestId => string) public questionOf;
    mapping(bytes32 requestId => bool) public pending;
    mapping(bytes32 requestId => Result) public results;

    event Asked(bytes32 indexed requestId, string question);
    event Checked(
        bytes32 indexed requestId,
        bool viaCallback,
        bool verified,
        bool answer,
        bytes4 err,
        uint256 verifyGas,
        uint64 issuedAt,
        uint64 checkedAt,
        uint16 panelSize,
        uint16 quorum,
        uint16 agreed
    );

    error NotOwner();
    error NotIntake();
    error NotPending();
    error UnknownRequest();

    constructor(IIntake intake_, address imd_, AttestationVerifier verifier_, address owner_) {
        intake = intake_;
        imd = imd_;
        verifier = verifier_;
        owner = owner_;
    }

    /// @notice Asks `question` with the oracle body `body` (compact UTF-8 JSON whose `question` is `question`), paying
    ///         `price` IMD held by this contract. The answer comes back to `onOracleResult`.
    function ask(string calldata question, bytes calldata body, uint256 price) external returns (bytes32 requestId) {
        if (msg.sender != owner) revert NotOwner();
        IERC20Min(imd).approve(address(intake), price);
        requestId = intake.request(ACTION, body, IIntake.Callback(address(this), this.onOracleResult.selector), imd, price);
        IERC20Min(imd).approve(address(intake), 0);
        questionOf[requestId] = question;
        pending[requestId] = true;
        emit Asked(requestId, question);
    }

    /// @notice Intake's callback (selector 0x510379c7, as in IMD's docs).
    function onOracleResult(bytes32 requestId, OracleAttestation calldata a, bytes calldata signature) external {
        if (msg.sender != address(intake)) revert NotIntake();
        if (!pending[requestId]) revert NotPending();
        pending[requestId] = false;
        // The delivery is recorded before the check, so a check that runs out of gas still leaves its timing.
        Result storage r = results[requestId];
        r.deliveredAt = uint64(block.timestamp);
        r.issuedAt = a.issuedAt;
        r.delivered = true;
        _check(requestId, a, signature, true);
    }

    /// @notice If the callback failed or ran out of gas: anyone hands over the attestation read from IMD's API.
    function submit(bytes32 requestId, OracleAttestation calldata a, bytes calldata signature) external {
        if (bytes(questionOf[requestId]).length == 0) revert UnknownRequest();
        _check(requestId, a, signature, false);
    }

    function sweep(address to) external {
        if (msg.sender != owner) revert NotOwner();
        IERC20Min(imd).transfer(to, IERC20Min(imd).balanceOf(address(this)));
    }

    function _check(bytes32 requestId, OracleAttestation calldata a, bytes calldata signature, bool viaCallback)
        internal
    {
        string memory question = questionOf[requestId];
        bool verified;
        bool answer;
        bytes4 err;
        uint256 g = gasleft();
        uint256 cap = g > CALLBACK_RESERVE ? g - CALLBACK_RESERVE : 0;
        try verifier.verifyBool{gas: cap}(a, signature, question) returns (bool ok) {
            verified = true;
            answer = ok;
        } catch (bytes memory reason) {
            err = reason.length >= 4 ? bytes4(reason) : bytes4(0xffffffff);
        }
        uint256 used = g - gasleft();
        Result storage r = results[requestId];
        r.issuedAt = a.issuedAt;
        r.verifyGas = uint32(used);
        r.err = err;
        r.checked = true;
        r.verified = verified;
        r.answer = answer;
        emit Checked(
            requestId, viaCallback, verified, answer, err, used, a.issuedAt, uint64(block.timestamp), a.panelSize,
            a.quorum, a.agreed
        );
    }
}
