// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {MerkleProofLib} from "solady/utils/MerkleProofLib.sol";

/// @notice The tree built by `launchpad/airdrop/snapshot.py` (fixture from `snapshot.py selftest --fixture`)
///         verifies with the leaf and proof format `AirdropDistributor` uses.
contract AirdropTreeTest is Test {
    function test_airdropTree_pythonTreeMatchesContractFormat() public view {
        string memory json = vm.readFile("test/fixtures/airdrop-tree.json");
        bytes32 root = vm.parseJsonBytes32(json, ".root");
        address[] memory accounts = vm.parseJsonAddressArray(json, ".accounts");
        string[] memory amounts = vm.parseJsonStringArray(json, ".amounts");
        assertEq(accounts.length, 7);
        for (uint256 i; i < accounts.length; ++i) {
            uint256 amount = vm.parseUint(amounts[i]);
            bytes32[] memory proof = vm.parseJsonBytes32Array(json, string.concat(".proofs[", vm.toString(i), "]"));
            // Same leaf as AirdropDistributor._verifyLeaf.
            bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(accounts[i], amount))));
            assertTrue(MerkleProofLib.verify(proof, root, leaf));
            bytes32 wrong = keccak256(bytes.concat(keccak256(abi.encode(accounts[i], amount + 1))));
            assertFalse(MerkleProofLib.verify(proof, root, wrong));
        }
    }
}
