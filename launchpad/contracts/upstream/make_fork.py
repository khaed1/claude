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

# ---------- 14. inheritGuards (migration keeps the placement guard, reference tick and cap; audit R1-A2-2/3)
rep('''    /// @notice Sends the accumulated trading-fee revenue''', '''    /// @notice PondPad: on migration, the new market keeps the old market's backstop placement floor, its
    /// block-lagged reference tick and its inventory cap, instead of reseeding them from the price in the
    /// migration block. Without this, whoever runs a migration could pump spot first and the new market's
    /// backstop could then be placed at the pumped price (audit R1-A2-2), and the cap would drop to the moved
    /// holdings in one step (R1-A2-3). The floor and the cap can only go up here (a higher floor only moves
    /// the bid to cheaper IMD; a higher cap only delays trims), so this can never loosen either guard.
    function inheritGuards(int24 floorTick, int24 refTick_, uint256 inventoryCap_) external onlyOwner {
        if (!marketOpen || refTick_ < TickMath.MIN_TICK || refTick_ > TickMath.MAX_TICK) {
            revert InvalidConfiguration();
        }
        if (floorTick > deploymentFloorTick) deploymentFloorTick = floorTick;
        refTick = refTick_;
        if (inventoryCap_ > inventoryCap) inventoryCap = inventoryCap_;
    }

    /// @notice Sends the accumulated trading-fee revenue''')
rep('''    5. `seedRetainedQuote` and `inheritFeeSchedule`: let MarketController carry retained IMD and the fee clock into
       a new market when it migrates (D-40).''', '''    5. `seedRetainedQuote`, `inheritFeeSchedule` and `inheritGuards`: let MarketController carry retained IMD,
       the fee clock, the backstop placement floor, the reference tick and the cap into a new market when it
       migrates (D-40, audit R1-A2-2/3).''')

# ---------- 15. audit round 2 (R2-A2-1, R2-A2-6, R2-A2-7)
# R2-A2-1: IMD that reaches retainedQuote without a trade (an owner closeBackstop, a migration seed) earns no keeper
# tip, so closeBackstop + rebalance in a loop can no longer pay the backstop out as tips.
rep('''    uint256 public retainedQuote;
''', '''    uint256 public retainedQuote;
    /// @notice PondPad (audit R2-A2-1): the part of `retainedQuote` that came back without a trade (an owner
    /// `closeBackstop`, a migration's `seedRetainedQuote`). Nobody paid a fee on it, so deploying it earns no
    /// keeper tip; otherwise `closeBackstop` + `rebalance` in a loop would pay the backstop out as tips.
    uint256 public untippedQuote;
''')
rep('''        uint256 tip = _keeperRewardDue(idleReady ? idle : 0, converted);
        if (_rebalanceGuarded(tip) && tip != 0) _payKeeper(msg.sender, tip);
    }''', '''        // PondPad (audit R2-A2-1): only idle IMD that came from trims qualifies for the tip.
        uint256 tippable = idle > untippedQuote ? idle - untippedQuote : 0;
        uint256 tip = _keeperRewardDue(idleReady ? tippable : 0, converted);
        if (_rebalanceGuarded(tip) && tip != 0) _payKeeper(msg.sender, tip);
        if (untippedQuote > retainedQuote) untippedQuote = retainedQuote; // what was deployed is no longer idle
    }''')
rep('''    /// the gate is only re-armed by fresh trims (or an owner `closeBackstop`, which is real work).''',
    '''    /// the gate is only re-armed by fresh trims (or an owner `closeBackstop`, which is real work but earns no
    /// tip: PondPad, audit R2-A2-1).''')
rep('''    function closeBackstop() external onlyOwner {
        if (backstop.liquidity == 0) return;
        _unlock(abi.encode(ACTION_CLOSE_BACKSTOP, bytes("")));
    }''', '''    function closeBackstop() external onlyOwner {
        if (backstop.liquidity == 0) return;
        uint256 before = retainedQuote;
        _unlock(abi.encode(ACTION_CLOSE_BACKSTOP, bytes("")));
        if (retainedQuote > before) untippedQuote += retainedQuote - before; // PondPad (audit R2-A2-1)
    }''')
rep('''        retainedQuote += amount;
        emit RetainedQuoteSeeded(amount);''', '''        retainedQuote += amount;
        untippedQuote += amount; // PondPad (audit R2-A2-1): no trade paid a fee on it
        emit RetainedQuoteSeeded(amount);''')
# R2-A2-7: a closed market stays closed (openMarket once per hook; migration targets are fresh hooks).
rep('''        if (marketOpen) revert AlreadyOpen();
        if (liquidity == 0) revert InvalidLiquidity();''', '''        if (marketOpen || marketOpenedAt != 0) revert AlreadyOpen(); // PondPad (R2-A2-7): never reopened
        if (liquidity == 0) revert InvalidLiquidity();''')
# R2-A2-6: two upstream comments that the fork made false.
rep('''    /// @dev The IMD leg of `_redeemClaims`, standalone. `take` to `address(this)` (via the PM-only
    /// `receive()`) can never be blocked by a token, so this always succeeds — it is the escape hatch's
    /// guarantee that a blacklisting/reverting token cannot strand retained IMD. Must run inside unlock.''',
    '''    /// @dev The IMD leg of `_redeemClaims`, standalone. PondPad (audit R2-A2-6): upstream took native ETH through
    /// a PoolManager-only `receive()`, which no token could block. Here the quote is IMD, an ERC-20: this succeeds
    /// as long as IMD (a LayerZero OFT, trusted in the threat model) never refuses a transfer to the hook. It still
    /// separates the IMD leg from the $PONDPAD leg, so a $PONDPAD settle failure can't strand retained IMD.
    /// Must run inside unlock.''')
rep('''    // The pool's 1% LP fee is the protocol's revenue.''', '''    // PondPad (audit R2-A2-6): the pool's LP fee (3% at open, falling to 1% over 7 days, D-34) is the protocol's revenue.''')
rep('''       migrates (D-40, audit R1-A2-2/3).''', '''       migrates (D-40, audit R1-A2-2/3).
    6. Audit round 2: an owner `closeBackstop` or a migration seed earns no keeper tip (`untippedQuote`, R2-A2-1); a
       closed market can never be reopened (R2-A2-7); two upstream comments corrected (R2-A2-6).''')

# ---------- 16. audit round 3 (R3-A2-3, R3-A3-2)
rep('import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";',
    'import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";\nimport {TransientStateLibrary} from "v4-core/libraries/TransientStateLibrary.sol";')
rep('    using StateLibrary for IPoolManager;\n', '    using StateLibrary for IPoolManager;\n    using TransientStateLibrary for IPoolManager;\n')
# R3-A3-2: the previous close has stood for every block since the last swap, so the reference may move one step per
# elapsed block, not one step per block that had a swap. Otherwise, after a crash and quiet blocks, the reference
# still sits at the pre-crash price and one pump-buy-dump block makes PadBuyer pay that price.
rep('''    /// reference — a distant poison then costs many consecutive block-edge captures. Pure snapshot — no
    /// liquidity op, no external call.
    function _observeTick() internal {
        if (block.number != refBlock) {
            int24 target = curBlockTick;
            int24 step = maxRefStep;
            int24 delta = target - refTick; // both are valid ticks; diff fits in int24
            if (delta > step) target = refTick + step;
            else if (delta < -step) target = refTick - step;
            refTick = target; // stays a valid tick: |target - refTick| <= |curBlockTick - refTick|''',
    '''    /// reference — a distant poison then costs many consecutive block-edge captures. Pure snapshot — no
    /// liquidity op, no external call.
    /// PondPad (audit R3-A3-2): the step is `maxRefStep` per block elapsed since the previous close (the block of
    /// the last swap), not per swapped block: that close has stood for every block since, so after quiet blocks the
    /// reference catches up with the price the market actually held instead of staying where it was before a move.
    /// Dragging it still needs the manipulated price to stand for one block per step, as before.
    function _observeTick() internal {
        if (block.number != refBlock) {
            int24 target = curBlockTick;
            uint256 blocks = block.number - refBlock;
            if (blocks > MAX_CATCHUP_BLOCKS) blocks = MAX_CATCHUP_BLOCKS;
            int256 step = int256(maxRefStep) * int256(blocks);
            int256 delta = int256(target) - int256(refTick);
            if (delta > step) target = int24(int256(refTick) + step);
            else if (delta < -step) target = int24(int256(refTick) - step);
            refTick = target; // stays a valid tick: |target - refTick| <= |curBlockTick - refTick|''')
rep('''    int24 internal constant MAX_TICK_RATE_CEIL = 2000;
''', '''    int24 internal constant MAX_TICK_RATE_CEIL = 2000;
    /// @dev PondPad (audit R3-A3-2): enough elapsed blocks to cross the whole tick range at the smallest step.
    uint256 internal constant MAX_CATCHUP_BLOCKS = 1 << 21;
''')
# R3-A2-3: a router that pays before it swaps (sync, transfer, swap, settle) settles against the PoolManager's synced
# reserves; a `take` of the synced currency inside its swap makes that settle fall short. Upstream took native ETH,
# which a synced ERC-20 settle never reads. So matured claims wait while IMD or $PONDPAD is synced; any later swap,
# settleClaims(), settleQuoteClaims() or rebalance() realises them.
rep('''    function _maybeRedeemMaturedClaims() internal {
        if (block.number <= lastClaimBlock) return;''', '''    function _maybeRedeemMaturedClaims() internal {
        if (block.number <= lastClaimBlock) return;
        // PondPad (audit R3-A2-3): not while the swapper has IMD or $PONDPAD synced for a pay-first settle.
        address synced = Currency.unwrap(poolManager.getSyncedCurrency());
        if (synced == quote || synced == token) return;''')
rep('''    6. Audit round 2: an owner `closeBackstop` or a migration seed earns no keeper tip (`untippedQuote`, R2-A2-1); a
       closed market can never be reopened (R2-A2-7); two upstream comments corrected (R2-A2-6).''', '''    6. Audit round 2: an owner `closeBackstop` or a migration seed earns no keeper tip (`untippedQuote`, R2-A2-1); a
       closed market can never be reopened (R2-A2-7); two upstream comments corrected (R2-A2-6).
    7. Audit round 3: `refTick` steps `maxRefStep` per block elapsed since the last swap (R3-A3-2); matured claims are
       not realised inside a swap while the swapper has IMD or $PONDPAD synced (R3-A2-3).''')

code = '\n'.join(l.split('//')[0] for l in s.splitlines())
for bad in ['msg.value', 'settle{value', 'safeTransferETH', 'lpFee', ' ether', 'external payable']:
    assert bad not in code, (bad, [l for l in s.splitlines() if bad in l.split('//')[0]])
open('src/PadMarketHook.sol', 'w').write(s)
print('ok')
