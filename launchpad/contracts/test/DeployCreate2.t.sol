// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {PondPadToken} from "../src/PondPadToken.sol";

contract DeployCreate2Harness is Deploy {
    function create2Above(bytes memory initCode, address floor) external returns (address) {
        return _create2Above(initCode, floor);
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
}
