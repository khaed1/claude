# Gas model and post-quantum ciphertext cost, v3

Prepared 10 Nov 2026. All web sources fetched 2026-11-10 between 14:44 and 14:56 UTC unless a row says otherwise. Read-only work: EIP texts, public JSON APIs, and read-only `eth_call` / `eth_getCode` / `eth_createAccessList` against public mainnet RPC endpoints. Nothing was sent on-chain and nobody was contacted.

**Regimes compared**

- **Today**: Fusaka/Osaka rules, live on mainnet.
- **Glamsterdam**: EIP-8037 + EIP-8038 + EIP-7976 as the texts stand today. Transaction base held at 21,000, as the task specified.
- **Glamsterdam, full set**: the same plus EIP-2780, which is scheduled for the same fork and which EIP-8037 formally requires. It changes the base of a zero-value call to a contract from 21,000 to 15,000. Shown as a "−6,000" line wherever it applies.

**Headline**

1. Every parameter in the earlier note (`ethereum_roadmap_v2.md`, sections 2 and 6) is confirmed unchanged. The EIP-8037 and EIP-8038 files are byte-identical to the versions that note recorded (same git blob hashes).
2. Glamsterdam is not live on mainnet and has no mainnet date. The fork process is paused over EIP-8037/8038, with audit reports due 13 Nov and a discussion on 19 Nov. The numbers below can still change.
3. One correction to the earlier note: its Groth16 line (210,000 + 7,200 per input) already contained the 21,000 base and the proof calldata, which the note then added again. Measured verifier execution is about 182,441 + 6,626 per public input. See section 2.g.
4. X-Wing's ciphertext is 1,120 bytes. 1,216 bytes is its public (encapsulation) key size. See section 2.h.

---

## Sources

| ID | Source | Fetched (UTC) |
|---|---|---|
| E1 | https://eips.ethereum.org/EIPS/eip-8037 and https://raw.githubusercontent.com/ethereum/EIPs/master/EIPS/eip-8037.md (git blob `c8bc85b0bf86`) | 14:44 |
| E2 | https://eips.ethereum.org/EIPS/eip-8038 and raw (git blob `a1c73c4f5bff`) | 14:44 |
| E3 | https://eips.ethereum.org/EIPS/eip-7976 and raw | 14:44 |
| E4 | https://eips.ethereum.org/EIPS/eip-7623 and raw | 14:44 |
| E5 | https://eips.ethereum.org/EIPS/eip-7825 and raw | 14:44 |
| E6 | https://eips.ethereum.org/EIPS/eip-7981 and raw | 14:44 |
| E7 | https://eips.ethereum.org/EIPS/eip-2780 and raw | 14:44 |
| E8 | https://eips.ethereum.org/EIPS/eip-7904 and raw | 14:44 |
| E9 | https://eips.ethereum.org/EIPS/eip-7773 (Glamsterdam meta), eip-8081 (Hegotá meta), eip-7954, eip-7935, eip-8261, eip-5988, eip-1108, eip-8131, eip-8311, eip-8368, eip-8372 (raw files) | 14:44–14:50 |
| E10 | https://eips.ethereum.org/all (full index, searched for "Poseidon") | 14:55 |
| F1 | Forkcast JSON: https://forkcast.org/api/eips.json (`generatedAt` 2026-11-10T06:22:13Z), /api/eips/{id}.json, /api/upgrades.json, /api/eip-stage-changes.json, /llms.txt | 14:45 |
| X1 | execution-specs: https://raw.githubusercontent.com/ethereum/execution-specs/mainnet/src/ethereum/forks/osaka/vm/gas.py and `.../precompiled_contracts/alt_bn128.py`; https://raw.githubusercontent.com/ethereum/execution-specs/forks/amsterdam/src/ethereum/forks/amsterdam/vm/gas.py and `.../amsterdam/transactions.py` | 14:52 |
| B1 | https://blog.ethereum.org/en/feed.xml and https://blog.ethereum.org/en/2026/11/06/glamsterdam-8037-8038 | 14:54 |
| R1 | Mainnet JSON-RPC, read-only: https://ethereum-rpc.publicnode.com and https://eth.drpc.org (blocks 26,385,194 to 26,385,223) | 14:45–14:51 |
| P1 | https://raw.githubusercontent.com/chancehudson/poseidon-solidity/main/README.md (identical file under vimwitch/), `test/poseidon.test.js`, `contracts/Test.sol`, `hardhat.config.js`, `package.json` (v0.0.5) | 14:46 |
| P2 | https://ethereum-magicians.org/t/is-there-appetite-for-a-cheaper-on-chain-ao-hash-ashlar-14-232-gas-vs-poseidons-18-229/29315 (post dated 6 Aug 2026; read through a summarising fetch tool) | 14:47 |
| P3 | https://raw.githubusercontent.com/zemse/poseidon2-evm/main/README.md | 14:48 |
| P4 | https://raw.githubusercontent.com/Railgun-Privacy/contract/main/contracts/logic/Poseidon.sol and `package.json` | 14:48 |
| G1 | https://hackmd.io/@nebra-one/ByoMB8Zf6 and https://hackmd.io/@Orbiter-Research/S1nat__m0 (both undated; read through a summarising fetch tool) | 14:53 |
| K1 | FIPS 203, https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.203.pdf (published 13 Aug 2024), text extracted locally | 14:52 |
| K2 | https://www.ietf.org/archive/id/draft-connolly-cfrg-xwing-kem-11.txt ; https://datatracker.ietf.org/doc/draft-connolly-cfrg-xwing-kem/ and `/doc.json` | 14:52 |
| K3 | IANA HPKE KEM Identifiers: https://www.iana.org/assignments/hpke/hpke-kem-ids.csv ; registry `hpke.xml` last updated 2026-04-16 | 14:52 |

---

## Part 1. Parameters

### 1.a EIP-8037, State Creation Gas Cost Increase [E1]

**Status.** `status: Last Call`, `last-call-deadline: 2026-11-01` (passed, not moved to Final). `requires: 161, 684, 2780, 6780, 7623, 7702, 7825, 7928, 7976, 8038`. Forkcast: Glamsterdam, "Scheduled" since ACDE #236 on 2026-05-07 [F1]. File unchanged against the earlier note.

**State gas amounts.** Quoted parameter table:

| Parameter | Value |
|---|---|
| `CPSB` | 1530 |
| `STATE_BYTES_PER_STORAGE_SET` | 64 |
| `STATE_BYTES_PER_NEW_ACCOUNT` | 120 |
| `STATE_BYTES_PER_AUTH_BASE` | 23 |
| `TX_MAX_TOTAL_GAS_LIMIT` | 4,294,967,295 (2^32 - 1) |

- New storage slot: 64 × 1,530 = **97,920** state gas. EIP row: "`GAS_STORAGE_SET` | 20,000 | `STATE_BYTES_PER_STORAGE_SET x CPSB` | 0 | `SSTORE`".
- New account: 120 × 1,530 = **183,600** state gas.
- Code: **1,530** state gas per byte, plus hashing in execution gas. EIP row: "`GAS_CODE_DEPOSIT` | 200/byte | `CPSB` per byte | `6 × ceil(len/32)` (hash cost)".
- Contract creation: "`GAS_CREATE` | 32,000 | `STATE_BYTES_PER_NEW_ACCOUNT x CPSB` | `CREATE_ACCESS`" (`CREATE_ACCESS` = 12,000 execution gas, from EIP-8038).
- The EIP's own impact table: new account 25,000 → 183,600; new slot 20,000 → 97,920; 24 kB deployment 4,947,200 → 37,784,880.
- The execution-specs Amsterdam fork carries the same constants (`COST_PER_STATE_BYTE = 1530`, 120, 64, 23) [X1].

**How state gas is metered.**

- "Two gas dimensions are introduced, execution-gas and state-gas. For state creation operations, the "new state costs" are charged to state-gas, while the "new execution costs" are charged to execution-gas. The costs of all other operations are charged to execution-gas."
- "At transaction level, the user pays for both execution-gas and state-gas. The total gas cost of a transaction is the sum of both dimensions."
- Block level: `gas_used = max(block_output.block_execution_gas_used, block_output.block_state_gas_used)`. The base fee updates on that value.
- A slot set and cleared again in the same transaction gets its state gas back ("refilled"). A reverted frame restores its state gas.

**Interaction with the 16,777,216 cap. Is the cap on execution gas only?** Yes, with a condition.

- "the transaction gas limit set in EIP-7825 only applies to execution-gas, while state-gas is capped by `tx.gas`, which this proposal in turn caps at `TX_MAX_TOTAL_GAS_LIMIT`."
- The reservoir, quoted:

```python
evm_gas = tx.gas - intrinsic_gas
execution_gas_budget = TX_MAX_GAS_LIMIT - intrinsic_gas
gas_left = min(execution_gas_budget, evm_gas)
state_gas_reservoir = evm_gas - gas_left
```

- "This means that the `state_gas_reservoir` holds gas that exceeds EIP-7825's budget."
- "State-gas charges deduct from `state_gas_reservoir` first. When the reservoir is exhausted, the remainder deducts from `gas_left`".
- "`state_gas_reservoir` is passed to a child frame in full: the 63/64 rule applies to `gas_left` only."
- "The `GAS` opcode returns `gas_left` only (excluding the reservoir)."

What this means in practice:

- **`tx.gas` ≤ 16,777,216:** the reservoir is zero. State gas is paid out of the same 16.78M budget as execution. The EIP says a negative `GAS` delta is possible "for every transaction with `tx.gas` up to `TX_MAX_GAS_LIMIT`".
- **`tx.gas` > 16,777,216:** the excess is a reservoir only state gas can spend. Execution is still limited to 16,777,216 minus intrinsic gas.
- **Validity:** "`tx.gas <= TX_MAX_TOTAL_GAS_LIMIT`" and "`max(intrinsic_gas, calldata_floor_gas_cost) <= TX_MAX_GAS_LIMIT`".
- **Inclusion:** "`min(TX_MAX_GAS_LIMIT, tx.gas) <= execution_gas_available` and `tx.gas <= state_gas_available`", where each "available" is the block gas limit minus what the block has used in that dimension. So the whole `tx.gas` must fit under the block gas limit in the state dimension, and a transaction with `tx.gas` above 2^24 needs a full 16,777,216 of unused execution gas in the block.

**Today, for comparison** [E5]: EIP-7825 is `Final`. "Enforce a protocol-level maximum of **16,777,216 gas (2^24)** for any single transaction." Today the cap is on `tx.gas` as a whole.

**Live risk to these numbers** [B1, F1]. The EF post of 6 Nov is still the newest. Read through a summarising tool, it says: "ACD has decided to delay the hardfork process and not fork Hoodi until the issues are resolved"; "If the findings show that the impact on deployed contracts is too widespread to accept, ACD could revise the specifications"; "Work is already underway to prototype and review several possible revisions." Dates it gives: audit reports 13 Nov, ACDT presentation 16 Nov, ACDE discussion 19 Nov. EIP-7773 still shows Sepolia live since 2026-10-06 and an empty mainnet row. Forkcast shows Glamsterdam "Upcoming" with `projectedActivation` 2026-12-02, which Forkcast documents as its own estimate and which predates the pause. Two Hegotá proposals would later change `CPSB` (EIP-8368, EIP-8372; both Draft, value "TBD", "Proposed for Inclusion").

### 1.b EIP-8038, State-Access Gas Cost Update [E2]

**Status.** `status: Last Call`, deadline 2026-11-01, `requires: 8037`. Forkcast: Glamsterdam, "Scheduled" (dated 2026-08-04). File unchanged against the earlier note.

| Parameter | Current | New | Used by |
|---|---|---|---|
| `COLD_ACCOUNT_ACCESS` | 2,600 | **3,000** | cold `*CALL`, `BALANCE`, `EXT*` |
| `COLD_STORAGE_ACCESS` | 2,100 | **2,100** | cold `SLOAD` / `SSTORE` |
| `WARM_ACCESS` | 100 | 100 | warm touches |
| `ACCOUNT_WRITE` | 6,700 | **9,000** | value-bearing `CALL`, creations |
| `STORAGE_WRITE` | 2,800 | **10,000** | `SSTORE` that changes a slot |
| `CREATE_ACCESS` | 7,000 | **12,000** | `CREATE`, `CREATE2`, creation transactions |
| `STORAGE_CLEAR_REFUND` | 4,800 | **11,616** | `SSTORE` x → 0 |
| `ACCESS_LIST_STORAGE_KEY_COST` | 1,900 | 2,000 | access lists |
| `ACCESS_LIST_ADDRESS_COST` | 2,400 | 2,900 | access lists |

SSTORE, quoted: "1. Access component: `COLD_STORAGE_ACCESS` or `WARM_ACCESS` ... 2. Write component: additionally charge `STORAGE_WRITE` if the new value is different from the current value and the current value equals the original value ... 3. State-creation component: additionally charge `GAS_STORAGE_SET` (per EIP-8037, metered in state-gas) if the original value is zero, the current value is zero, and the new value is non-zero."

Resulting prices:

| Operation | Today | Glamsterdam |
|---|---|---|
| SSTORE 0 → non-zero, cold | 2,100 + 20,000 = 22,100 | 2,100 + 10,000 execution + 97,920 state = 110,020 |
| SSTORE 0 → non-zero, warm | 20,000 | 100 + 10,000 + 97,920 = 108,020 |
| SSTORE x → y, cold | 5,000 | 2,100 + 10,000 = 12,100 |
| SSTORE x → y, warm | 2,900 | 100 + 10,000 = 10,100 |
| SSTORE x → 0, cold | 5,000, refund 4,800 | 12,100, refund 11,616 |
| SLOAD cold / warm | 2,100 / 100 | 2,100 / 100 |
| Cold account access | 2,600 | 3,000 |
| `CALL` with value, existing recipient | 9,000 (2,300 passed on as stipend) | 11,300 (stipend unchanged) |
| `CALL` with value, new recipient | + 25,000 | + 183,600 state |

- `CALL_VALUE` "is redefined as `ACCOUNT_WRITE + CALL_STIPEND`, where `CALL_STIPEND` (`G_callstipend`, 2,300) is unchanged."
- Refunds: "These refunds go to the transaction's refund counter and are capped to 20% of the total gas used by the transaction". `STORAGE_WRITE` is refunded when a slot is restored to its transaction-start value.
- "`EXTCODESIZE` and `EXTCODECOPY` are charged an additional `WARM_ACCESS`."

**EIP-2780** [E7], same fork, `Last Call`: `TX_BASE_COST` 12,000, `TX_VALUE_COST` 6,000, plus 3,000 for the recipient. Reference cases quoted from its table: "No-transfer to contract ... 15,000 + execution", "ETH transfer to contract ... 21,000 + execution", "Create transaction ... 24,000 / 183,600".

### 1.c Calldata: EIP-7623 (live) and EIP-7976 (proposed)

**EIP-7623** [E4], `status: Final`, live since Pectra. Standard cost 4 gas per token, floor 10 gas per token, where "`tokens_in_calldata = zero_bytes_in_calldata + nonzero_bytes_in_calldata * 4`". Formula, quoted:

```python
tx.gasUsed = (
    21000
    +
    max(
        STANDARD_TOKEN_COST * tokens_in_calldata
        + execution_gas_used
        + isContractCreation * (32000 + INITCODE_WORD_COST * words(calldata)),
        TOTAL_COST_FLOOR_PER_TOKEN * tokens_in_calldata
    )
)
```

Confirmed: it is a `max` of the standard path and the floor. Per byte, standard is 4 (zero) / 16 (non-zero) and floor is 10 / 40. The floor binds only when execution gas is below 6 × tokens, which is 24 gas per non-zero calldata byte and 6 per zero byte. The EIP: "The calldata cost for transactions involving significant EVM computation remains at 4/16 gas per byte". The gas limit must still reserve the floor: a transaction "with a gas limit below `21000 + TOTAL_COST_FLOOR_PER_TOKEN * tokens_in_calldata` ... is considered invalid."

**EIP-7976** [E3], `status: Last Call`, deadline 2026-11-01. Forkcast: Glamsterdam, "Scheduled" since ACDE #236. "`TOTAL_COST_FLOOR_PER_TOKEN` | `16`", and "`floor_tokens_in_calldata = (zero_bytes_in_calldata + nonzero_bytes_in_calldata) * 4`". "Equivalently, the floor cost is `64` gas per calldata byte (both zero and non-zero)". The standard path is untouched:

```python
tx.gasUsed = 21000 + max(
    4 * tokens_in_calldata + execution_gas_used + isContractCreation * (...),
    16 * floor_tokens_in_calldata          # = 64 * calldata_bytes
)
```

Under EIP-7976 the floor binds when execution gas is below 48 per non-zero byte plus 60 per zero byte.

Interactions inside Glamsterdam:

- With EIP-2780 the 21,000 in the floor becomes the transaction's own base (15,000 for a zero-value call to a contract). The Amsterdam spec code computes `data_floor_gas_cost = base_execution_gas + floor_tokens_in_calldata * TX_DATA_TOKEN_FLOOR + access_list_data_cost` [X1].
- With EIP-8037 the sender pays `max(tx_gas_used_after_refund, calldata_floor_gas_cost)`, where the first term includes state gas. Block accounting compares the floor against execution gas only [E1].
- EIP-7981 [E6], `Last Call`, scheduled: access lists pay an extra 64 gas per byte, 1,280 per address and 2,048 per storage key.
- Later proposals, not in Glamsterdam: EIP-8311 (Draft, no fork) would raise the floor to 96 per byte; EIP-8131 (Draft, Hegotá "Considered") keeps 64 and extends it to more fields.

### 1.d LOG and BN254 precompile prices

| Item | Today [X1, Osaka] | Glamsterdam [X1, Amsterdam] |
|---|---|---|
| LOG base | `GAS_LOG = 375` | `OPCODE_LOG_BASE = 375` |
| LOG per topic | `GAS_LOG_TOPIC = 375` | `OPCODE_LOG_TOPIC = 375` |
| LOG per data byte | `GAS_LOG_DATA = 8` | `OPCODE_LOG_DATA_PER_BYTE = 8` |
| ecAdd (0x06) | 150 | `PRECOMPILE_ECADD = 150` |
| ecMul (0x07) | 6,000 | `PRECOMPILE_ECMUL = 6000` |
| Pairing (0x08) | 34,000 × k + 45,000 | base 45,000, per point 34,000 |

- EIP-1108 (`Final`) sets the BN254 prices: "`ECADD` ... 150", "`ECMUL` ... 6 000", "Pairing check ... 34 000 * k + 45 000" [E9].
- EIP-7904 [E8] is now `Informational`, `Last Call`: "This EIP specifies **no changes** to the Ethereum gas schedule. No opcode or precompile gas cost is modified." Its table measures ecAdd at 108 and pairing at 8,247 + 11,712 per point against a 100 Mgas/s target, all below current prices, and proposes no change.
- None of the 18 EIPs scheduled in EIP-7773 reprices LOG, arithmetic opcodes or precompiles. EIP-7708 adds a protocol log for ETH transfers with no separate charge.
- Not checked: memory expansion and copy costs, which also apply when emitting a log. They are in the same unchanged compute schedule.

### 1.e Poseidon precompile

- EIP-5988 "Add Poseidon hash function precompile": `status: Stagnant` [E9]. Forkcast lists no fork relationship for it [F1].
- It is the only EIP with "Poseidon" in its title in the full index [E10].
- Not in Glamsterdam (EIP-7773) and not in any Hegotá list (EIP-8081: scheduled, considered, proposed or declined) [E9].
- Plan on Poseidon staying pure EVM code.

---

## Part 2. Measured building blocks

### 2.f Poseidon on-chain (BN254, circomlib-compatible)

**Published figures** [P1], poseidon-solidity README, package v0.0.5, "**This implementation has not been audited.**":

| Width | poseidon-solidity | circomlibjs | Canonical address |
|---|---|---|---|
| T2 (1 input) | 13,488 | 19,395 | `0x22233340039aAB0C858bc6086f508d9A4f2fA4db` |
| T3 (2 inputs) | 21,124 | 32,173 | `0x3333333C0A88F9BE4fd23ed0536F9B6c427e3B93` |
| T4 (3 inputs) | 37,617 | 48,267 | `0x4443338EF595F44e0121df4C21102677B142ECF0` |
| T5 (4 inputs) | 54,326 | 73,307 | `0x555333f3f677Ca3930Bf7c56ffc75144c51D9767` |
| T6 (5 inputs) | 74,039 | 100,197 | `0x666333F371685334CdD69bdDdaFBABc87CE7c7Db` |

"Deploy cost (T3) - poseidon-solidity: 5,129,638 gas - circomlibjs: 2,156,516 gas".

What the README figure is: the repository's `contracts/Test.sol` takes `gasleft()` before and after one external call from a Solidity contract, and each test deploys a fresh hasher. So each figure is **one cold call**, including the 2,600 cold account access and about 450 to 550 gas of caller-side encoding. Build settings: solc 0.7.6, optimizer runs 2^32 − 1.

**My measurements on mainnet** [R1]. Method: `eth_call` with a state override that places a 60-byte harness at an unused address; the harness calls the hasher three times and returns the `GAS` deltas. Cross-checked with `eth_createAccessList.gasUsed` for a direct call. Two RPC providers gave identical numbers. "Hasher execution" excludes the call's access charge.

| Deployed hasher | Code size (bytes) | Hasher execution | Warm call | Cold call (today) |
|---|---|---|---|---|
| poseidon-solidity T3, `0x3333…3B93` | 23,478 | 18,049 | 18,168 | 20,668 |
| poseidon-solidity T4, `0x4443…ECF0` | 14,189 | 34,478 | 34,597 | 37,097 |
| poseidon-solidity T5, `0x5553…9767` | 19,260 | 51,117 | 51,236 | 53,736 |
| poseidon-solidity T2, `0x2223…A4db` | 15,092 | 10,489 | 10,608 | 13,108 |
| Privacy Pools T3 library `0x8ffda7ed8b4ad98c2c34f54b76821711f4a6f2c5` | 23,522 | 18,229 | 18,348 | 20,848 |
| Privacy Pools T4 library `0xe393dd7287db9982e6f845824854baf8b8e823af` | 12,584 | 71,509 | 71,628 | 74,128 |
| Semaphore v4 PoseidonT3 `0xB43122Ecb241DD50062641f089876679fd06599a` | 16,852 | 30,873 | 30,992 | 33,492 |
| Railgun PoseidonT3 `0xf5fe83643dd42d408c19b938866fa441c6c52563` (circomlibjs) | 9,743 | 29,005 | 29,124 | 31,624 |
| Railgun PoseidonT4 `0xafd3fc0396f793b35e433bbe0e1160329bf0abd3` (circomlibjs) | 12,463 | 45,128 | 45,247 | 47,747 |

Notes:

- The harness adds only 119 gas over hasher execution. A Solidity caller adds roughly 450 to 600 more (README figure minus my cold-call figure: 456 for T3, 520 for T4, 590 for T5).
- The T5 and T2 rows were measured later the same day (23:12 UTC, block 26,387,720); the rest at 14:49 to 14:50 UTC.
- The two Privacy Pools libraries were found as the two code-bearing addresses pushed in the ETH pool's bytecode (`0xF241d57C…C9fB`) and identified by which `hash(uint256[n])` selector they answer. The two Railgun libraries were found the same way in the current implementation `0xd662c4b1…6a0c`. Railgun's source says "The deployed library is generated bytecode from the circomlib toolchain" [P4].
- Build settings matter by a factor of two. The same poseidon-solidity T3 source costs 18,049 to 18,229 at a saturated optimizer and about 30,900 in Semaphore's deployment. The Privacy Pools T4 costs 71,509 against 34,478 for the canonical T4. A forum benchmark reports the same split: Poseidon t=3 at 30,485 for optimizer runs up to 5,000 and 18,229 from 10,000 up (Foundry 1.7.1, solc 0.8.24) [P2].
- The canonical poseidon-solidity hashers already exist on mainnet at the addresses above, so they can be linked without paying deployment. Under EIP-8037 deploying a 23,478-byte hasher would cost about 36.5M gas.
- Poseidon2 is a different function and not compatible with circomlib Poseidon circuits. For reference [P3]: poseidon2-evm, BN254 t=4, "Yul 20,304", "Huff 14,845" for 1, 2 or 3 inputs, "Not yet audited", no code at its listed addresses on mainnet today.

**Per-hash figures used in Part 3** (poseidon-solidity, external library call from Solidity, hasher already warm): README figure minus 2,500.

| Width | Warm call | First (cold) call today | First (cold) call, Glamsterdam |
|---|---|---|---|
| T3 | 18,624 | 21,124 | 21,524 |
| T4 | 35,117 | 37,617 | 38,017 |
| T5 | 51,826 | 54,326 | 54,726 |

Each distinct hasher contract is cold once per transaction: +2,500 today, +2,900 under EIP-8038. Nothing else about hashing changes in Glamsterdam.

### 2.g Groth16 verification on BN254

**Formula.** With n public inputs: one 4-pair pairing check plus n scalar multiplications and n additions.

- Precompile gas only: 45,000 + 4 × 34,000 + n × (6,000 + 150) = **181,000 + 6,150 n**. Published as "≈ (181 + 6×ℓ) kgas" [G1, Nebra].
- Published measurement of the snarkjs-generated verifier [G1, Orbiter]: "207700 + 7160 × l", and "without calldata: 203,600 + 6,792 × l"; measured 214,635 gas with 1 public signal and 424,660 with 32. These figures are whole-transaction figures: they match my numbers only if the 21,000 base is inside them.

**My measurement** [R1]: the two snarkjs verifiers used by the Privacy Pools ETH pool, called through the same harness with generator points as the proof. The call returns false, but the gas is the same as for a valid proof because precompile prices do not depend on the result.

| Verifier | Public inputs | Code size | Verifier execution | Warm call | Cold call |
|---|---|---|---|---|---|
| `0xa45aca8604a73d80c551faad6355a5c3a5565ec6` (ragequit) | 4 | 1,582 B | 208,946 | 209,065 | 211,565 |
| `0x022891f938ae7fdc8ab9ead0fbf50aba8c897d6d` (withdraw) | 8 | 1,947 B | 235,451 | 235,570 | 238,070 |

Two-point fit: **verifier execution ≈ 182,441 + 6,626.25 × n**. Verifier code size ≈ 1,217 + 91 × n bytes.

For n = 11: 182,441 + 72,889 = **255,330** execution gas (extrapolated from n = 4 and 8). Add the cold call to the verifier: 2,600 today, 3,000 under Glamsterdam. Proof calldata (256 bytes plus 32 per input) is counted separately in Part 3.

**Correction to the earlier note.** It used "210,000 + 7 × 7,200 = 260,400" for 7 inputs and then added the base and calldata again. Measured-fit execution for n = 7 is 228,825, so its withdrawal totals are about 31,575 too high: 325,544 → about 293,969 today and 417,664 → about 386,089 under Glamsterdam. This is my recalculation.

### 2.h Post-quantum KEM sizes

**ML-KEM-768** [K1], FIPS 203 Table 3, "Sizes (in bytes) of keys and ciphertexts of ML-KEM": encapsulation key **1184**, decapsulation key 2400, ciphertext **1088**, shared secret key 32.

**X-Wing** (X25519 + ML-KEM-768) [K2], draft section 5.1: "Decapsulation key (private): 32 bytes", "Encapsulation key (public): 1216 bytes", "Ciphertext: 1120 bytes", "Shared secret: 32 bytes". Layout: `pk_M = pk[0:1184]`, `pk_X = pk[1184:1216]`; `ct_M = ct[0:1088]`, `ct_X = ct[1088:1120]`.

**Standardisation status today.**

- Still an Internet-Draft, not an RFC: `draft-connolly-cfrg-xwing-kem-11`, dated 23 September 2026, "Intended status: Informational", "Expires: 27 March 2027".
- Datatracker: state "Active"; stream "ISE" with ISE state "Submission Received"; IESG state "I-D Exists"; group "Individual Submissions". So it is going through the Independent Submission stream, not as a CFRG-adopted document.
- Revision history: -00 on 2024-01-10 through -11 on 2026-09-23.

**HPKE.** Yes, a KEM identifier is registered [K3]: "0x647A, X-Wing, Nsecret 32, Nenc 1120, Npk 1216, Nsk 32, Auth no, [draft-connolly-cfrg-xwing-kem-06]". The same registry lists "0x0041, ML-KEM-768, 32, 1088, 1184, 64" and the NIST-curve hybrids "0x0050, MLKEM768-P256" and "0x0051, MLKEM1024-P384" (reference draft-ietf-hpke-pq-04).

**Check on the payload sizes in Part 3.** 1,216 bytes equals the X-Wing public key, not the ciphertext. If the 1,216-byte "hybrid ciphertext" is an X-Wing ciphertext plus encrypted payload, it carries 1,120 + 96 bytes; the 1,360-byte one carries 1,120 + 240. If it was meant to be the bare KEM ciphertext, the right number is 1,120 bytes (calldata 17,920 + log 8,960 = 26,880 gas).

---

## Part 3. Worked table

**Constants used**

| Item | Today | Glamsterdam (8037 + 8038 + 7976) |
|---|---|---|
| Transaction base | 21,000 | 21,000 held; 15,000 with EIP-2780 for a zero-value call |
| Calldata, standard | 16 per non-zero byte, 4 per zero byte | same |
| Calldata floor | 40 per non-zero byte, 10 per zero byte | 64 per byte |
| Fresh slot, cold | 22,100 | 110,020 (12,100 execution + 97,920 state) |
| Overwrite x → y, cold | 5,000 | 12,100 |
| Clear x → 0, cold | 5,000, refund 4,800 | 12,100, refund 11,616 |
| SLOAD, cold | 2,100 | 2,100 |
| Cold account access | 2,600 | 3,000 |
| LOG | 375 + 375 per topic + 8 per byte | same |
| Poseidon T3 / T4 / T5, warm | 18,624 / 35,117 / 51,826 | same |
| First call to each hasher | + 2,500 | + 2,900 |
| Groth16 verify, n = 11 | 255,330 + 2,600 | 255,330 + 3,000 |

All calldata bytes are priced as non-zero, as the task assumed. Real ABI calldata has many zero bytes and costs less.

### 3.1 Publishing a hybrid ciphertext as calldata and as LOG data

Inside a transaction that already uses about 1,000,000 execution gas:

| Payload | Calldata, 16 × N | LOG data, 8 × N | **Added gas, both regimes** |
|---|---|---|---|
| 1,216 bytes | 19,456 | 9,728 | **29,184** |
| 1,360 bytes | 21,760 | 10,880 | **32,640** |

**Does the floor bind? No, in either regime.**

- Today the floor binds only if execution gas is below 24 × N: 29,184 for 1,216 bytes, 32,640 for 1,360 bytes.
- Under EIP-7976 it binds only below 48 × N: 58,368 and 65,280.
- The transaction has about 1,000,000, so the payload is priced at 16 gas per byte in both regimes and Glamsterdam changes nothing here.

Small extras not in the table, same in both regimes: about 290 gas for the two ABI words (offset, length) in calldata, 512 for the same two words in the log data, about 230 for copying the bytes into memory, and 750 if the payload gets its own event with one topic. 1,360 bytes is not a multiple of 32, so ABI encoding pads it with 16 zero bytes (64 gas in calldata, 128 in the log).

**If the floor did bind** (a transaction that does nothing but carry the payload, so the whole transaction is priced by the floor and the log is absorbed):

| Payload | Today: 21,000 + 40 × N | Glamsterdam: 21,000 + 64 × N | With EIP-2780: 15,000 + 64 × N |
|---|---|---|---|
| 1,216 bytes | 21,000 + 48,640 = **69,640** | 21,000 + 77,824 = **98,824** | 92,824 |
| 1,360 bytes | 21,000 + 54,400 = **75,400** | 21,000 + 87,040 = **108,040** | 102,040 |

For scale, a minimal standalone publish at standard rates would be about 51,300 gas for 1,216 bytes (21,000 + 19,456 + about 10,850 to emit one log). So the floor costs a data-only transaction about 18,300 extra today and about 47,500 extra under EIP-7976. Riding inside the spend transaction avoids both the second base charge and the floor.

### 3.2 Storage primitives

| Operation | Today | Glamsterdam | Ratio |
|---|---|---|---|
| One fresh slot, cold | 2,100 + 20,000 = **22,100** | 2,100 + 10,000 + 97,920 = **110,020** | 4.98x |
| One cold overwrite, non-zero → non-zero | 2,100 + 2,900 = **5,000** | 2,100 + 10,000 = **12,100** | 2.42x |
| One cold SLOAD | **2,100** | **2,100** | 1.00x |

### 3.3 Contract deployment by code size

Assumptions, as in the earlier note: a creation transaction to a new address; initcode the same size as the runtime code; initcode calldata all non-zero; constructor execution excluded. L is code size in bytes and W = L / 32 words.

- Today: 21,000 + 32,000 + 16 L + 2 W + 200 L.
- Glamsterdam execution: 12,000 + 12,000 + 16 L + 2 W + 6 W. This uses the EIP-2780 creation base of 24,000, because EIP-8037 defines creation transactions only on top of EIP-2780. If the base stayed at 21,000 plus `CREATE_ACCESS`, add 9,000.
- Glamsterdam state: 183,600 + 1,530 L.

| Code size | Today, total | Glamsterdam execution | Glamsterdam state | Glamsterdam total | Ratio |
|---|---|---|---|---|---|
| 4 KiB (4,096) | 937,992 | 90,560 | 6,450,480 | **6,541,040** | 6.97x |
| 8 KiB (8,192) | 1,822,984 | 157,120 | 12,717,360 | **12,874,480** | 7.06x |
| 12 KiB (12,288) | 2,707,976 | 223,680 | 18,984,240 | **19,207,920** | 7.09x |
| 16 KiB (16,384) | 3,592,968 | 290,240 | 25,251,120 | **25,541,360** | 7.11x |
| 20 KiB (20,480) | 4,477,960 | 356,800 | 31,518,000 | **31,874,800** | 7.12x |
| 24 KiB (24,576) | 5,362,952 | 423,360 | 37,784,880 | **38,208,240** | 7.12x |

Arithmetic for one row (16 KiB, W = 512): today 53,000 + 262,144 + 1,024 + 3,276,800 = 3,592,968. Glamsterdam execution 24,000 + 262,144 + 1,024 + 3,072 = 290,240; state 183,600 + 25,067,520 = 25,251,120. The 24 KiB row reproduces the earlier note's 38.2M.

**Does each fit in one transaction?**

| Code size | Today (cap 16,777,216 on `tx.gas`) | Glamsterdam (cap 16,777,216 on execution only) | Fits a 60M block under Glamsterdam |
|---|---|---|---|
| 4 KiB | yes | yes, and `tx.gas` stays below 2^24, so no reservoir; about 10.2M left for the constructor | yes |
| 8 KiB | yes | yes, no reservoir needed; about 3.9M left for the constructor | yes |
| 12 KiB | yes | yes, but `tx.gas` must exceed 2^24 (19.2M); state gas comes from the reservoir | yes, if the block has used at most 40.8M state gas |
| 16 KiB | yes | yes, with `tx.gas` about 25.5M | yes, if at most 34.5M state gas used |
| 20 KiB | yes | yes, with `tx.gas` about 31.9M | yes, if at most 28.1M state gas used |
| 24 KiB | yes | yes, with `tx.gas` about 38.2M | yes, if at most 21.8M state gas used |

- All six fit in one transaction in both regimes. Execution gas is at most 0.42M plus the constructor, far below the cap.
- From 12 KiB up, a Glamsterdam deployment also needs 16,777,216 of unused execution gas in the block at its position, because the inclusion check uses `min(TX_MAX_GAS_LIMIT, tx.gas)`.
- The calldata floor does not raise what the deployer pays (the floor for 24 KiB is about 1.6M against a 38.2M total).
- Deploying through a factory with `CREATE2` costs the same state gas and can use the reservoir, since the reservoir passes to child frames in full.

**Current mainnet block gas limit: 60M.** Read live: block 26,385,194 `gasLimit` 59,941,408 and block 26,385,195 `gasLimit` 59,999,943, at 14:45 UTC on 10 Nov 2026 [R1]. EIP-7935 (`Final`) set the 60M default. EIP-8261 (Informational, Last Call) describes a post-fork gas limit schedule but fixes no values.

### 3.4 Composite "spend"

Composition as revised by the coordinator: 32 Poseidon-T3 hashes plus 1 Poseidon-T5 hash (not 37 T3).

| Component | Today | Glamsterdam | Change |
|---|---|---|---|
| Base | 21,000 | 21,000 | 0 |
| Calldata, 2,300 non-zero bytes × 16 | 36,800 | 36,800 | 0 |
| Groth16 verify, 11 public inputs: 255,330 + cold call | 257,930 | 258,330 | +400 |
| 2 fresh nullifier slots | 2 × 22,100 = 44,200 | 2 × 110,020 = 220,040 | +175,840 |
| 32 Poseidon-T3: 32 × 18,624 = 595,968, + cold hasher | 598,468 | 598,868 | +400 |
| 1 Poseidon-T5: 51,826 + cold hasher | 54,326 | 54,726 | +400 |
| 6 cold overwrites | 6 × 5,000 = 30,000 | 6 × 12,100 = 72,600 | +42,600 |
| 4 cold SLOADs | 8,400 | 8,400 | 0 |
| LOG, 3 topics, 1,700 bytes: 375 + 1,125 + 13,600 | 15,100 | 15,100 | 0 |
| Misc | 15,000 | 15,000 | 0 |
| **Total** | **1,081,224** | **1,300,864** | **+219,640 (1.20x)** |

- Glamsterdam split: 1,105,024 execution + 195,840 state.
- With EIP-2780: **1,294,864**.
- Floor check: today 21,000 + 40 × 2,300 = 113,000; Glamsterdam 21,000 + 64 × 2,300 = 168,200. Not binding.
- `tx.gas` is below 2^24, so there is no reservoir and the 195,840 of state gas comes out of ordinary gas. Any gas limit sized for today's 1.08M fails.
- Hashing is 60% of the transaction today. With a circomlibjs-style T3 (29,673 warm) the 32 T3 hashes would cost 353,568 more.

### 3.5 "Deposit"

| Component | Today | Glamsterdam |
|---|---|---|
| Base | 21,000 | 21,000 |
| Calldata, 300 non-zero bytes × 16 | 4,800 | 4,800 |
| 1 fresh slot | 22,100 | 110,020 |
| ERC-20 `transferFrom` | 30,000 | 51,700 |
| LOG, 2 topics, 160 bytes: 375 + 750 + 1,280 | 2,405 | 2,405 |
| **Total** | **80,305** | **189,925 (2.37x)** |

- Glamsterdam split: 92,005 execution + 97,920 state. With EIP-2780: **183,925**.
- **What changes in `transferFrom`.** I modelled today's 30,000 as one cold call to the token (2,600), three cold slot overwrites (allowance, sender balance, receiver balance: 15,000), one Transfer event (1,756) and 10,644 of unchanged token logic. Under Glamsterdam: 3,000 + 3 × 12,100 + 1,756 + 10,644 = **51,700**. That is +400 for the call and +7,100 per slot written.
- Variants: with an unlimited allowance that is read but not written, the same model has two writes and one read: 27,100 today and 41,700 under Glamsterdam. A proxy token adds one more cold account access (+400). If the receiver's token balance is zero before the transfer, add a fresh slot (22,100 today, 110,020 under Glamsterdam); a pool that already holds the token does not pay this.
- This split is an estimate, not a measurement of any particular token.
- Floor check: 33,000 today, 40,200 under Glamsterdam. Not binding.
- The list has no hashing. If the deposit also inserts into a Merkle tree on-chain, add the T3 hashes at 18,624 each.

### 3.6 "Activate"

Composition as revised by the coordinator: 32 T3 + 1 T4 + 1 T5.

| Component | Today | Glamsterdam | Change |
|---|---|---|---|
| Base | 21,000 | 21,000 | 0 |
| Calldata, 300 non-zero bytes × 16 | 4,800 | 4,800 | 0 |
| 32 Poseidon-T3: 595,968 + cold hasher | 598,468 | 598,868 | +400 |
| 1 Poseidon-T4: 35,117 + cold hasher | 37,617 | 38,017 | +400 |
| 1 Poseidon-T5: 51,826 + cold hasher | 54,326 | 54,726 | +400 |
| 1 slot cleared (cold) | 5,000 | 12,100 | +7,100 |
| 5 cold overwrites | 25,000 | 60,500 | +35,500 |
| 3 cold SLOADs | 6,300 | 6,300 | 0 |
| LOG, 2 topics, 96 bytes: 375 + 750 + 768 | 1,893 | 1,893 | 0 |
| **Gross** | **754,404** | **798,204** | +43,800 |
| Refund for the cleared slot | −4,800 | −11,616 | |
| **Net paid** | **749,604** | **786,588 (1.05x)** | +36,984 |

- No state gas: nothing new is created. With EIP-2780: **780,588**.
- The refund is far below the 20% cap in both regimes.
- Floor check: 33,000 and 40,200. Not binding.
- The task list has no "misc" line for this transaction; none was added.

### Summary of Part 3

| # | Item | Today | Glamsterdam | With EIP-2780 |
|---|---|---|---|---|
| 1 | 1,216-byte payload, inside a 1M-gas transaction | 29,184 | 29,184 | same |
| 1 | 1,360-byte payload, inside a 1M-gas transaction | 32,640 | 32,640 | same |
| 1 | 1,216 / 1,360 bytes as a data-only transaction (floor binds) | 69,640 / 75,400 | 98,824 / 108,040 | 92,824 / 102,040 |
| 2 | Fresh slot / cold overwrite / cold SLOAD | 22,100 / 5,000 / 2,100 | 110,020 / 12,100 / 2,100 | same |
| 3 | Deploy 4 / 8 / 12 KiB | 0.94M / 1.82M / 2.71M | 6.54M / 12.87M / 19.21M | included |
| 3 | Deploy 16 / 20 / 24 KiB | 3.59M / 4.48M / 5.36M | 25.54M / 31.87M / 38.21M | included |
| 4 | Spend | 1,081,224 | 1,300,864 | 1,294,864 |
| 5 | Deposit | 80,305 | 189,925 | 183,925 |
| 6 | Activate (net of refund) | 749,604 | 786,588 | 780,588 |

---

## Could not verify, and estimates

**Estimates, not measurements**

- **Poseidon warm-call figures (18,624 / 35,117 / 51,826).** Derived as the published README cold figure minus 2,500. My own harness numbers support all three (hasher execution 18,049, 34,478 and 51,117; warm call from a minimal harness 18,168, 34,597 and 51,236). The T5 figure is therefore published and measured, not estimated; only the 450 to 600 gas of Solidity caller overhead inside each figure is inferred.
- **Groth16 at 11 public inputs (255,330).** Extrapolated from measurements at 4 and 8 inputs on two deployed snarkjs verifiers. Not measured at 11. A different verifier generator will differ by a few thousand gas.
- **Caller-side overhead** around hasher and verifier calls (encoding, memory): about 450 to 600 gas per hasher call is inside the Poseidon figures; the verifier's is assumed to sit in "misc".
- **ERC-20 `transferFrom` split** (30,000 → 51,700): a model, described in 3.5.
- **Deployment rows** exclude constructor execution and assume initcode size equals runtime size with all-non-zero calldata.
- **Calldata priced all non-zero**, per the task. This is an upper bound.
- **"If the floor did bind" rows** assume execution small enough that the floor sets the whole price; the 51,300 comparison figure is an estimate.

**Not verified**

- **Whether EIP-8037/8038 ship unchanged.** Open. The fork is paused; audit reports are due 13 Nov and ACDE discusses them on 19 Nov. The EF post was read through a summarising tool, so its quotes are as that tool reported them.
- **Glamsterdam mainnet date.** None exists. Forkcast's 2026-12-02 is its own estimate and predates the pause.
- **EIP-8037 without EIP-2780.** The "base held at 21,000" columns are a modelling convention requested by the task; the fork as specified includes EIP-2780.
- **Forum and HackMD sources** (P2, G1) were read through a summarising tool and are undated or self-published. The Orbiter formula's inclusion of the 21,000 base is my inference from matching numbers.
- **Privacy Pools and Railgun hasher identification** rests on bytecode inspection and on which selector each library answers, not on verified source. Build settings behind the slow Privacy Pools T4 and Semaphore T3 deployments were not looked up.
- **No Huff or Yul implementation of original (circomlib-compatible) Poseidon** with a published gas figure was found. poseidon-solidity at a saturated optimizer is the cheapest located. Its README says it is unaudited.
- **Deployed size of a circomlibjs-generated T5**, and gas for T5 in any implementation other than poseidon-solidity: not looked up beyond the README's 73,307.
- **X-Wing in draft-ietf-hpke-pq.** Whether the IETF HPKE working-group draft also carries X-Wing under another name was not checked. IANA lists only 0x647A.
- **Memory-expansion and copy costs** for logs were not itemised.

**Reproducing the measurements.** Scripts are in the session scratchpad, which is temporary: `/tmp/claude-0/-home-user-claude/4107f7be-64fa-56df-982c-ff1f40a87dd3/scratchpad/scripts/harness.py`, `/tmp/claude-0/-home-user-claude/4107f7be-64fa-56df-982c-ff1f40a87dd3/scratchpad/scripts/groth.py` and `/tmp/claude-0/-home-user-claude/4107f7be-64fa-56df-982c-ff1f40a87dd3/scratchpad/scripts/measure_poseidon.py`. The harness is: copy calldata to memory, then three times `GAS; STATICCALL(target); GAS; SUB`, return the three deltas; run with `eth_call` and a `code` state override.
