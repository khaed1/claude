// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {AttestationVerifier, OracleAttestation} from "../src/AttestationVerifier.sol";
import {OracleProbe, IIntake} from "./OracleProbe.sol";

contract ProbeIMD is ERC20 {
    function name() public pure override returns (string memory) {
        return "IMD";
    }

    function symbol() public pure override returns (string memory) {
        return "IMD";
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// Mimics Intake: `request` pulls the fee; `complete` calls the callback with a fixed 200,000-gas stipend, no revert.
contract MockIntake {
    address public immutable payTo = address(0xBEEF);
    uint256 public nonce;
    mapping(bytes32 => IIntake.Callback) public cb;

    function request(bytes32, bytes calldata, IIntake.Callback calldata callback, address asset, uint256 amount)
        external
        payable
        returns (bytes32 requestId)
    {
        requestId = keccak256(abi.encode(block.chainid, address(this), ++nonce));
        cb[requestId] = callback;
        ERC20(asset).transferFrom(msg.sender, payTo, amount);
    }

    function complete(bytes32 requestId, bytes calldata args) external returns (bool delivered) {
        IIntake.Callback memory c = cb[requestId];
        bytes memory data = bytes.concat(c.selector, args);
        address target = c.target;
        assembly ("memory-safe") {
            delivered := call(200000, target, 0, add(data, 0x20), mload(data), 0, 0)
        }
    }
}

contract OracleProbeTest is Test {
    address internal constant CONSUMER = 0x4663000000000000000000000000000000004663;
    address internal constant ATTESTER = 0x5598Aa9146215Bc13eb26f2c692Ad1461Fd32982;
    string internal constant QUESTION =
        "Does the page at https://imd.fun/docs/ mention the package '@identitymd/protocol'? Answer true only if that exact text appears on the page.";
    bytes internal constant SIG =
        hex"4ba0fcf197f4a92c49122fd59b6ac4c0d4ab267ddfa90ac9ca528fc44d277d7e12e8bdc895b5fe980571ba942a1b13dd7ec6363007a47af6168e5716ce6c340e1b";

    function _attestation() internal pure returns (OracleAttestation memory a) {
        a.requestId = 0xa0e4c24b4dd84ec68fefaa185f5209c300000000000000000000000000000000;
        a.chainId = 4663;
        a.questionHash = 0x9fd6f00049feddb50072d116869a3650b30e8b69a5d5fa6752362e9bb9b9512d;
        a.answerType = 0;
        a.answer = abi.encode(true);
        a.fromBlock = 81521335;
        a.toBlock = 82363546;
        a.blockHash = 0x1a31465835bb75f183c16cc028a38a68f0a006018f9e61f2aa3fcf9d39993ba0;
        a.panelJobId = 0xc684826466754c42a41b7517f095e4c800000000000000000000000000000000;
        a.panelSize = 51;
        a.quorum = 36;
        a.agreed = 39;
        a.issuedAt = 1791365119;
        a.expiresAt = 1791451519;
    }

    function test_probe_selectorMatchesImdDocs() public pure {
        assertEq(OracleProbe.onOracleResult.selector, bytes4(0x510379c7));
    }

    function test_probe_callbackVerifiesARealAnswerWithin200kGas() public {
        vm.chainId(4663);
        address owner = makeAddr("owner");
        deployCodeTo("AttestationVerifier.sol:AttestationVerifier", abi.encode(owner), CONSUMER);
        AttestationVerifier verifier = AttestationVerifier(CONSUMER);
        vm.prank(owner);
        verifier.setSigner(ATTESTER, true);
        ProbeIMD imd = new ProbeIMD();
        MockIntake intake = new MockIntake();
        OracleProbe probe = new OracleProbe(IIntake(address(intake)), address(imd), verifier, owner);
        imd.mint(address(probe), 1e18);
        // A long question, as long as the real activation question, costs the same SLOADs in the callback.
        vm.prank(owner);
        bytes32 id = probe.ask(QUESTION, bytes("{}"), 0.5e18);
        assertEq(imd.balanceOf(address(0xBEEF)), 0.5e18);
        assertEq(imd.allowance(address(probe), address(intake)), 0);

        vm.warp(1791365119 + 10);
        bool delivered = intake.complete(id, abi.encode(id, _attestation(), SIG));
        assertTrue(delivered, "delivered within the 200k stipend");
        (uint64 deliveredAt, uint64 issuedAt, uint32 verifyGas, bytes4 err, bool dlv, bool checked, bool verified, bool answer) =
            probe.results(id);
        console.log("verifyBool gas", verifyGas);
        assertTrue(dlv && checked && verified && answer);
        assertEq(err, bytes4(0));
        assertEq(issuedAt, 1791365119);
        assertEq(deliveredAt, 1791365119 + 10);

        // A strict issuedAt check: an answer from 30 s in the future is refused, recorded, and still delivered.
        vm.prank(owner);
        bytes32 id2 = probe.ask(QUESTION, bytes("{}"), 0.5e18);
        vm.warp(1791365119 - 30);
        assertTrue(intake.complete(id2, abi.encode(id2, _attestation(), SIG)));
        (,,, err,,, verified,) = probe.results(id2);
        assertFalse(verified);
        assertEq(err, AttestationVerifier.NotYetValid.selector);
    }

    function test_probe_callbackGasWithTheActivationQuestionLength() public {
        vm.chainId(4663);
        address owner = makeAddr("owner");
        deployCodeTo("AttestationVerifier.sol:AttestationVerifier", abi.encode(owner), CONSUMER);
        AttestationVerifier verifier = AttestationVerifier(CONSUMER);
        vm.prank(owner);
        verifier.setSigner(ATTESTER, true);
        ProbeIMD imd = new ProbeIMD();
        MockIntake intake = new MockIntake();
        OracleProbe probe = new OracleProbe(IIntake(address(intake)), address(imd), verifier, owner);
        imd.mint(address(probe), 1e18);
        // ~600 characters, like the version-activation question; the signature won't match, but the whole check runs
        // (question hash is computed and compared) before WrongQuestion, which is what costs the gas.
        string memory longQ = string.concat(QUESTION, QUESTION, QUESTION, QUESTION);
        vm.prank(owner);
        bytes32 id = probe.ask(longQ, bytes("{}"), 0.5e18);
        vm.warp(1791365119 + 10);
        assertTrue(intake.complete(id, abi.encode(id, _attestation(), SIG)), "delivered");
        (uint64 deliveredAt,, uint32 verifyGas, bytes4 err, bool dlv,,,) = probe.results(id);
        console.log("in the callback, ~560-char question: gas", verifyGas);
        console.logBytes4(err);
        assertTrue(dlv);
        assertEq(deliveredAt, 1791365119 + 10, "timing recorded even if the check ran out of gas");
        // Outside the callback, with all the gas it wants, the check runs to the end.
        probe.submit(id, _attestation(), SIG);
        (,, verifyGas, err,,,,) = probe.results(id);
        console.log("submit, ~560-char question: gas", verifyGas);
        assertEq(err, AttestationVerifier.WrongQuestion.selector);
    }
}
