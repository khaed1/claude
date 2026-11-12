// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Measures PLEA's five-contract launch through IMD's real mainnet ProjectFactory on a fork.
// Not part of khaed1/plea. Use from a scratch forge project (forge-std only, so it compiles in
// seconds) whose foundry.toml grants read access to a built PLEA checkout's out/ directory:
//   fs_permissions = [{ access = "read", path = "/home/user/plea-mainnet/out" }]
//   [PLEA_OUT=/path/to/out] MAINNET_RPC_URL=https://ethereum-rpc.publicnode.com forge test --match-path test/FactoryGas.t.sol -vvvv
// Read the factory frame's gas from the -vvvv trace ("[n] 0xfF03...::launchContracts"): the
// gasleft() difference in this test also counts this test's own memory and moves by ~0.8M with
// unrelated test code. Real tx gas = 21,000 + tx data gas + frame gas. Cross-check with
// eth_estimateGas (from the deployer, to the factory, this calldata).
// 2026-10-12, mainnet @ ddc4d79: frame 11,431,882, data 1,122,988, total 12,575,870;
// eth_estimateGas 11,513,828; LaunchManifest's stand-in factory 11,581,323 (overhead 994,547).
import {Test} from "forge-std/Test.sol";

struct Meta {
    bytes32 kind; // "evm_contracts"
    uint64 launchId; // must equal Params.id (else InvalidProject)
    uint64 c;
    bytes32 commit; // 20-byte commit, left aligned
    bytes32 e;
    bytes32 f;
    bytes32 g;
    string repo;
}

struct Params {
    uint64 id;
    bytes[] codes;
    bytes32[] names;
    address[] expected; // CREATE2 by the factory, salt keccak256(abi.encode(id, index))
    Meta meta;
    uint256[] extra;
}

interface IFactory {
    function launchContracts(Params calldata p) external; // 0x99674075
}

contract FactoryGasTest is Test {
    address constant FACTORY = 0xfF03410d0Fe5fa8f7F59F743de35E333D9857120;
    address constant DEPLOYER = 0xcECc29B037f5064fCdF45a5C318F132ef76aA551;
    address constant INTAKE = 0xa43e6F75ee006411F79Ac1C84120606C2330DE82;
    address constant IMD = 0xD34a99Bc0f67aE1bbd63C660e6d0b0dd03E263B7;
    address constant SIGNER = 0x5598Aa9146215Bc13eb26f2c692Ad1461Fd32982;
    address constant POOL_MANAGER = 0x000000000004444c5dc75cB358380D2e3dE08A90;
    address constant STACKER = address(0x5743C3E7); // placeholder until the mainnet Stacker exists
    uint64 constant ID = 4_000_000_001; // any id the registry has not recorded

    bytes[] codes;
    address[] expected;

    function _code(string memory name) internal view returns (bytes memory) {
        string memory out = vm.envOr("PLEA_OUT", string("/home/user/plea-mainnet/out"));
        return vm.parseJsonBytes(vm.readFile(string.concat(out, "/", name, ".sol/", name, ".json")), ".bytecode.object");
    }

    function _add(bytes memory code) internal {
        bytes32 salt = keccak256(abi.encode(uint256(ID), codes.length));
        codes.push(code);
        expected.push(
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), FACTORY, salt, keccak256(code))))))
        );
    }

    function test_launchThroughTheRealFactory() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        address owner = makeAddr("owner");
        _add(bytes.concat(_code("PLEA"), abi.encode(owner)));
        _add(bytes.concat(_code("CabalGate"), abi.encode(expected[0], INTAKE, IMD, IMD, SIGNER, 15 days, uint256(118800))));
        _add(bytes.concat(_code("Seasons"), abi.encode(expected[0], expected[1], IMD)));
        _add(bytes.concat(_code("PleaDistributor"), abi.encode(expected[0], owner)));
        _add(
            bytes.concat(
                _code("PleaLaunch"),
                abi.encode(
                    expected[0], expected[1], expected[2], expected[3], POOL_MANAGER, IMD, STACKER,
                    uint256(400_000), uint256(1791817200), IMD, false, keccak256(_code("Letterbox"))
                )
            )
        );
        bytes32[] memory names = new bytes32[](5);
        names[0] = "PLEA";
        names[1] = "CabalGate";
        names[2] = "Seasons";
        names[3] = "PleaDistributor";
        names[4] = "PleaLaunch";
        // Metadata shaped like run 2's real call (launch #1311 on Sepolia).
        Meta memory meta = Meta(
            "evm_contracts",
            ID,
            0,
            bytes32(bytes20(hex"fb8c0ae57aab2c270b36a61720a2f567e5183e5f")),
            0xba283e5d804478ffb31eb13bf7ae4b1f07f89018342c702c8933087f12a80e69,
            0x4eeaed6a03bb2acf00fda2b7fedbcce0c57bf770d25622782c2ef3f1722bfcc7,
            0x68249df1f422fa72f61ca7f0ddaf9b62043959c5c134498441d5e552a9921782,
            "https://github.com/identity-md-launches/launch-1311-launch-plea-test-run"
        );
        uint256[] memory extra = new uint256[](14);
        uint256[14] memory x = [
            uint256(50958), 51041, 51071, 51227, 51317, 51318, 51474, 51507, 51728, 52124, 52180, 52267, 52586, 52591
        ];
        for (uint256 i; i < 14; ++i) extra[i] = x[i];
        bytes memory data = abi.encodeCall(IFactory.launchContracts, (Params(ID, codes, names, expected, meta, extra)));
        uint256 dataGas;
        for (uint256 i; i < data.length; ++i) dataGas += data[i] == 0 ? 4 : 16;
        emit log_named_uint("tx data gas", dataGas);
        vm.prank(DEPLOYER, DEPLOYER);
        (bool ok, bytes memory ret) = FACTORY.call(data);
        if (!ok) emit log_named_bytes("revert", ret);
        assertTrue(ok, "factory call failed");
        for (uint256 i; i < 5; ++i) assertGt(expected[i].code.length, 0);
    }
}
