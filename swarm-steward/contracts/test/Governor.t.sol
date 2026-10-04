// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "solady/tokens/ERC20.sol";
import {LibString} from "solady/utils/LibString.sol";
import {DocketBase, MockIMD, MockSafe} from "./Base.t.sol";
import {OracleGovernor} from "../src/OracleGovernor.sol";
import {IOracleGovernor} from "../src/IOracleGovernor.sol";
import {OracleAttestation, OracleAttestationLib} from "../src/OracleAttestation.sol";
import {GrowthFund} from "pondpad/GrowthFund.sol";

/// @notice The OracleGovernor behaviour, run locally (`OracleGovernorTest`) and on a Robinhood fork with a real Safe
///         and the real IMD (`ForkOracleGovernorTest` in Fork.t.sol).
abstract contract GovernorTests is DocketBase {
    using LibString for uint256;
    using LibString for address;

    // ------------------------------------------------------------------ Happy path

    function test_grant_fullFlow() public {
        uint256 id = _proposeGrant(alice, 400e18);
        assertEq(imd.balanceOf(address(gov)), 10e18, "bond held");

        string memory q = gov.question(id);
        assertTrue(LibString.contains(q, string.concat("Docket proposal ", id.toString(), " for PondPad on chain id")));
        assertTrue(LibString.contains(q, string.concat("under the charter at ", CHARTER, ", section Grants")));
        assertTrue(LibString.contains(q, "call grant(address,address,uint256,bytes32,string)"));
        assertTrue(LibString.contains(q, string.concat("to=", alice.toHexString())));
        assertTrue(LibString.contains(q, string.concat("amount_wei=400000000000000000000, ref=", id.toString(), ", reason=ipfs://")));
        assertTrue(LibString.endsWith(q, "Answer true only if every rule that applies is met."));

        _answer(id, true);
        IOracleGovernor.Action memory a = gov.actionOf(id);
        assertEq(uint8(a.status), uint8(IOracleGovernor.Status.Queued));
        assertEq(imd.balanceOf(proposer), 1_000e18, "bond refunded");

        vm.expectRevert(IOracleGovernor.NotYet.selector);
        gov.execute(id);

        vm.warp(a.executableAt);
        vm.expectEmit(address(growthFund));
        emit GrowthFund.Granted(growthFund.currentEpoch(), address(imd), alice, 400e18, bytes32(id), EVIDENCE);
        gov.execute(id);
        assertEq(imd.balanceOf(alice), 400e18);
        assertEq(uint8(gov.actionOf(id).status), uint8(IOracleGovernor.Status.Executed));
    }

    function test_callData_matchesAbiEncoding() public {
        uint256 id = _proposeGrant(alice, 5e18);
        (address target, bytes memory data) = gov.callData(id);
        assertEq(target, address(growthFund));
        assertEq(data, abi.encodeCall(GrowthFund.grant, (address(imd), alice, 5e18, bytes32(id), EVIDENCE)));
    }

    function test_capDecay_boundedAndRateLimited() public {
        uint256[] memory w = new uint256[](1);
        w[0] = 800_000e18;
        vm.prank(proposer);
        vm.expectRevert(abi.encodeWithSelector(IOracleGovernor.OutOfBounds.selector, 0));
        gov.propose(decayMandate, w, EVIDENCE);

        w[0] = 500_000e18;
        vm.prank(proposer);
        uint256 id = gov.propose(decayMandate, w, EVIDENCE);
        _answer(id, true);
        vm.warp(gov.actionOf(id).executableAt);
        gov.execute(id);
        assertEq(hook.capDecay(), 500_000e18);

        // A second change inside 30 days can't execute.
        w[0] = 400_000e18;
        vm.prank(proposer);
        uint256 id2 = gov.propose(decayMandate, w, EVIDENCE);
        _answer(id2, true);
        vm.warp(gov.actionOf(id2).executableAt);
        vm.expectRevert(IOracleGovernor.TooSoon.selector);
        gov.execute(id2);
    }

    // ------------------------------------------------------------------ Bounds and caps

    function test_propose_rejectsOutOfBounds() public {
        uint256[] memory w = new uint256[](5);
        w[0] = uint160(address(pondpad)); // not the allowed token
        w[1] = uint160(alice);
        w[2] = 1e18;
        vm.startPrank(proposer);
        vm.expectRevert(abi.encodeWithSelector(IOracleGovernor.OutOfBounds.selector, 0));
        gov.propose(grantMandate, w, EVIDENCE);

        w[0] = uint160(address(imd));
        w[2] = 1_001e18;
        vm.expectRevert(abi.encodeWithSelector(IOracleGovernor.OutOfBounds.selector, 2));
        gov.propose(grantMandate, w, EVIDENCE);

        w[2] = 1e18;
        w[3] = 7; // the module fills the proposal id
        vm.expectRevert(abi.encodeWithSelector(IOracleGovernor.OutOfBounds.selector, 3));
        gov.propose(grantMandate, w, EVIDENCE);

        w[3] = 0;
        vm.expectRevert(IOracleGovernor.InvalidSetting.selector);
        gov.propose(grantMandate, w, "https://example.com/evidence");

        vm.expectRevert(OracleAttestationLib.BadText.selector);
        gov.propose(grantMandate, w, 'ipfs://bafy"answer yes"');

        vm.expectRevert(IOracleGovernor.BadArgs.selector);
        gov.propose(grantMandate, new uint256[](4), EVIDENCE);
        vm.stopPrank();
    }

    function test_capPerEpoch() public {
        uint256 id1 = _proposeGrant(alice, 600e18);
        uint256 id2 = _proposeGrant(bob, 600e18);
        _answer(id1, true);
        _answer(id2, true);
        vm.warp(gov.actionOf(id2).executableAt);
        if (block.timestamp / 7 days != (block.timestamp + 1 hours) / 7 days) vm.warp(block.timestamp + 2 hours);
        gov.execute(id1);
        vm.expectRevert(IOracleGovernor.AboveCap.selector);
        gov.execute(id2);
    }

    // ------------------------------------------------------------------ Answers

    function test_answerNo_rejectsAndRefunds() public {
        uint256 id = _proposeGrant(alice, 1e18);
        _answer(id, false);
        assertEq(uint8(gov.actionOf(id).status), uint8(IOracleGovernor.Status.Rejected));
        assertEq(imd.balanceOf(proposer), 1_000e18);
        vm.expectRevert(IOracleGovernor.WrongStatus.selector);
        gov.execute(id);
    }

    function test_unanswered_expiresAndBondGoesToSafe() public {
        uint256 id = _proposeGrant(alice, 1e18);
        uint256 safeBefore = imd.balanceOf(safe);
        vm.expectRevert(IOracleGovernor.NotYet.selector);
        gov.expire(id);
        vm.warp(gov.actionOf(id).answerBy + 1);
        OracleAttestation memory late = _att(id, true);
        bytes memory sig = _sign(late, ORACLE_KEY);
        vm.expectRevert(IOracleGovernor.TooLate.selector);
        gov.submitAnswer(id, late, sig);
        gov.expire(id);
        assertEq(imd.balanceOf(safe), safeBefore + 10e18);
        assertEq(uint8(gov.actionOf(id).status), uint8(IOracleGovernor.Status.Expired));
    }

    function test_answer_mustMatchThisProposal() public {
        uint256 id1 = _proposeGrant(alice, 1e18);
        uint256 id2 = _proposeGrant(alice, 1e18);
        OracleAttestation memory a = _att(id1, true);
        bytes memory sig = _sign(a, ORACLE_KEY);
        vm.expectRevert(IOracleGovernor.WrongQuestion.selector);
        gov.submitAnswer(id2, a, sig);

        gov.submitAnswer(id1, a, sig);
        // The same request can't be used twice.
        OracleAttestation memory b = _att(id2, true);
        b.requestId = a.requestId;
        bytes memory sigB = _sign(b, ORACLE_KEY);
        vm.expectRevert(IOracleGovernor.RequestUsed.selector);
        gov.submitAnswer(id2, b, sigB);
    }

    function test_answer_checks() public {
        uint256 id = _proposeGrant(alice, 1e18);
        OracleAttestation memory a = _att(id, true);
        bytes memory sig;

        sig = _sign(a, 0xB0B);
        vm.expectRevert(IOracleGovernor.UnknownSigner.selector);
        gov.submitAnswer(id, a, sig);

        a = _att(id, true);
        a.panelSize = 50;
        sig = _sign(a, ORACLE_KEY);
        vm.expectRevert(IOracleGovernor.PanelTooSmall.selector);
        gov.submitAnswer(id, a, sig);

        a = _att(id, true);
        a.agreed = 33; // below 2/3 of 51
        a.quorum = 30;
        sig = _sign(a, ORACLE_KEY);
        vm.expectRevert(IOracleGovernor.NotEnoughAgreement.selector);
        gov.submitAnswer(id, a, sig);

        a = _att(id, true);
        a.agreed = 35;
        a.quorum = 36; // below the request's own quorum
        sig = _sign(a, ORACLE_KEY);
        vm.expectRevert(IOracleGovernor.NotEnoughAgreement.selector);
        gov.submitAnswer(id, a, sig);

        a = _att(id, true);
        a.issuedAt = uint64(block.timestamp - 1); // answered before the proposal existed
        sig = _sign(a, ORACLE_KEY);
        vm.expectRevert(IOracleGovernor.StaleAnswer.selector);
        gov.submitAnswer(id, a, sig);

        a = _att(id, true);
        sig = _sign(a, ORACLE_KEY);
        vm.warp(block.timestamp + 2 days); // past the attestation's expiry
        vm.expectRevert(IOracleGovernor.StaleAnswer.selector);
        gov.submitAnswer(id, a, sig);

        a = _att(id, true);
        a.answer = abi.encode(uint256(2));
        sig = _sign(a, ORACLE_KEY);
        vm.expectRevert(IOracleGovernor.NotBool.selector);
        gov.submitAnswer(id, a, sig);
    }

    function test_answerShopping_earlierNoCancels() public {
        uint256 id = _proposeGrant(alice, 1e18);
        OracleAttestation memory no = _att(id, false); // issued now, kept hidden by the proposer
        bytes memory noSig = _sign(no, ORACLE_KEY);
        vm.warp(block.timestamp + 1 hours);
        _answer(id, true);
        // Anyone who finds the earlier "no" (attestations are public) cancels the action.
        vm.prank(bob);
        gov.submitAnswer(id, no, noSig);
        assertEq(uint8(gov.actionOf(id).status), uint8(IOracleGovernor.Status.Cancelled));
    }

    function test_answerShopping_laterNoDoesNotCancel() public {
        uint256 id = _proposeGrant(alice, 1e18);
        _answer(id, true);
        vm.warp(block.timestamp + 1 hours);
        OracleAttestation memory no = _att(id, false);
        bytes memory noSig = _sign(no, ORACLE_KEY);
        vm.expectRevert(IOracleGovernor.WrongStatus.selector);
        gov.submitAnswer(id, no, noSig);
    }

    // ------------------------------------------------------------------ Veto

    function test_lockToVeto_cancelsAtQuorum() public {
        uint256 id = _proposeGrant(alice, 1e18);
        _answer(id, true);
        uint256 quorum = gov.actionOf(id).vetoQuorum;
        assertEq(quorum, pondpad.totalSupply() * 500 / 10_000);

        // Alice locks half the quorum in $PONDPAD, Bob the rest as sPONDPAD.
        pondpad.transfer(alice, quorum / 2);
        pondpad.transfer(bob, quorum);
        vm.startPrank(alice);
        pondpad.approve(address(gov), type(uint256).max);
        gov.lockVeto(id, address(pondpad), quorum / 2);
        vm.stopPrank();
        assertEq(uint8(gov.actionOf(id).status), uint8(IOracleGovernor.Status.Queued));

        vm.startPrank(bob);
        pondpad.approve(address(spondpad), type(uint256).max);
        uint256 shares = spondpad.deposit(quorum, bob);
        spondpad.approve(address(gov), type(uint256).max);
        gov.lockVeto(id, address(spondpad), shares);
        vm.stopPrank();
        assertEq(uint8(gov.actionOf(id).status), uint8(IOracleGovernor.Status.Cancelled));

        // Locks stay until the timelock would have ended (no flash-loan vetoes).
        vm.prank(alice);
        vm.expectRevert(IOracleGovernor.NotYet.selector);
        gov.unlockVeto(id, address(pondpad));
        vm.warp(gov.actionOf(id).executableAt);
        vm.prank(alice);
        gov.unlockVeto(id, address(pondpad));
        assertEq(pondpad.balanceOf(alice), quorum / 2);
        vm.prank(bob);
        gov.unlockVeto(id, address(spondpad));
        assertEq(spondpad.balanceOf(bob), shares);

        vm.expectRevert(IOracleGovernor.WrongStatus.selector);
        gov.execute(id);
    }

    function test_lockToVeto_closedAfterTimelock() public {
        uint256 id = _proposeGrant(alice, 1e18);
        _answer(id, true);
        vm.warp(gov.actionOf(id).executableAt);
        pondpad.approve(address(gov), 1e18);
        vm.expectRevert(IOracleGovernor.WrongStatus.selector);
        gov.lockVeto(id, address(pondpad), 1e18);
        vm.expectRevert(IOracleGovernor.NoVeto.selector);
        gov.unlockVeto(id, address(pondpad));
    }

    function test_guardianCancels() public {
        uint256 id = _proposeGrant(alice, 1e18);
        vm.prank(alice);
        vm.expectRevert(IOracleGovernor.Unauthorized.selector);
        gov.cancel(id);
        _answer(id, true);
        vm.prank(guardian);
        gov.cancel(id);
        vm.warp(gov.actionOf(id).executableAt);
        vm.expectRevert(IOracleGovernor.WrongStatus.selector);
        gov.execute(id);
    }

    function test_executionWindow() public {
        uint256 id = _proposeGrant(alice, 1e18);
        _answer(id, true);
        vm.warp(gov.actionOf(id).expiresAt);
        vm.expectRevert(IOracleGovernor.TooLate.selector);
        gov.execute(id);
        gov.expire(id);
        assertEq(uint8(gov.actionOf(id).status), uint8(IOracleGovernor.Status.Expired));
    }

    // ------------------------------------------------------------------ Config

    function test_config_onlyThroughSafeAndTimelock() public {
        vm.expectRevert(IOracleGovernor.Unauthorized.selector);
        gov.setGuardian(alice);
        vm.expectRevert(IOracleGovernor.Unauthorized.selector);
        gov.proposeConfig(abi.encodeCall(OracleGovernor.setGuardian, (alice)));

        // Only config functions can be proposed.
        vm.expectRevert(IOracleGovernor.InvalidSetting.selector);
        _asSafe(address(gov), abi.encodeCall(OracleGovernor.proposeConfig, (abi.encodeCall(OracleGovernor.execute, (1)))));

        uint256 id = gov.actionCount() + 1;
        _asSafe(address(gov), abi.encodeCall(OracleGovernor.proposeConfig, (abi.encodeCall(OracleGovernor.setGuardian, (alice)))));
        vm.expectRevert(IOracleGovernor.NotYet.selector);
        gov.execute(id);
        vm.warp(gov.actionOf(id).executableAt);
        gov.execute(id);
        assertEq(gov.guardian(), alice);
    }

    function test_config_vetoedByHolders() public {
        uint256 id = gov.actionCount() + 1;
        _asSafe(address(gov), abi.encodeCall(OracleGovernor.proposeConfig, (abi.encodeCall(OracleGovernor.setGuardian, (alice)))));
        uint256 quorum = gov.actionOf(id).vetoQuorum;
        assertEq(quorum, pondpad.totalSupply() / 10);
        pondpad.approve(address(gov), quorum);
        gov.lockVeto(id, address(pondpad), quorum);
        assertEq(uint8(gov.actionOf(id).status), uint8(IOracleGovernor.Status.Cancelled));
        assertEq(gov.guardian(), guardian);
    }

    function test_config_safeCancelsOwnChange() public {
        uint256 id = gov.actionCount() + 1;
        _asSafe(address(gov), abi.encodeCall(OracleGovernor.proposeConfig, (abi.encodeCall(OracleGovernor.setGuardian, (alice)))));
        _asSafe(address(gov), abi.encodeCall(OracleGovernor.cancel, (id)));
        assertEq(uint8(gov.actionOf(id).status), uint8(IOracleGovernor.Status.Cancelled));
    }

    function test_disableMandate_isInstantAndBlocksExecution() public {
        uint256 id = _proposeGrant(alice, 1e18);
        _answer(id, true);
        vm.prank(alice);
        vm.expectRevert(IOracleGovernor.Unauthorized.selector);
        gov.disableMandate(grantMandate);
        _asSafe(address(gov), abi.encodeCall(OracleGovernor.disableMandate, (grantMandate)));
        vm.warp(gov.actionOf(id).executableAt);
        vm.expectRevert(IOracleGovernor.MandateInactive.selector);
        gov.execute(id);
        vm.prank(proposer);
        vm.expectRevert(IOracleGovernor.MandateInactive.selector);
        gov.propose(grantMandate, new uint256[](5), EVIDENCE);
    }

    function test_addMandate_validation() public {
        (IOracleGovernor.Mandate memory m, IOracleGovernor.ArgRule[] memory a) = _grantMandate();
        m.signature = "grant(address,address,uint256,bytes32)"; // 4 params, 5 rules
        _expectConfigFails(abi.encodeCall(OracleGovernor.addMandate, (m, a)));

        (m, a) = _grantMandate();
        m.target = safe; // the Safe itself: no
        _expectConfigFails(abi.encodeCall(OracleGovernor.addMandate, (m, a)));

        (m, a) = _grantMandate();
        m.minAgreementBps = 5_000;
        _expectConfigFails(abi.encodeCall(OracleGovernor.addMandate, (m, a)));

        (m, a) = _grantMandate();
        a[3] = _rule(IOracleGovernor.ArgKind.Evidence, IOracleGovernor.Check.Any, 0, 0, "second");
        _expectConfigFails(abi.encodeCall(OracleGovernor.addMandate, (m, a)));
    }

    function _expectConfigFails(bytes memory call) internal {
        uint256 id = gov.actionCount() + 1;
        _asSafe(address(gov), abi.encodeCall(OracleGovernor.proposeConfig, (call)));
        vm.warp(gov.actionOf(id).executableAt);
        vm.expectRevert();
        gov.execute(id);
    }

    // ------------------------------------------------------------------ Format

    /// @dev A real attestation from api.imd.fun (request 145633d5…, signer 0x5598…2982), also used by PondPad's
    ///      tests: checks our EIP-712 struct hash against what the oracle actually signs.
    function test_structHash_matchesLiveImdAttestation() public pure {
        OracleAttestation memory a;
        a.requestId = 0x145633d5031f4b9499d72f33b8a3261b00000000000000000000000000000000;
        a.chainId = 1;
        a.questionHash = 0x190d8eddbf6187c0ac2abcb41290d06adb73c7fdc9c0af65eea30a9237a59727;
        a.answerType = 2;
        a.answer = hex"63686c6f726f7068796c6c000000000000000000000000000000000000000000";
        a.fromBlock = 26115475;
        a.toBlock = 26115774;
        a.blockHash = 0xfb68a2df5d4f0f8dcedd2b8258f3a76c4af1ee4d01df82c4a2f300ff088d6614;
        a.panelJobId = 0x79416ef99b254efab6263be3bb05239000000000000000000000000000000000;
        a.panelSize = 200;
        a.quorum = 140;
        a.agreed = 140;
        a.issuedAt = 1791080459;
        a.expiresAt = 1791102059;
        bytes32 domain = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("IdentityMD Oracle"),
                keccak256("2"),
                uint256(1),
                address(0)
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domain, _structHash(a)));
        address signer = ecrecover(
            digest,
            0x1b,
            0x6724351565e38a8cccda51d268558b61f4f95c116b10c55b7246ca45530c50ef,
            0x03f40e1ea99a1408ee0e637e3ea561eca2e03bb788c399b1fee8f7dda19446f0
        );
        assertEq(signer, 0x5598Aa9146215Bc13eb26f2c692Ad1461Fd32982);
    }

    function test_digest_matchesContract() public {
        uint256 id = _proposeGrant(alice, 1e18);
        OracleAttestation memory a = _att(id, true);
        bytes32 domain = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("IdentityMD Oracle"),
                keccak256("2"),
                block.chainid,
                address(gov)
            )
        );
        assertEq(gov.attestationDigest(a), keccak256(abi.encodePacked("\x19\x01", domain, _structHash(a))));
    }

    function test_question_fitsOracleLimit() public {
        uint256 id = _proposeGrant(alice, 1_000e18);
        assertLt(bytes(gov.question(id)).length, 2_000);
    }
}

/// @notice Local run: a minimal Safe and a mock IMD.
contract OracleGovernorTest is GovernorTests {
    function _deploySafe() internal override returns (address) {
        return address(new MockSafe());
    }

    function _deployImd() internal override returns (ERC20) {
        return new MockIMD();
    }

    function _giveImd(address to, uint256 amount) internal override {
        MockIMD(address(imd)).mint(to, amount);
    }

    function _asSafe(address to, bytes memory data) internal override {
        MockSafe(safe).exec(to, data);
    }
}
