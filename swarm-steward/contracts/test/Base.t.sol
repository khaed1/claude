// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {LibString} from "solady/utils/LibString.sol";
import {OracleGovernor} from "../src/OracleGovernor.sol";
import {IOracleGovernor} from "../src/IOracleGovernor.sol";
import {OracleAttestation} from "../src/OracleAttestation.sol";
// PondPad, Docket's first client, used as is (read only).
import {GrowthFund} from "pondpad/GrowthFund.sol";
import {MarketController} from "pondpad/MarketController.sol";
import {PondPadToken} from "pondpad/PondPadToken.sol";
import {StakedPONDPAD} from "pondpad/StakedPONDPAD.sol";

/// @dev Stands in for IMD in local tests (the fork tests use the real IMD on Robinhood Chain).
contract MockIMD is ERC20 {
    function name() public pure override returns (string memory) {
        return "IMD";
    }

    function symbol() public pure override returns (string memory) {
        return "IMD";
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev The parts of PadMarketHook that MarketController.initialize and setCapDecay touch.
contract MockMarketHook {
    address public owner;
    address public quote;
    address public token;
    uint256 public capDecay;

    constructor(address owner_, address quote_, address token_) {
        owner = owner_;
        quote = quote_;
        token = token_;
    }

    function setCapDecay(uint256 tokensPerDay) external {
        require(msg.sender == owner, "owner");
        capDecay = tokensPerDay;
    }
}

/// @dev Minimal Safe for local tests: modules make calls, the test acts as the owners.
contract MockSafe {
    mapping(address => bool) public isModuleEnabled;

    function enableModule(address module) external {
        isModuleEnabled[module] = true;
    }

    function exec(address to, bytes calldata data) external returns (bytes memory) {
        (bool ok, bytes memory ret) = to.call(data);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
        return ret;
    }

    function execTransactionFromModuleReturnData(address to, uint256 value, bytes calldata data, uint8 operation)
        external
        returns (bool success, bytes memory returnData)
    {
        require(isModuleEnabled[msg.sender], "GS104");
        require(operation == 0, "call only");
        (success, returnData) = to.call{value: value}(data);
    }
}

/// @notice Shared setup: PondPad's GrowthFund and MarketController handed to a Docket module, with the two first
///         mandates (grants, cap decay). The values here are test fixtures from DESIGN.md §3.2, not decided settings.
abstract contract DocketBase is Test {
    using LibString for uint256;

    uint256 internal constant T0 = 1_900_000_000;
    uint256 internal constant ORACLE_KEY = 0xA11CE;
    string internal constant CHARTER = "ipfs://bafybeigdyrztdocketcharterv1pondpadexample";
    string internal constant EVIDENCE = "ipfs://bafybeievidenceforgrantproposalexample";

    address internal oracle;
    address internal guardian = makeAddr("guardian");
    address internal proposer = makeAddr("proposer");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    address internal safe;
    ERC20 internal imd;
    PondPadToken internal pondpad;
    StakedPONDPAD internal spondpad;
    GrowthFund internal growthFund;
    MarketController internal controller;
    MockMarketHook internal hook;
    OracleGovernor internal gov;

    uint32 internal grantMandate;
    uint32 internal decayMandate;

    // ------------------------------------------------------------------ Hooks for local vs fork

    function _deploySafe() internal virtual returns (address);
    function _deployImd() internal virtual returns (ERC20);
    function _giveImd(address to, uint256 amount) internal virtual;
    /// @dev Makes the Safe (its owners) call `to` with `data`.
    function _asSafe(address to, bytes memory data) internal virtual;

    function setUp() public virtual {
        vm.warp(T0);
        oracle = vm.addr(ORACLE_KEY);
        safe = _deploySafe();
        imd = _deployImd();

        pondpad = new PondPadToken(address(this));
        spondpad = new StakedPONDPAD(address(pondpad), address(this), 0);

        // GrowthFund: owner = PondPad's 48 h timelock (this test), granter = the Safe (launchpad D-47).
        growthFund = new GrowthFund(
            address(this), address(imd), address(pondpad), makeAddr("relay"), safe, 100e18, 1_000e18, 10_000_000e18
        );
        _giveImd(address(growthFund), 50_000e18);

        // MarketController: in PondPad its owner is the 48 h timelock; here the Safe owns it (see HANDOFF, open item).
        controller = new MarketController(
            safe, address(this), address(imd), address(pondpad), makeAddr("splitter"), makeAddr("burner"), 9_000e18, 3_000e18
        );
        hook = new MockMarketHook(address(controller), address(imd), address(pondpad));
        controller.initialize(address(hook), makeAddr("sale"));

        gov = new OracleGovernor(
            safe, guardian, address(imd), address(pondpad), "PondPad", CHARTER, oracle, 2 days, 3 days, 1_000
        );
        _asSafe(safe, abi.encodeWithSignature("enableModule(address)", address(gov)));

        _configure(abi.encodeCall(OracleGovernor.setVetoToken, (address(spondpad), IOracleGovernor.VetoKind.Vault)));
        (IOracleGovernor.Mandate memory gm, IOracleGovernor.ArgRule[] memory ga) = _grantMandate();
        _configure(abi.encodeCall(OracleGovernor.addMandate, (gm, ga)));
        grantMandate = 1;
        (IOracleGovernor.Mandate memory dm, IOracleGovernor.ArgRule[] memory da) = _decayMandate();
        _configure(abi.encodeCall(OracleGovernor.addMandate, (dm, da)));
        decayMandate = 2;

        _giveImd(proposer, 1_000e18);
        vm.prank(proposer);
        imd.approve(address(gov), type(uint256).max);
    }

    // ------------------------------------------------------------------ Mandates (fixtures)

    function _grantMandate() internal view returns (IOracleGovernor.Mandate memory m, IOracleGovernor.ArgRule[] memory a) {
        m = IOracleGovernor.Mandate({
            target: address(growthFund),
            signature: "grant(address,address,uint256,bytes32,string)",
            name: "growth grant",
            ruleRef: "section Grants",
            capArg: 2,
            capPerEpoch: 1_000e18,
            epochLength: 7 days,
            minInterval: 0,
            answerWindow: 7 days,
            delay: 3 days,
            executionWindow: 3 days,
            minPanel: 51,
            minAgreementBps: 6_667,
            vetoBps: 500,
            bond: 10e18
        });
        a = new IOracleGovernor.ArgRule[](5);
        a[0] = _rule(IOracleGovernor.ArgKind.Address, IOracleGovernor.Check.Equal, uint160(address(imd)), 0, "token");
        a[1] = _rule(IOracleGovernor.ArgKind.Address, IOracleGovernor.Check.Any, 0, 0, "to");
        a[2] = _rule(IOracleGovernor.ArgKind.Uint, IOracleGovernor.Check.Range, 1, 1_000e18, "amount_wei");
        a[3] = _rule(IOracleGovernor.ArgKind.ProposalId, IOracleGovernor.Check.Any, 0, 0, "ref");
        a[4] = _rule(IOracleGovernor.ArgKind.Evidence, IOracleGovernor.Check.Any, 0, 0, "reason");
    }

    function _decayMandate() internal view returns (IOracleGovernor.Mandate memory m, IOracleGovernor.ArgRule[] memory a) {
        m = IOracleGovernor.Mandate({
            target: address(controller),
            signature: "setCapDecay(uint256)",
            name: "market cap decay",
            ruleRef: "section Market settings",
            capArg: type(uint8).max,
            capPerEpoch: 0,
            epochLength: 0,
            minInterval: 30 days,
            answerWindow: 7 days,
            delay: 3 days,
            executionWindow: 3 days,
            minPanel: 51,
            minAgreementBps: 6_667,
            vetoBps: 500,
            bond: 10e18
        });
        a = new IOracleGovernor.ArgRule[](1);
        a[0] = _rule(IOracleGovernor.ArgKind.Uint, IOracleGovernor.Check.Range, 300_000e18, 700_000e18, "tokens_per_day_wei");
    }

    function _rule(IOracleGovernor.ArgKind k, IOracleGovernor.Check c, uint256 min, uint256 max, string memory label)
        internal
        pure
        returns (IOracleGovernor.ArgRule memory)
    {
        return IOracleGovernor.ArgRule({kind: k, check: c, min: min, max: max, label: label});
    }

    // ------------------------------------------------------------------ Helpers

    /// @dev Safe proposes a config change, the timelock passes, anyone executes.
    function _configure(bytes memory call) internal returns (uint256 id) {
        id = gov.actionCount() + 1;
        _asSafe(address(gov), abi.encodeCall(OracleGovernor.proposeConfig, (call)));
        vm.warp(gov.actionOf(id).executableAt);
        gov.execute(id);
    }

    function _proposeGrant(address to, uint256 amount) internal returns (uint256 id) {
        uint256[] memory w = new uint256[](5);
        w[0] = uint160(address(imd));
        w[1] = uint160(to);
        w[2] = amount;
        vm.prank(proposer);
        id = gov.propose(grantMandate, w, EVIDENCE);
    }

    /// @dev The oracle's canonical JSON, built independently of OracleAttestationLib.
    function _questionHash(string memory q, uint64 fromBlock, uint64 toBlock) internal pure returns (bytes32) {
        return keccak256(
            bytes(
                string.concat(
                    '{"answerType":"bool","chainId":4663,"evidence":"panel","question":"',
                    q,
                    '","v":1,"window":{"fromBlock":',
                    uint256(fromBlock).toString(),
                    ',"toBlock":',
                    uint256(toBlock).toString(),
                    "}}"
                )
            )
        );
    }

    uint256 private _nonce;

    function _att(uint256 id, bool yes) internal returns (OracleAttestation memory a) {
        a.requestId = keccak256(abi.encode("request", ++_nonce));
        a.chainId = 4663;
        a.fromBlock = 100;
        a.toBlock = 200;
        a.questionHash = _questionHash(gov.question(id), a.fromBlock, a.toBlock);
        a.answerType = 0;
        a.answer = abi.encode(yes ? uint256(1) : 0);
        a.panelJobId = keccak256(abi.encode("panel", _nonce));
        a.panelSize = 51;
        a.quorum = 34;
        a.agreed = 40;
        a.issuedAt = uint64(block.timestamp);
        a.expiresAt = uint64(block.timestamp + 1 days);
    }

    function _sign(OracleAttestation memory a, uint256 key) internal view returns (bytes memory) {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("IdentityMD Oracle"),
                keccak256("2"),
                block.chainid,
                address(gov)
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domain, _structHash(a)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _structHash(OracleAttestation memory a) internal pure returns (bytes32) {
        return keccak256(
            bytes.concat(
                abi.encode(
                    keccak256(
                        "OracleAttestation(bytes32 requestId,uint256 chainId,bytes32 questionHash,uint8 answerType,bytes answer,uint256 figure,uint64 fromBlock,uint64 toBlock,bytes32 blockHash,bytes32 panelJobId,uint16 panelSize,uint16 quorum,uint16 agreed,uint64 issuedAt,uint64 expiresAt)"
                    ),
                    a.requestId,
                    a.chainId,
                    a.questionHash,
                    a.answerType,
                    keccak256(a.answer),
                    a.figure,
                    a.fromBlock,
                    a.toBlock
                ),
                abi.encode(a.blockHash, a.panelJobId, a.panelSize, a.quorum, a.agreed, a.issuedAt, a.expiresAt)
            )
        );
    }

    function _answer(uint256 id, bool yes) internal {
        OracleAttestation memory a = _att(id, yes);
        gov.submitAnswer(id, a, _sign(a, ORACLE_KEY));
    }
}
