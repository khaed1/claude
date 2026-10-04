// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "solady/auth/Ownable.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";

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
    /// @notice The IMD/ETH v4 pool the router uses for ETH payments (the hookless pool today; a POOL4 market later).
    PoolKey internal _imdEthPoolKey;
    address public immutable imd;

    event LaunchSettingsUpdated(LaunchSettings settings);
    event FeeSplitterUpdated(address feeSplitter);
    event GrowthFundUpdated(address growthFund);
    event GuardianUpdated(address guardian);
    event LaunchesPaused(bool paused);
    event ImdEthPoolKeyUpdated(PoolKey key);

    error InvalidSetting();
    error NotGuardian();

    constructor(
        address owner_,
        address imd_,
        address feeSplitter_,
        address growthFund_,
        address guardian_,
        LaunchSettings memory s,
        PoolKey memory imdEthPoolKey_
    ) {
        _initializeOwner(owner_);
        imd = imd_;
        _setImdEthPoolKey(imdEthPoolKey_);
        _setFeeSplitter(feeSplitter_);
        _setGrowthFund(growthFund_);
        guardian = guardian_;
        _setLaunchSettings(s);
    }

    function launchSettings() external view returns (LaunchSettings memory) {
        return _launch;
    }

    function setLaunchSettings(LaunchSettings calldata s) external onlyOwner {
        _setLaunchSettings(s);
    }

    function imdEthPoolKey() external view returns (PoolKey memory) {
        return _imdEthPoolKey;
    }

    function setImdEthPoolKey(PoolKey calldata key) external onlyOwner {
        _setImdEthPoolKey(key);
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

    /// @dev Must be a native-ETH/IMD pool: currency0 is ETH (address zero sorts first), currency1 is IMD.
    function _setImdEthPoolKey(PoolKey memory key) internal {
        if (!key.currency0.isAddressZero() || Currency.unwrap(key.currency1) != imd) revert InvalidSetting();
        _imdEthPoolKey = key;
        emit ImdEthPoolKeyUpdated(key);
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
