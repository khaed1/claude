# PLEA run 9 site: round-2 fix list

The PLEA Sepolia test run 9 site (https://plea-test-run-9.sites.imd.fun/, launch #2234) after IMD's fix job fd8cb957, at commit cc33304. It was fixed against the round-1 file, run9-site-review.md (73 items). Every round-1 item was re-tested by a checker and checked again by a skeptic; where the two differed, this file follows the skeptic. This file lists what is still to do: 45 items (12 P1, 27 P2, 6 P3).

## How to use this file

- Fix every item in this file. Do the P1 items first (in every section), then P2, then P3.
- Round-1 items marked fixed must stay fixed. Keep everything under "Fixed in round 1 (keep it)" below working, and the round-1 "What works" items it lists, and re-check both after your changes. Where an item here deliberately changes one of them, the item wins.
- Where an item continues a round-1 item (its brackets name it, for example [T4]), the round-1 file's Should and Fix for that item still apply in full. This file quotes only what is still missing; where the two differ, this file wins.
- Check each fix on a fork of Sepolia (for example `anvil --fork-url <a Sepolia RPC>`, warping time for windows, seasons and the death), in a real browser at 320, 360, 768 and 1280 px, light and dark, with and without a wallet. Then check the read-only parts against the live contracts. Items with a "Done when" list their own checks as well.
- The brief (brief-site-job-run9.md), the design system (plea/site-design/: PAGE-KIT.md, components.html, tokens.css, components.css, pages/*.html and their "Design reference · other states" bands) and the contracts still apply. Use components.css as it is, follow the mockups' markup and copy, and read every number from chain.
- The product decisions stand: D1, the seed control only for `PLEA.owner()`; D2, no "Fund the buy wall", and Rebalance stays a small public action; D3, no Coinbase Wallet SDK.
- How an item reads:
  - **Now** says what is wrong: route, state, width and theme, and the source file:line under web/src at commit cc33304.
  - **Should** names the source of truth (brief, mockup, contract, or the round-1 item).
  - **Fix** says what to change.
  - The ids in brackets are what the item fixes. A round-1 item ref (T4, C9, S2, X1) is a round-1 item that is only partly fixed. An id starting with "r" is a new issue from the re-test. WW4 and WW5 are round-1 "What works" items 4 and 5, which regressed. The Index at the end maps each id to its item.
  - In the text, a bare ref such as "C5" is an item in this file; "round-1 C5" is an item in the round-1 file.
- Copy quoted from a mockup says "IMD" and "Ethereum": write imdTEST (the pair token's symbol, read from chain) and Sepolia / sepolia.etherscan.io. Sample values in quotes (08:06 UTC, plea #214, season 2) show the format; compute the real ones from chain.

## Status after round 1

- Fixed: 43 of the 73 round-1 items.
- Partly fixed: 30 round-1 items. What is still wrong is in the items below.
- New issues found by the re-test: 56.
- Regressions: 2, round-1 "What works" items 4 (focus rings, now X4) and 5 (direct loads of #/how and #/contracts, now X3).

## Fixed in round 1 (keep it)

These 43 round-1 items were re-tested and are fixed: each title names the round-1 problem, which is now gone. Keep them fixed. The refs are round-1 refs.

- **Round-1 T1** The first buy after the seed gets no quote, so Approve and Buy stay disabled
- **Round-1 T2** Seeding: owner only, followed at once by the opening buy, and no frozen 00:00 timer
- **Round-1 T3** Partial fills: the buy's own impact trips the price limit, the "minimum" is not a minimum, and success hides the shortfall
- **Round-1 T6** After the death, Buy/Sell still shows the alive rules
- **Round-1 T9** The launch-window panel lacks the mockup's notice and rows
- **Round-1 T11** Opening-buy payouts are not explained, and small cashback and claims show as 0.00
- **Round-1 T12** Exact-amount approvals: every buy takes two transactions
- **Round-1 C1** A lapsed approval or an expired unanswered plea locks the seller out of Plead
- **Round-1 C2** Sell now's default minimum comes from the hourly checkpoint, so the sale reverts after a ~1% dip
- **Round-1 C3** Auto-sell Plead accepts amounts and balances the Letterbox refuses
- **Round-1 C4** The automatic appeal shows the wrong amount: it ignores the escrow the Letterbox returns first
- **Round-1 C6** The meter ignores the verdict
- **Round-1 C7** A sold appeal is stamped SOLD instead of OVERTURNED
- **Round-1 C8** A VOID objection is shown as a re-score of 0; OVERRULED lacks its points
- **Round-1 C12** Amount chips and amounts filled into inputs show raw 18-decimal values
- **Round-1 C14** The sell window is not the urgent pair
- **Round-1 C18** The Objections page is a generic rewrite
- **Round-1 C21** Wrong copy on finished states, and the points hold
- **Round-1 C22** The oracle fallback trusts any api.imd.fun request with the same question
- **Round-1 C23** 'Copy hex data' stays 'Copied'
- **Round-1 S7** Plea cards (Wall, Home, Profile): per-state foot facts, badges, mono addresses, card names
- **Round-1 S8** Display name says 'This is your current name' when the wallet has no name
- **Round-1 S9** Another wallet's profile is written as the viewer's own
- **Round-1 S12** Claim: the 'not an address' error is not tied to the field
- **Round-1 S14** The claims.json loader is fragile
- **Round-1 S15** Share page buttons and copy errors
- **Round-1 X2** An idle tab sends about 260 eth_calls a minute to one public RPC, and more as the court gets busy
- **Round-1 X3** The need marker is drawn past the meter, so every profile page scrolls sideways
- **Round-1 X4** Every 15 s refresh blanks what is on screen: sections flash "Reading…", meters vanish, the layout jumps
- **Round-1 X5** Home live numbers: 4 of 6 cells, "PLEA burned" counts only the hook's burns, the pot is the whole Seasons balance, generic notes
- **Round-1 X6** Status strip and death banner: wrong pot, no season time or bonus, a partial dead state, "1d 9h", a forced second row
- **Round-1 X7** Remove the Coinbase Wallet SDK: it sends telemetry and sets a cookie on every load, and it is a third of the JS
- **Round-1 X9** Action buttons: one busy label for everything, native disabled, lower-cased connect text, no cost sub-label, a done state that disappears
- **Round-1 X10** Rule lengths and plea ages print as clock times ("within 07:00", "Up to 20:00", "sent 04:12 ago", "1d 9h")
- **Round-1 X12** Empty states: the 48 px icon renders at 20 px, it is always a gavel, and there is no action and no mockup copy
- **Round-1 X13** The wallet button is a short address that opens a modal: no name, no seat dot, no profile link, and "Switch to Sepolia" is not yellow
- **Round-1 X14** Menu and focus: Escape drops focus on `<body>`, opening does not move focus, an extra "Profile" item, a sun icon, page titles
- **Round-1 X16** Home after the Cabal dies: only the Plead button goes
- **Round-1 X19** Amounts round to nearest, not down; states flip one second early; three ABIs load unchecked
- **Round-1 X20** Link previews get no image; the share text can run long; the letter checker says IMD
- **Round-1 X21** Panel titles are h2 inside h2 sections
- **Round-1 X22** Sections sit 72 px apart, and short pages leave a band under the footer
- **Round-1 X23** The profile's "All pleas for this wallet" link is a 24 px target

Also keep the round-1 "What works (keep it)" list, items 1 to 25 of the round-1 file, except items 4 and 5, which regressed and are fixed here (X4 for WW4, X3 for WW5). Item 25's Wall skeleton cards on the first read are gone as well; X5 brings them back.

## T. Trading and money

Scope: #/buy (buy, and sell after the death), the fee and cashback rows, swap errors, the "Your PLEA" panel and Home's "Fees and supply". Round-1 T1, T2, T3, T6, T9, T11 and T12 are fixed: keep them. Code refs are web/src at cc33304.

### T1 (P1) Swap errors: a mined revert shows only "The transaction reverted.", the cap error is not on the field, and the messages carry no values [T4, rT-1]
- **Now:**
  - **Mined revert (rT-1).** On a fork, another wallet's buy is mined first in the same block. The site's swap then has receipt status 0, with PriceLimitAlreadyExceeded (0x7c9c6e8f) in the trace. Inline and in the toast it reads only "The transaction reverted.", because context.tsx:457-458 throws a bare Error and explainError passes it through (errors.ts:256). The link under the button still says "View pending transaction", because components.tsx:679-681 picks its label from `confirmed ?? done`.
  - **Launch cap.** "This buy would take 6,166,727 PLEA before the burn, above the 5,000,000 PLEA launch cap…" shows only under the button. #pay has no aria-invalid and its wrapper no is-invalid, because pages-trade.tsx:259 and 488-489 mark the field invalid for the balance only. When the balance is short, the same text shows twice: under the field and again under the button.
  - **Copy.**
    - BuyTooLarge has no cap and no UTC time (errors.ts:186-187).
    - PriceLimitAlreadyExceeded is generic, and on a sell it still says "bought" (errors.ts:75-76).
    - The pre-send shortfall (pages-trade.tsx:368-371) says "raise the slippage to 2%" even when the 2% chip is already chosen.
    - Every message is one string.
    - Buy passes no `errors` overrides to tx.send (:313, :343).
    - `HookCallFailed()` is in no ABI (errors.ts:193-199).
  - The rest of round-1 T4 is done; keep it: the recursive WrappedError decoding, no network text, and the cap check that blocks Approve.
- **Should:** Round-1 T4, Fix 1-3. buy.html's references "The launch window: a buy over the cap (BuyTooLarge)" and "Price moved past the slippage" show a toast__title plus a body. The "Not enough IMD" reference has the hint under the field, the button `aria-describedby` pointing to it, and no second copy. What works 16: the transaction link goes to sepolia.etherscan.io.
- **Fix:**
  1. **Title plus body.** Values in `messages` and `ErrorMap` may be a string or `{ title, body }`, and explainError returns `{ title, body? }`. In useTx (context.tsx:475-479), toast `{ text: title, body, kind: "bad", hash }`. Inline, show the title in `<b>`, then the body.
  2. **Overrides on #/buy.** Pass `errors` to both tx.send calls, with values from chain:
     - **BuyTooLarge:** "Not bought: more than 5,000,000 PLEA in one buy." / "Until 16:30 UTC one buy can take at most 5,000,000 PLEA. Pay less imdTEST, or split the buy in two. Nothing was bought." The cap is `LAUNCH_MAX_BUY` and the time is `clock(launchedAt + LAUNCH_WINDOW)`. The approve-time `prepare` (:325-334) throws this same message.
     - **PriceLimitAlreadyExceeded:** "The price moved more than 1%." / "Nothing was bought; your imdTEST stays in your wallet. Try again, or raise the slippage to 2%."
       - The first figure is the pressed chip, and the second is the next chip up of 0.5%, 1% and 2%. At 2% the body ends "Try again, or lower the amount."
       - On a sell after the death: "Nothing was sold; your PLEA stays in your wallet."
       - Use the same builder for the pre-send shortfall at :368-371.
  3. **Mined revert.** When `receipt.status !== "success"`, replay the request with `r.client.call({ ...req, account: address, blockNumber: receipt.blockNumber })`. Pass what the replay throws to explainError with `options.errors`, so the race above shows the PriceLimitAlreadyExceeded copy. If the replay passes, show "Mined but reverted." / "Nothing was traded; only the gas was spent. Try again." Keep the `hash`. While `hash && error && !busy`, Action labels the link "View the failed transaction" (components.tsx:679-681), and the toast carries the hash.
  4. **Cap on the field.** Set `invalid` when the amount is over the balance or `capError` is set.
     - While `invalid`: `.input.is-invalid`, `aria-invalid="true"` and the `field__hint bad-text` #pay-hint.
     - Action gets `describedBy="pay-hint"` and no reason paragraph of its own.
     - The cap hint reads "This buy would take 5,149,023 PLEA before the burn. Until 16:30 UTC one buy can take at most 5,000,000 PLEA. Pay less imdTEST, or split the buy in two."
     - Approve and Buy stay disabled.
  5. Add `error HookCallFailed()` to `poolErrors`, with the message "The pool hook refused this swap. Nothing was traded; refresh and try again."

### T2 (P1) Costs block: two rows missing, labels short of the mockup, and parts and sums that do not add up [T5, rT-3, rT-5]
- **Now:** The #/buy costs block (pages-trade.tsx:558-651), at every width:
  - **Rows.** There is no "Price" row and no "Reaches the pool" row; the pool amount appears only in the sum line.
  - **Labels.** The labels read "(0.5%)", "(1%)" and a bare "Burned". The launch row has 2 decimals ("Launch fee (66.62%)", :623) while the side panel shows "66.6%" (:729). "Fees, 2.25%" is not a `.total` row: Costs (components.tsx:126-141) only takes the index list `parts={[2,3,4,5,6]}`.
  - **Rounding** is mixed (:577-649). "Reaches" rounds down, cashback rounds down, and the fee total, owner, prize pot, wall and launch fee round up. As a result:
    - At 100 imdTEST the parts add to 0.49 + 0.99 + 0.246 + 0.246 = 1.972, against a total of 1.97.
    - In the launch window, 7 imdTEST reads "4.15 + 0.09 + 2.77 = 7.00", which adds to 7.01. 2 imdTEST adds to 2.01, and 48 to 48.01.
    - After Max, the line ends "= 270.15 imdTEST you pay" while the Balance aside and the field show 270.14. "You pay" rounds up and Balance rounds down.
  - The rest of round-1 T5 is done; keep it: per-input amounts, the launch-fee row, and the dead rows (no prize pot, wall 0.50%).
- **Should:** Round-1 T5. buy.html lines 102-111 list the rows Price, Minimum, Reaches the pool, the total "Fees, 2.25%", then the is-part rows "(0.50%)", "(1.00%)", "(0.25%)" and "Burned (0.25%)". Its sum line says "the four parts add up to" the total. The sum line adds up to the amount paid. Round-1 X19: costs the wallet pays round up, everything else rounds down.
- **Fix:**
  1. Write one helper that returns the display strings. #/buy uses it, and Home's sentence uses it (T6).
     - Keep the exact bigints as computed now (:276-282): fee, R, cashback, owner, prize and wall (the wall adds the prize share after the death). Launch fee = fee − R × `IMD_FEE_BPS` / 10000.
     - Round each value once: cashback down at 2 decimals, owner up at 2, prize pot and wall up at 3, and launch fee up at 2.
     - "Fees, 2.25%" = the sum of the rounded parts. Print a third decimal only when it is not 0.
     - "You pay" = the amount exactly as the field shows it. After Max, that is the Balance aside's value, rounded down to 2 decimals. This is the one place where "you pay" does not round up (round-1 X19): after Max the wallet pays its whole balance, and the line must match the Balance shown.
     - "Reaches the pool" = you pay − the fee total − the launch fee, with as many decimals as the fee total.
     - At 100 imdTEST this gives "98.028 imdTEST reaches the pool + 1.972 imdTEST fees = 100.00 imdTEST you pay", with the parts 0.49 + 0.99 + 0.246 + 0.246. After Max, the line ends at the Balance shown.
  2. Show the rows in buy.html's order:
     - "Price" with "1M PLEA = 14.16 imdTEST" (= `priceX96 × 10^24 / 2^96`, buys only).
     - "Minimum, 1% slippage".
     - "Reaches the pool".
     - The total "Fees, 2.25%", with "+ 0.25% of the PLEA" in its value as now.
     - The parts: "Back to you as cashback (0.50%)", "Owner (1.00%)", "Season prize pot (0.25%)" (while the Cabal lives), "Buy wall (0.25%)" (0.50% after the death) and "Burned (0.25%)" with "0.25% of the PLEA".
     - In the launch window, "Launch fee (66.6%), to the buy wall", with the side panel's 1-decimal value.
     - Print every percentage from its bps constant with 2 decimals.
  3. Give each Costs row a kind (`"part"` or `"total"`) to replace the index list, so the classes follow the rows when rows are added or dropped.

### T3 (P1) A sell after the death counts the cashback twice [rT-2]
- **Now:** #/buy, Sell, after the death. The toast and the inline fill read "Sold 80,000,000 PLEA for 383.05 imdTEST. 1.94 imdTEST cashback paid to you." The receipt has PoolManager→seller 381.110251, which matches the quote of ≈ 381.11, and PleaHook→seller 1.944440, which is the CashbackPaidPlain transfer. `received` (pages-trade.tsx:415-421) sums every imdTEST Transfer to the wallet.
- **Should:** Round-1 T3, Fix 4 (read the fill from the receipt): "Sold 80,000,000 PLEA for 381.11 imdTEST. 1.94 imdTEST cashback paid to you."
- **Fix:** On a sell, `received` counts only the imdTEST Transfers from the PoolManager to the wallet. The PleaHook→wallet Transfer is the cashback (PleaHook._payCashback, CashbackPaidPlain), and it stays in its own sentence. The same text feeds `setFill` and the saved done line. Buys need no change: their PLEA comes from the PoolManager.

### T4 (P2) Swap card states: no skeleton while the quote loads, a stale note under the button, and a done state that re-checks the traded amount [T7, rT-4, rT-V1]
- **Now:** #/buy, at every width:
  - **Quote loading.** You get is an empty input with the "Reading the pool…" aside and no skeleton__line (pages-trade.tsx:513-534). AmountInput (components.tsx:510-553) has no loading mode.
  - **The note under the button** (:690-696). When the allowance already covers the amount, it still says "One approval for imdTEST, then the buy. …". After a confirmed trade, "Step 1 of 2: lets the buy/sale spend exactly … Nothing is bought/sold yet." sits under "Confirmed".
  - **After a confirmed trade that spent more than half the balance** (every Max trade), the card re-checks the old amount against the new balance:
    - You sell turns is-invalid, with "You have 36,757,974 PLEA. Lower the amount or press Max." under it and again under the button.
    - The quote re-reads to "≈ 0.03" and "Minimum, 1% slippage 0.03 imdTEST", next to "Confirmed" and the fill line.
    - The causes are `invalid` (:259), `amountReason` (:260-266) and the quote's useRead (:229-241), which re-runs on every snapshot.
    - "Make another trade" (:698-708) resets the transaction but keeps the amount.
  - The rest of round-1 T7 is done; keep it.
- **Should:** buy.html's "Quote loading" reference: skeleton__line skeleton__line--mid inside `.input.input--readonly`, aria-busy, and "Waiting for the quote from the pool.". Round-1 T12's step notes. rT-4: no approval step is mentioned when the allowance covers the amount. What works 16: the done state keeps its link, and "Make another trade" resets the form.
- **Fix:**
  1. Give AmountInput a `loading` prop. While `quote.loading` and no earlier quote exists, render the mockup's markup: `<span class="field__label">`, then `.input.input--readonly` holding `<span class="skeleton__line skeleton__line--mid" aria-hidden="true">` and the unit, with `aria-busy="true"` on the field.
  2. Choose the note under the button by state:
     - While `needsApproval`: "Step 1 of 2: lets the buy spend exactly 50.00 imdTEST. Nothing is bought yet." (kept).
     - When the allowance covers a buy: only "0.24 imdTEST cashback is paid to you in the same transaction.", or no note in the "pool" payout mode.
     - When the allowance covers a sell: no note.
     - In the done state: no note.
  3. **Done state** (`tx.done && !approved`):
     - Keep the quote used in `prepare` in state and show it frozen.
     - Pause the quote read, the balance and cap checks, and the costs.
     - Show only "Confirmed", the link, the fill line and "Make another trade".
     - "Make another trade" also clears the amount (input "", maxRaw undefined).

### T5 (P2) "Your PLEA": no Balance label, an unsigned P/L, a bare open-plea line, the old selling text, and a 0.00 price and a Plead link before the seed [T8, rT-6]
- **Now:** pages-trade.tsx:750-820, with a wallet connected:
  - The balance is a bare stat__value with no "Balance" label (:753-755).
  - P/L uses `toFixed(1)` with no "+" and a hyphen-minus: "2.7%", "-31.3%" (:781).
  - An open plea shows only "Plea #N is open." (:797), with no sell-by time and no next-plea times.
  - While the Cabal lives, "What selling takes" reads "An approved plea, then a sale within the sell window. Your facts set the need." (:792).
  - Before the seed:
    - The panel shows "Now, at 0.00 imdTEST per 1M · No buy record", because :779 falls back to 0n.
    - It also shows "Plead to sell →" (:806-810), which has no seeded check.
  - The rest of round-1 T8 is done; keep it.
- **Should:** buy.html lines 127-141 show:
  - the "Balance" stat__label;
  - "Now, at 14.16 IMD per 1M −18.0%";
  - "A plea. The Cabal scores why you sell. Your hold time and profit or loss above are two of the four facts that set your need (71 − fact score); a new buy updates both.";
  - "**Plea #214 is open: sell by 08:06 UTC.** Next plea 4 hours after the sale (12:00 UTC if sold now), or 11:59 UTC if it lapses."

  The contract: CabalGate._clearStale sets lastLapsedAt to the plea's verdictAt (CabalGate.sol:494), and `_cooldown` adds COOLDOWN to it. The brief: "Until PleaHook.seeded is true, Buy, Plead and Letters say trading is not open yet."
- **Fix:**
  1. Write the balance as `<p><span class="stat__label">Balance</span><span class="stat__value">…</span></p>`.
  2. Write P/L as "+2.7%" for a gain, "−31.3%" (U+2212) for a loss and "0.0%" at zero.
  3. While the Cabal lives, use buy.html's text, with 71 read from `CabalGate.PASS_MARK`.
  4. Write the open-plea line as `.small`, with its first sentence in `<b>`:
     - **Approved and within the window:** "Plea #N is open: sell by HH:MM UTC. Next plea 4 hours after the sale (HH:MM UTC if sold now), or HH:MM UTC if it lapses."
       - sell by = verdictAt + `EXECUTE_WINDOW`;
       - if sold now = now + `COOLDOWN`;
       - if it lapses = verdictAt + `COOLDOWN`;
       - "4 hours" = `span(COOLDOWN)`.
     - **Pending:** "Plea #N is open: waiting for the verdict, usually 3 to 6 minutes."
     - Compute these times in one helper that Plead's open-plea notice also uses (C1).
  5. Until `PleaHook.seeded`, drop the "Now, at …" row and the "Plead to sell →" link. Keep the "What selling takes" text.

### T6 (P2) Home "Fees and supply": hardcoded supply shares, a fee sentence without its parts, and short percentages [T10]
- **Now:** #/ and #/contracts, details.tsx:
  - The supply shares are fixed fractions of TOTAL_SUPPLY (`total * 82n / 100n`, :96-107).
  - The 100-imdTEST sentence (:67-77) gives only "98.03 imdTEST reaches the pool…", with no fee and no parts.
  - Percentages read "0.5%", "1%" and "0.25%" (:47-64), and the bonus row says "first 6 seasons" (:101).
  - "Total", "Total PLEA at launch" and "Supply now" are not `.total` rows, and "Burned so far" has no minus sign.
  - The Rebalance sentence (:80-83) is shorter than round-1's and hardcodes "imdTEST".
  - D2 holds and the rest of round-1 T10 is done; keep both. There is no "Fund the buy wall", no approval to PleaHook, and Rebalance is a small button shown only when work is pending.
- **Should:** index.html section 5 (from line 296):
  - percentages "0.50%", "1.00%" and "0.25%", with "Total 2.25%" as a `.total` row;
  - "The IMD parts are taken from the IMD that reaches the pool. On a 100 IMD buy, 98.04 IMD reaches the pool and the fee is 1.96 IMD: 0.49 back to you, 0.98 to the owner, 0.245 to the season prize pot and 0.245 to the buy wall; 0.25% of the PLEA is burned.";
  - "in each of the first six seasons";
  - "Burned so far −26,134,870";
  - `.total` rows for "Total PLEA at launch" and "Supply now".

  Round-1 T10, Fix: shares = mint events ÷ TOTAL_SUPPLY, plus its Rebalance sentence.
- **Fix:**
  1. Build the fee sentence from T2's helper at 100 imdTEST, so Home and #/buy agree: "The imdTEST parts are taken from the imdTEST that reaches the pool. On a 100 imdTEST buy, 98.028 imdTEST reaches the pool and the fee is 1.972 imdTEST: 0.49 back to you, 0.99 to the owner, 0.246 to the season prize pot and 0.246 to the buy wall; 0.25% of the PLEA is burned." After the death, drop the prize pot ("… 0.99 to the owner and 0.491 to the buy wall"). Keep "Launch fees come on top during the opening window."
  2. Print percentages from the bps constants with 2 decimals. Write "first six seasons", spelling out `Seasons.BONUS_SEASONS` as a word.
  3. Use the T2 row kind `"total"` for "Total", "Total PLEA at launch" and "Supply now", and write "Burned so far −40,485 PLEA".
  4. **Supply shares.** Read the three PLEA `Transfer(from = 0x0)` logs. All three are in block 11948819 (= `PLEA.deployBlock()` = `APP.eventStart`), which the history scan already reads; with no history, one eth_getLogs for that block. Show the amounts minted to PleaHook, Seasons and PleaDistributor, with share = amount × 100 / `TOTAL_SUPPLY`.
  5. **Rebalance.** Use round-1 T10's sentence, with the pair symbol read from chain: "Anyone may press this, unpaid: it burns the PLEA the buy wall has bought and places all the imdTEST the hook has collected as one buy wall just below the price. The imdTEST never leaves the pool."

## C. The court

Scope: #/plead, #/p/<id> (the sale panel, the appeal box, the points, objections and judges panels, the timeline and details), #/objections, #/letters, the api.imd.fun oracle data shown on plea pages, and the text boxes (the Display name box on #/profile included). "Now" cites web/src at cc33304. Round 1's C conventions still apply: write imdTEST for IMD, Sepolia and sepolia.etherscan.io for Ethereum and etherscan.io, window lengths in words, and `now > deadline` means past. Round-1 C1–C4, C6–C8, C12, C14, C18 and C21–C23 are fixed. Keep them.

### C1 (P1) Plead's open-plea notice gives a stale "if it lapses" time [rC-1]
Continues round-1 C9, its "Open plea, approved" row (the rest of round-1 C9 is C8).
- **Now:** On #/plead, for a wallet with an approved open plea, at any width, the notice reads "Sell by 08:08 UTC. Next plea 4 hours after the sale, or 07:55 UTC if it lapses." The 07:55 is `balance.data.cooldown`, which is left over from the previous sale and already past. A lapse really runs to 12:01 (verdict 08:01 + 4 h). There is no "if sold now" time (pages-trade.tsx:1199).
- **Should:** Round-1 C9: "Sell by HH:MM UTC. Next plea 4 hours after the sale (HH:MM UTC if sold now), or HH:MM UTC if it lapses. Open plea #N". A sale sets lastExecutedAt = block.timestamp (CabalGate.sol:624). A lapse sets lastLapsedAt = verdictAt (CabalGate.sol:491-494). `_cooldown` adds COOLDOWN to each (CabalGate.sol:479-482).
- **Fix:** Let v = pendingPlea.verdictAt and C = CabalGate.COOLDOWN. Print `Sell by ${clock(v + EXECUTE_WINDOW)}. Next plea ${span(C)} after the sale (${clock(now + C)} if sold now), or ${clock(v + C)} if it lapses.`, then the "Open plea #N" link. Compute the three times with the helper T5 (fix 4) adds for "Your PLEA", so #/buy and #/plead agree. Re-render it with `now`. Never print `balance.data.cooldown` in this notice.

### C2 (P1) Sale panel: a sustained plea is told its points count, and the objection, sustained, overturned and upheld blocks are missing [C5, rC-V2]
Continues round-1 C5. The appeal-box eligibility, PENDING, the NO VERDICT reasons, LAPSED, "Appealed as plea #N" and "The appeal window closed…" are done; keep them.
- **Now:** On #/p/<id>, at every width:
  - **Sustained inside the sell window, seen by the seller:** "Miss it and the plea lapses (the points still count)." (pages-court.tsx:770-773). After the lapse: "The 0 points still count for season 1." (SaleSummary LAPSED, :1646-1657), next to "No points". The WindowLapsed error also says "Your +N points still count." (:840).
  - **Sold with a pending objection:** only the Sold and Points rows. There is no objector and no held line (status-4 branch, :1574-1626).
  - **Sold and sustained:** there is no branch at all.
  - **OVERTURNED:** "#4 was denied. This appeal overturned that verdict: 41 vs need 37 at 03:41 UTC." (:1627-1632).
  - **UPHELD:** only "No further appeal…" (:1687-1694).
  - **The denied seller:** reads "The seller may appeal once, until 07:57 UTC." above their own box (:1702). The box's countdown is labelled "Appeal window 3h 59m" (:321-324).
- **Should:** Round-1 C5 and plea.html's band (lines 338-430). Tribunal.standing (Tribunal.sol:194-206): sustained means no points, and so does an excluded seller. A ruling is sustained when `score + MARGIN < need` (Tribunal.sol:330), that is at need − MARGIN − 1 or less. Settle returns a sustained or void stake to the objector (Tribunal.sol:372-381).
- **Fix:**
  - **Sustained (`p.standing[1]`) or excluded:**
    - The sell-window note ends "Miss it and the plea lapses.", and WindowLapsed drops its points sentence.
    - LAPSED reads "An objection was sustained: no points for this plea." For an excluded seller: "This seller is excluded from season points."
  - **OBJECTION pending** (an objection with ruling 1, status 4 or 5):
    - "Objection #9 by <name or 0x…>:" and its text as plea__text.
    - Then "+N points held until the second panel rules. Sustained if the new score is S or less (more than M below the need N). The sale stands either way: X PLEA sold for Y imdTEST at HH:MM UTC.", with S = need − Tribunal.MARGIN − 1 and M = MARGIN (plea.html: "33 or less (more than 2 below the need 36)"). For LAPSED, end with "Nothing was sold." instead.
  - **SUSTAINED:**
    - "Objection #8 by <objector>: a second panel re-scored it S (A of B agreed). The first panel gave Y." S is the objection's newScore and Y is p.score. Show "(A of B agreed)" only when the oracle gives it (C4).
    - Then "No points for this plea. The sale stands: X PLEA sold for Y imdTEST at HH:MM UTC." For LAPSED: "No points for this plea. Nothing was sold."
    - Then the stake: "The objector's 0.35 imdTEST stake was returned." if settled, else "The objector's 0.35 imdTEST stake goes back when anyone calls settle." The amount is Tribunal.STAKE.
  - **OVERTURNED:**
    - Read the original from s.pleas or CabalGate.getPlea(originalId): "#O was denied, X vs need N, at HH:MM UTC. The appeal scored Y at HH:MM UTC."
    - Then the rows Sold N PLEA / For X imdTEST / Points "+P (Y × 1.2, seat)". Show "× 1.2, seat" only for a seat holder.
  - **UPHELD:** "#O was denied, X vs need N, at HH:MM UTC. The appeal scored Y at HH:MM UTC: denied again." before "No further appeal…", then the C4 judge line when it is available.
  - **The seller with the box shown:** "You may appeal once, until HH:MM UTC." Other viewers keep "The seller may appeal once…".
  - **Box countdown:** label `Appeal until ${clock(end)}` plus the time left, and aria-label "Appeal until 11:53 UTC, 3 hours 53 minutes left" (plea.html:274). Add an optional `ariaLabel` prop to Countdown for this.
  - **Sale times ("at HH:MM UTC"):** use the SellExecuted or Delivered block time (C12).

### C3 (P1) Objection cases: voided objections are counted, and closed cases read as open [rC-V1, rC-9, rC-V3, rC-8]
- **Now:**
  - **The plea page counts voided objections.** The pill and the closed line count every objection, voids included. Plea #7 has one OVERRULED, one VOID and a free slot, and reads "2 of 2 filed" and "Objections closed at 04:15 UTC · 2 of 2 filed.". #/objections shows the same case as "1 of 2 filed · one slot left" (pages-court.tsx:951-953, 994-996, `p.objections.length`).
  - **A full case reads as open on the plea page.** After two rulings inside the window, plea #12 still says "Others may until 03:02 UTC…" (:942-965). The timeline says "Objections: Closed at 03:02 UTC" at 02:44 (details.tsx:285-300).
  - **#/objections, sustained case:** plea #5, closed by a sustained ruling, still shows "Objections close in 16:29", "1 of 2 filed · one slot left" and "Objections closed at 04:15 UTC" while that time is still to come (ObjectionForm, pages-court.tsx:1178-1190, 1212-1219).
  - **#/objections, two rulings:** `closed` ignores a case with two rulings (:1133-1138), so it falls through to "Two objections are pending" (:1220-1234).
  - **#/objections, past the window:** ?plea=7 also keeps "one slot left".
  - **"Open now":** it keeps closed cases (:1291-1299), and the meta reads "1 approved pleas" (:1345).
  - The refused-text line (the rest of rC-8) and the "Already recorded" line (the rest of rC-9) are fixed in C11.
- **Should:** Round-1 C17 and C18: the pill is "N of 2 filed", from Tribunal.caseOf count + pending. A void frees its slot (Tribunal.sol:79-81, 383-393). A case is closed once sustained, once count ≥ MAX_OBJECTIONS, once recorded, once the seller is excluded, or after the window (Tribunal.object, Tribunal.sol:259-275). objections.html's "Window closed" band shows the pills "Objections closed at 08:07 UTC" and "0 of 2 filed", with no countdown.
- **Fix:**
  - **One helper, `caseState(p, s, now)` in chain.ts:**
    - `filed`: the objections with ruling 1, 2 or 3, never 4.
    - `closed`: the first reason that applies: sustained ("objection #N was sustained"), rulings ≥ MAX_OBJECTIONS ("both objections were ruled"), recorded ("the points were recorded"), seller excluded ("the seller is excluded"), or now > verdictAt + OBJECTION_WINDOW ("at HH:MM UTC").
    - `full`: !closed && filed ≥ MAX_OBJECTIONS.
  - Use the helper in the plea page panel, the timeline step, ObjectionForm and the Objections table.
  - **While the case is open:** show the countdown and "Others may until…".
  - **Once closed:** show the pill "Objections closed at HH:MM UTC" (window) or "Objections closed: <reason>", plus "N of 2 filed". The timeline step reads "Closed: <reason>" and never shows a future time.
  - **"one slot left":** add this suffix only while the case is open and filed = MAX_OBJECTIONS − 1.
  - **"Open now":** list only open cases. ?plea=N shows its card in the closed state.
  - **Full-case line:** "Two objections are pending on plea #N. Nothing to send." only when both slots are pending. With one ruling and one pending: "Objection #N is pending and the other slot has a ruling. Nothing to send."
  - **Meta:** "1 approved plea" / "N approved pleas".

### C4 (P2) Oracle data is rendered unchecked, and nothing catches a render error [rD-9]
- **Now:** oracleRequest returns api.imd.fun's JSON as it comes (oracle.ts:9-16, 29-37).
  - The plea page renders `oracle.data.panelSize`, `attestation?.agreed ?? agreement?.agreed` and `comment` as React children (pages-court.tsx:706-716, 1068-1072).
  - If any of these is an object, React throws "Objects are not valid as a React child". web/src has no error boundary (App.tsx:282-330 renders the route bare), so the whole app goes blank. The risk is latent: today's answers carry integers and no `comment` field.
  - A missing panelSize prints "Judged by Panel judges". A missing agreed count prints "Agreement pending" on a judged plea.
- **Should:** The brief reads oracle requests from api.imd.fun, a third party. Round-1 C22: the on-chain verdict is the source of truth. What works 18: text is rendered safely. A bad response may hide the judge line, never the page.
- **Fix:**
  - **oracle.ts returns only `{ id: string, panelSize?: number, agreed?: number, comment?: string }`:**
    - id must equal the requested uuid.
    - Numbers must be safe integers with 0 ≤ agreed ≤ panelSize ≤ 1000.
    - comment must be a string, cut to 280 characters.
    - Drop anything else.
  - **Judge line:** "Judged by {panelSize ?? CabalGate.PANEL_SIZE} · {agreed} agreed · {elapsed}". Leave out "· N agreed" when it is absent. Add "A judge said: “…”" only when there is a comment.
  - **Details "Panel" row:** "30 seats, quorum 17: 26 of 30 agreed, in 4m 10s" (round-1 C15). Show the agreed part only when it is known.
  - **Error boundary:** a class component with getDerivedStateFromError, around the routed page inside `main` in App.tsx and keyed on the route. The header, strip and footer stay. Its fallback is the kit's error-box (role="alert", i-warning-circle): "Can't show this page" / "Part of this page failed to draw. Nothing was sent; your funds are not affected.", then a `.btn-row` with Try again (resets the boundary) and a btn--sm Home link.

### C5 (P2) Plea page panels are written as the seller's own for other wallets and visitors [C17, rC-2]
Continues round-1 C17. The approved-only panel, the countdown, the Object link and the after-window line are done.
- **Now:** On #/p/<id> for approved-family pleas:
  - Another wallet and a visitor both get the seller's paragraph "You can't object to your own plea. Others may until…" (pages-court.tsx:955-965). The seller's own version lacks "(more than 2 below your need of N)" and "and then no points".
  - A visitor gets only the notice (:983-990): no aria-disabled Object button and no "Connect a wallet first…" line.
  - A pending objection reads "OBJECTION pending · “…”", with no objector (ObjectionLines, :1542-1555).
  - "Your points" with "Record my points" shows for everyone (:877-933). A visitor sees "Your points +50 points held".
- **Should:** plea.html:147-166 is the seller's view. The bands "Seen by someone else" (plea.html:432-440) and "Not connected: a visitor" (:442-449) show the other two. Seasons.record has no caller check (Seasons.sol:221-232), so anyone may record.
- **Fix:**
  - **The seller's objections panel:** "<b>You can't object to your own plea.</b> Others may until HH:MM UTC, for a 0.50 imdTEST fee + 0.35 imdTEST stake. A new panel of 30 re-scores it: sustained only at S or less (more than M below your need of N), and then no points. Void if that panel splits or gives no answer within 20 minutes: nothing changes. The sale is never touched." S = need − MARGIN − 1 and M = MARGIN, as in C2 (plea.html: "30 or less (more than 2 below your need of 33)").
  - **Another wallet:** no paragraph. Show the Object link, then "0.50 imdTEST oracle fee + 0.35 imdTEST stake. A new panel of 30 re-scores it; the sale is never touched."
  - **A visitor:** the notice, an aria-disabled btn--primary btn--block "Object 0.85 imdTEST", and "Connect a wallet first. Objections close at HH:MM UTC.", tied to the button with aria-describedby.
  - Read every number from Tribunal (ORACLE_FEE, STAKE, PANEL_SIZE, MARGIN, PENDING_EXPIRY, OBJECTION_WINDOW).
  - Show the objection panels in the state C3's `caseState` gives.
  - **Pending objection line:** "OBJECTION #9 pending by <name or 0x…> · “…”".
  - **Points panel:** the seller gets the title "Your points" and the button "Record my points". Anyone else gets the title "Points" and the button "Record the points".

### C6 (P2) Fact cells show points only, with no values and no sum [C10, C15]
Continues round-1 C10 and the facts part of round-1 C15. The order, lead, timeline, rules panel and totals are done. The NO VERDICT part of round-1 C15 is C7.
- **Now:** FactCells puts "+points" in fact__value and has no fact__pts and no value (components.tsx:1199-1236), so the cells read "Share sold +9 / Held +0 / …". Plead's aside reads "From the chain: 27" (pages-trade.tsx:1073-1077). The same cells appear on the plea card, the Home hero and Profile (components.tsx:996, 1091; profile.tsx:401).
- **Should:** plead.html:95-100 and plea.html:111-116: fact__value "20%" / "3d 4h" / "−18%" / "flat" with fact__pts "+16", and the aside "From the chain: 16 + 4 + 13 + 5 = 38". The .facts group has role="group" and aria-labelledby the label. The bands are CabalGate._factScoreAt's (CabalGate.sol:269-298).
- **Fix:**
  - **factParts (models.ts:69-129) also returns the values:**
    - shareBps: the ceil it already computes.
    - heldFor: now − avgBuyTime, or null when there is no buy record.
    - pnlBps: (value − spent) × 10000 / spent, or null when spent is 0.
    - trend: "up" (latest > 102% of price24hAgo), "flat" or "down", as the contract bands it. When price24hAgo is 0 the contract scores flat (+5): show "flat".
  - **FactCells renders `fact__value`:**
    - Share: "20%" (two decimals when not whole).
    - Held: heldTime(), e.g. "3d 4h" or "42 min".
    - Profit or loss: a signed "−18%" / "+12%" (U+2212 for the minus).
    - Trend: "up", "flat" or "down".
    - Any null value: "no data".
  - **FactCells also renders `fact__pts`:** "+N".
  - **Two-cell fallback:** the "Held, profit and trend" layout keeps the share value.
  - **Aside:** "From the chain: S + H + P + T = total" when parts.total equals CabalGate.factScore and no PLEA is uncovered. Otherwise "From the chain: total".
  - **On the plea page:** the values come from historicalFacts (chain.ts:726-790), at the submit block.
  - This one FactCells change also serves the Home hero (X7).

### C7 (P2) Finished NO VERDICT pages keep pending-era copy [rC-6]
Continues round-1 C15 (the timeline per state; C15 is indexed under C6) and C21 (the NO VERDICT subs).
- **Now:** On refused #11, split #15 and expired #6 and #7, at every width:
  - The timeline keeps "Waiting for the Cabal · Usually 3 to 6 minutes." as is-now (details.tsx:273-279).
  - "The judges" says "Verdict: Waiting" (pages-court.tsx:694).
  - An expiry with no PleaFailed log says "Cleared at once by the Intake" (SaleSummary, :1670-1686).
  - The share card prints "0 of 0 judges agreed · 17 needed". The refused plea's post text says "no answer" while its stamp says "request refused" (share.tsx:189-197, 343).
- **Should:** Round-1 C15 (steps per state) and C21 ("request refused" / "no answer" / "panel split A/B"). The Intake clears only the failures it reports, through onPleaFailure, which emits PleaFailed (CabalGate.sol:568-583). An unanswered plea simply goes stale after PENDING_EXPIRY (CabalGate.sol:500-504). Neither sets a cooldown (CabalGate._expire).
- **Fix:**
  - **One helper, `noVerdict(p, s)`:** it returns the sub ("request refused" / "no answer" / "panel split A/B"), the sentence ("The request was refused." / "No answer within 20 minutes." / "The panel split: A of B agreed (17 needed).") and the time (the PleaFailed block, else submittedAt + PENDING_EXPIRY). Use it in the stamp (components.tsx:877-884), SaleSummary, the timeline, The judges and share.tsx.
  - **Timeline:** "No verdict · <sentence>" as is-done with the gavel icon, then "No cooldown · The seller may plead again at once." as is-done.
  - **The judges:** the Verdict row reads "No verdict: <sub>".
  - **SaleSummary:** keep "Cleared at once by the Intake." only when a PleaFailed log exists. An expiry reads "The request expired at HH:MM UTC with no answer." Keep the no-cooldown and fee lines.
  - **Share card and post:** "No answer · No cooldown", with no tally. The refused post says "request refused". S13 asks for the same card change (rS-VN2): make it once, from this helper.

### C8 (P2) Plead states: no cooldown cause, the wrong not-connected line, no loading skeleton [C9]
Continues round-1 C9. The open-pending, cooldown, CannotPass, range and dead states are done; the approved open-plea notice is C1.
- **Now:** On #/plead:
  - The cooldown notice always says "4-hour cooldown after your last sale, denial or lapse." (pages-trade.tsx:1209-1214).
  - Without a wallet, the line under Submit is "Connect in the top bar to plead." This is Action's default (components.tsx:603-608) and repeats the notice.
  - While the facts load there is only the loading-label text (pages-trade.tsx:1082-1089): no icon, no skeleton, no aria-busy.
- **Should:** The round-1 C9 table: "4-hour cooldown after your sale.", saying denial or lapse when one of those set it. Not connected: "Connect a wallet first: your balance, facts and need come from it." Loading: plead.html's band "Loading: reading your facts" (plead.html:336-345).
- **Fix:**
  - **Cooldown cause:** WalletBalances (pages-trade.tsx:138-160) also returns which of lastExecutedAt, lastDeniedAt and the lapse time (lastLapsedAt, or the verdictAt of an approval whose window passed and is not cleared yet) is the latest. The notice body reads "4-hour cooldown after your sale." / "…after your denied plea." / "…after your plea lapsed.".
  - **Not connected:** pass connectText "Connect a wallet first: your balance, facts and need come from it." to both Submit buttons (pages-trade.tsx:1229-1262). ApprovedAction (components.tsx:727-838) must forward connectText to Action.
  - **Loading:** with a wallet, an amount and `fact.loading`, render a stack with aria-busy="true" holding the loading-label with i-hourglass ("Reading your balance and buy record from the chain…") and the skeleton (short line, block, mid line).

### C9 (P2) After seeding, Plead's costs with no amount say "after trading opens" and "At least 0.00" [C11, rC-4]
Continues round-1 C11. Every fee row, total and button label is done.
- **Now:** On #/plead, seeded, connected, with an empty amount:
  - Box on: "You get, if approved and sold: after trading opens" and "At least 0.00 imdTEST" (pages-trade.tsx:1144-1161).
  - Box off: both rows read "after trading opens" (:1169-1180).
  - The rows fall back to "after trading opens" whenever there is no quote, and "At least" computes from an amount of 0.
- **Should:** Round-1 C11 writes "after trading opens" only before the seed. Round-1 C10's line for an empty amount is "Enter an amount to read your fact score and need."
- **Fix:** Use one value function for the "You get" and "At least" rows in both modes:
  - not seeded → "after trading opens";
  - amount 0 → "enter an amount";
  - quote loading → "Reading the pool…";
  - quote error → "can't read the pool";
  - otherwise the values.

### C10 (P2) Letters and the appeal box give different PLEA figures for the same fee, and there is no NAME hex example [C19, rC-5, rC-V4]
Continues round-1 C19. The meta, commands, notices, fees, limits, examples, status and warning are done.
- **Now:**
  - On #/letters after seeding, the Letterbox card says "0.75 imdTEST, about 125,426 PLEA" and "What it costs" says "about 128,314 PLEA". The card skips the ÷ (1 − 2.25%) step (pages-info.tsx:277-289, against details.tsx:137-140).
  - In the appeal box, the "Paid in PLEA" row says "about 188,206 PLEA" and the "Or send APPEAL…" line says "about 188,205 PLEA". The row rounds up and the line rounds to nearest (pages-court.tsx:383-388 against 485-503).
  - The same estimate is coded four times (pages-trade.tsx:1013-1019, pages-court.tsx:1704-1712, details.tsx:137-140, pages-info.tsx:285-287).
  - The wallet data-field step has no NAME example (pages-info.tsx:322-338).
- **Should:** Round-1 C11: N = feeImd × 2^96 / latestPrice ÷ (1 − 2.25%), with the 2.25% from PleaHook.PLEA_BURN_BPS + IMD_FEE_BPS. letters.html:136: "For example, NAME mira_eth is 0x4e414d45206d6972615f657468."
- **Fix:**
  - Export one `feeInPlea(s, feeImd)`, a bigint that is undefined before the seed.
  - Add one text form: "about N PLEA" rounded up, else "after trading opens".
  - Use them in all five places (the four above and the appeal box's "Or send APPEAL…" line), and delete priceFee and the local copies.
  - Under the data-field step, add "For example, NAME mira_eth is <code class="addr__text">…</code>". Compute the hex with stringToHex, which pages-info.tsx already imports.

### C11 (P3) Disabled-button reasons: the connect text is guessed from the label, hides reasons that apply to everyone, and some reasons are generic or wrong [rC-3, rC-V5, rD-VN2]
A follow-up to round-1 X9. It also fixes the refused objection text (from rC-8) and the "Already recorded" line (from rC-9); both ids are indexed under C3.
- **Now:**
  - **Appeal box, empty or refused text:** "Waiting for the required chain state." This is Action's fallback (components.tsx:627-629); the Appeal reasons (pages-court.tsx:437-447, 474-480) have no text branch.
  - **#/objections without a wallet:** "Settle objection stake" and "Expire unanswered objection" read "Connect in the top bar to object.". Action builds the no-wallet reason by matching the label against regexes (components.tsx:604-622; pages-court.tsx:1508-1524).
  - **#/p/28 in a closed season, without a wallet:** the panel says "Season 1 is closed; these points were not recorded." but the button says "Connect in the top bar to record points.". Action puts the connect text before any reason (components.tsx:602-626). With a wallet it reads "Recording is closed for this season." (pages-court.tsx:903-929).
  - **A refused objection text:** "Write your objection to send it; nothing is paid until it passes." (pages-court.tsx:1157-1158).
  - **After Record:** the note says "Already recorded" (pages-court.tsx:920).
- **Should:**
  - Round-1 X9: every call site passes its own `connectText`, worded as in the mockups.
  - plea.html:315: "Appeal stays off until your text passes the checks; nothing is paid before that. Send it before 11:53 UTC."
  - Plead's line: "Fix the text above to submit. Nothing is paid until it passes."
  - objections.html:351: "The Tribunal refuses it: BadObjectionText. Fix the text above to object; nothing is paid until it passes."
  - A reason that no wallet can change is shown to every viewer, in the same words (round-1 X9).
- **Fix:**
  - **connectText:** make it a required prop of Action, ApprovedAction and TxButton, pass it at every call site, and delete the regex chain (components.tsx:604-622). Settle gets "Connect in the top bar to settle the stake."; Expire gets "Connect in the top bar to expire it.".
  - **New prop `lockedReason?: ReactNode`** on Action, passed through ApprovedAction and TxButton, for when no wallet can act now. When it is set, it shows instead of the connect and network texts, and the button stays aria-disabled.
    - Record (pages-court.tsx:903-929): season closed, points recorded ("+N points recorded."), objection sustained, seller excluded, and points held ("Record your +43 points after 08:19 UTC, when objections close.", plea.html:155).
    - Also a closed appeal window and a closed objection case (C3's `caseState`).
  - **Appeal, in both the auto and the manual branch:**
    - Empty text: the plea.html:315 line, with clock(verdictAt + COOLDOWN).
    - Refused text: "Fix the text above to appeal. Nothing is paid until it passes."
    - Facts not read yet: "Reading your fact score and need…".
  - **Objection text:** an empty text keeps its line; a refused, non-empty text gets the objections.html:351 line.

### C12 (P3) A manual sale shows no time [C16]
Continues round-1 C16. The delivered rows and the writer's amount everywhere are done.
- **Now:** On #/p/<id> for a plea the seller sold: "Sold 807,197 PLEA for 4.70 imdTEST", with no time (SaleSummary's manual branch, pages-court.tsx:1611-1615).
- **Should:** Round-1 C16: "Sold N PLEA for X imdTEST at HH:MM UTC" (SellExecuted.imdOut).
- **Fix:** Read the SellExecuted log's block timestamp with r.client.getBlock({ blockNumber }), cached per block as seasons.tsx:704 does, and append "at HH:MM UTC". C2's "sold … at HH:MM UTC" lines use the same time, from the Delivered block for letter sales.

### C13 (P3) The not-found plea page has no "Plead to sell" link [C20]
Continues round-1 C20. The breadcrumb, h1, empty copy and the read guard are done.
- **Now:** #/p/999 and #/share/999 show only "See the Wall" (pages-court.tsx:609-620, share.tsx:436-440). Empty takes a single action (components.tsx:102-125).
- **Should:** Round-1 C20: btn--sm "See the Wall" and a "Plead to sell" link, the link only while the Cabal lives.
- **Fix:** Let Empty take an `actions` list, rendered in a .btn-row. On both pages, add { href: "#/plead", label: "Plead to sell" } while CabalGate.cabalAlive and PleaHook.seeded are both true. S9 gives Empty an onClick action too; build both in the same change.

### C14 (P3) Text box details still differ from site.js [C13, rC-7, rS-N10]
Continues round-1 C13. The idle rows, the merged length row, counter--over and the code-keyed announcement are done.
- **Now:** In every plea, appeal, objection and letter box, and in #/profile's Display name box:
  - Extra issue rows use the x icon (components.tsx:398-405, 466-477).
  - The live line says "1 problems: …" (components.tsx:345). Typing "Kafka" in the Display name box announces "1 problems: Only lower-case a–z, digits 0–9 and _ are allowed…".
  - The letter's "Reads as:" notice uses Notice's default info icon (components.tsx:487, 92-95).
- **Should:**
  - site.js:128: warning-circle for extra problems, warning for warnings.
  - site.js:138: "1 problem:" in the singular.
  - letters.html:169: the Reads-as notice uses i-envelope-simple.
- **Fix:**
  - Mark the extra rows `extra: true` and give them warning-circle; warnings keep the warning icon.
  - Build the live line as `${n} ${n === 1 ? "problem" : "problems"}: …`, in the one place every box uses, the Display name box included.
  - Pass icon="envelope-simple" to the Reads-as Notice.

## S. Seasons, Wall, Profile, Claim, Share

Scope: #/seasons, #/wall, #/profile and #/profile/<address>, #/claim, #/share/<id>, and Home's live-number cells at 320 px. Round-1 S7, S8, S9, S12, S14 and S15 are fixed, so keep them. Every rule number (TOP, MIN_POINTS, shareBps, CLOSE_GRACE, the windows, SEAT_MULTIPLIER_BPS) comes from chain constants. Amounts use the pair symbol from chain (imdTEST). Line numbers are for web/src at cc33304.

### S1 (P1) Only one waiting season is shown, the rollover note names the wrong season, and the seat panel renders twice [S1, rS-VN1, rD-7]
- **Now:** (continues round-1 S1. The rest of S1 is done: one waiting season, the dead layout, the pots and the pre-seed state. Keep it.)
  - While the Cabal lives, with seasons 1 and 2 ended and not closed and season 3 running, #/seasons shows only "Season 1 ended · Awaiting close" and "Season 3". Season 2, with its own 0.02 imdTEST pot and its sellers' Record my points, appears nowhere. seasonState (chain.ts:689-707) knows only `awaiting = nextToClose`, and the snapshot reads only the displayed season and nextToClose (chain.ts:293-316).
  - The line "Seasons N to M wait to be closed, oldest first." prints only when the Cabal is dead (seasons.tsx:59).
  - The running season's pot note (seasons.tsx:307-313) and the Home stat (pages-info.tsx:143) say "plus what season {nextToClose+1} rolls over at its close". That gives "season 1" while season 3 runs, and "season 2" under season 8 after the death.
  - In the awaiting state SeasonView renders twice (seasons.tsx:53-68, 81). Each copy has `<div id="seat" />` (:472), so there are two #seat and #/seasons?seat=1 scrolls to the ended season's copy. The ended section's panels are h2 (Panel level={2}) under its own h2.
- **Should:** Round-1 S1: an ended season keeps its own board, standing and Record my points until its close, and the wait line shows when several seasons wait. closeSeason pays seasonFees[nextToClose] + rollover and leaves the unpaid part as the new rollover (Seasons.sol:320-348), so season k only ever receives what season k−1 rolls over. seasons.html:147 has one `<section class="panel" id="seat">`.
- **Fix:**
  - **Which seasons wait:** every k from nextToClose up to the last ended season, oldest first. That is displayed − 1 while the Cabal lives and displayed when it is dead. When more than one waits, print "Seasons N to M wait to be closed, oldest first." above the first, alive or dead.
  - The oldest waiting season keeps today's full "Season N ended" section.
  - Each season strictly between the oldest and the displayed one becomes a closed `<details className="panel">`. Its summary reads "Season N ended · Awaiting close · pot <seasonFees(k)> imdTEST". Add " · your plea #a, #b to record" when the connected wallet has approved, unrecorded pleas from that season (from the PleaSubmitted, Verdict and Recorded logs). Opening it mounts SeasonView(k).
  - SeasonView takes its data from s.v.seasons[k] when it is there. Otherwise it reads seasonBounds, seasonFees, topOf and closed(k) itself with useRead, so the global snapshot keeps its two season reads.
  - Its Close button keeps the existing reason "Close the oldest season first.".
  - **Pot note and Home stat:** for the season with 0-based index k, show the note only when k > nextToClose, and name the season before it. In 1-based words that is "Plus what season k rolls over at its close." (season 3's note names season 2).
  - Give SeasonView an `ended` prop. In an ended section or details block its panel titles and leaderboard head are h3, and it does not render the seat-multiplier panel.
  - Render the seat panel once, in the displayed season's view, as `<section className="panel" id="seat" aria-labelledby="seat-title">` (replacing the empty div), so Profile's #/seasons?seat=1 lands on it.

### S2 (P1) Seat holders' judges' scores print "?", and empty best-three slots print "0" [rS-N1, rD-VN1]
- **Now:** (continues round-1 S2 point 3 and round-1 S3's seat brackets.) judgeScores (seasons.tsx:243-255) compares each bestOf value with `Recorded.args.points`. That field is the wallet's running total (or 0), not the plea's points, so only a wallet's first record can match and every other slot prints "?". Your standing reads "Judges' scores, before × 1.2 · 40 · ? · ?" (seasons.tsx:389-396). The leaderboard reads "48 · 45 · 0(40 · ? · ? × 1.2)" and "54 · 0 · 0(45 · ? · ? × 1.2)" (:583-590).
- **Should:** Seasons._record emits Recorded(pleaId, season, wallet, score, pts), where score is the judges' score and pts = b[0] + b[1] + b[2] when the plea enters the best three, else 0. It also emits SeatMultiplier(pleaId, wallet, score, pleaPoints) when a seat changed the points (Seasons.sol:260-283). Among equal points the lower pleaId is kept. seasons.html:130 shows "Judges' scores, before × 1.2 · 34 · 33 · 31", :174 shows "45 · 44 · 43 (38·37·36 × 1.2)", and :194 shows "lamp_oil 33 · 28" (filled slots only).
- **Fix:**
  - Add one helper, `countedPleas(s, season, wallet, best)`. For each non-zero bestOf value, take the not-yet-used Recorded log of that season and wallet whose plea points equal the value, lowest pleaId first. A plea's points are its SeatMultiplier.pleaPoints if that log exists, else Recorded.score (the same as Seasons.pointsOf(pleaId)). Return {pleaId, score, multiplied}.
  - Use it for three things: Your standing's judges' row, the leaderboard bracket `<span class="seatx nowrap">(38·37·36 × 1.2)</span>`, and Profile's "also counts" line (S10). Show the row and the bracket when any counted plea was multiplied.
  - The leaderboard's "Best three" lists only the filled slots ("48 · 45"). Your standing keeps "a + b + c = N".
  - When a value finds no log (history still loading, or s.historyError), leave that row or bracket out. Never print "?".
  - X6's record toast reads the same logs; Recorded.points is never a plea's points.

### S3 (P1) After the death, the last season's leftovers are said to roll over to a season that never comes [rS-N6]
- **Now:** (continues round-1 S4's rollover row for the last season.) After the death, for the last season N, the lead correctly says "No season N+1 follows", but the page contradicts it in five places:
  - the 60-point bar says "the imdTEST share rolls over to season N+1" (seasons.tsx:559-567, 616-622);
  - "If the season ended now" reads "Rolls over to season N+1" (:640-641);
  - the Closing panel says "carries the unpaid prize shares forward" (:657-661);
  - Past seasons prints "Rolled over to season N+1" for it (:771-777);
  - the close toast says "1.22 imdTEST rolls over to season 10" (context.tsx:556-559).

  Every empty board, running, ended or dead, also says "The court is in session." (:543).
- **Should:** Once the last season closes, Seasons.finished() is true and flushToWall sends what is left to the buy wall (Seasons.sol:210-215, 355-370). Every close burns the unpaid PLEA bonus (Seasons._payBonus). The seasons.html dead band reads "The close records any approved plea nobody recorded and pays the top 25 with 60+ points in IMD and PLEA.", and "No more seasons" reads "What is left in Seasons goes to the buy wall…". For a running season, the band "A new season before its first recorded plea".
- **Fix:** With `last = dead && season === displayed`:
  - Bar: "60-point line · below it no prize: the imdTEST share goes to the buy wall", plus " and the PLEA bonus share is burned" when the season has a bonus (as every season's bar already does).
  - "If the season ended now": the row reads "Left for the buy wall".
  - Closing: the dead band's sentence above.
  - Past seasons, for the last season's SeasonClosedOut: "Left for the buy wall".
  - Close toast: "<x> imdTEST is left for the buy wall; <y> PLEA burned."
  - Every other season keeps "rolls over to season N+1".
  - Empty board, running season: the band copy "Season N has begun. The first approved plea to be recorded takes rank 1; its season prize pot starts with what season N−1 rolled over.", then "The gavel is polished and waiting." and "Write a plea". Drop the rollover clause for season 1.
  - Empty board, ended or dead season: "No points" / "No plea is recorded in season N. Approved pleas of season N can be recorded until it closes; the close records any that nobody recorded.", with no Write a plea.

### S4 (P1) Wall cards from "Load older pleas" never refresh [rD-5]
- **Now:** pages-court.tsx:58 keeps the older pages as Plea objects. loadMore reads them once (:103-118) and they are never read again, while the chips count from full history. After old plea #2 got its verdict, the chips read "Approved 10 · Pending 8" but the loaded #2 card still showed "PENDING · 14:47 left". An objection on #1 never appeared on its card.
- **Should:** The newest 24 cards refresh with every snapshot, and round-1 S6's counts come from full history. Every loaded card must agree with them.
- **Fix:** Keep the ids of the loaded older pleas. On each new snapshot, re-read with getPlea every loaded older plea that has a new log since the previous snapshot whose args.id or args.pleaId is its id (Verdict, PleaFailed, PleaExpired, PleaLapsed, SellExecuted, Delivered, Objected, Ruled, ObjectionVoid, Recorded). Replace that card in place, keeping scroll position and focus. Changes that depend only on time already come from pleaState(now).

### S5 (P2) Your standing: no rank-0 row, labelled Record buttons, the held-notice sentence, the no-plea band [S2, rS-N8, rD-11]
- **Now:** (continues round-1 S2. Own-plea filtering, the held and free states, record() and the closeSeason ids work. Keep them. The layout and seat-panel parts of round-1 S2 are S6.)
  - A wallet not on the board reads "Share at rank 0 · none yet" and "Prize now 0.00 imdTEST + 0 PLEA" (seasons.tsx:371-401, with rank = −1).
  - Each of the wallet's own unrecorded approvals gets a TxButton with the fixed label "Record my points" (:443-454), so two approvals give two identical buttons.
  - The held notice body is only "Record them after objections close. Nothing records them by itself." (:428-431).
  - The stats use `stats stats--3` (:357), so "Prize now 0.04 / imdTEST" wraps while half the card is empty.
  - With no plea, it reads "No recorded plea yet. Your best three approved pleas count here." (:459-467).
- **Should:** seasons.html:120-145 has:
  - stats in `div.cluster.standing`;
  - "Share at rank 4 · 4.38%";
  - the held notice "Recorded, they make 122 points (43 + 40 + 39; the 37 drops out) and rank 3: 8.14 IMD + 442,000 PLEA at today's season prize pot.".

  The band "Your standing for a wallet with no recorded plea" shows "Rank none yet", "Points 0" with "60 to share the season prize pot", "No approved plea of yours is recorded in season 2. Your best three count, and two pleas that score 30 already reach the 60-point bar; an IMD seat makes each one × 1.2." and Write a plea. The band "Record my points: after 08:19 UTC" reads "Objections on plea #214 closed. Anyone can record a plea's points; nothing records them by itself.". closeSeason pays rank i (0-based) potOf × shareBps(i) / 10,000 when its points ≥ MIN_POINTS, and the bonus in the first BONUS_SEASONS seasons (Seasons.sol:320-351, 440-460).
- **Fix:**
  - Stats: use `div.cluster.standing`, and copy seasons.html's `.standing { gap: var(--space-4) var(--space-6); align-items: flex-start; }` into site.css.
  - Not on the board (rank < 0): no Prize now stat and no "Share at rank" row. With 0 points, show the band's no-plea state, with MIN_POINTS/2 in the sentence and "Write a plea" only while the Cabal lives.
  - On the board but under MIN_POINTS: "Share at rank R" reads "no prize (P of 60)".
  - For each of the wallet's own pleas, put a line "Plea #N · +P points" (linked to #/p/N) above its button.
  - The button keeps the visible text "Record my points". Add an sr-only " for plea #N" (a new srLabel prop on TxButton/Action) and aria-describedby pointing at its reason. Once the plea is free, the reason is the band's "Objections on plea #N closed…" line.
  - Held notice body: the sentence above, worked out as follows.
    - P = pointsFor(seller, min(score, lowest)), the plea's points if recorded now. New best three = the top three of bestOf ∪ {P}. Add "; the d drops out" only when all three slots were filled and P is above the lowest.
    - R = 1 + the number of other topOf(season) wallets with at least N points.
    - Prize = potOf(s, season) (chain.ts:709) × shareBps(R−1) / 10,000 imdTEST, plus BONUS_PER_SEASON × shareBps(R−1) / 10,000 PLEA in a bonus season, when N ≥ MIN_POINTS, R ≤ TOP and the wallet is not excluded. Each rounded down. Otherwise end with "and rank R: no prize yet (N of 60)".

### S6 (P2) Seasons: the three panels in one row, and the seat panel's copy and label [S2, continued; indexed under S5]
- **Now:** (continues round-1 S2.)
  - seasons.tsx:258 puts Ends, Season prize pot and PLEA bonus in `auto-grid`. At 1280 that is two plus one, with PLEA bonus alone on row 2.
  - The seat panel (:471-511) reads "Seasons reads the identity.md seat NFT when points are recorded…".
  - Its rows read "36, with a seat · 43".
  - It prints the seat NFT as the bare 42-character address; "Seat NFT" appears only in the Copy button's aria-label.
- **Should:** seasons.html:85-116 puts the panels in `div.grid` with `md-span-8 lg-span-4`, `md-span-4 lg-span-4` and `md-span-4 lg-span-4`. The seat panel is at seasons.html:147-162:
  - Copy: "Hold an IMD seat NFT when your plea is recorded and its points are the judges' score × 1.2, rounded down."
  - Rows: "Score 36, with a seat · 43 points", "Score 45, with a seat · 54 points" and "Score 36, no seat · 36 points".
  - Note: "One seat or ten, the same…".
  - Address: `p.label` "Seat NFT · identity.md" over the short address, with Copy labelled "Copy identity.md seat NFT address".
- **Fix:**
  - Use that grid and those spans.
  - Port the seat panel's copy, rows (computed from SEAT_MULTIPLIER_BPS, rounded down as Seasons.pointsFor does), note and label.
  - Give AddressView an optional short display: short() on screen, with the full address in the link and in Copy. Use it here and on Profile's IMD seat panel (S10).

### S7 (P2) Leaderboard and the panels under it: column heads, SEAT badge, percentages, Closing states, loading and error [S3, rS-N2]
- **Now:** (continues round-1 S3. The bar placement, "no prize (N of 60)", the prize cells, YOU, names and the foot work. Keep them.)
  - The lb__head spans have no classes (seasons.tsx:547-553), so from 768 px "Points" and "Prize now" sit away from their columns.
  - Seat holders' rows have no "SEAT ×1.2" badge.
  - "Rolls over to season 2" reads "91.03999999999999% · 0.92 imdTEST", because :641 computes 100 − Number(shares)/100 in floats.
  - "Shares, as for the imdTEST" reads "4.5% to 3.5%" (:332).
  - Closing still reads "Anyone can close it from …" after the grace (:657-661).
  - The error box has no Try again (:523-527), and loading is a bare loading-label (:528-532).
- **Should:** seasons.html:173-199: the head has `<span class="lb__rank">Rank</span><span class="lb__who">Player</span><span class="lb__best">…</span><span class="lb__pts">…</span><span class="lb__prize">…</span>`, each row has `<span class="sr-only">Rank </span>`, and seat holders get `badge badge--seat` "SEAT ×1.2". seasons.html:204-221 uses `split split--even split--stretch`, shows "14.24% · 26.23 IMD" and has the rounding note. The bands "The leaderboard loading", "Read error" and "Close season 2 after the grace" ("The grace is over: anyone can close season 2 now. The close records any approved plea nobody recorded, pays the top 25 with 60+ points and rolls the rest over."). closeSeason reverts NotReady before end + CLOSE_GRACE (Seasons.sol:326).
- **Fix:**
  - **Head and rows:** give the head spans the lb__rank, lb__who, lb__best, lb__pts and lb__prize classes, and put sr-only "Rank " in each row's rank cell. Add badge--seat "SEAT ×1.2" (multiplier from chain) in lb__who for every holdsSeat row.
  - **Percentages:** add one helper, pct(bps) = (bps/100).toFixed(2) + "%". Compute the rollover share as 10000 − Σ shares in integers. Use pct for Paid to, Rolls over, Share at rank and the PLEA bonus shares ("4.50% to 3.50%").
  - **Closing, per state:**
    - not yet: the main mockup copy, a disabled button and its reason;
    - ready (now ≥ end + CLOSE_GRACE and this season is nextToClose): the band's "The grace is over…" copy;
    - last season: S3.
  - **Loading:** aria-busy on the panel, the real head, then a panel__body with the loading-label and the band's six skeleton lines.
  - **Error:** an error-box with role=alert, the title "Can't read the leaderboard", the body, and a btn-row Try again that calls X1's resetHealth() and then refresh(), as Profile's error box does.
  - **The two panels below:** use split--even split--stretch and the mockup's rounding note.

### S8 (P2) Past seasons: names, "(you)", the closer's checksum, the own row, an empty block [S4]
- **Now:** (continues round-1 S4. The pill, dates, costs and receipt link work, so keep them. The last season's rollover row is S3.)
  - The top rows print the short address and never call Letterbox.nameOf (seasons.tsx:790-795), and nothing marks the connected wallet with "(you)".
  - The closer is `short(tx.from)` in lower case (:762).
  - The rows come only from PrizePaid logs (:734-750). So a connected wallet that is ranked but unpaid gets no row, and a season where nobody was paid shows the h4 "Top three, and you" with nothing under it (:789).
- **Should:** seasons.html:225-262 has an `article.panel` per season: h3 and pill in cluster--between, then the meta, then split--even. One side has p.label "Season prize pot and bonus" with its costs and rounding note. The other has p.label "Top three, and you" with dl.costs rows such as "1 · one_shot, 129 points → 9.56 IMD + 450,000 PLEA" and "14 · mira_eth (you), 97 points → …". closeSeason leaves `_top[season]` in place, so topOf(season) still reads after the close.
- **Fix:**
  - Build the rows from topOf(season): ranks 1 to 3, plus the connected wallet's rank.
  - The prize is that wallet's PrizePaid + BonusPaid amounts for the season, or "no prize (N of 60)".
  - Names come from Letterbox.nameOf, with the mono short address when there is none, and "(you)" on the connected wallet.
  - Closer: short(getAddress(tx.from)).
  - When topOf is empty, replace the block with "No plea was recorded in season N."
  - Port the markup above.

### S9 (P2) Wall: port the page CSS, one "Show all pleas", a count line that names its filters [S6, rS-N5]
- **Now:** (continues round-1 S6. The families, counts, More filters, Sort, and the Next, busy and end texts work. Keep them.)
  - The page CSS in wall.html (:20-34) was never ported. So .wall-more is display:block, left-aligned and 0 px under the grid, and "That is every plea, back to #1." sits against the last card (pages-court.tsx:257-283).
  - The count line sits outside .wall-tools (:201-208). For Denied it reads "Showing #2 to #2: 1 of 29, newest first": it names no filter and uses the overall total.
  - For ?wallet= it reads "… · Showing pleas by 0x1eF0…842E" although that wallet is named seat_one (:205).
  - The empty state's action is `<a href="#/wall">` (:235), which does nothing while already on #/wall. A second "Show all pleas" button sits beside it (:247-250).
- **Should:** wall.html:20-34 and :101-131: the count line sits inside .wall-tools, and More filters' content is a `div.panel.wall-tools__panel` with two labelled groups. Also :222-225 and these bands:
  - "More filters open…": "Showing pleas sent by letter, newest first";
  - "Empty filter": one button, "Show all pleas";
  - "Loading older pleas": "The 12 cards above stay put.";
  - "The end of the Wall": p.strong, p.meta and a btn--sm.
- **Fix:**
  - Copy those rules into site.css and port that markup into Wall.
  - Count line: name every active filter in words: "approved pleas", "pleas sent by letter", "appeals", "sold pleas", "objected pleas", "by <name or short address>".
  - When a verdict chip is on, use that chip's count as the "of N", for example "Showing #2 to #2: 1 of 1 denied plea, newest first".
  - Read the ?wallet= name with Letterbox.nameOf.
  - Empty state: Empty's action becomes a button that calls reset() (give Empty an onClick action, in the same change as C13's `actions` list), and the separate button goes.
  - Busy text: name the count ("The 24 cards above stay put.").

### S10 (P2) Profile: badge in the title row, name preview, seasons table, "also counts", the dead state [S10]
- **Now:** (continues round-1 S10. Stats and notes, the open-plea notice, the buy record, "Your pleas", the lookup, loading and error work. Keep them.)
  - The SEAT badge and the "Read only" pill sit in a cluster under the lead (profile.tsx:249-262), not in .page-title, and the address comes after the lead.
  - The name preview is a plain `p.wall-card__who` with no badge (:436).
  - The seasons table always adds the displayed season (:110-121), so a wallet with no points gets the row "2 so far 0 none yet 0.00 + 0".
  - "so far" sits on the season cell even for an ended season; there is no "Nd Nh left", and the foot is generic (:552-574).
  - There is no "Season N also counts #… and #…." line.
  - After the death the stats still say "Next plea · Ready now · A sale, denial or lapse starts the cooldown" and "A plea: 14,822 PLEA to 741,102 PLEA" (:285, :298-301, :313).
- **Should:** profile.html:81-85, :140-141, :178 and :186-211. The death banner's "Pleas and objections are closed; sell on the Buy page." (_shell.html:68).
- **Fix:**
  - **Title:** give Title an aside slot inside .page-title holding the h1, badge--seat with the armchair icon, and, for another wallet, the pill "Read only". Under it, the address with Copy, then the lead.
  - **Name preview:** `div.wall-card__who` with `span.strong` for a name or `span.mono.strong` for an address, plus the SEAT badge when the wallet holds a seat.
  - **Seasons table rows:** one row per season with points > 0 or a prize. With no rows, show p.small "No plea of this wallet is recorded in any season yet." instead.
  - **Seasons table cells:**
    - season cell: "Season N" with a cell-note "closed, paid", "Nd Nh left" (running) or "awaiting close" (ended, not closed);
    - rank cell: "so far" as its note for open seasons;
    - prize cell: "<x> imdTEST" with a cell-note "+ <y> PLEA";
    - numeric cells: class r.
  - **Seasons panel:** use X4's flush Panel, with the head "Your seasons" and a "Season N leaderboard" link.
  - **Seasons foot:** "Season N's prize is rank R's share if it ended now. Prizes are rounded down and paid at the close, from <closeFrom>." When there is no rank, use only the second sentence.
  - **Under "Your pleas":** "Season N also counts #a and #b.", with links, taken from S2's countedPleas for the displayed season minus the two cards shown. Leave it out when empty.
  - **Dead:** "Next plea" shows "Closed" with the note "Pleas are closed; sell on the Buy page.", and the PLEA note becomes "Sells freely on the Buy page". Do the same in another wallet's stats.
  - **IMD seat panel:** the mockup copy and the "Seat NFT · identity.md" label with the short address (S6).

### S11 (P2) #/profile/<not an address> shows the viewer's own profile [rD-8]
- **Now:** profile.tsx:51 sets `wallet = target && isAddress(target) ? target : address`. So as p1, #/profile/0x1234 and an address with a broken checksum both render p1's own editable profile, with the name box and "Disconnect this wallet".
- **Should:** The not-an-address wording from round-1 S10 and S12: "That is not an address. Paste one that starts with 0x and has 40 more characters, 0–9 and a–f in either case."
- **Fix:**
  - When `target` is set and is not 0x plus 40 hex characters, render Title "Profile" and a notice--bad titled "That is not an address." with the rest of that sentence as its body.
  - Under it, show AddressLookup prefilled with the target, in its is-invalid state, and "Back to your profile" when a wallet is connected. Never fall back to `address`.
  - To match the sentence, accept 0x plus 40 hex in either case with isAddress(t, { strict: false }), and normalise with getAddress(t.toLowerCase()). Do the same in AddressLookup.

### S12 (P2) Claim: the mockup's vault list, Try again, and the vault message when the list fails [S11, rS-N9]
- **Now:** (continues round-1 S11. The numbers, lead, claimable notice, buttons, receipts and checksums work. Keep them. The unpadded "About the list" panel is X4 (rS-N3).)
  - Delegated vaults is a plain Panel that puts each vault, with its full address, in a nested `.panel` (pages-info.tsx:747-797, :770).
  - "Can't check the list" has no Try again (:663-668), and the fetch effect runs only on [isOpen].
  - With the root set but claims.json not loaded, each vault row says "The claim list is not open yet." (:513-517).
- **Should:** claim.html:101-151:
  - both panels are `panel--flush`, with a `panel__head` holding the h2 and the meta ("Final"/"Not set", and "delegate.xyz"), then a `panel__body stack`;
  - each vault is a dl.costs with Vault (short, mono) and Claimable;
  - the button reads "Claim 212,500 PLEA to the vault" with btn__sub "gas only";
  - the note reads "Sent from this hot wallet; the PLEA lands on the vault, which never connects.";
  - p.label "Read from the delegate.xyz registry".

  Also the bands "Delegated vaults: loading" and "Delegated vault already claimed", and :210, the error box with Try again.
- **Fix:**
  - **Panels:** build About the list and Delegated vaults with X4's flush Panel (meta "Final"/"Not set" and "delegate.xyz").
  - **Vaults:** lay them out as above.
    - Loading: the band's "Reading the delegate.xyz registry for <short>…" with a skeleton.
    - Already claimed: the notice "Already claimed for the vault <short>." with the receipt.
  - **Try again:** a btn-row btn--sm that bumps a reload key in the fetch effect's deps, with the mockup body.
  - **Vault message, by state:**
    - root zero: "The claim list is not open yet.";
    - loading: "Reading the claim list…";
    - load failed: "Can't check this vault: the claim list did not load. Try again above.";
    - loaded and the vault is not on it: the existing "not on the published list".

### S13 (P2) Share: the frame's label, the objection posts, the no-answer card [S13, rS-N7, rS-VN2]
- **Now:** (continues round-1 S13. Cards, badges, URLs, the X intent and the other posts work. Keep them.)
  - The share-frame role=img label is `Plea ${id}, ${state}, ${score} vs need ${need}, ${points} points.` for every state (share.tsx:99-103). So it reads "Plea 2, DENIED, 20 vs need 37, 20 points.", UPHELD reads "33 points", and SUSTAINED reads "42 vs need 37, 0 points" with the original score.
  - The post checks `p.status === 4` before SUSTAINED (:344). So a sold plea with a sustained objection posts "SUSTAINED: my plea, 30 vs need 37. Sold for 0.88 imdTEST."
  - A NO VERDICT plea that expired with no answer has no PleaFailed log, so its card shows "0 of 0 judges agreed · 17 needed" (:189-198).
- **Should:** The share-cards.html aria-labels (:113 to :383) follow "Share card for plea #N by <name>[, seat holder][, by letter][, the appeal of #M]: “<text>” <state sentence>. <link>", for example "Denied, 31 vs need 36. Appeal open until 11:53 UTC." and "Objection #8 sustained, 29 vs need 33: no points.". The posts at :342, :369 and :396 read:
  - "OBJECTION #9 to plea #211 by … (SOLD, 37 vs need 36): a new panel re-scores it, and 33 or less means no points."
  - "Objection #8 SUSTAINED: plea #209 by … re-scored 29 vs need 33, no points; the sale stands."
  - "Objection #7 OVERRULED: … re-scored 33 vs need 33, counts 39 points."
- **Fix:**
  - **Label:** build it per state from the card's own facts, using those sentences. Mention points only where the card shows them ("+N points held", "+N points"). Use "no points" for denied, upheld, sustained and no verdict, and the re-score for the objection states.
  - **Post:** handle OBJECTION, SUSTAINED and OVERRULED before the sold branch, with the mockup sentences. Use "my plea" for the seller, and need − Tribunal.MARGIN − 1 as the threshold.
  - **No answer (no PleaFailed log):** use C7's `noVerdict` helper (one change for both items).
    - card nums: "No answer · within <CabalGate.PENDING_EXPIRY in words>" and "No cooldown · no points";
    - label: "No verdict: no answer within 20 minutes. No cooldown."

### S14 (P2) Home live numbers overflow their cells at 320 px [S5, rS-N4]
- **Now:** (continues round-1 S5. The site.css overflow-wrap rule is gone, the Seasons PLEA bonus no longer breaks mid-number, and #/seasons and #/profile fit. Keep that.) On #/ at 320, light and dark, after the seed:
  - "Market cap 5,950 imdTEST" ends at 316 px against a cell edge at 303 px and is clipped to "5,950 imdTES".
  - "Price 5.95 imdTEST" and "Season prize pot 0.02 imdTEST" end right on the column divider.
  - Cause: each value is one nowrap span with the unit inside it (pages-info.tsx:168-178), and with the 7-letter imdTEST that cannot fit a 112 px cell. The unit test matches the literal " imdTEST" (:170).
- **Should:** The brief's QA (brief-site-job-run9.md:27) and PAGE-KIT.md:45 require no overflow at 320 px, and PAGE-KIT says a number never breaks inside its digits. .stats clips its cells with overflow:hidden (components.css:440). index.html's `.stat__value` is plain "14.16 IMD", free to wrap at the space.
- **Fix:**
  - Render the number and the unit as two nowrap spans with a normal space between them and no outer nowrap: `<span class="nowrap">5,950</span> <span class="nowrap small">imdTEST</span>`. A cell that is too narrow then drops the unit under the number instead of clipping it.
  - Take the unit from constants.pairSymbol.
  - **Done when** every Home stat value's right edge stays inside its cell at 320 and 360 in both themes, and no number breaks inside its digits anywhere from 320 to 1280.

## X. Shell and cross-cutting

Scope: Home (#/, #/how, #/contracts), the header, menu, status strip and footer, plus the site-wide parts: toasts, formats, loading and error states, RPC fallback, polling, security and accessibility. Home's "Fees and supply" is T6, Home's live-number cells are S14, the oracle data check and the error boundary are C4, and the disabled-button reasons are C11. The menu, theme, strip, banner, footer and not-found view passed the re-test; keep them as they are.

### X1 (P1) RPC transport: sentio cannot serve history, one JSON-RPC error or a short outage locks the site out for a minute, and a head lag shrinks log chunks to one block [X1, rX-1, rX-2, rD-1, rD-2, rD-3]
Continues round-1 X1. The 6 s timeout, the 429 cooldown and the five-call batches are done; keep them.
- **Now:** every route, every width.
  - **The response body is lost.** Sentio answers a 10,000-block eth_getLogs with HTTP 429 and the body `{"code":8,"message":"public eth_getLogs is limited to 1000 blocks"}`. viem 2.57 keeps only `data.error`, or else statusText (empty on HTTP/2), so this text never reaches config.ts:193-210 or chain.ts:111-128.
    - Result: sentio is benched for 60 s. With publicnode and ethpandaops down, #/ and #/wall show "History is incomplete" at 8 s and "Can't reach Sepolia" at 30 s, and ask for 10,000 blocks again at 120 s.
  - **Every JSON-RPC error benches its endpoint.** config.ts:204-207 tests the error text against `/HTTP|fetch|network|timeout/i`. viem's message always contains "URL: https://…", so the test always matches.
    - Any coded answer then marks the URL down for 60 s for every method: publicnode's 4444 pruned-history answer, ethpandaops' and sentio's "-32000 … is beyond the latest block … retry later", or an eth_call -32603.
    - One -32603 per endpoint stopped all getBlock and getLogs requests for about 115 s.
  - **There is no fallback when every URL is cooling.** config.ts:189 skips each URL whose `down` lies in the future and throws without sending anything.
    - After all three were down for 9 to 16 s (or the browser was offline for 13 s), the site sent 0 requests for 39 to 97 s and Try again failed at once.
    - Writes fail in that state too: their eth_call and estimateGas use the same client.
  - **A head lag is treated as a range limit.** publicnode's "block range extends beyond current head block" matches `block range`.
    - config.ts:202 rethrows it without trying the next URL, and chain.ts:123 treats it as a range limit.
    - chain.ts:128 stores each halving in the module-level `logChunk` (chain.ts:92) and never raises it again. A lag that lasts about 10 bisects leaves 1-block chunks for the whole session; a lag on a 2-block poll range sets 1 at once.
    - On any error, chain.ts:336-339 drops the whole partial scan, and :380 keeps `block` at the previous snapshot's block (eventStart − 1 on a cold load). On a cold load the poll (context.tsx:228-231) then rescans all history itself before refresh scans it again.
- **Should:**
  - Round-1 X1: every listed RPC can serve every read; a request-level error goes back to the caller and benches nothing; on "limited to N blocks", use N.
  - Brief: history comes from public RPCs, "at most 10,000 blocks per request, with fallback".
  - components.html: "The site tries the next one by itself".
- **Fix:** all in config.ts `resilientTransport`, chain.ts `scanLogs` and the poll.
  1. **Keep the body.** Give each `http(url, …)` a `fetchFn`.
     - It returns `res` when `res.ok`, or when the body is a JSON-RPC error (`typeof json.error?.code === "number"`).
     - Otherwise it reads `text = (await res.clone().text()).slice(0, 2000)` and throws `Object.assign(new Error(\`HTTP ${res.status}: ${text}\`), { status: res.status, details: text })`.
     - viem wraps that as HttpRequestError with this error as `cause`, so `cause.details` and `cause.status` reach both checks.
     - Send eth_getLogs through a second, unbatched `http(url)` per URL, so a range answer for one getLogs never fails the eth_calls batched with it.
  2. **Classify by error type, not by message text.** Walk `e` and its causes, and test in this order:
     1. **Request error** (throw to the caller at once, bench nothing): execution reverted or revert data. Also a range limit matching `/limited to [\d,]+ blocks|query returned more than|too many results|response size|block range (is )?too (large|wide)|exceeds? (the )?max(imum)? block range/i`, even when it arrives with HTTP 429.
     2. **Any other JSON-RPC answer:** a head lag (`/beyond (current head|the latest) block|retry later|header not found|unknown block/i`), 4444 or -32603. Try the next URL for this request only and bench nothing. If every URL answers this way, throw the first error.
     3. **Transport failure** (bench the URL for 60 s, try the next one): TimeoutError, a fetch TypeError, HttpRequestError with status 429, ≥ 500 or none, JSON-RPC code -32005 or 429, or a message matching `/rate limit|too many requests/i`.
     - A success sets that URL's `down = 0`.
  3. **Never fail without asking.**
     - When every URL is cooling, try them anyway, in order of the soonest `down`.
     - Export `resetHealth()`, which sets every `down` to 0. Call it before refresh() from Try again and from "Try history again" (App.tsx:267, 276), on `online`, and when `visibilitychange` makes the tab visible.
  4. **Chunks.**
     - Set `logChunk` only from an explicit "limited to N blocks".
     - For other range errors, halve locally inside `chunk()` and never store the result.
     - A head-lag error never shrinks the chunk: retry that chunk after 2 s, up to 3 times.
     - scanLogs returns the logs read so far and the last block covered. readSnapshot keeps them and resumes from there (chain.ts:327-339).
     - The poll's new-logs check starts from the last head it read, not from `block` (context.tsx:228-231).
  5. **Done when** all of these hold on the live site through a fault proxy:
     - Round-1 X1's first two criteria still hold: with publicnode hung, #/ is ready in under 15 s; with publicnode answering 429, it gets no requests for 60 s.
     - With publicnode and ethpandaops refusing connections or answering 503, #/ and #/wall load full history from sentio in 1,000-block chunks, with no "History is incomplete".
     - With eth_call answering -32603 on every URL, getBlock and getLogs keep flowing and only that read fails.
     - After all three answer 503 for 10 s and are restored (and after 13 s offline), Try again sends a request at once and the page recovers within 15 s.
     - After one "block range extends beyond current head block" answer on a cold load, the next scan still asks for 10,000 blocks.

### X2 (P1) Home hero: a denied or pending plea is shown with a sale and points [rX-6]
- **Now:** #/ when the newest judged plea is denied, alive or dead, at any width.
  - The hero reads "Sells 302,031 PLEA · +12 points" for plea #2 (12 vs need 37), with no appeal line. A pending plea reads "Sells … · +0 points".
  - HeroPlea's summary (components.tsx:1093-1101) has no status check, and chain.ts:199-206 fills `points` from pointsFor for every status.
  - The Wall card for the same plea correctly reads "no points · appeal until 20:03 UTC" (PleaCard, components.tsx:918, 928-976).
- **Should:**
  - A denial earns nothing: Seasons.record reverts NotApproved (Seasons.sol:223).
  - wall.html card feet: "need 36", "no points", "appeal until 11:53 UTC", "appealed in #207".
  - Round-1 X15: the seller of a denied plea sees "Appeal until HH:MM UTC".
  - An appeal is possible only for a denied plea that is not itself an appeal and not yet appealed, while the Cabal lives and until verdictAt + COOLDOWN (CabalGate.sol:376-380).
- **Fix:** move PleaCard's per-state foot (components.tsx:918-976: `earns` plus the nums) into one shared helper, and render the hero's `div.plea__summary` from it, as spans the way index.html:130-132 does. The hero then shows the same words as that plea's Wall card:
  - **PENDING:** "960,000 PLEA" · "need 36", plus the existing "Waiting for the Cabal" countdown.
  - **DENIED:** "N PLEA" · "no points" · "appeal until HH:MM UTC" (verdictAt + COOLDOWN) while an appeal is possible as above, "appealed in #N" once appealed. Never an appeal span after the death.
  - **UPHELD and NO VERDICT:** "N PLEA" · "no points".
  - **APPROVED, SOLD, OVERTURNED and LAPSED:** X7's sale summary with points; for a lapse, "not sold in 7 min".
  - Points only where `earns` is true, and never "+0 points".
  - **Done when** a denied, a pending and an approved hero each show the same points and sale words as their own Wall card, alive and dead.

### X3 (P2) Direct loads of #/how, #/contracts and #/seasons?seat=1 no longer scroll to their sections [WW5, rX-3, rD-4]
- **Now:**
  - App.tsx:85-94 schedules `scrollIntoView` 100 ms after a hash change, with deps `[hash]` only (:95).
  - On a direct load, App.tsx:282 is still showing the loader at that moment, so `getElementById` returns null. The effect never runs again when the snapshot arrives.
  - Result: scrollY stays 0 while the section top sits at 1022 to 1566 px (#how) or 3309 px (#contracts at 1280). The same happens for #/seasons?seat=1. Footer links and in-app links still scroll.
- **Should:** What works 5: "#/how and #/contracts scroll to their sections, from a direct load and from the footer links". This held at 520d734.
- **Fix:**
  - On each hash change, store the target id in a ref.
  - In an effect that runs on `[hash, !!s]` (or on every render until the target is found), scroll once the element exists, then clear the ref.
  - Give up after 20 s, or as soon as the user scrolls or presses a key.
  - #/seasons?seat=1 needs S1's single `#seat` section.
  - **Done when** a direct load and a reload of all three links land with the section top at 0 at 320, 768 and 1280, and the footer links still work.

### X4 (P2) Flush panels have no head or body: text touches the border and focus rings are clipped [WW4, rX-4, rS-N3]
Also round-1 X18, point (1).
- **Now:**
  - Panel (components.tsx:55-80) puts the heading and the children straight into `section.panel.stack`. It has no head or body.
  - With `className="panel--flush"` (padding 0 and overflow hidden, components.css:273), three panels put their heading, meta, labels, values and Copy buttons 3 px from the outer edge, which is just the border:
    - Contracts' two lists (home-info.tsx:240, 255);
    - Claim's "About the list" (pages-info.tsx:799), where "100,000,000 PLEA" touches the right border.
  - The 3 px rings (3 px offset) are cut on 30 of 32 Tab stops on #/contracts at 320 dark, on 16 stops at 1280 and 31 at 360 on Home, and on 2 stops on Claim's distributor row.
- **Should:**
  - index.html section 6 and claim.html:123-134: `panel--flush` holds a `.panel__head` (heading plus `.meta`) and a `.panel__body`.
  - What works 4: every Tab stop has a visible, unclipped 3 px ring.
- **Fix:**
  - Add `meta?: ReactNode` and `flush?: boolean` props to Panel. With `flush` it renders:
    - `<section class="panel panel--flush">` (no `stack` on the section);
    - inside it `<div class="panel__head"><hN>title</hN><span class="meta">{meta}</span></div>`;
    - then `<div class="panel__body stack">{children}</div>`.
  - Use it for both Contracts lists. Their metas, "Sepolia test run 9 · launch #2234" and "Live today", move out of the children into the head.
  - Use it for Claim's "About the list" (meta "Final" / "Not set") and "Delegated vaults" (S12), and for Profile's seasons panel (S10).
  - **Done when** tabbing through #/, #/contracts and #/claim at 320, 360 and 1280, light and dark, shows every ring whole, and the text sits 16 px inside the border (24 px from 768 px up).

### X5 (P2) Loading and read errors: one generic loader on every route, no Wall skeleton cards, a failing snapshot never reported, a bare Try again [X11, rX-7, rD-6]
Continues round-1 X11. The page-specific error titles, the strip text, the not-found view and keeping data on screen are done; keep them. Try again doing nothing after an outage is fixed in X1.
- **Now:**
  - **Loading:** while there is no snapshot, App.tsx:282-309 shows the same thing on every route: the page h1, "Reading the pool, the Cabal and the season from the chain…" and 3 skeleton lines.
    - There are no stat labels, no hero skeleton, no aria-busy, and 0 skeleton cards on the Wall.
    - This regresses What works 25: at 520d734 the Wall drew 3 skeleton cards.
  - **A failing snapshot is never reported.**
    - The poll (context.tsx:233-235) runs `await refresh(); failures.current = 0;`, but refresh (:205-208) swallows its own error.
    - So when the snapshot keeps failing (any read that reverts) while getBlock and getLogs work, the count resets on every poll: no error box, no backoff, and a full snapshot is retried about every 12 s.
    - Measured: 10 failures in 116 s with no error box.
  - **Try again** is a bare `btn--sm` with no i-arrow-clockwise and no `.btn-row`, and the body is a plain `<p>` (App.tsx:255-270).
- **Should:**
  - Round-1 X11: loading is each section's reference band; with data on screen, show the box after two failed polls and drop it on the next success.
  - Round-1 X2's backoff: 15, 30, then 60 s.
  - components.html:756-757.
- **Fix:**
  1. **Loading bands.** Replace App.tsx:282-309 with `<PageLoading page={page} id={path[1]} />`. Each route shows its band in an `aria-busy="true"` container under its real h1:
     - **Home:** the hero h1 and buttons; a skeleton card where the hero card goes; the six stat cells with their real labels and two skeleton lines each, under "Reading the pool, the Cabal and the season from the chain…" (index.html:409-418); then "Latest verdicts" with skeleton cards.
     - **Wall:** "Reading pleas from the chain…" and three `panel skeleton` cards, or two where the grid has two columns (wall.html:273-280).
     - **Seasons:** "Reading the leaderboard from Seasons…".
     - **Objections:** "Reading approvals and objections from the chain…".
     - **Plea page:** "Reading plea #N from the chain…".
     - **Plead:** "Reading your balance and buy record from the chain…".
     - **Profile:** "Reading <name or 0x7a3f…c21e>'s balances, pleas and seasons from the chain…".
     - **Buy:** "Reading the pool…".
     - Other routes keep today's line.
  2. **Count failures properly.**
     - refresh() returns true on success and false on failure. It already counts its own failure; the poll must not count it again.
     - The poll resets `failures` only after a refresh() that returned true, or after a getBlock that needed no refresh while the last snapshot was good.
     - With data on screen, the box shows after two failures in a row, and the poll backs off 15, 30, then 60 s (the existing timer formula, once the count is no longer reset).
     - Only a successful snapshot clears the box.
  3. **Error box** as components.html:757: a `<p class="small">` body and `<div class="btn-row"><button class="btn btn--sm" type="button"><Icon name="arrow-clockwise"/>Try again</button></div>`. Try again calls X1's `resetHealth()`, then refresh().
  - **Done when:**
    - with every RPC delayed 12 s, #/wall shows 3 skeleton cards (2 at 768) and #/ shows the labelled stat cells;
    - with eth_call answering "execution reverted" for 60 s, the box appears after the second failed poll and goes away on the first success.

### X6 (P2) Toasts: "sold for you" never appears, the record toast shows wrong points, and the denied, sale, letter, claim and window-closed toasts differ from the mockups [X8, rX-V1]
Continues round-1 X8. The toast shape, icons, stacking of 3, Dismiss, and the pending, approved, sold, name and copy toasts work; keep them.
- **Now:**
  - **Delivered:** context.tsx:188-195 requires `event.args.writer`. Letterbox emits `Delivered(id, runner, imdOut, tip, fee)` (Letterbox.sol:97), which has no writer field, so this toast never shows. On the fork, the writer watched Home for 75 s and got nothing.
  - **Record (found by code reading):** context.tsx:562-581 prints `+${recorded.points} points recorded.` and sums `Recorded.points`.
    - But Seasons sets `points` to the wallet's running best-three total, or to 0 when the plea did not enter the best three (Seasons.sol:271-282).
    - So a wallet's second record of a 45-point plea toasts "+93 points recorded". S2 (rS-N1) is the same misreading.
  - **Denied:** toast--bad with i-warning-circle and role="alert", reading "Denied, 12 vs need 37." (context.tsx:163-176; the role is set in the renderer at :288).
  - **Sell now:** "Sold N PLEA for X imdTEST." with no body (context.tsx:545-549).
  - **Letter:** gets the generic "Plea #N sent" text.
  - **Claim:** prints the full address, has no body and no vault variant (context.tsx:582-585).
  - **Window closed:** uses `clock(end)` with no seconds, and says "Plea #N lapsed unsold; its points still count." even when an objection was sustained (context.tsx:118-127).
- **Should:** round-1 X8's texts; letters.html:358-360; plea.html:457, 466; claim.html:235, 242; seasons.html:295. A lapse starts the cooldown at the verdict (lastLapsedAt = verdictAt) and a sale at the sale's block (lastExecutedAt = block.timestamp, also for executeSellFor) (CabalGate.sol:494, 624).
- **Fix:**
  1. **Delivered.**
     - Find the plea by `event.args.id` and compare its `seller` with the wallet. For a letter the seller is the writer (CabalGate.submitFor).
     - Show a toast--sold: "Approved, 37 vs need 30, and sold for you: 1,880,000 PLEA for 25.98 imdTEST." / "A runner (0x3b7e…91d0) sold it within the 7 minutes and earned the 0.25 imdTEST tip. Record your +37 points after 08:07 UTC. Next plea after 11:48 UTC."
     - The amount is chain.ts's `soldFor` (the writer's amount, round-1 C16), and the runner and tip come from the event. The record time is verdictAt + OBJECTION_WINDOW, and the next plea is the Delivered block time + COOLDOWN.
     - When a plea's Verdict and Delivered arrive in the same snapshot diff, show only this toast.
  2. **Record my points.**
     - The plea's points are the receipt's SeatMultiplier `pleaPoints` when that event is present, else the Recorded `score`.
     - The season line reads `Seasons.bestOf(season, wallet)` after the receipt and the rank from `topOf`: "Season 2: 122 points (43 + 40 + 39), rank 3." Leave out empty slots.
  3. **Denied.**
     - Use `kind: "bad"` with the x-circle icon and `role: "status"`. Add an optional `role` to Toast; the renderer uses it before the kind's default.
     - Text: "Denied, 12 vs need 37: 25 short." / "One appeal until HH:MM UTC.". The body shows only while an appeal is possible (X2's rule).
     - A letter plea uses letters.html:360's body: the APPEAL command, its fee in PLEA (C10's `feeInPlea`), and settle.
  4. **Sell now:** add the body "Record your +43 points after 08:19 UTC. Next plea at 12:00 UTC.".
     - The record time is verdictAt + OBJECTION_WINDOW. The next plea is the SellExecuted block time + COOLDOWN.
     - Drop the points sentence when the plea earns none (sustained objection or excluded seller).
  5. **Letter** (the receipt's Escrowed event has the BY_LETTER flag, `flags & 1`): toast--pending "Letter received as plea #212. The Cabal is reading your mail." / "0.75 imdTEST in fees, about 54,180 PLEA, paid from your PLEA. Usually 3 to 6 minutes.", with Escrowed.feePlea for the PLEA amount and the link "Open plea #212".
  6. **Claim:** "Claimed 48,210 PLEA for 0x7a3f…c21e." (short and mono) / "Claim #117 is done. Selling it will take a plea." (#N is Claimed.index).
     - When the account is not the connected wallet: "Claimed 212,500 PLEA for the vault 0x5e1d…44b0." / "The PLEA is on the vault; this wallet paid only the gas."
     - The link reads "View the receipt".
  7. **Window closed:** use `clock(end, true)` ("08:06:12 UTC") and plea.html:466's body: "Plea #214 lapsed: nothing was sold. Your +43 points still count: held until 08:19 UTC, then record them. Next plea at 11:59 UTC." The next plea is verdictAt + COOLDOWN.
     - With a sustained objection or an excluded seller, the body is only "Plea #214 lapsed: nothing was sold. Next plea at 11:59 UTC."
  - **Done when** each toast above appears once on a fork, with these words, for the connected wallet's own plea and never for another wallet's.

### X7 (P2) Home hero anatomy: no sale quote, no meta lines, no fact values, stamp--lg, and the headline breaks at 320 and 360 [X15, rX-8]
Continues round-1 X15. The label, head, YOU, meter, the stamp landing once, the countdowns and "Open plea #N →" work; keep them. Denied and pending summaries are X2.
- **Now:** #/, every width.
  - The summary is one `p`: "Sells 404,432 PLEA · +44 points held", with no "≈ X imdTEST" and no "(36 × 1.2)" (components.tsx:1093-1101).
  - There is no meta line under the countdowns, for the seller or for a visitor (components.tsx:1102-1121).
  - `<Stamp p={p} large />` draws a stamp--lg (components.tsx:1088). Stamp (:851-870) has no xl size.
  - The fact cells show only points (+16 / +0 / +13 / +5), not the values (FactCells, components.tsx:1199-1236).
  - The h1 wraps as "Buying is / open." at 320 and 360, because site.css:133-135 ports only `.hero-line`.
- **Should:** index.html:106-139, its "Hero card for a visitor" reference band, and its Home CSS (index.html:15-34).
- **Fix:**
  1. **Summary:** a `div.plea__summary` with two spans.
     - First span: "Sells <b>N</b> PLEA ≈ <b>X</b> imdTEST". X is the live sale quote: move pages-court.tsx:556-580's `saleQuote` into a shared `useSaleQuote(p)` hook. A visitor gets its pool estimate.
     - Second span: "<b>+43</b> points held (36 × 1.2)".
     - Once sold, the first span reads "Sold N PLEA for X imdTEST" (`soldFor`).
  2. **Meta line:** a `p.meta` after the countdowns, only while the windows are running.
     - Seller: "Sell by 08:06 UTC. Record your +43 points after 08:19 UTC."
     - Everyone else: "<name or 0x…> can sell until 08:06 UTC. Anyone else may object until 08:19 UTC."
  3. **Stamp:** give Stamp a `size?: "lg" | "xl"` prop; the hero uses xl.
  4. **Fact cells:** C6 changes FactCells to render a `.fact__value` (20%, 3d 4h, −18%, flat) and a `.fact__pts` (+16), as index.html:121-125. The hero uses that one component; do not build a second one.
  5. **CSS:** copy the Home rules from index.html:16-34 into site.css, tokens only:
     - `.hero .page-title { margin-bottom: var(--space-4); }`
     - `@media (max-width: 399px) { .hero-title { margin-inline-end: calc(-1 * var(--space-1)); } }`
     - `@media (min-width: 1100px) { .hero { align-items: center; } }`
     - `.hero-stamp { padding-block: var(--space-2); }`
     - `@media (max-width: 767px) { .hero-stamp .stamp--xl { font-size: var(--text-2xl); } }`
     - the two `.info-panel` rules (used by X8).
  - **Done when** "Buying is open." keeps one line at 360 and 390 (and at 320 as in index.html), and the hero matches index.html at 360 and 1280 for the seller and for a visitor.

### X8 (P2) "How it works": every step number shows twice, the steps use two columns, the copy is paraphrased, and the example is cost rows [X17, rX-5]
Continues round-1 X17. The fact table, the CannotPass notice, the worked numbers, the four panels with icons and links, and the chain numbers are there; keep them.
- **Now:** #/ and #/how, every width.
  - The steps are `div.steps` > `article.step`, each with an extra `span.step__num` (home-info.tsx:18-43, :38). Both the kit's `.step::before` counter and the span print the number, and the grid has 2 columns at 1280.
  - The step copy is paraphrased (:21-35). For example, step 1 has no "Open to anyone", and step 3 has no "A score at or above your need is approved."
  - "Your need" is one Panel (:45-112), with the table note outside the table panel.
  - "Example: a fresh buyer" is a Panel h3 with Costs rows (:113-139).
  - In the info panels the icon is a loose `<Icon>` in front of the text (:143-197).
  - The dead-man line is a plain `p[role=timer]` (:184-197), and its link ends with i-arrow-right.
- **Should:** index.html:203-292, with imdTEST and numbers from chain. In this run the cashback is plain imdTEST, not staked (round-1 T8).
- **Fix:**
  1. **Steps markup:** `<ol className="steps steps--4">` of `<li className="step"><h3/><p/></li>`. Delete the span.
  2. **Step copy** as index.html:207-210, numbers from chain as round-1 X17 lists them:
     - "Open to anyone. Every trade pays a 2.25% fee, and 0.5% comes back to you as cashback in imdTEST (0.49 imdTEST on a 100 imdTEST buy)." Use the mockup's "as staked IMD" wording only if the hook's cashback is ever staked (round-1 T8).
     - "Write why you want to sell 1% to 50% of your PLEA (at most 2,500,000): 1 to 280 bytes, any language. Pay the 0.50 imdTEST oracle fee. The contract computes your need first."
     - "30 judges score your plea from 0 to 45, and 17 must agree. It usually takes 3 to 6 minutes. A score at or above your need is approved."
     - "Approved: sell within 7 minutes, or tick auto-sell and anyone may sell it for you for a 0.25 imdTEST tip. Denied: one appeal within 4 hours. After a sale, a denial or a lapse: a 4-hour cooldown."
  3. **"Your need"** as index.html:212-268: a `div.stack.stack--md` holding the h3 and a `div.split` with two columns.
     - **Left:** a `div.stack.stack--lg` with:
       - the intro: "Before you pay, the contract scores four facts about your sale from the chain. Your need is 71 minus that fact score: the judges must reach it.";
       - the flush table panel, with its note inside a `.panel__body`;
       - the notice.
     - **Right:** a `div.panel.stack.stack--md` with:
       - h4 "Example: a fresh buyer";
       - "Selling up to 20% at a loss, on a flat day, held under a day:";
       - the `.facts` cells with values and points (C6's FactCells);
       - "Fact 16 + 0 + 13 + 5 = 34, so the need is 71 − 34 = 37.";
       - the Held / Fact score / Need table, from "under a day 34 37" to "a week 41 30".
     - Leave out the mockup's sample sentence about plea #214.
  4. **Info panels** as index.html:270-290.
     - Each is a `div.panel.stack.stack--md.info-panel` with an `h3.cluster.cluster--sm` that holds the icon.
     - Port the mockup's text, with imdTEST and "Sepolia Etherscan". The Letters panel's 20% is Letterbox LETTER_SHARE_BPS; the Seasons panel says "seat holders earn 1.2× points".
     - Link words: "How to send a letter", "Open objections", "See the season N leaderboard".
  5. **Dead-man:** a `<div class="cluster">` holding a `.countdown` with role="timer" and the words aria-label "The Cabal dies in 32 hours 59 minutes without a verdict", reading "Dies without a verdict in <span class="countdown__time">32h 59m</span>".
     - Use deadman() for the time; give Countdown a `format` prop for this.
     - Keep the lines for before the seed and after the death.
     - "Read the rule in the code" ends with i-arrow-square-out.
  - **Done when** each step number shows once and the section matches index.html at 360 and 1280, with 4 columns at 1280.

### X9 (P2) Contracts: the lists sit side by side, roles are inside the labels, and the owner text is rewritten [X18]
Continues round-1 X18. The order, roles, checksums, partner list, Copy toasts and the warning hidden after the death all work; keep them. The panel padding is X4.
- **Now:** #/ and #/contracts.
  - The two lists sit in a `div.split.split--even` (home-info.tsx:239), so they are side by side at 1280.
  - Roles are written into the `dt` (`<b>PLEA</b> · the token…`, :245-247) and into the partner labels (:224-228), for example "identity.md seat NFT (test NFT)".
  - So the PoolSwapTest Copy button is named "Copy Uniswap v4 PoolSwapTest · the swap router this test run trades through address", and its toast repeats the whole label.
  - The owner panel has three different paragraphs (:272-291).
- **Should:** index.html:326-367.
- **Fix:**
  1. **Layout:** replace the split with a `div.stack.stack--lg` holding, in this order: PLEA's contracts, What PLEA works with, the owner panel, the warn notice.
  2. **Labels:**
     - The `dt` holds the name only. The `dd` holds AddressView, then `<span class="meta">· role</span>`.
     - Partner labels become "Uniswap v4 PoolSwapTest" (meta "· the swap router this test run trades through") and "identity.md seat NFT" (meta "· a test NFT on Sepolia").
     - Copy names and toasts then read "Copy Uniswap v4 PoolSwapTest address" and "Uniswap v4 PoolSwapTest address copied.".
  3. **Owner panel:**
     - Use index.html:360-364's three paragraphs: "One switch, add-only." with `<code>PLEA.allow(account)</code>…; "Nothing else."…; "The owner does not play."…
     - Then one sentence that the distributor's owner sets the claim list's root once.
     - Then the PLEA owner's AddressView.

### X10 (P3) Formats: the 24h trend has no sign, and the trading gate prints today's date [rX-9]
A follow-up to round-1 X10.
- **Now:**
  - pages-info.tsx:71 prints `toFixed(1)`, so a rise reads "24h 0.8%" and a fall "-0.8%" with a hyphen.
  - TradingGate (components.tsx:242) uses utc(): "Trading may open from 2026-10-21 15:00 UTC.", while the Price cell beside it says "Opens from 15:00 UTC".
- **Should:**
  - index.html:147: "24h +0.8%".
  - Round-1 X10's clock(): "15:00 UTC" for today, the full date otherwise.
- **Fix:**
  - Sign the trend: "+0.8%", "−0.8%" with U+2212 (as in the mockups' "−18%"), and "0.0%" when it is exactly flat. Use the same signed-percent helper as T5's P/L and C6's profit cell.
  - Use clock(start) in TradingGate.

### X11 (P3) The Coinbase SDK packages are still in package-lock.json [rD-10]
- **Now:**
  - web/package-lock.json:112-230 lists @coinbase/wallet-sdk 4.3.6 and @coinbase/cdp-sdk. They come in through @wagmi/connectors 6.2.0 and @base-org/account; package.json never lists them.
  - dist/ contains no SDK code: 0 hits for cbwsdk, cca-lite, @coinbase/wallet-sdk and keyval-store.
- **Should:** D3 and round-1 X7. Its "Done when" is about the built chunks and network contact, and both hold.
- **Fix:**
  - Do not edit the lockfile: these are hard dependencies of wagmi's connectors and are never bundled.
  - Keep D3 as it is (no Coinbase Wallet connector).
  - Add the dist/ grep for those four strings (0 hits) to the build check so it stays true.

## Index

Each id and the item that fixes it. Round-1 refs point to the round-1 file; the items are in this file.

| Id | Item | Id | Item | Id | Item |
|---|---|---|---|---|---|
| T4 | T1 | rT-1 | T1 | rS-N10 | C14 |
| T5 | T2 | rT-2 | T3 | rS-VN1 | S1 |
| T7 | T4 | rT-3 | T2 | rS-VN2 | S13 |
| T8 | T5 | rT-4 | T4 | rX-1 | X1 |
| T10 | T6 | rT-5 | T2 | rX-2 | X1 |
| C5 | C2 | rT-6 | T5 | rX-3 | X3 |
| C9 | C8 | rT-V1 | T4 | rX-4 | X4 |
| C10 | C6 | rC-1 | C1 | rX-5 | X8 |
| C11 | C9 | rC-2 | C5 | rX-6 | X2 |
| C13 | C14 | rC-3 | C11 | rX-7 | X5 |
| C15 | C6 | rC-4 | C9 | rX-8 | X7 |
| C16 | C12 | rC-5 | C10 | rX-9 | X10 |
| C17 | C5 | rC-6 | C7 | rX-V1 | X6 |
| C19 | C10 | rC-7 | C14 | rD-1 | X1 |
| C20 | C13 | rC-8 | C3 | rD-2 | X1 |
| S1 | S1 | rC-9 | C3 | rD-3 | X1 |
| S2 | S5 | rC-V1 | C3 | rD-4 | X3 |
| S3 | S7 | rC-V2 | C2 | rD-5 | S4 |
| S4 | S8 | rC-V3 | C3 | rD-6 | X5 |
| S5 | S14 | rC-V4 | C10 | rD-7 | S1 |
| S6 | S9 | rC-V5 | C11 | rD-8 | S11 |
| S10 | S10 | rS-N1 | S2 | rD-9 | C4 |
| S11 | S12 | rS-N2 | S7 | rD-10 | X11 |
| S13 | S13 | rS-N3 | X4 | rD-11 | S5 |
| X1 | X1 | rS-N4 | S14 | rD-VN1 | S2 |
| X8 | X6 | rS-N5 | S9 | rD-VN2 | C11 |
| X11 | X5 | rS-N6 | S3 | WW4 | X4 |
| X15 | X7 | rS-N7 | S13 | WW5 | X3 |
| X17 | X8 | rS-N8 | S5 |  |  |
| X18 | X9 | rS-N9 | S12 |  |  |
