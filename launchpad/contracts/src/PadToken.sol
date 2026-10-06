// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {TransientStateLibrary} from "v4-core/libraries/TransientStateLibrary.sol";

/// @title PadToken
/// @notice A coin launched on PondPad: fixed supply of 1,000,000,000, no owner, no mint, no admin, with EIP-2612
///         permit. Holders earn IMD dividends when the coin's creator chose a holder tax at launch.
/// @dev Dividends use "reward per share" accounting, so payouts are O(1) and holders withdraw with `claim()`.
///      The bonding curve, the hook, the PoolManager and the dead address hold tokens on behalf of the market,
///      so they never earn dividends. Distribution is skipped while the PoolManager is unlocked by anyone but the
///      hook: inside an unlock, pool tokens can be flash-borrowed and would otherwise count as held.
contract PadToken is ERC20, ReentrancyGuard {
    using SafeTransferLib for address;
    using TransientStateLibrary for IPoolManager;

    uint256 public constant TOTAL_SUPPLY = 1_000_000_000e18;
    /// @notice Distributions wait until at least one whole token is eligible, which also bounds the per-share math.
    ///         While fewer are eligible, the curve and the hook send the holder tax to the growth fund instead of
    ///         parking it here for the next buyer's first holders (audit R2-A1-3).
    uint256 public constant MIN_ELIGIBLE = 1e18;
    uint256 internal constant MAGNITUDE = 2 ** 128;
    address internal constant DEAD = 0x000000000000000000000000000000000000dEaD;

    address public immutable curve;
    address public immutable hook;
    IPoolManager public immutable poolManager;
    address public immutable imd;

    string internal _name;
    string internal _symbol;

    uint256 public magnifiedDividendPerShare;
    uint256 public eligibleSupply;
    /// @notice IMD held by this contract that is already accounted for (credited to holders, not yet claimed).
    uint256 public accountedImd;
    uint256 public totalDividendsDistributed;
    mapping(address => int256) internal _corrections;
    mapping(address => uint256) public withdrawnDividends;

    event DividendsDistributed(uint256 amount);
    event DividendClaimed(address indexed holder, uint256 amount);

    constructor(string memory name_, string memory symbol_, address curve_, address hook_, address poolManager_, address imd_) {
        _name = name_;
        _symbol = symbol_;
        curve = curve_;
        hook = hook_;
        poolManager = IPoolManager(poolManager_);
        imd = imd_;
        _mint(curve_, TOTAL_SUPPLY);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /// @notice Always zero: the token has no owner and no admin functions.
    function owner() external pure returns (address) {
        return address(0);
    }

    /// @notice Burns the caller's own tokens.
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function isExcluded(address account) public view returns (bool) {
        return account == curve || account == hook || account == address(poolManager) || account == DEAD
            || account == address(0);
    }

    /// @notice Credits any IMD sent to this contract since the last distribution to current holders.
    function distribute() public {
        if (poolManager.isUnlocked() && msg.sender != hook) return;
        uint256 balance = SafeTransferLib.balanceOf(imd, address(this));
        uint256 amount = balance - accountedImd;
        if (amount == 0 || eligibleSupply < MIN_ELIGIBLE) return;
        magnifiedDividendPerShare += (amount * MAGNITUDE) / eligibleSupply;
        accountedImd = balance;
        totalDividendsDistributed += amount;
        emit DividendsDistributed(amount);
    }

    function withdrawableDividendOf(address account) public view returns (uint256) {
        if (isExcluded(account)) return 0;
        uint256 accumulated =
            uint256(int256(magnifiedDividendPerShare * balanceOf(account)) + _corrections[account]) / MAGNITUDE;
        return accumulated - withdrawnDividends[account];
    }

    /// @notice Sends the caller's IMD dividends.
    function claim() external nonReentrant returns (uint256 amount) {
        distribute();
        amount = withdrawableDividendOf(msg.sender);
        if (amount == 0) return 0;
        withdrawnDividends[msg.sender] += amount;
        accountedImd -= amount;
        imd.safeTransfer(msg.sender, amount);
        emit DividendClaimed(msg.sender, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override {
        int256 magnified = int256(magnifiedDividendPerShare * amount);
        if (!isExcluded(from)) {
            eligibleSupply -= amount;
            _corrections[from] += magnified;
        }
        if (!isExcluded(to)) {
            eligibleSupply += amount;
            _corrections[to] -= magnified;
        }
    }

    /// @dev No default infinite allowance for Permit2; approvals work the standard way.
    function _givePermit2InfiniteAllowance() internal pure override returns (bool) {
        return false;
    }
}
