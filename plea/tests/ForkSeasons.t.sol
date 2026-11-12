// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PLEA} from "../src/PLEA.sol";
import {CabalGate} from "../src/CabalGate.sol";
import {Seasons} from "../src/Seasons.sol";
import {Laureates} from "../src/Laureates.sol";
import {PleaHook} from "../src/PleaHook.sol";
import {OracleAttestation} from "../src/OracleAttestation.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

interface IPoolSwapTest {
    struct TestSettings {
        bool takeClaims;
        bool settleUsingBurn;
    }

    function swap(PoolKey memory key, SwapParams memory params, TestSettings memory s, bytes memory hookData)
        external
        payable
        returns (int256);
}

interface IMintable {
    function mint(address to, uint256 amount) external;
}

/// Full Seasons lifecycle against the live Sepolia launch #1242 on a fork. The oracle signer slot is
/// swapped for a test key so verdicts can be delivered by impersonating the Intake.
contract ForkSeasonsTest is Test {
    PLEA plea = PLEA(0x9b8d9aAE44e81B1205E227911DB279bDe6eDEAD9);
    CabalGate gate = CabalGate(0x758B8300C62563591950F32717BE44a5140a20f9);
    Seasons seasons = Seasons(0x178481Ac37E68A5c6EF95336DB4616Ba0169A17A);
    Laureates laureates = Laureates(0xD2311B6d4C42a6dC3900a0A74a364b2775dd61C1);
    PleaHook hook = PleaHook(0x3d4CcAc329010b8beA3b14498d9a45EAB00c68Cc);
    IPoolSwapTest pst = IPoolSwapTest(0x9B6b46e2c869aa39918Db7f52f5557FE577B6eEe);
    IERC20 imd = IERC20(0x2B69099E59b05901faA1DD164fabf098bf831E82);
    address oracleImd = 0x44a1Cd38474FB1748400E7DEb5F8D786ccE3F89A;
    address intake = 0x1397434cd35e8a9C8aC312A61D3A285EB31dea56;
    uint256 constant SIGNER_KEY = 0xA11CE;
    uint256 nonce;

    address[] w;

    function setUp() public {
        vm.createSelectFork("https://ethereum-sepolia-rpc.publicnode.com", 11887460);
        vm.store(address(gate), bytes32(uint256(2)), bytes32(uint256(uint160(vm.addr(SIGNER_KEY)))));
        assertEq(gate.oracleSigner(), vm.addr(SIGNER_KEY));
        for (uint256 i; i < 12; ++i) {
            address a = makeAddr(string.concat("w", vm.toString(i)));
            w.push(a);
            deal(address(imd), a, 10_000e18);
            vm.startPrank(a);
            imd.approve(address(pst), type(uint256).max);
            imd.approve(address(gate), type(uint256).max);
            IERC20(oracleImd).approve(address(gate), type(uint256).max);
            plea.approve(address(gate), type(uint256).max);
            plea.approve(address(pst), type(uint256).max);
            vm.stopPrank();
            IMintable(oracleImd).mint(a, 100e18);
        }
    }

    function _key() internal view returns (PoolKey memory) {
        return hook.poolKey();
    }

    function buy(address who, uint256 imdIn) internal {
        PoolKey memory k = _key();
        vm.prank(who);
        pst.swap(
            k,
            SwapParams({zeroForOne: true, amountSpecified: -int256(imdIn), sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1}),
            IPoolSwapTest.TestSettings(false, false),
            abi.encode(who)
        );
    }

    function _attest(uint256 score) internal returns (OracleAttestation.Attestation memory a) {
        a = OracleAttestation.Attestation({
            requestId: keccak256(abi.encode("fork", ++nonce)),
            chainId: 1,
            questionHash: keccak256("q"),
            answerType: 3,
            answer: abi.encode(score),
            figure: score,
            fromBlock: 1,
            toBlock: 2,
            blockHash: keccak256("b"),
            panelJobId: keccak256(abi.encode("job", nonce)),
            panelSize: 30,
            quorum: 17,
            agreed: 20,
            issuedAt: uint64(vm.getBlockTimestamp()),
            expiresAt: uint64(vm.getBlockTimestamp() + 3600)
        });
    }

    /// Plead 5% of the balance and deliver `score`; sell if approved and `sell`.
    function pleadAndAnswer(address who, uint256 score, bool sell) internal returns (uint256 id, bool approved) {
        uint256 amount = plea.balanceOf(who) / 20;
        vm.prank(who);
        id = gate.submitSell(amount, "I keep the rest through every season; this is for rent.");
        OracleAttestation.Attestation memory a = _attest(score);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_KEY, gate.attestationDigest(a));
        bytes32 iid = gate.getPlea(id).intakeId;
        vm.prank(intake);
        gate.onOracleResult(iid, a, abi.encodePacked(r, s, v));
        approved = gate.getPlea(id).status == CabalGate.Status.Approved;
        if (approved && sell) {
            vm.prank(who);
            gate.executeSell(0);
        }
    }

    function _now() internal view returns (uint256) {
        return vm.getBlockTimestamp();
    }

    function _warpTo(uint256 t) internal {
        vm.warp(t);
        vm.roll(vm.getBlockNumber() + 1);
    }

    function test_fullSeasonLifecycle() public {
        uint256 t0 = gate.startedAt();
        uint256 S = gate.SEASON();
        console2.log("fork time", _now(), "season0 ends", t0 + S);
        (bool live, uint256 cur,) = seasons.currentSeason();
        assertTrue(live);
        uint256 s0 = cur;

        // ---- current season: volume + one approved plea each (one plea per wallet fits before it ends)
        for (uint256 i; i < w.length; ++i) {
            buy(w[i], 200e18);
        }
        uint256[] memory ids0 = new uint256[](w.length);
        for (uint256 i; i < w.length; ++i) {
            // scores 34..45; even wallets sell, odd wallets let the approval lapse
            (ids0[i],) = pleadAndAnswer(w[i], 34 + i, i % 2 == 0);
        }
        // a denied plea earns nothing
        // record half now, leave the rest for closeSeason's list
        uint256 approvedCount;
        for (uint256 i; i < w.length; ++i) {
            CabalGate.Plea memory pl = gate.getPlea(ids0[i]);
            console2.log("round0 need", pl.need, "score", pl.score);
            if (i < 6 && pl.score >= pl.need) {
                seasons.record(ids0[i]);
                ++approvedCount;
            }
        }
        for (uint256 i; i < w.length; ++i) {
            CabalGate.Plea memory pl = gate.getPlea(ids0[i]);
            if (pl.score < pl.need) {
                vm.expectRevert(); // a denied plea earns nothing
                seasons.record(ids0[i]);
                break;
            }
        }
        console2.log("recorded now", approvedCount);
        uint256 fees0 = seasons.seasonFees(s0);
        console2.log("season", s0, "fees so far", fees0);
        assertGt(fees0, 0);

        // ---- close the current season after its end + 1h grace (all below 60 points -> everything rolls over)
        (,, uint64 end0,) = seasons.seasonBounds(s0);
        _warpTo(end0 + 10 minutes);
        uint256[] memory rest = new uint256[](6);
        for (uint256 i; i < 6; ++i) {
            rest[i] = ids0[6 + i];
        }
        // close the earlier live season(s) first (season 0 holds the real plea #4 by wallet B)
        while (seasons.nextToClose() < s0) {
            uint256 lb = laureates.totalSupply();
            seasons.closeSeason(new uint256[](0));
            console2.log("closed earlier season; laureates minted", laureates.totalSupply() - lb);
        }
        vm.expectRevert(); // NotReady: grace not over
        seasons.closeSeason(rest);
        _warpTo(end0 + 1 hours + 1);
        seasons.closeSeason(rest);
        assertTrue(seasons.closed(s0));
        Seasons.Entry[10] memory top0 = seasons.topOf(s0);
        console2.log("s0 #1", top0[0].wallet, top0[0].points);
        assertEq(top0[0].points, 45); // best single score
        console2.log("rollover after s0", seasons.rollover());
        assertGt(seasons.rollover(), 0);
        // five laureates minted to the top five pleas' authors
        assertEq(laureates.balanceOf(w[11]), 1);
        console2.log("laureates total", laureates.totalSupply());

        // ---- next season: two approvals per wallet (4h apart) -> up to 90 points; pays out
        // first season that starts after every round-one cooldown, so two rounds 4h apart fit in 5h
        uint256 ready = _maxCooldownEnd(0);
        uint256 s1 = (ready - t0 + S - 1) / S;
        (, uint64 start1, uint64 end1,) = seasons.seasonBounds(s1);
        console2.log("two-round season", s1);
        // close the empty seasons in between (rolls over, nothing paid)
        _warpTo(start1 + 5 minutes);
        while (seasons.nextToClose() < s1) {
            seasons.closeSeason(new uint256[](0));
        }
        for (uint256 i; i < w.length; ++i) {
            buy(w[i], 100e18);
        }
        uint256[] memory ids1 = new uint256[](w.length * 2);
        for (uint256 i; i < w.length; ++i) {
            (ids1[i],) = pleadAndAnswer(w[i], 36 + (i % 10), true);
        }
        _warpTo(_now() + 4 hours + 5 minutes);
        require(_now() < end1, "second round must fit in the season");
        for (uint256 i; i < w.length; ++i) {
            (ids1[w.length + i],) = pleadAndAnswer(w[i], 45, true);
        }
        // names
        vm.prank(w[11]);
        laureates.setName("eleven");
        assertEq(laureates.nameOf(w[11]), "eleven");
        vm.prank(w[10]);
        vm.expectRevert();
        laureates.setName("eleven"); // taken
        vm.prank(w[10]);
        vm.expectRevert();
        laureates.setName("cabal"); // reserved

        _warpTo(end1 + 1 hours + 1);
        uint256 potIn = seasons.seasonFees(s1) + seasons.rollover();
        uint256[] memory bal = new uint256[](w.length);
        for (uint256 i; i < w.length; ++i) {
            bal[i] = imd.balanceOf(w[i]);
        }
        seasons.closeSeason(ids1);
        Seasons.Entry[10] memory top1 = seasons.topOf(s1);
        uint256 paid;
        for (uint256 i; i < 10; ++i) {
            if (top1[i].wallet == address(0)) break;
            uint256 idx = _idx(top1[i].wallet);
            uint256 got = imd.balanceOf(top1[i].wallet) - bal[idx];
            console2.log("s1 rank", i + 1, top1[i].points);
            console2.log("   paid", got);
            uint256[10] memory sh = [uint256(2500), 1800, 1400, 1100, 900, 700, 600, 400, 300, 300];
            if (top1[i].points >= 60) assertApproxEqAbs(got, potIn * sh[i] / 10_000, 1);
            else assertEq(got, 0);
            paid += got;
        }
        console2.log("s1 pot in", potIn, "paid", paid);
        console2.log("rollover after s1", seasons.rollover());
        assertEq(seasons.rollover(), potIn - paid);
        string memory uri = laureates.tokenURI(laureates.totalSupply());
        assertGt(bytes(uri).length, 500);

        // ---- the Cabal dies: 33h with no verdict; last season closes; leftovers flush to the wall
        _warpTo(gate.lastVerdictAt() + gate.DEADMAN() + 1);
        assertFalse(gate.cabalAlive());
        assertFalse(plea.restricted());
        vm.expectRevert();
        seasons.flushToWall(); // last season not closed yet
        _warpTo(_now() + 1 hours + 1);
        uint256 closes;
        while (true) {
            (bool exists,,,) = seasons.seasonBounds(seasons.nextToClose());
            if (!exists) break;
            seasons.closeSeason(new uint256[](0));
            ++closes;
        }
        console2.log("seasons closed after death", closes);
        assertTrue(seasons.finished());
        uint256 left = seasons.pot();
        uint256 wallBefore = hook.retainedImd();
        seasons.flushToWall();
        assertEq(seasons.pot(), 0);
        assertEq(hook.retainedImd(), wallBefore + left);
        console2.log("flushed to wall", left);
        // free trading after death: a plain sell through the router (no gate)
        PoolKey memory k3 = _key();
        vm.prank(w[3]);
        pst.swap(
            k3,
            SwapParams({zeroForOne: false, amountSpecified: -int256(1e18), sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1}),
            IPoolSwapTest.TestSettings(false, false),
            abi.encode(w[3])
        );
    }

    function _idx(address a) internal view returns (uint256) {
        for (uint256 i; i < w.length; ++i) {
            if (w[i] == a) return i;
        }
        revert("unknown");
    }

    /// All 4h cooldowns from the first round are over, and we are inside `start`'s season.
    function _maxCooldownEnd(uint256 start) internal view returns (uint256 t) {
        t = start;
        for (uint256 i; i < w.length; ++i) {
            uint256 a = gate.lastExecutedAt(w[i]) + 4 hours + 1;
            uint256 b = gate.lastLapsedAt(w[i]) + 4 hours + 1;
            if (a > t) t = a;
            if (b > t) t = b;
        }
    }
}
