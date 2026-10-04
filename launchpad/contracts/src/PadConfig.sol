// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "solady/auth/Ownable.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {Hop} from "./Route.sol";

/// @title PadConfig
/// @notice Every adjustable PondPad setting, each with hard limits enforced here. The owner is meant to be a
///         timelock controlled by the team multisig. A guardian may pause new launches instantly, nothing else.
///         Coins copy the launch settings when they are created, so a change only affects future launches.
contract PadConfig is Ownable {
    struct LaunchSettings {
        uint96 launchFee; // IMD paid per launch, sent to the fee splitter
        uint96 graduationTarget; // net IMD the curve must raise before the coin graduates
        uint16 graduationFeeBps; // share of the raised IMD sent to the growth fund at graduation
        uint16 snipeTaxStartBps; // extra tax on buys at launch, decaying linearly to zero
        uint32 snipeTaxDuration; // seconds over which the snipe tax decays
        uint32 maxBuyWindow; // seconds after launch during which the per-wallet buy cap applies
        uint16 maxBuyBps; // per-wallet cap during the window, in bps of total supply
    }

    uint96 public constant MAX_LAUNCH_FEE = 10e18;
    uint96 public constant MIN_GRADUATION_TARGET = 1_000e18;
    uint96 public constant MAX_GRADUATION_TARGET = 10_000e18;
    uint16 public constant MAX_GRADUATION_FEE_BPS = 200;
    uint16 public constant MAX_SNIPE_TAX_BPS = 9_000;
    uint32 public constant MAX_SNIPE_TAX_DURATION = 120;
    uint32 public constant MAX_BUY_WINDOW = 300;
    uint16 public constant MIN_MAX_BUY_BPS = 50;

    LaunchSettings internal _launch;
    address public feeSplitter;
    address public growthFund;
    address public guardian;
    bool public launchesPaused;
    /// @notice Approved payment tokens and their swap path to IMD (address(0) = native ETH). The router can take
    ///         any of them for launches and buys, and pay them out on sells, swapping through IMD in the same
    ///         transaction. Contracts only ever receive IMD.
    mapping(address token => Hop[]) internal _routeToImd;
    address[] internal _paymentTokens;

    /// @notice Share of the protocol fee paid to a registered integrator on trades it routes through PadRouter.
    uint16 public integratorShareBps;
    uint16 public constant MAX_INTEGRATOR_SHARE_BPS = 2_500;
    mapping(address => bool) public isIntegrator;
    address public immutable imd;

    event LaunchSettingsUpdated(LaunchSettings settings);
    event FeeSplitterUpdated(address feeSplitter);
    event GrowthFundUpdated(address growthFund);
    event GuardianUpdated(address guardian);
    event LaunchesPaused(bool paused);
    event PaymentRouteSet(address indexed token, Hop[] hops);
    event PaymentRouteRemoved(address indexed token);
    event IntegratorShareUpdated(uint16 bps);
    event IntegratorSet(address indexed integrator, bool registered);

    error InvalidSetting();
    error NotGuardian();

    constructor(
        address owner_,
        address imd_,
        address feeSplitter_,
        address growthFund_,
        address guardian_,
        LaunchSettings memory s
    ) {
        _initializeOwner(owner_);
        imd = imd_;
        _setFeeSplitter(feeSplitter_);
        _setGrowthFund(growthFund_);
        guardian = guardian_;
        _setLaunchSettings(s);
        integratorShareBps = 1_500;
        emit IntegratorShareUpdated(1_500);
    }

    /// @notice The integrator share in bps for `referrer`, or zero if it is not a registered integrator.
    function integratorShareFor(address referrer) external view returns (uint256) {
        return referrer != address(0) && isIntegrator[referrer] ? integratorShareBps : 0;
    }

    function setIntegratorShareBps(uint16 bps) external onlyOwner {
        if (bps > MAX_INTEGRATOR_SHARE_BPS) revert InvalidSetting();
        integratorShareBps = bps;
        emit IntegratorShareUpdated(bps);
    }

    /// @notice Registers or removes an integrator. Owner or guardian: it only redirects part of the protocol's
    ///         own fee, never user funds, so onboarding an app doesn't wait for the timelock.
    function setIntegrator(address integrator, bool registered) external {
        if (msg.sender != guardian && msg.sender != owner()) revert NotGuardian();
        if (integrator == address(0)) revert InvalidSetting();
        isIntegrator[integrator] = registered;
        emit IntegratorSet(integrator, registered);
    }

    function launchSettings() external view returns (LaunchSettings memory) {
        return _launch;
    }

    function setLaunchSettings(LaunchSettings calldata s) external onlyOwner {
        _setLaunchSettings(s);
    }

    uint256 public constant MAX_ROUTE_HOPS = 3;

    /// @notice The swap path from `token` to IMD. Empty if `token` is not an approved payment token.
    function routeToImd(address token) external view returns (Hop[] memory) {
        return _routeToImd[token];
    }

    function paymentTokens() external view returns (address[] memory) {
        return _paymentTokens;
    }

    function isPaymentToken(address token) public view returns (bool) {
        return _routeToImd[token].length != 0;
    }

    /// @notice Approves `token` as a payment token with the given path to IMD, or replaces its path.
    ///         Each hop's output must be the next hop's input, the first input must be `token` and the last
    ///         output IMD.
    function setPaymentRoute(address token, Hop[] calldata hops) external onlyOwner {
        uint256 n = hops.length;
        if (token == imd || n == 0 || n > MAX_ROUTE_HOPS) revert InvalidSetting();
        address current = token;
        for (uint256 i; i < n; i++) {
            Hop calldata h = hops[i];
            (Currency input, Currency output) =
                h.zeroForOne ? (h.key.currency0, h.key.currency1) : (h.key.currency1, h.key.currency0);
            if (Currency.unwrap(input) != current) revert InvalidSetting();
            current = Currency.unwrap(output);
        }
        if (current != imd) revert InvalidSetting();

        if (!isPaymentToken(token)) _paymentTokens.push(token);
        delete _routeToImd[token];
        for (uint256 i; i < n; i++) {
            _routeToImd[token].push(hops[i]);
        }
        emit PaymentRouteSet(token, hops);
    }

    function removePaymentRoute(address token) external onlyOwner {
        if (!isPaymentToken(token)) revert InvalidSetting();
        delete _routeToImd[token];
        uint256 n = _paymentTokens.length;
        for (uint256 i; i < n; i++) {
            if (_paymentTokens[i] == token) {
                _paymentTokens[i] = _paymentTokens[n - 1];
                _paymentTokens.pop();
                break;
            }
        }
        emit PaymentRouteRemoved(token);
    }

    function setFeeSplitter(address feeSplitter_) external onlyOwner {
        _setFeeSplitter(feeSplitter_);
    }

    function setGrowthFund(address growthFund_) external onlyOwner {
        _setGrowthFund(growthFund_);
    }

    function setGuardian(address guardian_) external onlyOwner {
        guardian = guardian_;
        emit GuardianUpdated(guardian_);
    }

    /// @notice Pauses or resumes new launches. Trading, liquidity and fees are never affected.
    function setLaunchesPaused(bool paused) external {
        if (msg.sender != guardian && msg.sender != owner()) revert NotGuardian();
        launchesPaused = paused;
        emit LaunchesPaused(paused);
    }

    function _setLaunchSettings(LaunchSettings memory s) internal {
        if (
            s.launchFee > MAX_LAUNCH_FEE || s.graduationTarget < MIN_GRADUATION_TARGET
                || s.graduationTarget > MAX_GRADUATION_TARGET || s.graduationFeeBps > MAX_GRADUATION_FEE_BPS
                || s.snipeTaxStartBps > MAX_SNIPE_TAX_BPS || s.snipeTaxDuration > MAX_SNIPE_TAX_DURATION
                || s.maxBuyWindow > MAX_BUY_WINDOW || s.maxBuyBps < MIN_MAX_BUY_BPS || s.maxBuyBps > 10_000
        ) revert InvalidSetting();
        _launch = s;
        emit LaunchSettingsUpdated(s);
    }

    function _setFeeSplitter(address a) internal {
        if (a == address(0)) revert InvalidSetting();
        feeSplitter = a;
        emit FeeSplitterUpdated(a);
    }

    function _setGrowthFund(address a) internal {
        if (a == address(0)) revert InvalidSetting();
        growthFund = a;
        emit GrowthFundUpdated(a);
    }
}
