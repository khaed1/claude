// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "solady/auth/Ownable.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Base} from "./Base.t.sol";
import {BondingCurve} from "../src/BondingCurve.sol";
import {AttestationVerifier, OracleAttestation} from "../src/AttestationVerifier.sol";
import {CTOModule} from "../src/CTOModule.sol";
import {VersionRegistry} from "../src/VersionRegistry.sol";
import {SocialRegistry} from "../src/SocialRegistry.sol";
import {PadLens} from "../src/PadLens.sol";
import {PadToken} from "../src/PadToken.sol";
import {SwarmBudget} from "../src/SwarmBudget.sol";
import {CoinFees} from "../src/FeeLib.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

/// @dev Stands in for a community Safe: takeovers only go to contracts.
contract MockSafe {}

/// @dev Calls `target` from inside its own PoolManager unlock, as an outside router or attacker contract would.
contract UnlockCaller {
    IPoolManager internal immutable pm;

    constructor(IPoolManager pm_) {
        pm = pm_;
    }

    function run(address target, bytes calldata data) external {
        pm.unlock(abi.encode(target, data));
    }

    function unlockCallback(bytes calldata raw) external returns (bytes memory) {
        (address target, bytes memory data) = abi.decode(raw, (address, bytes));
        (bool ok, bytes memory ret) = target.call(data);
        if (!ok) {
            assembly ("memory-safe") {
                revert(add(ret, 32), mload(ret))
            }
        }
        return "";
    }
}

contract GovernanceTest is Base {
    address internal constant CTO_ADDR = address(0xC70C70);
    uint256 internal constant T0 = 1_000_000;
    string internal constant RULES = "ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi";
    uint256 internal constant P = T0 + 30 days; // first time a coin launched at T0 can be taken over

    AttestationVerifier internal verifier;
    CTOModule internal cto;
    VersionRegistry internal versions;
    SocialRegistry internal social;
    PadLens internal lens;

    address internal slowTimelock = makeAddr("slowTimelock");
    address internal council = makeAddr("council");
    address internal newOwner; // the community multisig
    uint256 internal oracleKey = 0xA11CE;
    address internal oracle;
    uint256 internal linkKey = 0xB0B;
    address internal linker;
    uint256 internal _req;

    function _ctoModuleAddress() internal pure override returns (address) {
        return CTO_ADDR;
    }

    function setUp() public override {
        super.setUp();
        vm.warp(T0);
        oracle = vm.addr(oracleKey);
        linker = vm.addr(linkKey);
        verifier = new AttestationVerifier(slowTimelock);
        social = new SocialRegistry(address(this), address(vault), linker);
        deployCodeTo(
            "CTOModule.sol:CTOModule",
            abi.encode(slowTimelock, address(vault), address(curve), address(social), address(verifier), council, RULES),
            CTO_ADDR
        );
        cto = CTOModule(CTO_ADDR);
        versions = new VersionRegistry(address(this), address(verifier));
        newOwner = address(new MockSafe());
        lens = new PadLens(address(curve), address(hook), address(vault), address(budget));
    }

    // ------------------------------------------------------------------ Helpers

    /// @dev A bool attestation for `question`, valid now, from a 60-member panel with 50 agreeing.
    function _att(string memory question, bool answer) internal returns (OracleAttestation memory a) {
        a.requestId = bytes32(++_req);
        a.chainId = 4663;
        a.fromBlock = 100;
        a.toBlock = 200;
        a.questionHash = verifier.questionHash(question, a.chainId, a.fromBlock, a.toBlock);
        a.answerType = 0;
        a.answer = abi.encode(answer);
        a.panelSize = 60;
        a.quorum = 40;
        a.agreed = 50;
        a.issuedAt = uint64(T0 - 1);
        a.expiresAt = uint64(T0 + 365 days);
    }

    function _sign(OracleAttestation memory a, uint256 key) internal view returns (bytes memory) {
        bytes32 digest =
            keccak256(abi.encodePacked("\x19\x01", verifier.domainSeparator(), verifier.hashAttestation(a)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _approveOracle() internal {
        vm.prank(slowTimelock);
        verifier.setSigner(oracle, true);
    }

    // ------------------------------------------------------------------ AttestationVerifier

    /// @dev A real attestation from api.imd.fun (request 145633d5…, signer 0x5598…2982): checks our EIP-712 type
    ///      hash and our rebuild of the oracle's question hash against what the oracle actually signs.
    function test_verifier_matchesLiveImdAttestation() public view {
        OracleAttestation memory a;
        a.requestId = 0x145633d5031f4b9499d72f33b8a3261b00000000000000000000000000000000;
        a.chainId = 1;
        a.questionHash = 0x190d8eddbf6187c0ac2abcb41290d06adb73c7fdc9c0af65eea30a9237a59727;
        a.answerType = 2; // bytes32
        a.answer = hex"63686c6f726f7068796c6c000000000000000000000000000000000000000000"; // "chlorophyll"
        a.figure = 0;
        a.fromBlock = 26115475;
        a.toBlock = 26115774;
        a.blockHash = 0xfb68a2df5d4f0f8dcedd2b8258f3a76c4af1ee4d01df82c4a2f300ff088d6614;
        a.panelJobId = 0x79416ef99b254efab6263be3bb05239000000000000000000000000000000000;
        a.panelSize = 200;
        a.quorum = 140;
        a.agreed = 140;
        a.issuedAt = 1791080459;
        a.expiresAt = 1791102059;

        assertEq(
            verifier.questionHashTyped(
                "Which pigment makes plants green? Answer with the single word only, in lowercase.",
                "bytes32",
                1,
                26115475,
                26115774
            ),
            a.questionHash
        );

        // That request named no consumer, so it was signed for chain 1 and the zero address.
        bytes32 domain = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("IdentityMD Oracle"),
                keccak256("2"),
                uint256(1),
                address(0)
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domain, verifier.hashAttestation(a)));
        address signer = ecrecover(
            digest,
            0x1b,
            0x6724351565e38a8cccda51d268558b61f4f95c116b10c55b7246ca45530c50ef,
            0x03f40e1ea99a1408ee0e637e3ea561eca2e03bb788c399b1fee8f7dda19446f0
        );
        assertEq(signer, 0x5598Aa9146215Bc13eb26f2c692Ad1461Fd32982);
    }

    function test_verifier_acceptsGoodRejectsBad() public {
        string memory q = "Is this a test question?";
        OracleAttestation memory a = _att(q, true);
        bytes memory sig = _sign(a, oracleKey);

        vm.expectRevert(AttestationVerifier.UnknownSigner.selector); // no signer approved yet
        verifier.verifyBool(a, sig, q);
        _approveOracle();
        assertTrue(verifier.verifyBool(a, sig, q));

        OracleAttestation memory no = _att(q, false);
        assertFalse(verifier.verifyBool(no, _sign(no, oracleKey), q));

        vm.expectRevert(AttestationVerifier.WrongQuestion.selector);
        verifier.verifyBool(a, sig, "Is this another question?");
        bytes memory bad = _sign(a, 0xBAD);
        vm.expectRevert(AttestationVerifier.UnknownSigner.selector);
        verifier.verifyBool(a, bad, q);

        OracleAttestation memory b = _att(q, true);
        b.panelSize = 50; // must be more than 50
        b.quorum = 40;
        b.agreed = 45;
        bytes memory bs = _sign(b, oracleKey);
        vm.expectRevert(AttestationVerifier.PanelTooSmall.selector);
        verifier.verifyBool(b, bs, q);

        b = _att(q, true);
        b.agreed = 39; // below 2/3 of 60
        b.quorum = 30;
        bs = _sign(b, oracleKey);
        vm.expectRevert(AttestationVerifier.NotEnoughAgreement.selector);
        verifier.verifyBool(b, bs, q);

        b = _att(q, true);
        b.quorum = 55; // agreed 50 < the request's own quorum
        bs = _sign(b, oracleKey);
        vm.expectRevert(AttestationVerifier.NotEnoughAgreement.selector);
        verifier.verifyBool(b, bs, q);

        b = _att(q, true);
        b.answerType = 2;
        bs = _sign(b, oracleKey);
        vm.expectRevert(AttestationVerifier.NotBool.selector);
        verifier.verifyBool(b, bs, q);

        b = _att(q, true);
        b.answer = abi.encode(uint256(2));
        bs = _sign(b, oracleKey);
        vm.expectRevert(AttestationVerifier.NotBool.selector);
        verifier.verifyBool(b, bs, q);

        b = _att(q, true);
        b.issuedAt = uint64(T0 + 1);
        bs = _sign(b, oracleKey);
        vm.expectRevert(AttestationVerifier.NotYetValid.selector);
        verifier.verifyBool(b, bs, q);

        vm.warp(T0 + 365 days + 1);
        vm.expectRevert(AttestationVerifier.Expired.selector);
        verifier.verifyBool(a, sig, q);

        vm.expectRevert(AttestationVerifier.BadQuestionText.selector);
        verifier.questionHash('say "yes"', 1, 1, 2);
    }

    /// @dev Audit R1-A4-13: exactly two thirds meets the two-thirds bar; one member fewer doesn't.
    function test_verifier_exactTwoThirdsAccepted() public {
        _approveOracle();
        string memory q = "Is this a test question?";
        uint16[3] memory panels = [uint16(51), 75, 99];
        for (uint256 i; i < 3; i++) {
            OracleAttestation memory a = _att(q, true);
            a.panelSize = panels[i];
            a.agreed = panels[i] * 2 / 3;
            a.quorum = a.agreed;
            assertTrue(verifier.verifyBool(a, _sign(a, oracleKey), q));
            a.agreed -= 1;
            a.quorum = a.agreed;
            bytes memory sig = _sign(a, oracleKey);
            vm.expectRevert(AttestationVerifier.NotEnoughAgreement.selector);
            verifier.verifyBool(a, sig, q);
        }
    }

    function test_verifier_settingsBounded() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        verifier.setSigner(oracle, true);
        vm.startPrank(slowTimelock);
        verifier.setSigner(oracle, true);
        assertEq(verifier.signerCount(), 1);
        vm.expectRevert(AttestationVerifier.InvalidSetting.selector);
        verifier.setSigner(oracle, true); // no double count
        vm.expectRevert(AttestationVerifier.InvalidSetting.selector);
        verifier.setThresholds(4, 6_667);
        vm.expectRevert(AttestationVerifier.InvalidSetting.selector);
        verifier.setThresholds(101, 6_667);
        vm.expectRevert(AttestationVerifier.InvalidSetting.selector);
        verifier.setThresholds(51, 5_000);
        verifier.setThresholds(75, 7_500);
        verifier.setSigner(oracle, false);
        vm.stopPrank();
        assertEq(verifier.minPanelSize(), 75);
        assertEq(verifier.signerCount(), 0);
    }

    // ------------------------------------------------------------------ CTOModule

    function _coinWithCreatorFees(CoinFees memory fees) internal returns (address coin) {
        coin = _launch(fees, 0);
        vm.warp(T0 + 1 hours);
        _buy(alice, coin, 100e18);
        assertGt(vault.balanceOf(coin), 0);
    }

    /// @dev Links `who`'s wallet to X account `handle` with a voucher from the X link service.
    function _linkX(address who, string memory handle) internal {
        uint256 nonce = social.walletNonces(who);
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                social.domainSeparator(),
                keccak256(
                    abi.encode(social.WALLET_LINK_TYPEHASH(), who, keccak256(bytes(vm.toLowercase(handle))), nonce, block.timestamp + 1)
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s_) = vm.sign(linkKey, digest);
        vm.prank(who);
        social.linkWallet(handle, block.timestamp + 1, abi.encodePacked(r, s_, v));
    }

    /// @dev Bob (X: frogdao) proposes moving `coin`'s fees to `to` with an oracle "yes".
    function _proposeAsBob(address coin, address to) internal returns (OracleAttestation memory a, bytes memory sig) {
        a = _att(cto.question(coin, to, "frogdao"), true);
        sig = _sign(a, oracleKey);
        vm.prank(bob);
        cto.propose(coin, to, a, sig);
    }

    function test_cto_attestedTakeoverToMultisig() public {
        _approveOracle();
        address coin = _coinWithCreatorFees(_noTax());
        _linkX(bob, "frogdao");
        vm.warp(P);
        (OracleAttestation memory a, bytes memory sig) = _proposeAsBob(coin, newOwner);
        CTOModule.Takeover memory t = cto.pendingOf(coin);
        assertEq(t.newRecipient, newOwner);
        assertEq(t.proposer, bob);
        assertEq(social.walletHandle(t.proposer), "frogdao"); // shown on the takeover page

        // The creator moving fees during the notice doesn't cancel the takeover.
        vm.prank(creator);
        vault.setRecipient(coin, alice);

        vm.warp(P + 3 days - 1);
        vm.expectRevert(CTOModule.NotYet.selector);
        cto.execute(coin);
        vm.prank(council);
        vm.expectRevert(CTOModule.NotCouncil.selector); // nobody can cancel an attested takeover
        cto.cancel(coin);

        uint256 accrued = vault.balanceOf(coin);
        uint256 aliceBefore = imd.balanceOf(alice);
        vm.warp(P + 3 days);
        cto.execute(coin);
        assertEq(vault.recipientOf(coin), newOwner);
        assertEq(imd.balanceOf(alice) - aliceBefore, accrued); // accrued fees went to the old recipient
        assertEq(vault.balanceOf(coin), 0);

        address another = address(new MockSafe());
        vm.prank(bob);
        vm.expectRevert(CTOModule.RequestUsed.selector); // the same attestation can't be replayed
        cto.propose(coin, another, a, sig);

        // No new takeover of this coin for 90 days.
        address other = address(new MockSafe());
        OracleAttestation memory b = _att(cto.question(coin, other, "frogdao"), true);
        bytes memory bSig = _sign(b, oracleKey);
        vm.warp(P + 3 days + 90 days - 1);
        vm.prank(bob);
        vm.expectRevert(CTOModule.Cooldown.selector);
        cto.propose(coin, other, b, bSig);
        vm.warp(P + 3 days + 90 days);
        vm.prank(bob);
        cto.propose(coin, other, b, bSig);
    }

    function test_cto_guards() public {
        _approveOracle();
        address coin = _coinWithCreatorFees(_noTax());
        OracleAttestation memory a = _att(cto.question(coin, newOwner, "frogdao"), true);
        bytes memory sig = _sign(a, oracleKey);

        vm.prank(bob);
        vm.expectRevert(CTOModule.NoXAccount.selector); // proposers need a verified X account
        cto.propose(coin, newOwner, a, sig);
        _linkX(bob, "frogdao");
        vm.prank(bob);
        vm.expectRevert(CTOModule.TooYoung.selector); // coins under 30 days can't be taken over
        cto.propose(coin, newOwner, a, sig);

        vm.warp(P);
        // A plain wallet can't receive a takeover: it must be a multisig or the coin (holders).
        OracleAttestation memory eoa = _att(cto.question(coin, alice, "frogdao"), true);
        bytes memory eoaSig = _sign(eoa, oracleKey);
        vm.prank(bob);
        vm.expectRevert(CTOModule.InvalidRecipient.selector);
        cto.propose(coin, alice, eoa, eoaSig);

        // An attestation naming Bob can't be used by another proposer.
        _linkX(alice, "alicefrog");
        vm.prank(alice);
        vm.expectRevert(AttestationVerifier.WrongQuestion.selector);
        cto.propose(coin, newOwner, a, sig);

        OracleAttestation memory no = _att(cto.question(coin, newOwner, "frogdao"), false);
        bytes memory noSig = _sign(no, oracleKey);
        vm.prank(bob);
        vm.expectRevert(CTOModule.AnswerNo.selector);
        cto.propose(coin, newOwner, no, noSig);

        vm.prank(bob);
        cto.propose(coin, newOwner, a, sig);
        OracleAttestation memory b = _att(cto.question(coin, coin, "frogdao"), true);
        bytes memory bSig = _sign(b, oracleKey);
        vm.prank(bob);
        vm.expectRevert(CTOModule.Pending.selector); // one takeover at a time
        cto.propose(coin, coin, b, bSig);

        // Once the execution window closes unexecuted, a new takeover can be proposed.
        vm.warp(P + 6 days);
        vm.expectRevert(CTOModule.WindowClosed.selector);
        cto.execute(coin);
        vm.prank(bob);
        cto.propose(coin, coin, b, bSig);
    }

    function test_cto_contestNeedsLargerPanel() public {
        _approveOracle();
        address coin = _coinWithCreatorFees(_noTax());
        _linkX(bob, "frogdao");
        vm.warp(P);
        _proposeAsBob(coin, newOwner);

        vm.prank(alice);
        vm.expectRevert(CTOModule.NotRecipient.selector); // only the current fee recipient contests
        cto.contest(coin);
        vm.prank(creator);
        cto.contest(coin);
        vm.prank(creator);
        vm.expectRevert(CTOModule.AlreadyContested.selector);
        cto.contest(coin);

        vm.warp(P + 3 days);
        vm.expectRevert(CTOModule.NotYet.selector); // 7 more days
        cto.execute(coin);

        // The first panel's answer doesn't count twice, and a confirmation needs at least 75 members.
        OracleAttestation memory small = _att(cto.confirmQuestion(coin, newOwner, "frogdao"), true);
        bytes memory smallSig = _sign(small, oracleKey);
        vm.expectRevert(CTOModule.PanelTooSmall.selector);
        cto.confirm(coin, small, smallSig);
        OracleAttestation memory wrong = _att(cto.question(coin, newOwner, "frogdao"), true);
        wrong.panelSize = 80;
        wrong.agreed = 60;
        wrong.issuedAt = uint64(P + 1 days);
        bytes memory wrongSig = _sign(wrong, oracleKey);
        vm.expectRevert(AttestationVerifier.WrongQuestion.selector);
        cto.confirm(coin, wrong, wrongSig);

        vm.warp(P + 10 days);
        vm.expectRevert(CTOModule.NotContested.selector); // contested and not confirmed
        cto.execute(coin);

        OracleAttestation memory big = _att(cto.confirmQuestion(coin, newOwner, "frogdao"), true);
        big.panelSize = 80;
        big.agreed = 60;
        big.issuedAt = uint64(P + 1 days); // asked after the contest
        bytes memory bigSig = _sign(big, oracleKey);
        cto.confirm(coin, big, bigSig); // anyone can submit it
        cto.execute(coin);
        assertEq(vault.recipientOf(coin), newOwner);
    }

    function test_cto_routeFeesToHolders() public {
        _approveOracle();
        // 1% coin tax, all to the swarm budget, so the coin also has a budget to hand over.
        address coin = _coinWithCreatorFees(CoinFees(100, 0, 0, 10_000));
        assertGt(budget.available(coin), 0);
        vm.expectRevert(Ownable.Unauthorized.selector); // only once fees are routed to holders
        budget.sweepToHolders(coin);

        _linkX(bob, "frogdao");
        vm.warp(P);
        _proposeAsBob(coin, coin); // the coin itself = its holders
        vm.warp(P + 3 days);
        cto.execute(coin);
        assertEq(vault.recipientOf(coin), coin);

        // New creator fees and the swarm budget now reach holders as IMD dividends, over about 7 days (D-78).
        _buy(bob, coin, 100e18);
        uint256 creatorFees = vault.balanceOf(coin);
        uint256 swarm = budget.available(coin);
        uint256 aliceBefore = PadToken(coin).withdrawableDividendOf(alice);
        vault.claim(coin); // anyone
        budget.sweepToHolders(coin); // anyone
        assertEq(budget.available(coin), 0);
        assertEq(PadToken(coin).withdrawableDividendOf(alice), aliceBefore, "nothing in one go");
        (uint128 remaining,,) = vault.holderStreamOf(coin);
        assertEq(remaining, creatorFees + swarm);
        uint256 day = P + 3 days;
        for (uint256 i = 1; i <= 7; i++) {
            vm.warp(day + i * 1 days);
            uint256 released = vault.releaseToHolders(coin); // anyone, at most one day's share
            assertLe(released, (creatorFees + swarm) / 7 + 1 days); // the per-second rate is rounded up
        }
        (remaining,,) = vault.holderStreamOf(coin);
        assertEq(remaining, 0, "all paid in 7 days");
        uint256 gained = PadToken(coin).withdrawableDividendOf(alice) - aliceBefore
            + PadToken(coin).withdrawableDividendOf(bob);
        assertApproxEqAbs(gained, creatorFees + swarm, 1e6);
        vm.prank(creator);
        vm.expectRevert(); // nobody holds the recipient role any more
        vault.setRecipient(coin, creator);
    }

    /// @dev Audit R1-A4-1: a wallet with no position can't buy, release a holder lump (creator fees and swarm
    ///      budget of a coin whose fees go to holders), claim its dividend and sell back in one block for a profit.
    function test_cto_holderLumpCantBeCapturedInOneBlock() public {
        address coin = _coinWithCreatorFees(CoinFees(300, 5_000, 0, 5_000));
        // A long-lived coin: lots of creator fees and swarm budget waiting (credited as the curve and hook do).
        imd.mint(address(vault), 2_000e18);
        vm.prank(address(curve));
        vault.credit(coin, 2_000e18);
        imd.mint(address(budget), 1_500e18);
        vm.prank(address(curve));
        budget.credit(coin, 1_500e18);
        vm.prank(creator);
        vault.setRecipient(coin, coin); // fees to holders

        address carol = makeAddr("carol");
        imd.mint(carol, 1_000e18);
        vm.prank(carol);
        imd.approve(address(router), type(uint256).max);
        uint256 before = imd.balanceOf(carol);
        uint256 got = _buy(carol, coin, 1_000e18);
        vault.claim(coin);
        budget.sweepToHolders(coin);
        vm.prank(carol);
        PadToken(coin).claim();
        _sell(carol, coin, got);
        assertLe(imd.balanceOf(carol), before, "no profit from a one-block position");
    }

    /// @dev Audit R1-A4-8: creator fees still pending in the hook (outside-router swaps since the last flush) at
    ///      execution go to the old recipient, like every fee accrued before the takeover.
    function test_cto_hookPendingFeesGoToOldRecipient() public {
        _approveOracle();
        address coin = _launch(_noTax(), 0);
        _fillCurve(coin);
        vault.claim(coin);
        _linkX(bob, "frogdao");
        vm.warp(P);
        _proposeAsBob(coin, newOwner);
        vm.warp(P + 3 days);

        PoolKey memory key = hook.poolKey(coin);
        bool imdIs0 = Currency.unwrap(key.currency0) == address(imd);
        PoolSwapTest swapper = new PoolSwapTest(IPoolManager(address(pm)));
        imd.mint(address(this), 100e18);
        imd.approve(address(swapper), type(uint256).max);
        swapper.swap(
            key,
            SwapParams({
                zeroForOne: imdIs0,
                amountSpecified: -100e18,
                sqrtPriceLimitX96: imdIs0 ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
        (, uint128 pendingCreator,,) = hook.pending(coin);
        assertEq(pendingCreator, 0.5e18);
        uint256 before = imd.balanceOf(creator);
        cto.execute(coin); // without anyone flushing first
        assertEq(imd.balanceOf(creator) - before, 0.5e18, "old recipient paid the pending fees");
        assertEq(vault.balanceOf(coin), 0);
    }

    function test_cto_councilFallbackAndRetirement() public {
        address coin = _coinWithCreatorFees(_noTax());
        vm.warp(P);
        vm.expectRevert(CTOModule.NotCouncil.selector);
        cto.proposeByCouncil(coin, newOwner, "ipfs://evidence");

        vm.prank(council);
        cto.proposeByCouncil(coin, newOwner, "ipfs://evidence");
        vm.prank(council);
        cto.cancel(coin); // the council may withdraw its own proposal
        assertEq(cto.pendingOf(coin).newRecipient, address(0));
        vm.prank(council);
        vm.expectRevert(CTOModule.Cooldown.selector); // and then waits 90 days for this coin
        cto.proposeByCouncil(coin, newOwner, "ipfs://evidence");

        vm.warp(P + 90 days);
        vm.prank(council);
        cto.proposeByCouncil(coin, newOwner, "ipfs://evidence");
        vm.warp(P + 90 days + 3 days);
        vm.expectRevert(CTOModule.NotYet.selector); // the council path has a 7-day notice
        cto.execute(coin);
        vm.prank(creator);
        cto.contest(coin);
        vm.warp(P + 90 days + 14 days);
        vm.expectRevert(CTOModule.NotContested.selector);
        cto.execute(coin);
        vm.prank(council);
        cto.confirmByCouncil(coin);
        cto.execute(coin);
        assertEq(vault.recipientOf(coin), newOwner);

        // Retiring needs a working oracle signer, and is one-way.
        vm.prank(slowTimelock);
        vm.expectRevert(CTOModule.CannotRetire.selector);
        cto.retireCouncil();
        _approveOracle();
        vm.prank(slowTimelock);
        cto.retireCouncil();
        vm.warp(P + 90 days + 14 days + 90 days);
        vm.prank(council);
        vm.expectRevert(CTOModule.NotCouncil.selector);
        cto.proposeByCouncil(coin, coin, "ipfs://evidence");
    }

    /// @dev Audit R1-A4-2: the confirmation names the X account the takeover was proposed under; unlinking the
    ///      proposer (the X link key, the 48 h timelock or the proposer) can't veto or rebind it.
    function test_cto_confirmUsesHandleFromProposal() public {
        _approveOracle();
        address coin = _coinWithCreatorFees(_noTax());
        _linkX(bob, "frogdao");
        vm.warp(P);
        _proposeAsBob(coin, newOwner);
        assertEq(cto.proposerXOf(coin), "frogdao");
        vm.prank(creator);
        cto.contest(coin);
        vm.prank(linker);
        social.unlinkWallet(bob);
        _linkX(bob, "otherfrog"); // relinking to another account changes nothing either

        OracleAttestation memory rebound = _att(cto.confirmQuestion(coin, newOwner, "otherfrog"), true);
        rebound.panelSize = 80;
        rebound.agreed = 60;
        rebound.issuedAt = uint64(P + 1 days);
        bytes memory reboundSig = _sign(rebound, oracleKey);
        vm.warp(P + 1 days);
        vm.expectRevert(AttestationVerifier.WrongQuestion.selector);
        cto.confirm(coin, rebound, reboundSig);

        OracleAttestation memory big = _att(cto.confirmQuestion(coin, newOwner, "frogdao"), true);
        big.panelSize = 80;
        big.agreed = 60;
        big.issuedAt = uint64(P + 1 days);
        cto.confirm(coin, big, _sign(big, oracleKey));
        vm.warp(P + 10 days);
        cto.execute(coin);
        assertEq(vault.recipientOf(coin), newOwner);
    }

    /// @dev Audit R1-A4-3: a confirming "yes" issued before the contest (asked in advance) doesn't count.
    function test_cto_confirmMustFollowContest() public {
        _approveOracle();
        address coin = _coinWithCreatorFees(_noTax());
        _linkX(bob, "frogdao");
        vm.warp(P);
        _proposeAsBob(coin, newOwner);
        vm.warp(P + 5 hours);
        vm.prank(creator);
        cto.contest(coin);
        OracleAttestation memory early = _att(cto.confirmQuestion(coin, newOwner, "frogdao"), true);
        early.panelSize = 80;
        early.agreed = 60;
        early.issuedAt = uint64(P); // issued before the contest
        bytes memory earlySig = _sign(early, oracleKey);
        vm.expectRevert(CTOModule.AnswerBeforeContest.selector);
        cto.confirm(coin, early, earlySig);
        assertFalse(cto.pendingOf(coin).confirmed);
    }

    /// @dev Audit R1-A4-5: the council can't hold a coin's takeover slot: a cancel starts a 90-day council cooldown
    ///      for that coin, and an attested proposal replaces a pending council one.
    function test_cto_councilCantSquatTheSlot() public {
        _approveOracle();
        address coin = _coinWithCreatorFees(_noTax());
        _linkX(bob, "frogdao");
        vm.warp(P);
        vm.startPrank(council);
        cto.proposeByCouncil(coin, newOwner, "ipfs://evidence");
        cto.cancel(coin);
        vm.expectRevert(CTOModule.Cooldown.selector);
        cto.proposeByCouncil(coin, newOwner, "ipfs://evidence");
        vm.stopPrank();

        // Another coin: a pending council proposal gives way to an attested one.
        vm.prank(creator);
        (address other,) =
            router.launchWith(_params("TOAD", _noTax(), bytes32(uint256(1))), address(imd), 1e18, false, 0, 0, address(0));
        vm.warp(P + 31 days);
        vm.prank(council);
        cto.proposeByCouncil(other, newOwner, "ipfs://evidence");
        address target = address(new MockSafe());
        OracleAttestation memory a = _att(cto.question(other, target, "frogdao"), true);
        bytes memory sig = _sign(a, oracleKey);
        vm.prank(bob);
        cto.propose(other, target, a, sig);
        CTOModule.Takeover memory t = cto.pendingOf(other);
        assertEq(t.newRecipient, target);
        assertFalse(t.byCouncil);
        // ...but the council can't replace an attested one.
        vm.prank(council);
        vm.expectRevert(CTOModule.Pending.selector);
        cto.proposeByCouncil(other, newOwner, "ipfs://evidence");
    }

    /// @dev Audit R1-A4-9: once the council path is retired, a council proposal made before can't execute.
    function test_cto_retiredCouncilProposalCannotExecute() public {
        address coin = _coinWithCreatorFees(_noTax());
        vm.warp(P);
        vm.prank(council);
        cto.proposeByCouncil(coin, newOwner, "ipfs://evidence");
        _approveOracle();
        vm.prank(slowTimelock);
        cto.retireCouncil();
        vm.warp(P + 7 days);
        vm.expectRevert(CTOModule.NotCouncil.selector);
        cto.execute(coin);
        assertEq(vault.recipientOf(coin), creator);
    }

    /// @dev Audit R1-A4-10: a single-key wallet with an EIP-7702 delegation (23 bytes of code) is not a contract.
    function test_cto_delegatedWalletIsNotAContractRecipient() public {
        address coin = _coinWithCreatorFees(_noTax());
        address delegated = makeAddr("delegated");
        vm.etch(delegated, abi.encodePacked(hex"ef0100", address(newOwner)));
        assertEq(delegated.code.length, 23);
        vm.warp(P);
        vm.prank(council);
        vm.expectRevert(CTOModule.InvalidRecipient.selector);
        cto.proposeByCouncil(coin, delegated, "ipfs://evidence");
    }

    function test_cto_rulesMustBeIpfs() public {
        vm.expectRevert(CTOModule.BadRulesURI.selector);
        new CTOModule(
            slowTimelock, address(vault), address(curve), address(social), address(verifier), council, "https://pondpad.fun/rules"
        );
    }

    /// @dev Audit R2-A4-5: the confirmation question names the time of the contest, so it can't be put to the oracle
    ///      before the contest (and then count once a contest happens); before a contest it doesn't exist.
    function test_cto_confirmQuestionNamesTheContest() public {
        _approveOracle();
        address coin = _coinWithCreatorFees(_noTax());
        _linkX(bob, "frogdao");
        vm.warp(P);
        _proposeAsBob(coin, newOwner);
        vm.expectRevert(CTOModule.NotContested.selector);
        cto.confirmQuestion(coin, newOwner, "frogdao");
        vm.warp(P + 5 hours);
        vm.prank(creator);
        cto.contest(coin);
        string memory q = cto.confirmQuestion(coin, newOwner, "frogdao");
        assertTrue(LibString.contains(q, string.concat("contested by the current fee recipient at unix time ", vm.toString(P + 5 hours))));
        OracleAttestation memory big = _att(q, true);
        big.panelSize = 80;
        big.agreed = 60;
        big.issuedAt = uint64(P + 6 hours);
        vm.warp(P + 6 hours);
        cto.confirm(coin, big, _sign(big, oracleKey));
        assertTrue(cto.pendingOf(coin).confirmed);
    }

    /// @dev Audit R1-A4-12: routing a coin's fees to its holders is final; nobody could contest a later takeover.
    function test_cto_holdersRoutingIsFinal() public {
        _approveOracle();
        address coin = _coinWithCreatorFees(_noTax());
        vm.prank(creator);
        vault.setRecipient(coin, coin);
        _linkX(bob, "frogdao");
        vm.warp(P);
        OracleAttestation memory a = _att(cto.question(coin, newOwner, "frogdao"), true);
        bytes memory sig = _sign(a, oracleKey);
        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("FeesGoToHolders()")));
        cto.propose(coin, newOwner, a, sig);
        vm.prank(council);
        vm.expectRevert(bytes4(keccak256("FeesGoToHolders()")));
        cto.proposeByCouncil(coin, newOwner, "ipfs://evidence");

        // Routing to holders during a takeover's notice also stands: the takeover can't execute.
        vm.prank(creator);
        (address other,) =
            router.launchWith(_params("TOAD", _noTax(), bytes32(uint256(1))), address(imd), 1e18, false, 0, 0, address(0));
        vm.warp(P + 31 days);
        vm.prank(council);
        cto.proposeByCouncil(other, newOwner, "ipfs://evidence");
        vm.prank(creator);
        vault.setRecipient(other, other);
        vm.warp(P + 31 days + 7 days);
        vm.expectRevert(bytes4(keccak256("FeesGoToHolders()")));
        cto.execute(other);
        assertEq(vault.recipientOf(other), other);
    }

    /// @dev Audit R2-A4-6: the recipient must still be the contract that was proposed when the takeover executes: not
    ///      emptied (an EIP-6780 self-destruct in its creation transaction) and not replaced by other code.
    function test_cto_recipientCheckedAgainAtExecute() public {
        address coin = _coinWithCreatorFees(_noTax());
        address c = address(new MockSafe());
        vm.warp(P);
        vm.prank(council);
        cto.proposeByCouncil(coin, c, "ipfs://evidence");
        vm.etch(c, "");
        vm.warp(P + 7 days);
        vm.expectRevert(CTOModule.InvalidRecipient.selector);
        cto.execute(coin);
        vm.etch(c, hex"00");
        vm.expectRevert(CTOModule.InvalidRecipient.selector);
        cto.execute(coin);
        assertEq(vault.recipientOf(coin), creator);
    }

    /// @dev Audit R2-A4-7: a rules link too long for the takeover questions is refused at deploy.
    function test_cto_rulesLinkMustFitTheQuestions() public {
        bytes memory long = new bytes(1_700);
        for (uint256 i; i < long.length; i++) {
            long[i] = "a";
        }
        vm.expectRevert(CTOModule.BadRulesURI.selector);
        new CTOModule(
            slowTimelock, address(vault), address(curve), address(social), address(verifier), council,
            string.concat("ipfs://", string(long))
        );
    }

    /// @dev Audit R2-A4-4: an attestation whose evidence window is inverted is refused.
    function test_verifier_refusesAnInvertedWindow() public {
        _approveOracle();
        string memory q = "Is this a test question?";
        OracleAttestation memory a = _att(q, true);
        a.fromBlock = 300;
        a.toBlock = 200;
        a.questionHash = verifier.questionHash(q, a.chainId, a.fromBlock, a.toBlock);
        bytes memory sig = _sign(a, oracleKey);
        vm.expectRevert(bytes4(keccak256("BadWindow()")));
        verifier.verifyBool(a, sig, q);
    }

    /// @dev Audits R2-A1-1 / R2-A4-2: funding a holder stream from inside an outside PoolManager unlock is refused,
    ///      so it can't move the stream's clock and erase the share holders were owed.
    function test_holderStream_fundingInsideAnUnlockCantStallIt() public {
        address coin = _coinWithCreatorFees(_noTax());
        vm.prank(creator);
        vault.setRecipient(coin, coin);
        vault.claim(coin);
        vm.warp(T0 + 1 hours + 1 days);
        uint256 due = vault.releasableToHolders(coin);
        assertGt(due, 0);
        UnlockCaller g = new UnlockCaller(IPoolManager(address(pm)));
        imd.mint(address(g), 1);
        g.run(address(imd), abi.encodeWithSignature("approve(address,uint256)", address(vault), 1));
        vm.expectRevert(bytes4(keccak256("PoolManagerUnlocked()")));
        g.run(address(vault), abi.encodeWithSignature("fundHolders(address,uint256)", coin, 1));
        assertEq(vault.releasableToHolders(coin), due, "the day's share is still owed");
        assertEq(vault.releaseToHolders(coin), due);
    }

    /// @dev Audits R2-A1-2 / R2-A4-1: a takeover can't be executed from inside an outside PoolManager unlock, where
    ///      the pre-switch hook flush would do nothing and pending creator fees would go to the new recipient.
    function test_cto_executeInsideAnUnlockIsRefused() public {
        _approveOracle();
        address coin = _launch(_noTax(), 0);
        _fillCurve(coin);
        vault.claim(coin);
        _linkX(bob, "frogdao");
        vm.warp(P);
        _proposeAsBob(coin, newOwner);
        vm.warp(P + 3 days);
        PoolKey memory key = hook.poolKey(coin);
        bool imdIs0 = Currency.unwrap(key.currency0) == address(imd);
        PoolSwapTest swapper = new PoolSwapTest(IPoolManager(address(pm)));
        imd.mint(address(this), 100e18);
        imd.approve(address(swapper), type(uint256).max);
        swapper.swap(
            key,
            SwapParams({
                zeroForOne: imdIs0,
                amountSpecified: -100e18,
                sqrtPriceLimitX96: imdIs0 ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
        UnlockCaller g = new UnlockCaller(IPoolManager(address(pm)));
        vm.expectRevert(bytes4(keccak256("PoolManagerUnlocked()")));
        g.run(address(cto), abi.encodeCall(CTOModule.execute, (coin)));
        uint256 before = imd.balanceOf(creator);
        cto.execute(coin);
        assertEq(imd.balanceOf(creator) - before, 0.5e18, "old recipient paid the fees pending in the hook");
    }

    /// @dev Audit R2-A4-3: 1-wei top-ups can't stretch a holder lump: it still pays out in about 7 days.
    function test_holderStream_dustTopUpsCantStretchIt() public {
        address coin = _coinWithCreatorFees(_noTax());
        vm.prank(creator);
        vault.setRecipient(coin, coin);
        imd.mint(address(this), 701e18);
        imd.approve(address(vault), type(uint256).max);
        vault.fundHolders(coin, 700e18);
        for (uint256 d = 1; d <= 7; d++) {
            vm.warp(T0 + 1 hours + d * 1 days);
            vault.releaseToHolders(coin);
            vault.fundHolders(coin, 1); // a stranger's top-up
        }
        (uint128 remaining,,) = vault.holderStreamOf(coin);
        assertLe(remaining, 7, "the lump paid out in ~7 days");
    }

    // ------------------------------------------------------------------ VersionRegistry

    /// @dev Audit R1-A4-6: activating an older, never-activated version doesn't roll new launches back to it.
    function test_versions_olderActivationDoesNotRollBack() public {
        for (uint256 i; i < 3; i++) {
            versions.register(address(factory), address(router), address(curve), address(hook), address(lens));
        }
        versions.activateManually(3, "https://api.imd.fun/jobs/audit-3/report.md");
        assertEq(versions.currentVersion(), 3);
        _approveOracle();
        string memory job = "6f1d2c3a-1111-4222-8333-944455556666";
        OracleAttestation memory a = _att(versions.question(2, job), true);
        bytes memory sig = _sign(a, oracleKey);
        vm.prank(bob);
        versions.activate(2, job, a, sig);
        assertGt(versions.versionInfo(2).activatedAt, 0, "marked activated");
        assertEq(versions.currentVersion(), 3, "still the newest");
        versions.setCurrent(2); // the owner can still roll back
        assertEq(versions.currentVersion(), 2);
    }

    function test_versions_registerActivateAndRollback() public {
        vm.prank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        versions.register(address(factory), address(router), address(curve), address(hook), address(lens));

        uint256 v1 = versions.register(address(factory), address(router), address(curve), address(hook), address(lens));
        assertEq(v1, 1);
        assertEq(
            versions.versionInfo(1).codeHash,
            keccak256(
                abi.encode(
                    address(factory).codehash,
                    address(router).codehash,
                    address(curve).codehash,
                    address(hook).codehash,
                    address(lens).codehash
                )
            )
        );
        vm.expectRevert(VersionRegistry.UnknownVersion.selector); // nothing active yet
        versions.current();

        // Fallback: manual activation with the audit link.
        versions.activateManually(1, "https://api.imd.fun/jobs/audit-1/report.md");
        assertEq(versions.currentVersion(), 1);
        vm.expectRevert(VersionRegistry.AlreadyActive.selector);
        versions.activateManually(1, "again");

        // Version 2 (same contracts here, for the test) activated by an oracle "yes".
        versions.register(address(factory), address(router), address(curve), address(hook), address(lens));
        _approveOracle();
        string memory job = "6f1d2c3a-1111-4222-8333-944455556666";
        OracleAttestation memory a = _att(versions.question(2, job), true);
        bytes memory sig = _sign(a, oracleKey);
        vm.expectRevert(AttestationVerifier.WrongQuestion.selector); // wrong job id
        versions.activate(2, "6f1d2c3a-0000-4222-8333-944455556666", a, sig);
        vm.expectRevert(VersionRegistry.BadAuditJob.selector);
        versions.activate(2, "job 1", a, sig);
        vm.prank(bob);
        versions.activate(2, job, a, sig);
        assertEq(versions.currentVersion(), 2);
        assertEq(versions.current().auditRef, job);

        // Rollback to an activated version only.
        versions.setCurrent(1);
        assertEq(versions.currentVersion(), 1);
        versions.register(address(factory), address(router), address(curve), address(hook), address(lens));
        vm.expectRevert(VersionRegistry.NotActivated.selector);
        versions.setCurrent(3);

        versions.retireManualActivation();
        vm.expectRevert(VersionRegistry.Retired.selector);
        versions.activateManually(3, "link");
        assertEq(versions.count(), 3);
    }

    // ------------------------------------------------------------------ SocialRegistry

    function _voucher(address coin, bytes32 handle, address account, uint256 nonce, uint256 deadline)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                social.domainSeparator(),
                keccak256(abi.encode(social.LINK_TYPEHASH(), coin, handle, account, nonce, deadline))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(linkKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function test_social_linkUnlinkAndDuplicates() public {
        address coin = _launch(_noTax(), 0);
        address coin2 = _launchOrdered(_noTax(), address(imd) > coin);
        bytes32 handle = keccak256("pondpadfun");
        uint256 deadline = T0 + 1 days;

        bytes memory sig = _voucher(coin, handle, creator, 0, deadline);
        vm.prank(alice); // only the fee recipient
        vm.expectRevert(Ownable.Unauthorized.selector);
        social.link(coin, handle, deadline, sig);
        vm.prank(creator);
        social.link(coin, handle, deadline, sig);
        (bytes32 h, bool dup) = social.badgeOf(coin);
        assertEq(h, handle);
        assertFalse(dup);

        vm.prank(creator); // the nonce moved on, so the voucher can't be reused
        vm.expectRevert(SocialRegistry.BadVoucher.selector);
        social.link(coin, handle, deadline, sig);

        // The same handle on a second coin is allowed but flagged on both.
        bytes memory sig2 = _voucher(coin2, handle, creator, 0, deadline);
        vm.prank(creator);
        social.link(coin2, handle, deadline, sig2);
        (, dup) = social.badgeOf(coin);
        assertTrue(dup);

        vm.prank(linker); // the verifier revokes the second link
        social.unlink(coin2);
        (, dup) = social.badgeOf(coin);
        assertFalse(dup);

        // Wallet X links (used by CTO proposers): handle checked, nonce per wallet, unlink by the wallet.
        _linkX(bob, "Frog_DAO");
        assertEq(social.walletHandle(bob), "Frog_DAO");
        vm.prank(bob);
        vm.expectRevert(SocialRegistry.BadHandle.selector);
        social.linkWallet("frog dao", T0 + 1, "");
        vm.prank(bob);
        social.unlinkWallet(bob);
        assertEq(bytes(social.walletHandle(bob)).length, 0);

        bytes memory late = _voucher(coin2, handle, creator, 1, deadline);
        vm.warp(deadline + 1);
        vm.prank(creator);
        vm.expectRevert(SocialRegistry.Expired.selector);
        social.link(coin2, handle, deadline, late);
    }

    // ------------------------------------------------------------------ PadLens

    function test_lens_listsAndCurveQuotesMatchTrades() public {
        address a = _launch(_noTax(), 0);
        address b = _launchOrdered(_holderTax(100), address(imd) > a);
        assertEq(lens.coinCount(), 2);
        PadLens.CoinView[] memory list = lens.coins(0, 10, true);
        assertEq(list.length, 2);
        assertEq(list[0].coin, b);
        assertEq(list[1].coin, a);
        assertEq(lens.coins(1, 10, false)[0].coin, b);
        assertEq(lens.coins(2, 10, false).length, 0);

        PadLens.CoinView memory v = lens.coinView(b);
        assertEq(v.symbol, "FROG");
        assertEq(v.totalFeeBps, 250);
        assertEq(v.feeRecipient, creator);
        assertEq(v.target, TARGET);
        assertGt(v.snipeTaxBps, 0);

        vm.warp(T0 + 1 hours);
        (uint256 out, uint256 fee,, bool graduated, bool full) = lens.quoteBuy(b, 50e18);
        assertFalse(graduated);
        assertTrue(full);
        assertEq(fee, 50e18 * 250 / 10_000);
        assertEq(_buy(alice, b, 50e18), out);
        (uint256 imdOut,,,) = lens.quoteSell(b, out / 2);
        assertEq(_sell(alice, b, out / 2), imdOut);

        address[] memory l = new address[](2);
        l[0] = a;
        l[1] = b;
        PadLens.Position[] memory p = lens.positions(alice, l);
        assertEq(p[1].balance, out - out / 2);
        assertEq(p[0].balance, 0);
    }

    function test_lens_poolQuotesMatchTrades() public {
        address coin = _launch(_holderTax(50), 0);
        _fillCurve(coin);
        PadLens.CoinView memory v = lens.coinView(coin);
        assertEq(uint8(v.status), uint8(BondingCurve.Status.Graduated));
        assertGt(v.poolLiquidity, 0);
        // Spot price matches the curve's final price E/R within rounding.
        assertApproxEqRel(v.priceE18, TARGET * 1e18 / 200_000_000e18, 1e15);

        (uint256 out, uint256 fee,, bool graduated, bool full) = lens.quoteBuy(coin, 20e18);
        assertTrue(graduated && full);
        assertEq(fee, 20e18 * 200 / 10_000);
        assertEq(_buy(alice, coin, 20e18), out);

        (uint256 imdOut,,, bool fullSell) = lens.quoteSell(coin, out / 3);
        assertTrue(fullSell);
        assertEq(_sell(alice, coin, out / 3), imdOut);

        address[] memory l = new address[](1);
        l[0] = coin;
        assertEq(lens.positions(alice, l)[0].pendingDividends, PadToken(coin).withdrawableDividendOf(alice));
    }
}
