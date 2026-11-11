# Review of the unreviewed parts of Murmuration v4, and the design changes that follow (v3 note, 10 Nov 2026)

Scope: the pool, the token contracts, the fee auction and the screening registry as written in the first version 4 page
(commit dff405a). Method: for each part, the weakest assumption, the most likely failure and what was overbuilt, as
mechanisms. The findings and the fixes are written up for readers in `reports/Murmuration v4 specification.html`,
sections "Review of the new parts" and "Build specification". This note records the reasoning and the checks behind them.

Author's caveat: the review and the redesign were done by the same session. The changes are unreviewed until the review
jobs R01 to R05 in `reports/build_plan/` have run. An independent second review was started and was lost to a usage limit
before it wrote anything.

## 1. Findings, ranked

| # | Finding | Mechanism | Fix adopted |
|---|---|---|---|
| 1 | The seven-day fallback switches screening off for one third of the registry | Threshold was two thirds of *registered* screeners. Holders of more than one third stay silent for 7 days; the fallback then approves any deposit whose sender is not on the Chainalysis sanctions oracle. With 15 honest screeners: 8 seats, 5.6 ETH, resalable. Same outcome from attrition alone. The fallback also pins an immutable pool to an oracle with an owner key | No fallback. Fail closed: deposits wait or refund. Threshold over *active* screeners; silent ones evicted after 7 epochs |
| 2 | The reward index can pay more than the budget, can be farmed with dust, cannot be referenced by a proof, and leaks the asset | Daily step credits a note created at 23:59 with the full day; cycling around each update over-issues. Index += emission/total with total = 1 wei gives one note the whole period (42,578% a year nominal in the simulation). The index moves every block, so a proof built earlier is stale. A per-asset index must be a public input of a transfer that otherwise hides the asset | One global index with fixed per-asset weights. Exact index written on-chain at activation; spends use a 300-block checkpoint (current or previous), which always rounds against the spender. Divisor floor at a quarter of capacity. Reward carried in the note as `accrued`; claimed inside any spend |
| 3 | The 20% liquidity add can be taken by the auction's settler | Settler flash-buys the token to push spot up, the distributor places IMD one-sided below the inflated spot, settler sells into those bids in the same transaction | Proceeds are spent as a stepped buyback through the locked position and the bought tokens burned. Step at most half of fee rate times IMD-side virtual reserves; see section 3 |
| 4 | Caps: no end, counted in the wrong place, and outrun by the cost of capture | "6,400 ETH after two years" with no stop: three assets hold about $41M. If counted on deposits, a free refundable deposit holds the cap shut. Registry capture cost is flat (30 seats, about 21 ETH) while the cap doubles each 90 days | Cap counted on activated value only. Recommended stop at 800 ETH per asset (owner to confirm) |
| 5 | Screening at entry cannot remove funds identified after activation; the criteria are an open-book test | Fresh thefts are on no list within a day; public deterministic criteria can be simulated before depositing; v4 accepted any past root, so a later exclusion did not bind | On-chain flags by screeners as an input to the published rule; refusal bitmap read at activation, so only current state counts; criteria may hold deposits longer than the 7,200-block floor. The limit itself is stated in the spec |
| 6 | Pay per head rewards copying and seat concentration | Agreement-based pay with no commit-reveal: copy the first root. Aggregator chooses which signatures to include. One holder registers every seat (largest address: 77 of 2,000) | Commit and reveal; individual reveals; 30-epoch wait; minimum of seven active. Concentration is disclosed, not solved |
| 7 | The token's Uniswap pool can be created and priced by anyone before launch | `createPool` checks nothing about the token; `initialize` is first-come | `launch()` handles an existing pool and resets a wrong price with a bounded swap |
| 8 | The canary does not reach the schedule boundaries, the second asset, the token paths; and an attacker can wait | 90 days at production pace never crosses a cap step | Whole system, compressed clock (7-day steps), published coverage script; described as a rehearsal. Lawyer's review moves before the canary because it places a token pool |
| 9 | Three circuits where one suffices; the launch gate proved only one of them | Deposit circuit proves a hash the contract can compute. Transfer and withdraw differ by one public number | One circuit (2 in, 3 out, reward note, optional public amount). Proof obligations cover all of it |
| 10 | Fixed exit sizes with arbitrary deposits and a public relay fee | Exits to one address sum to the deposit; fee quote marks each exit; dust under the smallest size is stuck after deposits close | Shielded relay fee note so every exit of a size pays the same; smallest size 0.001 ETH; wallet defaults to standard-size deposits |
| 11 | Staking reward sniping | Stake before a lump sweep, unstake after | Each sweep streamed over 50,400 blocks |
| 12 | Stake has no slashing condition | Nothing objective to slash on | Kept as decided; described as a deposit; amount recommended at 0.05% of supply |

Smaller points: v4's "70,000 gas per note at the calldata floor" is the cost of a data-only transaction (the floor is
max(standard, floor) and does not bind for a spend); the risk table's "70% unlocks" should be 75%; "swarm locked up to one
year" conflicts with "every schedule runs two years"; a post-quantum receiving address carries a 1,216-byte key.

## 2. Design decisions that follow, and why

- **Public activation instead of a first-spend proof.** The deposit and its approval are public, so the label check needs
  no zero-knowledge. The contract computes `commitment = H3(packed, index, ownerCommit)` from the public amount and the
  depositor's hidden `ownerCommit`. This is what makes the exact index at entry possible, which is what makes the reward
  total provably at most the emission: entry exact, internal moves telescope at the checkpoint value, exit floored.
- **Depositor-only activation.** If anyone could activate, a fee recipient could force-activate approved deposits and
  remove the free refund.
- **One leaf per transaction** (`leaf = H4(C0..C3)`), so the tree code is the plain single-insert incremental tree and a
  spend costs 32 `H2` + 1 `H4` on-chain instead of a batch insert.
- **Shielded relay fee note** for transfers and withdrawals alike: no public fee, so no asset leak on transfers and
  uniform payouts on exits.
- **Refusals as a bitmap of words with absolute masks**, relative to on-chain state: no Merkle proofs at activation, and
  an unapplied batch cannot corrupt later ones.
- **Fail closed** also means a registry bug can stop deposits and cannot touch shielded funds.
- **Fee Flow shape for the auction** (Euler `FeeFlowController`, GPL-2.0-or-later; audits by OtterSec, Team Omega and
  Zellic in the repository) with two changes: a non-zero price floor, because in Fee Flow the price is 0 after one epoch
  and the basket is then free; and explicit basket balances.

## 3. Checks made in this session

**Uniswap v3 core, v1.0.0 source** (read from the tagged repository, 10 Nov 2026):
- `UniswapV3Factory.createPool`: requires only `tokenA != tokenB`, `token0 != address(0)`, an enabled fee tier and no
  existing pool. No check that either token has code. Fee tiers in the constructor: 500/10, 3000/60, 10000/200.
- `UniswapV3Pool.initialize`: `require(slot0.sqrtPriceX96 == 0, 'AI')`. Anyone, once.
- `swap`: loop `while (state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != sqrtPriceLimitX96)`; with zero
  liquidity each step moves the price to the next tick or the limit with zero amounts.

**Euler Fee Flow** (`src/FeeFlowController.sol`, 194 lines): `getPriceFromCache` returns
`initPrice - initPrice * timePassed / epochPeriod`, and `0` once `timePassed > epochPeriod`; `buy` transfers the full
balance of each named asset, sets `newInitPrice = paymentAmount * priceMultiplier / 1e18` clamped to `minInitPrice`, and
guards with `epochId`, `deadline`, `maxPaymentTokenAmount`.

**Sandwich bound** (`reports/sim/buyback_sandwich_bound.py`, output in `sandwich_results.md`): constant-product model on
virtual reserves (12,000 IMD, 25% of supply), fee on input. Best profit over all attacker sizes is zero for a step of
0.5 and 1.0 times `fee × IMD reserves`, and positive from 1.5 times (5.6% of the step at a 1% fee). Reason: the step
moves the price by `2B/y` and the round trip costs `2f`. My first estimate of `2 × f × y` was wrong by a factor of two;
the specification uses half of `f × y`.

**Economics** (`reports/sim/murmuration_economics.py`, output in `results.md`): one-sided range closed form
`IMD = 12,000 × f/(1−f)`, `price = start/(1−f)²`; 75% of supply unlocks in two years; pool IMD exhausted in month 14
with half the pool bought and half of unlocks sold; fee income capped by the caps ($377 a month in the first 90 days at
Railgun's turnover); reward 261 tokens per ETH per day on a full pool, 0.57% a year at the starting valuation.

## 4. Not verified

- Nothing was built. Constraint count (about 22,000), proving time and every gas figure are estimates or models.
- Whether Uniswap governance takes a protocol fee on v3 pools at the 1% tier.
- That a v3 position from the start tick to the maximum tick behaves as the unbounded closed form to within rounding
  (it should; the simulation uses a top of 10^12 times the start).
- The reward arithmetic bounds (weight < 2^64, value < 2^96, index < 2^90, product < 2^251) are by hand, not machine-checked.

## 5. Addendum, 10 and 11 November 2026: owner's decisions after revision 4.1

- **Exit sizes start at 0.005 ETH** (10 Nov). Seventeen sizes; any amount under 1,000 ETH leaves in at most 16 withdrawals
  (checked by enumerating every multiple of 0.005). A remainder under 0.005 ETH cannot leave by itself.
- **IMD is a listed asset with full reward weight** (11 Nov). My first recommendation was to leave it out; then to list it
  with zero weight, because I had described the owner key's power over the LayerZero bridge peers as a way to mint. The
  owner pointed out that IMD cannot mint and has a fixed supply of about 7.08M across chains (4.22M on Ethereum on 11 Nov,
  `totalSupply()`; `owner()` is still the code-less key `0x047f…54b7`). The precise statement is that one key administers
  the bridge on Ethereum. With that, full weight is defensible if the cap is small:
  - cap 2,500 IMD rising to 80,000 (about 1.1% of supply), which is 4.0% of the pool's weighted capacity at every step;
  - a full IMD cap earns 4.0% of emissions when the other assets are full, 7.6% at half, 14.2% at a quarter, and 15.9% at
    most, because the divisor floor is a quarter of capacity (`reports/sim/results.md`, section 5);
  - the reward token is priced in IMD, so a fall in IMD's dollar price does not raise the reward per IMD shielded;
  - an equal-dollar cap (about 645,000 IMD at the stop) was rejected: a circuit failure could put 9% of supply on a market
    with about $1.14M of liquidity.
- **Consequence in the FeeDistributor:** fees paid in IMD cannot sensibly be auctioned for IMD, so their 20% goes straight
  to `buybackImd`, an explicit balance kept apart from IMD owed to stakers; `fundBuyback(amount)` lets the Distribution
  contract add the position's IMD trading fees. The invariant "IMD leaves only through the swap" becomes "`buybackImd`
  falls only through the swap".
- **Residual risks recorded in the spec:** the weight is a price ratio frozen at deployment; one key administers IMD's
  bridge; IMD's deposits and withdrawals will be few, so its privacy at the edges is weak.

---

## Addendum, 11 November 2026: revision 4.2

Source for everything below unless stated: `adversarial_review_independent_v3.md` in this folder (the independent review of revision 4.1), and the owner's instructions in session.

### What happened

1. An independent reviewer, given only the published revision 4.1 page, found 1 critical and 6 high faults, 24 contradictions between sections and 28 points a builder would have had to guess. It confirmed 20 claims of the 4.1 review, including that total reward paid cannot exceed the emission.
2. The owner fixed the asset list: ETH, USDT, USDC, IMD, the pool's own token. DAI is out. My 4.1 recommendation (USDC and DAI, no USDT) was wrong on the evidence: USDT is the largest stablecoin in both screened pools (31.6% of Railgun's Ethereum balance, 71.7% of Privacy Pools'; `privacy_pool_asset_mix_v3.md`).
3. Revision 4.2 of the specification answers the review. The changes are rows R4.2-1 to R4.2-22 of the changelog on the history page.

### Design decisions taken in 4.2, and why

| Decision | Reason | Finding |
|---|---|---|
| Token created inside `Distribution.launch()` with CREATE2, salt = `prevrandao` and caller. Bounded price reset (0.1% of supply), revert beyond | The address was computable from the published build, so anyone could pre-create the Uniswap pool and block launch for ever for about $100. Only a builder of the launch block can still interfere, per attempt | 1 (F-LAUNCH-1, 1b) |
| A batch covers only deposits a day old at its epoch start. `isApproved(id, depositTime)` requires `depositTime + 1 day <= dataTime` | The reaction window was 0 to 1 day, not 1 to 2. Also bounds `upTo`: no batch can approve a deposit made after its data time | 2, 5 (F-SCR-1, F-SCR-2) |
| Top statement plus ten lemmas | The five properties were satisfied by circuits with no spend authority, a free nullifier position, a free output index or asset | 3 (F-CIR-2) |
| No launch shortcut for screeners | 77 seats in one address would have been two thirds on day seven | 4 (F-SCR-3) |
| Majority hash per epoch, 7 consecutive misses allow eviction | A third plus one revealing junk blocked deposits for ever and profited if inside. Cost accepted and stated: a majority held for a week controls the registry | 6 (F-SCR-4) |
| Public `roll()`, one shift per call, checkpoint roots saved | One reading of 4.1 bricked every spend. Checkpoint roots also defeat a 64-root flush | 7 (F-RWD-1, F-RWD-2), F-POOL-1 |
| Deterministic rho and diversifier, `gRef` in `Spent`, ciphertext layouts | A wallet could not be restored from its seed | 8 (F-WAL-1) |
| Buyback bound from the locked position's constant liquidity and the price, one step per 12 hours | "Reserves" was undefined and inflatable | 9 (F-FEE-1 to 3) |
| Flag quorum max(3, a third of active), expiry 14 epochs, no hop expansion; truncation rule for more than 96 words | Three seats could have any deposit refused | 10 (F-SCR-6, F-SCR-7) |
| Relay fee as public ETH from a third (ETH) input. 13 public inputs, about 31,000 constraints by estimate | Shielded fee notes doubled the user's gas and told the relayer the asset | F-POOL-3 |
| Entry fee on top of the deposit | 1 ETH became 0.998 and stranded dust against standard sizes | F-POOL-4 |
| Seconds from `GENESIS` everywhere | Block counts halve if slots shorten. `GENESIS` also keeps a published build from launching early | F-POOL-6, F-GATE-1 |
| Refund of a refused deposit by anyone; basket fed over seven days; streams pause with no stakers; screeners' 40% to stakers when no batch for seven epochs | See the review | F-POOL-5, F-FEE-4, F-FEE-5, F-SCR-14 |

### Not adopted

- Refusals that lapse unless renewed: a bloc that controls the registry renews them.
- A launch that never reverts: an unbounded reset hands the public allocation to whoever parked bids.
- A third ciphertext for the relayer: unnecessary once the relayer is paid in ETH.
- Anything against cap squatting paid by emissions (F-POOL-2): no rule inside an immutable pool separates a user from a farmer. Stated as a risk.

### Claims of mine in 4.1 that were wrong

Commit and reveal "so that copying is not possible"; "individual reveals so nobody can be left out"; blocking "earns them nothing"; "recovers from ordinary attrition by itself"; capture means only "a bad deposit approved"; "one to two days for screeners"; "the launch code handles a pool that already exists"; "that IMD stays in the pool as bids for good"; the canary "calls every function and every branch". The exposure figures $166,000 / $5.3M / $43M were also wrong: they priced each stablecoin cap at the value of 25 ETH. With caps of 25 ETH, 50,000 USDT, 50,000 USDC and 2,500 IMD the figures are $159,850 / $5,115,200 / $40,921,600 (`reports/sim/results.md`).

### Checked for 4.2

- USDT on Ethereum, read on-chain 11 November: `basisPointsRate` 0, `maximumFee` 0, not paused, not deprecated, 6 decimals. Its `transfer` returns no value. Source code not re-read (Sourcify returned 403).
- Simulation re-run on the decided asset list: two-year IMD to the buyback 21,863 ($57,719); full-pool reward 251.1 tokens per ETH per day, 0.55% a year at the starting price.

### Not verified

- Revision 4.2 itself. Nobody but its author has read it.
- Gas of the three-input spend (adjusted by hand: about 1,142,000 today, 1,476,000 under Glamsterdam, relayed) and of a 13-input verifier (extrapolated: about 269,000).
- That `launch()` stays under 16,777,216 execution gas with a block's worth of hostile positions in front. It is a required fork test in B40 and R05.
- Exit sizes for USDT and USDC.

### Still for the owner

Nine defaults: minimum age measured at the batch; caps and the stop at 800 ETH; four-year deposit window; two thirds with no fallback and majority-miss removal; screener stake 0.05% with a 30-day wait; reward floor; two-year swarm vest; auction design; relay fee in ETH. Plus the stablecoin exit sizes.
