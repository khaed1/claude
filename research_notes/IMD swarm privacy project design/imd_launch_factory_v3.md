# IMD launch factory: what it can and cannot do (v3, fetched 10 Nov 2026)

Read-only design check. Nothing was signed, sent, posted or submitted. Live reads were made on **10 Nov 2026** in two
passes: 14:44 to ~15:00 UTC (Ethereum blocks 26,385,199 to 26,385,236; sections 1-5) and a second pass about eight hours
later at block 26,387,713 (section 6 and addenda 3a, 5a; the clock time of that block was not read).

STATUS OF THIS FILE: complete. Anything not checked is marked NOT VERIFIED; the full list is at the end.

## Summary of verdicts

| # | Question | Verdict |
|---|---|---|
| 1 | What is the launch factory | Verified: two immutable, ownerless contracts, callable only by IMD's deployer key |
| 2 | Token with no owner and no mint | Verified it can and usually does; enforced off chain, not by the factory |
| 3 | Where the 1% goes; contract recipient | Verified: 80% of a 1.25% Uniswap v4 LP fee, to a per-launch address that may be a contract |
| 4 | Pool type, pairing, lock | Verified: Uniswap v4, one-sided, position held by the factory with no exit |
| 5 | IMD token and main market | Verified: no transfer tax, no blacklist; owner key exists and controls the bridge mint path; main market is a hookless v4 ETH/IMD 1% pool |
| 6 | Seat concentration | Verified on chain: top 1 = 77, top 5 = 243, top 10 = 382 of 2,000 seats |

## Source keys

| Key | Source |
|---|---|
| DOCS | https://imd.fun/docs/llms.txt (158,265 bytes, the Markdown of https://imd.fun/docs/ and /docs/api/); line numbers refer to this file |
| CAP | https://api.imd.fun/requests/capabilities |
| L2978 | https://api.imd.fun/launches/bee25289-1960-476f-a21a-eef0759db6b2 (launch #2978 "Conditionals") |
| SRC | Sourcify, https://sourcify.dev/server/v2/contract/1/<address>?fields=all (verified source, ABI, deployment) |
| RPC | https://ethereum-rpc.publicnode.com (`eth_call`, `eth_getCode`, `extsload`); historical logs via https://rpc.mevblocker.io (`eth_getLogs`, 8,000-block chunks, blocks 26,128,670 to 26,385,211) |
| DEX | https://api.dexscreener.com/latest/dex/tokens/0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7 (14:53 UTC) |
| NOTES | earlier local notes in this folder (`imd_multisig_feature.md`, `imd_goals_and_state_v2.md`, `imd_pages_fetched.md`) |

Not reachable or not used in this run: etherscan.io HTML (curl returns 403; not retried through another tool, so
Etherscan's own "verified" badge for the factories is NOT VERIFIED here), api.github.com.

---

## 1. What is the launch factory?

**Verdict: Verified** (source on Sourcify + on-chain reads). Etherscan verification status not checked.

There are two factories on Ethereum mainnet, sharing one fee contract. Both are immutable (no proxy, no owner) and
both accept a launch from one wallet only.

| Contract | Address | Sourcify | Notes |
|---|---|---|---|
| LaunchFactory (hook launches, kind `univ4_hook`) | `0x12c63b581d07093f6126bc02263c58f7eadaa96f` | match (creation + runtime), verified 2026-10-08T17:44:20Z, `src/LaunchFactory.sol:LaunchFactory`, solc 0.8.26 | deployed block 26,128,678 by `0x047F606fD5b2BaA5f5C6c4aB8958E45CB6B054B7` (surfsurf.eth per NOTES) |
| ProjectFactory (`evm_project`, `custom_token`, `evm_contracts`) | `0xff03410d0fe5fa8f7f59f743de35e333d9857120` | match, verified 2026-10-08T20:50:20Z, `src/ProjectFactory.sol:ProjectFactory` | deployed block 26,128,681, same deployer |
| PoolInitializationGuard (pool hook of every ProjectFactory pool) | `0x784ff9a3ac5d88a30bfff6f7f2a270161fbe6000` | match, verified 2026-10-08T20:35:36Z | `factory()` = ProjectFactory |
| LaunchFees | `0x12c9e1007262afac205567457f5826a9416a3863` | match, verified 2026-10-12T08:49:26Z | Ownable2Step; `owner()` = `0x047f…54b7` (no code) |
| LaunchFactory registry | `0xa47fcb220ddd1cddda865f89029bec1b9eca3bf1` | no record under this address (404); its source `src/LaunchRegistry.sol` is inside the factory's verified bundle, and the factory constructs it | `count()` = 52 |
| ProjectFactory registry | `0x7c9d5ee697bff5ac4f10e2e54d3f40c44e48fe23` | same | `count()` = 489 |

DOCS line 2468 still says "None of the sources are verified on the explorers yet." That is out of date for Sourcify.

Evidence, source (SRC, LaunchFactory.sol):

> "/// @title The whole launch, in one transaction
> /// @notice Deploys the token and the hook at deterministic addresses, splits the supply per policy,
> /// initialises the pool, seeds it, funds the contributor distributor, and writes the public record —
> /// all or nothing."

> "This contract is immutable and permanent per chain: its address is an input to every CREATE2 address it produces"

> "/// @notice The one address allowed to launch. It holds the key that spends; this holds nothing.
> address public immutable deployer;" … "if (msg.sender != deployer) revert NotDeployer();"

ProjectFactory.sol:

> "Three doors. `launch` deploys the network's fixed-supply token and splits it the way a policy row says.
> `launchCustom` deploys a token the swarm wrote for a requester, with the requester's own pool share, opening price
> and remainder — and the swarm's share, `SWARM_BPS`, taken off the top before anything else, by this contract and not
> by any argument. `launchContracts` deploys only application contracts, with no token, distributor or pool"

On-chain (RPC, block 26,385,199): on both factories `deployer()` = `0xcecc29b037f5064fcdf45a5c318f132ef76aa551` (0 bytes
of code), `fees()` = LaunchFees, `poolManager()` = `0x000000000004444c5dc75cb358380d2e3de08a90`, `SWARM_BPS()` = 1000;
`owner()` reverts on both. Sourcify `proxyResolution.isProxy` = false for both.

DOCS line 2534: "Launch deployer | `0xcecc29b0…a551` | The only wallet either factory takes a launch from, on every chain."

**Who can use it.** Nobody outside IMD can call `launch` / `launchCustom`. A launch is ordered by paying 0.5 IMD
(`launch.open`, CAP) through the API or the on-chain Intake; IMD's control plane builds the parameters and its deployer
key sends the transaction. Every parameter the factory receives (token creation code, pool price, range, fee recipient,
Merkle root) is chosen off chain by that key. The factory only refuses combinations that do not add up.

**What one launch deploys** (one transaction): the token (CREATE2 from creation code passed in), a `MerkleDistributor`
funded with exactly 10% of supply, a Uniswap v4 pool seeded one-sided with the token, and a registry record. LaunchFactory
also deploys a per-launch hook; ProjectFactory deploys up to eight extra contracts and uses its one shared guard hook.

**Usage so far** (logs, blocks 26,128,670 to 26,385,211): `LaunchRecorded` events: custom_token 346, evm_contracts 110,
univ4_hook 52, evm_project 33. Pools opened: 431 (379 ProjectFactory, 52 LaunchFactory). Paired asset: IMD 359,
ETH 50, FWA 22.

Unknown: the off-chain admission rules beyond what DOCS state (the plane is closed source); whether the factories are
verified on Etherscan itself.

---

## 2. Can it issue a token with no owner and no mint function?

**Verdict: Verified that it can and routinely does. Not guaranteed by the factory: it is an off-chain rule.**

The factory has no token template. It deploys whatever creation code the deployer wallet passes:

> "/// @dev Creation code with constructor arguments already appended. The verifier attested the code without
> arguments; the deployer appends them and this recomputes what it deploys.
> bytes tokenCreationCode;" (SRC, LaunchFactory.sol)

The only on-chain token checks are at launch time:

> "The token must mint its whole supply to whoever deployed it, which is this contract. … the supply is checked as well
> as the balance: holding `totalSupply` proves nothing about a second mint to another wallet."
> `if (held != params.totalSupply || IERC20(token).totalSupply() != params.totalSupply) revert SupplyMismatch(...)`

Nothing in either factory inspects the token for an owner, a later mint, a pause or a blacklist. Those are refused (or
not) by IMD's off-chain check. DOCS:

> line 741: "On a project or hook launch the token is fixed: 1,000,000,000 with 18 decimals and plain transfers."
> line 737 (`customToken` on a hook launch): "Minted once and whole to the launch factory, nothing minted after launch,
> every transfer moves exactly what it asks, and no privileged address can move, freeze, pause or seize a holder's
> tokens; a fee on buys and sells is the hook's."
> line 742: "the check … refuses a transfer fee or minting after launch with an `own_token` blocker. Burning, freezing
> a holder pays for, limits and other rules are fine."
> line 1438: "`custom_token`: your supply and decimals, your pool share and opening cap. `economics` is required;
> `owner` is refused." (the `owner` here is the launch body field, not a property of the token)

**Templates actually deployed (verified source).**

- Standard token of project/hook launches, e.g. `0x8d035d90cfa100bfda2347b417fcddb24fba9b8f` (launch 972), Sourcify
  runtime match as `src/LaunchToken.sol:LaunchToken`:
  > "/// @notice EmberEVO (EMBEO), the standard fixed-supply launch token. … There are no constructor arguments,
  > extensions, privileged roles or later mint/burn entry points."
  > `contract LaunchToken is ERC20 { constructor() ERC20("EmberEVO", "EMBEO") { _mint(msg.sender, 1_000_000_000 * 10 ** 18); } }`
- Custom token example, launch #2978 COND `0x1fbf644110efe76184f9fd81cead18adef5e9420` (paired with IMD). Runtime code
  is 1,752 bytes with keccak `0xee1f97dd443307e3dcfa636a8560cccdcdd1a21a7c76e367468d32562d453746`, equal to
  `deployedCodeHash` in the launch's attestation (L2978). Sourcify runtime match: plain OpenZeppelin `ERC20` plus an
  `INITIAL_SUPPLY` constant. ABI functions: `INITIAL_SUPPLY, allowance, approve, balanceOf, decimals, name, symbol,
  totalSupply, transfer, transferFrom`. `owner()`, `getOwner()`, `mint(address,uint256)`, `paused()` all revert (RPC).
  L2978 manifest note: "Transfers move the exact requested amount, with no fees or taxes. There are no
  post-construction mint or burn functions, administrative p…".
  **130 custom_token launches share this exact runtime bytecode**; 34 more share a 1,753-byte sibling with the same
  selector set.

**Bytecode scan of all 431 launched tokens** (my script: PUSH4 constants in runtime code matched against a selector
list; opcodes scanned with push data skipped; block 26,385,222):

| Kind | Tokens | `mint(address,uint256)` / `mint(uint256)` / `mintTo` | `owner()`-family | `pause`/`paused` | blacklist/`freeze` | upgrade selectors | DELEGATECALL opcode | burn | permit |
|---|---|---|---|---|---|---|---|---|---|
| custom_token | 346 | 0 | 2 | 0 | 0 | 0 | 0 | 18 | 14 |
| evm_project | 33 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| univ4_hook | 52 | 0 | 2 | 0 | 2 | 0 | 0 | 6 | 1 |

- 240 of 431 tokens (202 of the 359 IMD-paired ones) contain nothing but the nine ERC-20 selectors, `INITIAL_SUPPLY`
  and OpenZeppelin error constants. This is a strict filter, so 240 is a lower bound for "plain".
- Tokens with an owner do exist, so the factory does not forbid one: launch 947 (custom_token, IMD pair,
  `0xf08b07b740df2aaa939eea6b7bf66b44908341b9`) has `owner()`, `pendingOwner()`, `transferOwnership(address)`,
  `renounceOwnership()`; launches 763, 2176 and 2503 have `owner()`; launches 2422 and 2503 have `freeze(address)`.
- No launched token is a proxy by this scan (no DELEGATECALL opcode, no upgrade selectors).
- Launch tokens are never fee-on-transfer on the swarm's leg by construction in ProjectFactory: "A token that taxes
  this transfer leaves the distributor short … so it is refused here" (`SwarmShareShort`).

Limits of this evidence: the scan finds named selectors only. For the ~190 non-plain tokens it does not prove the
absence of a privileged function under another name; each such token would need its own source read. For a new launch,
"no owner, no mint" is guaranteed only if (a) the request asks for it, (b) the delivered source is read before paying
(the repo is public under github.com/identity-md-launches), and (c) the deployed runtime hash is compared with the
attestation's `deployedCodeHash`, as done above for #2978.

---

## 3. Where does the "1% of every trade" go, and can the recipient be a contract?

**Verdict: Verified** (source + on-chain). One doc discrepancy found (network fee recipient).

**It is a pool fee, not a transfer tax.** The pool is a Uniswap v4 pool with a static LP fee of 1.25%
(`LaunchFees.poolFee()` = 12500, RPC; 430 of 431 pools carry fee 12500, one hook launch carries 3000). The factory is
the liquidity provider, so the LP fee accrues to the factory's position. Anyone may call `claimFees(launchNumber)`,
which collects and splits it. SRC, PoolFees.sol:

> "A factory owns the liquidity it seeds, so the fees that liquidity earns accrue to the factory. `claimFees` collects
> them for one launch and splits them: `REQUESTER_BPS` to the launch's requester (the wallet that paid for it, or
> whoever it handed the share to) and the rest to the network's recipient in `LaunchFees`, read at payout … Anyone may
> call it; nobody can send the fees anywhere else."

LaunchFees.sol:

> "/// @notice The requester's share of a pool's LP fees: 80%, which is 1% of volume at a 1.25% fee.
> uint16 public constant REQUESTER_BPS = 8000;"
> "The split itself is not here and cannot be changed: a requester was promised `REQUESTER_BPS` of their pool's fees
> when they paid, and an owner able to lower it would make that promise worth nothing. Only the recipient of the rest moves."

So "1%" = 80% of a 1.25% LP fee, paid in whichever currency the trader paid in (DOCS line 1800: "The fee arrives in
both of the pool's currencies."). It is not pushed per trade: it accrues in the pool until someone calls `claimFees`.

**Who the recipient is.** A per-launch storage field, `positions[launchNumber].requester`, set at launch from a
parameter the deployer supplies ("Who shares the pool's LP fees with the network: the wallet that paid for the launch,
or zero."). It is not `msg.sender` (that is always the deployer) and is not restricted to an EOA. DOCS lines 1789-1800:

> "The address that called `request`: your wallet, or your contract when the contract asks. Not `tx.origin`."
> "Your 1% of every trade | The payer | After the launch, the payer calls `setRequester(launchNumber, next)` on the
> factory that deployed it"
> "A payout a contract cannot take is kept owed to it on the factory, not lost; `OrdersALaunch` can hand the share on
> or withdraw it."

- At launch there is **no request field that names a different fee recipient**: it is the paying address. To have a
  contract receive from block one, the contract itself must be the payer (DOCS ships `OrdersALaunch`: "A launch with a
  pool: as payer, this contract earns 1% of every trade. Hand it on, or take it out.").
- After launch the current recipient can hand it to any nonzero address, contract or not:
  > `function setRequester(uint64 launchNumber, address next) external { … if (p.requester == address(0) || msg.sender != p.requester) revert NotRequester(launchNumber); if (next == address(0)) revert ZeroRequester(); … }`
  Only the current recipient can call it. There is no admin override and no way to renounce to the zero address.
- Payout mechanics: `claimFees` tries to pay; on failure the amount stays in `owed[account][currency]` and
  `withdraw(account, currency)` (callable by anyone, pays only `account`) retries. ETH is sent with a plain `call`,
  ERC-20 by `transfer`. A contract recipient therefore needs no special interface for ERC-20 legs, and needs a payable
  `receive` only for an ETH-paired pool.

On-chain use (logs): 431 `PositionOpened`, none with a zero requester; 5 `RequesterChanged` events (launches 1282, 1445
on ProjectFactory; 1785, 2321, 2843 on LaunchFactory), each to an address that has contract code today (1,702 to
12,592 bytes). 471 `FeesClaimed` events over 234 launches.

**Network share (0.25%).** On chain `LaunchFees.feeRecipient()` = `0x59b28f1f9680394d129adb10f2f19d4b1f1f2693`, a
`FeeRouter` contract (Sourcify match, verified 2026-10-21, deployed block 26,238,557), **not** the wallet DOCS line 2535
lists (`0x3f252e85…1f22`). FeeRouter source: "IMD to the chain's burn executor, every other token to Protocol Guild, and
ETH into IMD, bought in the chain's ETH/IMD pool and paid straight to the burn executor." `owner()` of FeeRouter and of
LaunchFees is the same code-less address `0x047f…54b7`, which can repoint `feeRecipient`, `treasury`, `guild` and
`burnExecutor` at any time.

Caveats that change the "1% of every trade" promise:
- It holds only while the factory's position is the in-range liquidity. On ProjectFactory pools anyone can add their
  own liquidity (the guard hook only gates `initialize`: "The address enables only beforeInitialize. Swaps, fees and
  liquidity ownership are unchanged."), and a third-party LP takes a pro-rata part of the fee.
- `LaunchFees.setPoolFee` (owner, up to 10%) changes the fee of pools opened later; existing pools keep theirs.
- On a hook launch the fee is "the fee their hook's launch sets", and the hook is custom code.
- DOCS line 603 context ("Contract wallets such as a Safe are not supported yet.") is quoted in NOTES; see section 3a.

Unknown: nothing on chain proves how the plane picks `requester` for an API (x402) payment versus an Intake payment;
the DOCS statement is the only source.

---

## 4. What pool does the factory create?

**Verdict: Verified.**

- **Venue:** Uniswap v4, the canonical PoolManager `0x000000000004444c5dc75cb358380d2e3de08a90` (DOCS line 2489: "Where
  launch pools live. Not deployed by IMD."). Not v2, v3 or an own AMM.
- **Hook:** ProjectFactory pools (`evm_project`, `custom_token`) all use `PoolInitializationGuard`
  `0x784f…6000` (379 of 379 on chain), whose only callback is `beforeInitialize` and only checks that the factory is
  initialising. LaunchFactory pools (`univ4_hook`) each get a hook written for that launch.
- **Fee and spacing:** ProjectFactory reads the fee from LaunchFees: "The fee is the chain's `LaunchFees` setting, not
  a launch parameter". Observed: fee 12500 (1.25%) on 430 pools, tick spacing 60 on 428.
- **Pair asset:** chosen per request with `pairWith`. CAP for chain 1 lists `eth` (default), `imd`
  (`0xd34a99bc…63b7`, custom opening cap between 250 and 250,000 IMD) and `fwa`. 359 of 431 pools are against IMD.
- **One-sided:** yes. DOCS line 743: "`poolBps` of the supply seeds the pool, single-sided in the launch token".
  LaunchFactory.sol: "The seed is the launched token only. Anything this factory holds in the paired currency is fees
  owed to other requesters and the network … so the seed must not spend it" (`PairedCurrencySpent`). The requester
  never supplies IMD or ETH liquidity. On chain for #2978 (block 26,385,208): position range ticks [-127140, 887220],
  pool tick -127176 (below the range, so the position is 100% launch token), price 3.0e-6 IMD per COND (= the
  3,000 IMD opening cap over 1e9 supply), PoolManager holds exactly 800,000,000 COND (`poolBps` 8000).
- **Who holds the LP position:** the factory contract itself, directly in the PoolManager (owner = factory, salt 0;
  no NFT, no PositionManager). #2978: `positionOf(2978)` returns the key and requester; position liquidity read from
  PoolManager storage = 1,388,091,186,815,324,813,106,340.
- **Locked:** permanently, by absence of any exit. The factories call `modifyLiquidity` in two places only: once with
  a positive amount when seeding, and with zero when collecting fees ("The principal is never touched: the only
  liquidity change is a zero one, which v4 treats as collecting."). There is no function that removes liquidity, no
  owner and no upgrade path. This is stronger than a time lock: neither the requester nor IMD can ever withdraw it.
- **Fixed supply split:** 10% always goes to the swarm's MerkleDistributor ("a constant, not a parameter"), `poolBps`
  (up to 9,000; at least the policy floor) to the pool, the rest to `remainderTo`. A paired design must accept that
  10% of supply goes to seat holders (8% per connected seat, 2% to workers), claimable after `contributorLockSeconds`,
  with unclaimed tokens swept to IMD's treasury address after the sweep delay.

Unknown: the policy floor for `poolBps` and the lock/sweep durations in force (set by the plane per policy version;
the distributor comment mentions "a six-month lock and a one-year sweep delay" but the live values were not read).

---

## 5. The IMD token itself

**Verdict: Verified** for token mechanics and pool identity; liquidity figures are point-in-time.

- **Address:** `0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7` (DOCS line 2474). Sourcify **exact match**, verified
  2026-03-28, contract `src/BridgedFP.sol:BridgedFP`, a LayerZero OFT (`contract BridgedFP is OFT`), deployed block
  23,501,863 by `0x047F…54B7`. Not a proxy.
- **RPC, block 26,385,229:** `name()` "Identity.md", `symbol()` "IMD", `decimals()` 18, `sharedDecimals()` 6,
  `totalSupply()` 4,213,302.77271 (Ethereum only; NOTES give about 7.08M across Ethereum, Base and Robinhood Chain on
  9 Nov).
- **Owner:** yes. `owner()` = `0x047f606fd5b2baa5f5c6c4ab8958e45cb6b054b7`, an address with no code (a plain key, not a
  Safe). The same address is the LayerZero endpoint delegate (`endpoint.delegates(IMD)`). Owner-only functions in the
  ABI: `setPeer`, `setDelegate`, `setEnforcedOptions`, `setMsgInspector`, `setPreCrime`, `updateName`, `updateSymbol`,
  `updateNameAndSymbol`, `transferOwnership`, `renounceOwnership`.
- **Mint:** there is no public `mint`/`burn` function (`mint(address,uint256)` and `burn(uint256)` revert). But supply
  on Ethereum is minted whenever a registered LayerZero peer sends a message: OFT.sol `_credit` → "Default OFT mints on
  dst. `_mint(_to, _amountLD);`". Registered peers read: eid 30184 → `0xab152db8…690a` (the Base bridge adapter in
  DOCS) and eid 30110 → `0x374080d8…a024` (which chain eid 30110 is was NOT VERIFIED here; the Robinhood Chain peer id
  was not identified). Because the owner can call `setPeer` and, as delegate, change the message-verification
  settings, **the owner key can in effect mint IMD on Ethereum**. "10M minted in 2023, none since" (DOCS) is a
  statement about practice, not a contract guarantee.
- **Transfer tax / fee-on-transfer:** none. `_update` is the unmodified OpenZeppelin v5.4.0 function (read in the
  verified bundle); BridgedFP overrides only `name()` and `symbol()`. `transfer` moves exactly the amount asked.
- **Blacklist / pause / freeze:** none in the ABI; probes for `paused()`, `blacklist(address)`, `isBlacklisted(address)`
  revert.
- **Where the "every sell burns" comes from:** not the token. It is done by a pool hook and by the FeeRouter (below).
  DOCS line 242: "Every sell in its pool burns a cut of supply, and so does every trade of a coin launched against it."

**Main market (verified on chain, differs from the docs' wording).**

| | Main pool | Second pool ("POOL4") |
|---|---|---|
| Venue | Uniswap v4 | Uniswap v4 |
| Pool id | `0xb07d640fd9e2eb9dc81b953c8e4fd006bdfeaf276010fb5418eb763ca15abfb3` | `0x415829f72e9f54531c26eae76f107618540e898a45d6ae35959e143f5faca704` |
| Pair | native ETH / IMD | native ETH / IMD |
| LP fee | 1% (10000) | 1% (10000) |
| Tick spacing | 200 | 60 |
| Hook | **none** (`0x000…000`) | `0xc6c965bd164c483e87d0b550671798e9a3602840`, `CappedBurnHook` (Sourcify exact match) |
| Initialised | block 25,640,607 | block 25,887,097 |
| DexScreener liquidity (14:53 UTC) | $1,137,907 (277,456 IMD + 250.0 ETH), 24h volume $342,083, price $2.22 | $99,733 (6,229 IMD + 41.5 ETH), 24h volume $4,386 |
| On chain (block 26,385,236) | in-range liquidity 9.50e21, i.e. about 310.7 ETH and 290,550 IMD of virtual reserves at the current tick; price 935.3 IMD per ETH | hook's position 6.68 ETH + 6,229 IMD, plus a 34.83 ETH backstop; `totalBurned()` 42,683 IMD |

- The pool id of the hookless pool equals the key stored in IMD's own FeeRouter (`imdPool()`: ETH, IMD, fee 10000,
  spacing 200, hooks 0), so IMD itself treats it as "the chain's ETH/IMD pool".
- DOCS line 264 says "All liquidity is in one pool: ETH/IMD on Uniswap v4, run by the POOL4 hook, which burns a cut of
  every sell." On chain about 92% of the ETH/IMD liquidity DexScreener reports is in the **hookless** pool, where a
  sell burns nothing. The burn applies only to sells routed through the hooked pool.
- The hooked pool is owner-custodied: only the hook may add liquidity (`LiquidityRestrictedToHook`), and
  `closeMarket(address recipient) external onlyOwner` carries the comment "the owner can withdraw the entire position
  at any moment, including from a healthy market. Holders are trusting the owner not to". `owner()` of the hook is the
  same code-less key `0x047f…54b7`.
- The main pool's `slot0` protocol-fee field reads 4,097,000 (= 1000 in each 12-bit half). I read that as a Uniswap
  protocol fee of 0.10% per direction on top of the 1% LP fee; this interpretation was not cross-checked.
- Launch pools hold no IMD at birth (one-sided), so a token paired against IMD gets its IMD-side depth only from buyers.

Unknown / not verified: who provides the liquidity in the hookless main pool and whether it can be withdrawn (see 5a);
Etherscan's label and holder list for IMD; the Base and Robinhood Chain token contracts (not re-read today).

---

## 6. Seat NFT ownership concentration

**Verdict: Verified on chain** (full enumeration, not a sample). Entity-level concentration cannot be verified.

Method: `ownerOf(tokenId)` for ids 0 to 2002 on `0x0000ec93127baa929e58e97dd0095a2bfb38ec1d` at block 26,387,713 (RPC,
batched `eth_call`). `name()` "identity.md", `symbol()` "IDMD", `totalSupply()` 2000. Ids 0 to 1999 each have an owner;
2000 and above revert.

- **2,000 seats, 791 distinct holding addresses.** (OpenSea shows 1,999 items and 794 owners, and IMD's API 795
  holders, per NOTES of 9 Nov; the one-item difference from OpenSea was not investigated. Percentages below are of
  2,000; against 1,999 they move by less than 0.01 point.)

| Group | Seats | Share of 2,000 |
|---|---|---|
| Top 1 holder | 77 | 3.85% |
| Top 5 | 243 | 12.15% |
| Top 10 | 382 | 19.10% |
| Top 20 | 588 | 29.40% |
| Top 50 | 910 | 45.50% |
| Top 100 | 1,154 | 57.70% |

- Smallest group that reaches one third of seats: 25 addresses. Smallest group that exceeds half: 65 addresses.
- 568 addresses hold exactly one seat (28.4% of seats). 38 addresses hold ten or more, 815 seats together (40.75%).
- Top ten addresses and seats: `0xb7a832db…e8ff` 77; `0xb64199cd…1d72` 54; `0x80271ce2…aca2` 48 (has 121 bytes of
  code, so a contract wallet of some kind, not identified); `0xe3de112a…d80c` 34; `0xabe0cdd0…98b1` 30;
  `0xd4bb7351…0f08` 30; `0xb19889f4…5dc2` 28; `0xf98c3bf5…c4db` 28; `0x7cc6f600…fc4e` 27; `0x6ba9ad59…742a` 26
  (`0xea24ea8f…bb64` also holds 26). Rank 21, `0x44bdd06d…5e7f` with 17 seats, is a contract with 8,299 bytes of code
  (not identified: could be a vault or an escrow holding seats for several people).
- **Connected seats are more concentrated than all seats.** In the reward snapshot of launch #2978 (L2978, taken
  2026-11-04T17:50Z) 1,033 seats were connected, held by 439 wallets: top 1 = 54 seats (5.23%), top 5 = 162 (15.68%),
  top 10 = 267 (25.85%). A registry that counts only seats that are online would see these higher shares.

What this means for "one seat = one vote":
- No single address is near control, but an address is not a person. One party can spread seats over many addresses,
  and nothing on chain links them. IMD's own (switched-off) jury design groups seats into "holder clusters" assembled
  off chain (NOTES, `imd_goals_and_state_v2.md` B.1), which shows IMD treats this as a real problem.
- Seats are transferable and cheap relative to a vote that matters: the floor was about 0.70 ETH on 10 Nov (NOTES).
  1,001 seats at that floor is roughly 700 ETH before slippage. This figure is my arithmetic from the NOTES floor, not
  a quoted source, and real cost would be higher because the floor is thin.
- The seat contract's `owner()` is the CREATE2 proxy, so its owner-only setters have no key behind them (NOTES, read
  9 Nov; not re-read today). Whether more seats can ever be minted was NOT VERIFIED in this run.

---

## Addenda

### 3a. Contract recipients in practice

- DOCS line 603 limits only the API payment path, not who can receive fees: "The wallet must sign with its own key: an
  ordinary account or an EIP-7702 account. Contract wallets such as a Safe are not supported yet." A contract can still
  pay through the on-chain Intake (the `OrdersALaunch` pattern), or receive the share later through `setRequester`.
- Contract as recipient **from the launch transaction**: launch 2442 (LaunchFactory, ETH pair) has had requester
  `0xb6b14c97f8a723501ae8bcc601f6a0d07fb28abe` (21,138 bytes of code today) since its `PositionOpened` event, and
  launch 1948 (ProjectFactory, IMD pair) has had `0xf9c003d5a247bb5282b2d6df534ed51860b14210` (123 bytes) since
  launch. I read the code at today's block, not at the launch block, so "was already a contract at launch" is an
  inference.
- Contract as recipient **after launch** via `setRequester`: launches 1282, 1445, 1785, 2321, 2843 (transaction hashes
  in the log extract; e.g. 1282: `0x94e47d543a1b8a99ad626f4913b8d8c33bc237e00dd0dd64ec4bf4d0f8fff98f`).
- 18 current requester addresses carry exactly 23 bytes of code. That length matches an EIP-7702 delegation marker,
  which fits the DOCS wording; I did not decode them.

### 5a. Who provides the main pool's liquidity

- All 1,626 `ModifyLiquidity` events of the hookless ETH/IMD pool since its creation were read (blocks 25,640,600 to
  26,385,235). 100% of the net liquidity was added through `0xbd216513d74c8cf14cf4747e6aaa6420ff64ee9e`, which matches
  the address I know as Uniswap's v4 PositionManager on mainnet (not re-checked against Uniswap's deployment list
  today). So the liquidity is ordinary NFT positions that their owners can withdraw at will; **nothing shows it is
  locked**. Who owns those position NFTs was NOT VERIFIED.
- 15 positions are live. The in-range depth is one full-range position (7.51e21 liquidity units, about 79% of in-range
  liquidity) plus one concentrated range (ticks 63800 to 69800, 1.93e21). The four other large positions sit at ticks
  39200 to 51800, far from the current tick 68411, and are IMD-only orders that trade only if IMD rises several-fold.
- Consequence for a token paired against IMD: its price in ETH or dollars rests on a main pool whose depth can be
  pulled by whoever holds those positions, and on a second pool the owner key can close.

---

## Could not verify (and why)

1. **Etherscan's own verification badges and labels** for the factories, LaunchFees, FeeRouter and the IMD token:
   etherscan.io returns 403 to curl in this session and was not retried another way. Sourcify verification is
   confirmed for each (registries excepted, see section 1).
2. **Off-chain admission rules.** What IMD's plane refuses in a token (owner, mint, tax) is known only from DOCS; the
   plane is closed source. On chain, the factory accepts any creation code from the deployer key.
3. **Absence of privileged functions in every non-plain launched token.** The selector scan covers named selectors
   only; about 190 tokens with extra constants were not read one by one.
4. **How `requester` is chosen for API (x402) payments**, and whether a launch body can ever name a different fee
   recipient: DOCS say it is the payer; no on-chain rule enforces that.
5. **Live `contributorLockSeconds`, sweep delay and the `poolBps` policy floor** for mainnet IMD pairings.
6. **Identity of LayerZero peer eid 30110 and the Robinhood Chain peer** of the IMD token; the DVN and library
   configuration behind the bridge (which decides how hard an illegitimate mint is) was not read.
7. **Owners of the main pool's liquidity positions**, and whether IMD's team is among them.
8. **The Uniswap protocol-fee reading** on the main pool (0.10% per direction) is my decoding of one storage field.
9. **Entity-level seat concentration** (one party behind several addresses), the two contract holders of seats, and
   whether the seat supply can grow.
10. **Base and Robinhood Chain deployments** of the factories and of IMD were not examined; everything above is
    Ethereum mainnet only.
11. DexScreener liquidity and volume are a third party's figures at 14:53 UTC; on-chain reserves were computed from
    in-range liquidity only and differ somewhat.

## Reproduction aids

- Function selectors used: `positionOf(uint64)`, `claimFees(uint64)`, `setRequester(uint64,address)`,
  `withdraw(address,address)` on either factory; `feeRecipient()`, `poolFee()`, `REQUESTER_BPS()` on LaunchFees;
  `imdPool()` on FeeRouter; `extsload(bytes32)` on the PoolManager (pool state slot = keccak256(poolId, 6)).
- Pool id = keccak256(abi.encode(currency0, currency1, fee, tickSpacing, hooks)).
- Launch #2978 transaction: `0xe03e7ba00711b498e442d4382f14f0bb79cb559899bb50d56ad781141c5ba457` (block 26,343,060).
