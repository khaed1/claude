// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {MarketBase} from "./Market.t.sol";
import {AirdropDistributor} from "../src/AirdropDistributor.sol";
import {TeamVesting} from "../src/TeamVesting.sol";

contract DistributionTest is MarketBase {
    uint256 internal constant OPEN = START + 30 minutes; // the market opens in `_graduate()` at this time
    uint256 internal constant AIRDROP = 50_000_000e18;
    uint256 internal constant TEAM = 20_000_000e18;

    AirdropDistributor internal airdrop;
    TeamVesting internal vesting;

    address internal dripperSink = makeAddr("rewardDripper");
    address internal teamSafe = makeAddr("teamSafe");
    address internal seat;
    uint256 internal seatKey;
    address internal hot = makeAddr("hotWallet");
    address internal staker = makeAddr("sIMDStaker");

    address[4] internal accounts;
    uint256[4] internal amounts;
    bytes32[4] internal leaves;

    function setUp() public override {
        super.setUp();
        (seat, seatKey) = makeAddrAndKey("seatHolder");
        accounts = [seat, staker, makeAddr("c"), makeAddr("d")];
        amounts = [uint256(30_000_000e18), 12_000_000e18, 5_000_000e18, 3_000_000e18];
        for (uint256 i; i < 4; ++i) {
            leaves[i] = keccak256(bytes.concat(keccak256(abi.encode(accounts[i], amounts[i]))));
        }
        bytes32 root = _hashPair(_hashPair(leaves[0], leaves[1]), _hashPair(leaves[2], leaves[3]));

        airdrop = new AirdropDistributor(address(pondpad), root, address(controller), dripperSink);
        vesting = new TeamVesting(address(pondpad), address(controller), teamSafe);
        pondpad.transfer(address(airdrop), AIRDROP);
        vm.prank(trader); // the test base already gave the sale and the trader 950M
        pondpad.transfer(address(vesting), TEAM);
    }

    // ------------------------------------------------------------------ Merkle helpers (OZ StandardMerkleTree)

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
    }

    function _proof(uint256 i) internal view returns (bytes32[] memory p) {
        p = new bytes32[](2);
        p[0] = leaves[i ^ 1];
        p[1] = i < 2 ? _hashPair(leaves[2], leaves[3]) : _hashPair(leaves[0], leaves[1]);
    }

    function _delegateSig(address claimWallet, uint256 nonce, uint256 deadline) internal view returns (bytes memory) {
        bytes32 structHash = keccak256(abi.encode(airdrop.DELEGATE_TYPEHASH(), seat, claimWallet, nonce, deadline));
        bytes32 domain = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("PondPad Airdrop"),
                keccak256("1"),
                block.chainid,
                address(airdrop)
            )
        );
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(seatKey, keccak256(abi.encodePacked("\x19\x01", domain, structHash)));
        return abi.encodePacked(r, s, v);
    }

    // ------------------------------------------------------------------ Airdrop

    function test_airdrop_vestsOverThirtyDaysFromMarketOpen() public {
        bytes32[] memory p = _proof(1);
        vm.prank(staker);
        vm.expectRevert(AirdropDistributor.NotOpen.selector);
        airdrop.claim(staker, amounts[1], p);
        assertEq(airdrop.claimable(staker, amounts[1]), 0);
        assertEq(airdrop.claimDeadline(), 0);

        _graduate();
        assertEq(controller.openedAt(), OPEN);
        assertEq(airdrop.claimDeadline(), OPEN + 180 days);

        vm.warp(OPEN + 6 days); // 1/5 vested
        vm.prank(staker);
        assertEq(airdrop.claim(staker, amounts[1], p), amounts[1] / 5);
        vm.prank(staker);
        assertEq(airdrop.claim(staker, amounts[1], p), 0); // nothing new in the same second

        vm.warp(OPEN + 15 days);
        assertEq(airdrop.claimable(staker, amounts[1]), amounts[1] / 2 - amounts[1] / 5);
        vm.warp(OPEN + 45 days); // fully vested
        vm.prank(staker);
        assertEq(airdrop.claim(staker, amounts[1], p), amounts[1] - amounts[1] / 5);
        assertEq(pondpad.balanceOf(staker), amounts[1]);
        assertEq(airdrop.totalClaimed(), amounts[1]);
        vm.prank(staker);
        assertEq(airdrop.claim(staker, amounts[1], p), 0);
    }

    function test_airdrop_guards() public {
        _graduate();
        vm.warp(OPEN + 30 days);
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
        _graduate();
        vm.warp(OPEN + 10 days); // 1/3 vested
        bytes32[] memory p = _proof(0);
        uint256 deadline = OPEN + 11 days;
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
        vm.warp(OPEN + 30 days);
        vm.prank(seat);
        airdrop.claim(seat, amounts[0], p);
        assertEq(pondpad.balanceOf(hot), amounts[0]);
        assertEq(pondpad.balanceOf(seat), 0);

        vm.warp(OPEN + 40 days);
        bytes memory late = _delegateSig(staker, 1, OPEN + 39 days);
        vm.expectRevert(AirdropDistributor.Expired.selector);
        airdrop.setClaimWalletBySig(seat, staker, OPEN + 39 days, late);
        vm.prank(seat); // the eligible wallet can still re-point its claim wallet directly
        airdrop.setClaimWallet(staker);
        assertEq(airdrop.claimWalletOf(seat), staker);
    }

    function test_airdrop_unclaimedSweptToStakersAfter180Days() public {
        vm.expectRevert(AirdropDistributor.ClaimWindowNotOver.selector); // not even open
        airdrop.sweep();
        _graduate();
        vm.warp(OPEN + 30 days);
        vm.prank(staker);
        airdrop.claim(staker, amounts[1], _proof(1));

        vm.warp(OPEN + 180 days - 1);
        vm.expectRevert(AirdropDistributor.ClaimWindowNotOver.selector);
        airdrop.sweep();
        vm.prank(seat);
        airdrop.claim(seat, amounts[0], _proof(0)); // last second

        vm.warp(OPEN + 180 days);
        vm.prank(accounts[2]);
        vm.expectRevert(AirdropDistributor.ClaimWindowOver.selector);
        airdrop.claim(accounts[2], amounts[2], _proof(2));
        assertEq(airdrop.claimable(accounts[2], amounts[2]), 0);

        vm.prank(hot); // permissionless
        uint256 swept = airdrop.sweep();
        assertEq(swept, amounts[2] + amounts[3]);
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
}
