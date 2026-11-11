# Status re-check of five provisional facts (v4) — 11 November 2026

Read-only re-check against primary sources. Every claim carries its source URL, the date read
(all reads on 11 November 2026 unless stated) and an exact quote or value. Each section separates
**Verified** from **Not verified**. Sections are filled in as they are finished; a section that
still says "(pending)" has not been done yet.

## 1. EIP-8037, EIP-8038 and EIP-7976 (Glamsterdam state and calldata pricing)

Read 11 November 2026, 15:55 to 16:05 UTC. "curl" means I downloaded the file and the quote is verbatim.
"git" means a clone or `ls-remote` of the repository. "WebFetch" means a summarising fetch tool, which is
weaker. `github.com` web pages and `api.github.com` are blocked by this session's network policy (HTTP 403);
`git clone`, `raw.githubusercontent.com` and `eips.ethereum.org` work.

### 1.1 Result

- **Nothing in the three EIPs has changed.** All three are still `Last Call` with the deadline of 1 November
  2026 already past, and every constant the specification uses is the constant in the text today.
- **No file commit since 1 November.** The last commits are 6 October (EIP-8037, EIP-7976) and 22 October
  (EIP-8038, a title-only change).
- **No open pull request changes a constant.** Two open pull requests would change how state gas is paid
  inside a transaction (#12581, #12582). Neither changes the price per byte, and neither has moved since
  25 October.
- **The 13 November and 19 November dates stand as described.** The Ethereum Foundation post is unchanged
  since 9 November. No audit report is published yet.
- **`launch` recomputed: about 5.8M gas today and about 41.7M under the Last Call text**, of which 41.2M is
  state gas. The specification's "about 6M" is confirmed. Its "about 45M" is about 3M too high for the call
  as described; it is safe as an upper bound. The call fits a 60M block. It stops fitting if the price per
  state byte rises above about 2,190 (it is 1,530), or if the block gas limit falls below about 42.1M.

### 1.2 Status and constants (verified)

Repository state: `git ls-remote https://github.com/ethereum/EIPs.git refs/heads/master` =
`bd93d240b72702450920eeeadc2ce593626bfd8a` (15:55 UTC), the commit "CI: Pin Jekyll build runner to
ubuntu-24.04 (#12640)" of 2026-11-10T11:25:20-05:00. This is the same head as the second pass in
`status_changes_v3.md`.

| EIP | Status today | Blob hash of the file | Source |
|---|---|---|---|
| 8037 | "status: Last Call", "last-call-deadline: 2026-11-01" | `c8bc85b0bf866089f84d0745769fd848733c2958` | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8037.md (curl) |
| 8038 | "status: Last Call", "last-call-deadline: 2026-11-01" | `a1c73c4f5bffc6b4ed69556c497fec6c3d24e287` | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8038.md (curl) |
| 7976 | "status: Last Call", "last-call-deadline: 2026-11-01" | `15abf8001a4296864141700add3bf66c9f1b8721` | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-7976.md (curl) |

The three blob hashes equal those recorded on 10 November, so the files are byte-identical. The rendered
pages https://eips.ethereum.org/EIPS/eip-8037, `/eip-8038` and `/eip-7976` (curl) each show "Last Call
Deadline 2026-11-01".

Constants in the text today, each quoted from the raw file:

| Constant the specification uses | Value in the EIP today | Exact text |
|---|---|---|
| State gas per byte of deployed code | 1,530 | EIP-8037: "`CPSB` \| 1530" and "`GAS_CODE_DEPOSIT` \| 200/byte \| `CPSB` per byte \| `6 × ceil(len/32)` (hash cost)" |
| State gas for a new storage slot | 64 × 1,530 = 97,920 | EIP-8037: "`STATE_BYTES_PER_STORAGE_SET` \| 64"; impact table "New slot \| 20,000 \| 97,920 \| ~5×" |
| New slot, cold, total | 22,100 today; 2,100 + 10,000 + 97,920 = 110,020 after | EIP-8038: "`COLD_STORAGE_ACCESS` ... 2,100 \| 2,100", "`STORAGE_WRITE` ... 2,800 (2) \| 10,000"; row "0 \| 0 \| x \| Cold \| New slot \| `COLD_STORAGE_ACCESS` + `STORAGE_WRITE` charged \| `GAS_STORAGE_SET` charged" |
| Cold-slot overwrite | 5,000 today; 2,100 + 10,000 = 12,100 after | EIP-8038 row "x \| x \| y \| Cold \| Existing slot, first change \| `COLD_STORAGE_ACCESS` + `STORAGE_WRITE` charged \| no state-gas adjustments" |
| New account | 120 × 1,530 = 183,600 | EIP-8037: "`STATE_BYTES_PER_NEW_ACCOUNT` \| 120"; "New account \| 25,000 \| 183,600" |
| Per-transaction execution cap | 16,777,216 | EIP-8037: "the transaction gas limit set in EIP-7825 only applies to execution-gas, while state-gas is capped by `tx.gas`". EIP-7825 (status Final): "maximum of **16,777,216 gas (2^24)**" |
| Reservoir | as described | EIP-8037: "`gas_left = min(execution_gas_budget, evm_gas)`", "`state_gas_reservoir = evm_gas - gas_left`"; "State-gas charges deduct from `state_gas_reservoir` first. When the reservoir is exhausted, the remainder deducts from `gas_left`" |
| Cap on `tx.gas` as a whole | 4,294,967,295 | EIP-8037: "`TX_MAX_TOTAL_GAS_LIMIT` \| 4,294,967,295 (2^32 - 1)" |
| Other EIP-8038 values | cold account 3,000; account write 9,000; create access 12,000; clearing refund 11,616 | "`COLD_ACCOUNT_ACCESS` ... 2,600 \| 3,000", "`ACCOUNT_WRITE` ... 9,000", "`CREATE_ACCESS` ... 12,000", "`STORAGE_CLEAR_REFUND` ... 4,800 \| 11,616" |
| Calldata floor (EIP-7976) | 64 gas per byte | "`TOTAL_COST_FLOOR_PER_TOKEN` \| `16`"; "the floor cost is `64` gas per calldata byte (both zero and non-zero)" |

Second primary source for the constants: the reference implementation, branch `forks/amsterdam` of
https://github.com/ethereum/execution-specs (git fetch; head `1689800`, 2026-10-06), file
`src/ethereum/forks/amsterdam/vm/gas.py`: "COST_PER_STATE_BYTE ... Uint(1530)",
"STATE_BYTES_PER_STORAGE_SET ... Uint(64)", "STORAGE_WRITE ... Uint(10000)", "COLD_ACCOUNT_ACCESS ...
Uint(3000)", "TX_MAX_GAS_LIMIT: Final[Uint] = Uint(16_777_216)", "TX_BASE ... Uint(12000)".

Block gas limit on mainnet today (RPC `eth_getBlockByNumber`, https://ethereum-rpc.publicnode.com and
https://eth.drpc.org, 15:58 to 16:03 UTC): block 26,392,730 `gasLimit` 59,941,408; of ten blocks sampled
between 26,390,953 and 26,392,753, eight read 60,000,000, one 59,999,943 and one 59,941,408. So "60M" is
right to within 0.1%, and the true limit is sometimes 58,592 gas lower.

One caveat inside the EIP text itself: EIP-8037 still says of the EIP-8038 values it uses "The values are not
yet final." (An open pull request, #12624, would delete that sentence.)

### 1.3 Commit history of each file (verified, git)

`git log origin/master --since=2026-10-01 -- EIPS/eip-N.md` on a clone taken at 15:55 UTC:

| File | Commits since 1 November | Last three commits |
|---|---|---|
| `EIPS/eip-8037.md` | none | `5ef38012` 2026-10-06 "Update EIP-2780: Move to Last Call (#12442)"; `5d012887` 2026-10-02 "add Gary Rong as co-author"; `eb9f828d` 2026-10-02 "add Spencer Taylor-Brown as co-author" |
| `EIPS/eip-8038.md` | none | `f1ade090` 2026-10-22 "Align titles and descriptions of Glamsterdam EIPs (#12561)"; `8b1cae50` 2026-10-15 "Expand gas estimation methodology and add supporting reports"; `5ef38012` 2026-10-06 |
| `EIPS/eip-7976.md` | none | `5ef38012` 2026-10-06; `c998ef94` 2026-07-08 "Move to Review"; `15e4f96c` 2026-04-15 "clarify token abstraction" |

The whole repository has six commits since 1 November; none touches these files (newest: `bd93d240`,
10 November, build configuration; `542e62eb`, 7 November, EIP-8355 test vectors).

### 1.4 Open pull requests and proposals that would change the constants

Method: `git ls-remote origin 'refs/pull/*'` (15:55 UTC), then a fetch of the head of every pull request
numbered 12560 or higher and of every older one that still has a merge ref (355 heads), then
`git diff --name-only` against master. Open or closed state comes from a WebFetch of the pull-request search
page (https://github.com/ethereum/EIPs/pulls?q=is%3Apr+is%3Aopen+8037+OR+8038+OR+7976, read 16:04 UTC),
which listed all of the following as open.

| PR | Head commit and date | What it changes | Changes a constant? |
|---|---|---|---|
| #12581 | `2ba9176f`, 2026-10-25 (18 commits) | EIP-8037 and EIP-2780: refills go to the reservoir; adds a "legacy share" of each state charge that is paid from `gas_left`. Adds "`PRE_FORK_GAS_STORAGE_SET` \| 20,000", "`PRE_FORK_GAS_NEW_ACCOUNT` \| 25,000", "`PRE_FORK_GAS_CREATE` \| 32,000" | No price change. Changes which pool pays |
| #12582 | `19d788c8`, 2026-10-25 (33 commits) | The above plus a "state-gas allowance of call frames": a called contract can take from the reservoir at most `child_gas * CPSB // LEGACY_GAS_PER_STATE_BYTE`, with "`LEGACY_GAS_PER_STATE_BYTE` \| 200" | No price change. Limits the reservoir per call |
| #12573 | `b3b26e84`, 2026-10-23 | EIP-8037 documentation: "Spent gas can return before transaction settlement" | No |
| #12624 | `a912bb29`, 2026-10-26 | EIP-8037 wording; removes "The values are not yet final." | No |
| #12612 | `a1055678`, 2026-11-02 | EIP-8038: maps the EIP-7928 table to the new constant names | No |
| #12626 | `cd3d77f8`, 2026-10-26 | EIP-8038 wording | No |
| #12639 | `51b53200`, 2026-11-09 | EIP-7976: renames parameters to "`TOKENS_PER_BYTE` \| `4`", "`STANDARD_COST_PER_TOKEN` \| `4`", "`FLOOR_COST_PER_TOKEN` \| `16`" | No. Still 64 gas per byte |
| #12638 | `92f337b0`, 2026-11-10 (was `17034f5` on 10 Nov) | New draft, `EIPS/eip-8488.md`, "Versioned Opcodes for Gas Repricing": old contracts keep the old schedule, new contracts use new opcodes | Not a change to these EIPs; an outside alternative with no fork target |

- Pull requests opened since the last note (#12647 to #12652): one revert of test vectors and five dependency
  bumps. None touches an EIP in this section.
- Effect of #12582 on `launch`, if it merged (my reading of the pull-request text, not tested): none. The
  top-level frame has no ceiling ("The top-level frame has no ceiling"), and the factory call is forwarded
  about 16M gas, which grants an allowance of about 7.65 × 16M = 122M against the 34M the pool's code needs.
- Forum: the EIP-8037 thread https://ethereum-magicians.org/t/25694.json (curl) has `last_posted_at`
  2026-11-03T01:51:02Z, 49 posts; EIP-8038 thread 2026-10-06; EIP-7976 thread 2026-08-26. A forum search for
  "8037" after 1 November returned no posts. The only new related topic is
  https://ethereum-magicians.org/t/30332.json, "EIP-8488: Versioned Opcodes for Gas Repricing", created
  2026-11-10, three posts, the last at 21:20 UTC on 10 November.
- Reference implementation: the two exploratory branches of ethereum/execution-specs still end on 3 November
  (`eips/amsterdam/eip-8037-clear-refill-capped`, `f2fd222`, "repay eip-8037 slot-clear state gas through the
  capped refund counter"; `...-clear-refill-counter`, `75af2f4`, "defer the slot-clear state gas refill until
  the transaction settles"). Both concern refills, not prices.
- Ethereum Foundation: "Work is already underway to prototype and review several possible revisions" (post
  quoted in 1.5). No revision is published as a pull request beyond those above.

### 1.5 The 13 November reports and the 19 November call (verified, still as described)

- https://blog.ethereum.org/en/2026/11/06/glamsterdam-8037-8038 (curl, 15:57 UTC). Response header
  `x-nextjs-date: Mon, 09 Nov 2026 21:20:01 GMT`; the feed's `lastBuildDate` is still "Mon, 09 Nov 2026
  21:18:41 GMT" and the newest item is still this post. The timeline reads, verbatim: "12.Nov ACDC
  Consensus-layer agenda; 8037/8038 not on the agenda", "13.Nov Engagements end Dedaub and ChainSecurity
  reports delivered and published", "16.Nov ACDT Dedaub, ChainSecurity and EF present findings. Open Q&A; app
  developers encouraged to join", "19.Nov ACDE Discussion of findings and possible next steps. No decision is
  pre-committed".
- Call schedule, https://github.com/ethereum/pm (git clone, head `61345cfc`, 2026-11-11T15:04:38Z),
  `.github/ACDbot/meeting_topic_mapping.json`: "All Core Devs - Consensus (ACDC) #191, November 12, 2026"
  `2026-11-12T14:00:00Z`; "All Core Devs - Testing (ACDT) #103, November 16, 2026" `2026-11-16T14:00:00Z`;
  "All Core Devs - Execution (ACDE) #249, November 19, 2026" `2026-11-19T14:00:00Z`.
- Agenda of the 19 November call: https://ethereum-magicians.org/t/30071.json (curl), first post last edited
  2026-11-04: "Agenda Glamsterdam Hegotá Misc". The GitHub issue (https://github.com/ethereum/pm/issues/2285,
  WebFetch) is open with the same three headings and no comment proposing an item on repricing.
- Agenda of the 16 November testing call: https://ethereum-magicians.org/t/30326.json (curl), first post
  edited 2026-11-11T00:36Z: "Glamsterdam EIP-8037/Gas Repricing Status of Ongoing Audits (completion expected
  16th-19th Nov). App Team contract findings. Open Q&A on audit findings".
- The two sources still disagree on when the audits end: 13 November (Foundation post) against "16th-19th
  Nov" (testing-call agenda). Unchanged from the last note.
- No report is published: https://www.chainsecurity.com/blog (curl, 16:03 UTC) has its newest post dated
  2026-10-21 and its only Glamsterdam post dated 2026-10-13; https://dedaub.com/blog/ (curl) has its newest
  post dated "30 September 2026" and no mention of Glamsterdam.
- No fork date: pm `glamsterdam-mainnet-plan.md` still reads "Hoodi | TBD" and "mainnet | TBD";
  https://forkcast.org/api/upgrades.json (curl, `generatedAt` 2026-11-11T06:19:54Z) has
  `"activationDateLabel": "TBD"`; consensus-specs `configs/mainnet.yaml` has "GLOAS_FORK_EPOCH:
  18446744073709551615" and "GAS_LIMIT_SCHEDULE: []".

### 1.6 Gas of `launch`, recomputed

What the call does (from `reports/build_plan/B40-distribution-launch-and-the-locked-position.md`): one
CREATE2 of the token, two token transfers, `UniswapV3Factory.createPool`, `pool.initialize`, one direct
`pool.mint` with a callback that transfers tokens to the pool, and four recorded values.

Measured on mainnet today, to anchor the model (RPC, 16:01 UTC; state changes from `trace_replayTransaction`
with `stateDiff` on https://eth.drpc.org):

| Transaction | What it does | `gasUsed` | New accounts and slots |
|---|---|---|---|
| `0xb00bc7230598deeba3e724bfbc8286bbac9365815947c8baf5beb4f274d63a70` (block 26,384,523) | creates and initializes a 1% pool through the position manager | 4,613,669 | 1 account with 22,142 bytes of code; 2 new slots in the factory, 2 in the pool |
| `0x86f2ad80d10cf8faf161d70b2ada8120eee9e4ce273e7d6ef9c2dd2e506f165f` (block 26,384,920) | creates, initializes and mints through the position manager | 5,119,708 | the same account; 2 factory slots, 9 pool slots, 10 position-manager slots, 1 token slot |

`eth_getCode` on six 1% pools created in the last 10,000 blocks returned 22,142 bytes each, so the
specification's pool size is confirmed. The first transaction reconciles with the cost model below to within
35,469 gas: 4,613,669 − 21,000 (base) − about 1,500 (calldata) − 4,460,400 (pool creation) − 88,400 (4 slots)
− 6,900 (the factory's temporary slots).

Assumptions, each chosen as an upper bound:
- Token code 3,071 bytes ("under 3 KiB").
- 23 new storage slots: factory 2; pool 10 (slot0 and the first observation at `initialize`; two slots for each
  of the two ticks, two bitmap words, one position slot and the liquidity slot at `mint`); token 7 (name,
  symbol, total supply and the creator's balance in the constructor, then the balances of the privacy pool,
  the registry and the Uniswap pool); the launch contract 4 (token, pool, liquidity, launch time). The task
  statement's "a few new storage slots" understates this; the count matters little (see the totals).
- The factory writes three temporary slots and clears them in the same call. Today that nets 6,900 gas. Under
  EIP-8037 their state gas (3 × 97,920 = 293,760) is charged and then refilled, so it is not paid but must be
  covered by `tx.gas`.
- "Other execution" (calls, cold reads, hashing, events, the initcode, Uniswap's arithmetic, the candidate
  loop): 150,000 to 250,000 gas. This is an estimate; it is the only estimated line.

Today:

| Line | Arithmetic | Gas |
|---|---|---|
| Base and calldata | 21,000 + 4 × 16 | 21,064 |
| Token creation and code | 32,000 + 200 × 3,071 | 646,200 |
| Pool creation and code | 32,000 + 200 × 22,142 | 4,460,400 |
| 23 new slots | 23 × 22,100 | 508,300 |
| Factory's temporary slots | 3 × 22,200 − 3 × 19,900 | 6,900 |
| Other execution | estimate | 150,000 to 250,000 |
| **Total today** | | **5.79M to 5.89M** |

Under the Last Call text (EIP-8037, EIP-8038, EIP-2780):

| Line | Execution gas | State gas |
|---|---|---|
| Base and calldata: 12,000 + 3,000 + 64 | 15,064 | 0 |
| Token: 12,000 + 6 × 96 execution; (120 + 3,071) × 1,530 state | 12,576 | 4,882,230 |
| Pool: 12,000 + 6 × 692 execution; (120 + 22,142) × 1,530 state | 16,152 | 34,060,860 |
| 23 new slots: 23 × 12,100 execution; 23 × 97,920 state | 278,300 | 2,252,160 |
| Factory's temporary slots: 3 × 12,200 − 3 × 10,000 | 6,600 | 0 net (293,760 charged, then refilled) |
| Other execution (estimate) | 150,000 to 250,000 | 0 |
| **Total** | **0.48M to 0.58M** | **41,195,250** |

- **Gas used: 41.67M to 41.77M.** State gas is 98.7% of it; the pool's code and account are 81.6%, the token
  11.7%.
- **`tx.gas` needed: at least about 42.1M** (gas used plus the 293,760 that is charged and refilled).
- Check of the state total: (22,262 + 3,191 + 23 × 64) bytes = 26,925 bytes; 26,925 × 1,530 = 41,195,250.
- With a 1,752-byte token (the size of the launch token read in `imd_launch_factory_v3.md`) and 19 slots the
  state gas is 25,350 × 1,530 = 38,785,500 and the total about 39.3M.
- Against the specification: "about 6M today" holds (5.8M to 5.9M). "About 45M under Glamsterdam" is 3.2M to
  3.3M above this recomputation. "Nearly all of it the state charge for the pool's code" holds for the state
  charge as a whole (98.7%); the pool alone is 82%.

Does it fit a 60M block? Yes, with conditions set by the EIP's inclusion rule, "`min(TX_MAX_GAS_LIMIT,
tx.gas) <= execution_gas_available` and `tx.gas <= state_gas_available`":
- Execution gas (0.5M to 0.6M) is far below the 16,777,216 cap. The cap is not the constraint.
- The whole `tx.gas`, about 42.1M, must fit in the state gas the block has left. In a 60,000,000 block the
  transactions placed before it may have used at most about 17.9M of state gas (17.8M at a limit of
  59,941,408). The rule tests `tx.gas`, not gas used, so a generous gas limit narrows this further: a `tx.gas`
  of 50M needs a block with at most 10M of state gas used before it.
- How the 42.1M is paid, with `tx.gas` = 42,100,000: `gas_left` = 16,777,216 − 15,064 = 16,762,152 and the
  reservoir = 42,100,000 − 16,777,216 = 25,322,784. The reservoir is drawn first: 5,947,110 before the pool's
  code is stored, leaving 19,375,674. The pool's code costs 22,142 × 1,530 = 33,877,260, so 14,501,586 of it
  comes out of the create frame's own `gas_left`. That frame receives at most about 16.1M (16.76M less what
  was spent, times 63/64 twice). The margin is about 1.6M. The call must therefore reach the factory with
  nearly all of its execution gas unspent, and must not be wrapped in a call that forwards a fixed, smaller
  amount of gas. A larger `tx.gas` widens this margin and narrows the block condition above.

What would break it (arithmetic: state bytes at the peak are 26,925 + 3 × 64 = 27,117; execution taken as
0.6M):
- **Price per state byte.** `tx.gas` ≈ 27,117 × CPSB + 0.6M must not exceed the block gas limit. At 60M the
  ceiling is (60,000,000 − 600,000) / 27,117 = **2,190 gas per byte**, 43% above today's 1,530, and only in a
  block with no other state creation before it. At 59,941,408 it is 2,188.
- **Block gas limit.** At 1,530 per byte the limit must be at least 27,117 × 1,530 + 0.6M = **42.09M**.
- **The reservoir.** If a revision applied the 16,777,216 cap to state gas as well, the call would fail at any
  price above (16,777,216 − 600,000) / 27,117 = 596 gas per byte. Today's 1,530 is 2.6 times that. The
  design depends on state gas being metered outside the per-transaction cap.
- Direction of travel: the EIP derives 1,530 for a reference limit of 150M ("Reference block gas limit:
  `150M` gas units") and says "`CPSB` can be re-derived in a subsequent EIP". Sepolia's Glamsterdam
  configuration schedules a 200M limit (https://raw.githubusercontent.com/eth-clients/sepolia/main/metadata/config.yaml,
  curl: "GAS_LIMIT_SCHEDULE: - EPOCH: 353024 GAS_LIMIT: 200000000"); mainnet's schedule is empty. A higher
  limit at the same price makes `launch` easier; at 150M the ceiling is 5,509 per byte.

### 1.7 Not verified

- What the 13 November reports will say and what the 16 and 19 November calls will decide. None has happened.
  This section goes stale at 14:00 UTC on 12, 16 and 19 November and whenever the reports appear.
- Open or closed state of pull requests rests on one WebFetch of a search page; heads and diffs are from git.
- Pull requests below #12560 that have a merge conflict (no merge ref) were not scanned (498 heads from
  #11900 up). An old conflicting pull request that changes a constant could have been missed.
- Whether the revisions the Foundation says are being prototyped exist anywhere other than pull requests
  #12581 and #12582 and the two execution-specs branches.
- The `launch` figures are a model, not an execution. The contract does not exist yet. The slot counts for
  the pool are from Uniswap's behaviour on chain (9 new pool slots in a real create-initialize-mint); the
  token's and launch contract's slot counts and the "other execution" line are assumptions.
- That EIP-7825's cap is enforced on mainnet today was not tested on chain; the EIP's status is Final.
- The effect of pull request #12582 on `launch` is my reading of its text.

## 2. The `clean` framework's Poseidon proofs

Read 11 November 2026, 19:41 to 19:46 UTC. "git" means `git fetch` and `git ls-remote` on
https://github.com/Verified-zkEVM/clean.git (including `refs/pull/*`). `github.com` pages and
`api.github.com` return HTTP 403 to curl here, so pull-request state, titles and review comments come from
WebFetch (the summarising tool) and are marked as such. Nothing was built: no Lean toolchain is installed in
this container.

### 2.1 Result

- **Not merged.** The branch `poseidon-n-arity` is still 3 commits ahead of `main` and is not an ancestor of
  it. `main` has not moved since 9 November.
- **The branch has not moved since 2 November** (commit `df7a54ca`). It is pull request #465, which is open,
  has one review comment from the maintainer ("close to mergeable from my side", 21 September) and no
  approval. It no longer merges cleanly: `main` changed `Clean/Circomlib/Poseidon.lean` after the branch's
  last commit.
- **`main` has Poseidon (not Poseidon2) over BN254 with circomlib's constants, proved at width 2 only**
  (one input). Widths 3, 4 and 5 exist on `main` as specifications with test vectors, without circuits or
  proofs. This is the same state as in `circuit_proof_tooling_v3.md`.
- **The R1CS exporter on `main` is byte-identical to the version merged on 16 September 2026.** It has no
  theorem relating the exported constraints to the framework's semantics. A pull request that adds that
  theorem (#473) has been open and untouched since 28 September.
- **For the design:** the proof plan's fallback applies. Either build on the unmerged, now-conflicting
  branch or redo widths 3 to 5. One further point not in the earlier note: the exporter writes one R1CS row
  per linear constraint, so a Poseidon exported from this framework has about twice the rows of circomlib's
  optimised circuit (2.4).

### 2.2 The branch and its pull request

Verified (git, 19:41 UTC):

| Fact | Value |
|---|---|
| `refs/heads/main` | `a985c76c845e1d69ab320831d535072fcadb7c76`, 2026-11-09T16:23:04+01:00, "Merge pull request #511 from Verified-zkEVM/completeness-exists" |
| `refs/heads/poseidon-n-arity` | `df7a54ca3e512a7a003e1384b9c2063b585365f0`, 2026-11-02T11:25:03+01:00, author Martin Ochoa, "Addressed comment on removing compatibiliy wrapper and using generic interface" |
| Earlier commits on the branch | `7fd1f72e` 2026-09-21 "Generate Poseidon constants during Lean elaboration"; `318f90cf` 2026-09-17 "Generalize verified Poseidon circuit to arities 1 through 16" |
| Is the branch an ancestor of `main`? | No (`git merge-base --is-ancestor` fails) |
| Ahead and behind | 3 commits ahead of `main`, 488 behind. Fork point `fba2a29f`, 2026-09-16, "Merge pull request #415 from VanshSahay/wasm-ir-compiler-clean" |
| Pull request | `refs/pull/465/head` = `df7a54ca`, the branch head |
| GitHub's test merge | `refs/pull/465/merge` = `11f6b84f`, made 2026-11-02T11:25:15+01:00 against `main` at `ce2eee63` (29 October). It has not been refreshed since |
| Merge against today's `main` | `git merge-tree --write-tree origin/main origin/poseidon-n-arity`: "CONFLICT (content): Merge conflict in Clean/Circomlib/Poseidon.lean". Against `ce2eee63` the same command merges cleanly |
| Why it conflicts | Two commits on `main` touched that file after `ce2eee63`: `9852171d` (2 November, "Bump Lean and Mathlib to v4.34.1") and `e3c9da78` (3 November, "Merge origin/main into confluent-vector-eval") |
| Lean version | Branch `lean-toolchain`: "leanprover/lean4:v4.33.1". `main`: "leanprover/lean4:v4.35.0" |
| Size of the change | 17 files, 2,517 insertions, 2,217 deletions against the fork point |

From WebFetch of https://github.com/Verified-zkEVM/clean/pull/465 (between 19:41 and 19:46 UTC):
- Title "Generalize verified Poseidon circuit to arities 1 through 16", state Open, author martin-ochoa, opened
  17 September 2026, head `poseidon-n-arity`, base `main`, 3 commits, no labels.
- Review by mitschabaude, 21 September 2026, state "Commented": "very nice, close to mergeable from my side".
  Inline comment the same day: "can we remove this compat wrapper and just use the generic interface in our
  existing tests/demos?"
- Reply by martin-ochoa, 2 November 2026: "Thanks @mitschabaude I have updated this, let me know if this goes
  in the right direction." No activity after that.
- The page says at least one approving review is required to merge, and none has been given.
- The search page https://github.com/Verified-zkEVM/clean/pulls?q=is%3Apr+poseidon lists #465 among 4 open
  results; no other open pull request generalises the circomlib Poseidon.

What the branch contains (git, files read at `df7a54ca`; not built):
- `Clean/Circomlib/Poseidon/Generic.lean`: "def circuit {t : ℕ} (params : Params t) : FormalCircuit F
  (fields (t - 1)) field", with `Spec` "output = Specs.PoseidonOptimized.poseidon params input", and
  `theorem soundness` and `theorem completeness` stated for every `params`.
- `Clean/Circomlib/Poseidon.lean`: `Poseidon2.circuit := Circomlib.Poseidon.circuit params_t3`,
  `Poseidon3.circuit := ... params_t4`, `Poseidon4.circuit := ... params_t5`, up to `Poseidon16`. These are
  the widths 3, 4 and 5 the design needs.
- The word `sorry` occurs in none of the 12 Poseidon `.lean` files on the branch; no `axiom` declaration.
  `native_decide` occurs only in the specification and test-vector files (7 + 27 + 13 uses), not in the
  circuit proofs.
- What is proved is agreement with the framework's own optimised specification. `Clean/Circomlib/Poseidon.md`
  on the branch: "The correspondence with the external circomlib source is an audited regression check rather
  than a theorem about that external file." Constants are regenerated in Lean and compared with "iden3/circomlib
  commit `35e54ea21da3e8762557234298dbb553c175ea8d`"; outputs are compared with "iden3/circomlibjs commit
  `48b3ab37013c5ed21e9ff8a80a5b010795c97094`" on test vectors ("widths 2, 3, and 4" against the
  non-optimised specification; "[1, 2, ..., n]" for arities 4 to 16).
- Witness counts stated in the same file: "32 * t + params.nPartial * (t + 4) + 1", "496 local witnesses for
  `Poseidon2` and 577 for `Poseidon3`". With `nPartial := 60` at width 5 the formula gives 701.

### 2.3 What `main` contains today

Verified (git, files read at `a985c76c`):

- Poseidon files on `main`: `Clean/Circomlib/Poseidon.lean`, `Clean/Circomlib/Poseidon.md`,
  `Clean/Specs/Poseidon.lean`, `Clean/Specs/PoseidonConstants.lean`, `Clean/Specs/PoseidonOptimized.lean`.
  The `Poseidon/Generic.lean` family of the branch is absent.
- It is the original Poseidon with circomlib's parameters over the BN254 scalar field.
  `Clean/Specs/Poseidon.lean`: "-- BN254 scalar field prime (same as used in circomlib/snarkjs)", "abbrev
  BN254_PRIME := BN254.scalarFieldSize", "abbrev F := ZMod BN254_PRIME". `Poseidon.md`: "S-box `sigma(x) =
  x^5` (BN254)" and "The constants `C_t*`, `M_t*` are copied verbatim from circomlib's
  `poseidon_constants.circom`."
- Circuit with proofs: one, `Poseidon1` (one input, width 2). `Clean/Circomlib/Poseidon.lean` ends with
  `namespace Poseidon1 ... def circuit : FormalCircuit F field field`, whose `Spec` is "output =
  Specs.PoseidonOptimized.poseidon1Opt input". No `sorry` in the file. `Poseidon.md` opens: "This note walks
  through the structure of the Poseidon arity-1 (t=2) soundness and completeness proof for BN254".
- Specifications without circuits: `poseidon1` to `poseidon4` (widths 2 to 5) in `Clean/Specs/Poseidon.lean`
  with 7 circomlibjs test vectors checked by `native_decide`; optimised forms `poseidon1Opt`, `poseidon2Opt`,
  `poseidon3Opt` (widths 2 to 4) in `PoseidonOptimized.lean`. The constants file defines `C_t2` to `C_t5` and
  `M_t2` to `M_t5`, but the sparse-round tables only up to `S_t4` and `P_t4`: on `main` there is no optimised
  specification at width 5.
- Still true on `main` (`Poseidon.md`): "(There is no formal proof of `poseidon1Opt = poseidon1`; it's
  validated only against this test set.)"
- Poseidon2 (the later, different permutation) does not appear in the Lean sources on `main`. The only matches
  are a Rust test dependency: `backends/plonky3/tests/common/mod.rs`, "use p3_baby_bear::{BabyBear,
  Poseidon2BabyBear};".
- Other Poseidon work in open pull requests is for other fields or a different core, not circomlib on BN254:
  `Clean/Orchard/Poseidon/*` and `Clean/Ironwood/Poseidon/*` (pull request heads #418, #505 and others), and
  `Clean2/Gadgets/Poseidon.lean` in #476 "Clean 2: a new experimental core" (open, WebFetch), whose header
  says "Full rounds only."
- Last commits on `main` to the circomlib Poseidon files: `e3c9da78` (3 November) and `9852171d` (2 November),
  both toolchain or refactoring merges; the last change of substance is `4b54a19c`, 8 August 2026, "fix:
  restore real BN254 primality proof via CompPoly v4.32.0".

### 2.4 The R1CS exporter

Verified (git):

- Location on `main`: `Clean/Backends/Circom/` with `Ast.lean` (72 lines), `Binary.lean` (350), `Compile.lean`
  (1,464), `R1CS.lean` (226), `TestWasmCompile.lean` (495), `TestWasmSemantics.lean` (102) and `README.md`.
- Unchanged since it was merged. The blob hash of each of the seven files at `fba2a29f` (the merge of pull
  request #415, 16 September 2026) equals its blob hash on `main` today (for example `R1CS.lean` `450366fe1ef1`,
  `Compile.lean` `21d6765c1086`). One commit touched `Compile.lean` in between (`9f4f3304`, 12 October) with
  no net change.
- No proofs. None of the six `.lean` files contains a `theorem` or `lemma` declaration. The README's claim is
  about failure modes, not correctness: "Never silently wrong : the compiler is total: every unsupported
  instruction or unknown label fails at *compile time*".
- What it emits (README on `main`): "R1CS constraint files in two formats: a pretty-printed JSON object, and
  the binary `.r1cs` format consumed directly by `snarkjs r1cs info`, `groth16 setup`, and the other `r1cs`
  subcommands." Limits: "`native` witnesses (Lean closures) | ❌ Not compilable (`.error`)"; "lookups |
  Ignored by witness generation; `.error` in R1CS export".
- Tested in continuous integration against snarkjs: `.github/workflows/ci.yml` has "npm install -g snarkjs"
  and "CleanTests shells out to snarkjs / wasm-validate; without them the affected checks print SKIP instead
  of failing." The README lists a test that "compiles full **Poseidon1** to WASM, runs `snarkjs wtns
  calculate` on three inputs, and checks each witness against the Lean ground truth".
- Open pull requests on the exporter (heads from git; open state from WebFetch of
  https://github.com/Verified-zkEVM/clean/pulls?q=is%3Apr+R1CS+sort%3Aupdated-desc, same window):

| PR | Head, date | Title | What it adds |
|---|---|---|---|
| #473 | `579b26a6`, 2026-09-28, 1 commit | "feat(R1CS): R1CS semantics and soundness of the export" | `R1CSSemantics.lean`, `R1CSSoundness.lean` with `theorem exportConstraints_sound` and `theorem FormalCircuit.r1cs_soundness` ("A satisfying assignment `w` of the constraints exported from `circuit.main input_var` yields the circuit's `Spec`"). No `sorry`. Its README adds: "The converse direction, that every circuit environment extends to an R1CS witness, is not proved yet." |
| #470 | `440c5b04`, 2026-09-25 | "feat(circom): product absorption in R1CS lowering" | fewer intermediate signals |
| #471 | `612df062`, 2026-09-28 | "feat(r1cs): certified R1CS constraint simplification" | a simplifier with proofs |
| #472 | `2b61ab18`, 2026-09-28 | "feat(operations): certified constraint simplification on Operations" | `Clean/Circuit/Simplify.lean` (1,142 lines), `SimplifyFormal.lean` (482) |

  All four fork from `main` at 16 September and are 488 commits behind it, on Lean v4.33.1. WebFetch of
  https://github.com/Verified-zkEVM/clean/pull/473 (same window): Open, no human review; an automated Copilot
  review of 28 September says "Changes recommended" with two findings, "Verify fieldPrime matches the
  abstract field size" and "Bind serialized fieldPrime to the coefficient field"; last activity 29 September.
- Row count of an exported Poseidon (my derivation from the sources, not a measurement). The exporter turns
  every assertion into a row, including linear ones: in `R1CS.lean` a linear assertion becomes
  `(lc, [(0, (1 : F))], [])`. The branch's Poseidon binds every output of every mixing layer with `<==`
  (`Poseidon/Linear.lean`: "let output : Vector (Expression F) t <== Vector.ofFn ..."). So the exported row
  count is about the witness count: 496 at width 3, 577 at width 4, 701 at width 5. Of these, the
  multiplications are 3 × (8t + nPartial): 243, 264 and 300. Circom with full simplification (`--O2`) removes
  linear constraints and keeps roughly the multiplications. A circuit exported from this framework without #471 or
  #472 therefore has about twice the Poseidon rows of the circomlib circuit. If the design's "about 22,000
  constraints" assumes circomlib's count and the deployed circuit is this framework's export, the figure
  needs rechecking.

### 2.5 Not verified

- Nothing was built. That the branch's proofs check (on Lean v4.33.1) rests on reading the files and on the
  absence of `sorry`; that they would still check after a rebase onto `main` (v4.35.0) is unknown.
- Open or closed state, titles, dates and review text of pull requests come from WebFetch only. The heads,
  dates of commits, diffs and the merge test are from git.
- Whether the maintainers intend to merge #465, and when. The page shows no statement after 2 November.
- The exported row counts in 2.4 are derived from a formula in the branch's documentation and from reading
  the exporter. No `.r1cs` file was produced. The circomlib figures are arithmetic (three multiplications per
  S-box), not a compiler run.
- Whether the exporter's handling of `fieldPrime` (the Copilot findings on #473) is a real defect on `main`.
- The relation between the optimised and the non-optimised specification is still test vectors only, on
  `main` and on the branch.

## 3. Uniswap's protocol fee on v3 pools at the 1% tier, Ethereum mainnet

Read 11 November 2026, 19:47 to 19:57 UTC. "RPC" means `eth_call` or `eth_getLogs` against
https://ethereum-rpc.publicnode.com and https://eth.drpc.org (historical calls on drpc). "Sourcify" means
`https://sourcify.dev/server/v2/contract/1/<address>?fields=all` (curl). Forum text is from the Discourse
JSON of gov.uniswap.org (curl), so quotes are verbatim.

### 3.1 Result

- **The factory is owned by a fee adapter, not by the governance timelock.** `owner()` =
  `0xf2371551Fe3937Db7c750f4DfABe5c2fFFdcBf5A`, the contract `V3OpenFeeAdapter`. Governance (the timelock)
  owns the adapter and is its fee setter.
- **A protocol fee is on for every v3 fee tier on mainnet.** Tier defaults: 0.01% and 0.05% pools pay 1/4 of
  the swap fee to the protocol; 0.30% and 1% pools pay 1/6. These values have not changed since the adapter
  was deployed in February 2026.
- **It is not automatic at pool creation.** A new pool starts with `feeProtocol` 0. Anyone can call
  `triggerFeeUpdate(pool)` on the adapter, which sets the pool to its tier's default. In practice one
  unlabelled account does this for every new 1% pool 13 to 23 minutes after creation: all 18 pools created at
  the 1% tier in the last 50,000 blocks now read `feeProtocol` 102.
- **Existing 1% pools read `slot0().feeProtocol` = 102**, that is 6 for each token: 1/6.
- **What a position should expect: it loses 1/6 (16.67%) of the fees it would otherwise earn.** A 1% pool's
  liquidity providers receive 0.8333% of swap volume; the protocol receives 0.1667%. Treat the first minutes
  after launch at the full 1% as a bonus that cannot be relied on.
- **The swapper's cost does not change.** The swapper pays the pool's fixed 1%; the protocol's share is
  subtracted from that amount afterwards.
- **The share can change by governance vote.** The pool's own code allows only 0 or between 1/10 and 1/4.
  So the worst case for a locked position is 1/4 (25%) of its fees, and nothing in the pool or the position
  can prevent it. The design's fee figures should use 5/6 of the 1% fee, with 3/4 as the floor.

### 3.2 Who owns the factory (verified)

- `UniswapV3Factory.owner()` at block 26,393,867 (2026-11-11T19:46:47Z), RPC, both endpoints:
  `0xf2371551fe3937db7c750f4dfabe5c2fffdcbf5a`. `eth_getCode` at that address returns 7,266 bytes.
- Verified source: Sourcify reports "match: exact_match" (creation and runtime), contract
  `src/feeAdapters/V3OpenFeeAdapter.sol:V3OpenFeeAdapter`, solc 0.8.29, verified 2026-02-23T15:19:09Z,
  deployed in block 24,520,406 by transaction `0xf99405e6eff4bd1a8224e73d426cad3540550a537c200cb3964f4eeb24fc512a`.
  https://eth.blockscout.com/api/v2/smart-contracts/0xf2371551fe3937db7c750f4dfabe5c2fffdcbf5a (curl) agrees:
  name "V3OpenFeeAdapter", "is_fully_verified": true, constructor arguments `_factory`
  `0x1F98431c8aD98523631AE4a59f267346ea31F984` and `_tokenJar` `0xf38521f130fcCF29dB1961597bc5d2B60F995f85`.
- The contract's own description (verified source): "A permissionless contract that allows anyone to trigger
  protocol fee updates for pools." "This is a simplified version of V3FeeAdapter that removes Merkle proof
  authorization." "This contract will be the set owner on the Uniswap V3 Factory." "Fee resolution uses a
  waterfall pattern: pool override → fee tier default → global default".
- State of the adapter (RPC, block 26,393,873): `owner()` = `0x1a9c8182c09f50c8318d769245bea52c32be35bc` (the
  Uniswap governance timelock); `feeSetter()` = the same address; `FACTORY()` = the v3 factory; `TOKEN_JAR()` =
  `0xf38521f130fccf29db1961597bc5d2b60f995f85`.
- History of the factory's owner (historical `owner()` calls on drpc, bisected to the block):

| From block | Time (UTC) | Owner | Transaction that changed it |
|---|---|---|---|
| before 24,106,378 | | `0x1a9c8182…35bc` (timelock) | |
| 24,106,378 | 2025-12-27 20:33:11 | `0x5e74c9f42eed283bff3744fbd1889d398d40867d` (`V3FeeAdapter`, the list-based adapter) | `0x091f0083242a777d55821c1189e568d6d033d9da501b75087dc736fa143d2c1e`, `GovernorBravo.execute(93)` |
| 24,596,885 | 2026-03-06 07:19:59 | `0xf2371551…bf5a` (`V3OpenFeeAdapter`) | `0xd6c4c93eaaac3b6cf144853655f91b326c5e3019b022baeec08eaf74c8af9833`, `GovernorBravo.execute(94)` |

### 3.3 Governance records (verified)

On chain, Governor Bravo `0x408ED6354d4973f66138C91495F2f2FCbd8724C3` (RPC, `proposals(id)`, `state(id)`,
`getActions(id)`; `proposalCount()` = 102, every proposal from 92 to 102 reads state Executed):

- Proposal 93 ("UNIfication"): for 125,342,017, against 742, abstain 1,500,007; eta 2025-12-27T20:32:23Z. Action
  2 targets the v3 factory with calldata `13af4035…5e74c9f42eed283bff3744fbd1889d398d40867d`, which is
  `setOwner(V3FeeAdapter)`. Action 4 calls `setFeeTo` on the v2 factory.
- Proposal 94: for 62,837,439, against 4,968; eta 2026-03-06T06:51:35Z. Action 3 targets the old adapter
  `0x5e74c9f4…867d` with calldata `f3cc660c…f2371551fe3937db7c750f4dfabe5c2fffdcbf5a`, which is
  `setFactoryOwner(V3OpenFeeAdapter)`.
- None of proposals 95 to 102 has the adapter `0xf2371551…` as a target or in its calldata. No proposal is
  pending.

Forum (curl of the topic JSON; both first posts were last edited 2026-11-10, and the revision record shows
only a category change, no change to the text):

- https://gov.uniswap.org/t/unification-proposal/25881 (posted 2025-11-10 by haydenadams): "Uniswap v3 has
  fixed swap fee tiers on mainnet, with protocol fees that are adjustable by governance and set at the
  individual pool level. Protocol fees for 0.01% and 0.05% pools would initially be set to 1/4th of LP fees.
  For 0.30% and 1% pools, protocol fees would be set to 1/6th of LP fees." And: "we propose fees roll out over
  time, starting with v2 pools and a set of v3 pools that make up 80-95% of LP fees on Ethereum mainnet."
- https://gov.uniswap.org/t/temp-check-protocol-fee-expansion-eight-more-chains-and-remaining-mainnet-v3-pools/26035
  (posted 2026-02-18 by haydenadams): "Enable protocol fees on all v3 pools via a new tier-based
  v3OpenFeeAdapter on mainnet and the above L2s". "Protocol fees are set uniformly across all pools sharing
  the same LP fee tier." "Any pool automatically gets the default protocol fee for its tier, no governance
  action is needed. This means if this proposal passes, protocol fees will be active on every v3 pool.
  Governance retains the ability to override fees on individual pools."
- Same topic, post 5 (eek637, 2026-03-03): "The correct address is
  `0xf2371551Fe3937Db7c750f4DfABe5c2fFFdcBf5A`. The only difference between the contracts is a global default
  fee setting."
- Future fee changes use a shorter process (UNIfication post): "we propose governance votes on fee parameters
  skip the RFC process and move straight to Snapshot followed by an onchain vote." The February post calls
  this "a five-day Snapshot followed by an onchain vote".
- A forum search for "setFeeTierDefault", "setPoolOverride" and for v3 fee-tier proposals after 1 June 2026
  returned no proposal to change the mainnet v3 levels. The open fee topics are about other chains and v4
  ("[Temp Check] Protocol Fee Expansion: Arc", "[Temp Check] Activate v4 Protocol Fees").

Repository https://github.com/Uniswap/protocol-fees (git clone, head `eacc9c0`, 2026-11-05):
`script/deployers/V3OpenMainnetDeployer.sol` has "uint8 constant DEFAULT_FEE_10000 = 6 << 4 | 6; // 1/6 for
1.00% tier" and "uint8 constant DEFAULT_FEE_3000 = 6 << 4 | 6; // 1/6 for 0.30% tier", "DEFAULT_FEE_100 = 4 <<
4 | 4; // 1/4 for 0.01% tier", "DEFAULT_FEE_500 = 4 << 4 | 4; // 1/4 for 0.05% tier". The README lists
`V3OpenFeeAdapter` on mainnet at `0xf2371551Fe3937Db7c750f4DfABe5c2fFFdcBf5A`.

### 3.4 The levels in force, and who can change them (verified)

Adapter state, RPC, block 26,393,873:

| Fee tier (`fee`) | `feeTierDefaults(tier)` | Meaning | Share of the swap fee |
|---|---|---|---|
| 100 (0.01%) | 68 = 0x44 | 4 for token0, 4 for token1 | 1/4 |
| 500 (0.05%) | 68 = 0x44 | 4, 4 | 1/4 |
| 3000 (0.30%) | 102 = 0x66 | 6, 6 | 1/6 |
| 10000 (1%) | 102 = 0x66 | 6, 6 | 1/6 |
| global `defaultFee()` | 68 | used only for a tier with no default | 1/4 |

- `feeTiers(0..3)` = 100, 500, 3000, 10000; `feeTiers(4)` reverts. The factory's
  `feeAmountTickSpacing(10000)` = 200.
- Unchanged since deployment: the same five values and the same `feeSetter` read at blocks 24,520,500
  (2026-02-23), 24,596,885, 24,900,000, 25,200,000, 25,500,000, 25,800,000, 26,100,000, 26,300,000 and
  26,393,912 (historical calls, drpc).
- Who can change them (verified source): `setFeeTierDefault`, `setDefaultFee`, `setPoolOverride`,
  `clearFeeTierDefault` and `clearPoolOverride` carry `onlyFeeSetter`; `setFeeSetter` and `setFactoryOwner`
  carry `onlyOwner`. Both roles are the timelock. A change reaches a pool only when someone calls the trigger
  again.
- Hard limits. Adapter: "V3 fees are packed uint8 with two 4-bit values, each must be 0 or in range [4, 10]".
  Pool (source of the 1% USDC/WETH pool `0x7BeA39867e4169DBe237d55C8242a8f2fcDcc387`, Sourcify "match", solc
  0.7.6; identical text at https://raw.githubusercontent.com/Uniswap/v3-core/v1.0.0/contracts/UniswapV3Pool.sol):
  "function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external override lock onlyFactoryOwner {
  require( (feeProtocol0 == 0 || (feeProtocol0 >= 4 && feeProtocol0 <= 10)) && (feeProtocol1 == 0 ||
  (feeProtocol1 >= 4 && feeProtocol1 <= 10)) );". So the protocol's share of a pool's swap fee is 0 or between
  1/10 and 1/4, per token.

### 3.5 New pools: the trigger (verified)

- A pool starts at zero. Pool source, `initialize`: "feeProtocol: 0,". The factory's `createPool` does not
  set it.
- The trigger is open to anyone. Adapter source: "function triggerFeeUpdate(address pool) external {
  _setProtocolFee(pool); }", documented "Triggers a fee update for a single pool. Permissionless." The same
  holds for `triggerFeeUpdate(address token0, address token1)`, `batchTriggerFeeUpdate` and
  `batchTriggerFeeUpdateByPool`. `_setProtocolFee` skips a pool that is not initialized ("if (sqrtPriceX96 ==
  0) return;") and otherwise calls "IUniswapV3PoolOwnerActions(pool).setFeeProtocol(feeValue % 16, feeValue >>
  4);".
- What happens in practice (RPC `eth_getLogs`, blocks 26,343,876 to 26,393,876, about seven days):
  - 18 `PoolCreated` events at fee 10000. All 18 pools read `slot0().feeProtocol` = 102 today.
  - Each was triggered between 66 and 113 blocks after creation (median 96), about 13 to 23 minutes.
  - All 73 `FeeUpdateTriggered` events in the window have the same caller,
    `0x87c4d68b2a3c929f5d9c4bc594c95ca5c1df5ce2`, an account with no code (nonce 1,082), calling
    `batchTriggerFeeUpdateByPool` (selector `0x08f4779e`).
  - Example, the newest 1% pool `0x124c31ffc8e47352cb3dbb8e663bb62d26530741`: created and initialized in
    block 26,392,942 (16:40:59 UTC) with `feeProtocol` 0; still 0 at block 26,393,025; 102 from block
    26,393,026 (16:57:47 UTC), transaction
    `0xfedacbb19aa1074034a1b6eb4e540d10ad6f6ee8d79f925a7a1cacbfa7092a4b`. That is 1,008 seconds.
- For the design: the pool that `launch` creates will carry no protocol fee in its creation block and for
  some minutes after. The launch contract cannot keep it that way. Anyone, including a competitor or the
  account above, can switch it to 1/6 in the next block.

### 3.6 `slot0().feeProtocol` on existing 1% pools (verified, RPC, block 26,393,873)

| Pool | Address | `fee` | `feeProtocol` | token0, token1 |
|---|---|---|---|---|
| PEPE/WETH | `0xf239009a101b6b930a527deaab6961b6e7dec8a6` | 10000 | 102 | 6, 6 |
| SHIB/WETH | `0x5764a6f2212d502bc5970f9f129ffcd61e5d7563` | 10000 | 102 | 6, 6 |
| WETH/USDT | `0xc5af84701f98fa483ece78af83f11b6c38aca71d` | 10000 | 102 | 6, 6 |
| USDC/WETH | `0x7bea39867e4169dbe237d55c8242a8f2fcdcc387` | 10000 | 102 | 6, 6 |
| LINK/WETH | `0x3a0f221ea8b150f3d3d27de8928851ab5264bb65` | 10000 | 102 | 6, 6 |

For comparison: USDC/WETH 0.05% `0x88e6a0c2…5640` reads 68 (4, 4); USDC/WETH 0.30% `0x8ad599c3…e6d8` reads
102; USDC/USDT 0.01% `0x3416cf6c…27c6` reads 68. For every pool above the adapter's `getFee(pool)` equals the
pool's value and `poolOverrides(pool)` is 0. The USDC/WETH 1% pool read 0 at block 24,106,377 and 102 from
block 24,106,500 (historical calls), so it was in the first list of December 2025.

### 3.7 What the fee takes, and from whom (verified in the pool's source)

Pool source (`swap`), the swap step is computed with the pool's fixed fee and the protocol's share is taken
out of the fee afterwards:

- "(state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep( ...,
  state.liquidity, state.amountSpecifiedRemaining, fee );"
- "// if the protocol fee is on, calculate how much is owed, decrement feeAmount, and increment protocolFee
  if (cache.feeProtocol > 0) { uint256 delta = step.feeAmount / cache.feeProtocol; step.feeAmount -= delta;
  state.protocolFee += uint128(delta); }"

So:

- The swapper pays `amountIn + feeAmount` whatever `feeProtocol` is. The price and the 1% charged are the
  same with the protocol fee on or off.
- With `feeProtocol` 6 the liquidity providers' fee growth is credited with `feeAmount − floor(feeAmount /
  6)`. A position loses 1/6 = 16.67% of its fee income: 0.8333% of input volume instead of 1%. Because of the
  rounding down, the protocol takes very slightly less than 1/6 on small swap steps.
- The same division applies to flash-loan fees ("uint256 fees0 = feeProtocol0 == 0 ? 0 : paid0 /
  feeProtocol0;").
- Fees already credited to a position are not touched. `collectProtocol` pays out only the separately
  accounted `protocolFees`; the adapter's `collect` is callable by anyone and sends them to the token jar.
- Range of outcomes for a locked position under the pool's immutable code: 100% of the fee (protocol fee
  off or not yet triggered), 5/6 (today), 3/4 (the maximum governance can set).

### 3.8 Not verified

- Who operates `0x87c4d68b…5ce2`, and whether it will keep running. If it stopped, a pool would stay at zero
  until anyone else called the trigger.
- The complete event history of the adapter (`FeeTierDefaultUpdated`, `PoolOverrideUpdated` and so on). Public
  endpoints refused log queries over old blocks, and Blockscout's log API returned "Too many requests". The
  claim "unchanged since deployment" rests on nine historical reads and on the targets of proposals 95 to 102,
  not on a full event scan. A change that was later reverted between two sampled blocks would not show.
- The text of on-chain proposals 93 and 94 (the `ProposalCreated` descriptions) was not read; their actions
  were decoded from `getActions`. The Snapshot votes were not read.
- Pool overrides: only the eight pools in 3.6 were checked for an override. Whether any pool has one was not
  scanned.
- Whether governance intends to change the 1% tier's level. No proposal was found; absence of evidence only.
- `etherscan.io` returns HTTP 403 here; nothing in this section depends on it.

## 4. X-Wing

(pending)

## 5. USDT's verified source on Ethereum

(pending)
