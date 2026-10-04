// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {FullMath} from "v4-core/libraries/FullMath.sol";
import {SafeCast} from "v4-core/libraries/SafeCast.sol";
import {TransientStateLibrary} from "v4-core/libraries/TransientStateLibrary.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary, toBeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";
import {PadConfig} from "./PadConfig.sol";
import {PadToken} from "./PadToken.sol";
import {CoinFees, FeeParts, FeeLib} from "./FeeLib.sol";

interface IFeeSinkHook {
    function credit(address coin, uint256 amount) external;
}

/// @title PadHook
/// @notice Uniswap v4 hook for graduated PondPad coins. It creates each coin's pool at graduation, owns the pool's
///         full-range liquidity forever (there is no function to remove it), and charges the coin's fee on the IMD
///         side of every swap, whichever router sends it.
/// @dev Pool LP fee is 0; the hook takes the whole fee through return deltas. Fees are held as PoolManager ERC-6909
///      claims and flushed to their destinations outside of any foreign unlock. A swap whose IMD amount is the
///      specified side must fill completely: a partial fill (price limit hit) reverts instead of being overcharged.
contract PadHook is IHooks, IUnlockCallback {
    using SafeTransferLib for address;
    using SafeCast for uint256;
    using PoolIdLibrary for PoolKey;
    using TransientStateLibrary for IPoolManager;
    using StateLibrary for IPoolManager;

    int24 public constant TICK_SPACING = 200;
    uint256 internal constant BPS = 10_000;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
    uint8 internal constant ACTION_SEED = 1;
    uint8 internal constant ACTION_FLUSH = 2;
    /// @dev Transient slots for the fee and expected pool amount of a specified-IMD swap.
    bytes32 internal constant FEE_SLOT = keccak256("pondpad.hook.fee");
    bytes32 internal constant EXPECTED_SLOT = keccak256("pondpad.hook.expected");

    IPoolManager public immutable poolManager;
    address public immutable imd;
    PadConfig public immutable config;
    address public immutable creatorVault;
    address public immutable swarmBudget;
    address internal immutable _deployer;

    address public curve;
    address public router;

    struct Market {
        bool imdIsCurrency0;
        bool live;
        CoinFees fees;
    }

    struct Pending {
        uint128 protocol;
        uint128 creator;
        uint128 holders;
        uint128 swarm;
    }

    mapping(address coin => Market) internal _markets;
    mapping(PoolId => address coin) public coinOfPool;
    mapping(address coin => Pending) public pending;

    event MarketOpened(address indexed coin, PoolId indexed poolId, uint160 sqrtPriceX96, uint128 liquidity);
    event Trade(
        address indexed coin, address indexed trader, bool isBuy, uint256 imdAmount, uint256 tokenAmount, uint256 fee
    );
    event FeesFlushed(address indexed coin, uint256 protocol, uint256 creator, uint256 holders, uint256 swarm);

    error Unauthorized();
    error AlreadyInitialized();
    error NotPoolManager();
    error OnlySelf();
    error UnknownPool();
    error PartialFill();
    error ZeroFill();
    error HookNotImplemented();

    constructor(
        IPoolManager poolManager_,
        address imd_,
        address config_,
        address creatorVault_,
        address swarmBudget_,
        address deployer_
    ) {
        poolManager = poolManager_;
        imd = imd_;
        config = PadConfig(config_);
        creatorVault = creatorVault_;
        swarmBudget = swarmBudget_;
        _deployer = deployer_;
        Hooks.validateHookPermissions(IHooks(address(this)), getHookPermissions());
    }

    function initialize(address curve_, address router_) external {
        if (msg.sender != _deployer) revert Unauthorized();
        if (curve != address(0)) revert AlreadyInitialized();
        curve = curve_;
        router = router_;
    }

    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    function getHookPermissions() public pure returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: true,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // ------------------------------------------------------------------ Graduation

    /// @notice Opens the coin's v4 pool at the price implied by the two amounts and adds them as full-range
    ///         liquidity owned by this hook. Called once by the bonding curve, which has already sent both amounts.
    function graduate(address coin, uint256 imdAmount, uint256 tokenAmount, CoinFees calldata fees) external {
        if (msg.sender != curve) revert Unauthorized();
        bool imdIs0 = imd < coin;
        _markets[coin] = Market({imdIsCurrency0: imdIs0, live: true, fees: fees});
        PoolKey memory key = poolKey(coin);
        coinOfPool[key.toId()] = coin;

        (uint256 amount0, uint256 amount1) = imdIs0 ? (imdAmount, tokenAmount) : (tokenAmount, imdAmount);
        uint160 sqrtPriceX96 =
            uint160(FixedPointMathLib.sqrt(FullMath.mulDiv(amount1, 1 << 192, amount0)));
        poolManager.initialize(key, sqrtPriceX96);
        poolManager.unlock(abi.encode(ACTION_SEED, abi.encode(coin, amount0, amount1, sqrtPriceX96)));
    }

    function _seed(address coin, uint256 amount0, uint256 amount1, uint160 sqrtP) internal {
        PoolKey memory key = poolKey(coin);
        uint160 sqrtL = TickMath.getSqrtPriceAtTick(TickMath.minUsableTick(TICK_SPACING));
        uint160 sqrtU = TickMath.getSqrtPriceAtTick(TickMath.maxUsableTick(TICK_SPACING));
        uint256 l0 = FullMath.mulDiv(amount0, FullMath.mulDiv(sqrtP, sqrtU, Q96), sqrtU - sqrtP);
        uint256 l1 = FullMath.mulDiv(amount1, Q96, sqrtP - sqrtL);
        uint128 liquidity = (l0 < l1 ? l0 : l1).toUint128();

        (BalanceDelta delta,) = poolManager.modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: TickMath.minUsableTick(TICK_SPACING),
                tickUpper: TickMath.maxUsableTick(TICK_SPACING),
                liquidityDelta: int256(uint256(liquidity)),
                salt: 0
            }),
            ""
        );
        _pay(key.currency0, uint256(int256(-delta.amount0())));
        _pay(key.currency1, uint256(int256(-delta.amount1())));

        // Rounding dust: leftover coin tokens are burned, leftover IMD goes to growth.
        uint256 tokenDust = SafeTransferLib.balanceOf(coin, address(this));
        if (tokenDust != 0) PadToken(coin).burn(tokenDust);
        uint256 imdDust = SafeTransferLib.balanceOf(imd, address(this));
        if (imdDust != 0) imd.safeTransfer(config.growthFund(), imdDust);

        emit MarketOpened(coin, key.toId(), sqrtP, liquidity);
    }

    function _pay(Currency currency, uint256 amount) internal {
        if (amount == 0) return;
        poolManager.sync(currency);
        Currency.unwrap(currency).safeTransfer(address(poolManager), amount);
        poolManager.settle();
    }

    // ------------------------------------------------------------------ Hook callbacks

    function beforeInitialize(address sender, PoolKey calldata, uint160) external view onlyPoolManager returns (bytes4) {
        if (sender != address(this)) revert OnlySelf();
        return IHooks.beforeInitialize.selector;
    }

    function beforeAddLiquidity(address sender, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        view
        onlyPoolManager
        returns (bytes4)
    {
        if (sender != address(this)) revert OnlySelf();
        return IHooks.beforeAddLiquidity.selector;
    }

    /// @dev The hook never removes liquidity and nobody else can hold a position, so every removal is rejected.
    function beforeRemoveLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        view
        onlyPoolManager
        returns (bytes4)
    {
        revert OnlySelf();
    }

    function beforeSwap(address, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        external
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        address coin = coinOfPool[key.toId()];
        if (coin == address(0)) revert UnknownPool();
        Market memory m = _markets[coin];
        bool exactIn = params.amountSpecified < 0;
        // Charge here only when IMD is the specified currency (exact-in buy, exact-out sell).
        if ((exactIn == params.zeroForOne) != m.imdIsCurrency0) {
            return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }
        uint256 feeBps = FeeLib.totalBps(m.fees);
        uint256 amount = exactIn ? uint256(-params.amountSpecified) : uint256(params.amountSpecified);
        // exact-in buy: fee on what the buyer pays. exact-out sell: fee on the gross the pool pays out.
        uint256 fee = exactIn ? (amount * feeBps) / BPS : (amount * feeBps) / (BPS - feeBps);
        uint256 expected = exactIn ? amount - fee : amount + fee;
        _charge(coin, m.fees, fee);
        bytes32 feeSlot = FEE_SLOT;
        bytes32 expectedSlot = EXPECTED_SLOT;
        assembly ("memory-safe") {
            tstore(feeSlot, fee)
            tstore(expectedSlot, expected)
        }
        return (IHooks.beforeSwap.selector, toBeforeSwapDelta(fee.toInt128(), 0), 0);
    }

    function afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external onlyPoolManager returns (bytes4, int128 hookDelta) {
        address coin = coinOfPool[key.toId()];
        Market memory m = _markets[coin];
        bool exactIn = params.amountSpecified < 0;
        int128 q = m.imdIsCurrency0 ? delta.amount0() : delta.amount1();
        int128 t = m.imdIsCurrency0 ? delta.amount1() : delta.amount0();
        uint256 poolImd = uint256(int256(q < 0 ? -q : q));
        uint256 tokenAmount = uint256(int256(t < 0 ? -t : t));
        if (poolImd == 0 || tokenAmount == 0) revert ZeroFill();

        uint256 fee;
        if ((exactIn == params.zeroForOne) == m.imdIsCurrency0) {
            bytes32 feeSlot = FEE_SLOT;
            bytes32 expectedSlot = EXPECTED_SLOT;
            uint256 expected;
            assembly ("memory-safe") {
                fee := tload(feeSlot)
                expected := tload(expectedSlot)
                tstore(feeSlot, 0)
                tstore(expectedSlot, 0)
            }
            if (poolImd != expected) revert PartialFill();
        } else {
            uint256 feeBps = FeeLib.totalBps(m.fees);
            // exact-in sell: fee on the pool's IMD output. exact-out buy: fee on what the buyer pays in total.
            fee = exactIn ? (poolImd * feeBps) / BPS : (poolImd * feeBps) / (BPS - feeBps);
            _charge(coin, m.fees, fee);
            hookDelta = fee.toInt128();
        }

        bool isBuy = params.zeroForOne == m.imdIsCurrency0;
        address trader = sender == router && hookData.length == 32 ? abi.decode(hookData, (address)) : sender;
        emit Trade(coin, trader, isBuy, isBuy ? poolImd + fee : poolImd - fee, tokenAmount, fee);
        return (IHooks.afterSwap.selector, hookDelta);
    }

    /// @dev The swap credits the hook `fee` IMD; minting claims of the same size settles that credit.
    function _charge(address coin, CoinFees memory fees, uint256 fee) internal {
        if (fee == 0) return;
        FeeParts memory p = FeeLib.split(fees, fee);
        Pending storage pd = pending[coin];
        pd.protocol += uint128(p.protocol);
        pd.creator += uint128(p.creator);
        pd.holders += uint128(p.holders);
        pd.swarm += uint128(p.swarm);
        poolManager.mint(address(this), CurrencyLibrary.toId(Currency.wrap(imd)), fee);
    }

    // ------------------------------------------------------------------ Fee flush

    /// @notice Sends a coin's pending fees to the fee splitter, creator vault, swarm budget and holders.
    ///         Anyone can call it outside an unlock. Inside an unlock only the router may, because it controls its
    ///         whole unlock; any other mid-unlock call leaves the fees pending.
    function flush(address coin) external {
        if (poolManager.isUnlocked()) {
            if (msg.sender == router) _flush(coin);
            return;
        }
        poolManager.unlock(abi.encode(ACTION_FLUSH, abi.encode(coin)));
    }

    function _flush(address coin) internal {
        Pending memory p = pending[coin];
        uint256 total = uint256(p.protocol) + p.creator + p.holders + p.swarm;
        if (total == 0) return;
        delete pending[coin];
        Currency c = Currency.wrap(imd);
        poolManager.burn(address(this), CurrencyLibrary.toId(c), total);
        poolManager.take(c, address(this), total);

        if (p.protocol != 0) imd.safeTransfer(config.feeSplitter(), p.protocol);
        if (p.creator != 0) {
            imd.safeTransfer(creatorVault, p.creator);
            IFeeSinkHook(creatorVault).credit(coin, p.creator);
        }
        if (p.swarm != 0) {
            imd.safeTransfer(swarmBudget, p.swarm);
            IFeeSinkHook(swarmBudget).credit(coin, p.swarm);
        }
        if (p.holders != 0) {
            imd.safeTransfer(coin, p.holders);
            PadToken(coin).distribute();
        }
        emit FeesFlushed(coin, p.protocol, p.creator, p.holders, p.swarm);
    }

    function unlockCallback(bytes calldata data) external onlyPoolManager returns (bytes memory) {
        (uint8 action, bytes memory payload) = abi.decode(data, (uint8, bytes));
        if (action == ACTION_SEED) {
            (address coin, uint256 amount0, uint256 amount1, uint160 sqrtP) =
                abi.decode(payload, (address, uint256, uint256, uint160));
            _seed(coin, amount0, amount1, sqrtP);
        } else {
            _flush(abi.decode(payload, (address)));
        }
        return "";
    }

    // ------------------------------------------------------------------ Views

    function poolKey(address coin) public view returns (PoolKey memory key) {
        Market storage m = _markets[coin];
        if (!m.live) revert UnknownPool();
        (address c0, address c1) = m.imdIsCurrency0 ? (imd, coin) : (coin, imd);
        key = PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: 0,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(this))
        });
    }

    function marketOf(address coin) external view returns (Market memory) {
        return _markets[coin];
    }

    // ------------------------------------------------------------------ Unused hook callbacks

    function afterInitialize(address, PoolKey calldata, uint160, int24) external pure returns (bytes4) {
        revert HookNotImplemented();
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure returns (bytes4, BalanceDelta) {
        revert HookNotImplemented();
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure returns (bytes4, BalanceDelta) {
        revert HookNotImplemented();
    }

    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        revert HookNotImplemented();
    }

    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        revert HookNotImplemented();
    }
}
