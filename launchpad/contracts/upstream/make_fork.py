import re
s = open('upstream/CappedBurnHook.sol').read()


def rep(old, new, count=1):
    global s
    n = s.count(old)
    assert n == count, (old[:90], n)
    s = s.replace(old, new)


# ---------- 1. mechanical renames: ETH quote -> IMD quote
s = re.sub(r'\beth(?=[A-Z])', 'quote', s)
s = s.replace('Eth', 'Quote')
s = s.replace('safeTransferETH', 'safeTransferQUOTE')
s = s.replace('ETH', 'IMD')
s = s.replace('safeTransferQUOTE', 'safeTransferETH').replace('ACTION_SETTLE_IMD', 'ACTION_SETTLE_QUOTE')

# ---------- 2. header / imports
rep('pragma solidity ^0.8.24;', 'pragma solidity 0.8.26;')
start = s.index('/*\n   ____')
end = s.index('*/\n', start) + 3
s = s[:start] + '''/*
  PondPad · PadMarketHook — the $PONDPAD/IMD market.

  A fork of POOL4's CappedBurnHook (MIT, verified on Ethereum at 0xc6c965bd164c483e87d0b550671798e9a3602840;
  original source kept in `upstream/CappedBurnHook.sol`). Changes, all marked "PondPad:" below:
    1. Quote asset is IMD (an ERC-20, currency0) instead of native ETH. $PONDPAD's address is mined above IMD's,
       so IMD sorts first and all price/amount math is unchanged. The native-ETH plumbing (value transfers,
       payable settles, ETH sends, the receive function) is replaced by ERC-20 sync / transfer / settle, and
       `eth*` names became `quote*`.
    2. Dynamic LP fee (D-34): the pool key carries v4's dynamic-fee flag and `beforeSwap` returns
       `currentFee()`: 3% when the market opens, falling linearly to 1% over 7 days, then 1% forever. No
       setter. The keeper-tip bound uses `currentFee()` where the original used the immutable LP fee.
       Nothing in the cap / trim / burn / backstop paths reads the fee.
    3. IMD-sized constants: rebalance threshold 40 IMD, default keeper tip 1 IMD, max keeper tip 40 IMD.
    4. v4-core types come from `PoolOperation.sol` in the pinned v4-core; compiled for cancun.
  The owner is MarketController, which does not expose `closeMarket` or `withdrawRetainedQuote` (D-18).
*/
''' + s[end:]
rep('import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";',
    'import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";\nimport {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";')
rep('import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";',
    'import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";\nimport {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";\nimport {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";')
s = s.replace('IPoolManager.ModifyLiquidityParams', 'ModifyLiquidityParams').replace('IPoolManager.SwapParams', 'SwapParams')
rep('contract CappedBurnHook is Ownable {', 'contract PadMarketHook is Ownable {')

# ---------- 3. errors / constants / immutables
rep('    error IncorrectQuoteAmount(uint256 required, uint256 supplied);\n    error InsufficientRetainedQuote(uint256 requested, uint256 available);\n',
    '    error IncorrectQuoteAmount(uint256 required, uint256 supplied);\n')
rep('    uint256 internal constant MAX_KEEPER_REWARD = 0.1 ether;',
    '    uint256 internal constant MAX_KEEPER_REWARD = 40e18; // PondPad: 0.1 ETH -> 40 IMD')
rep('''    IPoolManager public immutable poolManager;
    address public immutable token;''', '''    IPoolManager public immutable poolManager;
    /// @notice PondPad: the quote asset, IMD (currency0). The original hard-codes native ETH.
    address public immutable quote;
    address public immutable token;''')
rep('''    uint24 public immutable lpFee;
''', '''    /// @notice PondPad: dynamic LP fee schedule (D-34), in hundredths of a bip (1_000_000 = 100%).
    uint24 public constant START_FEE = 30_000; // 3% when the market opens
    uint24 public constant END_FEE = 10_000; // 1% from day 7 on
    uint256 public constant FEE_DECAY_PERIOD = 7 days;
    /// @notice When `openMarket` ran; the fee schedule counts from here. Zero before the market opens.
    uint256 public marketOpenedAt;
''')

# ---------- 4. constructor
rep('''        IPoolManager poolManager_,
        address token_,''', '''        IPoolManager poolManager_,
        address quote_,
        address token_,''')
rep('''        uint256 minTrimTokens_,
        uint24 lpFee_,
        int24 tickSpacing_''', '''        uint256 minTrimTokens_,
        int24 tickSpacing_''')
rep('''            owner_ == address(0) || address(poolManager_) == address(0) || token_ == address(0)''',
    '''            owner_ == address(0) || address(poolManager_) == address(0) || token_ == address(0)
                || quote_ == address(0) || quote_ >= token_ // PondPad: IMD must sort first (currency0)''')
rep('''                || lpFee_ > 1_000_000 || tickSpacing_ <= 0''', '''                || tickSpacing_ <= 0''')
rep('''        poolManager = poolManager_;
        token = token_;''', '''        poolManager = poolManager_;
        quote = quote_;
        token = token_;''')
rep('''        lpFee = lpFee_;
''', '')
rep('''        rebalanceQuoteThreshold = 0.1 ether;
        keeperReward = 0.002 ether; // small default tip; owner tunes (≤ threshold, ≤ MAX_KEEPER_REWARD)''',
    '''        rebalanceQuoteThreshold = 40e18; // PondPad: 0.1 ETH -> 40 IMD
        keeperReward = 1e18; // PondPad: 0.002 ETH -> 1 IMD; owner tunes (≤ threshold, ≤ MAX_KEEPER_REWARD)''')
rep('''    receive() external payable {
        if (msg.sender != address(poolManager)) revert InvalidPoolManagerCaller();
    }

''', '')

# ---------- 5. pool key + fee view
rep('''            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(token),
            fee: lpFee,''', '''            currency0: Currency.wrap(quote), // PondPad: IMD instead of native ETH
            currency1: Currency.wrap(token),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG, // PondPad: fee set per swap by beforeSwap (D-34)''')
rep('''    function poolId() public view returns (PoolId) {''', '''    /// @notice PondPad: the LP fee charged on swaps right now: 3% at market open, linearly down to 1% at day 7,
    ///         then 1% forever. A fixed schedule with no setter (D-34).
    function currentFee() public view returns (uint24) {
        uint256 opened = marketOpenedAt;
        if (opened == 0) return START_FEE;
        uint256 elapsed = block.timestamp - opened;
        if (elapsed >= FEE_DECAY_PERIOD) return END_FEE;
        return uint24(START_FEE - (uint256(START_FEE - END_FEE) * elapsed) / FEE_DECAY_PERIOD);
    }

    function poolId() public view returns (PoolId) {''')
rep('''    /// bounded by `lpFee` applied to measured idle/converted IMD.''',
    '''    /// bounded by `currentFee()` applied to measured idle/converted IMD.''')

# ---------- 6. openMarket / fundInventory: ERC-20 quote pulled from the owner
rep('''    /// @dev Send at least the IMD v4 requires; the surplus is refunded.
    function openMarket(uint128 liquidity, uint256 maximumTokenAmount, uint256 capFloor_, uint256 capDecayTokensPerDay_)
        external
        payable
        onlyOwner
    {''', '''    /// @dev PondPad: pulls the IMD and tokens v4 requires from the owner (approve both first), up to the maxima.
    function openMarket(
        uint128 liquidity,
        uint256 maximumTokenAmount,
        uint256 maximumQuoteAmount,
        uint256 capFloor_,
        uint256 capDecayTokensPerDay_
    ) external onlyOwner {''')
rep('''            _unlock(abi.encode(ACTION_OPEN, abi.encode(msg.sender, liquidity, msg.value, maximumTokenAmount)));''',
    '''            _unlock(abi.encode(ACTION_OPEN, abi.encode(msg.sender, liquidity, maximumQuoteAmount, maximumTokenAmount)));''', 2)
rep('''        marketOpen = true;
        positionLiquidity = liquidity;''', '''        marketOpen = true;
        marketOpenedAt = block.timestamp; // PondPad: starts the fee schedule
        positionLiquidity = liquidity;''')
rep('''        if (msg.value > quoteDeposited) SafeTransferLib.safeTransferETH(msg.sender, msg.value - quoteDeposited);
        emit MarketOpened''', '''        emit MarketOpened''')
rep('''    /// proportional, so this consumes both tokens and IMD; send at least what v4 asks for and the
    /// surplus is refunded.
    function fundInventory(uint128 liquidity, uint256 maximumTokenAmount) external payable onlyOwner {''',
    '''    /// proportional, so this consumes both tokens and IMD; PondPad: both are pulled from the owner, up to the
    /// maxima.
    function fundInventory(uint128 liquidity, uint256 maximumTokenAmount, uint256 maximumQuoteAmount)
        external
        onlyOwner
    {''')
rep('''        if (msg.value > quoteDeposited) SafeTransferLib.safeTransferETH(msg.sender, msg.value - quoteDeposited);
        emit InventoryFunded''', '''        emit InventoryFunded''')

# ---------- 7. closeMarket / withdrawRetainedQuote / keeper: IMD transfers
rep('''        uint256 bal = address(this).balance;''', '''        uint256 bal = SafeTransferLib.balanceOf(quote, address(this));''')
rep('''        if (quoteToSend != 0) SafeTransferLib.safeTransferETH(recipient, quoteToSend);''',
    '''        if (quoteToSend != 0) SafeTransferLib.safeTransfer(quote, recipient, quoteToSend);''')
rep('''        SafeTransferLib.safeTransferETH(recipient, amount);''', '''        SafeTransferLib.safeTransfer(quote, recipient, amount);''')
rep('''        SafeTransferLib.safeTransferETH(keeper, reward);''', '''        SafeTransferLib.safeTransfer(quote, keeper, reward);''')
rep('''        uint256 feeBound = workValue.fullMulDiv(lpFee, FEE_DENOMINATOR);''',
    '''        uint256 feeBound = workValue.fullMulDiv(currentFee(), FEE_DENOMINATOR); // PondPad: was lpFee''')

# ---------- 8. _payQuote: ERC-20 settle
rep('''            poolManager.burn(address(this), _currencyId(address(0)), fromClaims);
        }
        uint256 rest = amount - fromClaims;
        if (rest != 0) poolManager.settle{value: rest}();''', '''            poolManager.burn(address(this), _currencyId(quote), fromClaims);
        }
        uint256 rest = amount - fromClaims;
        if (rest != 0) {
            // PondPad: ERC-20 settle instead of a payable settle.
            poolManager.sync(Currency.wrap(quote));
            SafeTransferLib.safeTransfer(quote, address(poolManager), rest);
            poolManager.settle();
        }''')

# ---------- 9. remaining native-currency ids / takes
s = s.replace('_currencyId(address(0))', '_currencyId(quote)')
s = s.replace('CurrencyLibrary.ADDRESS_ZERO', 'Currency.wrap(quote)')
rep('import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";', 'import {Currency} from "v4-core/types/Currency.sol";')

# ---------- 10. hooks: permissions + beforeSwap
rep('''            beforeSwap: false,
            afterSwap: true,''', '''            beforeSwap: true, // PondPad: sets the dynamic fee
            afterSwap: true,''')
rep('''    /// @notice Applies the cap, then rebalances the backstop.''', '''    /// @notice PondPad: returns this swap's LP fee from the fixed schedule (D-34). No delta, so pricing and
    /// quoting are unchanged apart from the fee level.
    function beforeSwap(address, PoolKey calldata key, SwapParams calldata, bytes calldata)
        external
        view
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        _requirePoolManagerAndPool(key);
        return (
            IHooks.beforeSwap.selector,
            BeforeSwapDeltaLibrary.ZERO_DELTA,
            currentFee() | LPFeeLibrary.OVERRIDE_FEE_FLAG
        );
    }

    /// @notice Applies the cap, then rebalances the backstop.''')

# ---------- 11. _addPosition: ERC-20 quote from payer
rep('''        uint256 quoteBudget,
        uint256 maxTokens''', '''        uint256 maxQuote,
        uint256 maxTokens''')
rep('''        if (quoteBudget < quoteRequired) revert IncorrectQuoteAmount(quoteRequired, quoteBudget);''',
    '''        if (quoteRequired > maxQuote) revert IncorrectQuoteAmount(quoteRequired, maxQuote);''')
rep('''        if (quoteRequired != 0) poolManager.settle{value: quoteRequired}();''', '''        if (quoteRequired != 0) {
            // PondPad: ERC-20 settle instead of a payable settle.
            poolManager.sync(Currency.wrap(quote));
            if (payer == address(0)) {
                SafeTransferLib.safeTransfer(quote, address(poolManager), quoteRequired);
            } else {
                SafeTransferLib.safeTransferFrom(quote, payer, address(poolManager), quoteRequired);
            }
            poolManager.settle();
        }''')
rep('''            (address payer, uint128 liquidity, uint256 suppliedQuote, uint256 maxTokens) =
                abi.decode(payload, (address, uint128, uint256, uint256));
            return _addPosition(payer, tickLower, tickUpper, liquidity, suppliedQuote, maxTokens);''',
    '''            (address payer, uint128 liquidity, uint256 maxQuote, uint256 maxTokens) =
                abi.decode(payload, (address, uint128, uint256, uint256));
            return _addPosition(payer, tickLower, tickUpper, liquidity, maxQuote, maxTokens);''')

# ---------- 12. seedRetainedQuote (migration support, D-40)
rep('''    /// @notice Sends the accumulated trading-fee revenue''', '''    /// @notice PondPad: adds IMD to `retainedQuote` from the owner, so the next keeper rebalance deploys it as
    /// backstop. Used only when MarketController migrates a market: the old market's retained / backstop IMD,
    /// which does not fit the full-range position at the same price, carries over as the new market's buy wall
    /// instead of going anywhere else (D-40). Backed by real balance, which `_payQuote` already handles.
    function seedRetainedQuote(uint256 amount) external onlyOwner {
        if (!marketOpen) revert MarketNotOpen();
        if (amount == 0) return;
        SafeTransferLib.safeTransferFrom(quote, msg.sender, address(this), amount);
        retainedQuote += amount;
        emit RetainedQuoteSeeded(amount);
    }

    /// @notice Sends the accumulated trading-fee revenue''')
rep('''    event RetainedQuoteWithdrawn(address indexed recipient, uint256 amount);''', '''    event RetainedQuoteWithdrawn(address indexed recipient, uint256 amount);
    event RetainedQuoteSeeded(uint256 amount); // PondPad''')
rep('''    4. v4-core types come from `PoolOperation.sol` in the pinned v4-core; compiled for cancun.''', '''    4. v4-core types come from `PoolOperation.sol` in the pinned v4-core; compiled for cancun.
    5. `seedRetainedQuote`: lets MarketController carry retained IMD into a new market when it migrates (D-40).''')
rep('''  The owner is MarketController, which does not expose `closeMarket` or `withdrawRetainedQuote` (D-18).''', '''  The owner is MarketController. It never exposes `withdrawRetainedQuote`; it calls `closeMarket` only inside
  `migrate`, which moves everything into a new market hook (7-day timelock, first 12 months only, D-40).''')

# ---------- 13. inheritFeeSchedule (migration keeps the original fee clock, D-40)
rep('''    /// @notice Sends the accumulated trading-fee revenue''', '''    /// @notice PondPad: on migration, the new market continues the old market's fee schedule instead of
    /// restarting at 3%. The start can only move earlier, so the fee can only go down, never up (D-40).
    function inheritFeeSchedule(uint256 openedAt) external onlyOwner {
        if (!marketOpen || openedAt == 0 || openedAt > marketOpenedAt) revert InvalidConfiguration();
        marketOpenedAt = openedAt;
    }

    /// @notice Sends the accumulated trading-fee revenue''')
rep('''    5. `seedRetainedQuote`: lets MarketController carry retained IMD into a new market when it migrates (D-40).''','''    5. `seedRetainedQuote` and `inheritFeeSchedule`: let MarketController carry retained IMD and the fee clock into
       a new market when it migrates (D-40).''')

code = '\n'.join(l.split('//')[0] for l in s.splitlines())
for bad in ['msg.value', 'settle{value', 'safeTransferETH', 'lpFee', ' ether', 'external payable']:
    assert bad not in code, (bad, [l for l in s.splitlines() if bad in l.split('//')[0]])
open('src/PadMarketHook.sol', 'w').write(s)
print('ok')
