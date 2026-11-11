#!/usr/bin/env python3
"""
Generates the Murmuration build-plan job briefs and checks each against IMD's published request limits
(imd.fun docs, read 10 Nov 2026; see research_notes/.../imd_audit_and_jobs_v3.md):
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
          "No owner, admin, pause, upgrade or setter may appear in any contract. If the specification is ambiguous, "
          "stop and report the ambiguity instead of choosing.")

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
     "README.md", ".github/workflows/check.yml"],
    """Create the project layout: Foundry project (solc 0.8.30, optimizer 200 runs, evm version pinned), a Makefile with
    targets check, sizes, gas and vectors, and two parameter files. params/mainnet.json holds every value in the
    specification's parameter table (assets, caps, weights, exit sizes, epoch lengths, stake, emission steps, auction
    constants, seat contract and IMD token addresses). params/canary.json differs only in the cap step length, the
    emission period, the deposit window and the salt. script/gen_params.py writes src/Params.sol from a parameter file
    so that no constant is typed by hand in a contract. """ + COMMON,
    ["`make check` runs forge build and forge test and exits 0 on the empty project.",
     "`python3 script/gen_params.py params/mainnet.json` reproduces src/Params.sol byte for byte.",
     "`make sizes` fails if any deployed contract exceeds 24,576 bytes.",
     "params/canary.json differs from params/mainnet.json in exactly the four keys named in the objective.",
     "No parameter appears as a literal in src/ outside src/Params.sol (a grep test enforces it)."],
    notes=STRUCT)

# ------------------------------------------------------------------ contracts
job("B10", "Token", "build", "impl_tests", ["implement-and-test"], ["B00"],
    ["src/Token.sol", "test/Token.t.sol"],
    """Implement the Token contract: a plain ERC-20 with 18 decimals whose constructor creates the whole supply for the
    Distribution address passed in. No owner, mint, burn function, permit, hook, fee or blocklist. """ + COMMON,
    ["totalSupply equals Params.SUPPLY after construction and after any sequence of transfers (invariant test).",
     "The ABI contains only the ERC-20 functions and events; a test enumerates selectors and fails on any other.",
     "transfer and transferFrom move exactly the amount requested and revert on insufficient balance or allowance.",
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
    ["src/Pool.sol", "src/interfaces/IRegistry.sol", "test/PoolDeposit.t.sol", "test/mocks/MockRegistry.sol", "test/mocks/Tokens.sol"],
    """Implement the Pool's deposit, activate and refund functions and their accounting exactly as in the build
    specification: record hash per deposit, pending/shielded/fees per asset, the cap counted on activated value only,
    the 7,200-block minimum age, Registry.isApproved read at activation, the entry fee of amount/500, the commitment
    computed on-chain as H3(packed, index, ownerCommit) and inserted as H4(commitment, 0, 0, 0). The reward index is
    read through an internal hook that B13 fills; use a stub returning a stored value. spend is out of scope. """ + COMMON,
    ["Only the depositor can activate or refund; any other caller reverts (fuzzed caller).",
     "A deposit ends in exactly one of activated or refunded; a second activate or refund reverts.",
     "refund returns exactly the deposited amount in every screening state, including refused, and after the deposit window.",
     "activate reverts before 7,200 blocks, when not approved, and when shielded + net would exceed cap(asset).",
     "deposit reverts after DEPOSIT_END, for an unlisted asset, below the smallest size, and when the amount received differs from the amount named (fee-on-transfer mock).",
     "For each asset, balance >= pending + shielded + fees after every call (invariant test, 5,000 runs).",
     "The emitted commitment equals the reference computed in the test from the event fields.",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/Pool.sol"], notes=FOUNDRY)

job("B13", "Reward index library", "build", "impl_tests", ["implement-and-test"], ["B00"],
    ["src/lib/RewardIndex.sol", "test/RewardIndex.t.sol"],
    """Implement RewardIndex.sol: the accumulator g with 64 fractional bits, the weighted total, the divisor floor of
    a quarter of capacity at the current cap step, emission per block per step in proportion to the caps, released,
    and the 300-block checkpoints gCur and gPrev. accrueTo(block) must handle any number of cap-step boundaries since
    the last call. g rounds down, released rounds up. """ + COMMON,
    ["g never decreases and stays below 2^90 over the whole schedule at the smallest possible weighted total (test at weighted = 0 and = 1).",
     "released never exceeds the users' allocation; equality within 1e-9 relative when the pool is at or above the floor for the whole schedule.",
     "Differential test: 10,000 fuzzed sequences of balance changes and block jumps match a Python reference in test/ref within rounding bounds stated in the test.",
     "For any set of simulated notes, the sum of floor(weight*value*(gRef-index)/2^64) is at most released (invariant test).",
     "After the last emission step g stops changing.",
     "The checkpoint at an epoch boundary equals g at that block whether or not any call happened in the epoch before."],
    contracts=["src/lib/RewardIndex.sol"], notes=FOUNDRY)

job("B14", "Pool: spend", "build", "impl_tests_review",
    ["implement-and-test", "write-foundry-tests", "adversarial-review"], ["B12", "B13"],
    ["src/Pool.sol", "src/interfaces/IVerifier.sol", "test/PoolSpend.t.sol", "test/mocks/MockVerifier.sol"],
    """Add spend to the Pool: checkpoint roll, known-root check, gRef equal to gCur or gPrev, extHash recomputed as
    keccak256(chainid, pool address, recipient, keccak(ct0), keccak(ct1)) reduced mod p, two unused and distinct
    nullifiers, and for a non-zero public amount: a standard size of that asset (1, 2, 5 times a power of ten within
    the asset's range), the per-asset limit (for the token: tokenOut + amount <= tokenIn + released), the exit fee of
    amount/500 and payment of the rest to the recipient. Then verify through IVerifier, mark nullifiers, insert one
    leaf H4(C0..C3), emit Spent with both ciphertexts. Wire B13's library in place of the stub. Use a mock verifier
    in tests; real proofs come in B60. """ + COMMON,
    ["spend reverts on: unknown root, stale gRef, wrong extHash, a used nullifier, equal nullifiers, a public input >= p, a non-standard size, publicAsset != 0 with publicAmount == 0.",
     "A withdrawal pays the recipient exactly amount - amount/500 and adds amount/500 to fees, for every listed size of every asset.",
     "Total withdrawn per asset never exceeds total activated; for the token never exceeds activated + released (invariant test with a verifier that accepts everything).",
     "Re-entrancy from an ETH recipient or a token callback cannot enter any Pool function (test with attacking mocks).",
     "A spend with publicAmount == 0 moves no asset and changes no balance.",
     "Gas for a spend with the mock verifier is under 900,000 (snapshot), leaving room for 255,000 of verification.",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/Pool.sol"], notes=FOUNDRY)

job("B15", "Pool: fees, key announcements, size and gas report", "build", "impl_tests", ["implement-and-test", "gas-and-size-report"], ["B14"],
    ["src/Pool.sol", "test/PoolFees.t.sol", "docs/gas-report.md"],
    """Add sweepFees (anyone, once per 7,200 blocks per asset, sends fees to the distributor and calls notify),
    announce (event only) and the views cap, checkpoint and isKnownRoot. Produce docs/gas-report.md with measured gas
    for deposit, activate, refund and spend, today's rules and the EIP-8037/8038 rules computed from the storage
    operations each call performs. """ + COMMON,
    ["sweepFees transfers exactly fees[asset], zeroes it, and reverts if called twice within 7,200 blocks.",
     "announce writes no storage (state diff test).",
     "Pool deployed size is at most 24,576 bytes (`make sizes`).",
     "docs/gas-report.md lists, per function, measured gas, new slots, overwritten slots and the Glamsterdam estimate; the spend estimate is under 1,500,000."],
    contracts=["src/Pool.sol"], notes=FOUNDRY)

job("B20", "ScreenerRegistry: membership and stake", "build", "impl_tests_review",
    ["implement-and-test", "write-foundry-tests", "adversarial-review"], ["B10"],
    ["src/ScreenerRegistry.sol", "test/RegistryMembership.t.sol", "test/mocks/MockSeat.sol"],
    """Implement register, requestExit, withdrawStake and evict, with the active count and its per-epoch snapshot.
    register requires ownerOf(seatId) on the seat contract to be the caller and takes Params.STAKE. A screener counts
    from epoch registered + 30, or from epoch 7 if registered before epoch 7. evict is open to anyone when the seat's
    owner is no longer the registered holder, when the screener has not revealed for 7 epochs, or when it has missed
    7 accepted batches. Stakes return 14 epochs after exit or eviction, to the holder only. """ + COMMON,
    ["One registration per seat; a second reverts until the first has exited or been evicted.",
     "A screener registered in epoch e >= 7 is not counted before epoch e + 30; one registered in epochs 0-6 counts from epoch 7.",
     "After the seat is transferred, commit by the old operator reverts and evict succeeds.",
     "withdrawStake reverts before 14 epochs and pays exactly the stake to the registered holder afterwards; no path reduces a stake.",
     "activeCount equals the number of screeners that are registered, past their start epoch and not exited or evicted (invariant test).",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/ScreenerRegistry.sol"], notes=FOUNDRY)

job("B21", "ScreenerRegistry: commit, reveal, accept, apply", "build", "impl_tests_review",
    ["implement-and-test", "write-foundry-tests", "adversarial-review"], ["B20"],
    ["src/ScreenerRegistry.sol", "test/RegistryBatches.t.sol"],
    """Implement commit (first 4,800 blocks of an epoch), reveal (last 2,400), the tally, acceptance at two thirds of
    the screeners active at the epoch's start with at least seven active, apply(batch), isApproved(id) and flag.
    A batch is {epoch, criteriaHash, upTo, words[], dataCid}; apply requires its hash to equal an accepted batch newer
    than the last applied, raises screenedThrough (never lowers it) and overwrites each listed bitmap word; at most 96
    words. """ + COMMON,
    ["A batch is accepted exactly when matching reveals reach ceil(2n/3) with n >= 7 the snapshot count; never with n < 7.",
     "A reveal that does not match the screener's commitment, or arrives outside the reveal window, reverts; each screener reveals once per epoch.",
     "Two different batches can never both be accepted in one epoch (fuzz over reveal orders).",
     "apply reverts for a batch that is not accepted, is older than the last applied, lowers screenedThrough, or lists more than 96 words.",
     "isApproved(id) is true exactly when id <= screenedThrough and its bit is clear.",
     "apply with 96 words uses under 3,000,000 gas today and under 16,777,216 execution gas under the EIP-8037 model in the test.",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/ScreenerRegistry.sol"], notes=FOUNDRY)

job("B22", "ScreenerRegistry: pay", "build", "impl_tests", ["implement-and-test"], ["B21"],
    ["src/ScreenerRegistry.sol", "test/RegistryPay.t.sol"],
    """Implement fund(asset, amount) from the distributor, the per-asset pot, the 16-epoch ring of accepted batch,
    agree count and pay per head, settlement of a screener's previous reveal at its next commit, withdrawPay, and the
    token stream: each accepted epoch within the first 730 adds SCREENER_BUDGET/730 to the token pot; an epoch with
    no accepted batch adds nothing and its share stays locked. """ + COMMON,
    ["Each screener who revealed the accepted batch is credited pot/agreed for every asset; others are credited nothing.",
     "Fees received in an epoch with no accepted batch are paid in the next accepted epoch; the token share of that epoch is never paid.",
     "For each asset, balance >= pot + sum of owed (+ stakes and the unpaid budget for the token) after every call (invariant test).",
     "A screener that settles after more than 16 epochs gets nothing for the overwritten epoch and nothing reverts.",
     "Total token paid to screeners never exceeds SCREENER_BUDGET.",
     "Registry deployed size is at most 24,576 bytes."],
    contracts=["src/ScreenerRegistry.sol"], notes=FOUNDRY)

job("B30", "FeeDistributor: split and staking streams", "build", "impl_tests_review",
    ["implement-and-test", "write-foundry-tests", "adversarial-review"], ["B10", "B22"],
    ["src/FeeDistributor.sol", "test/DistributorStaking.t.sol"],
    """Implement notify(asset, amount), callable by the Pool only, splitting each receipt 40/40/20: 40% into that
    asset's staker stream restarted to pay evenly over the next 50,400 blocks, 40% sent to the registry with fund,
    20% to basket[asset]; for the project token the 20% goes to the burn address, and for IMD it is added to buybackImd,
    a balance kept apart from IMD owed to stakers; with nothing staked the stakers' 40% follows the 20%. Implement
    fundBuyback(amount), which pulls IMD from the caller into buybackImd, and stake, unstake and claim with
    reward-per-token accounting per asset. """ + COMMON,
    ["The three parts of every notify add up to the amount, with any remainder in the basket (fuzz).",
     "A staker who stakes one block before a notify and unstakes one block after earns at most 2/50,400 of that receipt's staker share.",
     "Two stakers with equal stake over the same blocks earn equal amounts within 1 wei per asset.",
     "For each asset, balance >= unpaid stream + sum owed + basket after every call (invariant test).",
     "Staked tokens return only to their staker; unstake of more than staked reverts.",
     "notify from any address but the Pool reverts. For IMD the 20% lands in buybackImd, never in the basket, and buybackImd never overlaps IMD owed to stakers (invariant test).",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/FeeDistributor.sol"], notes=FOUNDRY)

job("B31", "FeeDistributor: basket auction", "build", "impl_tests", ["implement-and-test"], ["B30"],
    ["src/FeeDistributor.sol", "test/DistributorAuction.t.sol"],
    """Implement buy(assets, to, saleId, deadline, maxPay): the price falls linearly from the starting price to
    Params.AUCTION_FLOOR over 7,200 blocks and stays at the floor; the buyer pays the price in IMD, which is added to
    buybackImd; the buyer receives basket[asset] of each asset named; the next starting price is
    twice the price paid and at least Params.AUCTION_MIN_START. The design follows Euler's FeeFlowController
    (GPL-2.0-or-later, audited) with two changes: a non-zero floor, and explicit basket balances instead of whole
    balances. """ + COMMON,
    ["Price at block offsets 0, 3,600, 7,200 and 100,000 equals start, the midpoint, floor and floor.",
     "buy reverts on a stale saleId, a passed deadline, or a price above maxPay.",
     "The buyer receives exactly basket[asset] for each named asset and nothing of the staker streams or stakes.",
     "A sale that names all assets but one whose transfer reverts (blocklist mock) succeeds when that asset is left out.",
     "After a sale at price x the next starting price is max(2x, AUCTION_MIN_START).",
     "Re-entrancy through an ETH payout or a token callback cannot reach buy, claim or unstake."],
    contracts=["src/FeeDistributor.sol"], notes=FOUNDRY)

job("B32", "FeeDistributor: buyback through the locked pool", "build", "impl_tests_review",
    ["implement-and-test", "write-foundry-tests", "adversarial-review"], ["B31", "B40"],
    ["src/FeeDistributor.sol", "src/interfaces/IUniswapV3.sol", "test/DistributorBuyback.t.sol"],
    """Implement buyback(): at most once per 25 blocks, swap IMD for the token in the Uniswap v3 pool created by
    Distribution, exact input, recipient the burn address. The amount is min(buybackImd, FEE * virtualImdReserve / 2)
    where virtualImdReserve is computed from pool.liquidity() and slot0.sqrtPriceX96 for IMD's side of the pair, and
    FEE is the pool's fee rate. Implement uniswapV3SwapCallback, which pays only when called by that pool. Tests run
    against the real Uniswap v3 core bytecode. """ + COMMON,
    ["The step never exceeds half of fee rate times IMD-side virtual reserves, for token0 and token1 orderings (fuzz over prices).",
     "A second buyback within 25 blocks reverts.",
     "The swap callback reverts for any caller but the pool, and pays exactly the amount owed.",
     "Sandwich test: for 200 fuzzed attacker sizes, buying before a step and selling after it loses money net of the two fees.",
     "buybackImd falls only inside the callback; a test enumerates every external function and checks it, and IMD owed to stakers is untouched by a buyback.",
     "Bought tokens arrive at the burn address and the pool's IMD balance rises by the amount spent.",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/FeeDistributor.sol"], notes=FOUNDRY + " The Uniswap v3 core artifacts are vendored as files because the job has no network.")

job("B40", "Distribution: launch and the locked position", "build", "impl_tests_review",
    ["implement-and-test", "write-foundry-tests", "adversarial-review"], ["B10"],
    ["src/Distribution.sol", "src/interfaces/IUniswapV3.sol", "test/DistributionLaunch.t.sol", "test/vendor/uniswap-v3-core/"],
    """Implement launch(), callable once by anyone: send 45% of supply to the Pool and 15% to the Registry; create the
    token/IMD Uniswap v3 pool at the 1% tier if absent; initialize it at the starting price if not initialized; if it
    is initialized above the starting price, swap at most Params.LAUNCH_RESET_MAX tokens with a price limit at the
    start and revert if the price is still above it; then mint one position from the start tick to the maximum usable
    tick with 25% of supply, owned by this contract. Implement the mint and swap callbacks, restricted to the pool. """ + COMMON,
    ["After launch the five destinations hold 45%, 25% (in the pool), 15%, and 15% left here for the swarm and founder, to the wei of rounding stated in the test.",
     "launch succeeds when the pool does not exist, exists uninitialized, is initialized at the start, below it, and above it with dust liquidity.",
     "launch reverts, changing nothing, if bringing the price down would need more than LAUNCH_RESET_MAX tokens.",
     "The position is one-sided in the token for both token orderings (test with two IMD mock addresses).",
     "No function in the ABI can call pool.burn with a non-zero amount; a test enumerates selectors and a symbolic test checks liquidity never falls.",
     "A second launch reverts. Callbacks revert for any caller but the pool.",
     "The adversarial review step reports no high or critical finding, or each one is fixed and re-reviewed."],
    contracts=["src/Distribution.sol"], notes=FOUNDRY)

job("B41", "Distribution: vesting, swarm claims, fee collection", "build", "impl_tests", ["implement-and-test"], ["B40"],
    ["src/Distribution.sol", "test/DistributionVesting.t.sol"],
    """Implement claimFounder (nothing for the first 216,000 blocks after launch, then linear to 5,256,000 blocks, to
    the fixed founder address), claimSwarm(index, account, amount, proof) against the fixed Merkle root with leaves
    keccak256(abi.encode(index, account, amount)) double-hashed, linear over Params.SWARM_VEST from launch, and
    collect(): burn(0) then collect on the position, IMD to the FeeDistributor through fundBuyback, token part to the burn address. """ + COMMON,
    ["Founder payout at 0, 215,999, 216,000, 2,628,000 and 5,256,000 blocks equals 0, 0, 216000/5256000, 1/2 and all of the 5%.",
     "A swarm entry can never be paid more than its vested amount or its allocation; a wrong proof, index or amount reverts.",
     "The sum of all swarm claims in a fuzzed tree never exceeds the 10%.",
     "collect sends fees only to the FeeDistributor and the burn address and leaves liquidity unchanged.",
     "Distribution deployed size is at most 24,576 bytes."],
    contracts=["src/Distribution.sol"], notes=FOUNDRY)

job("B50", "Deployer and deployment script", "build", "impl_tests", ["implement-and-test", "deploy-script"], ["B15", "B22", "B32", "B41", "B51"],
    ["src/Deployer.sol", "script/Deploy.s.sol", "test/Deployer.t.sol", "docs/deploy.md"],
    """Implement Deployer: its constructor stores six creation-code hashes in order; deploy(i, code) creates contract
    i with CREATE if keccak256(code) matches hash i and all earlier ones exist. Because addresses follow from the
    Deployer's address and its nonce, the script computes all six in advance and passes them as constructor
    arguments. Deploy.s.sol deploys the Deployer through the deterministic proxy at
    0x4e59b44847b379578588920cA78FbF26c0B4956C with the salt from the parameter file, then one contract per
    transaction, then calls launch. """ + COMMON,
    ["deploy reverts for wrong code, wrong order, or an index already deployed; anyone can call it.",
     "Each deployed contract's stored addresses of the other five equal the actual deployed addresses.",
     "The Deployer has no function other than deploy and views, and holds no funds.",
     "Running the script twice from clean state with the same parameter file gives identical addresses.",
     "docs/deploy.md lists each transaction with its gas today and under EIP-8037, and none needs more than 16,777,216 execution gas."],
    contracts=["src/Deployer.sol"], notes=FOUNDRY)

job("B51", "Verifier and verification-key checks", "build", "impl_tests", ["implement-and-test"], ["C06"],
    ["src/Verifier.sol", "test/Verifier.t.sol", "script/check_vk.py", "test/fixtures/proofs/"],
    """Wrap the snarkjs-generated Groth16 verifier for the Spend circuit as Verifier.sol with one view function
    verify(proof, inputs[11]). Add script/check_vk.py, which reads a verification key and fails unless gamma and
    delta are distinct, neither is the generator, all points are on the curve and in the right subgroup, and the
    number of IC points is 12. Two production verifiers were exploited in February 2026 because a setup step was
    skipped and gamma equalled delta; this check is the guard. """ + COMMON,
    ["All valid fixture proofs verify; each fixture with one public input or one proof byte altered fails.",
     "A public input equal to or above the field modulus is rejected.",
     "check_vk.py fails on a key with gamma == delta, on a point off the curve, and on a wrong IC count (three bad fixtures).",
     "Verification of 11 inputs costs under 270,000 gas (snapshot).",
     "The contract has no storage and no function besides verify."],
    contracts=["src/Verifier.sol"], notes=FOUNDRY + " The fixtures come from C06 and use a development setup, not the ceremony.")

job("B60", "End-to-end tests with real proofs", "build", "single", ["write-foundry-tests"], ["B50", "C06", "S03"],
    ["test/EndToEnd.t.sol", "test/fixtures/e2e/", "docs/e2e.md"],
    """Write end-to-end tests over all six contracts deployed through the Deployer on a fork with real Uniswap v3 and
    a mock seat contract, using proofs produced by C06 for a fixed scenario: three deposits in two assets, a refused
    deposit and its refund, activation, a transfer with a relay fee note, a transfer with a padding input, a claim of
    reward, withdrawals at two sizes, a fee sweep, a basket sale, three buyback steps, a staker claim and a screener
    pay withdrawal. """ + COMMON,
    ["Every step of the scenario succeeds with the real Verifier and the fixture proofs.",
     "Replaying any fixture proof a second time fails; replaying it against a second deployment with another address fails on extHash.",
     "At the end, each asset's Pool balance equals pending + shielded + fees exactly, and the reward paid is at most released.",
     "The scenario crosses one cap step and one emission step by warping, and a proof built against gPrev still verifies.",
     "docs/e2e.md lists each step with its gas."],
    notes=FOUNDRY)

# ------------------------------------------------------------------ fuzz
for fid, title, dep, harness, inv in [
    ("F01", "Fuzz: pool accounting", "B15", "test/fuzz/PoolAccounting.fuzz.sol",
     ["balance >= pending + shielded + fees for every asset", "withdrawn <= activated per asset, and for the token <= activated + released",
      "shielded <= cap at the block it last grew", "each deposit id ends activated or refunded at most once"]),
    ("F02", "Fuzz: reward budget", "B14", "test/fuzz/RewardBudget.fuzz.sol",
     ["the sum of reward computable by all live simulated notes plus reward already claimed is at most released",
      "released is at most the users' allocation", "g is monotone and below 2^90", "a note created and spent inside one checkpoint earns zero"]),
    ("F03", "Fuzz: registry", "B22", "test/fuzz/Registry.fuzz.sol",
     ["at most one accepted batch per epoch, and only with two thirds of the snapshot count and at least seven",
      "screenedThrough never falls", "token and fee balances cover pots, owed and stakes", "a stake is returned once, to its holder"]),
    ("F04", "Fuzz: distributor", "B32", "test/fuzz/Distributor.fuzz.sol",
     ["each receipt is split 40/40/20 with the remainder in the basket", "balances cover streams, owed and basket",
      "buybackImd only ever decreases through the swap callback", "a buyback step is at most half of fee rate times reserves"]),
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
    constraints in the build specification. Challenge.lean states the five capstone theorems (no value created, one
    nullifier per position and key, reward bound, determinism, no wrap-around) with `sorry` proofs. circuit/SPEC.md
    restates each theorem in plain words. No proofs in this job. """ + COMMON,
    ["`make lean-spec` (lake build of Spec.lean and Challenge.lean) succeeds with only the five expected `sorry` warnings.",
     "Every constraint 1-14 of the build specification maps to a named definition in Spec.lean, listed in a table in circuit/SPEC.md.",
     "Conservation and the reward bound are stated over the integers, not the field.",
     "No theorem in Challenge.lean has a hypothesis that is false for an honest spend; SPEC.md lists every hypothesis and why it is needed.",
     "The files' sha256 hashes are written to circuit/lean/FROZEN so later jobs can prove against an unchanged statement."],
    notes=STRUCT + " The statements are the trust anchor. R01 reviews them and the owner signs them off before any proof job starts.")

job("C01", "Circuit gadgets in clean: ranges, division, selection", "build", "single", ["scaffold-project"], ["C00"],
    ["circuit/lean/Murmuration/Gadgets/Range.lean", "circuit/lean/Murmuration/Gadgets/Division.lean",
     "circuit/lean/Murmuration/Gadgets/AssetTable.lean", "circuit/lean/Murmuration/Gadgets/Pack.lean", "circuit/lean/test/Gadgets.lean"],
    """Implement as clean circuits, reusing clean's proved bit-decomposition and comparator ports: range checks of 2,
    32, 64, 90 and 96 bits; exact division by 2^64 with a 64-bit remainder; the asset table lookup that maps an asset
    id to its constant weight and rejects unlisted ids; and the packed word TAG_NOTE*2^200 + accrued*2^104 +
    value*2^8 + asset. Constraint generation only; proofs are P01. """ + COMMON,
    ["`make lean-gadgets` builds and runs the gadget tests.",
     "Witness tests: each gadget accepts 1,000 random valid inputs and rejects boundary violations (value = 2^96, remainder = 2^64, asset id = number of assets).",
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
     "circuit/COUNTS.md", "Makefile"],
    """Compose the Spend circuit in clean from the gadgets: the fourteen constraints of the build specification, with
    the eleven public inputs in the order root, nf0, nf1, C0, C1, C2, C3, publicAmount, publicAsset, gRef, extHash.
    Export the constraint system as .r1cs and the witness generator as Circom-ABI WASM with clean's exporter, so
    that snarkjs can consume them without the Circom compiler. """ + COMMON,
    ["`make circuit` regenerates spend.r1cs and spend.wasm byte for byte from a clean checkout.",
     "snarkjs r1cs info reports 11 public inputs and a constraint count under 30,000, written to COUNTS.md.",
     "A valid witness is produced for each of the six scenarios in circuit/vectors/scenarios.json (transfer, padded transfer, fee note, claim, withdrawal, token withdrawal).",
     "For each scenario, changing any single private input makes witness generation or constraint checking fail, or changes a public output.",
     "The public input order matches IVerifier in B14 (a shared JSON file checked by both)."],
    notes=STRUCT + " clean's R1CS exporter dates from September 2026 and has no known production use; C05 exists to test it.")

job("C05", "Independent Circom implementation as a test oracle", "build", "single", ["scaffold-project"], ["C00"],
    ["circuit/circom/spend.circom", "circuit/circom/lib/", "circuit/circom/test/differential.mjs", "circuit/circom/package.json", "Makefile"],
    """Write the same Spend circuit in Circom 2 with circomlib's Poseidon, by an agent that has not seen the clean
    implementation. It is never deployed. It exists so that two independent implementations can be compared:
    differential.mjs feeds the same inputs to both witness generators and compares all eleven public outputs. """ + COMMON,
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
    ["wallet/src/keys.ts", "wallet/src/note.ts", "wallet/src/encrypt.ts", "wallet/src/address.ts", "wallet/test/vectors.test.ts",
     "wallet/vectors/xwing.json", "wallet/package.json"],
    """Implement the wallet-side primitives in TypeScript: key derivation (spk, nk, ownerPk with diversifier), note
    commitment and nullifier, the long and short address formats, HPKE base mode with the X-Wing KEM (HPKE id
    0x647A, draft-connolly-cfrg-xwing-kem-11), HKDF-SHA256 and ChaCha20-Poly1305 for output 0 (1,216 bytes), and
    the 96-byte self-encrypted change payload. Use audited libraries for X25519, ML-KEM-768 and the AEAD; write no
    primitive by hand. """ + COMMON,
    ["X-Wing passes the draft-11 test vectors in wallet/vectors/xwing.json.",
     "Commitments and nullifiers match the Lean specification on the shared scenario vectors.",
     "Encrypt then decrypt round-trips 1,000 random notes; a ciphertext is exactly 1,216 bytes and a change payload exactly 96.",
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

job("P04", "Proofs: the five capstone theorems", "proof", "single", ["scaffold-project"], ["C04", "P01", "P03"],
    ["circuit/lean/Murmuration/Proofs/Spend.lean", "circuit/lean/Murmuration/Proofs/Capstone.lean", "circuit/PROOFS.md"],
    """Prove the five theorems of Challenge.lean for the composed Spend circuit: (1) any satisfying assignment
    conserves value over the integers and every input with non-zero value or reward is a member of the tree with
    the given root, assuming Poseidon collision resistance where stated; (2) the nullifier is the specified function
    of nk, position and rho; (3) reward out is at most reward in plus the floor formula; (4) the public outputs are
    a function of the private inputs; (5) no intermediate value reaches the field modulus. circuit/PROOFS.md lists
    each theorem, its Lean name, its hypotheses and its axioms. """ + COMMON + " " + PROOF_GATE,
    ["`make lean-proofs` passes with --wfail, no `sorry`, and `lake comparator` reports the five Challenge theorems proved against the frozen statements.",
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
    notes=STRUCT + " These tools find bugs. They do not establish the capstone properties, which is what P04 is for.")

# ------------------------------------------------------------------ reviews
job("R01", "Review: are the frozen statements the right ones", "review", "research", ["research-report"], ["C00"],
    ["docs/reviews/R01-statements.md"],
    """Panel review, five reviewers, quorum four. Read circuit/lean/Murmuration/Spec.lean, Challenge.lean and
    circuit/SPEC.md at the pinned commit and the build specification. Answer for each of the five theorems: does the
    Lean statement say what the plain-words statement says; is any hypothesis stronger than an honest prover
    satisfies; could the statement be true of a circuit that lets value be created; is anything quantified over the
    wrong set (field versus integers, any root versus a known root). Propose a concrete counter-model for each
    weakness found. """,
    ["Each theorem gets a verdict: faithful, too weak (with a counter-model), or too strong (with an honest spend that violates a hypothesis).",
     "Each constraint 1-14 of the build specification is matched to a definition or reported missing.",
     "The report names every place where Spec.lean differs from the build specification, however small.",
     "Minimum of 3 citations to file and line per theorem."],
    notes="IMD's research template takes panelSize, panelQuorum, minCitations and a rubric. The owner reads this report and signs the statements off before P01 starts.")

job("R02", "Review: circuit and contract interface", "review", "single", ["adversarial-review"], ["B14", "C04"],
    ["docs/reviews/R02-interface.md"],
    """Adversarial review, read-only, of the boundary between the Spend circuit and the Pool: the order and encoding
    of the eleven public inputs; reduction of extHash and of every input modulo p on both sides; that the tree, the
    bundle leaf and the commitment computed in Solidity equal the circuit's for the same note; that the checkpoint
    the Pool accepts is the one the circuit used; that the standard-size check and the per-asset limit use the same
    asset id as the proof. Try to construct a call that the Pool accepts with a meaning the circuit did not prove. """,
    ["Each of the eleven public inputs has a row: produced where, checked where, encoding, and whether a mismatch is possible.",
     "Every finding has a severity, file and line, and a reproduction as a Foundry test or a witness.",
     "The review states explicitly whether a proof for one deployment can be accepted by another.",
     "No high or critical finding remains open at sign-off."],
    notes="IMD's adversarial review goes to a different agent on a different seat, with no write access.")

job("R03", "Review: zero-knowledge circuit checklist", "review", "research", ["research-report"], ["C04", "C05"],
    ["docs/reviews/R03-circuit.md"],
    """Panel review, five reviewers, quorum four, of the clean circuit and the Circom oracle against a checklist that
    IMD's audit template does not contain, because that template is written for Solidity. Checklist: signals assigned
    but not constrained; missing range checks before additions and comparisons; bit decompositions that allow an
    alias above the modulus; equality checks done on hints; selectors not forced to be boolean; public inputs unused
    in any constraint; nullifier not bound to the note it spends; padding inputs able to carry value or reward;
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
     "check_vk.py passes: gamma and delta distinct, all points valid, 12 IC points.",
     "A table shows the hash of spend.r1cs in three places: the P04 build, the ceremony and the fixtures; all equal.",
     "The verifier contract's constants match the key (script output included)."])

job("R05", "Review: launch, auction and buyback on a fork", "review", "single", ["adversarial-review"], ["B32", "B41"],
    ["docs/reviews/R05-market.md", "test/review/Market.t.sol"],
    """Adversarial review of the token's market mechanics on a mainnet fork with the real IMD token and Uniswap v3:
    try to make launch revert or place the position at a wrong price by acting first; try to take value from a
    buyback step by any sequence of swaps and liquidity changes in the same block; try to buy the basket below its
    value by manipulating the auction's state; try to strand an asset in the basket. Report what a third party can
    gain and at what cost. This step may write only the review test file. """,
    ["Each attack attempted is a Foundry test in test/review/Market.t.sol with the attacker's profit asserted.",
     "No attack shows a profit above gas cost, or the finding is filed as high.",
     "The report quantifies the cost to delay launch by pre-creating the pool with real liquidity.",
     "The report lists the IMD token's owner powers that affect this market, including bridge-side minting."],
    notes="IMD's review skills are read-only by default; this brief needs a variant that may add one test file, or a build job that writes the tests followed by a read-only review.")

# ------------------------------------------------------------------ audits
for aid, title, dep, contracts, worry in [
    ("A01", "Audit: Token, Distribution, Deployer", ["B41", "B50"], ["src/Token.sol", "src/Distribution.sol", "src/Deployer.sol"],
     "any path that creates supply, reduces the locked position, pays the founder or a swarm entry early or twice, or lets a third party block or misprice launch"),
    ("A02", "Audit: Pool", ["B15"], ["src/Pool.sol", "src/lib/RewardIndex.sol", "src/lib/NoteTree.sol", "src/lib/Hash.sol"],
     "any path that moves a deposit to anyone but its depositor, lets a spend take more than was activated, pays more reward than released, bypasses the cap or the minimum age, or leaves funds unable to move"),
    ("A03", "Audit: ScreenerRegistry", ["B22"], ["src/ScreenerRegistry.sol"],
     "acceptance of a batch with fewer than two thirds, a way to stop batches for ever, loss or theft of stakes or pay, and any way for the registry to affect funds in the Pool"),
    ("A04", "Audit: FeeDistributor", ["B32"], ["src/FeeDistributor.sol"],
     "staking reward sniping, a blocked or underpriced basket sale, IMD leaving except through the pool swap, and extraction around a buyback step"),
    ("A05", "Audit: Verifier", ["B51"], ["src/Verifier.sol"],
     "acceptance of an invalid proof, malleable or out-of-range public inputs, and precompile call handling"),
]:
    job(aid, title, "audit", "audit", ["audit (four specialists and a judge, added by IMD)"], dep, ["(read-only; report at /jobs/:id/report.md)"],
        f"""Audit the named contracts at the pinned commit against the build specification. They are immutable once
        deployed: there is no owner, pause or upgrade, so every finding that would normally be fixed by an admin is a
        permanent loss. What worries us most: {worry}. Check every invariant listed for these contracts in the build
        specification and say for each whether it holds, with the test or trace that shows it. Token behaviours to
        assume: USDC can blocklist any address including these contracts; DAI is plain; IMD is a plain bridged token with no fee, pause or blocklist; the project token is plain. """,
        ["The judge's coverage record has one row per external function: holds, finding, or unreached.",
         "Each invariant of the build specification for these contracts has a verdict and evidence.",
         "Every finding has a severity, file and line, a reproduction, and where possible a Foundry proof.",
         "No high or critical finding is open at sign-off; each fix goes through fix-findings and a second audit of the changed contract."],
        contracts=contracts,
        notes="IMD's audit template covers Solidity only: four specialists (math, permissions, economics, control flow) and a judge. It names at most four contracts per request.")

# ------------------------------------------------------------------ node and wallet
job("S01", "Deterministic screening program", "build", "single", ["scaffold-project"], ["B21"],
    ["node/src/screen/criteria.ts", "node/src/screen/batch.ts", "node/src/screen/data.ts", "node/test/determinism.test.ts",
     "node/criteria/sanctions-flags-and-hops.v2.json", "node/package.json"],
    """Implement the screening program: parse a criteria file, read deposits, Flag events and list data at the
    epoch's first block from an RPC endpoint, evaluate the rules, and output the Batch (upTo, the refusal bitmap
    words that differ from on-chain state, dataCid of the explanation file) and its hash. Same inputs must give the
    same bytes on any machine: canonical ordering, fixed number formats, no wall-clock time, no floating point. """ + COMMON,
    ["Two runs on different machines from the same recorded RPC responses produce byte-identical batch and explanation files (fixture replay test).",
     "Each rule in the reference criteria file has a test with a deposit it refuses and one it allows.",
     "The explanation file names, for every refused deposit, the rule and the evidence.",
     "A reorg of the epoch's first block before finality changes nothing because only finalized data is read (test with a recorded reorg).",
     "The batch hash equals the Solidity hash used by ScreenerRegistry.apply (shared vector)."],
    notes=STRUCT)

job("S02", "Node duty: commit, reveal, apply", "build", "single", ["scaffold-project"], ["S01"],
    ["node/src/duty/screener.ts", "node/src/duty/schedule.ts", "node/test/duty.test.ts", "node/README.md"],
    """Implement the screener duty for the node: each epoch run S01, commit in the commit window with a fresh salt
    kept on disk, reveal in the reveal window, call apply when a batch is accepted and not yet applied, and withdraw
    pay on request. The duty runs under its own Unix user with its own operator key and never reads IMD's worker
    files. It makes no call to api.imd.fun. """ + COMMON,
    ["Against a local chain with the contracts from B22, ten simulated nodes reach acceptance in every epoch of a 20-epoch test.",
     "A node restarted between commit and reveal still reveals the committed batch (salt persisted).",
     "A node whose RPC returns different data from the others reveals a different hash and the test shows it is not paid.",
     "No outbound request goes to any host other than the configured RPC and IPFS endpoints (network mock)."],
    notes=STRUCT)

job("S03", "Wallet flows for the pool", "build", "single", ["scaffold-project"], ["C06", "C07"],
    ["wallet/src/pool/deposit.ts", "wallet/src/pool/spend.ts", "wallet/src/pool/plan.ts", "wallet/src/pool/scan.ts", "wallet/test/pool.test.ts"],
    """Implement the wallet module for the pool: deposit with a fresh ownerCommit, activate and refund; note
    discovery by trial decryption of Spent events from snapshot files; building a spend (input selection, padding,
    relay fee note, optional reward claim) and proving it with prove.mjs; and plan.ts, which splits an amount into
    standard sizes, defaults deposits to standard sizes grossed up for the entry fee, and warns before several exits
    go to one address. """ + COMMON,
    ["The end-to-end scenario of B60 is driven entirely through this module against a local chain.",
     "plan.ts splits every multiple of 0.005 ETH below 1,000 ETH into at most 16 standard sizes and never leaves a remainder of 0.005 ETH or more.",
     "A wallet restored from its seed alone recovers every note and its accrued reward from chain data.",
     "A spend built against the previous checkpoint is rebuilt automatically when it would be stale.",
     "The module warns when a planned set of exits to one address sums to within 1% of a single deposit by the same wallet."],
    notes=STRUCT)

# ------------------------------------------------------------------ launch
job("L01", "Canary script and record", "build", "single", ["scaffold-project"], ["B60", "S02", "S03"],
    ["canary/script.md", "canary/run.ts", "canary/record.json", "canary/README.md"],
    """Write the canary's published script as a machine-readable list of steps covering every item in the build
    specification's canary checklist, and run.ts, which executes a step through the wallet and node modules and
    appends the transaction hash to record.json. The script must reach every external function of the six
    contracts and each of the six circuit scenarios, on the canary parameter file. """ + COMMON,
    ["Run against a local fork with canary parameters, every step completes and record.json has a transaction hash for each.",
     "A coverage check lists every external function selector of the six contracts and the step that calls it; none is missing.",
     "The script includes the third-party pre-created pool case, a full-cap activation failure, an epoch with no accepted batch, and spends after deposits close.",
     "canary/README.md states what a completed canary shows and what it does not."],
    notes=STRUCT + " Running the canary on mainnet is not part of this job and needs the lawyer's review first.")

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
