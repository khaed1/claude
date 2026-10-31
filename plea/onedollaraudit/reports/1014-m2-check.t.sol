// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Scratch check for One Dollar Audit job 1014's M-2 (not committed): after the Cabal's death, an
// exact-output sell whose fee no longer fits an int128 is cast with int128(int256(fee)) in beforeSwap.
// Does the swap revert, or can anything move?
import {Fixture} from "./utils/Fixture.sol";
import {PleaIsZeroFixture, ImdIsZeroFixture} from "./Orientation.t.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

contract ScratchOdaM2Test is Fixture {
    function _try(string memory label, uint256 imdWanted) internal {
        uint160 limit = hook.pleaIsZero() ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1;
        uint256 aliceImd = imd.balanceOf(alice);
        uint256 alicePlea = plea.balanceOf(alice);
        uint256 hookImd = imd.balanceOf(address(hook));
        uint256 pmImd = imd.balanceOf(address(pm));
        uint256 burned = hook.totalBurned();
        vm.prank(alice);
        try router.sellExactOutLimit(imdWanted, abi.encode(alice), limit) returns (uint256 out) {
            emit log_named_string("SUCCEEDED (look closely)", label);
            emit log_named_uint("  imd out", out);
            emit log_named_int("  alice IMD change", int256(imd.balanceOf(alice)) - int256(aliceImd));
            emit log_named_int("  alice PLEA change", int256(plea.balanceOf(alice)) - int256(alicePlea));
            emit log_named_int("  hook IMD change", int256(imd.balanceOf(address(hook))) - int256(hookImd));
            emit log_named_int("  PoolManager IMD change", int256(imd.balanceOf(address(pm))) - int256(pmImd));
            emit log_named_uint("  burned", hook.totalBurned() - burned);
        } catch (bytes memory err) {
            bytes4 sel;
            if (err.length >= 4) sel = bytes4(err);
            emit log_named_string("reverted", label);
            emit log_named_bytes32("  selector", bytes32(sel));
            emit log_named_bytes("  data", err);
            assertEq(imd.balanceOf(alice), aliceImd);
            assertEq(plea.balanceOf(alice), alicePlea);
            assertEq(imd.balanceOf(address(hook)), hookImd);
        }
    }

    function test_hugeExactOutputSellsAfterTheDeath() public {
        buy(alice, 20_000e18);
        skip(DEADMAN + 1);
        assertFalse(plea.restricted(), "the Cabal should be dead");
        vm.prank(alice);
        plea.approve(address(router), type(uint256).max);
        uint256 rate = 175;
        uint256 i128max = uint256(uint128(type(int128).max));
        // fee = amount * rate / (10_000 - rate)
        _try("fee just over int128.max (wraps negative)", (i128max + 1) * (10_000 - rate) / rate + 1e30);
        _try("fee = 2^128 + 1e18 (wraps to +1e18)", ((uint256(1) << 128) + 1e18) * (10_000 - rate) / rate + 1);
        _try("fee = 2^129 + 5e18 (wraps to ~+5e18)", ((uint256(1) << 129) + 5e18) * (10_000 - rate) / rate + 1);
        _try("a normal large exact-output sell (control)", 100e18);
    }
}

contract ScratchOdaM2PleaIsZeroTest is PleaIsZeroFixture, ScratchOdaM2Test {
    function deployImd() internal override(Fixture, PleaIsZeroFixture) {
        PleaIsZeroFixture.deployImd();
    }
}

contract ScratchOdaM2ImdIsZeroTest is ImdIsZeroFixture, ScratchOdaM2Test {
    function deployImd() internal override(Fixture, ImdIsZeroFixture) {
        ImdIsZeroFixture.deployImd();
    }
}
