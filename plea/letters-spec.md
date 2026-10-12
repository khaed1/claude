# PLEA letters and auto-sell: spec (next version)

Status: agreed with the user on 2026-10-12; **implemented on `khaed1/plea` branch `testnet3`** (Sepolia test run 3), see HANDOFF. Target: the PLEA version after the current mainnet draft. It does not fit the draft, which is already over the mainnet deploy-gas limit; see Size.

## Goal

Let anyone plead **straight from their wallet or Etherscan**, by sending an on-chain text message (an IDM: a transaction whose input data is UTF-8 text) to PLEA's **Letterbox**. No site visit, no approvals, no setup.

An approved plea **sells itself** ("auto-sell"): a runner sends the sale for a small tip, and the seller just sees the IMD arrive. Status and the leaderboard can also be read on chain.

The site gets the same auto-sell as an option.

## Agreed numbers

| Item | Value |
|---|---|
| Plea amount (letters) | Fixed: **10% of the writer's PLEA balance**, within the existing caps (≤ 2.5M PLEA, ≤ 35% of balance) |
| Appeal amount (letters) | The original plea's amount |
| Oracle fee | 0.5 IMD (unchanged), paid by selling the writer's PLEA |
| Runner tip | **0.25 IMD** per auto-sell, paid in PLEA up front; refunded if no sale happens |
| Appeal wall fee | 0.35 IMD (unchanged), paid in PLEA |
| Sale minimum (auto-sell) | **95%** of the PLEA's value at the hook's hourly price snapshot (5% margin) |
| Fee-swap cap | The court may spend at most the snapshot value of the IMD it needs **+10%** in PLEA |
| Sale window | 7 minutes (unchanged) |
| Score, pass mark, cooldowns, seasons | Unchanged. Letters score exactly like site pleas. |
| Badge | "By letter" wax seal on the Wall card and the Laureate. **No extra points.** |

## Contracts

### New: `Letterbox`

A small contract with no owner. It holds plea escrows and tips while they are open, and nothing else.

**Receiving letters.** `fallback()` takes `msg.data` as the letter text. A `receive()` function is not used: letters must carry text, and ETH sent to the Letterbox is refused.

**Etherscan only, no site (user decision 2026-10-12).** Letters must work from Etherscan alone. Etherscan's Write Contract tab can't send raw input data, so the Letterbox also has **`letter(string text)`** (ID `0xc95c7f37`, passes the ID rule): it reads `text` exactly like raw input data (plea, `APPEAL`, `SELL`, `NAME`), same 10%, fees in PLEA, escrow and auto-sell. Three ways to send the same letter:

| Way | How |
|---|---|
| Etherscan's IDM page (https://etherscan.io/idm, **mainnet only**: sepolia.etherscan.io/idm says "This feature is not available") | "Send To" = the Letterbox, type the message: it is sent as the input data, i.e. a raw letter. To confirm on mainnet that it sends plain UTF-8 to a contract address. |
| Etherscan Write Contract (mainnet and Sepolia) | Letterbox → Write Contract → connect wallet → `letter(text)` → type the letter in plain words → Write |
| A wallet's data field | 0 ETH to the Letterbox, the letter's UTF-8 bytes as hex data (MetaMask extension: Show hex data; not on mobile) |

The site's "Send letter" button suggested on 2026-10-12 is dropped: letters need no site.

**Function IDs must not be typeable.** A contract runs a function when the first 4 bytes of the input match that function's ID. So:
- No public function of the Letterbox may have an ID whose 4 bytes could be the start of a valid letter, i.e. of control-free UTF-8 text (implemented rule; "contains a non-ASCII byte" was not enough, since UTF-8 text uses bytes 0x80-0xF4). All readable names passed: `plead`, `appealAuto`, `deliver`, `settle`, `feesFor`, `escrowOf`, `openOf`, `status`, `leaderboard`.
- A test enumerates the ABI and asserts this, so no letter can trigger a function by accident.

**Commands.** The first word of the letter decides what it does. Commands are upper case, followed by a space or a newline.

| Letter | Effect |
|---|---|
| any text not starting with a command | New plea, fixed amount, auto-sell on |
| `APPEAL <text>` | Appeal the writer's latest denied plea, if inside its 4-hour window, for the original amount |
| `SELL` | Manual sale of the writer's approved plea, if no runner has done it yet. Same 95% minimum. Records the points. |
| `NAME <name>` | Set the writer's display name (Laureates rules: 3–20 chars, a–z, 0–9, `_`) |

- **The writer is always `msg.sender`.** Nobody can plead, appeal or sell for someone else.
- **Text rules** are the gate's existing ones, applied to the text after the command word: 1–280 bytes of UTF-8, no control, zero-width, bidi, tag or variation-selector characters, no `[PLEA]` markers.
- **Any failure reverts** with a custom error, so the wallet shows the reason before signing. Failures include: Cabal dead, cooldown (with its end time), pending plea, bad text, amount too small, fee cap exceeded.

**Paying in PLEA, in the letter's own transaction:**
1. Compute the fact score and the amount first, from the balance before anything moves. This is the same score the site would show.
2. Take the plea amount from the writer into escrow, using PLEA's new court entry point (see Changes to PLEA).
3. Take enough extra PLEA to buy the fees, and swap it through the PLEA hook **exact-output** for the IMD needed:
   - plea: 0.5 + 0.25 = 0.75 IMD;
   - appeal: 0.5 + 0.35 + 0.25 = 1.10 IMD.

   The PLEA spent is capped at snapshot value +10%, otherwise the letter reverts. The swap pays the normal 1.75% trade fee, including the writer's 0.5% cashback.
4. Pay the oracle fee to the Intake through the gate, keep the 0.25 IMD tip in the Letterbox, and send the 0.35 appeal fee to the wall via `fundWall`.
5. **Sepolia only:** the oracle-fee token is a separate test token with an open `mint`. A constructor flag makes the Letterbox mint the 0.5 instead of swapping for it, and only the tip (and appeal fee) is swapped. On mainnet, pool IMD and oracle IMD are the same token.

**Escrow and the buy record:** moving PLEA into escrow and back does not change the hook's buy record (cost basis, holding time). Only the final sale reduces it, exactly as a site sale does today.

**Auto-sell:**
- `deliver(uint256 id)`: anyone may call it while the plea is Approved and inside its 7-minute window. In one transaction it:
  1. sells the escrowed PLEA through the gate, with `minOut` = 95% of the snapshot value;
  2. sends the IMD to the seller;
  3. calls `Seasons.record(id)`;
  4. pays the 0.25 IMD tip to the caller.
- The caller must send enough gas: the hook's existing gas check applies.
- If the price has fallen below the minimum, `deliver` reverts and the plea can lapse.

**Settling everything else:**
- `settle(uint256 id)`: anyone may call it once the plea is Denied, cleared with no verdict, Expired, Lapsed or Upheld.
- It returns the escrowed PLEA and the 0.25 IMD tip to the writer. The oracle fee is not refunded.
- The writer's next letter also settles their old plea first, so funds never wait for a stranger.

**Our bot (backstop runner):** a small script that watches the gate's `Verdict`, `PleaFailed` and `PleaExpired` events, calls `deliver` on every approved letter or auto-sell plea, and calls `settle` on the rest. It runs whether or not the tip covers its gas.

**Status, readable on chain** (free, from Etherscan's Read Contract tab):
- `status(address)` returns one sentence. Examples:
  - `No open plea. Next plea possible now.`
  - `Plea #7 · PENDING · asked 2m ago`
  - `Plea #7 · APPROVED (38 vs 33) · selling automatically`
  - `Plea #7 · SOLD for 1.97 IMD · +38 points (season 2, rank 1)`
  - `Plea #7 · DENIED (31 vs 33) · send APPEAL <text> before 07:05 UTC`
  - `Plea #7 · NO VERDICT · PLEA and tip returned`
  - `Cooldown until 07:05 UTC`
- `leaderboard()` returns the current season's top 10 as text lines: rank, name or short address, points, IMD prize and PLEA bonus at the current pot, the time left, and the 60-point rule.
- These are view functions only; their IDs follow the non-ASCII rule above.

### Changes to `CabalGate`

- `submitFor(address seller, uint256 amount, string text, uint8 flags)` and `appealFor(...)`: only the Letterbox may call them. They do exactly what `submitSell` / `appeal` do, for `seller`, except that the Letterbox has already escrowed the PLEA and pays the fees. `flags` has two bits, `BY_LETTER` and `AUTO_SELL`.
- `executeSellFor(uint256 id, uint256 minOut)`: only the Letterbox. Sells the escrowed PLEA it holds for that plea, for the plea's seller.
- The plea gets a `flags` field, and a new event `PleaFlags(uint256 indexed id, uint8 flags)` is emitted at submit time, so the site and indexers know which pleas came by letter or sell automatically.
- Nothing else changes: score, need, cooldowns, appeal rules, the Intake request and the callback stay the same. The callback stays small; no transfers happen inside it.

### Changes to `PLEA`

- `courtTake(address from, uint256 amount)`: only the Letterbox may call it.
  - Moves `amount` from `from` to the Letterbox without an allowance.
  - The Letterbox only ever passes its own `msg.sender` as `from`, so a wallet's PLEA can only move inside that wallet's own letter or site transaction.
- The Letterbox is an exempt sender, like the gate and Seasons, so it can return escrow and sell.

### Changes to `Laureates`

- `tokenURI` adds a wax-seal "By letter" mark when the plea's `BY_LETTER` flag is set.

## Site (optional; letters don't need it)

- **Wall:** letter pleas show the "By letter" seal and a link to the letter transaction, so the original message is visible on Etherscan. Appeals by letter link to their original plea, as now.
- **Plead page:**
  - A checkbox **"Sell automatically if approved"**, on by default.
  - When checked, the plea goes through the Letterbox's site function `plead(amount, text)`, with the same escrow and the same 0.25 IMD tip. It follows the same non-ASCII ID rule.
  - No approvals are needed: `courtTake` moves the PLEA, and the fees are paid in PLEA exactly as letters pay them.
  - Unchecked keeps today's manual flow.
- **New page "Plead by letter":** the Letterbox address with a copy button, the command table, three example letters, what it costs (0.75 IMD of PLEA, 0.25 refundable), how to read `status` on Etherscan, and the warning never to tell the judges how to score.
- **Status page:** open escrows, tips held, and the last 20 `deliver` / `settle` calls with who ran them.

## Edge cases

- **Cabal dead:** letters revert ("The Cabal is dead. PLEA trades freely."), and `settle` still returns any open escrow.
- **Writer's balance too small:** if 10% of the balance is under a minimum (e.g. 1,000 PLEA), or the fee would take more than 10% of the balance, the letter reverts.
- **Price moves:** a fee swap over its cap reverts the letter; a sale under 95% makes `deliver` revert, and the plea lapses and is settled with a refund.
- **Two letters at once:** the second one reverts (`PendingExists`), as on the site.
- **Season end:** points are recorded at `deliver` and `SELL`. A lapsed approval is recorded by `settle`, because it still counts for the season, as today.
- **Pending plea when the Cabal dies:** `settle` refunds escrow and tip.
- **Reentrancy:** all external entry points are `nonReentrant`. The PLEA and IMD it touches are our own contracts or the known IMD token.

## Size and gas

- **Letterbox:** a new contract, outside the six-contract launch transaction if IMD allows a second transaction, or added to it otherwise.
- **Gate, PLEA and Laureates:** small additions, a few hundred bytes. They still count against the 16,777,216 mainnet deploy-gas cap, which the full code already exceeds, so the user's question to the IMD dev about that cap decides how this ships.
- **Gas per transaction, estimated on mainnet:** a letter plea is a normal plea (~2.6M on Sepolia's schedule, much less on mainnet) plus the fee swap (~0.8M). `deliver` is about a normal sale (~1M) plus `record` (~0.6M).

## Tests to write

- **Non-ASCII ID rule:** every public selector of the Letterbox has a non-printable byte.
- **Parsing:** plain text, `APPEAL`, `SELL`, `NAME`; the command word must be followed by a space or newline; lower-case `sell` is plain text.
- **Fixed amount:** 10% respects the 2.5M and 35% caps; an appeal reuses the original amount.
- **Fees paid in PLEA:**
  - exact IMD amounts reach the Intake, the tip and the wall;
  - the fee swap respects the +10% cap;
  - the Sepolia mint path works;
  - the fact score is computed before anything moves.
- **`deliver`:**
  - only while Approved and inside the window;
  - pays the seller, records the points, pays the tip to the caller;
  - reverts below 95%;
  - cannot be called twice.
- **`settle`:** every non-sold end state returns exactly the escrow and the tip; it cannot be called twice; it settles automatically on the writer's next letter.
- **Isolation:** a stranger cannot plead, sell or settle into their own wallet for someone else.
- **`status` and `leaderboard`:** check the strings for each state.
- **Fork rehearsal against live Sepolia:** a letter sent as raw calldata; approval → runner `deliver`; denial → appeal letter → settle; no verdict → settle.
