// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "solady/auth/Ownable.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {MarketBase} from "./Market.t.sol";
import {AirdropDistributor} from "../src/AirdropDistributor.sol";
import {TeamVesting} from "../src/TeamVesting.sol";

/// @dev A contract wallet (ERC-1271) that accepts its owner key's signatures.
contract Mock1271Wallet {
    address internal immutable signer;

    constructor(address signer_) {
        signer = signer_;
    }

    function isValidSignature(bytes32 hash, bytes calldata sig) external view returns (bytes4) {
        return ECDSA.recoverCalldata(hash, sig) == signer ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
}

contract DistributionTest is MarketBase {
    uint256 internal constant OPEN = START + 30 minutes; // the market opens in `_graduate()` at this time
    uint256 internal constant ACT = OPEN + 2 days; // `_activate()` brings in the 100th initiator at this time
    uint256 internal constant AIRDROP = 50_000_000e18;
    uint256 internal constant TEAM = 20_000_000e18;
    uint256 internal constant FILLERS = 100;
    uint256 internal constant FILLER_AMOUNT = 100_000e18;
    bytes32 internal constant DELEGATE_TYPEHASH =
        keccak256("Delegate(address account,address claimWallet,uint256 nonce,uint256 deadline)");
    bytes32 internal constant INITIATION_TYPEHASH =
        keccak256("Initiation(address account,bytes32 handleHash,bytes32 tweetHash,uint256 deadline)");

    AirdropDistributor internal airdrop;
    TeamVesting internal vesting;

    address internal dripperSink = makeAddr("rewardDripper");
    address internal teamSafe = makeAddr("teamSafe");
    address internal xChecker;
    uint256 internal xCheckerKey;
    address internal seat;
    uint256 internal seatKey;
    address internal hot = makeAddr("hotWallet");
    address internal staker = makeAddr("sIMDStaker");

    // Leaves 0..3: seat, staker, c, d (40M); leaves 4..103: 100 small holders (10M).
    address[] internal accounts;
    uint256[] internal amounts;
    bytes32[][] internal layers;

    function setUp() public override {
        super.setUp();
        (seat, seatKey) = makeAddrAndKey("seatHolder");
        (xChecker, xCheckerKey) = makeAddrAndKey("tweetChecker");
        accounts.push(seat);
        accounts.push(staker);
        accounts.push(makeAddr("c"));
        accounts.push(makeAddr("d"));
        amounts.push(20_000_000e18);
        amounts.push(12_000_000e18);
        amounts.push(5_000_000e18);
        amounts.push(3_000_000e18);
        for (uint256 i; i < FILLERS; ++i) {
            accounts.push(address(uint160(0x9000 + i)));
            amounts.push(FILLER_AMOUNT);
        }
        _buildTree();

        airdrop = new AirdropDistributor(
            timelock, address(pondpad), layers[layers.length - 1][0], address(controller), dripperSink, xChecker
        );
        vesting = new TeamVesting(address(pondpad), address(controller), teamSafe);
        pondpad.transfer(address(airdrop), AIRDROP);
        vm.prank(trader); // the test base already gave the sale and the trader 950M
        pondpad.transfer(address(vesting), TEAM);
        assertEq(airdrop.DELEGATE_TYPEHASH(), DELEGATE_TYPEHASH);
        assertEq(airdrop.INITIATION_TYPEHASH(), INITIATION_TYPEHASH);
    }

    // ------------------------------------------------------------------ Merkle helpers (OZ-compatible leaves, sorted pairs)

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
    }

    function _buildTree() internal {
        bytes32[] memory level = new bytes32[](accounts.length);
        for (uint256 i; i < level.length; ++i) {
            level[i] = keccak256(bytes.concat(keccak256(abi.encode(accounts[i], amounts[i]))));
        }
        layers.push(level);
        while (level.length > 1) {
            bytes32[] memory up = new bytes32[]((level.length + 1) / 2);
            for (uint256 i; i < up.length; ++i) {
                up[i] = 2 * i + 1 < level.length ? _hashPair(level[2 * i], level[2 * i + 1]) : level[2 * i];
            }
            layers.push(up);
            level = up;
        }
    }

    function _proof(uint256 i) internal view returns (bytes32[] memory p) {
        bytes32[] memory tmp = new bytes32[](layers.length);
        uint256 n;
        for (uint256 l; l + 1 < layers.length; ++l) {
            uint256 sib = i ^ 1;
            if (sib < layers[l].length) tmp[n++] = layers[l][sib]; // an odd last node moves up without a sibling
            i /= 2;
        }
        p = new bytes32[](n);
        for (uint256 k; k < n; ++k) {
            p[k] = tmp[k];
        }
    }

    // ------------------------------------------------------------------ Signature helpers

    function _digest(bytes32 structHash) internal view returns (bytes32) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("PondPad Airdrop"),
                keccak256("1"),
                block.chainid,
                address(airdrop)
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", domain, structHash));
    }

    function _sign(uint256 key, bytes32 structHash) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, _digest(structHash));
        return abi.encodePacked(r, s, v);
    }

    function _delegateSig(address claimWallet, uint256 nonce, uint256 deadline) internal view returns (bytes memory) {
        return _sign(seatKey, keccak256(abi.encode(DELEGATE_TYPEHASH, seat, claimWallet, nonce, deadline)));
    }

    function _voucher(uint256 key, address account, bytes32 handle, bytes32 tweet, uint256 deadline)
        internal
        view
        returns (bytes memory)
    {
        return _sign(key, keccak256(abi.encode(INITIATION_TYPEHASH, account, handle, tweet, deadline)));
    }

    /// @dev Account `i` initiates with X handle and tweet derived from `i`, a voucher valid for a day.
    function _initiate(uint256 i, uint256 now_) internal {
        address a = accounts[i];
        bytes32 handle = keccak256(abi.encode("handle", i));
        bytes32 tweet = keccak256(abi.encode("tweet", i));
        bytes memory v = _voucher(xCheckerKey, a, handle, tweet, now_ + 1 days);
        bytes32[] memory p = _proof(i);
        vm.prank(a);
        airdrop.initiate(a, amounts[i], p, handle, tweet, now_ + 1 days, v);
    }

    /// @dev Market opens at OPEN; the 100 small holders initiate, the last one at ACT.
    function _activate() internal {
        _graduate();
        vm.warp(OPEN + 1 days);
        for (uint256 i = 4; i < 4 + FILLERS - 1; ++i) {
            _initiate(i, OPEN + 1 days);
        }
        vm.warp(ACT);
        _initiate(4 + FILLERS - 1, ACT);
        assertEq(airdrop.activatedAt(), ACT);
    }

    // ------------------------------------------------------------------ Initiation

    function test_airdrop_activatesAtHundredthInitiatorAfterMarketOpen() public {
        vm.expectRevert(AirdropDistributor.MarketNotOpen.selector);
        _initiate(4, OPEN - 1);

        _graduate();
        vm.warp(OPEN + 1 days); // market open alone starts nothing
        vm.prank(staker);
        vm.expectRevert(AirdropDistributor.NotActive.selector);
        airdrop.claim(staker, amounts[1], _proof(1));

        for (uint256 i = 4; i < 4 + FILLERS - 1; ++i) {
            _initiate(i, OPEN + 1 days);
        }
        assertEq(airdrop.initiatorCount(), 99);
        assertEq(airdrop.activatedAt(), 0);
        assertEq(airdrop.claimable(staker, amounts[1]), 0);
        assertEq(airdrop.claimDeadline(), 0);

        vm.warp(ACT);
        _initiate(4 + FILLERS - 1, ACT);
        assertEq(airdrop.initiatorCount(), 100);
        assertEq(airdrop.activatedAt(), ACT);
        assertEq(airdrop.claimDeadline(), ACT + 180 days);

        vm.expectRevert(AirdropDistributor.AlreadyActive.selector); // no more initiations needed
        _initiate(2, ACT);

        // Everyone on the list can claim, initiators or not; vesting counts from activation.
        vm.warp(ACT + 6 days); // 1/5 vested
        vm.prank(staker);
        assertEq(airdrop.claim(staker, amounts[1], _proof(1)), amounts[1] / 5);
        vm.prank(staker);
        assertEq(airdrop.claim(staker, amounts[1], _proof(1)), 0); // nothing new in the same second
        vm.warp(ACT + 15 days);
        assertEq(airdrop.claimable(staker, amounts[1]), amounts[1] / 2 - amounts[1] / 5);
        vm.warp(ACT + 45 days);
        vm.prank(staker);
        airdrop.claim(staker, amounts[1], _proof(1));
        assertEq(pondpad.balanceOf(staker), amounts[1]);
        address filler = accounts[10];
        vm.prank(filler); // initiators get exactly their share (no bonus)
        assertEq(airdrop.claim(filler, FILLER_AMOUNT, _proof(10)), FILLER_AMOUNT);
        assertEq(airdrop.totalClaimed(), amounts[1] + FILLER_AMOUNT);
    }

    function test_airdrop_initiationGuards() public {
        _graduate();
        vm.warp(OPEN + 1 days);
        uint256 t = OPEN + 1 days;
        address a = accounts[4];
        bytes32 h = keccak256("h");
        bytes32 tw = keccak256("t");
        bytes32[] memory p = _proof(4);

        vm.prank(hot); // a stranger can't initiate for someone
        vm.expectRevert(AirdropDistributor.NotAuthorized.selector);
        airdrop.initiate(a, FILLER_AMOUNT, p, h, tw, t + 1, _voucher(xCheckerKey, a, h, tw, t + 1));

        vm.startPrank(a);
        (, uint256 otherKey) = makeAddrAndKey("other");
        vm.expectRevert(AirdropDistributor.BadVoucher.selector); // not the tweet checker
        airdrop.initiate(a, FILLER_AMOUNT, p, h, tw, t + 1, _voucher(otherKey, a, h, tw, t + 1));
        vm.expectRevert(AirdropDistributor.BadVoucher.selector); // voucher for another wallet
        airdrop.initiate(a, FILLER_AMOUNT, p, h, tw, t + 1, _voucher(xCheckerKey, accounts[5], h, tw, t + 1));
        vm.expectRevert(AirdropDistributor.BadVoucher.selector); // voucher for another tweet
        airdrop.initiate(a, FILLER_AMOUNT, p, h, keccak256("t2"), t + 1, _voucher(xCheckerKey, a, h, tw, t + 1));
        vm.expectRevert(AirdropDistributor.Expired.selector);
        airdrop.initiate(a, FILLER_AMOUNT, p, h, tw, t - 1, _voucher(xCheckerKey, a, h, tw, t - 1));
        vm.expectRevert(AirdropDistributor.InvalidProof.selector); // wrong amount
        airdrop.initiate(a, FILLER_AMOUNT + 1, p, h, tw, t + 1, _voucher(xCheckerKey, a, h, tw, t + 1));
        airdrop.initiate(a, FILLER_AMOUNT, p, h, tw, t + 1, _voucher(xCheckerKey, a, h, tw, t + 1));
        vm.expectRevert(AirdropDistributor.AlreadyInitiated.selector);
        airdrop.initiate(a, FILLER_AMOUNT, p, keccak256("h2"), keccak256("t2"), t + 1, "");
        vm.stopPrank();

        address b = accounts[5];
        p = _proof(5);
        vm.startPrank(b);
        vm.expectRevert(AirdropDistributor.HandleUsed.selector); // one X account, one wallet
        airdrop.initiate(b, FILLER_AMOUNT, p, h, keccak256("t2"), t + 1, "");
        vm.expectRevert(AirdropDistributor.TweetUsed.selector);
        airdrop.initiate(b, FILLER_AMOUNT, p, keccak256("h2"), tw, t + 1, "");
        vm.stopPrank();

        // Not on the list: no proof works.
        address outsider = makeAddr("outsider");
        vm.prank(outsider);
        vm.expectRevert(AirdropDistributor.InvalidProof.selector);
        airdrop.initiate(outsider, FILLER_AMOUNT, p, keccak256("h3"), keccak256("t3"), t + 1, "");

        // The claim wallet named by signature can initiate for the seat holder.
        bytes memory d = _delegateSig(hot, 0, t + 1);
        airdrop.setClaimWalletBySig(seat, hot, t + 1, d);
        bytes32 h4 = keccak256("h4");
        bytes32 t4 = keccak256("t4");
        bytes memory v4 = _voucher(xCheckerKey, seat, h4, t4, t + 1);
        bytes32[] memory p0 = _proof(0);
        vm.prank(hot);
        airdrop.initiate(seat, amounts[0], p0, h4, t4, t + 1, v4);
        assertTrue(airdrop.initiated(seat));
        assertEq(airdrop.initiatorCount(), 2);

        // Codes differ per wallet.
        assertTrue(airdrop.initiationCode(a) != airdrop.initiationCode(b));
    }

    function test_airdrop_onlyTimelockReplacesTweetChecker() public {
        (address newChecker, uint256 newKey) = makeAddrAndKey("newChecker");
        vm.expectRevert(Ownable.Unauthorized.selector);
        airdrop.setVerifier(newChecker);
        vm.prank(timelock);
        airdrop.setVerifier(newChecker);
        assertEq(airdrop.verifier(), newChecker);

        _graduate();
        vm.warp(OPEN + 1 days);
        vm.expectRevert(AirdropDistributor.BadVoucher.selector); // old key no longer works
        _initiate(4, OPEN + 1 days);
        address a = accounts[4];
        bytes32 h = keccak256("h");
        bytes32 tw = keccak256("t");
        bytes memory v = _voucher(newKey, a, h, tw, OPEN + 2 days);
        bytes32[] memory p = _proof(4);
        vm.prank(a);
        airdrop.initiate(a, FILLER_AMOUNT, p, h, tw, OPEN + 2 days, v);
        assertEq(airdrop.initiatorCount(), 1);
    }

    // ------------------------------------------------------------------ Claims

    function test_airdrop_claimGuards() public {
        _activate();
        vm.warp(ACT + 30 days);
        bytes32[] memory p = _proof(1);

        vm.prank(hot); // a stranger can't trigger someone else's claim
        vm.expectRevert(AirdropDistributor.NotAuthorized.selector);
        airdrop.claim(staker, amounts[1], p);

        vm.startPrank(staker);
        vm.expectRevert(AirdropDistributor.InvalidProof.selector); // wrong amount
        airdrop.claim(staker, amounts[1] + 1, p);
        vm.expectRevert(AirdropDistributor.InvalidProof.selector); // someone else's proof
        airdrop.claim(staker, amounts[1], _proof(2));
        vm.expectRevert(AirdropDistributor.ZeroAddress.selector);
        airdrop.setClaimWallet(address(0));
        vm.stopPrank();
    }

    function test_airdrop_claimWalletByGaslessSignature() public {
        _activate();
        vm.warp(ACT + 10 days); // 1/3 vested
        bytes32[] memory p = _proof(0);
        uint256 deadline = ACT + 11 days;
        bytes memory sig = _delegateSig(hot, 0, deadline);

        vm.prank(hot); // the seat holder's main wallet never sends a transaction
        uint256 paid = airdrop.setClaimWalletAndClaim(seat, deadline, sig, amounts[0], p);
        assertEq(paid, amounts[0] / 3);
        assertEq(airdrop.claimWalletOf(seat), hot);
        assertEq(pondpad.balanceOf(hot), paid);
        assertEq(pondpad.balanceOf(seat), 0);

        vm.expectRevert(AirdropDistributor.BadSignature.selector); // nonce used
        airdrop.setClaimWalletBySig(seat, hot, deadline, sig);
        vm.expectRevert(AirdropDistributor.BadSignature.selector); // signature for another claim wallet
        airdrop.setClaimWalletBySig(seat, staker, deadline, sig);

        // Later claims, by the main wallet or the claim wallet, always pay the claim wallet.
        vm.warp(ACT + 30 days);
        vm.prank(seat);
        airdrop.claim(seat, amounts[0], p);
        assertEq(pondpad.balanceOf(hot), amounts[0]);
        assertEq(pondpad.balanceOf(seat), 0);

        vm.warp(ACT + 40 days);
        bytes memory late = _delegateSig(staker, 1, ACT + 39 days);
        vm.expectRevert(AirdropDistributor.Expired.selector);
        airdrop.setClaimWalletBySig(seat, staker, ACT + 39 days, late);
        vm.prank(seat); // the eligible wallet can still re-point its claim wallet directly
        airdrop.setClaimWallet(staker);
        assertEq(airdrop.claimWalletOf(seat), staker);
    }

    /// @dev Audit R1-A3-4: re-pointing the claim wallet directly voids a delegation signed earlier but not submitted.
    function test_airdrop_directClaimWalletVoidsUnsubmittedDelegation() public {
        _activate();
        vm.warp(ACT + 30 days);
        uint256 deadline = ACT + 60 days;
        bytes memory sig = _delegateSig(hot, 0, deadline); // signed, never submitted
        vm.prank(seat);
        airdrop.setClaimWallet(staker);
        bytes32[] memory p = _proof(0);
        vm.prank(hot);
        vm.expectRevert(AirdropDistributor.BadSignature.selector);
        airdrop.setClaimWalletAndClaim(seat, deadline, sig, amounts[0], p);
        assertEq(airdrop.claimWalletOf(seat), staker);
    }

    /// @dev Audit R1-A3-5: if someone already submitted the delegation, the claim wallet's one-transaction claim
    ///      still works.
    function test_airdrop_combinedClaimWorksAfterDelegationWasSubmitted() public {
        _activate();
        vm.warp(ACT + 30 days);
        uint256 deadline = ACT + 31 days;
        bytes memory sig = _delegateSig(hot, 0, deadline);
        airdrop.setClaimWalletBySig(seat, hot, deadline, sig); // a relay (anyone) submits it first
        bytes32[] memory p = _proof(0);
        vm.prank(hot);
        uint256 paid = airdrop.setClaimWalletAndClaim(seat, deadline, sig, amounts[0], p);
        assertEq(paid, amounts[0]);
        assertEq(pondpad.balanceOf(hot), amounts[0]);
    }

    function test_airdrop_unclaimedSweptToStakersAfter180Days() public {
        vm.expectRevert(AirdropDistributor.ClaimWindowNotOver.selector); // not even active
        airdrop.sweep();
        _activate();
        vm.warp(ACT + 30 days);
        vm.prank(staker);
        airdrop.claim(staker, amounts[1], _proof(1));

        vm.warp(ACT + 180 days - 1);
        vm.expectRevert(AirdropDistributor.ClaimWindowNotOver.selector);
        airdrop.sweep();
        vm.prank(seat);
        airdrop.claim(seat, amounts[0], _proof(0)); // last second

        vm.warp(ACT + 180 days);
        vm.prank(accounts[2]);
        vm.expectRevert(AirdropDistributor.ClaimWindowOver.selector);
        airdrop.claim(accounts[2], amounts[2], _proof(2));
        assertEq(airdrop.claimable(accounts[2], amounts[2]), 0);

        vm.prank(hot); // permissionless
        uint256 swept = airdrop.sweep();
        assertEq(swept, amounts[2] + amounts[3] + FILLERS * FILLER_AMOUNT);
        assertEq(pondpad.balanceOf(dripperSink), swept);
        assertEq(pondpad.balanceOf(address(airdrop)), 0);
    }

    // ------------------------------------------------------------------ Team vesting

    function test_teamVesting_oneMonthCliffSixMonthsLinearFromMarketOpen() public {
        assertEq(vesting.release(), 0); // market not open
        _graduate();

        vm.warp(OPEN + 30 days - 1);
        assertEq(vesting.releasable(), 0);
        assertEq(vesting.release(), 0);

        vm.warp(OPEN + 30 days); // cliff: 1/6 at once
        vm.prank(hot); // permissionless, always pays the Safe
        assertEq(vesting.release(), TEAM / 6);
        assertEq(pondpad.balanceOf(teamSafe), TEAM / 6);

        vm.warp(OPEN + 90 days); // half
        assertEq(vesting.vestedAmount(), TEAM / 2);
        vesting.release();
        assertEq(pondpad.balanceOf(teamSafe), TEAM / 2);

        vm.warp(OPEN + 400 days);
        vesting.release();
        assertEq(pondpad.balanceOf(teamSafe), TEAM);
        assertEq(vesting.released(), TEAM);
        assertEq(vesting.release(), 0);
    }

    function test_teamVesting_onlyBeneficiaryMovesIt() public {
        address newSafe = makeAddr("newSafe");
        vm.expectRevert(TeamVesting.NotBeneficiary.selector);
        vesting.setBeneficiary(newSafe);
        vm.startPrank(teamSafe);
        vm.expectRevert(TeamVesting.ZeroAddress.selector);
        vesting.setBeneficiary(address(0));
        vesting.setBeneficiary(newSafe);
        vm.stopPrank();

        _graduate();
        vm.warp(OPEN + 180 days);
        vesting.release();
        assertEq(pondpad.balanceOf(newSafe), TEAM);
        assertEq(pondpad.balanceOf(teamSafe), 0);
    }

    // ------------------------------------------------------------------ Audit round 4

    /// @dev Audit R4-A3-8: a listed EOA carrying an EIP-7702 delegation (code `0xef0100…`) still names its claim wallet
    ///      with its own key's signature, and a tweet checker key in the same state still signs initiations.
    function test_airdrop_delegatedEoaSignaturesStillCount() public {
        vm.etch(seat, abi.encodePacked(hex"ef0100", address(0xdead)));
        bytes memory sig = _delegateSig(hot, 0, OPEN);
        airdrop.setClaimWalletBySig(seat, hot, OPEN, sig);
        assertEq(airdrop.claimWalletOf(seat), hot);

        vm.etch(xChecker, abi.encodePacked(hex"ef0100", address(0xdead)));
        _graduate();
        vm.warp(OPEN + 1 days);
        _initiate(4, OPEN + 1 days);
        assertEq(airdrop.initiatorCount(), 1);
    }

    /// @dev Audit R4-A3-9 (coverage): a contract wallet on the list (ERC-1271) names its claim wallet by signature, and
    ///      a contract tweet checker (ERC-1271) signs initiations.
    function test_airdrop_contractWalletAndContractChecker() public {
        (address walletOwner, uint256 walletKey) = makeAddrAndKey("walletOwner");
        address c = accounts[2];
        vm.etch(c, address(new Mock1271Wallet(walletOwner)).code);
        bytes memory sig = _sign(walletKey, keccak256(abi.encode(DELEGATE_TYPEHASH, c, hot, 0, OPEN)));
        airdrop.setClaimWalletBySig(c, hot, OPEN, sig);
        assertEq(airdrop.claimWalletOf(c), hot);
        bytes memory wrong = _sign(seatKey, keccak256(abi.encode(DELEGATE_TYPEHASH, c, staker, 1, OPEN)));
        vm.expectRevert(AirdropDistributor.BadSignature.selector); // not the wallet's key
        airdrop.setClaimWalletBySig(c, staker, OPEN, wrong);

        (address checkerOwner, uint256 checkerKey) = makeAddrAndKey("checkerOwner");
        Mock1271Wallet checker = new Mock1271Wallet(checkerOwner);
        vm.prank(timelock);
        airdrop.setVerifier(address(checker));
        _graduate();
        vm.warp(OPEN + 1 days);
        address a = accounts[4];
        bytes32 handle = keccak256("contract-checker-handle");
        bytes32 tweet = keccak256("contract-checker-tweet");
        bytes memory v = _voucher(checkerKey, a, handle, tweet, OPEN + 2 days);
        bytes32[] memory p = _proof(4);
        vm.prank(a);
        airdrop.initiate(a, amounts[4], p, handle, tweet, OPEN + 2 days, v);
        assertEq(airdrop.initiatorCount(), 1);
    }

    /// @dev Audit R4-A3-9 (coverage): a claim wallet set directly with `setClaimWallet` claims, and is paid.
    function test_airdrop_claimThroughADirectlySetClaimWallet() public {
        vm.prank(staker);
        airdrop.setClaimWallet(hot);
        _activate();
        vm.warp(ACT + 30 days);
        bytes32[] memory p = _proof(1);
        vm.prank(hot);
        uint256 paid = airdrop.claim(staker, amounts[1], p);
        assertEq(paid, amounts[1]);
        assertEq(pondpad.balanceOf(hot), amounts[1]);
        assertEq(pondpad.balanceOf(staker), 0);
    }

    /// @dev Audits R6-A3-5 (documented sink) and R6-A3-6 (coverage): $PONDPAD that reaches `TeamVesting` after deploy
    ///      joins the schedule and is paid to the beneficiary on the same clock; after day 180, at once.
    function test_teamVesting_lateTransferVestsToTheBeneficiary() public {
        _graduate();
        vm.warp(OPEN + 90 days);
        vm.prank(trader);
        pondpad.transfer(address(vesting), 6e18); // half-way: half of it has vested
        assertApproxEqAbs(vesting.vestedAmount(), (TEAM + 6e18) / 2, 1e6);
        vm.warp(OPEN + 200 days);
        vesting.release();
        assertEq(pondpad.balanceOf(teamSafe), TEAM + 6e18);
        vm.prank(trader);
        pondpad.transfer(address(vesting), 1e18);
        assertEq(vesting.releasable(), 1e18);
        vesting.release();
        assertEq(pondpad.balanceOf(teamSafe), TEAM + 7e18);
    }

    /// @dev Audit R6-A4-7 (coverage): a listed wallet with amount 0 is a valid leaf: it initiates and counts toward the
    ///      100 (`Deploy.s.sol` accepts such a list too, `test_deploy_airdropListAcceptsAZeroAmountClaim`).
    function test_airdrop_zeroAmountLeafCountsAsAnInitiator() public {
        accounts.push(makeAddr("zeroLeaf"));
        amounts.push(0);
        delete layers;
        _buildTree();
        airdrop = new AirdropDistributor(
            timelock, address(pondpad), layers[layers.length - 1][0], address(controller), dripperSink, xChecker
        );
        _graduate();
        vm.warp(OPEN + 1 days);
        _initiate(accounts.length - 1, OPEN + 1 days);
        assertEq(airdrop.initiatorCount(), 1);
        _initiate(4, OPEN + 1 days);
        assertEq(airdrop.initiatorCount(), 2);
    }
}
