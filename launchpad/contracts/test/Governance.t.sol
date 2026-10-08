// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Base} from "./Base.t.sol";
import {BondingCurve} from "../src/BondingCurve.sol";
import {AttestationVerifier, OracleAttestation} from "../src/AttestationVerifier.sol";
import {VersionRegistry} from "../src/VersionRegistry.sol";
import {SocialRegistry} from "../src/SocialRegistry.sol";
import {CreatorVault} from "../src/CreatorVault.sol";
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
import {ECDSA} from "solady/utils/ECDSA.sol";
import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {FixedOwnable} from "../src/FixedOwnable.sol";
import {PondPadTimelock} from "../src/PondPadTimelock.sol";
import {PadRouter} from "../src/PadRouter.sol";
import {LaunchParams} from "../src/PadFactory.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

/// @dev Stands in for a multisig a creator hands its fees to.
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

/// @dev A contract X link service key (ERC-1271), signing with an ordinary key behind it.
contract Mock1271Verifier {
    address internal immutable signer;

    constructor(address signer_) {
        signer = signer_;
    }

    function isValidSignature(bytes32 hash, bytes calldata sig) external view returns (bytes4) {
        return ECDSA.recoverCalldata(hash, sig) == signer ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
}

contract GovernanceTest is Base {
    uint256 internal constant T0 = 1_000_000;

    AttestationVerifier internal verifier;
    VersionRegistry internal versions;
    SocialRegistry internal social;
    PadLens internal lens;

    address internal slowTimelock = makeAddr("slowTimelock");
    address internal newOwner; // a multisig the creator hands its fees to
    uint256 internal oracleKey = 0xA11CE;
    address internal oracle;
    uint256 internal linkKey = 0xB0B;
    address internal linker;
    uint256 internal _req;

    function setUp() public override {
        super.setUp();
        vm.warp(T0);
        oracle = vm.addr(oracleKey);
        linker = vm.addr(linkKey);
        verifier = new AttestationVerifier(slowTimelock);
        social = new SocialRegistry(address(this), address(vault), linker);
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
        verifier.setThresholds(4, 2, 3);
        vm.expectRevert(AttestationVerifier.InvalidSetting.selector);
        verifier.setThresholds(101, 2, 3);
        vm.expectRevert(AttestationVerifier.InvalidSetting.selector);
        verifier.setThresholds(51, 1, 2); // half is not more than half
        vm.expectRevert(AttestationVerifier.InvalidSetting.selector);
        verifier.setThresholds(51, 4, 3); // more than all
        vm.expectRevert(AttestationVerifier.InvalidSetting.selector);
        verifier.setThresholds(51, 0, 0);
        verifier.setThresholds(75, 3, 4);
        verifier.setSigner(oracle, false);
        vm.stopPrank();
        assertEq(verifier.minPanelSize(), 75);
        assertEq(verifier.signerCount(), 0);
    }

    // ------------------------------------------------------------------ Creator fees to holders (D-52, D-82)

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

    /// @dev The fee recipient routes the coin's fees to its holders (recipient = the coin itself, D-52): new creator
    ///      fees and the swarm budget then reach holders as IMD dividends, paid second by second over about 7 days
    ///      (D-78, D-80), and nobody can change the recipient again. Before D-82 this ran through a takeover.
    function test_holders_creatorRoutesFeesToHolders() public {
        // 1% coin tax, all to the swarm budget, so the coin also has a budget to hand over.
        address coin = _coinWithCreatorFees(CoinFees(100, 0, 0, 10_000));
        assertGt(budget.available(coin), 0);
        vm.expectRevert(Ownable.Unauthorized.selector); // only once fees are routed to holders
        budget.sweepToHolders(coin);

        vm.warp(T0 + 2 days);
        vm.prank(creator);
        vault.setRecipient(coin, coin); // the coin itself = its holders
        assertEq(vault.recipientOf(coin), coin);

        _buy(bob, coin, 100e18);
        uint256 creatorFees = vault.balanceOf(coin); // fees accrued before the switch go to holders too
        uint256 swarm = budget.available(coin);
        uint256 aliceBefore = PadToken(coin).withdrawableDividendOf(alice);
        vault.claim(coin); // anyone
        budget.sweepToHolders(coin); // anyone
        assertEq(budget.available(coin), 0);
        assertEq(PadToken(coin).withdrawableDividendOf(alice), aliceBefore, "nothing in one go");
        (uint256 remaining, uint256 endsAt,) = PadToken(coin).holderStream();
        assertEq(remaining, creatorFees + swarm);
        assertEq(endsAt, T0 + 2 days + 7 days);
        vm.warp(T0 + 3 days);
        (,, uint256 due) = PadToken(coin).holderStream();
        assertApproxEqAbs(due, (creatorFees + swarm) / 7, 1, "a seventh a day");
        vm.warp(T0 + 9 days);
        (,, due) = PadToken(coin).holderStream();
        assertEq(due, creatorFees + swarm, "all paid in 7 days");
        uint256 gained = PadToken(coin).withdrawableDividendOf(alice) - aliceBefore
            + PadToken(coin).withdrawableDividendOf(bob);
        assertApproxEqAbs(gained, creatorFees + swarm, 1e6);
        vm.prank(creator);
        vm.expectRevert(CreatorVault.Unauthorized.selector); // nobody holds the recipient role any more
        vault.setRecipient(coin, creator);
    }

    /// @dev D-82 (and audit R1-A4-12): only a coin's fee recipient changes its recipient, and routing the fees to the
    ///      coin's holders is final, since the coin never calls `setRecipient`. The vault has no other way to change a
    ///      recipient: the takeover entry point is gone and `initialize` takes the curve and the hook only, once.
    function test_holders_routingIsFinal() public {
        address coin = _coinWithCreatorFees(_noTax());
        vm.prank(alice); // not the recipient
        vm.expectRevert(CreatorVault.Unauthorized.selector);
        vault.setRecipient(coin, alice);
        vm.prank(creator);
        vault.setRecipient(coin, coin);
        vm.prank(creator);
        vm.expectRevert(CreatorVault.Unauthorized.selector);
        vault.setRecipient(coin, creator);
        (bool ok,) = address(vault).call(abi.encodeWithSignature("ctoSetRecipient(address,address)", coin, alice));
        assertFalse(ok, "no takeover entry point");
        (ok,) = address(vault).call(abi.encodeWithSignature("ctoModule()"));
        assertFalse(ok, "no takeover module");
        vm.expectRevert(CreatorVault.AlreadyInitialized.selector);
        vault.initialize(address(curve), address(hook));
        assertEq(vault.recipientOf(coin), coin);
    }

    /// @dev Audit R1-A4-1: a wallet with no position can't buy, release a holder lump (creator fees and swarm
    ///      budget of a coin whose fees go to holders), claim its dividend and sell back in one block for a profit.
    function test_holders_lumpCantBeCapturedInOneBlock() public {
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

    /// @dev Audits R2-A1-1 / R2-A4-2: funding a holder stream from inside an outside PoolManager unlock can't stall it:
    ///      the stream settles by time on every balance change and funding (D-80), so what holders were owed stays owed.
    function test_holderStream_fundingInsideAnUnlockCantStallIt() public {
        address coin = _coinWithCreatorFees(_noTax());
        vm.prank(creator);
        vault.setRecipient(coin, coin);
        vault.claim(coin);
        vm.warp(T0 + 1 hours + 1 days);
        uint256 owed = PadToken(coin).withdrawableDividendOf(alice);
        assertGt(owed, 0);
        UnlockCaller g = new UnlockCaller(IPoolManager(address(pm)));
        imd.mint(address(g), 1);
        g.run(address(imd), abi.encodeWithSignature("approve(address,uint256)", address(vault), 1));
        g.run(address(vault), abi.encodeWithSignature("fundHolders(address,uint256)", coin, 1));
        assertEq(PadToken(coin).withdrawableDividendOf(alice), owed, "the day's share is still owed");
        vm.prank(alice);
        assertEq(PadToken(coin).claim(), owed);
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
            vault.fundHolders(coin, 1); // a stranger's top-up
        }
        (uint256 remaining,,) = PadToken(coin).holderStream();
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

        // Wallet X links (shown on profiles): handle checked, nonce per wallet, unlink by the wallet.
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

    // ------------------------------------------------------------------ Audit round 3

    /// @dev The round-3 vault's `releaseToHolders` (removed in D-80), called if it exists, as an attacker would.
    function _tryRelease(address coin) internal {
        (bool ok,) = address(vault).call(abi.encodeWithSignature("releaseToHolders(address)", coin));
        if (!ok) return;
    }

    /// @dev Audit R3-A4-1: a wallet with no position can't take a holder-routed lump's daily share in one transaction
    ///      (buy, release, claim, sell), on any day of the stream: the stream pays holders by the time they held.
    function test_holderStream_oneTransactionCaptureEarnsNothing() public {
        address coin = _coinWithCreatorFees(CoinFees(300, 5_000, 0, 5_000));
        imd.mint(address(vault), 2_000e18);
        vm.prank(address(curve));
        vault.credit(coin, 2_000e18);
        imd.mint(address(budget), 1_500e18);
        vm.prank(address(curve));
        budget.credit(coin, 1_500e18);
        vm.prank(creator);
        vault.setRecipient(coin, coin);
        vault.claim(coin);
        budget.sweepToHolders(coin);

        address carol = makeAddr("carol");
        vm.prank(carol);
        imd.approve(address(router), type(uint256).max);
        for (uint256 d = 1; d <= 7; d++) {
            vm.warp(T0 + 1 hours + d * 1 days);
            imd.mint(carol, 1_000e18);
            uint256 got = _buy(carol, coin, 1_000e18);
            _tryRelease(coin);
            vm.prank(carol);
            PadToken(coin).claim();
            _sell(carol, coin, got);
        }
        assertLe(imd.balanceOf(carol), 7_000e18, "a one-transaction position earns nothing from the stream");
        assertGt(PadToken(coin).withdrawableDividendOf(alice), 3_000e18, "the holder who held all week gets it");
    }

    /// @dev Audit R3-A4-2: while nobody holds the coin, the stream waits; the first buyer afterwards isn't paid the
    ///      time nobody held.
    function test_holderStream_timeWithNobodyEligibleIsNotBanked() public {
        address coin = _launch(_noTax(), 0);
        vm.warp(T0 + 1 hours);
        _sell(alice, coin, _buy(alice, coin, 100e18)); // nobody holds the coin any more
        assertLt(PadToken(coin).eligibleSupply(), 1e18);
        vm.prank(creator);
        vault.setRecipient(coin, coin);
        imd.mint(address(this), 700e18);
        imd.approve(address(vault), 700e18);
        vault.fundHolders(coin, 700e18);

        vm.warp(T0 + 1 hours + 30 days);
        address carol = makeAddr("carol");
        imd.mint(carol, 1e18);
        vm.prank(carol);
        imd.approve(address(router), type(uint256).max);
        uint256 got = _buy(carol, coin, 0.001e18);
        _tryRelease(coin);
        vm.prank(carol);
        PadToken(coin).claim();
        _sell(carol, coin, got);
        assertLe(imd.balanceOf(carol), 1e18, "the time nobody held isn't paid to the next buyer");
    }

    /// @dev Audits R3-A1-2 / R3-A4-3: a lump that joins a nearly finished stream still pays out over about a week, not
    ///      at the earlier lump's pace.
    function test_holderStream_laterLumpGetsItsOwnWeek() public {
        address coin = _coinWithCreatorFees(_noTax()); // alice is the only holder
        vm.prank(creator);
        vault.setRecipient(coin, coin);
        imd.mint(address(this), 7_900e18);
        imd.approve(address(vault), 7_900e18);
        uint256 s0 = T0 + 1 hours;
        vault.fundHolders(coin, 7_000e18);
        for (uint256 d = 1; d <= 6; d++) {
            vm.warp(s0 + d * 1 days);
            _tryRelease(coin);
        }
        vm.warp(s0 + 6 days + 23 hours); // the first lump is nearly paid
        vault.fundHolders(coin, 900e18);
        vm.warp(s0 + 7 days + 23 hours); // a day later
        _tryRelease(coin);
        uint256 paid = PadToken(coin).withdrawableDividendOf(alice);
        assertGt(paid, 6_900e18);
        assertLt(paid, 7_000e18 + 900e18 / 2, "the new lump pays out over about a week, not in a day");
    }

    /// @dev Audit R3-A1-1: a buyer that is the only eligible holder isn't credited its own holder tax, on the curve or
    ///      in the pool through PadRouter; it goes to the growth fund.
    function test_holderTax_soleHolderGetsNoOwnTaxBack() public {
        vm.prank(creator); // a 1 IMD dev buy, whose tax goes to growth (R2-A1-3)
        (address coin,) =
            router.launchWith(_params("TOAD", _holderTax(300), bytes32(0)), address(imd), 2e18, true, 0, 0, address(0));
        vm.warp(T0 + 1 hours);
        uint256 growthBefore = imd.balanceOf(growth);
        _buy(creator, coin, 1_000e18); // the creator is still the only holder
        assertEq(PadToken(coin).withdrawableDividendOf(creator), 0, "no own tax back on the curve");
        assertEq(imd.balanceOf(growth) - growthBefore, 30e18);

        address coin2 = _launchOrdered(_holderTax(200), true);
        _fillCurve(coin2);
        for (uint256 i; i < 10; i++) {
            address buyer = address(uint160(0x10000 + i));
            uint256 bal = PadToken(coin2).balanceOf(buyer);
            if (bal != 0) _sell(buyer, coin2, bal);
        }
        assertLt(PadToken(coin2).eligibleSupply(), 1e18);
        growthBefore = imd.balanceOf(growth);
        _buy(alice, coin2, 100e18);
        _buy(alice, coin2, 100e18);
        assertEq(PadToken(coin2).withdrawableDividendOf(alice), 0, "no own tax back in the pool");
        assertApproxEqAbs(imd.balanceOf(growth) - growthBefore, 4e18, 10); // the 2% holder tax of both buys
    }

    /// @dev Audit R3-A1-3: pool quotes match the trade to the wei when the price crosses a tick-bitmap word, in both
    ///      currency orderings.
    function test_lens_poolQuotesExactAcrossBitmapWords() public {
        for (uint256 k; k < 2; k++) {
            address coin = _launchOrdered(_holderTax(200), k == 0);
            _fillCurve(coin);
            (uint256 out,,,, bool full) = lens.quoteBuy(coin, 3_000e18);
            assertTrue(full);
            assertEq(_buy(alice, coin, 3_000e18), out, "buy quote");
            (uint256 imdOut,,, bool fullSell) = lens.quoteSell(coin, out);
            assertTrue(fullSell);
            assertEq(_sell(alice, coin, out), imdOut, "sell quote");
        }
    }

    function _walletVoucher(address who, string memory handle, uint256 nonce, uint256 deadline)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                social.domainSeparator(),
                keccak256(
                    abi.encode(social.WALLET_LINK_TYPEHASH(), who, keccak256(bytes(vm.toLowercase(handle))), nonce, deadline)
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s_) = vm.sign(linkKey, digest);
        return abi.encodePacked(r, s_, v);
    }

    /// @dev Audit R3-A4-5: revoking a link voids every voucher signed before it, for wallets and for coins.
    function test_social_revocationVoidsEarlierVouchers() public {
        uint256 deadline = T0 + 1 days;
        bytes memory v0 = _walletVoucher(bob, "frogdao", 0, deadline);
        bytes memory v1 = _walletVoucher(bob, "frogdao", 1, deadline); // a second voucher bob kept back
        vm.prank(bob);
        social.linkWallet("frogdao", deadline, v0);
        vm.prank(linker);
        social.unlinkWallet(bob); // the X link service revokes it
        vm.prank(bob);
        vm.expectRevert(SocialRegistry.BadVoucher.selector);
        social.linkWallet("frogdao", deadline, v1);
        assertEq(bytes(social.walletHandle(bob)).length, 0);

        address coin = _launch(_noTax(), 0);
        bytes32 h = keccak256("frogcoin");
        bytes memory c0 = _voucher(coin, h, creator, 0, deadline);
        bytes memory c1 = _voucher(coin, h, creator, 1, deadline);
        vm.prank(creator);
        social.link(coin, h, deadline, c0);
        social.unlink(coin); // the owner revokes it
        vm.prank(creator);
        vm.expectRevert(SocialRegistry.BadVoucher.selector);
        social.link(coin, h, deadline, c1);
        (bytes32 badge,) = social.badgeOf(coin);
        assertEq(badge, bytes32(0));
    }

    /// @dev Audit R3-A4-9: a coin's X badge belongs to the fee recipient that linked it; after the recipient changes
    ///      the old account is no longer shown, anyone can clear it, and the new recipient links its own.
    function test_social_badgeEndsWhenTheRecipientChanges() public {
        address coin = _launch(_noTax(), 0);
        bytes32 h = keccak256("ruggedcreator");
        uint256 deadline = T0 + 1 days;
        bytes memory v0 = _voucher(coin, h, creator, 0, deadline);
        vm.prank(creator);
        social.link(coin, h, deadline, v0);
        (bytes32 badge,) = social.badgeOf(coin);
        assertEq(badge, h);
        vm.prank(creator);
        vault.setRecipient(coin, newOwner); // the creator hands its fees to a multisig
        (badge,) = social.badgeOf(coin);
        assertEq(badge, bytes32(0), "the old recipient's X account is no longer the coin's badge");
        assertEq(social.handleOf(coin), bytes32(0));
        vm.prank(alice); // anyone can clear the stale link
        social.unlink(coin);
        bytes32 h2 = keccak256("frogdao");
        bytes memory v1 = _voucher(coin, h2, newOwner, social.nonces(coin), deadline);
        vm.prank(newOwner);
        social.link(coin, h2, deadline, v1);
        (badge,) = social.badgeOf(coin);
        assertEq(badge, h2);
    }

    /// @dev Audit R3-A4-6: after the owner rolls back, an attested activation of a version between the rolled-back
    ///      pointer and the newest activated one doesn't move `currentVersion`.
    function test_versions_activationAfterRollbackDoesNotMoveCurrent() public {
        for (uint256 i; i < 3; i++) {
            versions.register(address(factory), address(router), address(curve), address(hook), address(lens));
        }
        versions.activateManually(1, "https://api.imd.fun/jobs/audit-1/report.md");
        versions.activateManually(3, "https://api.imd.fun/jobs/audit-3/report.md");
        assertEq(versions.currentVersion(), 3);
        versions.setCurrent(1); // the owner rolls back
        _approveOracle();
        string memory job = "6f1d2c3a-1111-4222-8333-944455556666";
        OracleAttestation memory a = _att(versions.question(2, job), true);
        bytes memory sig = _sign(a, oracleKey);
        vm.prank(bob);
        versions.activate(2, job, a, sig);
        assertGt(versions.versionInfo(2).activatedAt, 0);
        assertEq(versions.currentVersion(), 1, "only the owner chooses among older versions");
    }

    /// @dev Audit R3-A4-11: one member short of two thirds is refused whatever the panel size.
    function test_verifier_lessThanTwoThirdsRefusedOnAnyPanel() public {
        _approveOracle();
        string memory q = "Is this a test question?";
        OracleAttestation memory a = _att(q, true);
        a.panelSize = 5_003;
        a.quorum = 0;
        a.agreed = 3_335; // 66.66%
        bytes memory sig = _sign(a, oracleKey);
        vm.expectRevert(AttestationVerifier.NotEnoughAgreement.selector);
        verifier.verifyBool(a, sig, q);
        a.agreed = 3_336;
        sig = _sign(a, oracleKey);
        assertTrue(verifier.verifyBool(a, sig, q));
    }

    /// @dev Audits R3-A2-2 / R3-A4-4: owners can't hand over, transfer or renounce their powers. Contracts built with
    ///      their timelock as owner never change owner; those the deployer builds are handed over once.
    function test_governance_ownersAreFixed() public {
        address undelayed = makeAddr("undelayed");
        vm.startPrank(slowTimelock);
        vm.expectRevert(FixedOwnable.OwnerIsFixed.selector);
        verifier.transferOwnership(undelayed);
        vm.expectRevert(FixedOwnable.OwnerIsFixed.selector);
        verifier.renounceOwnership();
        vm.stopPrank();
        vm.prank(undelayed);
        vm.expectRevert(FixedOwnable.OwnerIsFixed.selector);
        verifier.requestOwnershipHandover();
        address[4] memory built = [address(versions), address(social), address(config), address(budget)];
        for (uint256 i; i < built.length; i++) {
            Ownable(built[i]).transferOwnership(slowTimelock); // the deployment's one handoff
            vm.prank(slowTimelock);
            vm.expectRevert(FixedOwnable.OwnerIsFixed.selector);
            Ownable(built[i]).transferOwnership(undelayed);
            vm.prank(slowTimelock);
            vm.expectRevert(FixedOwnable.OwnerIsFixed.selector);
            Ownable(built[i]).renounceOwnership();
            assertEq(Ownable(built[i]).owner(), slowTimelock);
        }
    }

    /// @dev Audit R3-A4-4: a timelock's delay can't be lowered below the one it was deployed with, even by its own
    ///      delayed operation; it can be raised and lowered back to that.
    function test_timelock_delayNeverBelowDeployValue() public {
        address safe = makeAddr("safe");
        address[] memory proposers = new address[](1);
        proposers[0] = safe;
        address[] memory executors = new address[](1); // anyone executes
        TimelockController tl = new PondPadTimelock(2 days, proposers, executors, address(0));
        bytes memory toZero = abi.encodeCall(TimelockController.updateDelay, (0));
        vm.prank(safe);
        tl.schedule(address(tl), 0, toZero, bytes32(0), bytes32(0), 2 days);
        vm.warp(T0 + 2 days);
        vm.expectRevert(abi.encodeWithSelector(PondPadTimelock.DelayBelowMinimum.selector, 0, 2 days));
        tl.execute(address(tl), 0, toZero, bytes32(0), bytes32(0));
        assertEq(tl.getMinDelay(), 2 days);

        bytes memory longer = abi.encodeCall(TimelockController.updateDelay, (3 days));
        vm.prank(safe);
        tl.schedule(address(tl), 0, longer, bytes32(0), bytes32(uint256(1)), 2 days);
        vm.warp(T0 + 4 days);
        tl.execute(address(tl), 0, longer, bytes32(0), bytes32(uint256(1)));
        assertEq(tl.getMinDelay(), 3 days);
        bytes memory back = abi.encodeCall(TimelockController.updateDelay, (2 days));
        vm.prank(safe);
        vm.expectRevert(); // scheduling now needs the longer delay
        tl.schedule(address(tl), 0, back, bytes32(0), bytes32(uint256(2)), 2 days);
        vm.prank(safe);
        tl.schedule(address(tl), 0, back, bytes32(0), bytes32(uint256(2)), 3 days);
        vm.warp(T0 + 7 days);
        tl.execute(address(tl), 0, back, bytes32(0), bytes32(uint256(2)));
        assertEq(tl.getMinDelay(), 2 days);
        vm.expectRevert(abi.encodeWithSelector(TimelockController.TimelockUnauthorizedCaller.selector, address(this)));
        tl.updateDelay(2 days);
    }

    /// @dev Audit R3-A4-16 (coverage): the X link service key can be a contract wallet (ERC-1271).
    function test_social_contractVerifierSignsVouchers() public {
        Mock1271Verifier v = new Mock1271Verifier(linker);
        social.setVerifier(address(v));
        address coin = _launch(_noTax(), 0);
        bytes32 h = keccak256("frogcoin");
        uint256 deadline = T0 + 1 days;
        bytes memory v0 = _voucher(coin, h, creator, 0, deadline);
        vm.prank(creator);
        social.link(coin, h, deadline, v0);
        (bytes32 badge,) = social.badgeOf(coin);
        assertEq(badge, h);
        _linkX(bob, "frogdao");
        assertEq(social.walletHandle(bob), "frogdao");
    }

    // ------------------------------------------------------------------ Audit round 4

    /// @dev Swaps `amountIn` exact-in through v4's PoolSwapTest (an outside router), as the test contract.
    function _outsideSwap(PoolSwapTest swapper, PoolKey memory key, bool imdIn, uint256 amountIn) internal {
        bool imdIs0 = Currency.unwrap(key.currency0) == address(imd);
        bool zeroForOne = imdIn == imdIs0;
        swapper.swap(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
    }

    /// @dev Audit R4-A1-1: when the only holder trades through PadRouter, the holder tax other traders paid through an
    ///      outside router since the last flush goes to the holders, as `flush` sends it; only the trade's own holder
    ///      tax goes to the growth fund (R3-A1-1).
    function test_holderTax_soleHolderRouterTradeKeepsOthersTax() public {
        address coin = _launchOrdered(_holderTax(200), true);
        _fillCurve(coin);
        for (uint256 i; i < 10; i++) {
            address buyer = address(uint160(0x10000 + i));
            uint256 bal = PadToken(coin).balanceOf(buyer);
            if (bal != 0) _sell(buyer, coin, bal);
        }
        _buy(alice, coin, 100e18); // alice is now the only eligible holder

        // Another trader buys and sells back through an outside router, holding nothing at the end.
        PoolKey memory key = hook.poolKey(coin);
        PoolSwapTest swapper = new PoolSwapTest(IPoolManager(address(pm)));
        imd.mint(address(this), 300e18);
        imd.approve(address(swapper), type(uint256).max);
        PadToken(coin).approve(address(swapper), type(uint256).max);
        _outsideSwap(swapper, key, true, 300e18);
        _outsideSwap(swapper, key, false, PadToken(coin).balanceOf(address(this)));
        assertEq(PadToken(coin).balanceOf(address(this)), 0);
        (,, uint128 others,) = hook.pending(coin);
        assertGt(others, 0);

        uint256 growthBefore = imd.balanceOf(growth);
        uint256 dividendBefore = PadToken(coin).withdrawableDividendOf(alice);
        _buy(alice, coin, 100e18);
        assertApproxEqAbs(
            PadToken(coin).withdrawableDividendOf(alice) - dividendBefore, others, 1e6, "the others' tax goes to holders"
        );
        assertApproxEqAbs(imd.balanceOf(growth) - growthBefore, 2e18, 10, "only the trade's own tax goes to growth");
    }

    /// @dev Audit R4-A1-2: a curve sell paid out in ETH (or USDG) names the seller in `CurveTrade`, not the router.
    function test_curve_sellEventNamesTheSeller() public {
        address coin = _launch(_noTax(), 0);
        vm.warp(T0 + 1 hours);
        uint256 got = _buy(alice, coin, 10e18);
        vm.startPrank(alice);
        PadToken(coin).approve(address(router), got);
        vm.recordLogs();
        router.sellFor(coin, address(0), got, 0, T0 + 1 hours, address(0));
        vm.stopPrank();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 topic = keccak256("CurveTrade(address,address,bool,uint256,uint256,uint256,uint256,uint256)");
        uint256 seen;
        for (uint256 i; i < logs.length; i++) {
            if (logs[i].emitter == address(curve) && logs[i].topics[0] == topic) {
                assertEq(address(uint160(uint256(logs[i].topics[2]))), alice, "the seller");
                seen++;
            }
        }
        assertEq(seen, 1);
    }

    /// @dev Audit R4-A1-3: coin tokens sent to the coin's own address earn no dividends (nobody could ever claim them);
    ///      the holder tax goes to the real holders.
    function test_holderTax_coinsOwnAddressEarnsNothing() public {
        address coin = _launch(_holderTax(300), 0);
        vm.warp(T0 + 1 hours);
        uint256 got = _buy(alice, coin, 100e18);
        vm.prank(alice);
        PadToken(coin).transfer(coin, got / 2);
        assertTrue(PadToken(coin).isExcluded(coin));
        _buy(bob, coin, 100e18); // 3 IMD holder tax
        assertEq(PadToken(coin).withdrawableDividendOf(coin), 0, "the coin's own address earns nothing");
        assertApproxEqAbs(PadToken(coin).withdrawableDividendOf(alice), 3e18, 1e6, "all to the real holder");
    }

    /// @dev Audit R4-A4-6: after a recipient change, a stranger who clears the stale link doesn't use up the nonce, so
    ///      the voucher the new recipient already holds still works; a revocation by the recipient still voids it.
    function test_social_strangerClearDoesNotVoidTheNewRecipientsVoucher() public {
        address coin = _launch(_noTax(), 0);
        uint256 deadline = T0 + 1 days;
        bytes32 old = keccak256("old");
        bytes memory v0 = _voucher(coin, old, creator, 0, deadline);
        vm.prank(creator);
        social.link(coin, old, deadline, v0);
        vm.prank(creator);
        vault.setRecipient(coin, newOwner);
        bytes32 h = keccak256("new");
        bytes memory v1 = _voucher(coin, h, newOwner, 1, deadline); // signed before anyone clears the stale link
        vm.prank(alice);
        social.unlink(coin); // a stranger clears it
        vm.prank(newOwner);
        social.link(coin, h, deadline, v1);
        (bytes32 badge,) = social.badgeOf(coin);
        assertEq(badge, h);

        bytes memory v2 = _voucher(coin, h, newOwner, 2, deadline);
        vm.prank(newOwner);
        social.unlink(coin); // the recipient's own revocation
        vm.prank(newOwner);
        vm.expectRevert(SocialRegistry.BadVoucher.selector);
        social.link(coin, h, deadline, v2);
    }

    /// @dev Audit R4-A3-8: the X link service key may be an EOA carrying an EIP-7702 delegation (code `0xef0100…`):
    ///      its own-key signature still counts, checked before ERC-1271.
    function test_social_delegatedEoaVerifierSignsVouchers() public {
        vm.etch(linker, abi.encodePacked(hex"ef0100", address(0xdead)));
        _linkX(bob, "frogdao");
        assertEq(social.walletHandle(bob), "frogdao");
        address coin = _launch(_noTax(), 0);
        bytes32 h = keccak256("frogcoin");
        bytes memory v0 = _voucher(coin, h, creator, 0, T0 + 1 days);
        vm.prank(creator);
        social.link(coin, h, T0 + 1 days, v0);
        (bytes32 badge,) = social.badgeOf(coin);
        assertEq(badge, h);
    }

    // ------------------------------------------------------------------ Audit round 5

    /// @dev Audit R5-A1-1: a coin's fee recipient can't be the vault itself, the curve, the hook, the hook's PoolManager
    ///      or another registered coin, at launch or later: anyone's `claim` would hand the fees to a contract that never
    ///      counts them (or to the other coin's holders) before the recipient could correct it, and the coin's swarm
    ///      budget could never be spent, cancelled or swept. Naming the coin itself (fees to holders) stays allowed, at
    ///      launch too; any other address is the recipient's own choice.
    function test_vault_refusesRecipientsThatStrandFees() public {
        address coin = _coinWithCreatorFees(_noTax());
        address other = _launchOrdered(_noTax(), address(imd) > coin);
        address[5] memory sinks = [address(vault), address(curve), address(hook), address(pm), other];
        for (uint256 i; i < sinks.length; i++) {
            vm.prank(creator);
            vm.expectRevert(CreatorVault.InvalidRecipient.selector);
            vault.setRecipient(coin, sinks[i]);
        }
        assertEq(vault.recipientOf(coin), creator);
        vm.prank(creator);
        vault.setRecipient(coin, newOwner);
        uint256 owed = vault.balanceOf(coin);
        vault.claim(coin); // anyone's claim pays the recipient
        assertEq(imd.balanceOf(newOwner), owed);

        for (uint256 i; i < sinks.length; i++) {
            LaunchParams memory p = _params("SINK", _noTax(), bytes32(uint256(100 + i)));
            p.feeRecipient = sinks[i];
            vm.prank(creator);
            vm.expectRevert(CreatorVault.InvalidRecipient.selector);
            router.launchWith(p, address(imd), 1e18, false, 0, 0, address(0));
        }
        LaunchParams memory own = _params("OWN", _noTax(), bytes32(uint256(200)));
        own.feeRecipient = factory.predictAddress(own, creator);
        vm.prank(creator);
        (address self,) = router.launchWith(own, address(imd), 1e18, false, 0, 0, address(0));
        assertEq(self, own.feeRecipient);
        assertEq(vault.recipientOf(self), self, "fees to its holders from the start");
    }

    /// @dev Audit R5-A4-3: a new fee recipient that clears the previous recipient's stale link (tidying the coin's page
    ///      before linking its own) doesn't use up the nonce, so the voucher it already holds still works. Clearing a
    ///      stale link revokes nothing (R4-A4-6); the recipient revoking its own live link still voids earlier
    ///      vouchers (R3-A4-5, `test_social_strangerClearDoesNotVoidTheNewRecipientsVoucher`).
    function test_social_newRecipientClearingAStaleLinkKeepsItsVoucher() public {
        address coin = _launch(_noTax(), 0);
        uint256 deadline = T0 + 1 days;
        bytes32 old = keccak256("old");
        bytes memory v0 = _voucher(coin, old, creator, 0, deadline);
        vm.prank(creator);
        social.link(coin, old, deadline, v0);
        vm.prank(creator);
        vault.setRecipient(coin, newOwner);
        bytes32 h = keccak256("new");
        bytes memory v1 = _voucher(coin, h, newOwner, 1, deadline); // signed before the stale link is cleared
        vm.prank(newOwner);
        social.unlink(coin); // the new recipient tidies up
        assertEq(social.nonces(coin), 1, "the nonce didn't move");
        vm.prank(newOwner);
        social.link(coin, h, deadline, v1);
        (bytes32 badge,) = social.badgeOf(coin);
        assertEq(badge, h);
    }

    /// @dev Audit R5-A4-3: the previous recipient clearing its own stale link doesn't use up the nonce either. Its vouchers
    ///      are useless while it isn't the recipient, so a bump would only void the voucher the new recipient holds (the
    ///      R4-A4-6 path). Passes on `3cd764f` too: it pins the rule the fix keeps.
    function test_social_oldRecipientClearingItsStaleLinkKeepsTheNewVoucher() public {
        address coin = _launch(_noTax(), 0);
        uint256 deadline = T0 + 1 days;
        bytes32 old = keccak256("old");
        bytes memory v0 = _voucher(coin, old, creator, 0, deadline);
        vm.prank(creator);
        social.link(coin, old, deadline, v0);
        vm.prank(creator);
        vault.setRecipient(coin, newOwner);
        bytes32 h = keccak256("new");
        bytes memory v1 = _voucher(coin, h, newOwner, 1, deadline);
        vm.prank(creator);
        social.unlink(coin); // the old recipient clears the link it made
        assertEq(social.nonces(coin), 1, "the nonce didn't move");
        vm.prank(newOwner);
        social.link(coin, h, deadline, v1);
        (bytes32 badge,) = social.badgeOf(coin);
        assertEq(badge, h);
    }

    /// @dev Audit R5-A4-5: the version registry's verifier must be a contract: an address without code made `activate`
    ///      and `retireManualActivation` revert until another 7-day change.
    function test_versions_verifierNeedsCode() public {
        address eoa = makeAddr("eoa");
        vm.expectRevert(VersionRegistry.NoCode.selector);
        new VersionRegistry(address(this), address(0));
        vm.expectRevert(VersionRegistry.NoCode.selector);
        new VersionRegistry(address(this), eoa);
        vm.expectRevert(VersionRegistry.NoCode.selector);
        versions.setVerifier(address(0));
        vm.expectRevert(VersionRegistry.NoCode.selector);
        versions.setVerifier(eoa);
        AttestationVerifier other = new AttestationVerifier(slowTimelock);
        versions.setVerifier(address(other));
        assertEq(address(versions.verifier()), address(other));
    }

    /// @dev Audit R5-A4-7: every address of a version must have code, so a version can't commit to the code hash of an
    ///      empty account (a typo, or a contract not deployed yet); a balance is not code.
    function test_versions_registerNeedsCodeAtEveryAddress() public {
        address eoa = makeAddr("eoa");
        address[5] memory five = [address(factory), address(router), address(curve), address(hook), address(lens)];
        for (uint256 i; i < 5; i++) {
            address[5] memory v;
            for (uint256 j; j < 5; j++) {
                v[j] = i == j ? eoa : five[j];
            }
            vm.expectRevert(VersionRegistry.NoCode.selector);
            versions.register(v[0], v[1], v[2], v[3], v[4]);
        }
        vm.deal(eoa, 1 wei);
        vm.expectRevert(VersionRegistry.NoCode.selector);
        versions.register(eoa, five[1], five[2], five[3], five[4]);
        assertEq(versions.register(five[0], five[1], five[2], five[3], five[4]), 1);
    }

    /// @dev Audit R5-A4-6: the social registry's verifier can't be address(0), which refused every voucher until another
    ///      48 h change (the airdrop's setter already refused it).
    function test_social_verifierCantBeZero() public {
        vm.expectRevert(SocialRegistry.ZeroAddress.selector);
        new SocialRegistry(address(this), address(vault), address(0));
        vm.expectRevert(SocialRegistry.ZeroAddress.selector);
        social.setVerifier(address(0));
        assertEq(social.verifier(), linker);
    }

    /// @dev Audit R5-A4-8 (coverage): an accepted attestation can't be used again, for the same version or another; a
    ///      "no" is refused and leaves its request id unused; the manual fallback can't be retired while the verifier
    ///      has no signer (v1 approves none, D-86).
    function test_versions_attestationReplayAndNoAnswer() public {
        for (uint256 i; i < 3; i++) {
            versions.register(address(factory), address(router), address(curve), address(hook), address(lens));
        }
        vm.expectRevert(VersionRegistry.CannotRetire.selector);
        versions.retireManualActivation();
        _approveOracle();
        string memory job = "6f1d2c3a-1111-4222-8333-944455556666";
        OracleAttestation memory a = _att(versions.question(2, job), true);
        bytes memory sig = _sign(a, oracleKey);
        versions.activate(2, job, a, sig);
        assertTrue(versions.usedRequest(a.requestId));
        vm.expectRevert(VersionRegistry.RequestUsed.selector);
        versions.activate(2, job, a, sig);
        vm.expectRevert(VersionRegistry.RequestUsed.selector);
        versions.activate(3, job, a, sig);

        OracleAttestation memory no = _att(versions.question(3, job), false);
        bytes memory noSig = _sign(no, oracleKey);
        vm.expectRevert(VersionRegistry.AnswerNo.selector);
        versions.activate(3, job, no, noSig);
        assertFalse(versions.usedRequest(no.requestId), "a refused 'no' uses nothing up");
        assertEq(versions.versionInfo(3).activatedAt, 0);
        assertEq(versions.currentVersion(), 2);
    }

    /// @dev Audit R5-A4-8 (coverage): strangers can't use the owner setters of the governance contracts, nor the vault's
    ///      and the budget's wiring; unlinking a coin with no link reverts `NotLinked`.
    function test_governance_strangersOnOwnerSetters() public {
        address coin = _launch(_noTax(), 0);
        versions.register(address(factory), address(router), address(curve), address(hook), address(lens));
        vm.startPrank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        versions.setVerifier(address(verifier));
        vm.expectRevert(Ownable.Unauthorized.selector);
        versions.activateManually(1, "https://api.imd.fun/jobs/audit-1/report.md");
        vm.expectRevert(Ownable.Unauthorized.selector);
        versions.setCurrent(1);
        vm.expectRevert(Ownable.Unauthorized.selector);
        versions.retireManualActivation();
        vm.expectRevert(Ownable.Unauthorized.selector);
        verifier.setSigner(alice, true);
        vm.expectRevert(Ownable.Unauthorized.selector);
        social.setVerifier(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        budget.setRelay(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        budget.setMaxRequest(1);
        vm.expectRevert(Ownable.Unauthorized.selector);
        budget.initialize(alice, alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        budget.credit(coin, 1);
        vm.expectRevert(Ownable.Unauthorized.selector);
        config.setGuardian(alice);
        vm.expectRevert(CreatorVault.Unauthorized.selector);
        vault.initialize(alice, alice);
        vm.expectRevert(CreatorVault.Unauthorized.selector);
        vault.register(alice, alice);
        vm.expectRevert(CreatorVault.Unauthorized.selector);
        vault.credit(coin, 1);
        vm.stopPrank();
        vm.prank(creator);
        vm.expectRevert(SocialRegistry.NotLinked.selector);
        social.unlink(coin);
    }

    /// @dev Audit R5-A4-8 (coverage): the swarm budget's guards: a request above the cap or above the budget, a
    ///      stranger's cancel while the creator receives the fees, a second cancel or a release of a closed request,
    ///      and the owner's relay and cap setters.
    function test_swarmBudget_guardsAndSetters() public {
        address coin = _launch(CoinFees(100, 0, 0, 10_000), 0); // a 1% tax, all to the swarm budget
        vm.warp(T0 + 1 hours);
        _buy(alice, coin, 100e18);
        uint256 avail = budget.available(coin);
        assertGt(avail, 0);
        budget.setMaxRequest(uint96(avail / 2));
        vm.prank(creator);
        vm.expectRevert(SwarmBudget.AboveMaxRequest.selector);
        budget.requestSpend(coin, uint96(avail / 2 + 1), keccak256("site"));
        budget.setMaxRequest(100e18);
        vm.prank(creator);
        vm.expectRevert(SwarmBudget.InsufficientBudget.selector);
        budget.requestSpend(coin, uint96(avail + 1), keccak256("site"));
        vm.prank(creator);
        uint256 id = budget.requestSpend(coin, uint96(avail), keccak256("site"));
        vm.prank(alice);
        vm.expectRevert(Ownable.Unauthorized.selector);
        budget.cancel(id);
        vm.prank(creator);
        budget.cancel(id);
        vm.prank(creator);
        vm.expectRevert(SwarmBudget.RequestClosed.selector);
        budget.cancel(id);
        vm.prank(relay);
        vm.expectRevert(SwarmBudget.RequestClosed.selector);
        budget.release(id, "job-1");

        address newRelay = makeAddr("newRelay");
        budget.setRelay(newRelay);
        vm.prank(creator);
        uint256 id2 = budget.requestSpend(coin, uint96(avail), keccak256("site"));
        vm.prank(relay);
        vm.expectRevert(Ownable.Unauthorized.selector);
        budget.release(id2, "job-2");
        vm.prank(newRelay);
        budget.release(id2, "job-2");
        assertEq(imd.balanceOf(newRelay), avail);
        assertEq(budget.available(coin), 0);
    }

    /// @dev Audit R5-A4-1 (documented): a stale link (its linker no longer the fee recipient) still counts in
    ///      `linkCount`, so the same handle linked on another coin is flagged a duplicate until someone clears the
    ///      stale link; anyone may, and the flag goes. The site computes its warning from live links.
    function test_social_staleLinkFlagsADuplicateUntilCleared() public {
        address coin1 = _launch(_noTax(), 0);
        address coin2 = _launchOrdered(_noTax(), address(imd) > coin1);
        bytes32 h = keccak256("frogdao");
        uint256 deadline = T0 + 1 days;
        bytes memory v1 = _voucher(coin1, h, creator, 0, deadline);
        vm.prank(creator);
        social.link(coin1, h, deadline, v1);
        vm.prank(creator);
        vault.setRecipient(coin1, newOwner);
        (bytes32 b1,) = social.badgeOf(coin1);
        assertEq(b1, bytes32(0), "coin1 shows no badge");
        bytes memory v2 = _voucher(coin2, h, creator, 0, deadline);
        vm.prank(creator);
        social.link(coin2, h, deadline, v2);
        (bytes32 b2, bool dup) = social.badgeOf(coin2);
        assertEq(b2, h);
        assertTrue(dup, "the stale link still counts");
        vm.prank(alice); // anyone clears the stale link
        social.unlink(coin1);
        (, dup) = social.badgeOf(coin2);
        assertFalse(dup);
    }

    /// @dev Audit R5-A4-2 (documented): routing a coin's fees to its holders (recipient = the coin) ends its X badge for
    ///      good, since the coin never calls `link`; the creator's own wallet link stays on its profile.
    function test_social_holderRoutingEndsTheBadge() public {
        address coin = _launch(_noTax(), 0);
        bytes32 h = keccak256("frogcoin");
        uint256 deadline = T0 + 1 days;
        bytes memory v0 = _voucher(coin, h, creator, 0, deadline);
        vm.prank(creator);
        social.link(coin, h, deadline, v0);
        _linkX(creator, "frogcreator");
        vm.prank(creator);
        vault.setRecipient(coin, coin);
        (bytes32 badge,) = social.badgeOf(coin);
        assertEq(badge, bytes32(0), "no badge once the holders receive the fees");
        bytes memory v1 = _voucher(coin, h, creator, social.nonces(coin), deadline);
        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        social.link(coin, h, deadline, v1);
        assertEq(social.walletHandle(creator), "frogcreator", "the creator's own X link stays");
    }

    /// @dev Audit R5-A1-3 (coverage): `PadLens` pool quotes still equal router trades to the wei after outside routers
    ///      moved the price either way, for buys and sells, in both currency orderings.
    function test_lens_quotesAfterOutsideSwapsMovedThePrice() public {
        for (uint256 k; k < 2; k++) {
            address coin = _launchOrdered(_holderTax(200), k == 0);
            _fillCurve(coin);
            PoolKey memory key = hook.poolKey(coin);
            PoolSwapTest swapper = new PoolSwapTest(IPoolManager(address(pm)));
            imd.mint(address(this), 10_000e18);
            imd.approve(address(swapper), type(uint256).max);
            ERC20(coin).approve(address(swapper), type(uint256).max);

            _outsideSwap(swapper, key, true, 1_500e18); // an outside buy moves the price up
            (uint256 out,,,, bool full) = lens.quoteBuy(coin, 200e18);
            assertTrue(full);
            assertEq(_buy(alice, coin, 200e18), out, "buy quote after an outside buy");
            (uint256 imdOut,,, bool fullSell) = lens.quoteSell(coin, out / 2);
            assertTrue(fullSell);
            assertEq(_sell(alice, coin, out / 2), imdOut, "sell quote after an outside buy");

            _outsideSwap(swapper, key, false, ERC20(coin).balanceOf(address(this)) / 2); // an outside sell moves it down
            (out,,,, full) = lens.quoteBuy(coin, 50e18);
            assertTrue(full);
            assertEq(_buy(alice, coin, 50e18), out, "buy quote after an outside sell");
            (imdOut,,, fullSell) = lens.quoteSell(coin, out);
            assertTrue(fullSell);
            assertEq(_sell(alice, coin, out), imdOut, "sell quote after an outside sell");
        }
    }
}
