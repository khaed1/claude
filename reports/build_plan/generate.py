#!/usr/bin/env python3
"""
Generates the Murmuration build-plan job briefs and checks each against IMD's published request limits
(imd.fun docs, read 10 Nov 2026; see research_notes/.../imd_audit_and_jobs_v3.md).
The briefs follow revision 4.3 of the specification (11 Nov 2026), which answers the reviews in
research_notes/.../adversarial_review_r42_core_v3.md and adversarial_review_r42_mechanisms_v3.md. Limits:
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
          "block.timestamp; no schedule may count blocks. Screening epochs count from Params.GENESIS; caps, emissions and "
          "the deposit window count from START, which the registry records at its first applied batch. If the specification is "
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
    ["foundry.toml", "Makefile", "params/mainnet.json", "params/canary.json", "script/gen_params.py", "script/check_params.py",
     "src/Params.sol", "src/lib/Addresses.sol", "README.md", ".github/workflows/check.yml"],
    """Create the project layout: Foundry project (solc 0.8.30, optimizer 200 runs, evm version pinned), a Makefile with
    targets check, sizes, gas and vectors, and two parameter files. params/mainnet.json holds every value in the
    specification's parameter table: the five assets with ids 1 to 5 (ETH, USDT, USDC, IMD, token), their caps,
    integer weights per base unit, units-per-ETH rates for the fee ceiling and exit sizes; GENESIS; epoch and
    checkpoint lengths in seconds; the fee-ceiling constants; the stake; the 730-day emission; auction constants;
    the token's name and symbol; the swarm root; the seat contract; the USDT, USDC and IMD addresses; the three
    Poseidon contracts with their code hashes. params/canary.json differs only in the salt, GENESIS, the token's
    name and symbol, the swarm root, the cap step (10 days), the emission period (81 days), the deposit window
    (85 days), the four starting caps (0.5 ETH, 1,000 USDT, 1,000 USDC, 50 IMD) and the screener wait (3 epochs).
    script/gen_params.py writes src/Params.sol from a parameter file. script/check_params.py computes the largest
    value the reward index can reach and fails at 2^88 or above. src/lib/Addresses.sol computes the addresses of
    the five deployed contracts from the Deployer's address and their fixed creation order. """ + COMMON,
    ["`make check` runs forge build and forge test and exits 0 on the empty project.",
     "`python3 script/gen_params.py params/mainnet.json` reproduces src/Params.sol byte for byte.",
     "`make sizes` fails if any deployed contract exceeds 24,576 bytes.",
     "params/canary.json differs from params/mainnet.json in exactly the keys named in the objective (a test lists the differing keys).",
     "check_params.py reports the largest reward index for both files, both under 2^88, and fails on a test file with a supply of 79 billion and unit weights.",
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
    insert per call, the last 64 roots kept in a ring, and leaf = H4(s0, s1, s2, s3) over four slots (a spend fills slots 0 to 2, an activation slot 0, every other slot is 0). Tests etch the hasher bytecode
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
    deposit(asset, value, ownerCommit) is open from launch (the token exists) until the deposit window closes; it
    pulls value + value/500 and checks that exactly that arrived (msg.value for ETH, zero msg.value for a token),
    stores keccak256 of depositor, asset, value, ownerCommit and deposit time, and adds to pending.
    activate(id, record), depositor only, requires Registry.isApproved(id, depositTime) and room under the cap
    counted on activated value, computes the commitment on-chain as H3(packed, index, ownerCommit), inserts
    H4(commitment, 0, 0, 0), moves value to shielded (tokenIn for the reward token) and value/500 to fees.
    refund(id, record) is open to the depositor in every state, and to anyone once the deposit is at least
    Params.REFUND_OPEN (21 days) old and Registry.isRefused(id, depositTime) is true. It always pays the
    depositor value plus fee and reverts if that payment fails. Token transfers go through SafeTransfer.sol,
    which accepts tokens that return no value and fails when the target has no code. The token's address is read
    once from Distribution.token() and cached. The reward index and roll are internal hooks that B13 and B14
    fill; use stubs. spend is out of scope. """ + COMMON,
    ["Only the depositor can activate (fuzzed caller). A third party can refund only when the deposit is refused and at least 21 days old, and the money still goes to the depositor.",
     "A deposit refused on day 2 and cleared on day 5 cannot be refunded by a third party at any time, and can be activated after it is cleared.",
     "A deposit ends in exactly one of activated or refunded; a second activate or refund reverts. A refund whose payment fails reverts and leaves the record.",
     "activate reverts when isApproved is false and when shielded + value would exceed cap(asset); the note's value is exactly the deposited value.",
     "deposit reverts before launch, after the deposit window, for an unlisted asset, below the smallest size, above the cap, with ownerCommit >= p, with ETH sent alongside a token, and when the amount received differs from value + value/500 (fee-on-transfer mock).",
     "A token whose transfer returns no value (USDT mock) deposits, activates and refunds correctly; a transfer to an address without code fails.",
     "For each asset, balance >= pending + shielded + fees after every call (invariant test, 5,000 runs).",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/Pool.sol"], notes=FOUNDRY)

job("B13", "Reward index library", "build", "impl_tests", ["implement-and-test"], ["B00"],
    ["src/lib/RewardIndex.sol", "test/RewardIndex.t.sol", "test/ref/reward_index.py"],
    """Implement RewardIndex.sol exactly as the reward-index box of the build specification: t = now - START;
    step = min(t / 90 days, LAST_STEP) in every formula; cap(a) = cap0(a) * 2^step; an emission rate per second
    of USERS * 2^step / D while t < 730 days and zero afterwards, where D is the sum of 2^step over the 730 days;
    g with 64 fractional bits, rounded down and held at 2^90 - 1; released rounded up and never above USERS;
    weighted over ETH, USDT, USDC and IMD with the integer weights; the floor of a quarter of weighted capacity.
    Nothing advances before START is known. roll(): reads START from the registry if it is still zero and does
    nothing more while it is zero; otherwise, if no checkpoint was taken in the current hourly window, advances
    g to now, then sets gPrev = gCur and gCur = g and records the window. Exactly one shift per call, however
    many windows have passed. roll never reverts. """ + COMMON,
    ["g never decreases and stays below 2^90 over the whole schedule at the smallest possible weighted total (test at weighted = 0 and = 1), for the mainnet and the canary parameter files.",
     "With parameters chosen to overflow, g stops at 2^90 - 1, released stops growing, and roll, activate and spend keep working.",
     "released never exceeds the users' allocation; equality within 1e-9 relative when the pool is at or above the floor for the whole 730 days.",
     "Differential test: 10,000 fuzzed sequences of balance changes and time jumps match the Python reference in test/ref within rounding bounds stated in the test.",
     "For any set of simulated notes, the sum of floor(weight*value*(gRef-index)/2^64) is at most released (invariant test).",
     "After any idle time, including 20 years, one roll leaves gPrev equal to the old gCur and gCur equal to g; a second roll in the same window changes nothing; roll does not revert in any reachable state (fuzz).",
     "Before START nothing is emitted and caps are those of step 0; after 730 days g stops changing and roll still rotates."],
    contracts=["src/lib/RewardIndex.sol"], notes=FOUNDRY)

job("B14", "Pool: spend and roll", "build", "impl_tests_review",
    ["implement-and-test", "write-foundry-tests", "adversarial-review"], ["B12", "B13"],
    ["src/Pool.sol", "src/interfaces/IVerifier.sol", "test/PoolSpend.t.sol", "test/mocks/MockVerifier.sol"],
    """Add the public roll() and spend(proof, inputs, ext) to the Pool. roll wraps B13's roll and also saves
    rootPrev = rootCur and rootCur = the current root, emitting CheckpointRolled(window, g, root). The 11 public
    inputs are, in order: root, nf0, nf1, C0, C1, C2, publicAmount, publicAsset, relayFee, gRef, extHash.
    ext is (recipient, relayer, ct0, ct1). spend works in the specification's order and checks every row of
    its public-input table: the root; nf0 and nf1 non-zero, unused and different; publicAmount zero or a
    standard size of publicAsset; relayFee at most feeCeiling(publicAsset); publicAsset zero exactly when
    publicAmount and relayFee are both zero, otherwise a listed asset; gRef equal to gCur or gPrev; extHash
    recomputed; recipient zero exactly when publicAmount is; relayer zero exactly when relayFee is; ct0 1,216
    bytes and ct1 96; every input below p. Then verify, mark both nullifiers, insert H4(C0, C1, C2, 0), and if
    publicAmount + relayFee is not zero advance the index, require the balance of publicAsset to cover the sum
    (token rule: tokenOut + publicAmount + relayFee <= tokenIn + released) and lower it by the sum, keep one
    five-hundredth of each of the two amounts as fees, emit Spent, and pay the relayer and then the recipient. feeCeiling in ETH is
    (FEE_K * block.basefee + FEE_TIP) * FEE_GAS; in another asset it is that times FEE_SLACK at the frozen
    units-per-ETH rate. ETH is paid by call with Params.PAY_GAS; a failed payment is credited to owed[address].
    Use a mock verifier in tests; real proofs come in B60. """ + COMMON,
    ["spend reverts on each broken row of the public-input table, one test per row, including nf1 equal to nf0, a non-zero publicAsset with nothing leaving, a zero publicAsset with a fee, a non-zero relayer with no fee, and a ciphertext of the wrong length.",
     "A withdrawal pays the recipient exactly amount - amount/500 for every listed size of every asset. The relayer receives relayFee - relayFee/500 in publicAsset, for ETH and for each token, with and without a public amount in the same spend.",
     "A relay fee above feeCeiling(publicAsset) reverts at any base fee (fuzz), so no sequence of spends moves more through the fee than the ceiling per spend.",
     "Total leaving per asset, public amounts and relay fees together, never exceeds total activated; for the token tokenOut never exceeds tokenIn + released (invariant test with a verifier that accepts everything).",
     "An ETH recipient or relayer that reverts, or uses more than the gas allowance, does not make spend fail: the amount is in owed and claimOwed delivers it. Re-entrancy from either cannot enter any Pool function.",
     "Root flush: after a roll and 65 further spends, a proof against rootCur is accepted; after the next roll it is accepted as rootPrev; after two rolls it is rejected.",
     "Gas for a relayed spend with the mock verifier is under 900,000 (snapshot), leaving room for 290,000 of verification.",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/Pool.sol"], notes=FOUNDRY)

job("B15", "Pool: fees, credits, key announcements, size and gas report", "build", "impl_tests", ["implement-and-test", "gas-and-size-report"], ["B14"],
    ["src/Pool.sol", "test/PoolFees.t.sol", "docs/gas-report.md"],
    """Add sweepFees (anyone, at most once per 86,400 seconds per asset and only when the fees are at least the
    asset's smallest exit size; sends the fees to the distributor and calls notify(asset)), claimOwed(address)
    (anyone; sends the credit to that address with all remaining gas, reverts if it fails), announce(key)
    (requires 1,216 bytes; emits the key and its keccak256; writes no storage) and the views cap, feeCeiling,
    checkpoints and isKnownRoot. The distributor's address comes from Addresses.sol. Produce docs/gas-report.md
    with measured gas for an ETH deposit, a USDT deposit, activate, refund, roll, a self-sent spend, a spend
    relayed for ETH and one relayed for USDT, under today's rules and under the EIP-8037/8038 rules computed
    from the storage operations each call performs, with the checkpoint write shown separately. """ + COMMON,
    ["sweepFees transfers exactly fees[asset], zeroes it, reverts if called twice within 86,400 seconds, and reverts below the smallest exit size.",
     "claimOwed pays only the address the credit was recorded for, clears it, and reverts when nothing is owed.",
     "announce writes no storage (state diff test) and reverts for any other length.",
     "Pool deployed size is at most 24,576 bytes (`make sizes`).",
     "docs/gas-report.md lists, per function, measured gas, new slots, overwritten slots and the Glamsterdam estimate; the relayed spend estimate is under 1,600,000.",
     "No Pool function sends an asset anywhere but a depositor, a recipient or relayer named in a verified call, an address with a recorded credit, or the distributor (a test enumerates every transfer site)."],
    contracts=["src/Pool.sol"], notes=FOUNDRY)

job("B20", "ScreenerRegistry: membership and stake", "build", "impl_tests_review",
    ["implement-and-test", "write-foundry-tests", "adversarial-review"], ["B10"],
    ["src/ScreenerRegistry.sol", "test/RegistryMembership.t.sol", "test/mocks/MockSeat.sol"],
    """Implement register, activate, requestExit, withdrawStake and evict, with activeCount, joining and the
    snapshot. Every state-changing function begins by closing the previous epoch if that has not been done;
    closing folds joining into activeCount and fixes snapActive (B21 and B22 add the rest of closing). register
    requires ownerOf(seatId) on the seat contract to be the caller and the seat not to be barred; if the seat
    has a record under an earlier holder that record is evicted first, in full; if it has a record under the
    caller it reverts. It takes Params.STAKE of the token, read from Distribution.token(). activate(seatId) is
    open to the holder or operator from Params.SCREENER_WAIT epochs after registering, checks the seat is still
    held, and adds the screener to joining, so it counts from the next epoch. evict is open to anyone and, after
    settling, removes the screener when the seat's owner is no longer the registered holder (an ownerOf call
    that reverts counts as not held), when it has not revealed for 7 epochs counted from the later of its last
    reveal and its first active epoch, or when it has 14 strikes (the counter is written by B21). For the last
    two grounds barredUntil[seatId] is set 90 epochs ahead. Exit and eviction move the stake to
    unbonding[holder], one total per holder, released 14 epochs after the latest addition. """ + COMMON,
    ["One live record per seat. register by a new owner over an old record leaves activeCount equal to the number of active records and moves the old stake to the old holder's unbonding; register by the same holder twice reverts.",
     "No screener counts in any snapshot before SCREENER_WAIT + 1 epochs after registering, including in the first epochs after launch (fuzz over registration times).",
     "activeCount equals the number of active records after every call (invariant test with seat transfers, exits, evictions and re-registrations in the handler).",
     "After the seat is transferred, commit by the old operator reverts and evict succeeds; a seat contract that reverts is treated as not held.",
     "A seat evicted for silence or strikes cannot be registered for 90 epochs, by any holder; a seat evicted because it changed hands can be registered at once.",
     "withdrawStake reverts before 14 epochs and pays exactly the stakes to the holder who posted them; no path reduces a stake.",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/ScreenerRegistry.sol"], notes=FOUNDRY)

job("B21", "ScreenerRegistry: commit, reveal, accept, apply", "build", "impl_tests_review",
    ["implement-and-test", "write-foundry-tests", "adversarial-review"], ["B20"],
    ["src/ScreenerRegistry.sol", "test/RegistryBatches.t.sol"],
    """Implement the epoch of 86,400 seconds from GENESIS: commit in the first 43,200, reveal in the next 28,800,
    and apply from acceptance until the epoch ends. Implement the tally with leadHash and leadCount, acceptance
    at two thirds of the snapshot rounded up with a snapshot of at least seven, and at closing the majority hash
    (the lead, if more than half of the snapshot revealed it). Strikes, worked out when a screener is settled:
    for each closed epoch in the ring with a majority hash in which the screener was active, minus one (floor
    zero) if it revealed that hash, plus two if it did not, silence included. A batch is {epoch, criteriaHash,
    upTo, words[], dataCid}, hashed as keccak256(abi.encode(...)) in that order. apply(batch) requires its hash
    to be the accepted batch of the current epoch, not yet applied, and at most 96 words; it sets dataTime to
    the start of the epoch, screenedThrough to upTo, overwrites the listed words, sets lastApplied, and on the
    first apply ever records start. isApproved(id, depositTime) is id <= screenedThrough, depositTime + 86,400
    <= dataTime, and bit clear; isRefused is the same two conditions and bit set. flag(seatId, depositId) and
    signalCriteria(seatId, hash) emit events. No commit is taken from Params.COMMIT_END_WAIT epochs after the
    deposit window closes. """ + COMMON,
    ["A batch is accepted exactly when matching reveals reach ceil(2n/3) with n >= 7 the snapshot count; never with n < 7; at most one per epoch (fuzz over reveal orders).",
     "A reveal that does not match the commitment, comes outside hours 12 to 20, or comes from a seat no longer held reverts; each screener commits and reveals once per epoch.",
     "apply reverts for a batch that is not the accepted batch of the current epoch, after the epoch has ended, a second time, or with more than 96 words. Batches of different epochs never depend on each other (a skipped epoch changes nothing for the next).",
     "No deposit with depositTime + 86,400 > dataTime is approved or refused, whatever upTo and the bitmap say: a batch with upTo = 2^64-1 and every bit set decides nothing made later than a day before its epoch (fuzz).",
     "Strikes: four of ten screeners silent six days and revealing on the seventh are evictable on day 9; alternating silence and junk reaches 14 in seven days; one miss in three never reaches 14; an epoch with no majority changes nobody's count.",
     "start is zero until the first apply and never changes afterwards.",
     "apply with 96 words uses under 3,000,000 gas today and under 16,777,216 execution gas under the EIP-8037 model in the test.",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/ScreenerRegistry.sol"], notes=FOUNDRY)

job("B22", "ScreenerRegistry: pay", "build", "impl_tests", ["implement-and-test"], ["B21"],
    ["src/ScreenerRegistry.sol", "test/RegistryPay.t.sol"],
    """Implement fund(asset), callable by the distributor, which adds to the pot whatever arrived: the registry's
    balance of the asset less everything it already accounts for. Implement the 16-slot ring, each slot tagged
    with its epoch and cleared when reused: the accepted hash, whether it was applied, the majority hash, how
    many revealed the accepted hash, and the pay per head in each asset. An epoch pays when its batch was both
    accepted and applied: at its closing the pot and one share of the screeners' token budget are divided
    equally among those who revealed the accepted hash, the remainder stays in the pot, and the amount per head
    is written to the ring. The budget is paid in 730 equal shares (paidEpochs counts them); after the 730th
    there is no token share. A screener is credited when settled (at its next commit, exit, withdrawal or
    eviction attempt), to owed[holder][asset], within 16 epochs. withdrawPay(assets) pays the caller. """ + COMMON,
    ["Each screener who revealed the accepted and applied batch is credited pot/agreed for every asset; others are credited nothing; the remainder stays in the pot.",
     "An epoch whose batch was accepted and not applied pays nobody, keeps its fees in the pot and does not use a token share.",
     "After 730 paid epochs the token paid equals SCREENER_BUDGET less rounding and never exceeds it; the 731st pays fees only.",
     "For each asset, balance >= pot + sum of owed, plus stakes, unbonding stakes and the unpaid budget for the token, after every call (invariant test).",
     "Pay earned through a seat that is then sold is paid to the holder who earned it, never to the buyer.",
     "A ring slot is read only when its tag matches: a screener settled after more than 16 epochs gets nothing for the overwritten epoch and never another epoch's pay.",
     "fund books the amount that arrived even when the token takes a fee on transfer (mock). Registry deployed size is at most 24,576 bytes."],
    contracts=["src/ScreenerRegistry.sol"], notes=FOUNDRY)

job("B30", "FeeDistributor: split and staking streams", "build", "impl_tests_review",
    ["implement-and-test", "write-foundry-tests", "adversarial-review"], ["B10", "B22"],
    ["src/FeeDistributor.sol", "test/DistributorStaking.t.sol"],
    """Implement notify(asset), callable by the Pool only. The receipt is what actually arrived: the balance
    less accounted[asset]. It is split 40/40/20. The stakers' 40% joins that asset's stream: what is left of
    the stream plus the new amount, paid evenly over the next 604,800 seconds. The screeners' 40% goes to the
    registry with fund(asset) when the registry's lastApplied is the current epoch or the one before, and
    otherwise joins the staker stream. The last 20% joins basketStream[asset], which B31 releases into the
    basket; for the project token it goes to the burn address, and for IMD it is added to buybackImd, a balance
    kept apart from IMD owed to stakers. With nothing staked, whatever would go to stakers follows the 20%.
    Implement fundBuyback(amount), and stake, unstake and claim with reward-per-token accounting per asset in
    which the per-token figure is scaled by 10^36 and the rate by 10^18. While nothing is staked a stream's
    clock stops and resumes at the next stake. Transfers use SafeTransfer.sol. """ + COMMON,
    ["The three parts of every notify add up to the receipt, with any remainder in the basket stream (fuzz), and the receipt is the measured balance increase even when the token takes a fee on transfer.",
     "Six-decimal asset: with the whole supply staked and one receipt of 1 USDT, stakers can claim the staker share to within one base unit per update, however often the stream is updated (fuzz over update times).",
     "A staker who stakes 12 seconds before a notify and unstakes 12 seconds after earns at most 24/604,800 of that receipt's staker share.",
     "A stream that runs while nothing is staked pays out in full to later stakers; nothing is stranded (test with a gap of 30 days).",
     "For each asset, balance >= accounted after every call (invariant test).",
     "The screeners' 40% goes to the registry only when lastApplied is the current or the previous epoch, and to stakers otherwise, including for ever after commits stop.",
     "notify from any address but the Pool reverts. For IMD the 20% lands in buybackImd, never in the basket, and buybackImd never overlaps IMD owed to stakers (invariant test).",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/FeeDistributor.sol"], notes=FOUNDRY)

job("B31", "FeeDistributor: basket auction", "build", "impl_tests", ["implement-and-test"], ["B30"],
    ["src/FeeDistributor.sol", "test/DistributorAuction.t.sol"],
    """Implement the basket stream and buy(assets, to, saleId, deadline, maxPay). Each receipt's 20% is released
    into basket[asset] evenly over 604,800 seconds. The price falls linearly from the starting price to
    Params.AUCTION_FLOOR over 86,400 seconds and stays at the floor; the first sale's clock starts at the first notify. The
    buyer names assets by id, must receive something, pays the price in IMD, which is added to buybackImd, and receives the released
    basket balance of each asset named. The next starting price is twice the price paid and at least
    Params.AUCTION_MIN_START. The design follows Euler's FeeFlowController (GPL-2.0-or-later, audited) with three
    changes: a non-zero floor, explicit basket balances instead of whole balances, and the seven-day release. """ + COMMON,
    ["Price at offsets 0, 43,200, 86,400 and 1,000,000 seconds equals start, the midpoint, floor and floor.",
     "After one notify the released basket at time t is 20% of the receipt times min(t, 604,800)/604,800, within 1 wei.",
     "buy reverts before the first notify, on a stale saleId, a passed deadline, a price above maxPay, or when the buyer would receive nothing.",
     "The buyer receives exactly the released basket of each named asset and nothing of the unreleased stream, the staker streams or the stakes.",
     "A sale that names all assets but one whose transfer reverts (blocklist mock) succeeds when that asset is left out.",
     "After a sale at price x the next starting price is max(2x, AUCTION_MIN_START).",
     "Re-entrancy through an ETH payout or a token callback cannot reach buy, claim or unstake."],
    contracts=["src/FeeDistributor.sol"], notes=FOUNDRY)

job("B32", "FeeDistributor: buyback through the locked pool", "build", "impl_tests_review",
    ["implement-and-test", "write-foundry-tests", "adversarial-review"], ["B31", "B40"],
    ["src/FeeDistributor.sol", "src/interfaces/IUniswapV3.sol", "test/DistributorBuyback.t.sol"],
    """Implement buyback(): at most once per 43,200 seconds, swap IMD for the token in the Uniswap v3 pool created by
    Distribution, exact input, no price limit, recipient the burn address. The token is token0 and IMD is token1
    in that pool, always. The amount is min(buybackImd, FEE * virtualImd / 2), where FEE is the pool's fee rate
    and virtualImd is Distribution.liquidity(), the constant recorded at launch, times the larger of
    slot0.sqrtPriceX96 and the starting square-root price. A token balance, pool.liquidity() or any other
    figure a third party can change is never used. When the amount is zero the call does nothing and the timer
    is not restarted. Implement uniswapV3SwapCallback, which pays only when called by that pool. Tests run
    against the real Uniswap v3 core bytecode. """ + COMMON,
    ["The step never exceeds half of fee rate times the locked position's virtual IMD reserve at the larger of the current and the starting price (fuzz over prices).",
     "With the price pushed to the minimum by a zero-cost swap while the position holds no IMD, the next step is the same size as at the starting price, not dust.",
     "The step is unchanged when a third party adds in-range liquidity, adds out-of-range IMD bids, or sends IMD to the pool (three tests).",
     "A second buyback within 43,200 seconds reverts; a call with nothing to spend does not start the timer.",
     "The swap callback reverts for any caller but the pool, and pays exactly the amount owed.",
     "Sandwich test with the price inside the locked range: for 200 fuzzed attacker sizes, buying before a step and selling after it loses money net of the two fees. A second test records what a sandwich takes when the price is below the start on thin outside liquidity; it is reported, not asserted to be zero.",
     "buybackImd falls only inside the callback; bought tokens arrive at the burn address.",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/FeeDistributor.sol"], notes=FOUNDRY + " The Uniswap v3 core artifacts are vendored as files because the job has no network.")

job("B40", "Distribution: launch and the locked position", "build", "impl_tests_review",
    ["implement-and-test", "write-foundry-tests", "adversarial-review"], ["B10"],
    ["src/Distribution.sol", "src/interfaces/IUniswapV3.sol", "test/DistributionLaunch.t.sol", "test/vendor/uniswap-v3-core/"],
    """Implement launch(), callable once by anyone from GENESIS. For n from 0 to 255 it computes the CREATE2
    address of the Token with the salt keccak256(abi.encode(block.prevrandao, msg.sender, n)) and takes the
    first candidate that is numerically below the IMD address and for which UniswapV3Factory.getPool(candidate,
    IMD, 10000) is the zero address; it reverts if none qualifies. It creates the Token there, sends 45% of
    supply to the Pool and 15% to the Registry, creates the pool, initializes it at the starting price, and
    mints one position with the 25% from the starting tick to the highest usable tick, owned by this contract.
    The starting tick is the starting price rounded down to a multiple of 200. It records token, pool, the
    position's liquidity and launchTime. There is no price reset: the pool cannot exist before this
    transaction. Implement the views token(), pool(), liquidity() and launchTime(), zero before launch, and the
    mint callback, restricted to the pool. """ + COMMON,
    ["After launch the Pool holds 45%, the Registry 15%, the position 25%, and 15% stays here for the swarm and founder, to the rounding stated in the test.",
     "launch reverts before GENESIS, and a second launch reverts. token(), pool(), liquidity() and launchTime() are zero before and constant after.",
     "The token's address is below IMD's for every prevrandao and caller (fuzz), so the token is token0 and the position holds tokens only.",
     "With pools created in the same block for the first 13 qualifying candidates, launch succeeds at the 14th; the front-runner's gas is at least 13 pool creations and launch's extra gas is under 150,000.",
     "With every one of the 256 candidates blocked (test-only cheat), launch reverts and changes nothing; a later block succeeds.",
     "Execution gas of launch is under 16,777,216 in every case above, and total gas under the EIP-8037 model is reported with the share that is state gas.",
     "No function in the ABI can call pool.burn with a non-zero amount; a test enumerates selectors and a symbolic test checks liquidity never falls.",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/Distribution.sol"], notes=FOUNDRY)

job("B41", "Distribution: vesting, swarm claims, fee collection", "build", "impl_tests", ["implement-and-test"], ["B40"],
    ["src/Distribution.sol", "test/DistributionVesting.t.sol"],
    """Implement claimFounder (pays the fixed founder address whatever has vested and not been paid; vested is zero
    until 2,592,000 seconds after launch and from then on 5% of supply times min(time since launch, 63,072,000)
    over 63,072,000), claimSwarm(index, account, amount, proof)
    against the fixed Merkle root with leaves keccak256(bytes.concat(keccak256(abi.encode(index, account,
    amount)))), linear over Params.SWARM_VEST from launch, and collect(): burn(0) then collect on the position, the
    IMD to the FeeDistributor through fundBuyback, the token part to the burn address. """ + COMMON,
    ["Founder payout at 0, 2,591,999, 2,592,000, 31,536,000 and 63,072,000 seconds after launch equals 0, 0, 30/730, 1/2 and all of the 5%.",
     "A swarm entry can never be paid more than its vested amount or its allocation; a wrong proof, index or amount reverts.",
     "The sum of all swarm claims in a fuzzed tree whose amounts total 10% never exceeds the 10%; script/check_swarm.py recomputes a list's total and root and fails unless the total is exactly 10%.",
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
    verify(proof, inputs[11]). Add script/check_vk.py, which reads a verification key and fails unless: the 12
    input points are pairwise different and none is the point at infinity; every point is on its curve and the
    G2 points are in the right subgroup; alpha, beta, gamma and delta are not the point at infinity; gamma and
    delta differ; delta is not the generator. Two production verifiers were exploited in February 2026 because
    a setup step was skipped and gamma equalled delta; this check is the guard. """ + COMMON,
    ["All valid fixture proofs verify; each fixture with any one of the 11 public inputs or one proof byte altered fails, including a fixture in which value is moved between publicAmount and relayFee with their sum unchanged.",
     "A public input equal to or above the field modulus is rejected.",
     "check_vk.py fails on a key with gamma == delta, a point off the curve, a G2 point outside the subgroup, two equal input points, an input point at infinity, and a wrong input count (six bad fixtures).",
     "Verification of 11 inputs costs under 270,000 gas (snapshot).",
     "The contract has no storage and no function besides verify."],
    contracts=["src/Verifier.sol"], notes=FOUNDRY + " The fixtures come from C06 and use a development setup, not the ceremony.")

job("B60", "End-to-end tests with real proofs", "build", "single", ["write-foundry-tests"], ["B50", "C06", "S03"],
    ["test/EndToEnd.t.sol", "test/fixtures/e2e/", "docs/e2e.md"],
    """Write end-to-end tests over the contracts deployed through the Deployer and launch() on a fork with real
    Uniswap v3, the real USDT and USDC bytecode and a mock seat contract, using proofs produced by C06 for a
    fixed scenario: deposits in ETH, USDT and IMD; a deposit refused, held past 21 days and refunded by a third
    party; activation; a self-sent transfer; an ETH transfer relayed for a fee in ETH; a USDT
    withdrawal relayed for a USDT fee by a wallet that holds one USDT note; a transfer with an empty input; a
    claim of reward; an ETH withdrawal to a contract that refuses payment, then claimOwed; a fee sweep; a
    basket sale; two buyback steps; a staker claim in USDT; a screener pay withdrawal. """ + COMMON,
    ["Every step of the scenario succeeds with the real Verifier and the fixture proofs, and every amount paid equals the amount the specification gives, to the base unit.",
     "Replaying any fixture proof a second time fails; replaying it against a second deployment with another address fails on extHash; submitting it with another relayer address fails.",
     "At the end, each capped asset's Pool balance equals pending + shielded + fees + owed exactly, and the reward paid is at most released.",
     "The scenario crosses one cap step by warping, and a proof built against gPrev and a checkpoint root still verifies after 65 other spends.",
     "A spend built with a relay fee one base unit above the ceiling is rejected at the block's base fee.",
     "docs/e2e.md lists each step with its gas."],
    notes=FOUNDRY)

# ------------------------------------------------------------------ fuzz
for fid, title, dep, harness, inv in [
    ("F01", "Fuzz: pool accounting", "B15", "test/fuzz/PoolAccounting.fuzz.sol",
     ["balance >= pending + shielded + fees (+ owed for ETH) for every capped asset, and for the token >= pending + fees + tokenIn - tokenOut",
      "public amounts plus relay fees out <= activated per asset, and for the token tokenOut <= tokenIn + released",
      "shielded <= cap at the time it last grew", "each deposit id ends activated or refunded at most once, and a refund always pays the depositor"]),
    ("F02", "Fuzz: reward budget", "B14", "test/fuzz/RewardBudget.fuzz.sol",
     ["the sum of reward computable by all live simulated notes plus reward already claimed is at most released",
      "released is at most the users' allocation", "g is monotone and below 2^90, and gCur and gPrev are never above g",
      "a note created and spent inside one checkpoint window earns zero"]),
    ("F03", "Fuzz: registry", "B22", "test/fuzz/Registry.fuzz.sol",
     ["at most one accepted batch per epoch, and only with two thirds of the snapshot count and at least seven",
      "no deposit younger than one day at the last applied batch's data time is approved or refused, and activeCount equals the number of active records",
      "token and fee balances cover pots, owed, stakes and unbonding stakes", "a stake is returned once, to its holder"]),
    ("F04", "Fuzz: distributor", "B32", "test/fuzz/Distributor.fuzz.sol",
     ["each receipt is split 40/40/20 with the remainder in the basket stream", "balance >= accounted for every asset, and each staker stream pays out what was put in to within one unit per update",
      "buybackImd only ever decreases through the swap callback",
      "a buyback step is at most half of fee rate times the locked position's virtual reserve at max(current, starting) price, at most once per 43,200 seconds"]),
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
    pinned to a commit. Spec.lean defines, as plain functions over field elements and naturals: key derivation,
    the packed word, the note commitment, the nullifier, the bundle leaf, Merkle root recomputation, the asset
    table with integer weights, earned reward as an integer floor division, and the predicate
    SpendValid(public, private) that is the conjunction of the fifteen constraints in the build specification,
    for two inputs, three outputs and the 11 public inputs. Challenge.lean
    states, with `sorry` proofs, part A of "What must be shown": the relation theorem (every assignment that
    satisfies the constraint system satisfies SpendValid) and the eleven lemmas, the last of which is
    completeness: for every state in the reachable ranges of the parameter table the honest witness satisfies
    the constraint system. Poseidon collision and preimage resistance appear as named hypotheses, never as
    axioms. circuit/SPEC.md restates each statement in plain words and lists parts B, C and D of the
    specification with where each is checked. No proofs in this job. """ + COMMON,
    ["`make lean-spec` (lake build of Spec.lean and Challenge.lean) succeeds with only the twelve expected `sorry` warnings.",
     "Every constraint 1-15 of the build specification maps to a named definition in Spec.lean, listed in a table in circuit/SPEC.md.",
     "Conservation and the reward bound are stated over the integers, not the field; publicAmount and relayFee enter conservation as a sum, and SPEC.md says which constraints separate them.",
     "The completeness lemma quantifies over explicit ranges taken from params/mainnet.json and params/canary.json, and SPEC.md lists them.",
     "SPEC.md names, for each of these broken circuits, the statement it violates: no spend authority; a free nk or rho in the nullifier; a free output index; a free output asset; an unbound extHash; publicAmount and relayFee sharing one column because a range check was dropped; a publicAsset that is free when a relay fee is paid; the same note in two inputs; a circuit that accepts nothing.",
     "No theorem has a hypothesis that is false for an honest spend; SPEC.md lists every hypothesis and why it is needed.",
     "The files' sha256 hashes are written to circuit/lean/FROZEN so later jobs can prove against an unchanged statement."],
    notes=STRUCT + " The statements are the trust anchor. R01 reviews them and the owner signs them off before any proof job starts. The first two lists in this specification were too weak: a circuit missing whole constraints satisfied the first, and a circuit that accepts nothing the second.")

job("C01", "Circuit gadgets in clean: ranges, division, selection", "build", "single", ["scaffold-project"], ["C00"],
    ["circuit/lean/Murmuration/Gadgets/Range.lean", "circuit/lean/Murmuration/Gadgets/Division.lean",
     "circuit/lean/Murmuration/Gadgets/AssetTable.lean", "circuit/lean/Murmuration/Gadgets/Pack.lean", "circuit/lean/test/Gadgets.lean"],
    """Implement as clean circuits, reusing clean's proved bit-decomposition and comparator ports: range checks of 2,
    32, 64, 90 and 96 bits; exact division by 2^64 with a 64-bit remainder; the asset table lookup that maps an asset
    id (1 to 5) to its constant weight and rejects zero and unlisted ids; the emptiness test on value + 2^96*accrued; and the packed word TAG_NOTE*2^200 + accrued*2^104 +
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
    """Compose the Spend circuit in clean from the gadgets: the fifteen constraints of the build specification over
    two inputs and three outputs, with the eleven public
    inputs in the order root, nf0, nf1, C0, C1, C2, publicAmount, publicAsset, relayFee, gRef, extHash. Export the constraint system as .r1cs and the witness generator as Circom-ABI WASM with
    clean's exporter, so that snarkjs can consume them without the Circom compiler. """ + COMMON,
    ["`make circuit` regenerates spend.r1cs and spend.wasm byte for byte from a clean checkout.",
     "snarkjs r1cs info reports 11 public inputs and a constraint count under 50,000, written to COUNTS.md with the count per gadget.",
     "A valid witness is produced for each of the nine scenarios in circuit/vectors/scenarios.json: self-sent transfer; transfer with one empty input; relayed transfer of ETH; relayed spend of a token from a single note; claim; withdrawal; relayed withdrawal; token withdrawal; and a spend at the largest values and index the parameter table allows.",
     "For each scenario, changing any single private input makes witness generation or constraint checking fail, or changes a public output.",
     "No satisfying witness exists with the same non-empty note in two inputs, with a note at slot 3, with an output of an asset other than the inputs' asset, or with publicAsset different from the asset while publicAmount + relayFee is not zero. The r1cs columns of publicAmount and relayFee are checked to be different.",
     "The public input order matches IVerifier in B14 (a shared JSON file checked by both)."],
    notes=STRUCT + " clean's R1CS exporter dates from September 2026 and has no known production use; C05 exists to test it.")

job("C05", "Independent Circom implementation as a test oracle", "build", "single", ["scaffold-project"], ["C00"],
    ["circuit/circom/spend.circom", "circuit/circom/lib/", "circuit/circom/test/differential.mjs", "circuit/circom/package.json", "Makefile"],
    """Write the same Spend circuit in Circom 2 with circomlib's Poseidon, by an agent that has not seen the clean
    implementation. It is never deployed. It exists so that two independent implementations can be compared:
    differential.mjs feeds the same inputs to both witness generators and compares all eleven public values. """ + COMMON,
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
    """Implement the wallet-side primitives in TypeScript exactly as "Keys, notes and addresses" in the build
    specification: spendRoot, viewRoot and the X-Wing key from the seed by HKDF-SHA256 with the stated labels;
    sk = spendRoot mod p; spk, nk, ownerPk; commitment and nullifier; rho and the diversifier of deposit n; rho
    and the diversifier of outputs 1 and 2 from nf0 and the slot; the ciphertext-1 key from nf0, C1 and C2;
    the long and short address formats. Ciphertext 0 is HPKE base mode with the X-Wing KEM (0x647A,
    draft-connolly-cfrg-xwing-kem-11), HKDF-SHA256 and ChaCha20-Poly1305, info "murmuration/v1/ct0" followed by
    the chain id and pool address: 1,120 bytes of encapsulation, the 80-byte payload (asset 1, value 12,
    accrued 12, rho 31, diversifier 8, memo 16) and a 16-byte tag. Ciphertext 1 is 96 bytes under the
    ciphertext-1 key with a zero nonce: value and accrued of outputs 1 and 2 (12 bytes each), the claim (12),
    20 spare bytes and a 16-byte tag. Empty inputs take fresh random rho, leafIndex and slot. Use audited
    libraries for X25519, ML-KEM-768, HKDF and the AEAD; write no primitive by hand. """ + COMMON,
    ["X-Wing passes the draft-11 test vectors in wallet/vectors/xwing.json.",
     "Commitments and nullifiers match the Lean specification on the shared scenario vectors.",
     "Every derivation matches wallet/vectors/derive.json, which a second implementation in another language also reproduces.",
     "Encrypt then decrypt round-trips 1,000 random notes; ciphertext 0 is exactly 1,216 bytes and ciphertext 1 exactly 96, with the byte layout of the specification (layout test).",
     "Two spends with the same first nullifier and different output amounts use different ciphertext-1 keys.",
     "A view-only wallet built from viewRoot, spk and nk decrypts every note and computes every nullifier and cannot produce a spend.",
     "Decryption with the wrong key or one flipped bit fails without throwing an unhandled error. A short address resolves to its key only when keccak256(key) matches."],
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

job("P04", "Proofs: the relation and its eleven lemmas", "proof", "single", ["scaffold-project"], ["C04", "P01", "P03"],
    ["circuit/lean/Murmuration/Proofs/Spend.lean", "circuit/lean/Murmuration/Proofs/Capstone.lean",
     "circuit/lean/Murmuration/Proofs/Complete.lean", "circuit/PROOFS.md"],
    """Prove the twelve theorems of Challenge.lean for the composed Spend circuit: the relation theorem (every
    satisfying assignment satisfies SpendValid) and lemmas 1 to 11 of part A of "What must be shown" in the build
    specification: spend authority; membership; one nullifier per note, as a function of the position, the rho
    inside ownerCommit and the nk inside ownerPk; no value created, with no position used twice and
    the public amount and the relay fee both counted; no reward created; outputs start at the checkpoint; the public
    asset is true; nothing is left free, in the exact form the specification gives; no wrap-around in
    constraints 8, 9, 12, 13 and 14, the packed word, the emptiness test and the position; every public input
    occurs in a surviving constraint and the public columns are linearly independent; and completeness over
    the reachable ranges. circuit/PROOFS.md lists each theorem, its Lean name, its hypotheses and its axioms. """ + COMMON + " " + PROOF_GATE,
    ["`make lean-proofs` passes with --wfail, no `sorry`, and `lake comparator` reports the twelve Challenge theorems proved against the frozen statements.",
     "Axiom check: only the allow-listed axioms plus the named Poseidon hypotheses, which appear as theorem hypotheses and not as axioms.",
     "The completeness proof covers every scenario class of C04 and the ends of every range, with the ranges read from the parameter files and not typed into the proof.",
     "The circuit proved is the one exported in C04: the build hashes spend.r1cs from the same Lean term the theorems are about.",
     "PROOFS.md states in plain words what is proved, what is assumed and what is only tested, and lists parts B, C and D with where each is covered.",
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
    notes=STRUCT + " These tools find bugs. They do not establish the relation or its lemmas, which is what P04 is for.")

# ------------------------------------------------------------------ reviews
job("R01", "Review: are the frozen statements the right ones", "review", "research", ["research-report"], ["C00"],
    ["docs/reviews/R01-statements.md"],
    """Panel review, five reviewers, quorum four, by agents that have not seen any circuit code. Read
    circuit/lean/Murmuration/Spec.lean, Challenge.lean and circuit/SPEC.md at the pinned commit and the build
    specification. Answer for the relation theorem and each of the eleven lemmas: does the Lean statement say
    what the plain-words statement says; is any hypothesis stronger than an honest prover satisfies; is anything
    quantified over the wrong set (field versus integers, any root versus a known root, some states versus all
    reachable states). Then try to break the list as a whole in both directions. Describe a circuit that
    satisfies all twelve statements and still lets someone spend a note that is not theirs, spend a note twice,
    create value or reward, change one asset into another, or redirect a payment. And describe a circuit that
    satisfies the eleven soundness statements and rejects an honest spend the pool can reach, and say whether
    the completeness lemma catches it. Propose a concrete counter-model for each weakness found. """,
    ["Each of the twelve statements gets a verdict: faithful, too weak (with a counter-model), or too strong (with an honest spend that violates a hypothesis).",
     "Each constraint 1-16 of the build specification is matched to a definition or reported missing.",
     "For each of the eight broken circuits named in C00, the report confirms which statement fails, or reports that none does.",
     "The ranges in the completeness lemma are checked against the parameter files and against what the Pool can produce, and any reachable state outside them is named.",
     "The report names every place where Spec.lean differs from the build specification, however small.",
     "Minimum of 3 citations to file and line per statement."],
    notes="IMD's research template takes panelSize, panelQuorum, minCitations and a rubric. The owner reads this report and signs the statements off before P01 starts.")

job("R02", "Review: circuit and contract interface", "review", "single", ["adversarial-review"], ["B14", "C04"],
    ["docs/reviews/R02-interface.md"],
    """Adversarial review, read-only, of the boundary between the Spend circuit and the Pool: the order and encoding
    of the eleven public inputs; reduction of extHash and of every input modulo p on both sides; that the tree,
    the bundle leaf and the commitment computed in Solidity equal the circuit's for the same note; that the
    checkpoint and the checkpoint root the Pool accepts are the ones the circuit used; that the zero conventions
    the circuit leaves to the contract are all enforced there; that the standard-size check and the per-asset limit
    use the same asset id as the proof; that the relayer paid is the one bound into extHash; that the fee ceiling
    and the 0.2% on the fee apply to publicAsset as the proof named it, and that no call can move value between publicAmount and relayFee of a proof. Try to construct a
    call that the Pool accepts with a meaning the circuit did not prove. """,
    ["Each of the eleven public inputs has a row: produced where, checked where, encoding, and whether a mismatch is possible.",
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
    in any constraint; nullifier not bound to the note it spends; empty inputs able to carry value or reward; public inputs that enter the constraints only as a sum and so share a column; a public asset left free; the same note in two inputs; a note accepted at slot 3;
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
     "check_vk.py passes: 12 input points pairwise different and none at infinity, subgroup checks, gamma and delta distinct, and the key recomputed from the final ceremony file by a second tool matches.",
     "A table shows the hash of spend.r1cs in three places: the P04 build, the ceremony and the fixtures; all equal.",
     "The verifier contract's constants match the key (script output included)."])

job("R05", "Review: launch, auction and buyback on a fork", "review", "single", ["adversarial-review"], ["B32", "B41"],
    ["docs/reviews/R05-market.md", "test/review/Market.t.sol"],
    """Adversarial review of the token's market mechanics on a mainnet fork with the real IMD token and Uniswap v3.
    Launch: as anyone who sees the launch transaction, including a block builder and a proposer who knows the
    next block's randomness, try to make launch revert, run out of gas or place the position wrongly, by
    creating pools for its candidate addresses; measure what each blocked candidate costs and how many fit in a
    block. Buyback: try to take value from a step by any sequence of swaps and liquidity changes; try to shrink
    or enlarge a step, including with the price parked below the range; measure what a holder gains by adding
    liquidity for one transaction. Auction: try to buy the basket below its value or strand an asset in it.
    Report what a third party can gain and at what cost. This step may write only the review test file. """,
    ["Each attack attempted is a Foundry test in test/review/Market.t.sol with the attacker's profit asserted.",
     "No attack blocks launch at a cost under that of creating pools for every qualifying candidate, and the report gives that cost in gas for a 60M and a 100M block.",
     "No attack shows a profit above gas cost with the price inside the locked range, or the finding is filed as high. What a sandwich or a one-transaction liquidity provider takes below or at the edge of the range is measured and reported.",
     "The report states what the launch caller gains by buying in the same transaction, in tokens and in dollars at the starting valuation.",
     "The report lists the IMD token's owner powers that affect this market, including administration of its bridge peers on Ethereum, and whether Uniswap's protocol fee is on for this pool."],
    notes="IMD's review skills are read-only by default; this brief needs a variant that may add one test file, or a build job that writes the tests followed by a read-only review.")

# ------------------------------------------------------------------ audits
for aid, title, dep, contracts, worry in [
    ("A01", "Audit: Token, Distribution, Deployer", ["B41", "B50"], ["src/Token.sol", "src/Distribution.sol", "src/Deployer.sol"],
     "any path that creates supply, reduces the locked position, pays the founder or a swarm entry early or twice, lets a third party block launch for less than the cost of creating a pool for every candidate, or places the position on the wrong side of the price"),
    ("A02", "Audit: Pool", ["B15"], ["src/Pool.sol", "src/lib/RewardIndex.sol", "src/lib/NoteTree.sol", "src/lib/Hash.sol"],
     "any path that moves a deposit to anyone but its depositor, lets a spend take more than was activated, pays more reward than released, pays a recipient or relayer the proof did not name, lets more leave through the relay fee than its ceiling, accepts one note twice in a spend, bypasses the cap or the screening check, makes roll revert, or leaves funds unable to move"),
    ("A03", "Audit: ScreenerRegistry", ["B22"], ["src/ScreenerRegistry.sol"],
     "acceptance of a batch with fewer than two thirds, approval of a deposit less than a day old at the batch's data time, a way for a minority to stop batches for longer than the strike rule allows or to evict honest screeners, an active count that drifts from the records, a batch that depends on another, loss or theft of stakes or pay, and any way for the registry to affect funds in the Pool"),
    ("A04", "Audit: FeeDistributor", ["B32"], ["src/FeeDistributor.sol"],
     "staking reward sniping, a blocked or underpriced basket sale, IMD leaving except through the pool swap, income in a six-decimal asset lost to rounding, a buyback step that a third party can enlarge or shrink, and extraction around a step"),
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
     "node/test/vectors/", "node/criteria/sanctions-flags-and-funding.v4.json", "node/package.json"],
    """Implement the screening program for the criteria file and the Batch rules in the specification. The base
    block is the last block whose timestamp is before the epoch's start, once finalized; the registry's bitmap is
    read there. Inputs are logs, receipts and the value of top-level transactions only. Only deposits still
    open are evaluated; a closed deposit's bit is written as 0. upTo is the highest deposit id at least one day
    old at the epoch's start. A word is listed when the bit of an open, covered deposit in it must change;
    words that set a bit come first, then words that only clear, each group ascending; at most 96; if more
    than 96 set a bit, list the first 96 and lower upTo to just below the first deposit of the first one left
    out; clear-only words that do not fit wait. Rules: deny listed(depositor); deny flagged(deposit), which
    needs Flag(seatId, depositId) events from more than half of the epoch's snapshot within 14 epochs; hold 7
    epochs when fundedByListed(depositor) is 25% or more; hold 3 epochs for a deposit over 10 ETH at the frozen
    weights from an address first funded within 72 hours. The file in force is the one more than two thirds
    of the snapshot's seats have signalled, each seat's latest signal counting, else the file named in the
    parameter file. dataCid is the CIDv1 (raw, sha2-256) of a canonical JSON file naming every refusal and its
    rule. No wall-clock time, no floating point. """ + COMMON,
    ["Two runs on different machines from the same recorded RPC responses produce byte-identical batch and explanation files, and both reproduce every vector in node/test/vectors/.",
     "Each rule has a test with a deposit it refuses and one it allows; dust sent by a listed address to a depositor changes nothing; a held deposit is cleared in the batch after its last hold epoch.",
     "A deposit made one second less than a day before the epoch's start is not covered; one made exactly a day before is.",
     "With 97 words that set a bit, the batch lists 96 and upTo stops below the first deposit of the 97th. With 90 that set and 20 that only clear, all 90 and the first 6 clears are listed and upTo is not lowered.",
     "Flags from half of the snapshot refuse nothing; from one more they refuse that deposit and no other deposit of the same address; the same flags refuse nothing 15 epochs later.",
     "A deposit that was activated or refunded never causes a word to be listed, whatever its depositor's status becomes.",
     "The batch hash equals the Solidity hash used by ScreenerRegistry.apply (shared vector)."],
    notes=STRUCT)

job("S02", "Node duty: commit, reveal, apply", "build", "single", ["scaffold-project"], ["S01"],
    ["node/src/duty/screener.ts", "node/src/duty/schedule.ts", "node/test/duty.test.ts", "node/README.md"],
    """Implement the screener duty for the node: call activate once the waiting period has passed; each epoch run
    S01 against the published test vectors first and refuse to commit if any fails; commit in the first 12 hours
    with a fresh salt kept on disk; reveal in hours 12 to 20; call apply as soon as a batch is accepted and
    before the epoch ends; withdraw pay on request. The duty warns its operator when its batch differs from the
    recorded majority hash and shows its strike count and how far it is from 14. It runs under its own Unix
    user with its own operator key and never reads IMD's worker files. It makes no call to api.imd.fun. """ + COMMON,
    ["Against a local chain with the contracts from B22, ten simulated nodes reach acceptance and apply the batch inside every epoch of a 20-epoch test.",
     "A node restarted between commit and reveal still reveals the committed batch (salt persisted).",
     "A node whose RPC returns different data from the others reveals a different hash, is not paid, and logs a warning with its strike count each epoch.",
     "With four of ten nodes silent six days in seven, the four become evictable within ten epochs and acceptance is daily again after they are evicted.",
     "If no node applies an accepted batch before the epoch ends, nobody is paid for it and the next epoch's batch covers the same deposits.",
     "No outbound request goes to any host other than the configured RPC and IPFS endpoints (network mock)."],
    notes=STRUCT)

job("S03", "Wallet flows for the pool", "build", "single", ["scaffold-project"], ["C06", "C07"],
    ["wallet/src/pool/deposit.ts", "wallet/src/pool/spend.ts", "wallet/src/pool/plan.ts", "wallet/src/pool/scan.ts",
     "wallet/src/pool/restore.ts", "wallet/test/pool.test.ts"],
    """Implement the wallet module for the pool and the wallet rules of the build specification: deposit with an
    ownerCommit derived from the seed and a counter, paying the value plus 0.2%; activate and refund; note
    discovery from snapshot files by trying the ciphertext-1 key and the X-Wing key on every Spent event;
    building a spend (input selection, empty inputs filled at random, optional reward claim) and proving it
    with prove.mjs. One proving policy: always the checkpoint root and gCur; roll first when the current window
    has no checkpoint; wait for the next roll before spending a newer note. Fee asset: ETH from a small fee
    note when the wallet has one, otherwise the asset being spent, with a notice that this shows the asset.
    Quotes: refuse one above the fee ceiling less a margin, and never hand the same inputs to a second relayer
    before the first quote has expired. restore.ts rebuilds every note from the seed and chain events alone,
    with a gap limit of 20 deposit counters. plan.ts splits an amount into standard sizes, defaults deposits
    to standard sizes, warns before several exits go to one address and before reward tokens are withdrawn to
    an address linked to other exits. The long address is the default; the short one needs announce and a
    warning about what it reveals. """ + COMMON,
    ["The end-to-end scenario of B60 is driven entirely through this module against a local chain.",
     "plan.ts splits every multiple of 0.005 ETH below 1,000 ETH into at most 16 standard sizes and never leaves a remainder of 0.005 ETH or more; a deposit of a standard size becomes a note of exactly that size.",
     "restore.ts, given only the seed, recovers every note of the scenario with its value, accrued reward and index: activated deposits not yet spent, change and reward notes, including when several deposits carry one ownerCommit.",
     "A wallet holding a single USDT note completes a relayed withdrawal with change and pays the fee in USDT; the wallet warns once per asset that relaying shows the asset, and can send the same spend itself with no relay fee.",
     "Every proof in a 200-spend test uses the checkpoint root and gCur; none mixes policies.",
     "A quote above the ceiling is refused before proving, and a second relayer is not given the same nullifiers while a quote is live.",
     "The module warns when a planned set of exits to one address sums to within 1% of a single deposit by the same wallet."],
    notes=STRUCT)

# ------------------------------------------------------------------ launch
job("L01", "Canary script and record", "build", "single", ["scaffold-project"], ["B60", "S02", "S03"],
    ["canary/script.md", "canary/run.ts", "canary/record.json", "canary/fork/", "canary/README.md"],
    """Write the canary's published script as a machine-readable list of steps covering the build specification's
    three canary lists, and run.ts, which executes a step through the wallet module and appends the transaction
    hash and the amounts paid to record.json. First list: lines the project completes as a user, each with the
    expected amount to the base unit. Second list: lines that depend on screeners; the script records them when
    they occur and never causes them. Under canary/fork/ write tests for the second list and for the paths that
    cannot be reached on mainnet in the time: a launch with pools created for its first candidates; launch
    under the gas rules in force; a batch in which more than 96 words set a bit; a stablecoin issuer freezing
    the pool and freezing a depositor; the end of the two-year vesting; the 30-day screener wait and the 90-day
    bar; the end of commits after deposits close. The script runs on the canary parameter file. """ + COMMON,
    ["Run against a local fork with canary parameters, every step of the first list completes and record.json has a transaction hash and an amount equal to the expected one for each.",
     "A coverage check lists every external function selector of the Pool, FeeDistributor, Distribution and Token and the step that calls it; none is missing.",
     "The first list includes a spend relayed for a fee in its own asset by a single-note wallet, an ETH payment refused and later claimed, a staker's USDT claim of the exact amount, and a restore from seed.",
     "No step of the first list needs a screener's key, and the funds each step needs are listed and add up to at most 10 ETH in value through the third cap step.",
     "Each fork test under canary/fork/ passes and its result is written to a file the README links.",
     "canary/README.md states what a completed canary shows and what it does not, in the words of the specification."],
    notes=STRUCT + " Running the canary on mainnet is not part of this job and needs the lawyer's review first. It also needs at least seven registered seats, which no job can arrange.")

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
       "", "The briefs were regenerated on 11 November 2026 for revision 4.3 of the specification, which answers the review of revision 4.2. "
       "Three reviews in two days each found high faults in the fixes for the one before, so no brief should be submitted until a review of revision 4.3 comes back with no high finding.",
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
