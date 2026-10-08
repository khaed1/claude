// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {PondPadToken} from "../src/PondPadToken.sol";
import {PadHook} from "../src/PadHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

contract DeployCreate2Harness is Deploy {
    function create2Above(bytes memory initCode, address floor) external returns (address) {
        return _create2Above(initCode, floor);
    }

    function create2Hook(bytes memory initCode, uint160 flags) external returns (address) {
        return _create2Hook(initCode, flags);
    }

    function padHookFlags() external pure returns (uint160) {
        return PAD_HOOK_FLAGS;
    }
}

/// @dev Audit R1-A4-14: anyone can submit the script's $PONDPAD init code and salt to the public CREATE2 deployer
///      first. The script must then use the token already there instead of reverting on every re-run.
contract DeployCreate2Test is Test {
    function test_deploy_usesTokenPreDeployedAtItsSalt() public {
        DeployCreate2Harness h = new DeployCreate2Harness();
        address deployer = makeAddr("deployer");
        bytes memory initCode = abi.encodePacked(type(PondPadToken).creationCode, abi.encode(deployer));
        address floor = address(0x1000);
        uint256 i;
        while (h.create2Address(bytes32(i), keccak256(initCode)) <= floor) ++i;
        address expected = h.create2Address(bytes32(i), keccak256(initCode));

        vm.prank(makeAddr("frontRunner"));
        (bool ok,) = CREATE2_FACTORY.call(abi.encodePacked(bytes32(i), initCode));
        assertTrue(ok);
        assertGt(expected.code.length, 0);

        address got = h.create2Above(initCode, floor);
        assertEq(got, expected);
        assertEq(PondPadToken(got).balanceOf(deployer), PondPadToken(got).totalSupply(), "supply is the deployer's");
    }

    /// @dev Audit R3-A4-16 (coverage): the same holds for a hook pre-deployed at its mined salt. The init code names the
    ///      deployer, so only the deployer can initialize the hook found there.
    function test_deploy_usesHookPreDeployedAtItsSalt() public {
        DeployCreate2Harness h = new DeployCreate2Harness();
        bytes memory initCode = abi.encodePacked(
            type(PadHook).creationCode,
            abi.encode(
                IPoolManager(address(0x1001)), address(0x1002), address(0x1003), address(0x1004), address(0x1005),
                address(0x1006), address(h)
            )
        );
        uint160 flags = h.padHookFlags();
        (bytes32 salt, address expected) = h.mineHookSalt(keccak256(initCode), flags);
        vm.prank(makeAddr("frontRunner"));
        (bool ok,) = CREATE2_FACTORY.call(abi.encodePacked(salt, initCode));
        assertTrue(ok);
        assertEq(h.create2Hook(initCode, flags), expected);
        vm.prank(makeAddr("frontRunner"));
        vm.expectRevert(PadHook.Unauthorized.selector);
        PadHook(expected).initialize(address(0x2001), address(0x2002));
        vm.prank(address(h));
        PadHook(expected).initialize(address(0x2001), address(0x2002));
        assertEq(PadHook(expected).router(), address(0x2002));
    }
}

/// @dev Audits R2-A3-7 / R3-A3-3 / R3-A4-13: the deploy takes the airdrop root from the snapshot tool's claims.json only
///      if the listed amounts add up to its total, the total fits the 50M the distributor is funded with, and the root
///      is exactly the tree of the listed claims (rebuilt as `airdrop/snapshot.py` builds it).
contract DeployAirdropListTest is Test {
    function _leaf(address a, uint256 amount) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(a, amount))));
    }

    function _pair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
    }

    function _claim(address a, uint256 amount) internal pure returns (string memory) {
        return string.concat('"', vm.toString(a), '":{"amount":"', vm.toString(amount), '","proof":[]}');
    }

    function _json(bytes32 root, uint256 total, string memory claims) internal pure returns (string memory) {
        return string.concat(
            '{"root":"', vm.toString(root), '","total":"', vm.toString(total), '","claims":{', claims, "}}"
        );
    }

    /// @dev The 7-claim tree `snapshot.py selftest` built (fixture): the script rebuilds the same root.
    function _fixture() internal view returns (bytes32 root, uint256 total, string memory claims, bytes32[] memory leaves) {
        string memory f = vm.readFile("test/fixtures/airdrop-tree.json");
        root = vm.parseJsonBytes32(f, ".root");
        address[] memory accounts = vm.parseJsonAddressArray(f, ".accounts");
        string[] memory amounts = vm.parseJsonStringArray(f, ".amounts");
        leaves = new bytes32[](accounts.length);
        for (uint256 i; i < accounts.length; ++i) {
            uint256 amount = vm.parseUint(amounts[i]);
            total += amount;
            claims = string.concat(claims, i == 0 ? "" : ",", _claim(accounts[i], amount));
            leaves[i] = _leaf(accounts[i], amount);
        }
    }

    /// @dev `n` wallets with `amount` each, and the root the script must rebuild for them.
    function _list(Deploy d, uint256 n, uint256 amount) internal pure returns (bytes32 root, string memory claims) {
        bytes32[] memory leaves = new bytes32[](n);
        for (uint256 i; i < n; ++i) {
            address w = address(uint160(0x5000 + i));
            leaves[i] = _leaf(w, amount);
            claims = string.concat(claims, i == 0 ? "" : ",", _claim(w, amount));
        }
        root = d.standardMerkleRoot(leaves);
    }

    function test_deploy_airdropRootMustMatchTheClaims() public {
        Deploy d = new Deploy();
        (bytes32 root, uint256 total, string memory claims, bytes32[] memory leaves) = _fixture();
        assertEq(d.standardMerkleRoot(leaves), root, "the Python tree, rebuilt");

        vm.expectRevert(bytes("airdrop total doesn't match the claims"));
        d.airdropRootFromClaims(_json(root, total - 1, claims));

        // A root that commits to 60M (two leaves) handed over with only one of its claims listed.
        address a = address(0xA11CE);
        address b = address(0xB0B);
        bytes32 root60 = _pair(_leaf(a, 40_000_000e18), _leaf(b, 20_000_000e18));
        vm.expectRevert(bytes("airdrop root doesn't match the claims"));
        d.airdropRootFromClaims(_json(root60, 40_000_000e18, _claim(a, 40_000_000e18)));

        // The same 60M list in full: consistent, but more than the airdrop holds.
        string memory both = string.concat(_claim(a, 40_000_000e18), ",", _claim(b, 20_000_000e18));
        vm.expectRevert(bytes("airdrop list exceeds 50M"));
        d.airdropRootFromClaims(_json(root60, 60_000_000e18, both));

        // 50M exactly is fine (with at least 100 wallets, R4-A3-4).
        (bytes32 root50, string memory fifty) = _list(d, 100, 500_000e18);
        assertEq(d.airdropRootFromClaims(_json(root50, 50_000_000e18, fifty)), root50);
    }

    /// @dev Audit R4-A3-4: a list shorter than the 100 initiators the distributor needs could never activate nor be
    ///      swept, so the 50M would be locked for ever: the deploy refuses it, the Python fixture's 7 claims included.
    function test_deploy_airdropListNeedsAHundredWallets() public {
        Deploy d = new Deploy();
        address a = address(0xA11CE);
        address b = address(0xB0B);
        bytes32 root2 = _pair(_leaf(a, 30_000_000e18), _leaf(b, 20_000_000e18));
        string memory two = string.concat(_claim(a, 30_000_000e18), ",", _claim(b, 20_000_000e18));
        vm.expectRevert(bytes("airdrop list below 100 wallets"));
        d.airdropRootFromClaims(_json(root2, 50_000_000e18, two));
        (bytes32 root7, uint256 total7, string memory seven,) = _fixture();
        vm.expectRevert(bytes("airdrop list below 100 wallets"));
        d.airdropRootFromClaims(_json(root7, total7, seven));
        (bytes32 root99, string memory list99) = _list(d, 99, 500_000e18);
        vm.expectRevert(bytes("airdrop list below 100 wallets"));
        d.airdropRootFromClaims(_json(root99, 99 * 500_000e18, list99));
        (bytes32 root100, string memory list100) = _list(d, 100, 400_000e18);
        assertEq(d.airdropRootFromClaims(_json(root100, 40_000_000e18, list100)), root100);
    }

    /// @dev P5-3 (check before round 5, R4-A3-4 fix incomplete): the 100 counts distinct, non-zero wallets, not the
    ///      file's keys. Both fixtures (`test/fixtures/make_airdrop_lists.py`, built with `airdrop/snapshot.py`'s own
    ///      `build_tree`) list 100 keys whose amounts add up to the total and rebuild the root, but only 99 wallets that
    ///      can initiate: one wallet in lowercase and in uppercase (two keys, two leaves, one `initiated` slot), or 99
    ///      wallets and address 0. Either would have locked the 50M as in R4-A3-4.
    function test_deploy_airdropListCountsWalletsNotKeys() public {
        Deploy d = new Deploy();
        string memory repeated = vm.readFile("test/fixtures/airdrop-repeated-wallet.json");
        assertEq(vm.parseJsonKeys(repeated, ".claims").length, 100, "100 keys");
        vm.expectRevert(bytes("airdrop list repeats a wallet"));
        d.airdropRootFromClaims(repeated);

        string memory zero = vm.readFile("test/fixtures/airdrop-zero-wallet.json");
        assertEq(vm.parseJsonKeys(zero, ".claims").length, 100, "100 keys");
        vm.expectRevert(bytes("airdrop list names address 0"));
        d.airdropRootFromClaims(zero);
    }
}
