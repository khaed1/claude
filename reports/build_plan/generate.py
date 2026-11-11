#!/usr/bin/env python3
"""
Generates the Murmuration build-plan job briefs and checks each against IMD's published request limits
(imd.fun docs, read 10 Nov 2026; see research_notes/.../imd_audit_and_jobs_v3.md).
The briefs follow revision 4.2 of the specification (11 Nov 2026), which answers the independent review in
research_notes/.../adversarial_review_independent_v3.md. Limits:
  objective <= 8,000 characters; 1-6 steps, one skill per step; <= 8 acceptance criteria per step, each <= 500 characters;
  <= 16 writable paths; <= 4 contracts named; whole request body <= 16 KiB.
Run:  python3 generate.py      (rewrites the .md files beside it)
Nothing here submits anything. The briefs are drafts for the owner.
"""
import pathlib, textwrap

HERE = pathlib.Path(__file__).parent
SPEC = "reports/Murmuration v4 specification.html"
COMMON = ("Work only from the pinned commit of the project repository and the build specification "
          f"(`{SPEC}`, section \"Build specification\"). Solidity 0.8.30, Foundry, optimizer on, no ffi, no network. "
          "No owner, admin, pause, upgrade or setter may appear in any contract. Every duration is in seconds of "
          "block.timestamp counted from Params.GENESIS; no schedule may count blocks. If the specification is "
          "ambiguous, stop and report the ambiguity instead of choosing.")

J = []
def job(id, title, kind, template, skills, depends, paths, objective, accept, contracts=(), notes="", out=""):
    J.append(dict(id=id, title=title, kind=kind, template=template, skills=skills, depends=depends, paths=paths,
                  objective=" ".join(objective.split()), accept=accept, contracts=contracts,
                  notes=" ".join(notes.split()), out=" ".join(out.split())))

FOUNDRY = "IMD's verifier runs forge build, forge test and Slither on this job."
STRUCT = ("IMD's verifier checks only structure and paths for this job: it does not build or run non-Foundry code. "
          "Acceptance therefore rests on the make target named below, which the paired review job re-runs and anyone can run.")

# ------------------------------------------------------------------ foundation
job("B00", "Repository scaffold and parameter files", "build", "single", ["scaffold-project"], [],
    ["foundry.toml", "Makefile", "params/mainnet.json", "params/canary.json", "script/gen_params.py", "src/Params.sol",
     "src/lib/Addresses.sol", "README.md", ".github/workflows/check.yml"],
    """Create the project layout: Foundry project (solc 0.8.30, optimizer 200 runs, evm version pinned), a Makefile with
    targets check, sizes, gas and vectors, and two parameter files. params/mainnet.json holds every value in the
    specification's parameter table: the five assets with ids 1 to 5 (ETH, USDT, USDC, IMD, token), caps, weights,
    exit sizes, GENESIS, epoch and checkpoint lengths in seconds, stake, emission steps, auction constants, the launch
    reset bound, the seat contract and the USDT, USDC and IMD addresses. params/canary.json differs only in the salt,
    GENESIS, the cap step (10 days), the emission period (80 days), the deposit window (85 days), the four starting
    caps (0.5 ETH, 1,000 USDT, 1,000 USDC, 50 IMD) and the screener wait (3 epochs). script/gen_params.py writes
    src/Params.sol from a parameter file so that no constant is typed by hand in a contract. src/lib/Addresses.sol
    computes the addresses of the five deployed contracts from the Deployer's address and their fixed creation order. """ + COMMON,
    ["`make check` runs forge build and forge test and exits 0 on the empty project.",
     "`python3 script/gen_params.py params/mainnet.json` reproduces src/Params.sol byte for byte.",
     "`make sizes` fails if any deployed contract exceeds 24,576 bytes.",
     "params/canary.json differs from params/mainnet.json in exactly the keys named in the objective (a test lists the differing keys).",
     "No parameter appears as a literal in src/ outside src/Params.sol, and no source file reads block.number (two grep tests enforce it).",
     "Addresses.sol matches the addresses CREATE gives a contract with nonces 1 to 5 (fuzz over deployer addresses)."],
    notes=STRUCT)

# ------------------------------------------------------------------ contracts
job("B10", "Token", "build", "impl_tests", ["implement-and-test"], ["B00"],
    ["src/Token.sol", "test/Token.t.sol"],
    """Implement the Token contract: a plain ERC-20 with 18 decimals whose constructor creates the whole supply for
    its creator, which is the Distribution contract inside launch(). No constructor argument, no owner, mint, burn
    function, permit, hook, fee or blocklist. """ + COMMON,
    ["totalSupply equals Params.SUPPLY after construction and after any sequence of transfers (invariant test).",
     "The ABI contains only the ERC-20 functions and events; a test enumerates selectors and fails on any other.",
     "transfer and transferFrom move exactly the amount requested, return true, and revert on insufficient balance or allowance.",
     "The creation code is a constant: it contains no address and no constructor argument, so its CREATE2 address depends only on the creator and the salt.",
     "Deployed size is under 3,000 bytes."],
    contracts=["src/Token.sol"], notes=FOUNDRY)

job("B11", "Hash adapter and note tree", "build", "impl_tests", ["implement-and-test"], ["B00"],
    ["src/lib/Hash.sol", "src/lib/NoteTree.sol", "test/NoteTree.t.sol", "test/vectors/poseidon.json"],
    """Implement Hash.sol, which calls the three poseidon-solidity contracts already on mainnet (addresses and code
    hashes in Params) for H2, H3 and H4, and NoteTree.sol: an append-only tree of depth 32 with empty leaf ZERO, one
    insert per call, the last 64 roots kept in a ring, and leaf = H4(C0, C1, C2, C3). Tests etch the hasher bytecode
    from fixtures. """ + COMMON,
    ["H2, H3 and H4 match every vector in test/vectors/poseidon.json (generated from circomlibjs, at least 64 per width, including 0 and p-1).",
     "Inputs at or above the field modulus revert.",
     "After n inserts the root equals a reference implementation in the test for n in 1..300 and for the fuzzed case.",
     "isKnownRoot is true for the last 64 roots and false for the 65th and for zero.",
     "An insert costs at most 700,000 gas with warm hashers (gas snapshot test).",
     "The constructor reverts if any hasher's code hash differs from Params."],
    contracts=["src/lib/NoteTree.sol", "src/lib/Hash.sol"], notes=FOUNDRY)

job("B12", "Pool: deposit, activate, refund", "build", "impl_tests_review",
    ["implement-and-test", "write-foundry-tests", "adversarial-review"], ["B11"],
    ["src/Pool.sol", "src/lib/SafeTransfer.sol", "src/interfaces/IRegistry.sol", "test/PoolDeposit.t.sol",
     "test/mocks/MockRegistry.sol", "test/mocks/Tokens.sol"],
    """Implement the Pool's deposit, activate and refund and their accounting exactly as in the build specification.
    deposit(asset, value, ownerCommit) pulls value + value/500 and checks that exactly that arrived (msg.value for
    ETH, zero msg.value for a token), stores keccak256 of depositor, asset, value, ownerCommit and deposit time, and
    adds to pending. activate(id, record), depositor only, requires Registry.isApproved(id, depositTime) and room
    under the cap counted on activated value, computes the commitment on-chain as H3(packed, index, ownerCommit),
    inserts H4(commitment, 0, 0, 0), moves value to shielded (tokenIn for the reward token) and value/500 to fees.
    refund(id, record) is open to the depositor in every state and to anyone while Registry.isRefused(id); it always
    pays the depositor value plus fee. Token transfers go through SafeTransfer.sol, which accepts tokens that return
    no value, as USDT does. The reward index and roll are read through internal hooks that B13 and B14 fill; use
    stubs. spend is out of scope. """ + COMMON,
    ["Only the depositor can activate (fuzzed caller). A third party can refund only while the registry marks the deposit refused, and the money still goes to the depositor.",
     "A deposit ends in exactly one of activated or refunded; a second activate or refund reverts.",
     "refund returns exactly value + value/500 in every screening state and after the deposit window.",
     "activate reverts when isApproved is false and when shielded + value would exceed cap(asset); the note's value is exactly the deposited value.",
     "deposit reverts after DEPOSIT_END, for an unlisted asset, below the smallest size, above the cap, with ownerCommit >= p, with ETH sent alongside a token, and when the amount received differs from value + value/500 (fee-on-transfer mock).",
     "A token whose transfer returns no value (USDT mock) deposits, activates and refunds correctly.",
     "For each asset, balance >= pending + shielded + fees after every call (invariant test, 5,000 runs).",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/Pool.sol"], notes=FOUNDRY)

job("B13", "Reward index library", "build", "impl_tests", ["implement-and-test"], ["B00"],
    ["src/lib/RewardIndex.sol", "test/RewardIndex.t.sol", "test/ref/reward_index.py"],
    """Implement RewardIndex.sol: the accumulator g with 64 fractional bits, the weighted total over ETH, USDT, USDC
    and IMD, the divisor floor of a quarter of capacity at the current cap step, emission per second per step in
    proportion to the caps, released, and the hourly checkpoints. accrueTo(time) must handle any number of cap-step
    boundaries since the last call. g rounds down, released rounds up. roll(): if no checkpoint was taken in the
    current window, where window = (now - GENESIS) / 3,600, advance g to now, then set gPrev = gCur and gCur = g and
    record the window. Exactly one shift per call, however many windows have passed; otherwise nothing changes. """ + COMMON,
    ["g never decreases and stays below 2^90 over the whole schedule at the smallest possible weighted total (test at weighted = 0 and = 1).",
     "released never exceeds the users' allocation; equality within 1e-9 relative when the pool is at or above the floor for the whole schedule.",
     "Differential test: 10,000 fuzzed sequences of balance changes and time jumps match the Python reference in test/ref within rounding bounds stated in the test.",
     "For any set of simulated notes, the sum of floor(weight*value*(gRef-index)/2^64) is at most released (invariant test).",
     "After any idle time, one roll leaves gPrev equal to the old gCur and gCur equal to g at the call's timestamp; a second roll in the same window changes nothing; gCur and gPrev are never above g.",
     "After the last emission step g stops changing."],
    contracts=["src/lib/RewardIndex.sol"], notes=FOUNDRY)

job("B14", "Pool: spend and roll", "build", "impl_tests_review",
    ["implement-and-test", "write-foundry-tests", "adversarial-review"], ["B12", "B13"],
    ["src/Pool.sol", "src/interfaces/IVerifier.sol", "test/PoolSpend.t.sol", "test/mocks/MockVerifier.sol"],
    """Add the public roll() and spend(proof, inputs, ext) to the Pool. roll wraps B13's roll and also saves
    rootPrev = rootCur and rootCur = the current root, emitting CheckpointRolled(window, g, root). The 13 public
    inputs are, in order: root, nf0, nf1, nf2, C0, C1, C2, C3, publicAmount, publicAsset, relayFee, gRef, extHash.
    ext is (recipient, relayer, ct0, ct1). spend works in the specification's order: roll; root is one of the last 64
    or rootCur or rootPrev; gRef is gCur or gPrev; extHash equals keccak256(abi.encode(chainid, pool, recipient,
    relayer, keccak256(ct0), keccak256(ct1))) mod p; every input below p; the zero conventions (publicAsset is zero
    exactly when publicAmount is, recipient is zero when nothing leaves, nf2 is zero exactly when relayFee is);
    nullifiers unused and distinct; verify; mark nullifiers and insert H4(C0..C3); if anything leaves, advance the
    index, then for a public amount require a standard size and enough balance (for the token: tokenOut + amount <=
    tokenIn + released), lower the balance and keep amount/500 as the exit fee, and for a relay fee lower the ETH
    balance; emit Spent with gRef, relayFee, relayer and both ciphertexts; pay the recipient and the relayer last.
    activate calls roll first. Use a mock verifier in tests; real proofs come in B60. """ + COMMON,
    ["spend reverts on: unknown root, stale gRef, wrong extHash (including a changed relayer), a used nullifier, equal nullifiers, a public input >= p, a non-standard size, and each broken zero convention.",
     "A withdrawal pays the recipient exactly amount - amount/500 and adds amount/500 to fees, for every listed size of every asset; the relayer receives exactly relayFee in ETH and shielded ETH falls by it.",
     "Total withdrawn per asset never exceeds total activated; for the token tokenOut never exceeds tokenIn + released (invariant test with a verifier that accepts everything).",
     "Re-entrancy from an ETH recipient, a relayer or a token callback cannot enter any Pool function (attacking mocks).",
     "Root flush: after a roll and 65 further spends, a proof against rootCur is accepted; after the next roll it is accepted as rootPrev; after two rolls it is rejected.",
     "Liveness: after any idle time, one roll makes a spend against gCur succeed, and a note activated in a quiet pool is spendable after the next roll.",
     "Gas for a relayed spend with the mock verifier is under 900,000 (snapshot), leaving room for 285,000 of verification.",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/Pool.sol"], notes=FOUNDRY)

job("B15", "Pool: fees, key announcements, size and gas report", "build", "impl_tests", ["implement-and-test", "gas-and-size-report"], ["B14"],
    ["src/Pool.sol", "test/PoolFees.t.sol", "docs/gas-report.md"],
    """Add sweepFees (anyone, at most once per 86,400 seconds per asset and only when the fees are at least the
    asset's smallest exit size; sends the fees to the distributor and calls notify), announce (event only) and the
    views cap, checkpoints and isKnownRoot. The distributor's address comes from Addresses.sol and the token's from
    Distribution.token(). Produce docs/gas-report.md with measured gas for deposit, activate, refund, roll, a
    self-sent spend and a relayed spend, under today's rules and under the EIP-8037/8038 rules computed from the
    storage operations each call performs. """ + COMMON,
    ["sweepFees transfers exactly fees[asset], zeroes it, reverts if called twice within 86,400 seconds, and reverts below the smallest exit size.",
     "announce writes no storage (state diff test).",
     "Pool deployed size is at most 24,576 bytes (`make sizes`).",
     "docs/gas-report.md lists, per function, measured gas, new slots, overwritten slots and the Glamsterdam estimate; the relayed spend estimate is under 1,600,000.",
     "No Pool function sends an asset anywhere but a depositor, a recipient or relayer named in a verified call, or the distributor (a test enumerates every transfer site)."],
    contracts=["src/Pool.sol"], notes=FOUNDRY)

job("B20", "ScreenerRegistry: membership and stake", "build", "impl_tests_review",
    ["implement-and-test", "write-foundry-tests", "adversarial-review"], ["B10"],
    ["src/ScreenerRegistry.sol", "test/RegistryMembership.t.sol", "test/mocks/MockSeat.sol"],
    """Implement register, activate, requestExit, withdrawStake and evict, with activeCount, joining and the per-epoch
    snapshot taken at the first registry call of an epoch. register requires ownerOf(seatId) on the seat contract to
    be the caller and takes Params.STAKE of the token, whose address is read from Distribution.token(). Nobody is
    active before Params.SCREENER_WAIT epochs after registering, and there is no shortcut at launch. activate(seatId)
    is then called by the holder or operator, checks the seat is still held, and adds the screener to joining, which
    is folded into activeCount at the next snapshot. evict is open to anyone when the seat's owner is no longer the
    registered holder (an ownerOf call that reverts counts as not held), when the screener has not revealed for 7
    epochs counted from the later of its last reveal and its first active epoch, or when it has 7 consecutive misses
    (the counter is written by B21). Exit and eviction move the stake to unbonding[holder], released 14 epochs later
    to that holder only, so a seat that changed hands can be registered again at once. """ + COMMON,
    ["One registration per seat; a second reverts until the first has exited or been evicted, and succeeds straight after.",
     "No screener counts in any snapshot before SCREENER_WAIT epochs after registering, including in epochs 0 to 7 after launch (fuzz over registration times).",
     "activeCount changes only at a snapshot, an exit or an eviction, and equals the number of screeners activated and not exited or evicted (invariant test).",
     "After the seat is transferred, commit by the old operator reverts and evict succeeds; a seat contract that reverts is treated as not held.",
     "A screener that became active but never revealed is evictable 7 epochs after its first active epoch and not before.",
     "withdrawStake reverts before 14 epochs and pays exactly the stake to the holder who posted it; no path reduces a stake.",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/ScreenerRegistry.sol"], notes=FOUNDRY)

job("B21", "ScreenerRegistry: commit, reveal, accept, apply", "build", "impl_tests_review",
    ["implement-and-test", "write-foundry-tests", "adversarial-review"], ["B20"],
    ["src/ScreenerRegistry.sol", "test/RegistryBatches.t.sol"],
    """Implement commit (first 57,600 seconds of an epoch), reveal (last 28,800), the tally with leadHash and
    leadCount, acceptance at two thirds of the snapshot rounded up with a snapshot of at least seven, the majority
    hash (the lead, recorded when the epoch ends if more than half of the snapshot revealed it), the miss counter
    (a screener that revealed something else in an epoch with a majority hash has one more miss; one that revealed
    the majority hash has none), apply, isApproved, isRefused, flag and signalCriteria. A batch is {epoch,
    criteriaHash, upTo, words[], dataCid}, hashed as keccak256(abi.encode(...)) in that order. apply(batch) requires
    its hash to be the accepted batch of its epoch, that epoch to be later than lastApplied, and at most 96 words
    in ascending order; it sets dataTime to the start of that epoch, sets screenedThrough to upTo and overwrites the
    listed bitmap words. isApproved(id, depositTime) is id <= screenedThrough, bit clear, and depositTime + 86,400
    <= dataTime. No commit is taken from 30 epochs after the deposit window closes. """ + COMMON,
    ["A batch is accepted exactly when matching reveals reach ceil(2n/3) with n >= 7 the snapshot count; never with n < 7; at most one per epoch (fuzz over reveal orders).",
     "A reveal that does not match the screener's commitment, or arrives outside the reveal window, reverts; each screener commits and reveals once per epoch.",
     "apply reverts for a batch that is not accepted, whose epoch is not later than lastApplied, that lists more than 96 words, or whose words are not ascending.",
     "No deposit with depositTime + 86,400 > dataTime is approved, whatever upTo says: a batch with upTo = 2^64-1 approves nothing made later than one day before its epoch began (fuzz).",
     "Misses: a screener that reveals a non-majority hash in 7 consecutive epochs with a majority becomes evictable; revealing the majority hash resets the count; an epoch with no majority changes nobody's count.",
     "A minority of one third plus one revealing junk for 7 epochs can be evicted, after which the remaining screeners accept a batch (scenario test).",
     "apply with 96 words uses under 3,000,000 gas today and under 16,777,216 execution gas under the EIP-8037 model in the test.",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/ScreenerRegistry.sol"], notes=FOUNDRY)

job("B22", "ScreenerRegistry: pay", "build", "impl_tests", ["implement-and-test"], ["B21"],
    ["src/ScreenerRegistry.sol", "test/RegistryPay.t.sol"],
    """Implement fund(asset, amount) from the distributor, the per-asset pot, and the 16-slot ring. Each slot is
    tagged with its epoch and cleared when reused, and holds the accepted hash, the majority hash, how many agreed
    and the pay per head in each asset. At the first registry call after an epoch with an accepted batch, the pot
    and one share of the screeners' token budget are divided equally among the screeners who revealed that batch.
    The budget is paid in 730 equal shares, one per accepted epoch (paidEpochs counts them), so an epoch without a
    batch delays its share and does not destroy it. A screener is credited at its next commit, exit, eviction or
    withdrawPay, within 16 epochs. Expose lastAccepted for the distributor. """ + COMMON,
    ["Each screener who revealed the accepted batch is credited pot/agreed for every asset; others are credited nothing.",
     "Fees received in an epoch with no accepted batch stay in the pot and are paid in the next accepted epoch.",
     "After 730 accepted epochs the token paid equals SCREENER_BUDGET less rounding and never exceeds it, however many epochs had no batch in between.",
     "For each asset, balance >= pot + sum of owed, plus stakes, unbonding stakes and the unpaid budget for the token, after every call (invariant test).",
     "A ring slot is read only when its tag matches: a screener that settles after more than 16 epochs gets nothing for the overwritten epoch and never another epoch's pay.",
     "A screener that exits or is evicted is settled before its record changes.",
     "Registry deployed size is at most 24,576 bytes."],
    contracts=["src/ScreenerRegistry.sol"], notes=FOUNDRY)

job("B30", "FeeDistributor: split and staking streams", "build", "impl_tests_review",
    ["implement-and-test", "write-foundry-tests", "adversarial-review"], ["B10", "B22"],
    ["src/FeeDistributor.sol", "test/DistributorStaking.t.sol"],
    """Implement notify(asset, amount), callable by the Pool only, splitting each receipt 40/40/20. The stakers' 40%
    joins that asset's stream: what is left of the stream plus the new amount, paid evenly over the next 604,800
    seconds. The screeners' 40% goes to the registry with fund, or to the staker stream when the registry's
    lastAccepted is more than seven epochs old. The last 20% joins basketStream[asset], which B31 releases into the
    basket; for the project token it goes to the burn address, and for IMD it is added to buybackImd, a balance kept
    apart from IMD owed to stakers. With nothing staked, the stakers' share follows the 20%. Implement
    fundBuyback(amount), which pulls IMD from the caller into buybackImd, and stake, unstake and claim with
    reward-per-token accounting per asset. While nothing is staked a stream's clock stops and resumes at the next
    stake. Transfers use SafeTransfer.sol. """ + COMMON,
    ["The three parts of every notify add up to the amount, with any remainder in the basket stream (fuzz).",
     "A staker who stakes 12 seconds before a notify and unstakes 12 seconds after earns at most 24/604,800 of that receipt's staker share.",
     "Two stakers with equal stake over the same period earn equal amounts within 1 wei per asset.",
     "A stream that runs while nothing is staked pays out in full to later stakers; nothing is stranded (test with a gap of 30 days).",
     "For each asset, balance >= unpaid stream + sum owed + basket + basket stream, plus staked tokens for the token and buybackImd for IMD, after every call (invariant test).",
     "When the registry has accepted no batch for more than seven epochs the screeners' 40% goes to stakers, and it goes back to the registry after the next accepted batch.",
     "notify from any address but the Pool reverts. For IMD the 20% lands in buybackImd, never in the basket, and buybackImd never overlaps IMD owed to stakers (invariant test).",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/FeeDistributor.sol"], notes=FOUNDRY)

job("B31", "FeeDistributor: basket auction", "build", "impl_tests", ["implement-and-test"], ["B30"],
    ["src/FeeDistributor.sol", "test/DistributorAuction.t.sol"],
    """Implement the basket stream and buy(assets, to, saleId, deadline, maxPay). Each receipt's 20% is released
    into basket[asset] evenly over 604,800 seconds. The price falls linearly from the starting price to
    Params.AUCTION_FLOOR over 86,400 seconds and stays at the floor; the first sale's clock starts at GENESIS. The
    buyer names at least one asset, pays the price in IMD, which is added to buybackImd, and receives the released
    basket balance of each asset named. The next starting price is twice the price paid and at least
    Params.AUCTION_MIN_START. The design follows Euler's FeeFlowController (GPL-2.0-or-later, audited) with three
    changes: a non-zero floor, explicit basket balances instead of whole balances, and the seven-day release. """ + COMMON,
    ["Price at offsets 0, 43,200, 86,400 and 1,000,000 seconds equals start, the midpoint, floor and floor.",
     "After one notify the released basket at time t is 20% of the receipt times min(t, 604,800)/604,800, within 1 wei.",
     "buy reverts on a stale saleId, a passed deadline, an empty asset list, or a price above maxPay.",
     "The buyer receives exactly the released basket of each named asset and nothing of the unreleased stream, the staker streams or the stakes.",
     "A sale that names all assets but one whose transfer reverts (blocklist mock) succeeds when that asset is left out.",
     "After a sale at price x the next starting price is max(2x, AUCTION_MIN_START).",
     "Re-entrancy through an ETH payout or a token callback cannot reach buy, claim or unstake."],
    contracts=["src/FeeDistributor.sol"], notes=FOUNDRY)

job("B32", "FeeDistributor: buyback through the locked pool", "build", "impl_tests_review",
    ["implement-and-test", "write-foundry-tests", "adversarial-review"], ["B31", "B40"],
    ["src/FeeDistributor.sol", "src/interfaces/IUniswapV3.sol", "test/DistributorBuyback.t.sol"],
    """Implement buyback(): at most once per 43,200 seconds, swap IMD for the token in the Uniswap v3 pool created by
    Distribution, exact input, recipient the burn address. The amount is min(buybackImd, FEE * virtualImd / 2),
    where FEE is the pool's fee rate and virtualImd is the locked position's own virtual IMD reserve: the constant
    Distribution.liquidity() recorded at launch combined with slot0.sqrtPriceX96 for IMD's side of the pair. A
    token balance, pool.liquidity() or any other figure a third party can change is never used. Implement
    uniswapV3SwapCallback, which pays only when called by that pool. Tests run against the real Uniswap v3 core
    bytecode. """ + COMMON,
    ["The step never exceeds half of fee rate times the locked position's virtual IMD reserve, for token0 and token1 orderings (fuzz over prices).",
     "The step is unchanged when a third party adds in-range liquidity, adds out-of-range IMD bids, or sends IMD to the pool (three tests).",
     "A second buyback within 43,200 seconds reverts.",
     "The swap callback reverts for any caller but the pool, and pays exactly the amount owed.",
     "Sandwich test against the locked position alone: for 200 fuzzed attacker sizes, buying before a step and selling after it loses money net of the two fees.",
     "buybackImd falls only inside the callback; a test enumerates every external function and checks it, and IMD owed to stakers is untouched by a buyback.",
     "Bought tokens arrive at the burn address and the pool's IMD balance rises by the amount spent.",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/FeeDistributor.sol"], notes=FOUNDRY + " The Uniswap v3 core artifacts are vendored as files because the job has no network.")

job("B40", "Distribution: launch and the locked position", "build", "impl_tests_review",
    ["implement-and-test", "write-foundry-tests", "adversarial-review"], ["B10"],
    ["src/Distribution.sol", "src/interfaces/IUniswapV3.sol", "test/DistributionLaunch.t.sol", "test/vendor/uniswap-v3-core/"],
    """Implement launch(), callable once by anyone from GENESIS. It creates the Token with CREATE2 and the salt
    keccak256(abi.encode(block.prevrandao, msg.sender)), so the token's address cannot be computed before the
    block; sends 45% of supply to the Pool and 15% to the Registry; creates the token/IMD Uniswap v3 pool at the 1%
    tier and initializes it at the starting price. If someone in the same block has already created and priced it
    above the start, it sells at most Params.LAUNCH_RESET_MAX tokens with the starting price as the limit, sends the
    IMD received to the distributor with fundBuyback, and reverts the whole call if the price is still above the
    start. It then mints one position from the start tick to the maximum usable tick with what is left of the 25%,
    owned by this contract, and records token, pool and the position's liquidity. Implement the views token(),
    pool() and liquidity(), zero before launch, and the mint and swap callbacks, restricted to the pool. """ + COMMON,
    ["After launch the Pool holds 45%, the Registry 15%, the position 25% less at most LAUNCH_RESET_MAX, and 15% stays here for the swarm and founder, to the rounding stated in the test.",
     "launch reverts before GENESIS, and a second launch reverts. token(), pool() and liquidity() are zero before and constant after.",
     "The token's address has no code before launch and differs for a different prevrandao or caller (fuzz).",
     "launch succeeds when a same-block front-runner created the pool, priced it above the start and added bids that LAUNCH_RESET_MAX tokens clear; it reverts, changing nothing, when they do not, and a retry in a later block succeeds at a new token address.",
     "Gas: with 60,000,000 gas of dust positions placed in front in the same block, launch either completes under 16,777,216 execution gas or reverts cleanly; the measured worst case is reported.",
     "The position is one-sided in the token for both token orderings, and also when the front-runner priced the pool below the start.",
     "No function in the ABI can call pool.burn with a non-zero amount; a test enumerates selectors and a symbolic test checks liquidity never falls.",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/Distribution.sol"], notes=FOUNDRY)

job("B41", "Distribution: vesting, swarm claims, fee collection", "build", "impl_tests", ["implement-and-test"], ["B40"],
    ["src/Distribution.sol", "test/DistributionVesting.t.sol"],
    """Implement claimFounder (zero for the first 2,592,000 seconds after launch, then 5% of supply times the time
    since launch over 63,072,000 seconds, to the fixed founder address), claimSwarm(index, account, amount, proof)
    against the fixed Merkle root with leaves keccak256(bytes.concat(keccak256(abi.encode(index, account,
    amount)))), linear over Params.SWARM_VEST from launch, and collect(): burn(0) then collect on the position, the
    IMD to the FeeDistributor through fundBuyback, the token part to the burn address. """ + COMMON,
    ["Founder payout at 0, 2,591,999, 2,592,000, 31,536,000 and 63,072,000 seconds after launch equals 0, 0, 30/730, 1/2 and all of the 5%.",
     "A swarm entry can never be paid more than its vested amount or its allocation; a wrong proof, index or amount reverts.",
     "The sum of all swarm claims in a fuzzed tree never exceeds the 10%.",
     "collect sends fees only to the FeeDistributor and the burn address and leaves liquidity unchanged.",
     "Distribution deployed size, including the Token's creation code it carries, is at most 24,576 bytes."],
    contracts=["src/Distribution.sol"], notes=FOUNDRY)

job("B50", "Deployer and deployment script", "build", "impl_tests", ["implement-and-test", "deploy-script"], ["B15", "B22", "B32", "B41", "B51"],
    ["src/Deployer.sol", "script/Deploy.s.sol", "script/compare_builds.py", "test/Deployer.t.sol", "docs/deploy.md"],
    """Implement Deployer: its constructor stores five creation-code hashes in order (Verifier, ScreenerRegistry,
    FeeDistributor, Pool, Distribution); deploy(i, code) creates contract i with CREATE if keccak256(code) matches
    hash i and every earlier one exists, and reverts if creation fails. No address is passed to any constructor:
    each contract takes its siblings from Addresses.sol, using the Deployer (msg.sender in its constructor) and the
    fixed order, so no hash depends on an address. The Token is not deployed here; Distribution creates it at
    launch. Deploy.s.sol deploys the Deployer through the deterministic proxy at
    0x4e59b44847b379578588920cA78FbF26c0B4956C with the salt from the parameter file, then one contract per
    transaction, then calls launch once GENESIS has passed. script/compare_builds.py compares the creation code of
    two builds and lists every differing constant. """ + COMMON,
    ["deploy reverts for wrong code, wrong order, an index already deployed, or a creation that fails; anyone can call it.",
     "Each deployed contract's computed addresses of the other four equal the actual deployed addresses, and each reads the token from Distribution.token().",
     "The Deployer has no function other than deploy and views, and holds no funds.",
     "Running the script twice from clean state with the same parameter file gives identical addresses for the five contracts.",
     "compare_builds.py on the canary and mainnet builds reports differences only in the constants params/canary.json changes, and fails on any other differing byte.",
     "docs/deploy.md lists each transaction with its gas today and under EIP-8037, and none needs more than 16,777,216 execution gas."],
    contracts=["src/Deployer.sol"], notes=FOUNDRY)

job("B51", "Verifier and verification-key checks", "build", "impl_tests", ["implement-and-test"], ["C06"],
    ["src/Verifier.sol", "test/Verifier.t.sol", "script/check_vk.py", "test/fixtures/proofs/"],
    """Wrap the snarkjs-generated Groth16 verifier for the Spend circuit as Verifier.sol with one view function
    verify(proof, inputs[13]). Add script/check_vk.py, which reads a verification key and fails unless gamma and
    delta are distinct, neither is the generator, all points are on the curve and in the right subgroup, and the
    number of IC points is 14. Two production verifiers were exploited in February 2026 because a setup step was
    skipped and gamma equalled delta; this check is the guard. """ + COMMON,
    ["All valid fixture proofs verify; each fixture with any one of the 13 public inputs or one proof byte altered fails.",
     "A public input equal to or above the field modulus is rejected.",
     "check_vk.py fails on a key with gamma == delta, on a point off the curve, and on a wrong IC count (three bad fixtures).",
     "Verification of 13 inputs costs under 285,000 gas (snapshot).",
     "The contract has no storage and no function besides verify."],
    contracts=["src/Verifier.sol"], notes=FOUNDRY + " The fixtures come from C06 and use a development setup, not the ceremony.")

job("B60", "End-to-end tests with real proofs", "build", "single", ["write-foundry-tests"], ["B50", "C06", "S03"],
    ["test/EndToEnd.t.sol", "test/fixtures/e2e/", "docs/e2e.md"],
    """Write end-to-end tests over the contracts deployed through the Deployer and launch() on a fork with real
    Uniswap v3, the real USDT and USDC bytecode and a mock seat contract, using proofs produced by C06 for a fixed
    scenario: deposits in ETH, USDT and IMD, a refused deposit refunded by a third party, activation, a self-sent
    transfer, a transfer through a relayer paid from an ETH fee note, a transfer with an empty input, a claim of
    reward, withdrawals at two sizes, a fee sweep, a basket sale, two buyback steps, a staker claim and a screener
    pay withdrawal. """ + COMMON,
    ["Every step of the scenario succeeds with the real Verifier and the fixture proofs.",
     "Replaying any fixture proof a second time fails; replaying it against a second deployment with another address fails on extHash; submitting it with another relayer address fails.",
     "At the end, each capped asset's Pool balance equals pending + shielded + fees exactly, and the reward paid is at most released.",
     "The scenario crosses one cap step and one emission step by warping, and a proof built against gPrev and a checkpoint root still verifies after 65 other spends.",
     "The relayer's ETH balance rises by exactly relayFee and the recipient of a withdrawal receives exactly size - size/500.",
     "docs/e2e.md lists each step with its gas."],
    notes=FOUNDRY)

# ------------------------------------------------------------------ fuzz
for fid, title, dep, harness, inv in [
    ("F01", "Fuzz: pool accounting", "B15", "test/fuzz/PoolAccounting.fuzz.sol",
     ["balance >= pending + shielded + fees for every capped asset, and for the token >= pending + fees + tokenIn - tokenOut",
      "withdrawn <= activated per asset, and for the token tokenOut <= tokenIn + released",
      "shielded <= cap at the time it last grew", "each deposit id ends activated or refunded at most once, and a refund always pays the depositor"]),
    ("F02", "Fuzz: reward budget", "B14", "test/fuzz/RewardBudget.fuzz.sol",
     ["the sum of reward computable by all live simulated notes plus reward already claimed is at most released",
      "released is at most the users' allocation", "g is monotone and below 2^90, and gCur and gPrev are never above g",
      "a note created and spent inside one checkpoint window earns zero"]),
    ("F03", "Fuzz: registry", "B22", "test/fuzz/Registry.fuzz.sol",
     ["at most one accepted batch per epoch, and only with two thirds of the snapshot count and at least seven",
      "no deposit younger than one day at the last applied batch's data time is approved",
      "token and fee balances cover pots, owed, stakes and unbonding stakes", "a stake is returned once, to its holder"]),
    ("F04", "Fuzz: distributor", "B32", "test/fuzz/Distributor.fuzz.sol",
     ["each receipt is split 40/40/20 with the remainder in the basket stream", "balances cover streams, owed, basket and basket stream",
      "buybackImd only ever decreases through the swap callback",
      "a buyback step is at most half of fee rate times the locked position's virtual reserve, at most once per 43,200 seconds"]),
]:
    job(fid, title, "build", "fuzz", ["write-foundry-tests"], [dep], [harness],
        f"""Write one Foundry invariant harness, {harness}, with handler functions for every external function of the
        contract under test and ghost variables for the sums the invariants need. Run it for 1,000,000 calls. Mock
        verifiers accept every proof so that the harness explores the contract's own checks. """ + COMMON,
        [f"Invariant holds over 1,000,000 calls: {x}." for x in inv] +
        ["The handler reaches every external function at least 1,000 times (call summary in the output)."],
        contracts=[harness], notes="IMD's fuzz template takes exactly one harness and a run count; this brief sets runs to 1,000,000.")

# ------------------------------------------------------------------ circuit
job("C00", "Formal specification of Spend, frozen", "build", "single", ["scaffold-project"], ["B00"],
    ["circuit/lean/Murmuration/Spec.lean", "circuit/lean/Murmuration/Challenge.lean", "circuit/lean/lakefile.toml",
     "circuit/lean/lean-toolchain", "circuit/SPEC.md", "Makefile"],
    """Write the specification of the Spend circuit in Lean 4 for the `clean` framework (Verified-zkEVM/clean, MIT),
    pinned to a commit. Spec.lean defines, as plain functions over field elements and naturals: key derivation, the
    packed word, the note commitment, the nullifier, the bundle leaf, Merkle root recomputation, earned reward as an
    integer floor division, and the predicate SpendValid(public, private) that is the conjunction of the fourteen
    constraints in the build specification, for three inputs (two of the asset, one of ETH), four outputs and the
    13 public inputs. Challenge.lean states, with `sorry` proofs, the top statement (for every assignment that
    satisfies the constraint system there exist a key and up to three notes for which SpendValid holds and the
    public inputs are the specified functions of them) and the ten lemmas of the build specification: spend
    authority, membership, one nullifier per note, per-asset conservation, no reward created, outputs start at the
    checkpoint, true public asset, nothing free, no wrap-around, non-malleability. circuit/SPEC.md restates each in
    plain words. No proofs in this job. """ + COMMON,
    ["`make lean-spec` (lake build of Spec.lean and Challenge.lean) succeeds with only the eleven expected `sorry` warnings.",
     "Every constraint 1-14 of the build specification maps to a named definition in Spec.lean, listed in a table in circuit/SPEC.md.",
     "Conservation and the reward bound are stated over the integers, not the field, and separately for the asset and for ETH.",
     "No theorem in Challenge.lean has a hypothesis that is false for an honest spend; SPEC.md lists every hypothesis and why it is needed.",
     "SPEC.md names, for each of these broken circuits, the lemma it violates: no spend authority; a free nullifier position; a free output index; a free output asset; an unbound extHash; a fee input that is not ETH.",
     "The files' sha256 hashes are written to circuit/lean/FROZEN so later jobs can prove against an unchanged statement."],
    notes=STRUCT + " The statements are the trust anchor. R01 reviews them and the owner signs them off before any proof job starts. The first list of statements, in revision 4.1, was too weak: a circuit missing whole constraints satisfied it.")

job("C01", "Circuit gadgets in clean: ranges, division, selection", "build", "single", ["scaffold-project"], ["C00"],
    ["circuit/lean/Murmuration/Gadgets/Range.lean", "circuit/lean/Murmuration/Gadgets/Division.lean",
     "circuit/lean/Murmuration/Gadgets/AssetTable.lean", "circuit/lean/Murmuration/Gadgets/Pack.lean", "circuit/lean/test/Gadgets.lean"],
    """Implement as clean circuits, reusing clean's proved bit-decomposition and comparator ports: range checks of 2,
    32, 64, 90 and 96 bits; exact division by 2^64 with a 64-bit remainder; the asset table lookup that maps an asset
    id (1 to 5) to its constant weight and rejects zero and unlisted ids; and the packed word TAG_NOTE*2^200 + accrued*2^104 +
    value*2^8 + asset. Constraint generation only; proofs are P01. """ + COMMON,
    ["`make lean-gadgets` builds and runs the gadget tests.",
     "Witness tests: each gadget accepts 1,000 random valid inputs and rejects boundary violations (value = 2^96, remainder = 2^64, asset id = 0 and = 6).",
     "Constraint counts per gadget are printed and written to circuit/COUNTS.md.",
     "No gadget uses an unconstrained hint whose value is not fixed by a constraint (listed in COUNTS.md with the fixing constraint)."],
    notes=STRUCT)

job("C02", "Poseidon at widths 3, 4 and 5 in clean", "build", "single", ["scaffold-project"], ["C00"],
    ["circuit/lean/Murmuration/Gadgets/Poseidon.lean", "circuit/lean/test/PoseidonVectors.lean", "circuit/vectors/poseidon.json"],
    """Provide Poseidon circuits for two, three and four inputs with circomlib's constants in clean. If clean's
    `poseidon-n-arity` work has been merged at the pinned commit, import it; otherwise port it into this repository
    and say so in the output. Check each width against circuit/vectors/poseidon.json, the same vectors B11 uses for
    the on-chain hashers. """ + COMMON,
    ["All vectors for widths 3, 4 and 5 pass in `make lean-poseidon`, at least 64 per width including 0 and p-1.",
     "The round constants are byte-identical to circomlib's poseidon_constants (hash comparison in the test).",
     "The output states which clean commit or branch each width comes from and whether its soundness proof exists there.",
     "Constraint count per width is written to circuit/COUNTS.md."],
    notes=STRUCT + " On 10 Nov 2026 only width 2 was proved on clean's main branch; widths 3 to 5 were on an unmerged branch.")

job("C03", "Merkle membership and bundle gadgets", "build", "single", ["scaffold-project"], ["C02"],
    ["circuit/lean/Murmuration/Gadgets/Merkle.lean", "circuit/lean/Murmuration/Gadgets/Bundle.lean", "circuit/lean/test/Merkle.lean"],
    """Implement the bundle gadget (place a commitment at slot 0-3 among three others and hash with H4) and the
    depth-32 Merkle root recomputation from a leaf, 32 index bits and 32 siblings, with the conditional check
    (value + 2^96*accrued) * (computedRoot - root) = 0. """ + COMMON,
    ["Witness tests against roots produced by the Solidity NoteTree from B11 for 200 random trees (fixture file shared with B11).",
     "A wrong sibling, a flipped index bit or a wrong slot makes the constraint system unsatisfiable for a non-zero note.",
     "A note with value 0 and accrued 0 satisfies the constraints with any path; a note with value 0 and accrued 1 does not.",
     "position = 4*leafIndex + slot is exposed for the nullifier and matches the path bits."],
    notes=STRUCT)

job("C04", "Spend circuit: composition and export", "build", "single", ["scaffold-project"], ["C01", "C03"],
    ["circuit/lean/Murmuration/Spend.lean", "circuit/lean/Export.lean", "circuit/build/spend.r1cs", "circuit/build/spend.wasm",
     "circuit/COUNTS.md", "circuit/vectors/scenarios.json", "Makefile"],
    """Compose the Spend circuit in clean from the gadgets: the fourteen constraints of the build specification over
    three inputs (inputs 0 and 1 of the asset, input 2 always an ETH note that pays the relayer) and four outputs,
    with the thirteen public inputs in the order root, nf0, nf1, nf2, C0, C1, C2, C3, publicAmount, publicAsset,
    relayFee, gRef, extHash. Export the constraint system as .r1cs and the witness generator as Circom-ABI WASM
    with clean's exporter, so that snarkjs can consume them without the Circom compiler. """ + COMMON,
    ["`make circuit` regenerates spend.r1cs and spend.wasm byte for byte from a clean checkout.",
     "snarkjs r1cs info reports 13 public inputs and a constraint count under 40,000, written to COUNTS.md.",
     "A valid witness is produced for each of the seven scenarios in circuit/vectors/scenarios.json (self-sent transfer with nf2 = 0, transfer with one empty input, relayed transfer with a fee note, claim, withdrawal, relayed withdrawal, token withdrawal).",
     "For each scenario, changing any single private input makes witness generation or constraint checking fail, or changes a public output.",
     "An empty fee input gives nf2 = 0 and relayFee = 0, and a fee input with a non-ETH asset has no satisfying witness.",
     "The public input order matches IVerifier in B14 (a shared JSON file checked by both)."],
    notes=STRUCT + " clean's R1CS exporter dates from September 2026 and has no known production use; C05 exists to test it.")

job("C05", "Independent Circom implementation as a test oracle", "build", "single", ["scaffold-project"], ["C00"],
    ["circuit/circom/spend.circom", "circuit/circom/lib/", "circuit/circom/test/differential.mjs", "circuit/circom/package.json", "Makefile"],
    """Write the same Spend circuit in Circom 2 with circomlib's Poseidon, by an agent that has not seen the clean
    implementation. It is never deployed. It exists so that two independent implementations can be compared:
    differential.mjs feeds the same inputs to both witness generators and compares all thirteen public outputs. """ + COMMON,
    ["`circom --inspect` and circomspect report no warning that is not listed and justified in circuit/circom/WARNINGS.md.",
     "`make differential` runs 10,000 random valid inputs and 2,000 edge cases through both implementations with identical public outputs.",
     "Every invalid input rejected by one implementation is rejected by the other (5,000 mutated inputs).",
     "Constraint count is within 15% of the clean circuit's, or the difference is explained."],
    notes=STRUCT)

job("C06", "Proof fixtures and development setup", "build", "single", ["scaffold-project"], ["C04"],
    ["circuit/setup/dev_setup.sh", "circuit/build/dev/verification_key.json", "circuit/build/dev/Groth16Verifier.sol",
     "test/fixtures/proofs/", "test/fixtures/e2e/", "circuit/prover/prove.mjs"],
    """Produce a development Groth16 setup for spend.r1cs with snarkjs from a public powers-of-tau file pinned by
    hash, clearly marked as not the ceremony, including the final beacon step. Generate the Solidity verifier and
    proof fixtures for the scenarios in circuit/vectors/scenarios.json and for the end-to-end scenario of B60.
    prove.mjs is a command-line prover that takes a JSON input and writes proof and public inputs. """ + COMMON,
    ["`snarkjs zkey verify` passes for the development key against spend.r1cs and the pinned powers-of-tau file.",
     "script/check_vk.py from B51 passes on the development verification key.",
     "Every fixture proof verifies with snarkjs and with the generated Solidity verifier.",
     "The setup script is deterministic given its recorded entropy and beacon, and prints the hashes of every output.",
     "Proving time and peak memory for one proof on the job's machine are recorded in circuit/COUNTS.md."],
    notes=STRUCT)

job("C07", "Wallet cryptography library", "build", "single", ["scaffold-project"], ["C00"],
    ["wallet/src/keys.ts", "wallet/src/note.ts", "wallet/src/derive.ts", "wallet/src/encrypt.ts", "wallet/src/address.ts",
     "wallet/test/vectors.test.ts", "wallet/vectors/xwing.json", "wallet/vectors/derive.json", "wallet/package.json"],
    """Implement the wallet-side primitives in TypeScript: key derivation (spk, nk, ownerPk with diversifier), note
    commitment and nullifier, the long and short address formats, and the deterministic derivations that let a
    wallet be rebuilt from its seed: rho and the diversifier of a deposit from a keyed hash of the seed and a
    per-wallet deposit counter, and rho for outputs 1, 2 and 3 of a spend from a keyed hash of the seed, the
    spend's first nullifier and the slot. Ciphertext 0 is HPKE base mode with the X-Wing KEM (HPKE id 0x647A,
    draft-connolly-cfrg-xwing-kem-11), HKDF-SHA256 and ChaCha20-Poly1305: 1,120 bytes of encapsulation, an 80-byte
    payload (asset 1, value 12, accrued 12, rho 31, diversifier 8, memo 16) and a 16-byte tag, 1,216 bytes in all.
    Ciphertext 1 is 96 bytes sealed with a key from the seed and the first nullifier: value and accrued of outputs
    1 and 2 (12 bytes each), the claim (12), 20 spare bytes and a 16-byte tag. Use audited libraries for X25519,
    ML-KEM-768 and the AEAD; write no primitive by hand. """ + COMMON,
    ["X-Wing passes the draft-11 test vectors in wallet/vectors/xwing.json.",
     "Commitments and nullifiers match the Lean specification on the shared scenario vectors.",
     "Encrypt then decrypt round-trips 1,000 random notes; ciphertext 0 is exactly 1,216 bytes and ciphertext 1 exactly 96, with the byte layout of the objective (layout test).",
     "The derivations match wallet/vectors/derive.json, and a deposit's rho and diversifier are recomputed from the seed and the counter alone.",
     "Decryption with the wrong key or one flipped bit fails without throwing an unhandled error.",
     "A short address resolves to its key only when keccak256(key) matches."],
    notes=STRUCT)

# ------------------------------------------------------------------ proofs
PROOF_GATE = ("The gate is not a green build. It is: `lake build --wfail`; an axiom allow-list on every theorem named below "
              "(propext, Classical.choice, Quot.sound and nothing else unless named here); and `lake comparator` against the frozen "
              "Challenge.lean, whose hash must equal circuit/lean/FROZEN.")
job("P01", "Proofs: range, division, selection and packing gadgets", "proof", "single", ["scaffold-project"], ["C01", "R01"],
    ["circuit/lean/Murmuration/Proofs/Range.lean", "circuit/lean/Murmuration/Proofs/Division.lean",
     "circuit/lean/Murmuration/Proofs/AssetTable.lean", "circuit/lean/Murmuration/Proofs/Pack.lean"],
    """Prove soundness and completeness of each gadget from C01 as clean FormalCircuits against Spec.lean: a
    satisfying assignment implies the specified relation over the integers, and every valid input has a satisfying
    assignment. The division gadget's soundness must use the range bounds, since a field inverse alone would admit
    wrong quotients. """ + COMMON + " " + PROOF_GATE,
    ["`make lean-proofs-gadgets` passes with --wfail and no `sorry`, `admit` or `native_decide`.",
     "`#print axioms` for each of the eight soundness and completeness theorems lists only the allow-listed axioms (checked by script).",
     "No file outside the four listed paths changes; Spec.lean and Challenge.lean hashes equal FROZEN.",
     "The packing proof shows the packed word determines asset, value and accrued uniquely given the range checks."],
    notes=STRUCT + " " + "Documented failure modes of agent-written proofs are about statements: added assumptions, weakened input types, vacuous specifications, a disabled checker. The gate above exists for those.")

job("P02", "Proofs: Poseidon at widths 3, 4 and 5", "proof", "single", ["scaffold-project"], ["C02", "R01"],
    ["circuit/lean/Murmuration/Proofs/Poseidon.lean"],
    """Prove that the Poseidon circuits of widths 3, 4 and 5 compute the Poseidon function defined in Spec.lean
    (soundness and completeness). If the pinned clean commit already contains these proofs, this job only imports
    them, re-checks them under the gate and records the commit. The equality of the optimised and the reference
    round structure may be taken as tested, not proved, and must then be listed as such. """ + COMMON + " " + PROOF_GATE,
    ["`make lean-proofs-poseidon` passes with --wfail and no `sorry`.",
     "Axiom check passes for the three soundness theorems.",
     "The output lists exactly which statements are proved and which are covered by test vectors only.",
     "FROZEN hashes are unchanged."],
    notes=STRUCT)

job("P03", "Proofs: Merkle membership and bundle", "proof", "single", ["scaffold-project"], ["C03", "P02", "R01"],
    ["circuit/lean/Murmuration/Proofs/Merkle.lean", "circuit/lean/Murmuration/Proofs/Bundle.lean"],
    """Prove, by induction over depth, that the Merkle gadget's satisfying assignments are exactly those where the
    recomputed root equals Spec.merkleRoot(leaf, index, siblings), and that the bundle gadget places the commitment
    at the stated slot. Prove that the conditional check forces membership whenever value or accrued is non-zero. """ + COMMON + " " + PROOF_GATE,
    ["`make lean-proofs-merkle` passes with --wfail and no `sorry`.",
     "The theorem for the conditional check has no hypothesis on the path when value = accrued = 0 and forces root equality otherwise.",
     "Axiom check passes. FROZEN hashes are unchanged.",
     "position = 4*leafIndex + slot is proved to be the position used by the nullifier."],
    notes=STRUCT)

job("P04", "Proofs: the top statement and its ten lemmas", "proof", "single", ["scaffold-project"], ["C04", "P01", "P03"],
    ["circuit/lean/Murmuration/Proofs/Spend.lean", "circuit/lean/Murmuration/Proofs/Capstone.lean", "circuit/PROOFS.md"],
    """Prove the eleven theorems of Challenge.lean for the composed Spend circuit. The top statement: every
    satisfying assignment yields a key and up to three notes for which SpendValid holds. The lemmas: (1) each
    non-empty input's owner is derived from the sk in the witness; (2) each non-empty input is in the tree under
    root at the position used, assuming Poseidon collision resistance where stated; (3) the position inside each
    nullifier is the position proved in the tree; (4) value is conserved over the integers per asset, with outputs
    0 and 1 in the inputs' asset and output 2 in ETH; (5) reward out equals reward in plus earned, earned uses each
    input's committed index and its own asset's weight, and output 3 is a token note with no accrued reward; (6)
    every output's index is gRef; (7) the public asset is the inputs' asset whenever the public amount is non-zero;
    (8) the public outputs are a function of the private inputs; (9) no sum or product in constraints 8, 11 and 12
    reaches the field modulus; (10) every one of the 13 public inputs takes part in a constraint that fixes it.
    circuit/PROOFS.md lists each theorem, its Lean name, its hypotheses and its axioms. """ + COMMON + " " + PROOF_GATE,
    ["`make lean-proofs` passes with --wfail, no `sorry`, and `lake comparator` reports the eleven Challenge theorems proved against the frozen statements.",
     "Axiom check: only the allow-listed axioms plus the named Poseidon collision-resistance hypothesis, which appears as a theorem hypothesis and not as an axiom.",
     "The circuit proved is the one exported in C04: the build hashes spend.r1cs from the same Lean term the theorems are about.",
     "PROOFS.md states in plain words what is proved, what is assumed and what is only tested.",
     "FROZEN hashes are unchanged."],
    notes=STRUCT)

job("P05", "Automatic checkers on the Circom oracle", "proof", "single", ["scaffold-project"], ["C05"],
    ["circuit/analysis/run.sh", "circuit/analysis/REPORT.md", "circuit/analysis/out/"],
    """Run the open-source analysers on the Circom implementation and record the results honestly: circomspect,
    `circom --inspect`, Picus and CIVER (`--check_safety`) on each non-hash template, and zkFuzz on the full
    circuit for one hour. Picus and CIVER are expected to time out on Poseidon and on the top level; record
    `unknown` where they do. """ + COMMON,
    ["`circuit/analysis/run.sh` reproduces every result in out/ from pinned tool versions.",
     "REPORT.md has one row per template and tool: safe, unsafe with counterexample, or unknown with the time limit used.",
     "No template is reported safe unless the tool's own output says so (raw logs are in out/).",
     "Any unsafe result or fuzzer counterexample is reproduced as a failing differential test in C05's suite."],
    notes=STRUCT + " These tools find bugs. They do not establish the top statement or its lemmas, which is what P04 is for.")

# ------------------------------------------------------------------ reviews
job("R01", "Review: are the frozen statements the right ones", "review", "research", ["research-report"], ["C00"],
    ["docs/reviews/R01-statements.md"],
    """Panel review, five reviewers, quorum four, by agents that have not seen any circuit code. Read
    circuit/lean/Murmuration/Spec.lean, Challenge.lean and circuit/SPEC.md at the pinned commit and the build
    specification. Answer for the top statement and each of the ten lemmas: does the Lean statement say what the
    plain-words statement says; is any hypothesis stronger than an honest prover satisfies; is anything quantified
    over the wrong set (field versus integers, any root versus a known root). Then try to break the list as a
    whole: describe a circuit that satisfies all eleven statements and still lets someone spend a note that is not
    theirs, spend a note twice, create value or reward, change one asset into another, or redirect a payment.
    Propose a concrete counter-model for each weakness found. """,
    ["Each of the eleven statements gets a verdict: faithful, too weak (with a counter-model), or too strong (with an honest spend that violates a hypothesis).",
     "Each constraint 1-14 of the build specification is matched to a definition or reported missing.",
     "For each of the six broken circuits named in C00, the report confirms which lemma fails, or reports that none does.",
     "The report names every place where Spec.lean differs from the build specification, however small.",
     "Minimum of 3 citations to file and line per statement."],
    notes="IMD's research template takes panelSize, panelQuorum, minCitations and a rubric. The owner reads this report and signs the statements off before P01 starts.")

job("R02", "Review: circuit and contract interface", "review", "single", ["adversarial-review"], ["B14", "C04"],
    ["docs/reviews/R02-interface.md"],
    """Adversarial review, read-only, of the boundary between the Spend circuit and the Pool: the order and encoding
    of the thirteen public inputs; reduction of extHash and of every input modulo p on both sides; that the tree,
    the bundle leaf and the commitment computed in Solidity equal the circuit's for the same note; that the
    checkpoint and the checkpoint root the Pool accepts are the ones the circuit used; that the zero conventions
    the circuit leaves to the contract are all enforced there; that the standard-size check and the per-asset limit
    use the same asset id as the proof; that the relayer paid is the one bound into extHash. Try to construct a
    call that the Pool accepts with a meaning the circuit did not prove. """,
    ["Each of the thirteen public inputs has a row: produced where, checked where, encoding, and whether a mismatch is possible.",
     "Every check the build specification leaves to the contract has a row naming the line that performs it.",
     "Every finding has a severity, file and line, and a reproduction as a Foundry test or a witness.",
     "The review states explicitly whether a proof for one deployment can be accepted by another, and whether a relayer can change the recipient or the fee.",
     "No high or critical finding remains open at sign-off."],
    notes="IMD's adversarial review goes to a different agent on a different seat, with no write access.")

job("R03", "Review: zero-knowledge circuit checklist", "review", "research", ["research-report"], ["C04", "C05"],
    ["docs/reviews/R03-circuit.md"],
    """Panel review, five reviewers, quorum four, of the clean circuit and the Circom oracle against a checklist that
    IMD's audit template does not contain, because that template is written for Solidity. Checklist: signals assigned
    but not constrained; missing range checks before additions and comparisons; bit decompositions that allow an
    alias above the modulus; equality checks done on hints; selectors not forced to be boolean; public inputs unused
    in any constraint; nullifier not bound to the note it spends; empty inputs able to carry value or reward; a fee input able to carry
    an asset other than ETH; an empty fee input with a non-zero nullifier;
    domain separation between hashes; division by a value that can be zero; differences between the witness
    generator and the constraints. """,
    ["Each checklist item has a verdict per template with file and line, or 'not applicable' with a reason.",
     "Every finding comes with a witness that satisfies the constraints and violates the specification, or is marked unconfirmed.",
     "The report states what the reviewers could not cover.",
     "Minimum of 10 citations."],
    notes="Nothing public shows that IMD has reviewed a circuit before. This brief supplies the checklist the template lacks.")

job("R04", "Review: ceremony transcript and verification key", "review", "single", ["adversarial-review"], ["L02", "B51"],
    ["docs/reviews/R04-ceremony.md"],
    """Read-only check of the final ceremony output: verify the whole contribution chain with snarkjs from the pinned
    powers-of-tau file to the final key; confirm the final beacon step was applied; run script/check_vk.py on the
    final verification key; confirm the constants in src/Verifier.sol equal that key; confirm spend.r1cs used in
    the ceremony is the file whose hash P04 proved. """,
    ["The full `snarkjs zkey verify` output for the final key is in the report and passes.",
     "check_vk.py passes: gamma and delta distinct, all points valid, 14 IC points.",
     "A table shows the hash of spend.r1cs in three places: the P04 build, the ceremony and the fixtures; all equal.",
     "The verifier contract's constants match the key (script output included)."])

job("R05", "Review: launch, auction and buyback on a fork", "review", "single", ["adversarial-review"], ["B32", "B41"],
    ["docs/reviews/R05-market.md", "test/review/Market.t.sol"],
    """Adversarial review of the token's market mechanics on a mainnet fork with the real IMD token and Uniswap v3.
    As a block builder who sees the launch transaction and can act before it in the same block: try to make launch
    revert, run out of gas, or place the position at a wrong price, with bids above the start and with a block's
    worth of dust positions. As anyone: try to learn the token's address before the launch block; try to take
    value from a buyback step by any sequence of swaps and liquidity changes; try to enlarge a step by adding
    liquidity or sending IMD to the pool; try to buy the basket below its value by manipulating the auction's
    state; try to strand an asset in the basket. Report what a third party can gain and at what cost. This step
    may write only the review test file. """,
    ["Each attack attempted is a Foundry test in test/review/Market.t.sol with the attacker's profit asserted.",
     "No attack shows a profit above gas cost, or the finding is filed as high.",
     "The report states what a block builder must spend to block one launch attempt, and that nobody else can block it.",
     "The report states what the launch caller gains by buying in the same transaction, in tokens and in dollars at the starting valuation.",
     "The report lists the IMD token's owner powers that affect this market, including administration of its bridge peers on Ethereum."],
    notes="IMD's review skills are read-only by default; this brief needs a variant that may add one test file, or a build job that writes the tests followed by a read-only review.")

# ------------------------------------------------------------------ audits
for aid, title, dep, contracts, worry in [
    ("A01", "Audit: Token, Distribution, Deployer", ["B41", "B50"], ["src/Token.sol", "src/Distribution.sol", "src/Deployer.sol"],
     "any path that creates supply, reduces the locked position, pays the founder or a swarm entry early or twice, lets anyone learn the token address before the launch block, or lets a third party block or misprice launch"),
    ("A02", "Audit: Pool", ["B15"], ["src/Pool.sol", "src/lib/RewardIndex.sol", "src/lib/NoteTree.sol", "src/lib/Hash.sol"],
     "any path that moves a deposit to anyone but its depositor, lets a spend take more than was activated, pays more reward than released, pays a recipient or relayer the proof did not name, bypasses the cap or the screening check, or leaves funds unable to move"),
    ("A03", "Audit: ScreenerRegistry", ["B22"], ["src/ScreenerRegistry.sol"],
     "acceptance of a batch with fewer than two thirds, approval of a deposit less than a day old at the batch's data time, a way for a minority to stop batches for ever or to evict honest screeners, loss or theft of stakes or pay, and any way for the registry to affect funds in the Pool"),
    ("A04", "Audit: FeeDistributor", ["B32"], ["src/FeeDistributor.sol"],
     "staking reward sniping, a blocked or underpriced basket sale, IMD leaving except through the pool swap, a buyback step that a third party can enlarge, and extraction around a step"),
    ("A05", "Audit: Verifier", ["B51"], ["src/Verifier.sol"],
     "acceptance of an invalid proof, malleable or out-of-range public inputs, and precompile call handling"),
]:
    job(aid, title, "audit", "audit", ["audit (four specialists and a judge, added by IMD)"], dep, ["(read-only; report at /jobs/:id/report.md)"],
        f"""Audit the named contracts at the pinned commit against the build specification. They are immutable once
        deployed: there is no owner, pause or upgrade, so every finding that would normally be fixed by an admin is a
        permanent loss. What worries us most: {worry}. Check every invariant listed for these contracts in the build
        specification and say for each whether it holds, with the test or trace that shows it. Token behaviours to
        assume: USDT returns no value on transfer and its owner can pause it, blocklist any address and switch on a transfer fee that is zero today; USDC can blocklist any address including these contracts and is upgradeable; IMD is a plain bridged token with no fee, pause or blocklist; the project token is plain. """,
        ["The judge's coverage record has one row per external function: holds, finding, or unreached.",
         "Each invariant of the build specification for these contracts has a verdict and evidence.",
         "Every finding has a severity, file and line, a reproduction, and where possible a Foundry proof.",
         "No high or critical finding is open at sign-off; each fix goes through fix-findings and a second audit of the changed contract."],
        contracts=contracts,
        notes="IMD's audit template covers Solidity only: four specialists (math, permissions, economics, control flow) and a judge. It names at most four contracts per request.")

# ------------------------------------------------------------------ node and wallet
job("S01", "Deterministic screening program", "build", "single", ["scaffold-project"], ["B21"],
    ["node/src/screen/criteria.ts", "node/src/screen/batch.ts", "node/src/screen/data.ts", "node/test/determinism.test.ts",
     "node/criteria/sanctions-flags-and-hops.v3.json", "node/package.json"],
    """Implement the screening program: parse a criteria file, read deposits, Flag events and list data from
    finalized blocks as of the epoch's start from an RPC endpoint, evaluate the rules, and output the Batch and its
    hash. upTo is the highest deposit id that was at least one day old at the epoch's start. words are the full
    refusal bitmap of each word that differs from the registry's, in ascending order; if more than 96 differ, the
    batch lists the first 96 and lowers upTo to just below the first deposit of the first word left out. Flags
    count only from active screeners, lapse after 14 epochs, need max(3, one third of active screeners) and reach
    only the address flagged. dataCid is the CIDv1 (raw, sha2-256) of a canonical JSON file naming every refusal
    and its rule. Same inputs must give the same bytes on any machine: canonical ordering, fixed number formats,
    no wall-clock time, no floating point. """ + COMMON,
    ["Two runs on different machines from the same recorded RPC responses produce byte-identical batch and explanation files (fixture replay test).",
     "Each rule in the reference criteria file has a test with a deposit it refuses and one it allows.",
     "A deposit made one second less than a day before the epoch's start is not covered; one made exactly a day before is.",
     "With 97 changed words the batch lists 96 and upTo stops below the first deposit of the 97th; the next epoch's batch picks up the rest.",
     "Two flags from active screeners out of nine refuse nothing; three do; the same three flags refuse nothing 15 epochs later; a flag on an address does not refuse deposits from addresses it sent funds to.",
     "A reorg of unfinalized blocks changes nothing because only finalized data is read (test with a recorded reorg).",
     "The batch hash equals the Solidity hash used by ScreenerRegistry.apply (shared vector)."],
    notes=STRUCT)

job("S02", "Node duty: commit, reveal, apply", "build", "single", ["scaffold-project"], ["S01"],
    ["node/src/duty/screener.ts", "node/src/duty/schedule.ts", "node/test/duty.test.ts", "node/README.md"],
    """Implement the screener duty for the node: call activate once the waiting period has passed; each epoch run
    S01, commit in the first 16 hours with a fresh salt kept on disk, reveal in the last 8 hours, call apply when a
    batch is accepted and not yet applied, and withdraw pay on request. The duty warns its operator when its batch
    differs from the recorded majority hash, and says how many consecutive misses remain before it can be evicted.
    It runs under its own Unix user with its own operator key and never reads IMD's worker files. It makes no call
    to api.imd.fun. """ + COMMON,
    ["Against a local chain with the contracts from B22, ten simulated nodes reach acceptance in every epoch of a 20-epoch test.",
     "A node restarted between commit and reveal still reveals the committed batch (salt persisted).",
     "A node whose RPC returns different data from the others reveals a different hash, is not paid, and logs a warning with its miss count each epoch.",
     "With four of ten nodes revealing junk, no batch is accepted for seven epochs, the four become evictable, and acceptance resumes after they are evicted.",
     "No outbound request goes to any host other than the configured RPC and IPFS endpoints (network mock)."],
    notes=STRUCT)

job("S03", "Wallet flows for the pool", "build", "single", ["scaffold-project"], ["C06", "C07"],
    ["wallet/src/pool/deposit.ts", "wallet/src/pool/spend.ts", "wallet/src/pool/plan.ts", "wallet/src/pool/scan.ts",
     "wallet/src/pool/restore.ts", "wallet/test/pool.test.ts"],
    """Implement the wallet module for the pool: deposit with an ownerCommit derived from the seed and a counter,
    paying the value plus 0.2%; activate and refund; note discovery by trial decryption of Spent events from
    snapshot files; building a spend (input selection, an empty input when one note is enough, the ETH fee note
    for a relayed spend, optional reward claim) and proving it with prove.mjs; keeping a small shielded ETH note
    for relay fees and topping it up; restore.ts, which rebuilds every note from the seed and chain events alone;
    and plan.ts, which splits an amount into standard sizes, defaults deposits to standard sizes, and warns before
    several exits go to one address. """ + COMMON,
    ["The end-to-end scenario of B60 is driven entirely through this module against a local chain.",
     "plan.ts splits every multiple of 0.005 ETH below 1,000 ETH into at most 16 standard sizes and never leaves a remainder of 0.005 ETH or more; a deposit of a standard size becomes a note of exactly that size.",
     "restore.ts, given only the seed, recovers every note of the scenario with its value, accrued reward and index: activated deposits not yet spent, change, ETH fee change and reward notes.",
     "A relayed spend with no usable ETH fee note is refused with a clear message, and the module offers a self-sent spend or a top-up.",
     "A spend built against the previous checkpoint is rebuilt automatically when it would be stale.",
     "The module warns when a planned set of exits to one address sums to within 1% of a single deposit by the same wallet."],
    notes=STRUCT)

# ------------------------------------------------------------------ launch
job("L01", "Canary script and record", "build", "single", ["scaffold-project"], ["B60", "S02", "S03"],
    ["canary/script.md", "canary/run.ts", "canary/record.json", "canary/fork/", "canary/README.md"],
    """Write the canary's published script as a machine-readable list of steps covering every line of the build
    specification's canary checklist, and run.ts, which executes a step through the wallet and node modules and
    appends the transaction hash to record.json. The script runs on the canary parameter file and must reach every
    external function of the contracts and each of the seven circuit scenarios. Write, under canary/fork/, the
    tests for the paths the specification says cannot be reached on mainnet in 90 days: a launch that a block
    builder front-runs with bids and with a block's worth of ticks, a batch with more than 96 changed words, a
    stablecoin issuer freezing the pool, the end of the two-year vesting, and the 30-day screener wait. """ + COMMON,
    ["Run against a local fork with canary parameters, every step completes and record.json has a transaction hash for each.",
     "A coverage check lists every external function selector of the contracts and the step that calls it; none is missing.",
     "The script includes: a refused deposit refunded by its depositor and another by a third party; an activation that fails at a full cap and succeeds after a withdrawal; an epoch with no accepted batch; evictions for silence, for seven misses and for a transferred seat; a restore from seed; spends and refunds after deposits close.",
     "The funds the script needs at each step are listed, and the canary's caps can be filled with them.",
     "Each fork test under canary/fork/ passes and its result is written to a file the README links.",
     "canary/README.md states what a completed canary shows and what it does not."],
    notes=STRUCT + " Running the canary on mainnet is not part of this job and needs the lawyer's review first. It also needs at least seven seat holders willing to stake a canary token, which no job can arrange.")

job("L02", "Ceremony tooling", "build", "single", ["scaffold-project"], ["C04", "P04"],
    ["ceremony/contribute.sh", "ceremony/verify.sh", "ceremony/README.md", "ceremony/transcript/"],
    """Write the scripts for a public phase-2 ceremony for spend.r1cs with snarkjs: start from a powers-of-tau file
    pinned by hash, accept contributions one after another through pull requests that add one file and one
    attestation, apply a public random beacon at the end, and verify the whole chain. Anyone can run verify.sh. The
    scripts must refuse a transcript without the final beacon step. """ + COMMON,
    ["A rehearsal with five simulated contributors produces a final key that passes `snarkjs zkey verify` and check_vk.py.",
     "verify.sh fails on a transcript with a missing contribution, a reordered one, or no beacon.",
     "The r1cs hash checked by verify.sh equals the hash recorded by P04.",
     "ceremony/README.md says how a contributor checks that their contribution is included."],
    notes=STRUCT + " Who coordinates the real ceremony is an open question; the team operates nothing.")

# ------------------------------------------------------------------ output
def check(j):
    assert len(j["objective"]) <= 8000, (j["id"], len(j["objective"]))
    assert 1 <= len(j["skills"]) <= 6, j["id"]
    assert 1 <= len(j["accept"]) <= 8, (j["id"], len(j["accept"]))
    for a in j["accept"]: assert len(a) <= 500, (j["id"], len(a), a[:40])
    assert len(j["paths"]) <= 16, j["id"]
    assert len(j["contracts"]) <= 4, j["id"]
    body = j["objective"] + "".join(j["accept"]) + "".join(j["paths"])
    assert len(body.encode()) <= 12 * 1024, (j["id"], len(body))     # leaves room inside the 16 KiB request body

def slug(t): return "".join(c.lower() if c.isalnum() else "-" for c in t).strip("-").replace("--", "-").replace("--", "-")

KIND = {"build": "Build", "review": "Review", "audit": "Audit", "proof": "Proof"}
ids = {j["id"] for j in J}
for j in J:
    check(j)
    for d in j["depends"]: assert d in ids, (j["id"], d)
    lines = [f"# {j['id']} · {j['title']}", "",
             f"**Kind:** {KIND[j['kind']]} · **IMD template:** `{j['template']}` · **Steps:** {', '.join('`'+s+'`' for s in j['skills'])}",
             f"**Depends on:** {', '.join(j['depends']) if j['depends'] else 'nothing'}",
             "**Status:** draft. Not submitted. One request, 0.5 IMD.", "",
             "## Objective", "", textwrap.fill(j["objective"], 110), ""]
    if j["contracts"]:
        lines += ["## Contracts named", ""] + [f"- `{c}`" for c in j["contracts"]] + [""]
    lines += ["## Paths the job may write", ""] + [f"- `{p}`" for p in j["paths"]] + [""]
    lines += ["## Acceptance tests", ""] + [f"{n}. {a}" for n, a in enumerate(j["accept"], 1)] + [""]
    if j["notes"]:
        lines += ["## Notes", "", textwrap.fill(j["notes"], 110), ""]
    lines += ["## Inputs", "", "`repoUrl` and `baseCommit`: the project's public repository at the commit that contains the outputs of the jobs "
              "this one depends on. Resolve the commit with IMD's free import check before quoting.", ""]
    (HERE / f"{j['id']}-{slug(j['title'])}.md").write_text("\n".join(lines))

# index
order = [("Foundation and contracts", "B"), ("Fuzzing", "F"), ("Circuit", "C"), ("Proofs", "P"), ("Reviews", "R"),
         ("Audits", "A"), ("Node and wallet", "S"), ("Canary and ceremony", "L")]
idx = ["# Murmuration build plan", "",
       "Draft job briefs for the IMD swarm, written against the build specification in `reports/Murmuration v4 specification.html`. "
       "**None has been submitted, and none should be without the owner's decision.** Everything in a brief becomes public for good once it is.",
       "", "The briefs were regenerated on 11 November 2026 for revision 4.2 of the specification, which answers an independent review. "
       "Two reviews in two days each found faults in the fixes for the one before, so no brief should be submitted until a reviewer who has seen neither has read revision 4.2.",
       "", f"There are {len(J)} briefs. Each is sized for one IMD request under the limits IMD publishes (read 10 November 2026): an objective of at most "
       "8,000 characters, at most six steps of one skill each, at most eight acceptance criteria per step of 500 characters each, at most 16 writable paths, "
       "at most four contracts named, and a request body of at most 16 KiB. `generate.py` writes these files and fails if a brief breaks a limit.", "",
       "## What IMD checks, and what it does not", "",
       "- A request costs 0.5 IMD whatever its size. There are no refunds and no buyer acceptance step: IMD's own verifier accepts or rejects.",
       "- For Solidity the verifier runs `forge build`, `forge test` and Slither. Those briefs carry their acceptance tests as Foundry tests.",
       "- For everything else (Lean, Circom, TypeScript, scripts) the verifier checks only structure and paths. Those briefs name a `make` target, "
       "and a later review job, or anyone, re-runs it. Treat an accepted non-Solidity job as unverified until that has happened.",
       "- IMD's audit template is for Solidity: four specialists and a judge. Nothing public shows IMD has reviewed a zero-knowledge circuit. "
       "R03 supplies a circuit checklist and P01 to P04 put the weight on machine-checked proofs.",
       "- A job gets its inputs from a public GitHub repository at a pinned commit. The project needs one public repository that every job builds on.", "",
       "## Order", "",
       "1. B00, then C00 and R01. The owner reads R01 and signs off the frozen statements. Nothing in the proof track starts before that.",
       "2. Contracts B10 to B41 and the circuit C01 to C07 in parallel. Each contract's fuzz job follows it.",
       "3. Proofs P01 to P05, reviews R02 and R03, audits A01 to A05. Fixes go through `fix-findings` and the changed contract is audited again.",
       "4. B50, B51, B60, the node and wallet S01 to S03, R05.",
       "5. L01 and L02, then R04 on the real ceremony output. The lawyer's review comes before the canary runs.", "",
       "## Budget", "",
       f"{len(J)} requests are {len(J)*0.5:.1f} IMD, about ${len(J)*0.5*2.64:,.0f} at $2.64. Rejected attempts, fix rounds and second audits will "
       "multiply that several times. A plan of 300 to 600 requests, 150 to 300 IMD, is a reasonable working figure.", ""]
for name, prefix in order:
    idx += [f"## {name}", "", "| Id | Brief | Kind | Template | Depends on |", "|---|---|---|---|---|"]
    for j in J:
        if j["id"].startswith(prefix):
            idx.append(f"| {j['id']} | [{j['title']}]({j['id']}-{slug(j['title'])}.md) | {KIND[j['kind']]} | `{j['template']}` | {', '.join(j['depends']) or 'none'} |")
    idx.append("")
(HERE / "README.md").write_text("\n".join(idx))
kinds = {}
for j in J: kinds[j["kind"]] = kinds.get(j["kind"], 0) + 1
print(len(J), "briefs written:", kinds)
