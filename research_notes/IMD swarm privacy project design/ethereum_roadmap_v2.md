# Ethereum roadmap re-verification, v2 (9–10 November 2026)

Delta check against `ethereum_roadmap_nov2026.md` (state as of 8 Nov 2026) and the "Prices" rows of `cost_inputs.md`. Only items that can have moved were re-fetched; the corpus was not redone.

**Fetch windows.** Main pass: 2026-11-09 21:08–21:25 UTC. Re-check after the date rolled over: 2026-11-10 00:13 UTC (EIP files, EF blog feed, Forkcast API, Magicians, gas-invariants repo, prices). Where a row says "9 Nov / 10 Nov", the 10 Nov re-check returned the same content.

**Headline.** Nothing in the protocol specification or the fork schedule changed between 8 Nov and 10 Nov 2026. EIP-8037 and EIP-8038 are byte-identical to what the 8 Nov note recorded; no ACD call has taken place since 29 Oct; the EF 6 Nov post is still the latest official statement. What did move is prices. This pass also found several things the 8 Nov note had missed or got wrong (section 8, second table).

## Sources and fetch dates

| Key | Source | Fetched (UTC) |
|---|---|---|
| S1 | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8037.md and https://eips.ethereum.org/EIPS/eip-8037 | 2026-11-09 21:08; re-checked 2026-11-10 00:13 |
| S2 | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8038.md and https://eips.ethereum.org/EIPS/eip-8038 | same |
| S3 | `git clone` of https://github.com/ethereum/EIPs (master `542e62e`, history since 2026-09-01) for per-file commit dates; PR head refs `refs/pull/*/head` for pending diffs | 2026-11-09 21:09; `git ls-remote` 2026-11-10 00:13 still `542e62e` |
| S4 | https://github.com/ethereum/EIPs/pulls?q=is%3Apr+8037+sort%3Aupdated-desc and PR pages /pull/12581, /pull/12582, /pull/12638 | 2026-11-09 ~21:18 |
| S5 | https://blog.ethereum.org/en/feed.xml ; https://blog.ethereum.org/2026/11/06/glamsterdam-8037-8038 ; /2026/10/22/glamsterdam-hoodi-delay ; /2026/10/16/glamsterdam-hoodi-announcement | 2026-11-09 21:10; feed re-checked 2026-11-10 00:13 |
| S6 | https://github.com/ethereum/glamsterdam-gas-invariants (cloned; HEAD `5998e89`, 2026-11-06 09:21 UTC) | 2026-11-09 21:10; HEAD re-checked 2026-11-10 00:13 |
| S7 | https://github.com/ethereum/pm (cloned): `.github/ACDbot/meeting_topic_mapping.json`, `.github/ACDbot/artifacts/{acde/2026-10-22_248,acdt/2026-10-26_102,acdc/2026-10-29_190}/tldr.json`, `glamsterdam-mainnet-plan.md`; issue list https://github.com/ethereum/pm/issues?q=is%3Aissue+sort%3Acreated-desc ; issues /2285, /2291 | 2026-11-09 21:10–21:18 |
| S8 | Forkcast JSON API: https://forkcast.org/api/eips.json , /api/eip-stage-changes.json , /api/upgrades.json , /api/calls.json ; https://forkcast.org/llms.txt ; repo https://github.com/ethereum/forkcast (`src/data/whether-report.ts`, `public/artifacts/{acde,acdc}/plan/*.json`) | 2026-11-09 21:17; API re-checked 2026-11-10 00:13 (`generatedAt` 2026-11-09T13:14Z) |
| S9 | https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8081.md and https://eips.ethereum.org/EIPS/eip-8081 ; same for eip-7773 | 2026-11-09 21:15; re-checked 2026-11-10 00:13 |
| S10 | Raw + rendered pages for EIP-2780, 7708, 7732, 7778, 7825, 7843, 7904, 7928, 7954, 7976, 7981, 7997, 8141, 8250, 7805, 8151, 8272, 8182, 8105, 7701, 8015, 8246, 8261 (same URL pattern as S1) | 2026-11-09 21:15 |
| S11 | https://ethereum-magicians.org/latest.json?order=created ; topic JSON /t/25694 (EIP-8037), /t/25693 (EIP-8038), /t/30139 (ACDC #191), /t/30071 (ACDE #249), /t/28494 (EIP-8261) | 2026-11-09 21:16; latest re-checked 2026-11-10 00:13 |
| S12 | https://ethereum.org/roadmap/glamsterdam/ and https://ethereum.org/roadmap/hegota/ | 2026-11-09 21:16 |
| S13 | https://raw.githubusercontent.com/eth-clients/{hoodi,sepolia,mainnet}/main/metadata/config.yaml ; https://raw.githubusercontent.com/ethereum/consensus-specs/master/configs/mainnet.yaml | 2026-11-09 21:20 |
| S14 | https://github.com/ethereum/execution-specs (branch heads fetched at depth 1) | 2026-11-09 21:22 |
| S15 | https://www.chainsecurity.com/blog/glamsterdam-gas/index.html (dated 2026-10-13) | 2026-11-09 21:16 |
| S16 | JSON-RPC https://ethereum-rpc.publicnode.com and https://eth.drpc.org (`eth_getBlockByNumber`, `eth_gasPrice`, `eth_feeHistory` over 217,440 blocks) | 2026-11-09 21:15–21:19; 2026-11-10 00:13 |
| S17 | https://ultrasound.money/api/v2/fees/base-fee-per-gas-stats | 2026-11-09 21:19; 2026-11-10 00:13 |
| S18 | https://api.coinbase.com/v2/prices/ETH-USD/spot ; https://api.exchange.coinbase.com/products/ETH-USD/stats ; https://api.gemini.com/v1/pubticker/ethusd ; https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd&include_last_updated_at=true ; Chainlink ETH/USD feed `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419` `latestRoundData()` via S16 ; https://chaingate.dev/gas-tracker/ethereum | 2026-11-09 21:19; 2026-11-10 00:13 |
| S19 | https://cointelegraph.com/news/ethereum-devs-fork-glamsterdam-hoodi-smart-contract-risks (secondary, dated 2026-11-06) | 2026-11-09 21:23 |

---

## 1. Glamsterdam: schedule and status

**Status on 10 Nov 2026: paused, no Hoodi date, no mainnet date. No new decision since the 6 Nov EF post.**

| Network | State | Evidence |
|---|---|---|
| Sepolia | Live since 2026-10-06 13:53:36 UTC, epoch 353024 | EIP-7773 activation table [S9]; `GLOAS_FORK_EPOCH: 353024` in eth-clients/sepolia config [S13] |
| Hoodi | Unscheduled. The 2026-10-26 17:42:48 UTC activation (epoch 132352) and the 200M gas-limit step were removed on 22 Oct | EF post 22 Oct [S5]; eth-clients/hoodi config has no `GLOAS_*` entries at all [S13]; `glamsterdam-mainnet-plan.md` shows Hoodi "TBD" [S7] |
| Holešky | Not part of Glamsterdam. Sunset after Fusaka; EIP-7773's table lists only Sepolia, Hoodi, Mainnet | https://blog.ethereum.org/2025/09/01/holesky-shutdown-announcement (fetched 2026-11-09 21:20); [S9] |
| Mainnet | TBD. `GLOAS_FORK_EPOCH: 18446744073709551615` in consensus-specs mainnet config; eth-clients/mainnet has no Gloas entry | [S13]; [S7] plan file "TBD" |

Caveat: the EIP-7773 file itself still prints the Hoodi row "132352 / 1793036568 (2026-10-26 17:42:48 UTC)". It is stale. PR #12568 "Update EIP-7773: Clear postponed Hoodi activation" (head dated 2026-10-22) has not been merged [S3].

**What the calls decided (from ACDbot `tldr.json`, [S7]):**
- ACDE #248, 22 Oct: "Hoodi Glamsterdam hard fork canceled indefinitely; no new date set"; "Mainnet Glamsterdam fork date decision deferred until full impact analysis complete"; highlight "December 2026 fork now very unlikely; 2027 expected"; "13 major DeFi projects identified as vulnerable"; three response tiers: on-schedule mainnet if mitigated, delayed mainnet with the same spec, or Glamsterdam spec changes.
- ACDT #102, 26 Oct: "Hoodi fork delayed at least 2 weeks pending EIP-8037/8038 blast radius analysis"; audit ETA "~2 weeks from October 26th"; "Default path: affected contracts fix themselves; spec changes only as last resort"; "Francesco: no meaningful findings after comprehensive analysis including Sourcify contract scan; spec changes very unlikely"; "Łukasz's spec-change PR being reviewed; Maria decomposing into targeted per-invariant fixes rather than a bundle".
- ACDC #190, 29 Oct: consensus-specs release 30 Oct; a Glamsterdam devnet including a consensus-breaking "Lido PR" estimated for 16–20 Nov at the earliest.

**Since 6 Nov:**
- No ACD call has happened. The call list jumps from ACDC #190 (29 Oct) to ACDC #191 on **12 Nov 2026 14:00 UTC** and ACDE #249 on **19 Nov 2026 14:00 UTC** (moved from 5 Nov because of Devcon) [S7, S8, S11]. Both agendas contain only the headings "Glamsterdam / Hegotá / Misc" [S7 issues 2291, 2285].
- ACDT #102 announced "ACDT #103 moved to November 9th", but there is no pm issue, Magicians topic, or Forkcast artifact for an ACDT #103 as of 2026-11-10 00:13 UTC [S7, S8, S11]. Whether it was held is NOT VERIFIED.
- EF blog: newest post is still 6 Nov [S5]. Gas-invariants repo: last commit 2026-11-06 09:21 UTC [S6]. Magicians EIP-8037 thread: last post 3 Nov; EIP-8038 thread: last post 6 Oct [S11].
- Forkcast homepage brief (dated 2026-11-06): rollout "is paused while a security disclosure is analyzed" [S8]. Forkcast's `projectedActivation` for Glamsterdam still reads 2026-12-02; Forkcast documents that field as its own planning estimate, "never an announced date", and it predates the pause [S8].
- ethereum.org Glamsterdam page is unchanged and stale: "Page last update: October 16, 2026", "Expected on mainnet Q4 2026", "Next milestone Hoodi fork, October 27, 2026" [S12].
- Forkcast's generated agenda suggestions for ACDE #249 (generated 2026-11-09) list "Glamsterdam security impact analysis and mainnet fork decision" as the top item [S8]. This is a bot suggestion, not a confirmed agenda.

**The eight invariants** (README of [S6]; types P = price change, A = accounting change):

| ID | Old assumption | Type | What changes |
|---|---|---|---|
| INV-1 | If a call runs out of gas, the whole transaction fails | A | With a reservoir, code after a failed call can still write storage; `call{gas: X}` does not bound the callee's state gas |
| INV-2 | Clearing a value set earlier in the tx gives no gas back until the end | A | 0 → x → 0 refills 97,920 state gas at once, so `gasleft()` rises |
| INV-3 | Gas used by a reverting call is gone | A | A reverting call hands back its state gas; a failed creation hands back 183,600 |
| INV-4 | A fixed gas amount is enough | P | State creation costs 5–8x more; existing-slot writes cost about 7,200 more |
| INV-5 | `gasleft()` only decreases, so start minus end measures cost | A | `gasleft()` can go up; reservoir-paid state gas never appears in it |
| INV-6 | The 1/64 left after a starved call is too little to do anything | P | At the new prices the leftover can finish and record a failure |
| INV-7 | Reserves and the 2,300 stipend sized for today suffice | P | A post-call storage write costs 110,020; the stipend cannot create a slot |
| INV-8 | A 7702 delegation in a mined tx was applied | A | A delegation that runs out of gas is rolled back but the tx is mined; the signed authorization can be reused |

The repo says "Most findings we had reference INV-4 and INV-7" and "Depending on the response we might decide to slightly change EIP-8037/8038 or not." [S6]

**Resolved or re-specified? No.** Three separate pieces of evidence:
1. The EIP files have not changed (section 2).
2. Candidate spec changes exist only as open pull requests [S3, S4]:
   - #12581 (Łukasz Rozmej, opened 24 Oct, last commit 25 Oct, last comment 4 Nov, **open**): refills and rollbacks credit the reservoir only, so `gas_left` never increases; adds a "legacy share" so that a new slot, a new account and a `CREATE` take at least their pre-fork cost from `gas_left` (10,000 / 25,000 / 20,000 with current EIP-8038 values; constants `PRE_FORK_GAS_STORAGE_SET = 20,000`, `PRE_FORK_GAS_NEW_ACCOUNT = 25,000`, `PRE_FORK_GAS_CREATE = 32,000`). Latest comment (rakita, 4 Nov) says the PR "probably can be closed".
   - #12582 (same author, opened 24 Oct, **open**): per-call-frame state-gas allowance, `LEGACY_GAS_PER_STATE_BYTE = 200`, i.e. a callee can draw at most about 7.65x its forwarded gas from the reservoir.
   - #12573 and #12624 (flcl42, open): wording corrections only. #12612 and #12626 (EIP-8038; not merged, open/closed state not checked individually): clarifications only.
   - #12638 (opened 8 Nov, updated 9 Nov, open, draft EIP-8488 "Versioned Opcodes for Gas Repricing"): new contracts would use V2 opcodes carrying the 8037/8038 schedule while existing contracts keep the legacy one. An outside proposal with no fork target.
   - **Neither #12581 nor #12582 changes any price.** Total gas paid per operation is identical; they change which pool pays and when gas comes back.
3. In ethereum/execution-specs, `forks/amsterdam` has had no commit since 2026-10-06. Two exploratory branches dated 2026-11-03 exist: `eips/amsterdam/eip-8037-clear-refill-capped` ("repay eip-8037 slot-clear state gas through the capped refund counter") and `eips/amsterdam/eip-8037-clear-refill-counter` ("defer the slot-clear state gas refill until the transaction settles"). Neither is merged [S14].

Reading: the audit window announced on 26 Oct ("~2 weeks") ends about now, and the first venue for a decision is ACDC #191 (12 Nov) or, more plausibly for an execution-layer question, ACDE #249 (19 Nov). The only variants under discussion change gas accounting mechanics, not `CPSB` or the EIP-8038 constants. That is an inference from the PR set and call notes; no source states it as a decision.

---

## 2. EIP-8037 and EIP-8038: exact current parameters

**File status.** Both are `status: Last Call`, `last-call-deadline: 2026-11-01` (the deadline has passed without a move to Final) [S1, S2]. Raw markdown on master and the rendered eips.ethereum.org pages agree on every parameter below. Git blob hashes of the downloaded files equal those at master HEAD `542e62e` (`c8bc85b…` for 8037, `a1c73c4…` for 8038) [S3].

| File | Latest commit touching it | Last substantive change | Changed after 6 Nov? |
|---|---|---|---|
| `EIPS/eip-8037.md` | `5ef3801`, 2026-10-06 21:57:47 UTC, "Update EIP-2780: Move to Last Call (#12442)" | 2026-10-02 (co-author additions); same commit moved it to Last Call | **No** |
| `EIPS/eip-8038.md` | `f1ade09`, 2026-10-22 14:08:27 UTC, "Align titles and descriptions of Glamsterdam EIPs (#12561)" | `8b1cae5`, 2026-10-15 14:33:13 UTC, "Expand gas estimation methodology and add supporting reports" | **No** |

Master HEAD itself is dated 2026-11-07 21:56 UTC (an EIP-8355 test-vector commit) and was unchanged at 2026-11-10 00:13 UTC [S3].

### EIP-8037 (State Creation Gas Cost Increase) [S1]

| Parameter | Value | Derived cost |
|---|---|---|
| `CPSB` (cost per state byte) | 1530 | from 120 GiB/yr at a 150M reference gas limit, 50% utilisation |
| `STATE_BYTES_PER_STORAGE_SET` | 64 | new storage slot = **97,920** state gas |
| `STATE_BYTES_PER_NEW_ACCOUNT` | 120 | new account = **183,600** state gas |
| `STATE_BYTES_PER_AUTH_BASE` | 23 | 7702 delegation indicator = 35,190 state gas |
| Code deposit | `CPSB` per byte | **1,530** state gas per byte, plus `6 × ceil(len/32)` execution gas (hash cost) |
| `SYSTEM_MAX_SSTORES_PER_CALL` | 16 | `SYSTEM_CALL_GAS_LIMIT = 30,000,000 + 64×1530×16 = 31,566,720` |
| `TX_MAX_TOTAL_GAS_LIMIT` | 4,294,967,295 (2^32 − 1) | cap on `tx.gas` as a whole |
| `EXECUTION_PER_AUTH_BASE_COST` | 7,816 (via EIP-2780) | 1,616 calldata + ecRecover 3,000 + cold access 3,000 + 2 × 100 |

Old-to-new mapping in the EIP: `GAS_CREATE` 32,000 becomes 183,600 state + `CREATE_ACCESS` execution; `GAS_CODE_DEPOSIT` 200/byte becomes 1,530 state/byte + hash cost; `GAS_NEW_ACCOUNT` 25,000 becomes 183,600 state; `GAS_STORAGE_SET` 20,000 becomes 97,920 state; `PER_EMPTY_ACCOUNT_COST` 25,000 becomes 183,600 state + `ACCOUNT_WRITE`; `PER_AUTH_BASE_COST` 12,500 becomes 35,190 state + 7,816 execution.

**Is state gas a separate dimension, and does it count against the 16,777,216 cap?** Quoted from the current text [S1]:
- "Two gas dimensions are introduced, execution-gas and state-gas."
- "the transaction gas limit set in EIP-7825 only applies to execution-gas, while state-gas is capped by `tx.gas`, which this proposal in turn caps at `TX_MAX_TOTAL_GAS_LIMIT`."
- Reservoir split: `evm_gas = tx.gas − intrinsic_gas`; `gas_left = min(TX_MAX_GAS_LIMIT − intrinsic_gas, evm_gas)`; `state_gas_reservoir = evm_gas − gas_left`.
- "State-gas charges deduct from `state_gas_reservoir` first. When the reservoir is exhausted, the remainder deducts from `gas_left`".

So the answer has two halves:
- **`tx.gas` above 16,777,216:** the excess sits in a separate reservoir that only state gas can use. State gas paid from it does not count against the 2^24 execution cap.
- **`tx.gas` at or below 16,777,216:** the reservoir is zero. All state gas comes out of `gas_left`, i.e. out of the same 16.78M budget as execution. The gas-invariants README states this directly: the reservoir exists "only when `tx.gas > 2^24`. Below that, all state gas comes out of `gasleft()`" [S6].

Other accounting rules that matter for contract design [S1]:
- The reservoir is passed to child frames in full; the 63/64 rule applies to `gas_left` only. The `GAS` opcode returns `gas_left` only.
- Refills (state creation undone in the same tx) are credited LIFO: to `gas_left` first, up to what the frame drew from it, then to the reservoir. This is why `gasleft()` can increase.
- Validity: `tx.gas ≤ 2^32 − 1` and `max(intrinsic_gas, calldata_floor) ≤ 16,777,216`. Inclusion: `min(16,777,216, tx.gas) ≤ execution_gas_available` and **`tx.gas ≤ state_gas_available = block_gas_limit − block_state_gas_used`**. A transaction's whole `tx.gas` must therefore fit under the block gas limit in the state dimension.
- Block: `gas_used = max(block_execution_gas_used, block_state_gas_used)`; the base fee updates on that value.
- Refund cap stays at 20% of gas used. State-gas refills are not refunds and stay netted out of block accounting even under EIP-7778.
- EIP-8037's own impact table: new account 25,000 → 183,600 (~7x); new slot 20,000 → 97,920 (~5x); 24 kB deployment 4,947,200 → 37,784,880 (~8x).

### EIP-8038 (State-Access Gas Cost Update) [S2]

| Parameter | Current | New | Change |
|---|---|---|---|
| `COLD_ACCOUNT_ACCESS` | 2,600 | **3,000** | +15% |
| `COLD_STORAGE_ACCESS` (cold SLOAD/SSTORE touch) | 2,100 | **2,100** | 0% |
| `WARM_ACCESS` | 100 | 100 | 0% |
| `ACCOUNT_WRITE` (per value-bearing call, creation, delegation set) | 6,700 | **9,000** | +34% |
| `STORAGE_WRITE` (SSTORE that changes a slot; net-metered per tx) | 2,800 | **10,000** | +257% |
| `CREATE_ACCESS` (= `ACCOUNT_WRITE + COLD_ACCOUNT_ACCESS`) | 7,000 | **12,000** | +71% |
| `STORAGE_CLEAR_REFUND` | 4,800 | **11,616** | +142% |
| `ACCESS_LIST_STORAGE_KEY_COST` | 1,900 | 2,000 | +5% |
| `ACCESS_LIST_ADDRESS_COST` | 2,400 | 2,900 | +21% |
| `CALL_VALUE` (redefined as `ACCOUNT_WRITE + CALL_STIPEND`) | 9,000 | 11,300 | stipend stays 2,300 |
| `EXTCODESIZE` / `EXTCODECOPY` | access cost | access cost + 100 | second database read |

SSTORE under the two EIPs together: access component (2,100 cold or 100 warm) + `STORAGE_WRITE` 10,000 if the write moves the slot away from its tx-start value + 97,920 state gas if 0 → non-zero. Refund rules: `STORAGE_CLEAR_REFUND` granted on x → 0, reversed if the slot is set again in the same tx; `STORAGE_WRITE` refunded when a slot is restored to its tx-start value.

### Comparison with the 8 Nov note

| Item | 8 Nov note | Current text | Match |
|---|---|---|---|
| CPSB | 1530 | 1530 | yes |
| New storage slot | 97,920 | 97,920 state gas | yes |
| New account | 183,600 | 183,600 state gas | yes |
| Per code byte | 1,530 | 1,530 state gas (+ 6 gas per 32-byte word) | yes; the hash cost was not recorded before |
| Storage write | 10,000 | 10,000 | yes |
| Cold account access | 3,000 | 3,000 | yes |
| Cold SLOAD | 2,100 | 2,100 | yes |
| Create access | 12,000 | 12,000 | yes |
| Clear refund | 11,616 | 11,616 | yes |
| State gas separate from 2^24 cap | yes | yes, but only for the part of `tx.gas` above 2^24 | refinement |

---

## 3. Other Glamsterdam EIPs: parameters and status [S10, S3]

All Glamsterdam core EIPs below show `status: Last Call`, deadline 2026-11-01, unless noted. None changed after 6 Nov.

| EIP | Current parameters | Latest commit to file (UTC) |
|---|---|---|
| EIP-7976 calldata floor | `STANDARD_TOKEN_COST = 4`, `TOTAL_COST_FLOOR_PER_TOKEN = 16`; floor = **64 gas per calldata byte**, zero or non-zero (was 10/40). Open PR #12639 (9 Nov) only renames parameters (`TOKENS_PER_BYTE`, `STANDARD_COST_PER_TOKEN`, `FLOOR_COST_PER_TOKEN`); values identical | 2026-10-06 |
| EIP-7981 access-list cost | adds `64 × access_list_bytes` as a flat surcharge: **+1,280 per address, +2,048 per storage key**, on top of the EIP-2930 item cost. With EIP-8038's 2,900 / 2,000 that makes 4,180 per address and 4,048 per key | 2026-10-06 |
| EIP-7778 | block accounting `block.gas_used += max(tx_gas_used, calldata_floor)` with refunds not subtracted; users still receive refunds | 2026-10-22 (titles) |
| EIP-2780 | `TX_BASE_COST = 12,000`, `TX_VALUE_COST = 6,000`, plus 3,000 cold touch of `tx.to`. ETH transfer to existing EOA 21,000; **zero-value call to a contract 15,000 + execution**; self-transfer 12,000; transfer creating an account 21,000 + 183,600 state; create tx 24,000 + 183,600 state; 7702 authorisation 7,816 execution | 2026-10-22 (substantive 2026-10-16) |
| EIP-7708 | LOG3-equivalent from `0xfffffffffffffffffffffffffffffffffffffffe`, `topics[0] = 0xddf252ad…3b3ef`, for every non-zero value transfer (tx, CALL, SELFDESTRUCT, CREATE/CREATE2). No separate gas charge is specified for the log | 2026-10-22 (titles) |
| EIP-7954 | code size limit 24,576 → **65,536** bytes (`0x10000`); initcode limit 49,152 → **131,072** bytes (`0x20000`) | 2026-10-22 (titles) |
| EIP-7997 | `FACTORY_ADDRESS = 0x4e59b44847b379578588920cA78FbF26c0B4956C`; chain state MUST contain it with non-zero nonce and the stated runtime code; satisfied by an ordinary (keyless) deployment or by genesis inclusion; "Client software MUST NOT check for the existence of the contract at the fork boundary". **It is not a precompile and the address is not `0x12`.** ethereum.org still says "address 0x12" [S12], which contradicts the EIP | 2026-10-22 (description punctuation only) |
| EIP-7843 | `SLOTNUM` at `0x4b`, fixed gas 2, `uint64`; `engine_newPayloadV5`, `engine_getPayloadV6`, `engine_forkchoiceUpdatedV4` | 2026-10-22 (titles) |
| EIP-7825 | **Final**. 16,777,216 (2^24) per transaction; live since Fusaka | on or before 2026-09-01 |
| EIP-7732 ePBS | `PTC_SIZE = 512`; `BUILDER_PAYMENT_THRESHOLD` 6/10; `BUILDER_WITHDRAWAL_PREFIX = 0xB0`; `BUILDER_INDEX_FLAG = 2^40`; `MAX_PAYLOAD_ATTESTATIONS = 4`; request types `0x03` / `0x04`; `MAX_BUILDER_DEPOSIT_REQUESTS_PER_PAYLOAD = 64`; `MAX_BUILDER_EXIT_REQUESTS_PER_PAYLOAD = 16`; `MIN_BUILDER_WITHDRAWABILITY_DELAY = 64` epochs | 2026-10-22 (substantive 2026-10-20) |
| EIP-7928 BALs | header field `block_access_list_hash`; `bal_items ≤ block_gas_limit // ITEM_COST`, `ITEM_COST = 2000`; integer fields RLP-encoded minimally | 2026-10-27 |
| EIP-7904 (Informational) | "specifies **no changes** to the Ethereum gas schedule. No opcode or precompile gas cost is modified." BN254 ECADD 150 and pairing 45,000 + 34,000 per point are therefore unchanged | not checked |
| EIP-7773 meta | `status: Review` (the 8 Nov note said Draft); 18 SFI EIPs, same list as before | 2026-10-22 |

---

## 4. Hegotá

**EIP-8081 text today** [S9]: `status: Draft`, created 2025-11-11, latest commit `25b1952` 2026-10-20 22:17 UTC. Unchanged since 8 Nov. Activation table empty for Sepolia, Hoodi and Mainnet.

Lists exactly as printed in EIP-8081:
- **SFI (2):** 7805, 8141.
- **CFI (20):** 3298, 4758, 5920, 7668, 7709, 7906, 7979, 8015, 8077, 8116, 8131, 8151, 8163, 8198, 8250, 8253, 8272, 8279, 8298, 8360.
- **PFI (10):** 7907, 8142, 8148, 8173, 8205, 8365, 8368, 8369, 8372, 8383.
- **DFI (26):** 2488, 7645, 7666, 7716, 7807, 7819, 7851, 7862, 7923, 8025, 8094, 8115, 8146, 8182, 8188, 8200, 8219, 8237, 8243, 8304, 8321, 8333, 8355, 8363, 8371, 8379. (The 8 Nov note headed this "DFI (25)" but listed 26.)

**EIP-8081 lags the calls.** It was last synced to ACDC #189. The ACDC #190 decisions of 29 Oct are in the ACDbot summary [S7] and in Forkcast's data [S8] but not in the meta EIP. Actual stage sets per Forkcast (`generatedAt` 2026-11-09T13:14Z):
- **Scheduled (3):** 7805 (ACDC #175, 2026-02-19), 8141 (ACDE #244, 2026-08-27), **8015** (ACDC #190, 2026-10-29).
- **Considered (24):** 3298, 4758, 5920, 7668, 7709, 7906, 7979, 8077, 8116, 8131, **8148**, 8151, 8163, 8198, 8250, 8253, 8272, 8279, 8298, **8334**, 8360, **8365**, **8383**, **8411**. (Bold = not shown as CFI in EIP-8081.)
- **Proposed (5):** 7907, 8173, 8368, 8369, 8372.
- **Declined (35):** the 26 in EIP-8081 plus 8142, 8184, 8205, 8341, 8358, 8359, 8367, 8374, 8375.
- **Withdrawn (1):** 8105.

No stage change is dated after 29 Oct, so nothing moved between 8 Nov and 10 Nov.

| EIP | Document status | Hegotá stage | Latest commit (UTC) | Notes |
|---|---|---|---|---|
| 8141 Frame Transaction | Draft | **SFI** since ACDE #244, 27 Aug 2026 | 2026-11-01 11:20, "Transaction nonce check boundary" | `FRAME_TX_TYPE 0x06`, `FRAME_TX_INTRINSIC_COST 12000`, `FRAME_TX_PER_FRAME_COST 475`, `ENTRY_POINT address(0xaa)`, `MAX_FRAMES 64`, `EXPIRY_VERIFIER 0x81413f0cF12e9b6a49B1D0439E081c577D57FfFf`. Still moving: about ten PR heads from Oct–Nov differ from master for this file (open/closed state not checked one by one). A "legacy share" change was merged and reverted on 25 Oct (#12583, #12587); #12588 (open) re-proposes it |
| 8250 Keyed Nonces | Draft | **CFI** since ACDE #246, 24 Sep 2026 | 2026-10-19 16:09 | `NONCE_MANAGER 0x8250968C12e01A19d6F667b9B2F3b3A4d0e51cB7` (ordinary contract, keyless deployment, code `0x60006000fd`); `MAX_NONCE_KEYS 16`; first use 97,920 state gas; 12,100 execution gas per key; `FORK_TIMESTAMP` TBD |
| 7805 FOCIL | Draft | **SFI** since ACDC #175, 19 Feb 2026 | on or before 2026-09-01 | open rebase PR #12470 |
| 8151 restricted ecRecover | Draft | CFI since ACDE #247, 8 Oct 2026 | 2026-11-05 15:26 | in bogota-devnet-2 scope |
| 8272 Recent Roots | Draft | CFI since ACDE #246, 24 Sep 2026 | 2026-10-08 09:57 | |
| 8182 Private ETH/ERC-20 Transfers | Review | **DFI** since ACDE #245, 10 Sep 2026 | on or before 2026-09-01 | |
| 8105 Encrypted Mempool | Draft | **Withdrawn** from Hegotá (Forkcast, 2026-02-23); absent from EIP-8081 | on or before 2026-09-01 | |
| 7701 Native AA | **Withdrawn**, `withdrawal-reason: Superseded by EIP-8141` | none | on or before 2026-09-01 | |
| 8368 / 8372 (CPSB recalibration, normalized state gas limit) | Draft | PFI, held until at least 30 days of Glamsterdam mainnet data | | now blocked by the Glamsterdam pause |

**Planned date.** ethereum.org: "Expected on mainnet Q2 2027 · Date not yet confirmed", "Next milestone Sepolia fork, 2027", page last update 16 Oct 2026 [S12]. Forkcast: label "2027", `projectedActivation` 2027-06-16 (its own estimate) [S8]. EIP-8081: no dates. No source has revised the Hegotá date since the Glamsterdam pause. With Glamsterdam mainnet now expected in 2027 (ACDE #248), a Q2 2027 Hegotá mainnet looks optimistic; that is an inference.

**Devnets** [S7]: bogota-devnet-2 (EL only; EIP-8253, 4758, 8298, 8151) targeted the week of 27 Oct. The first merged EL+CL devnet, hegota-devnet-0, is targeted "post-DevCon". ACDC #190 proposed sequencing "FOCIL + PeerDAS first, add smaller EIPs next, merge quick slots later".

---

## 5. Prices

| Item | 9 Nov 2026, ~21:19 UTC | 10 Nov 2026, 00:13 UTC | Source |
|---|---|---|---|
| ETH/USD | 2,126.46 (Coinbase spot); 2,126.02 (Coinbase Exchange last); 2,127.54 (Gemini last); 2,126.15 (Chaingate); Chainlink on-chain 2,121.58, updated 20:33:23 UTC | **2,130.05** (Coinbase spot); 2,132.23 (CoinGecko, updated 00:12:06 UTC); 2,130.71 (Gemini); 2,132.81 (Chaingate) | S18 |
| Base fee, latest block | 0.1277 gwei at block 26,379,959 (21:14:59 UTC) | **0.0458 gwei** at block 26,380,849 (00:13:11 UTC) | S16 |
| `eth_gasPrice` | 0.1277 gwei | 0.0493 gwei | S16 |
| Base fee, 1-hour average | 0.140 gwei | 0.045 gwei | S17 |
| Base fee, 24-hour average | 0.207 gwei | 0.157 gwei | S17 |
| **Base fee, 7-day average** | 0.2028 gwei | **0.2033 gwei** | S17 |
| **Base fee, 30-day average** | 0.4176 gwei | **0.4179 gwei** | S17 |
| Block gas limit | 60,000,000 | 59,999,886 | S16 |

Independent check: `eth_feeHistory` over blocks 26,162,521–26,379,960 (217,440 contiguous blocks, ending 9 Nov 21:15 UTC) [S16]:
- last 50,400 blocks (about 7 days): mean base fee 0.2050 gwei, gas-weighted 0.2026, **median 0.058**, 90th percentile 0.280;
- last 216,000 blocks (about 30 days, starting 2026-10-10 19:00 UTC): mean 0.4216 gwei, gas-weighted 0.4164, **median 0.066**, 90th percentile 0.296;
- gas-weighted base fee plus median priority fee (a proxy for average gas price paid): 0.277 gwei over 7 days, 0.488 gwei over 30 days.

The 30-day mean is dominated by one event: a spike on 29 Oct 2026 peaking at 252.75 gwei (block 26,301,016), which gives that 7,200-block bucket a mean of 8.5 gwei. Every other daily bucket in the window is between 0.04 and 0.60 gwei. For a cost model, the median (about 0.06 gwei) describes a typical block; the mean (about 0.42 gwei) describes expected spend if transactions cannot be delayed.

Gas limit: 60,000,000 in 9 of 12 sampled blocks from 10 Oct to 9 Nov; lowest sampled 59,941,351 on 2 Nov [S16].

USD per 1,000,000 gas at $2,130: $0.098 at 0.046 gwei; $0.432 at 0.203 gwei; $0.890 at 0.418 gwei.

---

## 6. Gas arithmetic, today (Fusaka/Osaka rules) versus Glamsterdam (current EIP-8037/8038/2780 text)

Constants used. Today: cold slot 2,100; `SSTORE_SET` 20,000; `SSTORE_RESET` 2,900 (+2,100 cold = 5,000); cold account 2,600; `CALL_VALUE` 9,000 with 2,300 stipend; `GAS_NEW_ACCOUNT` 25,000; `GAS_CREATE` 32,000; code deposit 200/byte; initcode 2 gas per word; calldata 4 / 16 per zero / non-zero byte. Glamsterdam: section 2 and 3 values.

### (a) One fresh storage slot write (0 → non-zero)

| | Cold slot | Warm slot |
|---|---|---|
| Today | 2,100 + 20,000 = **22,100** | 20,000 |
| Glamsterdam | 2,100 + 10,000 execution + 64 × 1,530 = 97,920 state = **110,020** | 100 + 10,000 + 97,920 = 108,020 |
| Ratio | 4.98x | 5.40x |

Of the 110,020, only 12,100 is execution gas. USD per cold fresh slot at $2,130: today $0.0022 / $0.0096 / $0.0197 at 0.046 / 0.203 / 0.418 gwei; Glamsterdam $0.0108 / $0.0476 / $0.0980.

### (b) One overwrite of a non-zero slot (x → y)

| | Cold | Warm |
|---|---|---|
| Today | 2,100 + 2,900 = **5,000** | 2,900 |
| Glamsterdam | 2,100 + 10,000 = **12,100** | 100 + 10,000 = 10,100 |
| Ratio | 2.42x | 3.48x |

No state gas. Clearing a non-zero slot costs the same 12,100 and earns an 11,616 refund, subject to the 20% cap.

### (c) Deploying 24 KiB and 64 KiB of runtime code

Creation transaction, new address, initcode assumed equal in size to the runtime code, calldata priced at the 16 gas/byte worst case, constructor execution excluded.

**24 KiB = 24,576 bytes (768 words)**

| Component | Today | Glamsterdam |
|---|---|---|
| Transaction base | 21,000 | `TX_BASE_COST` 12,000 |
| Creation | `GAS_CREATE` 32,000 | `CREATE_ACCESS` 12,000 execution + new account 120 × 1,530 = 183,600 state |
| Initcode calldata, 16 × 24,576 | 393,216 | 393,216 |
| Initcode word cost, 2 × 768 | 1,536 | 1,536 |
| Code hash cost, 6 × 768 | (inside deposit) | 4,608 |
| Code deposit | 200 × 24,576 = 4,915,200 | 1,530 × 24,576 = 37,601,280 state |
| **Total** | **5,362,952** | **38,208,240** = 423,360 execution + 37,784,880 state |

Ratio 7.12x. Deposit-plus-creation alone: 4,947,200 → 37,784,880 state + 16,608 execution, matching EIP-8037's own table. With all-zero calldata (4 gas/byte) the totals are 5,068,040 and 37,913,328. USD at $2,130: today $0.53 / $2.32 / $4.77; Glamsterdam $3.74 / $16.52 / $34.02 at 0.046 / 0.203 / 0.418 gwei.

**64 KiB = 65,536 bytes (2,048 words)**

| Component | Today | Glamsterdam |
|---|---|---|
| Allowed? | **No.** EIP-170 caps code at 24,576 bytes | Yes (EIP-7954) |
| Transaction base + creation | | 12,000 + 12,000 execution + 183,600 state |
| Initcode calldata, 16 × 65,536 | | 1,048,576 |
| Initcode word cost, 2 × 2,048 | | 4,096 |
| Code hash cost, 6 × 2,048 | | 12,288 |
| Code deposit, 1,530 × 65,536 | (13,107,200 at 200/byte, hypothetical) | 100,270,080 state |
| **Total** | not deployable | **101,542,640** = 1,088,960 execution + 100,453,680 state |

USD at $2,130: $9.95 / $43.91 / $90.41 at 0.046 / 0.203 / 0.418 gwei.

Three consequences:
1. Both deployments need `tx.gas` above 2^24, so the state gas comes from the reservoir. This is the case the reservoir exists for.
2. Inclusion requires `tx.gas ≤ block_gas_limit − block_state_gas_used`. At a 60M block gas limit the 24 KiB deployment (38.2M) fits only in a block with under about 21.8M of state gas already used, and **the 64 KiB deployment (101.5M) cannot be included at all**. It needs a block gas limit above about 101.5M, hence the planned 200M step.
3. The calldata floor (64 gas/byte: 1,572,864 and 4,194,304) does not raise what the sender pays here, because the transaction total far exceeds it.

Deploying from inside a contract (`CREATE`/`CREATE2`) costs the same state gas. If the outer `tx.gas` is at most 2^24, all of it comes from `gas_left`, which limits code size to roughly 7.5 kB (EIP-8037's own estimate with a 5M constructor budget).

### (d) Groth16 withdrawal

Line items:
- Proof verification: 210,000 + 7 × 7,200 = **260,400**, taken as given and unchanged in Glamsterdam (EIP-7904 confirms no precompile repricing). Under Glamsterdam add 400 for the cold call to a separate verifier contract (2,600 → 3,000).
- Calldata: 4-byte selector + 256-byte proof + 7 × 32-byte inputs = 484 bytes, priced at the 16 gas/byte upper bound = 7,744. Unchanged. The floor (today 21,000 + 10 × 1,936 = 40,360; Glamsterdam 64 × 484 = 30,976 plus base) does not bind.
- Transaction base: today 21,000. Glamsterdam 15,000 (EIP-2780, zero-value call to a contract).
- Fresh nullifier slot, cold: 22,100 → 110,020.
- Root overwrite, cold: 5,000 → 12,100.
- Transfer out, four variants:

| Transfer | Today | Glamsterdam |
|---|---|---|
| ETH to an existing account | 2,600 + 9,000 − 2,300 stipend returned = 9,300 | 3,000 + 11,300 − 2,300 = 12,000 |
| ETH to a fresh (empty) account | 9,300 + 25,000 = 34,300 | 12,000 + 183,600 state = 195,600 |
| ERC-20, recipient already holds the token | 2,600 + 5,000 + 5,000 + LOG3 1,756 + 2,000 token logic = 16,356 | 3,000 + 12,100 + 12,100 + 1,756 + 2,000 = 30,956 |
| ERC-20, first-time holder | 2,600 + 5,000 + 22,100 + 1,756 + 2,000 = 33,456 | 3,000 + 12,100 + 110,020 + 1,756 + 2,000 = 128,876 |

LOG3 with 32 data bytes = 375 + 3 × 375 + 8 × 32 = 1,756. The 2,000 for token-internal logic is an assumption, identical on both sides. Pool-internal logic outside these items (dispatch, memory, hashing, events) is excluded on both sides.

Common part: today 21,000 + 7,744 + 260,400 + 22,100 + 5,000 = 316,244. Glamsterdam 15,000 + 7,744 + 260,800 + 12,100 + 12,100 = 307,744 execution, plus 97,920 state.

| Scenario | Today | Glamsterdam (execution + state) | Ratio | USD at 0.203 gwei, today → Glamsterdam |
|---|---|---|---|---|
| ETH to existing account | **325,544** | 319,744 + 97,920 = **417,664** | 1.28x | $0.141 → $0.181 |
| ETH to fresh account | 350,544 | 319,744 + 281,520 = **601,264** | 1.72x | $0.152 → $0.260 |
| ERC-20, existing holder | 332,600 | 338,700 + 97,920 = **436,620** | 1.31x | $0.144 → $0.189 |
| ERC-20, first-time holder | 349,700 | 338,700 + 195,840 = **534,540** | 1.53x | $0.151 → $0.231 |

At the current 0.046 gwei the first row is $0.032 → $0.041; at the 30-day mean of 0.418 gwei it is $0.290 → $0.372.

What this shows:
- The verifier dominates and is not repriced, so the baseline withdrawal rises only about 28%. Execution gas actually falls slightly (the 6,000 saved on the transaction base offsets the dearer root write); the increase is the 97,920 of state gas for the nullifier.
- The exposure is in the recipient. A privacy withdrawal normally pays out to a fresh address, which turns a 25,000 charge into 183,600 of state gas and takes the total to about 601k. Every further fresh slot (a commitment insert, a first-time token balance) adds 110,020.
- A single withdrawal is far below 2^24, so there is no reservoir. All state gas comes out of `gas_left`, which is the INV-4 / INV-7 situation: any fixed gas limit, relayer gas estimate or `gasleft()` reserve sized for today's 325k–350k is too small.
- Batching: about 305k execution gas per withdrawal gives about 55 withdrawals per transaction under the 2^24 execution cap, the same as today. Under Glamsterdam the batch's state gas (97,920 or more per withdrawal) can ride in the reservoir if `tx.gas` is set above 2^24, so the batch size is preserved, and the batch `tx.gas` must fit the block's state-gas headroom.
- If PR #12581 (legacy share) were adopted, these totals would not change; 10,000 of each fresh slot's state gas and 25,000 of each new account's would be taken from `gas_left` even when a reservoir exists.

---

## 7. Changed between 8 Nov and 9–10 Nov 2026

| Item | 8 Nov value | 9–10 Nov value | Source | Date |
|---|---|---|---|---|
| ETH/USD | 2,225.29 | 2,126.46 (9 Nov 21:19 UTC); 2,130.05 (10 Nov 00:13 UTC), about −4.3% | S18 | 9 and 10 Nov |
| Base fee, spot | 0.058–0.068 gwei | 0.128 gwei (9 Nov 21:15); 0.046 gwei (10 Nov 00:13) | S16 | 9 and 10 Nov |
| 30-day average base fee | ~0.37 gwei (secondary article) | 0.418 gwei (ultrasound.money; own computation 0.416–0.422) | S17, S16 | 10 Nov |
| 7-day average base fee | not found | 0.203 gwei (median 0.058) | S17, S16 | 10 Nov |
| Block gas limit | 59,882,873 (gaslimit.pics, 6 Oct) | 60,000,000 (59,999,886 at 10 Nov 00:13) | S16 | 9 and 10 Nov |
| EIPs repo: new PRs touching the repricing | none recorded | #12638 "Versioned Opcodes for Gas Repricing" (opened 8 Nov, updated 9 Nov); #12639 EIP-7976 parameter rename (9 Nov). Both open, neither changes a value | S3, S4 | 9 Nov |
| Forkcast plan artifacts | n/a | regenerated 9 Nov 13:13 UTC for ACDE #249 / ACDC #191; no stage change | S8 | 9 Nov |
| EIP-8037, EIP-8038 text | CPSB 1530 etc. | **unchanged** (last commits 6 Oct and 22 Oct) | S1, S2, S3 | 10 Nov |
| Glamsterdam schedule | paused, no dates | **unchanged**; no call held, no new EF post | S5, S7, S8 | 10 Nov |
| EIP-8081 lists; EIP-8141 / 8250 status | SFI 7805, 8141; 8250 CFI | **unchanged** (file last changed 20 Oct; last stage change 29 Oct) | S9, S8 | 10 Nov |

### Corrections and additions to the 8 Nov note (true before 8 Nov, found in this pass)

| Item | 8 Nov note | Verified | Source |
|---|---|---|---|
| Hegotá SFI set | 2 (7805, 8141) | 3: EIP-8015 was SFI'd at ACDC #190 on 29 Oct. EIP-8081 has not been updated | S7, S8 |
| Hegotá CFI / DFI | per EIP-8081 | CFI also 8148, 8334, 8383, 8411 (29 Oct) and 8365 (1 Oct); DFI also 8205 (29 Oct), 8142 (21 Sep) and seven more that EIP-8081 does not list | S7, S8 |
| EIP-8081 DFI count | "25" | 26 entries | S9 |
| EIP-8105 | "Not in EIP-7773 or EIP-8081" | Forkcast records it as Withdrawn from Hegotá on 2026-02-23 | S8 |
| EIP-7773 document status | Draft | Review (since before 1 Sep 2026) | S9, S3 |
| EIP-7773 Hoodi row | cited as the schedule | still printed, but stale; the removal PR #12568 is unmerged | S9, S3 |
| The eight invariants | "not fetched" | enumerated in section 1 | S6 |
| Spec-change proposals | "unknown" | open PRs #12581 and #12582, plus two EELS branches of 3 Nov; none merged; none changes a price | S3, S4, S14 |
| Mainnet timing | "Q1 2027 or later (inference)" | ACDE #248 summary: "December 2026 fork now very unlikely; 2027 expected" | S7 |
| Next decision points | not given | ACDC #191 on 12 Nov; ACDE #249 on 19 Nov (moved from 5 Nov) | S7, S11 |
| State gas and the 2^24 cap | "not subject to the 2^24 cap" | true only for the part of `tx.gas` above 2^24; below that, state gas is paid from the same budget | S1, S6 |
| Code deposit | 1,530 per byte | plus 6 execution gas per 32-byte word | S1 |
| EIP-7997 address | conflict flagged | EIP text is unambiguous: `0x4e59…956C`, an ordinary contract. ethereum.org's "0x12" is wrong or outdated | S10, S12 |
| EIP-2780 effect on a contract call | not drawn out | zero-value transaction to a contract has a 15,000 base instead of 21,000 | S10 |
| 64 KiB deployment | "payable because state gas is not subject to the cap" | also needs a block gas limit above about 101.5M; impossible at 60M | S1 |

---

## 8. Could not verify

- **Whether ACDT #103 took place on 9 Nov 2026, and what was said.** ACDT #102 announced it for that date; no pm issue, Magicians topic or Forkcast artifact exists as of 2026-11-10 00:13 UTC.
- **Audit results from ChainSecurity and Dedaub** (ETA "~2 weeks from October 26th"). Nothing published; web search found no Dedaub output.
- **Christine Kim, Tim Beiko and Ethereal news coverage after 6 Nov.** Not fetched directly. The Magicians ACD threads link to them but carry no post-6-Nov content, and web search returned nothing newer than 6 Nov.
- **A new Hoodi date or mainnet target.** None exists in any primary source. Forkcast's 2026-12-02 and 2027-06-16 are its own planning estimates.
- **Whether EIP-8037/8038 will ship unchanged.** Open; PRs #12581 and #12582 are neither merged nor closed. Draft/open state was read from GitHub's HTML through a summarising fetch tool, not the API.
- **Etherscan gas tracker and average-gas-price chart** (HTTP 403). The 7-day and 30-day figures are base-fee averages from ultrasound.money and from `eth_feeHistory`; an Etherscan-style "average gas price" over all transactions was approximated only as base fee plus median tip.
- **Groth16 verification cost.** The "210k + 7.2k per public input" formula was taken as given, not measured. The 2,000 gas for ERC-20 internal logic and the all-non-zero calldata assumption are modelling choices.
- **Constructor execution and real initcode size** for the deployment figures (excluded; initcode assumed equal to runtime size).
- **Client release versions that implement the current Amsterdam rules.** Not checked.
- **The rendered Forkcast pages** (client-rendered); the JSON API was used instead.
- **Per-file commit dates before 2026-09-01.** The clone was shallow, so "on or before 2026-09-01" is an upper bound for EIP-7825, 7805, 8182, 8105 and 7701.
