Thanks! You're right, and we hit exactly that today on Sepolia. Here's a concrete proposal, then a few smaller things.

**1. Tell the contract when there's no answer**

Today `complete()` calls the callback only when `status == 0`. On a refusal (1) or a split panel or failure (2), the writer records the outcome in the `Completed` event, but the contract that paid never hears about it. Contracts can't read events, so the request just stays open forever on their side.

We hit both cases:
- **Plea #1 (split):** tx `0x77214bc7…f7775`. The panel split 17 of 28, the writer completed it in `0x84dcf9b2…229d`, and our Gate still shows the plea as Pending. The seller waits out a 2h timeout we had to guess, though the plane knew within ~4 minutes.
- **12 calibration requests (refused):** all `testnet_only` (e.g. `0x0cd687e4…dde`), completed on-chain with nothing delivered.

**Proposal: an opt-in failure hook, named in the body** (a sibling of `deliver`):

```json
{ "v": 1, "question": "…", "chainId": 1, "window": { "hours": 1 },
  "answerType": "bool", "evidence": "panel", "panelSize": 30, "quorum": 16,
  "validForSeconds": 3600, "definitions": { … },
  "consumer": { "chainId": 11155111, "verifyingContract": "0xGate" },
  "onFailure": "0x…selector" }
```

On every completion with status 1 or 2, `complete()` calls the same callback `target` with that selector:

```solidity
struct OracleFailure {
    bytes32 requestId;  // the intake id that request() returned (same as the success callback's first arg)
    uint8   status;     // 1 = refused, 2 = no answer (disagreed or failed)
    bytes32 reason;     // short code, right-padded: "disagreed", "failed", "testnet_only",
                        // "body_invalid", "short_payment", "quorum_unreachable", …
    uint16  agreed;     // largest group of matching answers (0 if no panel ran)
    uint16  answered;   // members who answered (0 if no panel ran)
    uint16  quorum;     // matching answers that were needed
}

interface IOracleFailureReceiver {
    function onOracleFailure(OracleFailure calldata f) external;
}
```

Examples from today:
- plea #1: `{0xcc4e…6a8d, 2, "disagreed", 17, 28, 20}`
- a refused request: `{0x7e14…4ca6, 1, "testnet_only", 0, 0, 8}`

**How it behaves:**
- **Same rules as the success callback:** called once, 200k gas, inside a try. A revert can't block the write; `Completed` records `delivered: false`.
- **No signature needed:** only the writer can call `complete`, and the call carries no answer to forge. A consumer checks `msg.sender == Intake` and that `requestId` is one it made. The worst a bad call could do is make a contract stop waiting early.
- **Opt-in:** no `onFailure` in the body, no call. Existing consumers are untouched.
- **Kept out of `questionHash`,** like `consumer`, so it doesn't change what judges see or what gets signed.
- **Refused upfront:** `onFailure` without a callback (or `deliver`) is refused at check/quote time, before anyone pays.
- **Cross-chain:** with `deliver`, IntakeDelivery makes the same call on the destination chain. Today a failure "is completed on the paying chain only", so cross-chain consumers are the most blind.
- **Why a struct:** you can add fields later (a URL to the record, a retry hint) without changing the selector.
- **One gap:** if the body isn't valid JSON, the plane can't read `onFailure`. That's rare, and a free full-body check catches it (see 2). To cover it anyway, you could call `onOracleFailure` on any callback target that returns true for `supportsInterface(type(IOracleFailureReceiver).interfaceId)` (ERC-165), with no body field needed.

**What we'd do with it:** the Gate frees the seller's slot right away and the Wall shows "the Cabal was split 17–11". No timeout, no relayer.

**2. A free check of the full body before paying.** The quote now needs a request token, and `/requests/check` only takes the short input. So an on-chain payer can't test a complete body (consumer, definitions, guards) without paying, and the `testnet_only` rule isn't in the docs either. A free endpoint that runs every refusal rule on the exact body would stop spent payments.

**3. Link the attestation to the intake request.** The attestation carries the oracle's request UUID, not the intake `requestId`. So a public `submit` fallback (as the docs suggest) can't tell its own paid request from one anyone else paid with the same public body, and a seller could re-ask until they get a yes. Putting the intake `requestId` (or the payer and body hash) into the signed attestation would close that.

**4. Panels split on judgment calls.** Both of our real tests ended "disagreed" (17/13 and 17/28) on a yes/no close to a threshold. An option to sign a `uint256` answer as the panel *median* (with a minimum number of answers) would help: the contract compares the number to its own threshold.

**5. `evm_contracts` launches:**
- **Hook addresses:** a Uniswap v4 hook needs a mined CREATE2 salt; supporting a salt (like `univ4_hook` does) would save us mining on-chain in a constructor.
- **Gas preflight:** the Sepolia preflight estimated 23.7M gas for a deploy that really uses 3.08M, and parked the launch.
- **Verifier memory:** the verifier ran out of memory compiling v4-core's PoolManager (exit 137).

**6. Small one:** let the payer buy a higher callback gas limit than 200k, for consumers that need to do real work in the callback.

**7. Chain mode can't sign transaction-level checks (tested 2026-10-10 on Sepolia).** We asked, in chain mode, "did wallet W buy token T from pair P, and was the pair's liquidity pulled afterwards?" about a real Ethereum rug. All 13 answering members said **true**, with correct notes (tx.from, Swap amounts, Burn vs prior Sync reserve), but nothing was signed: each member had to pick a stand-in recipe from the catalogue (8 used `balanceOf`, 4 `getReserves`, 1 `token0`, with different thresholds), so only 2 matched. The same facts asked in **panel mode** were signed 12/12 with the right answer. Requests: oracle `aebb2ae2-1250-4cb4-8451-0049491ec872` (chain, disagreed) and `e8e13011-0901-430d-8f4b-4467e48a4897` (panel, attested). Suggestions, most useful first:
- **A transaction recipe:** given a tx hash, check `from`, `status`, `blockNumber` and decoded logs (e.g. "emitted Transfer of T from P to W"). One receipt read, fully deterministic.
- **Historical calls and comparisons:** a call at a given block (not only the closing block), and comparing two reads (reserve after Burn ≤ 1% of reserve before).
- **AND of recipes:** let one bool answer be the conjunction of several recipes, so multi-step checks can be rerun.
- **Agree on the answer when recipes differ:** if every member gives the same answer but no single recipe reaches quorum, fall back to a panel-style signature (marked as such) instead of "disagreed", or let the requester opt in with something like `evidence: "chain-or-panel"`.
- **Publish the recipe catalogue** (in the docs or `/requests/capabilities`), so requesters can word chain questions to fit an existing recipe.

Happy to test any of this on Sepolia; it's free there now, which is great.
