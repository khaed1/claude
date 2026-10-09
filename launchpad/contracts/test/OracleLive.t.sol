// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {AttestationVerifier, OracleAttestation} from "../src/AttestationVerifier.sol";

/// @dev A real IMD oracle attestation for a consumer on Robinhood Chain: request a0e4c24b-4dd8-4ec6-8fef-aa185f5209c3
///      (7 Oct 2026, paid through the API), evidence chain 4663, a 51-member panel (39 agreed, quorum 36),
///      `allowAmbiguous: true`, and a question with a slash, an apostrophe, a colon and an at sign. Our verifier,
///      at the request's consumer address on chain 4663, accepts it with its own onchain rebuild of the question
///      hash: the oracle escapes none of those characters and doesn't hash `allowAmbiguous` (HANDOFF §7, R3-A4-15).
contract OracleLiveTest is Test {
    address internal constant CONSUMER = 0x4663000000000000000000000000000000004663;
    address internal constant ATTESTER = 0x5598Aa9146215Bc13eb26f2c692Ad1461Fd32982;
    string internal constant QUESTION =
        "Does the page at https://imd.fun/docs/ mention the package '@identitymd/protocol'? Answer true only if that exact text appears on the page.";

    function _attestation() internal pure returns (OracleAttestation memory a) {
        a.requestId = 0xa0e4c24b4dd84ec68fefaa185f5209c300000000000000000000000000000000;
        a.chainId = 4663;
        a.questionHash = 0x9fd6f00049feddb50072d116869a3650b30e8b69a5d5fa6752362e9bb9b9512d;
        a.answerType = 0; // bool
        a.answer = abi.encode(true);
        a.figure = 0;
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

    function test_verifier_acceptsLiveRobinhoodAttestation() public {
        vm.chainId(4663);
        address owner = makeAddr("owner");
        deployCodeTo("AttestationVerifier.sol:AttestationVerifier", abi.encode(owner), CONSUMER);
        AttestationVerifier verifier = AttestationVerifier(CONSUMER);
        vm.prank(owner);
        verifier.setSigner(ATTESTER, true);

        OracleAttestation memory a = _attestation();
        bytes memory sig =
            hex"4ba0fcf197f4a92c49122fd59b6ac4c0d4ab267ddfa90ac9ca528fc44d277d7e12e8bdc895b5fe980571ba942a1b13dd7ec6363007a47af6168e5716ce6c340e1b";
        assertEq(
            verifier.questionHash(QUESTION, 4663, 81521335, 82363546), a.questionHash, "our rebuild is the oracle's hash"
        );

        vm.warp(1791365119 + 1 hours);
        assertTrue(verifier.verifyBool(a, sig, QUESTION), "panel answered true");

        // Bound to its consumer: the same signature on another chain recovers another address.
        vm.chainId(1);
        vm.expectRevert(AttestationVerifier.UnknownSigner.selector);
        verifier.verifyBool(a, sig, QUESTION);
    }
}
