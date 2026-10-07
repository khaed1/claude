// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {PondPadToken} from "../src/PondPadToken.sol";
import {StakedPONDPAD} from "../src/StakedPONDPAD.sol";
import {RewardDripper} from "../src/RewardDripper.sol";

/// @dev Random stakes (`deposit` / `mint`), exits (`withdraw` / `redeem`), share moves (`transfer` / `transferFrom`),
///      attempts to park shares at address(0) or the vault, reward inflows, drips, and time and block steps on sPONDPAD
///      and its dripper. Keeps its own clock and block count (via-IR re-reads `block.*` after cheatcodes).
contract StakingHandler is CommonBase, StdUtils {
    PondPadToken internal immutable token;
    StakedPONDPAD internal immutable vault;
    RewardDripper internal immutable dripper;
    address[] internal actors;
    uint256 internal time;
    uint256 internal blockNumber;

    /// @notice Set when a drip released more than 1/7 of the buffer, other than sweeping a remainder under one $PONDPAD.
    bool public dripTooLarge;
    uint256 public drips;

    constructor(PondPadToken token_, StakedPONDPAD vault_, RewardDripper dripper_, address[] memory actors_) {
        token = token_;
        vault = vault_;
        dripper = dripper_;
        actors = actors_;
        time = block.timestamp;
        blockNumber = block.number;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function deposit(uint256 seed, uint256 amount) external {
        address a = _actor(seed);
        uint256 bal = token.balanceOf(a);
        if (bal == 0) return;
        amount = bound(amount, 1, bal);
        vm.prank(a);
        try vault.deposit(amount, _actor(seed >> 8)) {} catch {}
    }

    function mint(uint256 seed, uint256 shares) external {
        address a = _actor(seed);
        shares = bound(shares, 1, 1_000_000e24);
        vm.prank(a);
        try vault.mint(shares, a) {} catch {}
    }

    function withdraw(uint256 seed, uint256 percent) external {
        address a = _actor(seed);
        uint256 assets = (vault.maxWithdraw(a) * bound(percent, 1, 100)) / 100;
        if (assets == 0) return;
        vm.prank(a);
        try vault.withdraw(assets, a, a) {} catch {}
    }

    function redeem(uint256 seed, uint256 percent) external {
        address a = _actor(seed);
        uint256 shares = (vault.maxRedeem(a) * bound(percent, 1, 100)) / 100;
        if (shares == 0) return;
        vm.prank(a);
        try vault.redeem(shares, a, a) {} catch {}
    }

    function transfer(uint256 seed, uint256 percent) external {
        address from = _actor(seed);
        uint256 amount = (vault.balanceOf(from) * bound(percent, 1, 100)) / 100;
        vm.prank(from);
        try vault.transfer(_actor(seed >> 8), amount) {} catch {}
    }

    function transferFrom(uint256 seed, uint256 percent) external {
        address from = _actor(seed);
        address spender = _actor(seed >> 8);
        uint256 amount = (vault.balanceOf(from) * bound(percent, 1, 100)) / 100;
        vm.prank(from);
        vault.approve(spender, amount);
        vm.prank(spender);
        try vault.transferFrom(from, _actor(seed >> 16), amount) {} catch {}
    }

    /// @dev Tries to park shares where nobody can redeem them (refused since audit R4-A3-1).
    function parkShares(uint256 seed, uint256 amount, bool atVault) external {
        address a = _actor(seed);
        address to = atVault ? address(vault) : address(0);
        uint256 bal = token.balanceOf(a);
        if (bal != 0) {
            vm.prank(a);
            try vault.deposit(bound(amount, 1, bal), to) {} catch {}
        }
        uint256 shares = vault.balanceOf(a);
        if (shares != 0) {
            vm.prank(a);
            try vault.transfer(to, bound(amount, 1, shares)) {} catch {}
        }
    }

    function addRewards(uint256 amount) external {
        amount = bound(amount, 0, 1_000_000e18);
        if (amount > token.balanceOf(address(this))) return;
        token.transfer(address(dripper), amount);
    }

    /// @dev Moves time on (at least an hour, so a drip is usually due), then drips.
    function drip(uint256 secs) external {
        time += bound(secs, 1 hours, 2 days);
        blockNumber += 1;
        vm.warp(time);
        vm.roll(blockNumber);
        uint256 buffer = token.balanceOf(address(dripper));
        try dripper.drip() returns (uint256 toVault, uint256 tip) {
            drips++;
            uint256 released = toVault + tip;
            bool sweep = released == buffer && buffer - buffer / 7 < 1e18; // a remainder under one $PONDPAD
            if (released > buffer / 7 && !sweep) dripTooLarge = true;
        } catch {}
    }

    function step(uint256 secs, uint256 blocks) external {
        time += bound(secs, 0, 2 days);
        blockNumber += bound(blocks, 0, 3);
        vm.warp(time);
        vm.roll(blockNumber);
    }
}

/// @dev Audit R4-A3-9: stateful invariants of the staking vault and its dripper (THREAT-MODEL invariants 13 and 14)
///      under random interleavings across blocks: the vault never counts more than it holds and never owes more than
///      it counts, no shares sit where nobody can redeem them, a held share never exceeds its holder's balance, one
///      drip releases at most 1/7 of the buffer (bar the final dust sweep), and nothing drips while the vault is closed.
/// forge-config: default.invariant.runs = 48
/// forge-config: default.invariant.depth = 40
contract StakingInvariantTest is Test {
    PondPadToken internal token;
    StakedPONDPAD internal vault;
    RewardDripper internal dripper;
    StakingHandler internal handler;
    address[] internal actors;

    function setUp() public {
        vm.warp(1_000_000);
        token = new PondPadToken(address(this));
        address owner = makeAddr("timelock");
        uint256 expiry = block.timestamp + 365 days;
        vault = new StakedPONDPAD(address(token), owner, expiry);
        dripper = new RewardDripper(address(token), address(vault), owner, 7 days, 1 days, 10e18, 1_000e18, expiry);
        actors.push(makeAddr("stakerA"));
        actors.push(makeAddr("stakerB"));
        actors.push(makeAddr("stakerC"));
        for (uint256 i; i < actors.length; i++) {
            token.transfer(actors[i], 10_000_000e18);
            vm.prank(actors[i]);
            token.approve(address(vault), type(uint256).max);
        }
        handler = new StakingHandler(token, vault, dripper, actors);
        token.transfer(address(handler), 300_000_000e18); // reward inflows
        // Start open with a buffer, so drips happen from the first calls on.
        vm.prank(actors[0]);
        vault.deposit(1_000_000e18, actors[0]);
        token.transfer(address(dripper), 1_000_000e18);
        targetContract(address(handler));
    }

    /// @dev How many drips the run made (logged with `-vv`; a drip action moves time at least an hour first, so most
    ///      drip calls release).
    function afterInvariant() public view {
        console2.log("drips", handler.drips());
    }

    function invariant_vaultAndDripperBooks() public view {
        uint256 shares;
        uint256 redeemable;
        for (uint256 i; i < actors.length; i++) {
            address a = actors[i];
            uint256 bal = vault.balanceOf(a);
            shares += bal;
            redeemable += vault.convertToAssets(bal);
            if (vault.lastDepositBlock(a) == block.number) assertLe(vault.heldShares(a), bal, "held within the balance");
        }
        assertEq(vault.balanceOf(address(0)) + vault.balanceOf(address(vault)), 0, "no unredeemable shares");
        assertEq(shares, vault.totalSupply(), "every share is a staker's");
        assertLe(vault.trackedAssets(), token.balanceOf(address(vault)), "counts no more than it holds");
        assertLe(redeemable, vault.totalAssets(), "owes no more than it counts");
        assertFalse(handler.dripTooLarge(), "one drip <= 1/7 of the buffer");
        if (vault.rewardsOpenSince() == 0) assertEq(dripper.drippable(), 0, "closed: nothing drips");
    }
}
