// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "solady/tokens/ERC20.sol";
import {GovernorTests} from "./Governor.t.sol";

interface ISafeProxyFactory {
    function createProxyWithNonce(address singleton, bytes memory initializer, uint256 saltNonce)
        external
        returns (address proxy);
}

interface ISafeFull {
    function setup(
        address[] calldata owners,
        uint256 threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    ) external;

    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) external payable returns (bool);

    function isModuleEnabled(address module) external view returns (bool);
    function getOwners() external view returns (address[] memory);
}

/// @notice The whole OracleGovernor suite on a Robinhood Chain fork, with a real Safe v1.4.1 (canonical factory and
///         L2 singleton, deployed on chain 4663) and the real IMD token. Run with
///         `FORK_RPC=https://rpc.mainnet.chain.robinhood.com forge test --match-contract Fork`.
contract ForkOracleGovernorTest is GovernorTests {
    address internal constant SAFE_FACTORY = 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67;
    address internal constant SAFE_L2_SINGLETON = 0x29fcB43b46531BcA003ddC8FCB67FFE91900C762;
    address internal constant SAFE_FALLBACK = 0xfd0732Dc9E303f09fCEf3a7388Ad10A83459Ec99;
    address internal constant IMD = 0x5F7Bb59365ce557C26dbcAa4EE9d39A4b95B7127;

    address internal owner = makeAddr("safeOwner");

    function setUp() public override {
        string memory rpc = vm.envOr("FORK_RPC", string(""));
        if (bytes(rpc).length == 0) vm.skip(true);
        vm.createSelectFork(rpc);
        assertEq(block.chainid, 4663);
        super.setUp();
    }

    function _deploySafe() internal override returns (address) {
        address[] memory owners = new address[](1);
        owners[0] = owner;
        bytes memory init = abi.encodeCall(
            ISafeFull.setup, (owners, 1, address(0), "", SAFE_FALLBACK, address(0), 0, payable(address(0)))
        );
        return ISafeProxyFactory(SAFE_FACTORY).createProxyWithNonce(SAFE_L2_SINGLETON, init, 42);
    }

    function _deployImd() internal pure override returns (ERC20) {
        return ERC20(IMD);
    }

    function _giveImd(address to, uint256 amount) internal override {
        deal(IMD, to, ERC20(IMD).balanceOf(to) + amount);
    }

    /// @dev Enabling the module goes through the owners' real `execTransaction`. Other Safe calls are made as the
    ///      Safe directly, so a revert surfaces with its own error instead of the Safe's "GS013".
    function _asSafe(address to, bytes memory data) internal override {
        if (to == safe) {
            bytes memory sig = abi.encodePacked(uint256(uint160(owner)), uint256(0), uint8(1)); // pre-approved: sender is owner
            vm.prank(owner);
            bool ok = ISafeFull(safe).execTransaction(to, 0, data, 0, 0, 0, 0, address(0), payable(address(0)), sig);
            assertTrue(ok);
            return;
        }
        vm.prank(safe);
        (bool success, bytes memory ret) = to.call(data);
        if (!success) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }

    function test_fork_realSafeEnabledTheModule() public view {
        assertTrue(ISafeFull(safe).isModuleEnabled(address(gov)));
        assertEq(ISafeFull(safe).getOwners()[0], owner);
        assertEq(growthFund.granter(), safe);
    }

    /// @dev The grant is paid through the real Safe's module path (`execTransactionFromModuleReturnData`).
    function test_fork_grantPaysRealImdThroughSafe() public {
        uint256 id = _proposeGrant(alice, 250e18);
        _answer(id, true);
        vm.warp(gov.actionOf(id).executableAt);
        uint256 fundBefore = imd.balanceOf(address(growthFund));
        gov.execute(id);
        assertEq(imd.balanceOf(alice), 250e18);
        assertEq(imd.balanceOf(address(growthFund)), fundBefore - 250e18);
    }

    /// @dev If the Safe's owners disable the module, nothing executes any more.
    function test_fork_ownersCanSwitchOffTheModule() public {
        uint256 id = _proposeGrant(alice, 1e18);
        _answer(id, true);
        // Safe v1.4.1 keeps modules in a linked list; the sentinel 0x1 is the previous entry of the only module.
        _asSafe(safe, abi.encodeWithSignature("disableModule(address,address)", address(1), address(gov)));
        vm.warp(gov.actionOf(id).executableAt);
        vm.expectRevert();
        gov.execute(id);
    }
}
