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
///      so they never earn dividends; nor does the coin's own address, which can't claim (audit R4-A1-3).
///      Distribution is skipped while the PoolManager is unlocked by anyone but the hook: inside an unlock, pool
///      tokens can be flash-borrowed and would otherwise count as held.
///      Holder stream (D-78, D-80): IMD routed to a coin's holders as a lump (creator fees of a coin whose fees go
///      to holders, its swept swarm budget) is paid out second by second over about 7 days, to the balances held
///      during each second. The stream is settled before every balance change, so a position held for no time
///      earns nothing from it, whatever moment a buyer picks (audit R3-A4-1); while nobody is eligible the stream
///      waits instead of banking the time for the next buyer (audit R3-A4-2).
contract PadToken is ERC20, ReentrancyGuard {
    using SafeTransferLib for address;
    using TransientStateLibrary for IPoolManager;

    uint256 public constant TOTAL_SUPPLY = 1_000_000_000e18;
    /// @notice Distributions wait until at least one whole token is eligible, which also bounds the per-share math.
    ///         While fewer are eligible apart from the trader, the curve and the hook send the holder tax to the
    ///         growth fund instead of crediting it back to the trader (audits R2-A1-3, R3-A1-1).
    uint256 public constant MIN_ELIGIBLE = 1e18;
    uint256 internal constant MAGNITUDE = 2 ** 128;
    /// @notice A lump added to the holder stream pays out over this long (D-78).
    uint256 public constant HOLDER_STREAM_PERIOD = 7 days;
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

    /// @dev The holder stream: IMD held here but not yet credited, paid linearly until `end`, settled up to `last`.
    struct Stream {
        uint128 remaining;
        uint64 end;
        uint64 last;
    }

    Stream internal _stream;

    event DividendsDistributed(uint256 amount);
    event DividendClaimed(address indexed holder, uint256 amount);
    event HolderStreamFunded(address indexed from, uint256 amount, uint256 remaining, uint256 endsAt);

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

    /// @notice Eligible supply not held by `account`: the holders a trade's holder tax would reach other than the
    ///         trader (audit R3-A1-1). `address(0)` means no trader to leave out.
    function eligibleSupplyExcept(address account) external view returns (uint256) {
        if (account == address(0) || isExcluded(account)) return eligibleSupply;
        return eligibleSupply - balanceOf(account);
    }

    function isExcluded(address account) public view returns (bool) {
        return account == curve || account == hook || account == address(poolManager) || account == DEAD
            || account == address(0) || account == address(this); // tokens sent to the coin itself (audit R4-A1-3)
    }

    /// @notice Credits any IMD sent to this contract since the last distribution to current holders. IMD in the
    ///         holder stream is not part of it: the stream credits holders second by second.
    function distribute() public {
        if (poolManager.isUnlocked() && msg.sender != hook) return;
        uint256 balance = SafeTransferLib.balanceOf(imd, address(this));
        uint256 accounted = accountedImd + _stream.remaining;
        uint256 amount = balance - accounted;
        if (amount == 0 || eligibleSupply < MIN_ELIGIBLE) return;
        magnifiedDividendPerShare += (amount * MAGNITUDE) / eligibleSupply;
        accountedImd += amount;
        totalDividendsDistributed += amount;
        emit DividendsDistributed(amount);
    }

    /// @notice Adds `amount` IMD (pulled from the caller) to the holder stream. The stream ends at the
    ///         amount-weighted average of its current end and 7 days from now, so a new lump still pays out over
    ///         about 7 days (audits R3-A1-2 / R3-A4-3) and a tiny top-up can't stretch a running one (R2-A4-3).
    ///         `CreatorVault` uses it for coins whose fees go to holders; anyone may add to it.
    function fundHolderStream(uint256 amount) external nonReentrant {
        if (amount == 0) return;
        _settleStream();
        imd.safeTransferFrom(msg.sender, address(this), amount);
        Stream memory st = _stream;
        uint256 newEnd = block.timestamp + HOLDER_STREAM_PERIOD;
        if (st.remaining != 0) {
            // A running stream's end is in the future and at most 7 days away, so the average lies between them.
            newEnd = (uint256(st.remaining) * st.end + amount * newEnd) / (uint256(st.remaining) + amount);
        }
        uint256 remaining = uint256(st.remaining) + amount;
        _stream = Stream(uint128(remaining), uint64(newEnd), uint64(block.timestamp));
        emit HolderStreamFunded(msg.sender, amount, remaining, newEnd);
    }

    /// @notice The holder stream: IMD not yet paid out, when it ends at its current pace, and IMD the next
    ///         settlement would credit to holders now.
    function holderStream() external view returns (uint256 remaining, uint256 endsAt, uint256 due) {
        Stream memory st = _stream;
        (due,) = _streamDue(st);
        return (st.remaining, st.end, due);
    }

    function withdrawableDividendOf(address account) public view returns (uint256) {
        if (isExcluded(account)) return 0;
        uint256 perShare = magnifiedDividendPerShare;
        (uint256 due,) = _streamDue(_stream);
        if (due != 0) perShare += (due * MAGNITUDE) / eligibleSupply;
        uint256 accumulated = uint256(int256(perShare * balanceOf(account)) + _corrections[account]) / MAGNITUDE;
        return accumulated - withdrawnDividends[account];
    }

    /// @notice Sends the caller's IMD dividends.
    function claim() external nonReentrant returns (uint256 amount) {
        _settleStream();
        distribute();
        amount = withdrawableDividendOf(msg.sender);
        if (amount == 0) return 0;
        withdrawnDividends[msg.sender] += amount;
        accountedImd -= amount;
        imd.safeTransfer(msg.sender, amount);
        emit DividendClaimed(msg.sender, amount);
    }

    /// @dev What the stream owes holders now, and whether it is waiting because nobody is eligible.
    function _streamDue(Stream memory st) internal view returns (uint256 due, bool waiting) {
        if (st.remaining == 0 || block.timestamp == st.last) return (0, false);
        if (eligibleSupply < MIN_ELIGIBLE) return (0, true);
        // A running stream always ends after its last settlement (funding and waiting both keep `end > last`).
        if (block.timestamp >= st.end) return (st.remaining, false);
        due = (uint256(st.remaining) * (block.timestamp - st.last)) / (uint256(st.end) - st.last);
    }

    /// @dev Credits the stream's share for the time since the last settlement to the balances held during it.
    ///      Runs before every balance change (`_beforeTokenTransfer`), on claims and when the stream is funded. No
    ///      external call, so it also runs inside a PoolManager unlock: a flash-borrowed balance is held for no
    ///      time and earns nothing. While nobody is eligible the stream waits (its end moves with the clock).
    function _settleStream() internal {
        Stream memory st = _stream;
        if (st.remaining == 0 || block.timestamp == st.last) return;
        (uint256 due, bool waiting) = _streamDue(st);
        if (waiting) {
            _stream.end = uint64(uint256(st.end) + (block.timestamp - st.last));
        } else if (due != 0) {
            _stream.remaining = uint128(uint256(st.remaining) - due);
            magnifiedDividendPerShare += (due * MAGNITUDE) / eligibleSupply;
            accountedImd += due;
            totalDividendsDistributed += due;
        }
        _stream.last = uint64(block.timestamp);
    }

    function _beforeTokenTransfer(address, address, uint256) internal override {
        _settleStream();
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
