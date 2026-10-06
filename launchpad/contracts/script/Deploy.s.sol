// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PadConfig} from "../src/PadConfig.sol";
import {BondingCurve} from "../src/BondingCurve.sol";
import {PadHook} from "../src/PadHook.sol";
import {PadFactory} from "../src/PadFactory.sol";
import {PadRouter} from "../src/PadRouter.sol";
import {PadLens} from "../src/PadLens.sol";
import {CreatorVault} from "../src/CreatorVault.sol";
import {SwarmBudget} from "../src/SwarmBudget.sol";
import {FeeSplitter} from "../src/FeeSplitter.sol";
import {IntegratorVault} from "../src/IntegratorVault.sol";
import {Hop} from "../src/Route.sol";
import {PondPadToken} from "../src/PondPadToken.sol";
import {PadSale} from "../src/PadSale.sol";
import {PadBurner} from "../src/PadBurner.sol";
import {PadMarketHook} from "../src/PadMarketHook.sol";
import {MarketController} from "../src/MarketController.sol";
import {StakedPONDPAD} from "../src/StakedPONDPAD.sol";
import {RewardDripper} from "../src/RewardDripper.sol";
import {PadBuyer} from "../src/PadBuyer.sol";
import {WorkerFund} from "../src/WorkerFund.sol";
import {GrowthFund} from "../src/GrowthFund.sol";
import {AttestationVerifier} from "../src/AttestationVerifier.sol";
import {SocialRegistry} from "../src/SocialRegistry.sol";
import {CTOModule} from "../src/CTOModule.sol";
import {VersionRegistry} from "../src/VersionRegistry.sol";
import {AirdropDistributor} from "../src/AirdropDistributor.sol";
import {TeamVesting} from "../src/TeamVesting.sol";
import {LiquidityReserve} from "../src/LiquidityReserve.sol";

/// @notice Deploys and wires all of PondPad v1 on Robinhood Chain in one run, then hands every owner power to the
///         timelocks (D-6, HANDOFF §5). Numbers come from DECISIONS.md; addresses and links from the environment.
///
///   forge script script/Deploy.s.sol --rpc-url robinhood --broadcast --sender <deployer> [--account|--private-key …]
///
/// Required env: SAFE (team Safe: timelock proposer, council, granter, guardian, treasury, team vesting),
/// RELAY (Swarm Relay wallet), X_LINK_KEY (X link service key), TWEET_CHECKER (airdrop tweet checker key),
/// AIRDROP_CLAIMS (claims.json from airdrop/snapshot.py build; test chains may give AIRDROP_ROOT instead), SALE_START,
/// CTO_RULES (ipfs://… link). Optional: WORKER_REWARDS (default: not set yet),
/// AUDIT_LINK (activates version 1 at deploy), POWERS_EXPIRE_AT (staking powers; default SALE_START + 365 days).
///
/// On Robinhood Chain (4663) the chain addresses and the 48 h / 7-day delays are the constants below and cannot be
/// overridden. On any other chain (the Robinhood testnet, 46630) they come from `deployments/<chainId>-setup.json`,
/// written by `testnet/TestnetSetup.s.sol`, and the delays from FAST_DELAY / SLOW_DELAY (default 10 / 30 minutes).
///
/// The deployer only holds powers during the run: the 48 h and 7-day timelocks (proposer: the Safe, executor:
/// anyone) own everything at the end, and the deployer keeps no $PONDPAD.
contract Deploy is Script {
    // ------------------------------------------------------------------ Robinhood Chain (4663)
    address internal constant PM = 0x8366a39CC670B4001A1121B8F6A443A643e40951;
    address internal constant IMD = 0x5F7Bb59365ce557C26dbcAa4EE9d39A4b95B7127;
    address internal constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    address internal constant ETH_USDG_HOOK = 0x06a889870C8f83640D6816319f72e2aA579b6080;
    // CREATE2_FACTORY (forge-std): the standard deterministic deployer 0x4e59…956C, present on Robinhood Chain.

    // ------------------------------------------------------------------ Settings (DECISIONS.md)
    uint256 internal constant FAST_DELAY = 48 hours;
    uint256 internal constant SLOW_DELAY = 7 days;
    uint256 internal constant TESTNET_FAST_DELAY = 10 minutes; // D-62
    uint256 internal constant TESTNET_SLOW_DELAY = 30 minutes;
    uint160 internal constant PAD_HOOK_FLAGS = Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
        | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
        | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG;
    uint160 internal constant MARKET_HOOK_FLAGS = Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
        | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG;
    uint256 internal constant SALE_TARGET = 8_460e18; // D-17, D-32
    uint256 internal constant CAP_FLOOR = 150_000_000e18; // D-21
    uint256 internal constant CAP_DECAY = 500_000e18; // D-21
    uint256 internal constant SALE_SUPPLY = 900_000_000e18; // 60% curve + 30% pool (D-17)
    uint256 internal constant AIRDROP = 50_000_000e18; // 5%
    uint256 internal constant TEAM = 20_000_000e18; // 2%
    uint256 internal constant LIQUIDITY_RESERVE = 30_000_000e18; // 3%, LiquidityReserve → 48 h timelock once the market opens

    /// @dev Everything that differs between chains. Mainnet: `robinhood()`.
    struct Network {
        address poolManager;
        address imd;
        address usdg;
        uint24 ethUsdgFee; // ETH/USDG pool used by the USDG payment route
        int24 ethUsdgTickSpacing;
        address ethUsdgHook;
        uint256 fastDelay;
        uint256 slowDelay;
        PadConfig.LaunchSettings launch; // coin launch settings at deploy (mainnet: D-76)
    }

    struct Params {
        Network chain;
        address deployer; // the account that sends every transaction of the run
        address safe;
        address relay;
        address xLinkKey;
        address tweetChecker;
        address workerRewards;
        bytes32 airdropRoot;
        uint256 saleStart;
        uint256 powersExpireAt;
        string ctoRules;
        string auditLink;
    }

    struct Deployment {
        TimelockController fastTimelock;
        TimelockController slowTimelock;
        PondPadToken pondpad;
        FeeSplitter splitter;
        PadConfig config;
        CreatorVault creatorVault;
        SwarmBudget swarmBudget;
        IntegratorVault integrators;
        BondingCurve curve;
        PadHook hook;
        PadFactory factory;
        PadRouter router;
        PadLens lens;
        AttestationVerifier verifier;
        SocialRegistry social;
        CTOModule cto;
        VersionRegistry versions;
        WorkerFund workerFund;
        GrowthFund growthFund;
        PadBurner burner;
        MarketController controller;
        PadMarketHook market;
        PadSale sale;
        StakedPONDPAD sVault;
        RewardDripper dripper;
        PadBuyer buyer;
        AirdropDistributor airdrop;
        TeamVesting vesting;
        LiquidityReserve reserve;
    }

    function run() external returns (Deployment memory d) {
        Params memory p = Params({
            chain: block.chainid == 4663 ? robinhood() : _chainFromSetup(),
            deployer: msg.sender,
            safe: vm.envAddress("SAFE"),
            relay: vm.envAddress("RELAY"),
            xLinkKey: vm.envAddress("X_LINK_KEY"),
            tweetChecker: vm.envAddress("TWEET_CHECKER"),
            workerRewards: vm.envOr("WORKER_REWARDS", address(0)),
            airdropRoot: _airdropRoot(),
            saleStart: vm.envUint("SALE_START"),
            powersExpireAt: 0,
            ctoRules: vm.envString("CTO_RULES"),
            auditLink: vm.envOr("AUDIT_LINK", string(""))
        });
        p.powersExpireAt = vm.envOr("POWERS_EXPIRE_AT", p.saleStart + 365 days);
        vm.startBroadcast(p.deployer);
        d = deploy(p);
        vm.stopBroadcast();
        _log(d);
        _write(d, p.chain);
    }

    /// @dev The airdrop root. With AIRDROP_CLAIMS (path to the claims.json that `airdrop/snapshot.py build` writes)
    ///      the root comes from that file after its list total is checked against the 50M the distributor gets
    ///      (audit R2-A3-7: nothing onchain ties the root to the balance). Required on mainnet; AIRDROP_ROOT, if
    ///      also set, must match. Test chains may pass a placeholder AIRDROP_ROOT alone.
    function _airdropRoot() internal view returns (bytes32 root) {
        string memory path = vm.envOr("AIRDROP_CLAIMS", string(""));
        if (bytes(path).length == 0) {
            require(block.chainid != 4663, "AIRDROP_CLAIMS required on mainnet");
            return vm.envBytes32("AIRDROP_ROOT");
        }
        root = airdropRootFromClaims(vm.readFile(path));
        bytes32 given = vm.envOr("AIRDROP_ROOT", bytes32(0));
        require(given == bytes32(0) || given == root, "AIRDROP_ROOT differs from the claims file");
    }

    /// @notice The root of a `snapshot.py build` claims.json, after checking its list total fits the airdrop.
    function airdropRootFromClaims(string memory json) public pure returns (bytes32 root) {
        root = vm.parseJsonBytes32(json, ".root");
        uint256 total = vm.parseUint(vm.parseJsonString(json, ".total"));
        require(total <= AIRDROP, "airdrop list exceeds 50M");
    }

    /// @notice Robinhood Chain mainnet (4663): the only chain values a mainnet run can use.
    function robinhood() public pure returns (Network memory) {
        return Network(PM, IMD, USDG, 0x800000, 10, ETH_USDG_HOOK, FAST_DELAY, SLOW_DELAY, launchForMainnet());
    }

    /// @notice Coin launch settings for mainnet (D-76): 0.35 IMD launch fee, Leap at 4,000 IMD, early-bird tax 70%
    ///         falling to zero over 80 s, max-buy 2% of supply for the first 80 s, 1% Leap cut to growth.
    function launchForMainnet() public pure returns (PadConfig.LaunchSettings memory) {
        return PadConfig.LaunchSettings({
            launchFee: 0.35e18,
            graduationTarget: 4_000e18,
            graduationFeeBps: 100,
            snipeTaxStartBps: 7_000,
            snipeTaxDuration: 80,
            maxBuyWindow: 80,
            maxBuyBps: 200
        });
    }

    /// @notice Coin launch settings for test chains: the ones the Robinhood testnet runs with (D-11, D-14, D-76).
    function launchForTestnet() public pure returns (PadConfig.LaunchSettings memory) {
        return PadConfig.LaunchSettings({
            launchFee: 1e18,
            graduationTarget: 2_060e18,
            graduationFeeBps: 100,
            snipeTaxStartBps: 5_000,
            snipeTaxDuration: 20,
            maxBuyWindow: 60,
            maxBuyBps: 200
        });
    }

    /// @dev Test chains: test IMD / USDG and their pools from TestnetSetup's file, short timelock delays.
    function _chainFromSetup() internal view returns (Network memory c) {
        string memory json = vm.readFile(string.concat("deployments/", vm.toString(block.chainid), "-setup.json"));
        c.poolManager = vm.parseJsonAddress(json, ".poolManager");
        c.imd = vm.parseJsonAddress(json, ".imd");
        c.usdg = vm.parseJsonAddress(json, ".usdg");
        c.ethUsdgFee = uint24(vm.parseJsonUint(json, ".ethUsdgFee"));
        c.ethUsdgTickSpacing = int24(int256(vm.parseJsonUint(json, ".ethUsdgTickSpacing")));
        c.ethUsdgHook = vm.parseJsonAddress(json, ".ethUsdgHook");
        c.fastDelay = vm.envOr("FAST_DELAY", TESTNET_FAST_DELAY);
        c.slowDelay = vm.envOr("SLOW_DELAY", TESTNET_SLOW_DELAY);
        c.launch = launchForTestnet();
    }

    /// @notice The whole deployment. `p.deployer` must be the account executing these calls (the broadcaster, or
    ///         this contract in a fork rehearsal).
    function deploy(Params memory p) public returns (Deployment memory d) {
        require(p.safe != address(0) && p.relay != address(0) && p.xLinkKey != address(0), "params");
        require(p.tweetChecker != address(0) && p.airdropRoot != bytes32(0), "airdrop params");
        require(p.saleStart > block.timestamp && p.powersExpireAt > p.saleStart, "times");
        require(p.chain.poolManager != address(0) && p.chain.imd != address(0) && p.chain.usdg != address(0), "chain");
        require(p.chain.fastDelay != 0 && p.chain.slowDelay >= p.chain.fastDelay, "delays");
        if (block.chainid == 4663) require(keccak256(abi.encode(p.chain)) == keccak256(abi.encode(robinhood())), "mainnet");
        address imd = p.chain.imd;
        address pm = p.chain.poolManager;

        // 1. Timelocks: the Safe proposes (and can cancel), anyone executes after the delay, no admin.
        address[] memory proposers = new address[](1);
        proposers[0] = p.safe;
        address[] memory executors = new address[](1); // address(0) = anyone
        d.fastTimelock = new TimelockController(p.chain.fastDelay, proposers, executors, address(0));
        d.slowTimelock = new TimelockController(p.chain.slowDelay, proposers, executors, address(0));
        address fast = address(d.fastTimelock);
        address slow = address(d.slowTimelock);

        // 2. $PONDPAD at an address above IMD's, so IMD is currency0 in its pool (D-19).
        d.pondpad = PondPadToken(_create2Above(abi.encodePacked(type(PondPadToken).creationCode, abi.encode(p.deployer)), imd));
        address pondpad = address(d.pondpad);

        // 3. Funds and fee routing (recipients finalized in step 9 once PadBuyer exists).
        d.workerFund = new WorkerFund(slow, imd, pondpad, p.workerRewards);
        d.growthFund = new GrowthFund(fast, imd, pondpad, p.relay, p.safe, 100e18, 1_000e18, 10_000_000e18); // D-47
        d.splitter = new FeeSplitter(
            p.deployer,
            imd,
            FeeSplitter.Shares({stakers: 4_000, workers: 2_500, growth: 2_000, treasury: 1_500}),
            FeeSplitter.Recipients({stakers: p.safe, workers: address(d.workerFund), growth: address(d.growthFund), treasury: p.safe})
        );
        d.config = new PadConfig(
            p.deployer,
            imd,
            address(d.splitter),
            address(d.growthFund),
            p.safe,
            p.chain.launch
        );
        _setPaymentRoutes(d.config, p.chain);

        // 4. Coin launch and trading (version 1).
        d.creatorVault = new CreatorVault(imd);
        d.swarmBudget = new SwarmBudget(fast, imd, address(d.creatorVault), p.relay, 100e18);
        d.integrators = new IntegratorVault(imd);
        d.curve = new BondingCurve(imd, address(d.config), pm);
        d.hook = PadHook(
            _create2Hook(
                abi.encodePacked(
                    type(PadHook).creationCode,
                    abi.encode(
                        IPoolManager(pm), imd, address(d.config), address(d.creatorVault), address(d.swarmBudget),
                        address(d.integrators), p.deployer
                    )
                ),
                PAD_HOOK_FLAGS
            )
        );
        d.factory = new PadFactory(address(d.curve), address(d.hook), pm, imd);
        d.router = new PadRouter(imd, pm, address(d.config), address(d.curve), address(d.hook), address(d.factory));
        d.lens = new PadLens(address(d.curve), address(d.hook), address(d.creatorVault), address(d.swarmBudget));

        // 5. Oracle, X links and takeovers (the vault takes the CTO module once, so it comes first).
        d.verifier = new AttestationVerifier(slow);
        d.social = new SocialRegistry(fast, address(d.creatorVault), p.xLinkKey);
        d.cto = new CTOModule(
            slow, address(d.creatorVault), address(d.curve), address(d.social), address(d.verifier), p.safe, p.ctoRules
        );

        d.creatorVault.initialize(address(d.curve), address(d.hook), address(d.cto));
        d.swarmBudget.initialize(address(d.curve), address(d.hook));
        d.curve.initialize(
            address(d.factory), address(d.router), address(d.hook), address(d.creatorVault), address(d.swarmBudget),
            address(d.integrators)
        );
        d.integrators.initialize(address(d.curve), address(d.hook));
        d.hook.initialize(address(d.curve), address(d.router));
        d.factory.initialize(address(d.router));

        // 6. Version registry: version 1, activated now only if the swarm audit link is given (D-46 fallback).
        d.versions = new VersionRegistry(p.deployer, address(d.verifier));
        uint256 v1 = d.versions.register(address(d.factory), address(d.router), address(d.curve), address(d.hook), address(d.lens));
        if (bytes(p.auditLink).length != 0) d.versions.activateManually(v1, p.auditLink);
        d.versions.transferOwnership(slow);

        // 7. $PONDPAD market, sale and staking.
        d.burner = new PadBurner(pondpad);
        d.controller = new MarketController(
            fast, slow, imd, pondpad, address(d.splitter), address(d.burner), p.safe, CAP_FLOOR, CAP_DECAY
        );
        d.sVault = new StakedPONDPAD(pondpad, slow, p.powersExpireAt);
        d.dripper = new RewardDripper(pondpad, address(d.sVault), fast, 7 days, 1 days, 10e18, 1_000e18, p.powersExpireAt);
        d.market = PadMarketHook(
            _create2Hook(
                abi.encodePacked(
                    type(PadMarketHook).creationCode,
                    abi.encode(
                        address(d.controller), IPoolManager(pm), imd, pondpad, address(d.burner), address(d.dripper),
                        uint256(1_500), uint256(1_000e18), int24(200)
                    )
                ),
                MARKET_HOOK_FLAGS
            )
        );
        d.sale = new PadSale(
            imd, pm, address(d.config), pondpad, address(d.controller), address(d.integrators), SALE_TARGET, p.saleStart
        );
        d.integrators.setSale(address(d.sale));
        d.controller.initialize(address(d.market), address(d.sale));
        d.buyer = new PadBuyer(fast, imd, pondpad, pm, address(d.controller), address(d.dripper));

        // 8. Airdrop and team vesting (D-53 to D-56).
        d.airdrop = new AirdropDistributor(fast, pondpad, p.airdropRoot, address(d.controller), address(d.dripper), p.tweetChecker);
        d.vesting = new TeamVesting(pondpad, address(d.controller), p.safe);
        // The liquidity reserve waits for the market to open, then goes to the 48 h timelock (audit R1-A2-4).
        d.reserve = new LiquidityReserve(pondpad, address(d.controller), fast);

        // 9. Final fee routing, then hand the deployer's powers to the timelocks.
        d.splitter.setRecipients(
            FeeSplitter.Recipients({
                stakers: address(d.buyer),
                workers: address(d.workerFund),
                growth: address(d.growthFund),
                treasury: p.safe
            })
        );
        d.splitter.transferOwnership(slow);
        d.config.transferOwnership(fast);

        // 10. Distribute the whole $PONDPAD supply: the deployer keeps nothing.
        d.pondpad.approve(address(d.sale), SALE_SUPPLY);
        d.sale.fund();
        d.pondpad.transfer(address(d.airdrop), AIRDROP);
        d.pondpad.transfer(address(d.vesting), TEAM);
        d.pondpad.transfer(address(d.reserve), LIQUIDITY_RESERVE);
        require(d.pondpad.balanceOf(p.deployer) == 0, "supply left");
    }

    // ------------------------------------------------------------------ Helpers

    /// @dev ETH via the hookless IMD/ETH pool; USDG via the ETH/USDG pool (on mainnet the dynamic-fee one), then
    ///      IMD/ETH (D-30).
    function _setPaymentRoutes(PadConfig config, Network memory c) internal {
        PoolKey memory imdEth = PoolKey(Currency.wrap(address(0)), Currency.wrap(c.imd), 10_000, 100, IHooks(address(0)));
        PoolKey memory ethUsdg = PoolKey(
            Currency.wrap(address(0)), Currency.wrap(c.usdg), c.ethUsdgFee, c.ethUsdgTickSpacing, IHooks(c.ethUsdgHook)
        );
        Hop[] memory eth = new Hop[](1);
        eth[0] = Hop(imdEth, true);
        config.setPaymentRoute(address(0), eth);
        Hop[] memory usdg = new Hop[](2);
        usdg[0] = Hop(ethUsdg, false);
        usdg[1] = Hop(imdEth, true);
        config.setPaymentRoute(c.usdg, usdg);
    }

    function create2Address(bytes32 salt, bytes32 initCodeHash) public pure returns (address addr) {
        address factory = CREATE2_FACTORY;
        assembly ("memory-safe") {
            let ptr := mload(0x40) // scratch above the free pointer, not allocated: no memory growth in loops
            mstore8(ptr, 0xff)
            mstore(add(ptr, 0x01), shl(96, factory))
            mstore(add(ptr, 0x15), salt)
            mstore(add(ptr, 0x35), initCodeHash)
            addr := and(keccak256(ptr, 0x55), 0xffffffffffffffffffffffffffffffffffffffff)
        }
    }

    /// @dev First salt whose address has exactly `flags` in its low 14 bits (v4 hook permissions).
    function mineHookSalt(bytes32 initCodeHash, uint160 flags) public pure returns (bytes32 salt, address addr) {
        for (uint256 i;; ++i) {
            addr = create2Address(bytes32(i), initCodeHash);
            if (uint160(addr) & Hooks.ALL_HOOK_MASK == flags) return (bytes32(i), addr);
        }
    }

    function _create2Hook(bytes memory initCode, uint160 flags) internal returns (address addr) {
        (bytes32 salt, address expected) = mineHookSalt(keccak256(initCode), flags);
        addr = _create2(salt, initCode);
        require(addr == expected, "hook address");
    }

    function _create2Above(bytes memory initCode, address floor) internal returns (address addr) {
        bytes32 h = keccak256(initCode);
        uint256 i;
        while (create2Address(bytes32(i), h) <= floor) ++i;
        addr = _create2(bytes32(i), initCode);
    }

    /// @dev If someone already deployed this exact init code at this salt through the public CREATE2 deployer (all
    ///      of it is public once the deployer address is known), the contract there is the one we want: the address
    ///      commits to the init code, constructor arguments included ($PONDPAD mints to the deployer either way).
    ///      Use it instead of reverting on every re-run (audit R1-A4-14).
    function _create2(bytes32 salt, bytes memory initCode) internal returns (address addr) {
        address predicted = create2Address(salt, keccak256(initCode));
        if (predicted.code.length != 0) return predicted;
        (bool ok, bytes memory ret) = CREATE2_FACTORY.call(abi.encodePacked(salt, initCode));
        require(ok && ret.length == 20, "create2");
        addr = address(bytes20(ret));
    }

    /// @dev Addresses for the keeper, frontend and indexer: deployments/<chainId>.json.
    function _write(Deployment memory d, Network memory c) internal {
        string memory k = "deployment";
        vm.serializeAddress(k, "fastTimelock", address(d.fastTimelock));
        vm.serializeAddress(k, "slowTimelock", address(d.slowTimelock));
        vm.serializeAddress(k, "imd", c.imd);
        vm.serializeAddress(k, "usdg", c.usdg);
        vm.serializeAddress(k, "poolManager", c.poolManager);
        vm.serializeAddress(k, "pondpad", address(d.pondpad));
        vm.serializeAddress(k, "feeSplitter", address(d.splitter));
        vm.serializeAddress(k, "config", address(d.config));
        vm.serializeAddress(k, "creatorVault", address(d.creatorVault));
        vm.serializeAddress(k, "swarmBudget", address(d.swarmBudget));
        vm.serializeAddress(k, "integratorVault", address(d.integrators));
        vm.serializeAddress(k, "curve", address(d.curve));
        vm.serializeAddress(k, "hook", address(d.hook));
        vm.serializeAddress(k, "factory", address(d.factory));
        vm.serializeAddress(k, "router", address(d.router));
        vm.serializeAddress(k, "lens", address(d.lens));
        vm.serializeAddress(k, "attestationVerifier", address(d.verifier));
        vm.serializeAddress(k, "socialRegistry", address(d.social));
        vm.serializeAddress(k, "ctoModule", address(d.cto));
        vm.serializeAddress(k, "versionRegistry", address(d.versions));
        vm.serializeAddress(k, "workerFund", address(d.workerFund));
        vm.serializeAddress(k, "growthFund", address(d.growthFund));
        vm.serializeAddress(k, "burner", address(d.burner));
        vm.serializeAddress(k, "marketController", address(d.controller));
        vm.serializeAddress(k, "marketHook", address(d.market));
        vm.serializeAddress(k, "sale", address(d.sale));
        vm.serializeAddress(k, "stakedPondpad", address(d.sVault));
        vm.serializeAddress(k, "rewardDripper", address(d.dripper));
        vm.serializeAddress(k, "padBuyer", address(d.buyer));
        vm.serializeAddress(k, "airdrop", address(d.airdrop));
        vm.serializeAddress(k, "teamVesting", address(d.vesting));
        vm.serializeAddress(k, "liquidityReserve", address(d.reserve));
        string memory json = vm.serializeUint(k, "chainId", block.chainid);
        vm.writeJson(json, string.concat("deployments/", vm.toString(block.chainid), ".json"));
    }

    function _log(Deployment memory d) internal pure {
        console2.log("fast timelock        ", address(d.fastTimelock));
        console2.log("slow timelock        ", address(d.slowTimelock));
        console2.log("PONDPAD              ", address(d.pondpad));
        console2.log("PadConfig            ", address(d.config));
        console2.log("FeeSplitter          ", address(d.splitter));
        console2.log("BondingCurve         ", address(d.curve));
        console2.log("PadHook              ", address(d.hook));
        console2.log("PadRouter            ", address(d.router));
        console2.log("PadLens              ", address(d.lens));
        console2.log("CTOModule            ", address(d.cto));
        console2.log("VersionRegistry      ", address(d.versions));
        console2.log("PadSale              ", address(d.sale));
        console2.log("MarketController     ", address(d.controller));
        console2.log("PadMarketHook        ", address(d.market));
        console2.log("StakedPONDPAD        ", address(d.sVault));
        console2.log("RewardDripper        ", address(d.dripper));
        console2.log("PadBuyer             ", address(d.buyer));
        console2.log("AirdropDistributor   ", address(d.airdrop));
        console2.log("TeamVesting          ", address(d.vesting));
        console2.log("LiquidityReserve     ", address(d.reserve));
    }
}
