# PLEA run 9 site: review and fix list

The PLEA Sepolia test run 9 site (https://plea-test-run-9.sites.imd.fun/, launch #2234, commit 520d734). Testers found 158 problems, and a second reviewer re-checked each one; the ones that did not hold up are gone, and where the reviewer corrected a finding, the item follows the correction. The 158 are grouped into the fix items below.

## How to use this file

- Fix every item in this file. Do the P1 items first (in every section), then P2, then P3.
- Keep everything under "What works (keep it)" working. Re-check that list after your changes. Where an item deliberately changes something listed there (for example the busy label in X9 or the seed control in T2), the item wins.
- Check each fix on a fork of Sepolia (for example `anvil --fork-url <a Sepolia RPC>`, warping time for windows, seasons and the death), in a real browser at 320, 360, 768 and 1280 px, light and dark, with and without a wallet, as the brief's QA asks. Then check the read-only parts against the live contracts.
- The brief (brief-site-job-run9.md) and the design system (plea/site-design/: PAGE-KIT.md, components.html, tokens.css, components.css, pages/*.html and their "Design reference · other states" bands) still apply. Use components.css as it is, follow the mockups' markup and copy, and read every number from chain.
- How an item reads:
  - **Now** says what is wrong: route, state, width and theme, and the source file:line under web/src at commit 520d734.
  - **Should** names the source of truth (brief, mockup, contract).
  - **Fix** says what to change.
  - The ids in brackets are the testers' finding ids; the Index at the end maps each id to its item. A bare ref such as "C9" points to another item in this file.
- Copy quoted from a mockup says "IMD" and "Ethereum": write imdTEST (the pair token's symbol, read from chain) and Sepolia / sepolia.etherscan.io. Sample values in quotes (17.14, 08:06 UTC, plea #214, season 2) show the format; compute the real ones from chain.
- Items marked "Decision D1", "D2" or "D3" follow the product decisions below.

## Product decisions

- **D1. Seeding.** The public seed control is shown only to the PLEA owner's wallet (`PLEA.owner()`), with plain words that seeding opens trading and that the owner's opening buy should follow at once. Everyone else sees the not-open state and its countdown only. (T2)
- **D2. The buy wall.** Remove the "Fund the buy wall" donation control and its PleaHook approval. Keep Rebalance as a small public maintenance action with one plain sentence about what it does. (T10)
- **D3. Coinbase Wallet.** Remove the Coinbase Wallet SDK connector: it sends telemetry and sets a cookie on every page load. EIP-6963 and injected wallets cover Coinbase Wallet's extension. (X7)

## What works (keep it)

These were checked and work. Do not break them.

1. **Build and hosting.** `npm ci`, typecheck, `npm test` (11/11) and `npm run build` pass, the build is reproducible, and the live site is byte-identical to dist/.
2. **Design files and look.** tokens.css, components.css, text-check.js and icons.js are byte-identical to the design system. Every computed colour is a tokens.css value. Only Archivo and IBM Plex Mono load, as local woff2 files. Hard shadows appear only where the kit puts them, the only gradient is the kit's stripes, and each view has at most one btn--primary.
3. **Accessibility sweep.** All 16 routes at 320, 360, 768 and 1280 px, light and dark, with and without a wallet, and at 200% zoom: 0 axe WCAG 2.1 AA violations and no console errors. There is no sideways scroll anywhere except the profile meter (X3).
4. **Keyboard and motion.** The skip link is the first Tab stop and moves focus to main#main. Every Tab stop has a visible, unclipped 3 px ring (inputs ring their wrapper). Forced colours keep focus, pressed chips and the disabled submit visible. With reduced motion there are no animations, and the press offset is instant.
5. **Header and menu.** The tab order is logo, links, Dark theme, Connect. Under 1100 px the links fold into the Menu, and under 400 px the theme toggle moves into the drawer's Theme row. The Menu button is 44 × 44 with aria-expanded and aria-controls. aria-current is set in both the bar and the drawer. #/how and #/contracts scroll to their sections, from a direct load and from the footer links.
6. **Theme.** Light by default, dark through the toggle ("Dark theme", aria-pressed), stored in localStorage `plea-theme` and set before first paint, with no light flash.
7. **Wallet.** The Connect dialog is a labelled native dialog that lists EIP-6963 wallets; focus starts on Close and Escape returns it to Connect. A wallet on another chain gets "Switch to Sepolia"; the site sends wallet_switchEthereumChain 0xaa36a7, and on error 4902 wallet_addEthereumChain with the right Sepolia parameters. Everything reads without a wallet.
8. **Test-run wording.** The status strip starts "Sepolia test run 9 · test tokens, no value". The footer says the site is not an official IMD page. The logo is the PLEA stamp, never the diamond. No route says mainnet, Ethereum, "[after launch]" or placeholder text.
9. **Chain values.** Every constant the site shows equals the chain: the hook's 2.25% fee and its parts, the launch window and cap, CabalGate's limits, windows, pass mark, panel and dead-man, the Tribunal's window, fee, stake and margin, the Seasons rules and shares, PleaLaunch.START (2026-10-21 15:00 UTC) and the PLEA allocations. The contract addresses equal addresses.json and link to sepolia.etherscan.io.
10. **Before the seed.** Buy, Plead and Letters say "Trading is not open yet" with a countdown to PleaLaunch.START that matches the chain. Claim shows its zero-root empty state.
11. **Every write.** Each write is simulated with eth_call first and sends gas = ceil(estimate × 1.3). This held for seed, approve, swap, rebalance, Letterbox.plead, submitSell, executeSell, deliver, object, appeal, appealAuto, Letterbox.settle, CabalGate.expire, Seasons.record, Tribunal.settle, closeSeason, setName and letter.
12. **Approvals.** Every approval is for an exact amount, never unlimited: PoolSwapTest for the swap, CabalGate 0.50 (plea) and 0.85 (appeal) and the PLEA amount for executeSell, and the Tribunal 0.85.
13. **Swaps.** Buys call PoolSwapTest.swap with PleaHook.poolKey(), zeroForOne true, exact input and hookData = abi.encode(buyer); a sell after the death uses zeroForOne false with the same hookData. When it can quote, the estimate is exact for full fills (5 imdTEST quoted 515,663 PLEA, received 516,060).
14. **Money reads.** Cashback earned = the wallet's CashbackStacked + CashbackPaidPlain + CashbackPaidClaims. The ERC-6909 imdTEST claims (id = uint256(uint160(imdTEST))) are read on Profile. The buy record matches PleaHook.basisOf.
15. **History.** Logs are read from block 11948819 in 10,000-block chunks with RPC fallback, and polling pauses while the tab is hidden.
16. **Per-button states.** Disabled with a reason; busy with aria-busy and "View pending transaction"; done with a sepolia.etherscan.io link; "Make another trade" resets the form; after the approval the button becomes "Buy PLEA". A declined wallet request, a short balance (ERC20InsufficientBalance), SlippageExceeded and TooSmallForTheFee each give a plain error that says how to fix it, and an amount above the balance reads "You have 49.00 imdTEST. Lower the amount or press Max."
17. **Plead.** The fact score and need equal CabalGate.factScore at every chip, Submit is disabled at need > 45, the 1% to 50% range and the 2,500,000 cap come from the gate's constants, and the cooldown shows. The auto-sell box is ticked by default and properly labelled. The auto-sell numbers match Letterbox.feesFor (0.75 and maxFeePlea) and the 0.35 fee. The auto plea sends Letterbox.plead(amount, text); the manual plea approves exactly 0.50 and then calls submitSell.
18. **Text boxes.** The live "N / 280 bytes" counter is exact (ASCII, Cyrillic, CJK, emoji, 280 and 281 bytes). The checks come from text-check.js and refuse U+FE0F, zero-width characters, direction marks, newlines, tabs and the [plea / [objection markers; submit stays disabled until the text passes. Plea text, names and objections render as React text, never HTML (no innerHTML or dangerouslySetInnerHTML), and the bundle holds no keys or secrets.
19. **Stamps.** Every state has its word and colour (APPROVED, DENIED, PENDING striped with its time left, NO VERDICT, LAPSED dashed, SOLD, OVERTURNED, UPHELD), "N vs need N" sits under the stamp and never an amount, and an objection is a second small stamp. A stamp lands once, only when a verdict arrives live (landVerdict); nothing else animates.
20. **Court flows.** The urgent countdown shows only to the seller. LAPSED, a denial appealed to OVERTURNED and to UPHELD, NO VERDICT from a failure and from expiry, and "Return escrow and tip" for auto pleas all work. Points read "held" during the objection window; an OVERRULED ruling lowers the points and a SUSTAINED one removes them; Record my points enables only after the window and nothing records by itself; an overruled stake goes to seasonFees, others back to the objector.
21. **Seasons.** Points use Seasons.pointsFor (a seat holder's 42 gave 50), shares come from shareBps (450, 446, 442 bps), the 10,000,000 PLEA bonus shows, Close season stays disabled until end + CLOSE_GRACE, and the close records pleas through its plea-id argument and pays the top three.
22. **Profile names.** setName and nameOf work, with "This is your current name" after saving. Taken, upper-case, reserved and short names are refused before sending, and an empty name clears.
23. **Letters.** No message-page card; Write Contract and Read Contract link to sepolia.etherscan.io; the pills read "Network: Sepolia" and "Send 0 ETH"; the exact UTF-8 hex has a Copy button; the checker reads SELL, APPEAL and NAME and every checker case in the band; the direct Send letter (letter(text)) works.
24. **Claim.** claim(index, account, amount, proof) always pays the listed account, delegate.xyz v2 getIncomingDelegations(connected) uses `from` as the vault, and a bad claims file cannot redirect funds.
25. **Share and Wall.** #/share/<id> works for every state and #/share for the default card: a 1200 × 675 PNG with the fonts embedded, drawn dark in the dark theme; Copy image puts image/png on the clipboard; Share on X opens twitter.com/intent/tweet with encoded text and url = the #/p/<id> link. The Wall reads without a wallet, shows YOU only for the connected seller and has skeleton cards on its first read.

## T. Trading and money

Scope: #/buy (buy, and sell after the death), the not-open state and seeding, the launch window, fees, the buy-wall controls, swap quotes, price limits, partial fills, approvals, swap errors, cashback and the ERC-6909 claims. The gate sale's quote on #/p/<id> is C2. imdTEST is the pool token (currency0, so a buy is zeroForOne). Read every number from chain, and label amounts with the token's symbol.

### T1 (P1) The first buy after the seed gets no quote, so Approve and Buy stay disabled [TR-01, TT-01]
- **Now:** #/buy, every width and theme, any wallet, state: seeded with no trade yet. While the Cabal lives, the v4 Quoter returns 0 for buys, because the hook takes the whole PLEA output (src/PleaHook.sol afterSwap). The page therefore always falls back to `estimateHookOutput`. Its float `sqrtAtTick` (web/src/swap-math.ts:7-9) gives 33124552144574705359574211231744 for tick 120720. The pool sits exactly at TickMath's 33124552144596724627636001868808, because PleaHook.seed initialises at `getSqrtPriceAtTick(upper)` (src/PleaHook.sol:397). So `current <= b.hi` (swap-math.ts:39) fails, no band is active, and :44 throws. `useRead` (web/src/context.tsx:170) turns that error into the generic "The request could not complete… check your wallet is on Sepolia…". That text becomes Buy's disabled reason (pages-trade.tsx:240-247), and the Action is disabled whenever a reason is set (:268-273), so "Approve imdTEST" cannot be pressed either. The site quotes only after someone has traded outside it, so the owner's opening buy cannot be made on the site.
- **Should:** Brief: Buy works "exactly as in pages/buy.html" once PleaHook.seeded is true. README (Fees, Design notes): the owner's own 2 IMD buy right after `seed` is the first trade. buy.html shows a quote and an enabled "Buy PLEA".
- **Fix:**
  1. Replace `sqrtAtTick` with an exact bigint port of `TickMath.getSqrtPriceAtTick` (lib/v4-core/src/libraries/TickMath.sol: the per-bit ratio constants for |tick|, invert for tick > 0, then `>> 32` rounding up). Use it for every band edge: the quote, the price limit (T3) and the wall's IMD (T10, T11).
  2. Add a unit test. At sqrt 33124552144596724627636001868808, market (-887220, 120720, 1961295295737331612477319), wall liquidity 0 and a 7,000 bps launch fee, a 2 imdTEST buy quotes about 202,700 PLEA (not a throw), and `sqrtAtTick(120720)` equals that sqrt.
  3. Never gate the approval on the quote. When the allowance is below the amount, "Approve imdTEST" is enabled whenever the amount is valid and within the balance, even while the quote is loading or has failed. Only Buy waits for the quote (T4's launch-cap check is the one exception).
  4. A quote that fails because of the amount says so in words: keep the site's own thrown text (for example "The pool can fill at most 312.40 imdTEST at 1% slippage. Lower the amount."). Do not show the network text. buy.html's "Can't read the price" error box ("The public RPC did not answer, so there is no quote to buy at. The site tries the next one by itself; nothing was sent." plus Try again) is only for RPC failures.

### T2 (P1) Seeding: owner only, followed at once by the opening buy, and no frozen 00:00 timer [TR-05] Decision D1
- **Now:** `TradingGate` (web/src/components.tsx:170-192) on #/, #/buy, #/plead and #/letters. Before START nobody gets a seed control, not even PLEA's owner, whom PleaLaunch.seed lets seed at any time (the TooEarly check exempts `PLEA.owner()`). From START the countdown freezes at "Seed is available 00:00" (still `role="timer"`) under "Trading is not open yet". A "Seed trading" button appears for every connected wallet, with no words on what seeding does, and the toast says "seed confirmed.".
- **Should:** Brief: until PleaHook.seeded, Buy, Plead and Letters say trading is not open yet, with a countdown to PleaLaunch.START. Decision D1: only the PLEA owner's wallet (`PLEA.owner()`) sees the seed control, with plain words that seeding opens trading and that the owner's opening buy should follow at once. Everyone else sees the not-open state and its countdown only. README: the owner's 2 IMD buy right after seed lets later buys pay their shares normally (PleaHook `PAYOUT_RESERVE` = 2e18).
- **Fix:**
  - Read `PLEA.owner()` in the snapshot (web/src/chain.ts readSnapshot). It is Ownable2Step, so read it live; HomeDetails already reads it once.
  - Everyone but the owner (and no wallet): `notice--warn` "Trading is not open yet" with "Anyone may seed it from 2026-10-21 15:00 UTC." (from `PleaLaunch.START`), then the countdown "Trading may open in 21h 25m" (aria-label in words), wrapped in a `<div>` so it sizes to its text. From START on, drop the timer and say "Trading can open any moment: anyone may seed it since 2026-10-21 15:00 UTC." No seed button.
  - The owner's wallet, on #/buy only, in the TradingGate block at the top of the swap card: "Seeding opens trading for everyone. It creates the pool at a 5,700 imdTEST market cap and starts the Cabal's 33-hour clock and the 90-minute launch window. Make your opening 2 imdTEST buy here at once: its own shares join the pool, and every later buy then pays cashback normally." Below it, a `btn btn--block` "Seed trading", enabled at any time (it is not primary; Buy PLEA keeps the primary). Read the numbers from `PleaHook.MARKET_CAP_IMD`, `CabalGate.DEADMAN`, `PleaHook.LAUNCH_WINDOW` and `PleaHook.PAYOUT_RESERVE`. On #/, #/plead and #/letters the owner sees a `btn--sm` link "Seed on the Buy page →" instead.
  - After the seed receipt: toast "Trading is open. Make your opening buy now.", fill You pay with 2.00 (from PAYOUT_RESERVE) and move focus to that field.

### T3 (P1) Partial fills: the buy's own impact trips the price limit, the "minimum" is not a minimum, and success hides the shortfall [TR-02, TT-08]
- **Now:** #/buy, 1280 light, after the launch window, 30 imdTEST at 0.5%. The page quoted 5,089,917 PLEA with "Minimum estimate 5,064,467 PLEA". The swap filled 11.96 of the 30 imdTEST and delivered 2,046,136 PLEA, 40% of the "minimum". The button read "Confirmed" and the toast "swap confirmed.". At 1% slippage, any buy above about 24 imdTEST fills partially. Causes:
  - `priceLimit` (web/src/swap-math.ts:85-94) applies the slippage to the current price (pages-trade.tsx:222-224), so the trade's own impact hits the limit.
  - `minOut` (:197-199) is only displayed; PoolSwapTest has no amountOutMinimum.
  - `buy()` (:205-239) never reads the actual fill.
- **Should:** buy.html: the Slippage aside "If the price moves more, nothing is bought". The row "Minimum, 1% slippage 6,812,427 PLEA" (= quote × 0.99). The reference "Price moved past the slippage": "The price moved more than 1%." / "Nothing was bought; your IMD stays in your wallet. Try again, or raise the slippage to 2%." The reference "Bought": "Bought 6,881,240 PLEA. 0.49 IMD cashback staked."
- **Fix:**
  1. `estimateHookOutput` also returns the post-trade sqrt `next` and the gross PLEA before the 0.25% burn (T4 needs it).
  2. Price limit = `next` moved by the slippage. For a buy: `isqrt(next² × (10000 − slip) / 10000)`. For a sell after the death: `isqrt(next² × 10000 / (10000 − slip))`. Now only a move beyond the quote stops the trade.
  3. Right before sending, `simulateContract` PoolSwapTest.swap with the same args from the wallet. It returns `int256 delta`: amount0 is the high 128 bits and amount1 the low 128 bits, both signed. If the input side spends less than the typed amount, do not send: show the buy.html "price moved" toast (imdTEST for IMD, with the chip's slippage and the next chip up).
  4. After the receipt, read the fill from its logs: the imdTEST Transfer from the wallet, the PLEA Transfer to it, FeeRefunded, and the Cashback* events. Toast and inline: "Bought 2,046,136 PLEA for 11.96 imdTEST." plus the cashback line (T11). If less than the typed amount was spent, add "18.04 imdTEST did not fill and stayed in your wallet: the price reached your 0.5% limit."
  5. Rename the row "Minimum, 1% slippage" (following the chip). Remove the "Price protection" notice (pages-trade.tsx:396-404).

### T4 (P1) Swap errors: hook reverts arrive wrapped and show the network text, and the launch cap is not checked before the approval [TR-03, TT-06]
- **Now:** #/buy in the launch window, 50 imdTEST at 2%. The page quoted 5,094,238 PLEA with no warning, while the side panel says "Most per buy 5,000,000 PLEA". The approval was sent and confirmed. Buy then failed in simulation with "The request could not complete… check your wallet is on Sepolia…", inline and as a toast.
  - The PoolManager re-throws hook reverts as `WrappedError(address target, bytes4 selector, bytes reason, bytes details)` (selector 0x90bfb865; lib/v4-core/src/libraries/CustomRevert.sol:11, Hooks.sol:137).
  - `explainError` (web/src/errors.ts:120-152) decodes only the outer data against the site ABIs, which lack that error. So BuyTooLarge, SellsOnlyViaGate, NotSeeded, ExactOutputBuyRefused, RecipientRequired, NotEnoughGas and PartialFill never reach their messages. The same happens on #/buy and in the gate's swaps (CabalGate.executeSell, Letterbox.deliver, letters).
  - The v4 Pool errors (PriceLimitAlreadyExceeded and others) are in no ABI, and 54 of the 120 ABI errors have no message.
- **Should:** Brief MUST HAVE "Decode the contracts' custom errors into the plain words the mockups use." buy.html reference "The launch window: a buy over the cap (BuyTooLarge)": "Not bought: more than 5,000,000 PLEA in one buy." / "Until 13:30 UTC one buy can take at most 5,000,000 PLEA. Pay less IMD, or split the buy in two. Nothing was bought."
- **Fix:**
  1. Add `WrappedError(address,bytes4,bytes,bytes)`, `HookCallFailed()`, `PriceLimitAlreadyExceeded(uint160,uint160)`, `PriceLimitOutOfBounds(uint160)` and `PoolNotInitialized()` to the error ABIs. When the decoded error is WrappedError, decode its `reason` again against all ABIs, recursively up to 3 levels, and use the inner name.
  2. Write each message as a title plus a body, with imdTEST for IMD and values from chain:
     - BuyTooLarge: the buy.html text above, with `LAUNCH_MAX_BUY` and `launchedAt + LAUNCH_WINDOW` as the UTC time.
     - PriceLimitAlreadyExceeded: "The price moved more than 1%." / "Nothing was bought; your imdTEST stays in your wallet. Try again, or raise the slippage to 2%." (the chip's slippage, and the next chip up; on a sell after the death, "Nothing was sold; your PLEA stays in your wallet.")
     - SellsOnlyViaGate: "While the Cabal lives you can only sell with an approved plea."
     - NotSeeded: "Trading is not open yet."
  3. Check the cap before signing. While `now < launchedAt + LAUNCH_WINDOW`, if the quote's gross PLEA output (before the burn, as `_checkMaxBuy` compares it) exceeds `LAUNCH_MAX_BUY`, mark the input invalid with "Until 13:30 UTC one buy can take at most 5,000,000 PLEA. Pay less imdTEST, or split the buy in two." and disable both Approve and Buy.
  4. Any other decoded error that has no message reads "The contract refused this (ErrorName)." in place of the network text. Add a plain message for the one user-reachable error still missing: Seasons `UnfundedStake`, which Tribunal.settle can raise ("The prize pot could not account for this stake. Nothing moved; try Settle again."). `TooLate`, `WrongPanel` and `ScoreOutOfRange` come only from the Intake's callbacks and need no message. The generic network text stays for real RPC failures only.

### T5 (P1) Fee breakdown: per-trade amounts, the launch fee, and no prize share after the death [TR-04, TR-11]
- **Now:** The #/buy Costs block (web/src/pages-trade.tsx:359-390) shows percentages only: "Trade fees 2.25%", "Cashback 0.5% in imdTEST", "Owner 1%", "Season prize pot 0.25%", "Buy wall 0.25%", "Burned 0.25% of PLEA". It has no "Reaches the pool" row, no amounts and no sum. In the launch window nothing in the card names the launch fee. The quote includes it: at the open, 7,000 bps of what reaches the pool, about 42% of the imdTEST sent. After the death, Buy, Sell and Home's "Fees on every trade" (web/src/details.tsx:38-60) still list "Season prize pot 0.25%". The hook pays no prize share then: in PleaHook._payFees, `toPrize` is set only while `_alive()` (PleaHook.sol:598), and that share stays in the pool.
- **Should:** buy.html costs:
  - "Price 1M PLEA = 14.16 IMD"
  - "Minimum, 1% slippage 6,812,427 PLEA"
  - "Reaches the pool 98.04 IMD"
  - total "Fees, 2.25% 1.96 IMD + 0.25% of the PLEA"
  - `.is-part` rows "Back to you as staked IMD (0.50%) 0.49 IMD", "Owner (1.00%) 0.98 IMD", "Season prize pot (0.25%) 0.245 IMD", "Buy wall (0.25%) 0.245 IMD", "Burned (0.25%) 0.25% of the PLEA"
  - the sum line "The IMD fee is 2% of what reaches the pool: 98.04 + 1.96 = 100.00 IMD…"

  README Fees: the prize share becomes pool liquidity once the Cabal is dead.
- **Fix:**
  - Compute the rows for input A, with rate = `IMD_FEE_BPS` + the live launch extra (buys only):
    - fee = A × rate / (10000 + rate), and R (what reaches the pool) = A − fee.
    - cashback = R × `CASHBACK_BPS` / 10000; owner = R × `OWNER_BPS` / 10000; prize = R × `PRIZE_BPS` / 10000.
    - buy wall = R × `POOL_BPS` / 10000. The "Fees, 2.25%" total is R × `IMD_FEE_BPS` / 10000, the sum of these four parts.
    - launch fee (launch window only) = fee − that 2.25% total. The hook adds it to the buy wall with the 0.25% (`toPool = imdFee − out`, PleaHook._payFees).
  - Show the buy.html rows with imdTEST at 2 decimals (3 for the prize-pot and wall parts, as the mockup does). Name the cashback row "Back to you as cashback (0.50%)": in run 9 it is plain imdTEST (T8).
  - In the launch window, keep the total "Fees, 2.25%" and its parts, and add one more row under them, "Launch fee (46.7%), to the buy wall 31.39 imdTEST" (for 100 imdTEST at 46.7%, from `launchExtraBps()`). buy.html's launch panel likewise keeps "Normal fees, on top 2.25%" and names the launch fee apart (T9). The sum line then reads "Reaches the pool + fees + launch fee = what you pay", so it still adds up to the amount typed.
  - Once `CabalGate.diedAt` > 0, drop the prize-pot row and show "Buy wall (0.50%)", on #/buy and in Home's fee table (T10). The total stays 2.25%.
  - For a sell after the death, use the buy.html dead-state rows instead (T6).

### T6 (P1) After the death, Buy/Sell still shows the alive rules [TR-07]
- **Now:** #/buy with `CabalGate.diedAt` > 0, in Buy and Sell, at 360 and 1280, light and dark:
  - The lead still says "Buying is open to anyone. Selling needs a plea while the Cabal lives." (web/src/pages-trade.tsx:250-252), even under "Sell PLEA".
  - "Your PLEA" shows "Next plea: Ready when trading opens" and a "Plead to sell" button that leads to a closed page (:436-460).
  - The "Before you buy" notice still says you can only sell with an approved plea (:507-516).
  - There is no "Plea needed: none" row and no "What selling takes" text.
  - The Buy/Sell chips render under the action button (:276-293).
  - Sell still shows "Every buy identifies you in hookData".
- **Should:** Brief MUST HAVE: after the Cabal dies, "Sell on Buy". buy.html reference "After the Cabal dies":
  - a Buy / Sell `chips` group (aria-label "Buy or sell") first in the card;
  - the "Sell PLEA" card: "You sell" with "Balance 6,200,000 PLEA", "You get (quote) ≈ 17.14 IMD", the costs "Minimum, 1% slippage 16.97 IMD", "Fees 2.25%" and "Plea needed: none, the Cabal is dead", and the button "Sell PLEA";
  - "Your PLEA" ending in "What selling takes: Nothing more than a swap. No plea and no need: the Cabal is dead, so PLEA sells like any token on Uniswap v4."
- **Fix:** Branch on `diedAt > 0`:
  - Put the chips first in the card and build the dead reference's fields, rows and button.
  - The lead reads "The Cabal is dead, so buying and selling are open to everyone, forever." (index.html dead-state wording).
  - Remove the "Before you buy" notice, the Plead link and the Next plea row, and show the dead "What selling takes" text.
  - Buy keeps T5's rows without the prize pot.

### T7 (P2) The swap card's order, labels and states differ from buy.html [FA-13, FA-10, TR-17, FA-31]
- **Now:** The swap card (web/src/pages-trade.tsx:254-408):
  - The action button and its reason sit at the top, under TradingGate and before the fields. DESIGN.md calls this deliberate, but it is not the mockup.
  - The You pay aside reads "Balance 50.00 · Max" with no unit, and "Balance — · Max" without a wallet. Max fills the raw 18-decimal string (:311-312).
  - The quote label switches to "Indicative pool calculation" or "Live v4 Quoter", with no "Updated N s ago" and no "≈". While loading, "Reading the pool…" is the input's value.
  - The slippage label is "Slippage / price limit" with no aside.
  - A balance shortfall is only a line under the top button; the input is not marked invalid.
  - Developer text is added: "One approval to PoolSwapTest, then the swap. Every buy identifies you in hookData. Cashback in this run falls back…", "Test tokens have no value. No USD price source is configured."
  - Dashes stand in for values: "Minimum estimate — PLEA", "1M PLEA = — imdTEST".
  - At 360 the card title breaks as "Swap imdTEST / for PLEA".
  - The TradingGate countdown is a pill as wide as its column (686 of 686 px) on #/, #/buy and #/plead.
- **Should:** buy.html's main state and its references "Not connected", "Empty: no amount yet", "Quote loading", "Not enough IMD" and "Error: no connection to Ethereum".
- **Fix:**
  - **Order** the card as in buy.html: (dead only) chips, You pay, You get (quote), Slippage, costs (T5), then the button block with its note. Do the same on #/plead: the submit block goes last, after the auto-sell box and costs (C10 orders the rest of that form).
  - **You pay:** aside "Balance 412.50 imdTEST · Max", with sr-only ": pay all 412.50 imdTEST". With no wallet, the aside is "Your balance shows once you connect" and the note under the button "Connect in the top bar to buy.". Max keeps the exact bigint in state but shows the value with 2 decimals.
  - **You get:** label "You get (quote)", aside "Updated 3 s ago" (since the quote was read), value "≈ 6,881,240". While loading, the aside is the `loading-label` with i-hourglass "Reading the pool…", the input a `skeleton__line`, and the reason "Waiting for the quote from the pool.". Keep the last quote on screen while a snapshot refreshes.
  - **Slippage:** label "Slippage", aside "If the price moves more, nothing is bought".
  - **No amount:** hide the costs; the reason reads "Enter how much imdTEST to pay, or press Max. The quote and the fees show once there is an amount."
  - **Not enough imdTEST:** `.input.is-invalid` with `aria-invalid="true"`, and the `field__hint bad-text` "You have 412.50 imdTEST. Lower the amount or press Max." under the field, tied to both the input and the button with `aria-describedby`.
  - **Note under the button:** "One approval for imdTEST, then the buy. 0.49 imdTEST cashback is paid to you in the same transaction."
  - **Remove** the token-note line and the hookData/Stacker sentence.
  - **Title:** write it as "Swap imdTEST for&nbsp;PLEA".
  - **Countdowns:** wrap the TradingGate countdown in a `<div>`.
  - **Plead:** on #/plead without a wallet, drop the dashes "From — PLEA to — PLEA"; C9's Not connected notice ("Connect in the top bar to plead.") replaces them.
  - **Notice:** the alive "Before you buy" notice uses buy.html's exact text: "While the Cabal lives you can only sell with an approved plea. The Cabal dies after 33 hours without a verdict; then PLEA trades freely forever."

### T8 (P2) The "Your PLEA" and "Cashback" panels: stale copy, no profit or loss, a wrong open-plea link, developer text [FA-14, TR-15]
- **Now:** web/src/pages-trade.tsx:410-486:
  - A "Next plea" row stands where buy.html has the profit/loss row. It falls back to "Ready when trading opens" after the seed and after the death (:446).
  - "Open plea #<lastPleaOf>" shows for any past plea, SOLD or closed included, so "Plead to sell" never comes back after a first plea (:452-460).
  - The buttons are full size with no arrow, and there is no "What selling takes".
  - The Cashback text reads "Sum of CashbackStacked, CashbackPaidPlain and CashbackPaidClaims for your wallet…", and "Earned so far" shows "—" without a wallet.
  - Home's empty Latest-verdict card keeps "The first case will be heard when trading opens." after the seed (web/src/pages-info.tsx:86).
- **Should:** buy.html "Your PLEA":
  - Balance.
  - The label "Your buy record" with "Cost basis 17.27 IMD per 1M", "Held, buy-weighted 3d 4h" and "Now, at 14.16 IMD per 1M −18.0%".
  - "What selling takes" and its text.
  - Only while a plea is open: "Plea #214 is open: sell by 08:06 UTC. Next plea 4 hours after the sale (12:00 UTC if sold now), or 11:59 UTC if it lapses." and `btn--sm` "Open plea #214 →". Otherwise `btn--sm` "Plead to sell →" (reference "Your PLEA, no plea open").

  Cashback: "Earned so far 0.83 IMD" and "Paid as staked IMD through imd/acc: 0.50% of every trade (0.49 IMD on this buy), in the same transaction." index.html "Latest verdicts, before the first plea": "No pleas yet / Every verdict lands here, newest first. The court is in session; the judges are filing their nails. [Write the first plea]".
- **Fix:**
  - **Port the panel.** P/L = spot per 1M (`priceX96 × 10^24 / 2^96`) ÷ cost basis (`basisOf.imdSpent × 10^24 / pleaHeld`) − 1, with sign and 1 decimal. Drop the Next plea row.
  - **Open-plea line:** show it and "Open plea #N →" only while C1's state says the wallet's plea is open: pending and within `submittedAt + PENDING_EXPIRY`, or approved and within `verdictAt + EXECUTE_WINDOW`. A lapsed approval or an expired pending plea counts as closed, as in CabalGate._clearStale. Otherwise show "Plead to sell →", plus "Next plea from 12:00 UTC." while the cooldown runs.
  - **Cashback text:** run 9's Stacker cannot stake imdTEST, so the hook pays plain imdTEST (README, Sepolia settings). Write "Paid in the same transaction: 0.50% of every trade (0.49 imdTEST on this buy). In this test run it arrives as plain imdTEST, not staked." Use the mockup's staked wording, with its imdacc.fun link, only when the wallet has CashbackStacked events. With no wallet: "Connect in the top bar to see your cashback.".
  - **Home's empty card:** after the seed, use index.html's empty state above; before the seed, keep the not-open line.

### T9 (P2) The launch-window panel lacks the mockup's notice and rows [TR-V1]
- **Now:** #/buy, seeded, inside the 90 minutes (web/src/pages-trade.tsx:487-506). The panel shows only "Launch fee ends in 1h 29m", "Launch fee now 70% of input reaching the pool" and "Most per buy 5,000,000 PLEA". The percentage is the snapshot value, refreshed every 15 s. Nothing says the fee comes on top of the 2.25% or that a buy over the cap is refused, and there is no UTC end time.
- **Should:** buy.html reference "The launch window":
  - `notice--warn` with i-timer: "Launch window: 30 of 90 minutes gone." / "Until 13:30 UTC every buy pays a launch fee on top of the normal 2.25%; a buy over the cap is refused."
  - costs "Launch fee now 46.7% of the IMD that reaches the pool", "How it falls in a straight line from 70% to 0% at 13:30 UTC", "Most per buy 5,000,000 PLEA" and "Normal fees, on top 2.25%"
  - the countdown "Launch fee ends at 13:30 UTC 1h 00m", with aria-label "The launch fee ends at 13:30 UTC, in 1 hour 0 minutes"
- **Fix:** Build the panel as drawn, at the top of the side column, hidden once the window ends. Values from chain:
  - minutes gone = `floor((now − launchedAt) / 60)` of `LAUNCH_WINDOW / 60`;
  - end time = `launchedAt + LAUNCH_WINDOW`;
  - fee now = `LAUNCH_EXTRA_BPS × (end − now) / LAUNCH_WINDOW`, recomputed every second from `now`, shown with 1 decimal;
  - the "from" value is `LAUNCH_EXTRA_BPS / 100`, the cap is `LAUNCH_MAX_BUY`, and the normal fee is `(IMD_FEE_BPS + PLEA_BURN_BPS) / 100`.

### T10 (P2) Home "Fees and supply" and the buy wall: port the mockup section, drop the donation form, keep Rebalance small [FA-18, TR-19, TT-21] Decision D2
- **Now:** #/ and #/contracts, every width:
  - **Fees** (web/src/details.tsx:38-63): short labels, no total row, and no 100-IMD sentence.
  - **Supply** (:65-90): rows "Minted to pool hook / for seasons / to distributor" and "Burned by hook" (PleaHook.totalBurned only), with no percentages, no total rows and no claim-list button.
  - **"The buy wall"** (details.tsx:121-191, rendered at pages-info.tsx:221) is an extra section. "Inventory and reserves" carries a disabled dashed "Rebalance buy wall" whose only text is "Anyone may rebalance when the hook reports work ready." "Fund the buy wall" asks for an approval to PleaHook and then calls `fundWall`, an irreversible donation, worded as "paired tokens". After a rebalance both reserve rows read 0.00, and nothing shows where the 4.32 imdTEST went.
- **Should:** index.html section 5 "Fees and supply" (meta "Paid inside the swap, nothing to claim later"):
  - **Fees on every trade:** "Cashback to you, as staked IMD through imd/acc 0.50%", "Owner 1.00%", "Season prize pot 0.25%", "IMD buy wall, kept in the pool 0.25%", "Burned 0.25% of the PLEA", total "Total 2.25%", then the 100-IMD sentence.
  - **Supply:** "Pool liquidity, locked forever 820,000,000 (82%)", "Season bonus: 10,000,000 in each of the first six seasons 60,000,000 (6%)", "Claim list: swarm 10% + airdrop 2% 120,000,000 (12%)", total "Total PLEA at launch", "Burned so far", total "Supply now", and `btn--sm` "Check the claim list →".

  No buy-wall section exists in the brief or any mockup. Decision D2: remove "Fund the buy wall" and its PleaHook approval, and keep Rebalance as a small public maintenance action with one plain sentence.
- **Fix:**
  - **Fees:** port section 5 with live values. Word the cashback row as T8 does, and after the death apply T5 (no prize-pot row, wall 0.50%).
  - **Supply:** shares = mint events ÷ `PLEA.TOTAL_SUPPLY`; "Burned so far" = `TOTAL_SUPPLY − PLEA.totalSupply()`, which also counts the season-bonus burns.
  - **The buy wall:** delete the section and the `fundWall` ApprovedAction. No approval to PleaHook remains anywhere on the site.
  - **Rebalance:** under the fee table, and only while `PleaHook.pendingRebalance()` is true, add the `.small` line "Anyone may press this, unpaid: it burns the PLEA the buy wall has bought and places all the imdTEST the hook has collected as one buy wall just below the price. The imdTEST never leaves the pool." (PleaHook.rebalance, PleaHook.sol:841-845) with `btn--sm` "Rebalance buy wall" (`PleaHook.rebalance`; RebalanceNotNeeded keeps its message).
  - **CSP:** the host sets it; nothing to change in the site for it.

### T11 (P3) Opening-buy payouts are not explained, and small cashback and claims show as 0.00 [TR-06, TR-21]
- **Now:**
  - #/buy promises "Cashback 0.5% in imdTEST" on every buy. While the pool's own IMD plus the buy's fee is under `PAYOUT_RESERVE` (2 imdTEST), the cashback, owner and prize shares join the pool instead (PayoutsToPool, PleaHook.sol:611). One 0.5 imdTEST opening buy got no cashback while the page showed "Earned so far 0.00" and "swap confirmed.".
  - A larger opening buy is paid as ERC-6909 claims (CashbackPaidClaims).
  - Profile lists the claim twice, as "PoolManager claims" and "ERC-6909 claims" (web/src/pages-info.tsx:836, 875), and "Opening buys may return imdTEST claims…" does not say what they are.
  - Non-zero sub-cent amounts round down to look empty: 0.003 imdTEST of cashback shows "0.00", and 0.0149 shows "0.01".
- **Should:** README (Fees; Design notes "The very first buy") and PleaHook._payFees: the page should state what this buy will actually pay. Brief: Profile shows the wallet's ERC-6909 imdTEST claims on the PoolManager. PAGE-KIT: IMD with 2 decimals, and the mockup uses a third where needed ("0.245 IMD").
- **Fix:**
  - **Before signing,** mirror `_payFees`' test:
    - out = R × (`CASHBACK_BPS` + `OWNER_BPS` + `PRIZE_BPS`) / 10000 (no prize share after the death);
    - own = `imdInMarket()` + `retainClaims()` + the wall's imdTEST (0 until a wall exists; from `PleaHook.wall()` with T1's TickMath);
    - if own < out and imdTEST.balanceOf(PoolManager) < out, then: when own + fee < `PAYOUT_RESERVE`, the cashback row reads "none on this opening buy: the cashback, owner and prize shares join the pool"; otherwise it reads "0.49 imdTEST, paid as a claim on the PoolManager (see Profile)".
  - **After the receipt,** a PayoutsToPool event adds "No cashback on this opening buy: its payouts joined the pool." to the toast.
  - **On Profile,** show the claim once, as "imdTEST claims on the PoolManager 0.0149 imdTEST", with "Paid on opening buys when the pool could not pay at once. They are ERC-6909 balances on Uniswap v4's PoolManager (id = the imdTEST address), separate from your imdTEST balance; this site cannot redeem them."
  - **Small amounts:** a non-zero cashback or claim under 0.01 shows "< 0.01 imdTEST", never "0.00".

### T12 (P3) Exact-amount approvals: every buy takes two transactions [TR-22]
- **Now:** web/src/pages-trade.tsx:205-216 approves PoolSwapTest for exactly the typed amount. After a full fill the allowance is 0, so every buy is an approval plus a swap. A partial fill left 17.63 imdTEST approved, which is harmless because PoolSwapTest settles from msg.sender.
- **Should:** buy.html: "One approval for IMD, then the buy." Reference "Busy: approving IMD (step 1 of 2)": "Lets the buy spend your IMD. Nothing is bought yet." The approval policy is the PLEA team's choice.
- **Fix:**
  - Keep exact-amount approvals (no unlimited allowance) and skip the approval when the allowance already covers the amount.
  - Before the approval, the note under "Approve imdTEST" reads "Step 1 of 2: lets the buy spend exactly 100.00 imdTEST. Nothing is bought yet."
  - After the approval confirms, the same button becomes "Buy PLEA" (step 2 of 2) without retyping, and the quote and amount stay as they were.

## C. The court

Scope: #/plead, #/p/<id> (including the seller's sale and its quote), #/letters and #/objections. Conventions for this section. Quoted copy comes from the mockups. Where a mockup says IMD, write the chain's pair symbol (imdTEST). Where it says Ethereum or etherscan.io, write Sepolia or sepolia.etherscan.io. Write window lengths in words ("7 minutes", "4 hours"). Section X holds the shared fixes for the duration format, toasts, busy labels and done states, empty-state icons and the need-marker clamp. The contract's time checks are strict: `now > deadline` means past.

### C1 (P1) A lapsed approval or an expired unanswered plea locks the seller out of Plead [CT-03, TT-02, CT-05]
- **Now:** On #/plead, at every width, both Submit buttons are disabled with "Plea #N is open. Open it before sending another plea." whenever `CabalGate.pendingOf(wallet) > 0` (web/src/pages-trade.tsx:564-571, 613-617). The cooldown at :98-105 ignores the lapse. pendingOf stays set after an approval's 7-minute window ends, and after a pending plea passes 20 minutes, until the seller's next plea clears it. So the seller is blocked forever. On the fork the page was still blocked after the cooldown ended, while eth_call submitSell succeeded. Every LAPSED plea on #/p/<id> shows "Mark plea lapsed" (pages-court.tsx:547-553). It calls CabalGate.expire and always reverts NotPending. The "Next plea: after plea #N" line on #/buy (pages-trade.tsx:441-446) has the same fault.
- **Should:**
  - CabalGate._requireCanPlead → _clearStale (CabalGate.sol:469-498) runs inside the next submitSell, Letterbox.plead or appeal:
    - An Approved plea past verdictAt + EXECUTE_WINDOW becomes Lapsed, with lastLapsedAt = verdictAt, so the cooldown runs until verdictAt + COOLDOWN.
    - A Pending plea past submittedAt + PENDING_EXPIRY (or whose Intake request completed without a verdict) is expired, with no cooldown.
  - expire() accepts only Pending pleas (CabalGate.sol:516-518). No public function marks a lapse.
  - Letterbox._next computes the next-plea time the same way.
  - plead.html reference band: "At 08:00 UTC: plea #214 is open" and "Cooldown active".
- **Fix:**
  - In WalletBalances, when pendingOf ≠ 0, read getPlea(pendingOf) and derive the state:

    | getPlea status | Time check | Result |
    |---|---|---|
    | Pending | now ≤ submittedAt + PENDING_EXPIRY | Open, waiting for the Cabal |
    | Pending | past that | Not open. The next plea clears it, with no cooldown. |
    | Approved | now ≤ verdictAt + EXECUTE_WINDOW | Open, sell window |
    | Approved | past that | Not open. Use lapsedAt = max(lastLapsedAt, verdictAt). |

  - Cooldown ends at max(non-zero lastExecutedAt, lastDeniedAt, lapsedAt) + COOLDOWN.
  - Show "Open plea #N" only for an open plea. Feed Plead's notice and reason from this state (copy in C9).
  - Buy's "Your PLEA" panel (T8) and Profile's Next plea stat (S10) use this same state, never pendingOf alone.
  - Delete the "Mark plea lapsed" button. A LAPSED plea shows the LAPSED copy of C5. Keep "Return escrow and tip" (Letterbox.settle) for auto pleas.
  - Check on a fork:
    1. Approve a plea and warp 8 minutes: Plead says "Cooldown until <verdict + 4 h>".
    2. Warp past that time: Submit enables and the plea goes through.
    3. Leave a pending plea unanswered past 20 minutes: Submit enables at once.

### C2 (P1) Sell now's default minimum comes from the hourly checkpoint, so the sale reverts after a ~1% dip [FA-V1]
- **Now:** #/p/<id> for an approved manual plea, seen by its seller ("Your sale"), at every width. "Minimum you receive" defaults to 99% of amount × PleaHook.latestPrice × (1 − 2.25%) (pages-court.tsx:380-391, 499-519), ignoring price impact. latestPrice is the hourly checkpoint, not the spot price. On the fork two other sales that hour left the spot 1.34% under the checkpoint: the default minimum was 18.7552 imdTEST while the sale yields 18.6280, so executeSell reverted SlippageExceeded twice. The error said "The price moved beyond your minimum. Refresh the quote or raise your slippage.", controls this page does not have, while the 7-minute window kept running.
- **Should:** plea.html "Your sale" shows "Sells 1,240,000 PLEA", "You get about 17.14 IMD", "At least, with 1% slippage 16.97 IMD" and the button `btn--ink` "Sell now" with `btn__sub` "≈ 17.14 IMD". Its "Sell failed" reference toast reads: "The price moved more than 1%. Nothing was sold; your PLEA stays in your wallet. The window is open until 08:06:12 UTC: try again." In PleaHook.sol:263-277, priceX96 is the spot price; latestPrice is the checkpoint used for fact scores only. CabalGate.executeSell returns the imdTEST out (CabalGate.sol:597-604).
- **Fix:**
  - Compute "You get" from the live pool:
    - Once the seller's PLEA allowance to CabalGate covers p.amount, simulate `CabalGate.executeSell(0)` with eth_call from the seller. It returns the exact imdTEST out.
    - Before the approval, use the #/buy estimator (`estimateHookOutput`, with T1's exact TickMath) for `p.amount` PLEA in: zeroForOne false (imdTEST is currency0), sqrt = `PleaHook.currentSqrtPriceX96()`, the market and wall bands, input fee `PLEA_BURN_BPS`, output fee `IMD_FEE_BPS`. Never use latestPrice.
  - Re-run the estimate on every snapshot while the window is open, and once more right before sending. Send `minOut = out × 99 / 100`.
  - Replace the "Minimum you receive" input (and its raw 18-decimal value) with the three costs rows of C14 and the button's sub-label.
  - Give `useTx.send` an optional per-call error map, passed to explainError. On this page:
    - SlippageExceeded on Sell now → the mockup's "The price moved more than 1%…" toast, with the real window end.
    - WindowLapsed → "The window closed at HH:MM:SS UTC. Plea #N lapsed: nothing was sold. Your +P points still count: held until HH:MM UTC, then record them. Next plea at HH:MM UTC." (plea.html "Sell failed" band).
    - SlippageExceeded on Deliver (the Letterbox sets its own minimum, 95% of the snapshot value after fees; Letterbox.sol:400-405) → "The pool price is more than 5% under the hourly snapshot, so the Letterbox's minimum can't be met. Nothing was sold; try again before HH:MM:SS UTC."

### C3 (P1) Auto-sell Plead accepts amounts and balances the Letterbox refuses [TT-05, CT-17]
- **Now:** This is #/plead with the auto-sell box on, which is the default, at every width. The hint, chips and reason use only the gate's limits, "From 1% … to 50%" (pages-trade.tsx:540-575, 625). Two failures follow:
  - A 1% plea worth under 0.70 imdTEST enables Submit, then fails in simulation with "The sale is too small to cover its fees. Increase the amount." The message does not name an amount.
  - A wallet holding less than 10 × the fee cap passes every check, then gets "The fee would take too much PLEA. Try a larger eligible sale…" (errors.ts:76-79). A larger sale cannot fix it. On the fork the wallet held 514,617 PLEA against a fee cap of 141,869 PLEA.
- **Should:** Letterbox._plead (Letterbox.sol:293-312) applies three rules:
  - The plea must be worth at least MIN_SALE_VALUE, 0.70 imdTEST, at PleaHook.latestPrice. Otherwise it reverts TooSmallForTheFee(value) (:430-433).
  - `feesFor(false).maxFeePlea` may be at most 10% of the balance (MAX_FEE_SHARE_BPS). Otherwise it reverts FeeTooHigh(maxFeePlea, balance).
  - amount + maxFeePlea ≤ balance.
  - The balance is read after `_settleOpen` returns the writer's open, settleable escrow.
  - letters.html "Limits" states the same rules.
- **Fix:**
  - With the box on, set `autoMin = max(gate min, ceil(0.70e18 × 2^96 / latestPrice))`. The 1% chip fills autoMin when 1% is below it.
  - If `maxFeePlea × 10 > balance`, disable Submit with: "Auto-sell's fees (at most N PLEA) may take at most 10% of your PLEA, so it needs at least M PLEA. Untick 'Sell automatically if approved' to pay the 0.50 imdTEST oracle fee from your imdTEST." Once this rule holds, amount + fee ≤ balance always holds, because the amount is at most 50%.
  - For these checks the balance is `PLEA.balanceOf` plus the escrow of an open, settleable letter plea (the rule in C4), since the Letterbox settles it first.
  - Hint: "From N PLEA (worth 0.70 imdTEST at the hourly price) to M PLEA: at most 50% and 2,500,000."
  - MIN_SALE_VALUE is internal (Letterbox.sol:124), so declare it as a named constant (C11).
  - Error texts:
    - TooSmallForTheFee → "Worth X imdTEST at the hourly price; auto-sell needs at least 0.70 imdTEST (about N PLEA). Raise the amount or untick auto-sell."
    - FeeTooHigh(uint256,uint256) has the same selector in Letterbox and in CabalGate._swapFee. When the second argument equals the wallet's PLEA balance, use the 10% message above. Otherwise use: "The price fell since the hourly snapshot, so the fee needs more PLEA than its 10% margin. Nothing was paid; try again after the next snapshot or untick auto-sell."

### C4 (P1) The automatic appeal shows the wrong amount: it ignores the escrow the Letterbox returns first [CT-01, TT-07]
- **Now:** This is the "One appeal" panel on #/p/<id>, with the box on (the default), seen by the seller of a denied auto-sell plea. The read-only "Appeal amount" and the need preview come from appealPreview, which clamps on PLEA.balanceOf(wallet) (appeal.ts:16-44). The denied plea's PLEA is still in Letterbox escrow. On the fork the shown amount was 26-27% low: 608,836 PLEA shown against 767,425 PLEA escrowed by appealAuto.
- **Should:**
  - Letterbox._appeal (Letterbox.sol:314-372) first calls _settleOpen(writer), which returns the open, settleable escrow. Only then does it read `bal = balanceOf` and clamp:
    - amount = min(original amount, 50% of bal, bal × original amount ÷ pleaBalance(original))
    - at least min(bal, pleaBalance)/100, capped at MAX_SELL
    - raised to the 0.70 imdTEST floor, but never above the original amount or 50%
  - The gate scores the share band on min(share, original share) (CabalGate._open, :420-434).
- **Fix:**
  - For the automatic path, read Letterbox.openOf(wallet). If the id is not 0, read escrowOf(id).
    - If the escrow is open and settleable, set `bal = balanceOf + escrow amount`. Settleable means gate status Denied, Expired or Lapsed; Approved past verdictAt + 7 minutes; or Pending past submittedAt + 20 minutes.
    - If it is open but not settleable, disable Appeal with "Plea #id is still open: one plea at a time."
  - Clamp on bal exactly as the contract does.
  - Fact = `factScore(wallet, amount) − sharePoints(ceil(amount×10000/balanceOf)) + sharePoints(min(ceil(amount×10000/bal), ceil(original.amount×10000/pleaBalance(original))))`.
  - Pre-check the Letterbox's own refusals, with the C3 messages:
    - `_requireWorthTheFee(amount)`.
    - FeeTooHigh with `feesFor(true).maxFeePlea`: refused when the fee is over 10% of bal and also over 110% of the original amount, or when amount + maxFeePlea > bal.
  - Show the amount as formatted whole PLEA text, not an input. Add the line "Your open escrow of N PLEA comes back first."
  - The manual path (CabalGate.appeal) settles nothing and keeps using balanceOf.

### C5 (P1) The appeal box appears where no appeal is possible, and the sale panel is one line per state [FA-08, CT-08]
- **Now:**
  - On #/p/<id> the Appeal panel renders for the seller on both DENIED and UPHELD pleas (pages-court.tsx:614). It has a live "Appeal window 3h 59m" countdown, the amount, the text box and the costs. Only Submit is disabled, with "This appeal window is closed." (:223-227, 291-293).
  - UPHELD and already-appealed DENIED pleas both read "The Cabal denied this plea. The seller may have one appeal." (:534-536), with no link to the appeal.
  - Every other state is one sentence in "Sale status" (:463-538). PENDING is a plain "Panel deadline" countdown.
- **Should:** CabalGate._appeal (CabalGate.sol:371-394) accepts only a Denied original that is not itself an appeal, not yet appealed, within verdictAt + COOLDOWN, while the Cabal is alive and the seller has no other open plea. plea.html's reference band has blocks for PENDING, DENIED (with the appeal box), NO VERDICT, LAPSED, SOLD by letter, OBJECTION pending, SUSTAINED, OVERTURNED and UPHELD.
- **Fix:**
  - **When to show the Appeal box:** only when the wallet is the seller, status is 3, !isAppeal, !appealed, now ≤ verdictAt + COOLDOWN and cabalAlive. An expired appeal resets `appealed`, so a retry shows the box again. If another plea is open (C1's state), show the box disabled with "Plea #N is open: one plea at a time."
  - **Otherwise, one line:**
    - UPHELD: "No further appeal. The 4-hour cooldown ran from this verdict, until HH:MM UTC."
    - Already appealed: "Appealed as plea #N", linked to the plea whose originalId is this id.
    - Past the window: "The appeal window closed at HH:MM UTC."
    - Another wallet: "The seller may appeal once, until HH:MM UTC."
  - **Sale panel per state, from the band (numbers from chain):**
    - PENDING: `countdown countdown--block countdown--wait` with its bar and "Usually 3 to 6 minutes. The request expires at HH:MM:SS UTC.", plus the "Waiting for the judges" meter.
    - NO VERDICT:
      - The reason: "The panel split: A of B agreed (17 needed)." from PleaFailed agreed/answered and QUORUM. When nothing was answered: "No answer within 20 minutes."
      - Then "Cleared at once by the Intake. No cooldown; the 0.50 imdTEST oracle fee is not refunded." and "The seller may plead again at once."
      - For an auto plea, offer only "Return escrow and tip": Letterbox.settle expires the plea and refunds in one transaction.
    - LAPSED: "Approved at … but not sold within 7 minutes: the window closed at …", then "The N points still count for season K.", a "Next plea in …" countdown, and "The 4-hour cooldown runs from the verdict, until …".
    - SOLD: the rows of C16.
    - OBJECTION pending:
      - The objector and the objection text.
      - "+N points held until the second panel rules. Sustained if the new score is need−3 or less (more than 2 below the need N). The sale stands either way: …"
    - SUSTAINED:
      - "a second panel re-scored it X … The first panel gave Y".
      - "No points for this plea. The sale stands: …"
      - The stake line.
    - OVERTURNED: "#O was denied, X vs need N, at …. The appeal scored Y at …." with Sold, For and Points rows.
    - UPHELD: the line above plus the judge line.
  - **The DENIED appeal box itself:**
    - A countdown "Appeal until HH:MM UTC".
    - The costs and button of C11.
    - The letter alternative: "Or send APPEAL <text> to the Letterbox from Etherscan: 1.10 imdTEST paid in PLEA, about N PLEA (0.50 oracle fee + 0.35 to the buy wall + 0.25 tip, back if you send SELL yourself). How letters work".
    - When the denied plea has an open escrow: "Not appealing? Call settle to get your PLEA back; a new plea waits for the cooldown, until HH:MM UTC." with the Return escrow button.

### C6 (P1) The meter ignores the verdict [FA-04]
- **Now:** The Meter component (components.tsx:727-763) is used on #/p/<id> "The score", on Plead and in the appeal box. Its class is `meter`, or `meter meter--none` when the score is falsy. Three faults follow:
  - .meter__fill defaults to --approved, so DENIED and UPHELD pleas get a green bar under a red stamp.
  - A real verdict of 0 reads "No score yet".
  - There is no "passes by N" / "N short". The aria-label reads "Score 31, need 36 of 45".
- **Should:** components.html and plea.html define these states (CSS in components.css:321-323):
  - Approved: `meter`, ok-text "passes by 3", aria-label "Score 36 of 45, need 33: passes by 3".
  - Denied #213: `meter meter--denied`, bad-text "5 short", aria-label "Score 31 of 45, need 36: 5 short".
  - Pending: `meter meter--none`, legend "Waiting for the judges", aria-label "No score yet, need 36".
  - Plead: "No score yet", aria-label "No score yet. Your need is 33 of 45."
- **Fix:** Give Meter a `verdict` prop taken from pleaState, never from the score:
  - APPROVED, SOLD, LAPSED, OVERTURNED → `meter`, legend "Judges S · Need N = 71 − fact F · passes by S−N" in ok-text.
  - DENIED, UPHELD → `meter meter--denied`, "N−S short" in bad-text.
  - PENDING → `meter--none`, "Waiting for the judges".
  - Plead, the appeal preview and NO VERDICT → `meter--none`, "No score yet".
  - A verdict of 0 shows "Judges 0" with an empty fill.
  - Use the aria-labels quoted above. The marker clamp and the need > 45 case are X3.

### C7 (P1) A sold appeal is stamped SOLD instead of OVERTURNED [CT-06, FB-10]
- **Now:** pleaState (chain.ts:321-345) returns OVERTURNED only for status 2. Once an approved appeal is sold (status 4), every stamp reads "SOLD 42 vs need 37": plea page, Wall, Profile, Objections and share card.
- **Should:** The PAGE-KIT stamp rule says "OVERTURNED and UPHELD mark an appeal". sample-data #207 has stamp OVERTURNED and soldStamp SOLD. wall.html #207 shows "Overturned 34 vs need 33" with "sold for 15.48 IMD" in the foot. See also plea.html's OVERTURNED reference.
- **Fix:** In pleaState:
  - isAppeal and (status 4, or status 2 with now ≤ verdictAt + EXECUTE_WINDOW) → OVERTURNED.
  - isAppeal and status 3 → UPHELD.
  - A lapsed appeal stays LAPSED.
  - Keep "sold for X" in the card foot and the sale rows.
  - The Wall filters (S6) take their states from this function.

### C8 (P1) A VOID objection is shown as a re-score of 0; OVERRULED lacks its points [CT-07, FB-11, TT-10]
- **Now:** ObjectionStamps (components.tsx:637-655) and the share card (share.tsx:74-84) print "#id: newScore vs need N" for every ruling except pending. A void therefore reads "VOID #1: 0 vs need 37". Recent rulings on #/objections prints "new score 0" (pages-court.tsx:787-790). Overruled has no "· counts N points".
- **Should:** components.html gives one form per ruling:
  - "Sustained · #8: 29 vs need 33"
  - "Overruled · #7: 33 vs need 33 · counts 39 points"
  - "Void · the panel split: nothing changes"
  - Tribunal._void never sets newScore (Tribunal.sol:383-388). Tribunal.status counts points as Seasons.pointsOf (when recorded) or pointsFor(seller, min(score, lowest)).
- **Fix:** Write one helper `objectionLine(o, p)` and use it in ObjectionStamps, the plea cards (S7), share.tsx and the Objections table:

  | Ruling | Line |
  |---|---|
  | Pending | "pending" |
  | Sustained | "#id: S vs need N" |
  | Overruled | "#id: S vs need N · counts P points", with P as in Tribunal.status |
  | Void, ObjectionVoid.reason "stale" | "#id: no answer within 20 minutes: nothing changes" |
  | Void, any other reason | "#id: the panel split: nothing changes" |

  Never print newScore for a void.

### C9 (P2) Plead states are one line under the button; Plead is not closed when the Cabal dies; CannotPass reads badly [FA-12, CT-18]
- **Now:**
  - Every state on #/plead is one `reason` string under Submit (pages-trade.tsx:564-582): dead, open plea, cooldown, range, "Reading your fact score.".
  - After the Cabal's death the whole form stays: amount, chips, text, box and costs.
  - CannotPass (Max, need 50, at 360 and 1280) keeps the meter with its need marker past the bar's end and on the card's edge. Its warning-icon notice repeats itself: "This plea cannot pass" / "This plea cannot pass (CannotPass). Sell a smaller share…" (:655-668), and names no size that passes.
  - The amount input is never marked invalid. There is no not-connected notice and no skeleton.
- **Should:** plead.html's reference band has these states: open plea (notice--info), Cooldown active (notice--warn), CannotPass, Not connected, Amount over the cap (is-invalid), Loading (skeleton), and "The Cabal is dead: plead is closed" (.empty). The brief's MUST HAVE: "After the Cabal dies: … Plead and Objections closed", and "above 45, disable submit and say the plea cannot pass (CannotPass)".
- **Fix:** Show each state above the Submit block, with its line under the button:

  | State | Notice above Submit | Line under Submit |
  |---|---|---|
  | Open plea, approved | notice--info "Plea #N is open: one plea at a time." / "Sell by HH:MM UTC. Next plea 4 hours after the sale (HH:MM UTC if sold now), or HH:MM UTC if it lapses. Open plea #N" | "Plea #N is still open. You can write your next plea now; it is kept until you can send it." |
  | Open plea, pending | "Plea #N is waiting for the Cabal, until HH:MM UTC." | same line as above |
  | Cooldown | notice--warn "Next plea possible at HH:MM UTC." / "4-hour cooldown after your sale." (say denial or lapse when that set it) | "Cooldown until HH:MM UTC. You can write your plea now and send it then." |
  | CannotPass | see below | "Need 46 of 45: cannot pass at this size. Nothing is paid." |
  | Not connected | notice--info "Connect in the top bar to plead." / "Everything else here reads without a wallet." | "Connect a wallet first: your balance, facts and need come from it." |
  | Refused text | none | "Fix the text above to submit. Nothing is paid until it passes." |

  - **CannotPass:**
    - Show the facts (C10). In place of the meter (X3 draws no bar when need > 45): "Need 46 = 71 − fact 25, above the 45 a plea can score."
    - Then notice--bad with the prohibit icon: "This plea cannot pass." / "Even a perfect plea (45) cannot pass at this size. Plead 20% or less (need 33) or wait for better facts."
    - Name the largest chip amount whose need is ≤ 45, by reading CabalGate.factScore at each chip amount. If none passes, say only "Wait for better facts."
  - **Out of range:** `.input.is-invalid` with `aria-invalid="true"` and the bad-text hint "At most 2,500,000 PLEA in one plea (3,100,000 is 50% of your balance). Lower the amount." Add the matching line for under the minimum.
  - **Loading:** loading-label "Reading your balance and buy record from the chain…" and a skeleton.
  - **Cabal dead** (diedAt > 0): replace the whole form with .empty (i-gavel) "Plead is closed" / "No verdict for 33 hours, so PLEA trades freely forever: sell on the Buy page with no plea. Court is adjourned." and btn--sm "Sell on the Buy page" (#/buy). This is also the Plead half of TR-08, which X16 lists.

### C10 (P2) Plead form: no fact breakdown, Submit at the top, side panels differ [CT-12, FA-09, FA-27]
- **Now:**
  - On #/plead, at every width, Submit and its reason come first in the card, above the amount (pages-trade.tsx:591-617).
  - Only CabalGate.factScore is read, and it appears only in the meter legend. There is no "Your fact score" field and no four facts (:655-662).
  - A connected wallet with no amount still reads "Connect and enter an amount to see them".
  - Side panels (:585-588, 669-673, 741-786): the timeline has numbered dots, all is-later, and its 4th step is "Record points". There is no "Rules the contract checks" panel. The lead, hint and aside are shorter. "Pleas that passed" uses full wall cards.
- **Should:**
  - plead.html order: amount → "Your fact score · From the chain: 16 + 4 + 13 + 5 = 38" with four .fact cells (Share sold, Held, Profit or loss, 24h trend) → meter → text → auto-sell box and costs → submit block.
  - The submit block has its btn__sub and the note "Submit stays off until your text passes the checks; nothing is paid before that. One plea at a time, and a 4-hour cooldown follows a sale, a denial or a lapse."
  - The brief's MUST HAVE: "Before paying, show the fact score and need = 71 - fact".
- **Fix:**
  - Reorder the Plead form as in plead.html (T7 reorders Buy and lists FA-10, which covers both).
  - Compute the four facts with CabalGate._factScoreAt's rules (CabalGate.sol:262-306), from PLEA.balanceOf, PleaHook.basisOf (spent, heldPlea, avgBuyTime), latestPrice, price24hAgo and CabalGate.startedAt:

    | Fact | Value | Points |
    |---|---|---|
    | Share sold | ceil(amount×10000/balance) bps | ≤2000: 16; ≤3500: 9; else 3 |
    | Held | now − avgBuyTime | ≥7d: 7; ≥3d: 4; ≥1d: 2; else 0 |
    | Profit or loss | heldPlea × latestPrice / 2^96 against spent | loss: 13; gain ≤50%: 12; ≤200%: 10; ≤500%: 8; ≤1,000%: 6; more: 4; none when spent is 0 |
    | 24h trend | latestPrice against price24hAgo | ago = 0: +5; latest > ago×1.02: +9 "up"; latest ≥ ago×0.98: +5 "flat"; else 0 "down" |

  - When heldPlea < amount, the gate takes the PLEA-weighted mean of held + P&L, with (held since startedAt + 10) for the uncovered PLEA. Say so in a note: "N PLEA have no buy record: they count as held since trading opened, profit 10".
  - The total must equal CabalGate.factScore(wallet, amount). If it does not, show only the total and the share cell.
  - Connected but no amount yet: "Enter an amount to read your fact score and need."
  - Port the rest of plead.html:
    - The lead "…The Cabal, 30 judges, scores it from 0 to 45…", with PANEL_SIZE and MAX_PLEA_SCORE from chain.
    - The aside "One line, up to 280 bytes" and the bar "≈ 280 Latin · 140 Cyrillic · 93 CJK".
    - The hint with "lines like “give me 45” count as manipulation and score 0".
    - The timeline: arrow-right, hourglass, gavel and timer icons; the first step is-now; "Up to 20 minutes, usually 3 to 6. 30 judges score it; 17 must agree."; the three verdict lines; the 4th step "Cooldown · 4 hours after a sale, a denial or a lapse."
    - The "Rules the contract checks" panel.
    - Compact "Pleas that passed" entries: stamp, link, text and meta.

### C11 (P2) Cost breakdowns are incomplete on Plead and in the appeal box [FA-11, TT-14, CT-24]
- **Now:**
  - Plead with the box on (pages-trade.tsx:674-739):
    - "Runner tip: Read when trading opens" before seeding.
    - "Paid in PLEA 0.75 imdTEST equivalent", with no PLEA amount.
    - "At most N PLEA".
    - "Auto-sell fee from delivered sale 0.35", read from CabalGate.APPEAL_POOL_SHARE.
  - Plead with the box off: "Oracle fee, approve once / Extra fee none / Sell yourself within 07:00".
  - In both modes there are no "You get" or "At least" rows, the button is a plain "Submit plea", and the box copy has no numbers.
  - The appeal box (pages-court.tsx:248-283):
    - It always shows both "Automatic total, paid in PLEA 1.10" and "Manual total 0.85".
    - It has no tip, PLEA amount, At most or auto-sell fee row.
    - Its toggle has no description.
    - The appeal floor is computed as 2 × APPEAL_POOL_SHARE (appeal.ts:36-38).
- **Should:** The brief's MUST HAVE: "Show both cost breakdowns" (the 0.50 oracle fee + 0.25 tip and 0.35 of a delivered sale to the pot; manual: approve 0.50, submitSell, executeSell(minOut)). Follow plead.html's rows and sub-labels for each box state, and plea.html's DENIED appeal rows. TIP 0.25e18, AUTO_SELL_FEE 0.35e18, MIN_SALE_VALUE 0.70e18 and MIN_OUT_BPS 9500 are internal Letterbox constants (Letterbox.sol:111-136). Run 9's Letterbox buys the oracle fee with PLEA (`mintOracleFee = false`, README Sepolia settings), so `feesFor(false).feeImd` is 0.75 and `feesFor(true).feeImd` is 1.10.
- **Fix:**
  - Declare those Letterbox constants once, named and commented with their Letterbox.sol lines. Take the 2.25% from PleaHook.PLEA_BURN_BPS + IMD_FEE_BPS. Compute the appeal floor from MIN_SALE_VALUE.
  - E below is C2's live sale estimate. V = amount × latestPrice / 2^96.
  - **Plead, box off:**
    - Rows: "Oracle fee, from your imdTEST (approve once) 0.50"; "Extra fee none"; total "You get, if approved and sold about E"; "At least, with 1% slippage E×0.99".
    - Note: "Off: you pay the 0.50 imdTEST oracle fee from your imdTEST and sell yourself within 7 minutes, no extra fee."
    - Button: "Submit plea `<btn__sub>`0.50 imdTEST".
  - **Plead, box on:**
    - Rows: "Oracle fee 0.50"; "Tip for whoever sells it 0.25" (always shown, from the constant).
    - Total "Paid in PLEA, 0.75 imdTEST · about N PLEA", with N = feeImd × 2^96 / latestPrice ÷ (1 − 2.25%). Before seeding, write "after trading opens".
    - "At most M PLEA" (feesFor(false).maxFeePlea); "Auto-sell fee, from the sale to the season prize pot 0.35".
    - Total "You get, if approved and sold about E − 0.35"; "At least V×95%×(1−2.25%) − 0.35" (the Letterbox's own minimum).
    - Note: "Press Sell yourself and you keep the tip. If nobody sells it, or on any other ending, your PLEA and the tip come back; the 0.50 imdTEST oracle fee is spent."
    - Button: "`<btn__sub>`0.75 imdTEST in PLEA".
  - **Box description:** "The fees are paid in PLEA. If approved, anyone can sell it for you within 7 minutes and earns the 0.25 imdTEST tip. 0.35 imdTEST of the sale goes to the season prize pot." Keep the mockup's "our runner does…" only if IMD runs a runner for run 9; FRONTEND.md:58 says the site runs none.
  - **Appeal, box on:**
    - Rows: Oracle fee 0.50; To the buy wall 0.35; Tip for whoever sells it 0.25.
    - "Paid in PLEA, 1.10 imdTEST · about N PLEA"; "At most M PLEA" (feesFor(true)); auto-sell fee 0.35.
    - The mockup's note.
  - **Appeal, box off:**
    - Rows: "Oracle fee, from your imdTEST 0.50"; "To the buy wall, from your imdTEST 0.35"; total "You pay 0.85"; "Extra fee none".
    - Note: "Off: you pay in imdTEST and, if approved, sell yourself within 7 minutes."
  - **Appeal button:** "Appeal", with btn__sub "1.10 imdTEST in PLEA" or "0.85 imdTEST". Tie the toggle's description with aria-describedby (same runner caveat).

### C12 (P2) Amount chips and amounts filled into inputs show raw 18-decimal values [FA-03, CT-20, FA-V3]
- **Now:**
  - On #/plead with a wallet holding 0 PLEA, all five chips have `aria-pressed="true"`: the code compares 0n === 0n (pages-trade.tsx:636-640).
  - Chips fill raw 18-decimal strings such as "38550.509657451895843767" and "1539879.125015331044799848", cut off at 360 (:641-648).
  - Sell now's minimum shows "12.25962183958937047" (pages-court.tsx:503-506).
  - The auto appeal amount shows "999999.999999999983222784" (:237-244).
- **Should:** components.html and plead.html press at most one chip, the one that matches the amount. PAGE-KIT formats: PLEA as whole numbers with thousands separators ("1,240,000"), imdTEST with 2 decimals.
- **Fix:**
  - A chip is pressed only when raw > 0n and it equals the chip's amount.
  - With a 0 balance, set the chips aria-disabled with the hint "You hold no PLEA yet. Buy PLEA first."
  - Chips fill whole PLEA with separators, rounded down (`v / 10n ** 18n * 10n ** 18n`). The exception is the 1% chip: it rounds up so it never falls below the gate's 1% minimum, and it fills C3's auto minimum when that is larger.
  - AmountInput accepts and strips thousands separators; keep the exact bigint in state.
  - The appeal amount (C4) and the Sell now amounts (C2, C14) become formatted text, not inputs; the transaction still uses the exact bigint. Buy's Max follows T7.

### C13 (P2) Text box checks differ from site.js and re-announce on every key [FA-28, FB-26]
- **Now:** TextBox (components.tsx:193-338) serves the plea, appeal, objection and letter boxes:
  - An empty box shows one line, "Write your text to run the contract's checks."
  - While typing, issue messages with x icons come before four rows with different wording ("1–280 UTF-8 bytes", "No [PLEA or [OBJECTION marker prefixes"). A text that is too long shows two red rows.
  - The counter never gets counter--over.
  - The sr-only `role="status"` line holds the first message with live numbers, so it re-announces on every keystroke (:326-332).
  - The letter's "Reads as" is mono chain-text, shown even for an empty box, with text-check.js's hard-coded "IMD".
- **Should:** site.js:47-57 and 66-152 is the kit's spec for behaviour and wording:
  - Four rule rows always show, in the contract's order. Before typing they are idle (check--idle, minus icon):
    - "1 to 280 bytes", which becomes "(N used)" or ": N now, cut M"
    - "One line, no control characters"
    - "No hidden characters (zero-width, direction marks, variation selectors)"
    - "No “[plea” or “[objection” markers, in any case"
  - Extra issues follow the rows: warning-circle for problems, the warning icon for warnings.
  - counter--over turns on above 280.
  - One polite line announces only when the set of problem codes changes.
  - letters.html shows "Reads as:" in a notice with the envelope icon.
- **Fix:**
  - Port ruleRows and the announce logic from site.js into TextBox for the non-name kinds. The name box is S8.
  - Drop the "Write your text…" line, show the four rows idle, merge the length issue into row 1, and toggle counter--over.
  - Set aria-invalid only when the box is shown bad (touched or not empty).
  - Replace the `role="status"` line with one `aria-live="polite"` sr-only line keyed on the problem codes ("Text passes the checks." / "N problems: …").
  - Show the letter's "Reads as" only when the box has text, as the kit's notice with the envelope icon. Swap " IMD" for the chain's pair symbol at render (`\bIMD\b`), so text-check.js stays byte-identical.

### C14 (P2) The sell window is not the urgent pair [CT-13, FA-05]
- **Now:** On #/p/<id>, for an approved plea seen by its seller, at every width (pages-court.tsx:477-526):
  - The countdown is a small inline countdown--urgent, "Sell within 06:48", with no bar, closing time or lapse note.
  - A "Minimum you receive" input carries a technical hint.
  - "Approve PLEA", "Sell now" and the auto seller's "Sell yourself" are yellow btn--primary with no btn__sub. ApprovedAction defaults to primary (components.tsx:430).
- **Should:** PAGE-KIT reserves "--ink only for the sell window", and README calls the window and its button "the urgent pair". plea.html "Your sale":
  - `countdown countdown--block countdown--urgent` with the timer icon, mm:ss, countdown__bar and "The window closes at 08:06:12 UTC. Miss it and the plea lapses (the points still count)."
  - Costs rows: Sells / You get about / At least, with 1% slippage.
  - `btn btn--ink btn--block` "Sell now `<btn__sub>`≈ 17.14 IMD".
- **Fix:**
  - Add a `variant` to Action and ApprovedAction. Use btn--ink for the seller's Approve PLEA, Sell now and Sell yourself.
  - Render the block countdown as in plea.html, with aria-label "Sell within 6 minutes 12 seconds. The window closes at 08:06:12 UTC."
  - Replace the input with the three costs rows, filled from C2's live quote. Label the button "Sell now ≈ X imdTEST".
  - Other wallets keep the plain countdown. For a manual plea they read "Only the seller can sell plea #N." (plea.html "Seen by someone else").

### C15 (P2) Plea status page anatomy: card, timeline, share and details panels, title [CT-11, FA-06, FA-26, FA-V4]
- **Now:** On #/p/<id>, in every state, width and theme:
  - The plea uses the wall-card layout, with no facts, summary or judge line (pages-court.tsx:411-456).
  - "The score" panel holds the meter, Amount / Submitted / Verdict, a short oracle id and a "Share this plea" link to #/share.
  - The timeline (details.tsx:380-446) is Submitted / Verdict / Sold / "Points wait". Done steps use is-now. The points step shows in every state, including denied, upheld, pending and no verdict.
  - There is no Share panel and no Details panel.
  - The breadcrumb is "Wall / Plea #N" as plain text. There is no YOU badge, and the lead is "APPROVED. 36 vs need 33." (:398-410).
- **Should:** plea.html main:
  - Title area:
    - A breadcrumb ending in `<a aria-current="page">Plea #214</a>`, and the h1 with badge--you.
    - A lead in words: "The Cabal approved your plea 48 s ago. Sell within the 7-minute window, by 08:06 UTC. Your +43 points are held while objections are open: record them after 08:19 UTC."
  - The plea card, article.card.plea:
    - plea__top: who, badges, "approved 48 s ago" and stamp--lg.
    - .facts and the meter.
    - plea__summary: "Sells N PLEA ≈ X IMD" and "+43 points (36 × 1.2) held until 08:19 UTC".
    - plea__judge.
  - "Your points": the stat, "36 × 1.2 with your IMD seat (43.2, rounded down)" and the hold line.
  - The timeline uses is-done / is-now / is-later: Submitted, Judged, Sell window, Objections, Record the points, 4-hour cooldown.
  - A Share panel and a Details panel in `.split--even.split--stretch`.
- **Fix:** Build the page as plea.html, with its classes (status__plea, status__side, status__timeline).
  - **Facts:**
    - Share sold is exact: amount ÷ CabalGate.pleaBalance(id). For an appeal, use the band of min(share, original share).
    - For the other three cells, read C10's inputs at the block before the PleaSubmitted log, using the submit block's timestamp.
    - If the RPC refuses historical state, show one cell "Held, profit and trend +X", with X = factScore − share points.
  - **Judge line:**
    - "Judged by 30 · 26 agreed · 4m 10s", from the api.imd.fun panelSize and agreed, and verdictAt − submittedAt.
    - Add "A judge said: “…”" only when the oracle response carries a comment.
  - **Timeline:** steps per state. Show the points steps only for APPROVED, SOLD, LAPSED and OVERTURNED. Denials show the appeal window and the cooldown instead.
  - **Share panel:** the same share-card component as #/share/<id> (its content is fixed in S13), the post text, and Share on X / Download image / Copy image.
  - **Details, dl.addr-list:**
    - Seller: name, mono address and copy-btn.
    - Amount: "N PLEA (X% of B)".
    - Value: "X imdTEST at 1M PLEA = Y imdTEST".
    - Fact score: "38 (16 + 4 + 13 + 5)".
    - Need: "33 (71 − 38)".
    - Panel: "30 seats, quorum 17: 26 of 30 agreed, in 4m 10s", with the "View oracle request" link.
    - Plea transaction and Verdict transaction: the time and a link to sepolia.etherscan.io/tx/<hash>, from the PleaSubmitted and Verdict logs.
    - Contract: the CabalGate address.
  - **Title area:** the breadcrumb, the YOU badge for the seller and a lead per state, as above.

### C16 (P2) One sale shows two unlabelled amounts [CT-10]
- **Now:** On #/p/1, an auto plea sold by a runner:
  - The card foot says "Sold for 4.43", and the sale panel says "Sold. 4.43 imdTEST paid to the seller." Both come from escrowOf soldFor (components.tsx:687-698, pages-court.tsx:530-531).
  - The timeline says "Sold 4.78", from SellExecuted imdOut (details.tsx:412-426).
  - The 0.35 auto-sell fee, the runner and the tip appear nowhere.
- **Should:** plea.html "SOLD by letter · #212" lists: Sold N PLEA / Sold by 0x… / Tip, to whoever sold it 0.25 IMD / To the writer 25.98 IMD / Points. Per the brief, the auto-sell fee goes to the season prize pot.
- **Fix:**
  - For an escrowed plea, read the Letterbox Delivered event (runner, imdOut, tip, fee) and show these rows:
    - Sold N PLEA.
    - Sold by <runner>, or "you" when the runner is the writer.
    - Tip, to whoever sold it 0.25.
    - Auto-sell fee, to the season prize pot 0.35. Show it only when fee > 0; letters pay none.
    - To the writer X (soldFor, which equals Delivered.imdOut).
    - Points.
  - For a manual sale: "Sold N PLEA for X imdTEST at HH:MM UTC" (SellExecuted.imdOut).
  - The card foot "sold for" and the timeline use the writer's amount.

### C17 (P2) The plea page's objections panel and visitor states [FA-07, CT-V1]
- **Now:**
  - Every plea page ends with "Objections · The sale stands. Objections can only reduce season points. · Open the case" (pages-court.tsx:617-622). That includes DENIED, UPHELD, PENDING and NO VERDICT pleas, which have no sale and cannot take an objection.
  - The panel has no countdown, filed count, rules or Object action.
  - Another wallet and no wallet both see "Only the seller can execute this manual plea. Connect in the top bar if it is yours."
- **Should:**
  - Tribunal.object reverts NotApproved unless gate.result(id).approved, which means status 2, 4 or 5 (Tribunal.sol:259-263).
  - plea.html's Objections panel:
    - A countdown "Objections close in 19:12" and the pill "0 of 2 filed".
    - The rules text: "You can't object to your own plea. Others may until 08:19 UTC, for a 0.50 IMD fee + 0.35 IMD stake. A new panel of 30 re-scores it: sustained only at 30 or less (more than 2 below your need of 33), and then no points. Void if that panel splits or gives no answer within 20 minutes: nothing changes. The sale is never touched."
    - The link "How objections work →".
  - The band also has "Seen by someone else" and "Not connected: a visitor".
- **Fix:**
  - Show the panel only for status 2, 4 and 5.
  - Inside OBJECTION_WINDOW, show the countdown and the pill "N of 2 filed" (Tribunal.caseOf count + pending), then by viewer:
    - **The seller:** the rules text above, with the sustained threshold = need − 3.
    - **Another wallet:** btn--primary "Object `<btn__sub>`0.85 imdTEST" linking to #/objections?plea=N, then "0.50 imdTEST oracle fee + 0.35 imdTEST stake. A new panel of 30 re-scores it; the sale is never touched."
    - **No wallet:** notice--info "Connect in the top bar to object." / "The plea, its verdict and its timeline read without a wallet. Only the seller can sell it.", an aria-disabled Object button, and "Connect a wallet first. Objections close at HH:MM UTC."
  - After the window: "Objections closed at HH:MM UTC · N of 2 filed", with the C8 lines.
  - A manual plea seen by another wallet: "Only the seller can sell plea #N."

### C18 (P2) The Objections page is a generic rewrite [FB-08]
- **Now:** On #/objections (pages-court.tsx:629-834):
  - The lead differs and there are no pills.
  - Each open case is a Panel that nests a whole PleaCard link card, then a countdown, the text box, costs and a bare "Object" button.
  - The seller's own case and full cases keep the form, with only a one-line reason. Closed cases drop out of the list.
  - "Recent rulings" is an auto-grid of panels ("new score N").
  - "How a ruling works" is one paragraph at the bottom.
  - The dead state is "The Cabal is dead / New objections are closed."
- **Should:** pages/objections.html and its band:
  - The lead "For 20 minutes after an approval, anyone else may object…" with the pills "20 minutes after an approval", "0.50 IMD fee + 0.35 IMD stake" and "At most 2 per plea".
  - "Open now" with the meta "N approved pleas · closing soonest first".
  - A .split of article.card.plea cases beside the "How a ruling works" panel.
  - The rulings table.
  - Band states: Sending, A ruling arrives, Case full, Window closed, The seller sees their own plea, Not connected, Refused objection text, Nothing open, Loading, Error, After the Cabal dies.
- **Fix:** Rebuild the page from objections.html, using Tribunal's OBJECTION_WINDOW, ORACLE_FEE, STAKE, MAX_OBJECTIONS and MARGIN.
  - **Header pills:** the three pills above, from Tribunal.OBJECTION_WINDOW (X10's span()), ORACLE_FEE, STAKE and MAX_OBJECTIONS.
  - **Case card:**
    - plea__head: h3 "Plea #N", by, badges, "approved 12 min ago". Then the stamp and the text.
    - The factline "Judges S · Need N = 71 − fact F · Sold X PLEA for Y imdTEST".
    - The countdown and the pill "1 of 2 filed · one slot left".
    - A pending objection in panel--sunken: "Objection #9 pending by … · a new panel is re-scoring the plea", then its text.
    - The points line.
    - The form "Object to plea #N", with the hint "Say why the score is too high. On plea #N the objection is sustained if the new score is N−3 or less, more than 2 below the need N. How a ruling works".
    - The button "Object `<btn__sub>`0.85 imdTEST" and the note "0.50 imdTEST oracle fee + 0.35 imdTEST stake, from your imdTEST (balance). Write your objection to send it; nothing is paid until it passes."
  - **Case states:**
    - The seller's own plea: the hand-palm notice and no form.
    - A full case: the prohibit notice "This case is full. A plea takes at most 2 objections, from different wallets.", an aria-disabled Object button and "Two objections are pending on plea #N. Nothing to send."
    - A case whose window closes while it is shown, or one opened by ?plea=N: "Objections closed at HH:MM UTC" and the Record line.
  - **Side panel:**
    - The Sustained, Overruled and Void small stamps, with their meanings.
    - Costs: "Oracle fee, spent 0.50 / Stake: back unless overruled 0.35 / An objection, from your imdTEST 0.85".
    - The four lines with the coins, scales, gavel and hourglass icons.
  - **Recent rulings:**
    - A `.table.table--tight` inside a focusable `.table-wrap` with role="region" and an aria-label. sr-only caption: "Recent rulings on objections, newest first".
    - Columns, each `th scope="col"`: Objection / Ruling / Plea / Points that count / Stake / Objection text.
    - Rows as in the mockup: "Sustained 29 vs need 33 · 23 of 30 agreed" (the agreed count from api.imd.fun when available), "none · was 34", "0.35 imdTEST returned".
    - A void row uses the C8 line, "unchanged" and "back to the objector".
    - Keep the Expire and Settle stake buttons on their rows.
  - **Dead state:** .empty "The court has risen" / "No plea can be approved any more, so there is nothing new to object to. Stakes on objections already filed still move when anyone calls settle." with btn--sm "Sell on the Buy page". Recent rulings stay.

### C19 (P2) Letters: misleading 'sells automatically', missing sections, '—' fees before seeding [FB-03, FB-09]
- **Now:** #/letters (pages-info.tsx:247-433, details.tsx:192-254):
  - The "any text" row says "A new plea for 20% of your PLEA, within the cap. It sells automatically if approved. Letters pay no auto-sell fee." (:337). A letter plea sells only if someone calls deliver within 7 minutes, or the writer sends SELL; the site runs no runner (FRONTEND.md:58).
  - The APPEAL, SELL and NAME rows drop the cap, the 4-hour window, the 1.10 cost, the tip and the 3–20 rule.
  - Missing parts:
    - The fees line in the Letterbox card and the Write Contract field list.
    - The "Commands are matched in capitals" notice and the "Try your letter" head.
    - The Limits panel, the Example letters and the status sentences.
    - The "Never tell the judges how to score" warning.
  - Before seeding, the fees table shows "— imdTEST" for the tip, the letter and the appeal, and "—" for "Most PLEA for the fee", because feesFor reverts NoPrice. There is no total row and no auto-sell row.
- **Should:** pages/letters.html, with only the brief's Sepolia changes: no message-page card; keep Write Contract letter(text) and the raw data.
- **Fix:** Port letters.html's copy, with numbers from chain:
  - **Meta:** "Same judges, same score, same need as a plea from the site. If the Cabal approves, anyone may sell it for you within 7 minutes and earn the 0.25 imdTEST tip, or you send SELL and keep the tip." Same runner caveat as C11.
  - **Commands:**
    - any text: "A new plea for 20% of your PLEA (at most 2,500,000). If approved, anyone may sell it for you within 7 minutes and earns the 0.25 imdTEST tip. On the Wall it carries the BY LETTER badge."
    - APPEAL: "Appeals your latest denied plea within its 4 hours, for the same share of your PLEA. It costs 1.10 imdTEST in PLEA: 0.35 imdTEST more, to the buy wall."
    - SELL: "Sells your approved letter plea yourself, within its 7 minutes and if nobody has yet, and the 0.25 imdTEST tip comes back to you."
    - NAME: "Sets your display name: 3 to 20 characters, only lower-case a–z, digits 0–9 and _. NAME alone clears it."
  - **Info notice:** "Commands are matched in capitals, at the very start. “SELL me some mercy” is read as SELL, not as a plea. To plead, start with another word."
  - **Letterbox card:** "…The fees (0.75 imdTEST, about N PLEA) come out of your PLEA; in ETH you pay only the gas."
  - **Send steps:** the Write Contract list (Tab Contract › Write Contract / Function letter(text) / text your letter, in plain words), and the wallet hint with a NAME example whose hex the page computes.
  - **"Try your letter":** a section head. Keep the working Send letter button, so the meta must not say that nothing is sent.
  - **"What it costs" Fees rows:** Oracle fee 0.50; Tip 0.25; A letter 0.75; "In PLEA … about N PLEA"; "Never more than M PLEA"; APPEAL 1.10 with its PLEA rows; "Auto-sell fee none for letters". Always show the fixed imdTEST amounts (C11's constants). Before seeding, write "after trading opens" in the PLEA rows.
  - **Limits:**
    - 280 bytes, with the script estimate.
    - One line, no hidden characters.
    - A balance of at least 10 × feesFor(false).maxFeePlea.
    - A plea worth at least 0.70 imdTEST.
    - 20% of the balance at least 1,000 PLEA.
    - The closing sentence.
  - **Example letters:** the three letter-samples with "Reads as".
  - **"Read your status on Etherscan":** the connected wallet's live Letterbox.status(address) instead of the mockup's sample sentences, plus the leaderboard() line.
  - **Warning notice:** "Never tell the judges how to score…".

### C20 (P2) #/p/<id> for a plea that does not exist shows a transaction error [FA-21, CK-12]
- **Now:** Live #/p/1, with no pleas yet, no wallet, at every width and in both themes: "Plea not found" over "The request could not complete. Refresh the chain data, check your wallet is on Sepolia, and try again. Nothing is confirmed until a receipt appears.", with a 20 px icon. There is no breadcrumb and no way back (pages-court.tsx:361-373). getPlea throws "This plea does not exist. Check the plea number." (chain.ts:133-134). useRead passes it through explainError (context.tsx:170), which lets only the Connect/Switch texts through (errors.ts:123-128) and falls back to the generic line (:151).
- **Should:** A plain not-found message in the kit's empty pattern, with plea.html's breadcrumb. #/share/1 already says "Check the plea number."
- **Fix:**
  - When the id is not digits, is 0, or is ≥ CabalGate.nextId, do not read. Render the breadcrumb "Wall / Plea #N", h1 "Plea #N" and .empty (i-scales, X12's component) "No plea #N yet" / "Check the plea number in this link. N pleas so far." Before seeding, say "The first plea comes after trading opens." instead. Add btn--sm "See the Wall" and a "Plead to sell" link (only while the Cabal lives).
  - #/share/<id> follows the same rule.
  - useRead uses X11's `explainReadError`, which passes the site's own plain Error messages through instead of the generic text.
  - A real RPC failure keeps the error box (X11).

### C21 (P3) Wrong copy on finished states, and the points hold [CT-21, TT-20]
- **Now:**
  - SUSTAINED #2 has the lead "Points wait for objections to end; nothing records them by itself." and "Objections close in 14:50" under "No points" (pages-court.tsx:407-409, 578-587).
  - LAPSED keeps "Points wait" after objections closed.
  - A failure with 0 answers reads "panel split 0/0" (components.tsx:625-631).
  - The Seasons list shows "Plea #2 · +0 points once recorded".
  - `held = standing[0] || now ≤ objectionUntil` (pages-court.tsx:394), so Record stays disabled until the window ends even after two rulings, when Tribunal.standing already says the points are not held.
  - The UPHELD and appealed reason is "This appeal window is closed.".
  - The timeline's gross sale amount differs from the card's net amount.
  - Buy reads "Next plea: Ready when trading opens" after seeding (pages-trade.tsx:446).
- **Should:** Each state uses its own text. Tribunal.standing (Tribunal.sol:194-206) decides the hold: the points are not held once MAX_OBJECTIONS rulings exist. Seasons.record follows it.
- **Fix:**
  - Branch the lead and the points panel by state. No "Points wait" line for sustained, excluded, recorded or non-approved pleas, and no hold countdown when the plea earns no points.
  - NO VERDICT sub:
    - Failure status 1: "request refused".
    - Status 2 with 0 answered, or a pending plea past its 20 minutes: "no answer".
    - Otherwise: "panel split A/B".
  - `held = Tribunal.standing(id).held` only, re-read every poll. Show the countdown only while it is true.
  - Drop sustained and excluded pleas from every "points to record" list (S2 replaces the Seasons list).
  - C5 fixes the appeal reasons, C16 the sale amounts, and T8 (with C1's state) Buy's "Next plea" line.

### C22 (P3) The oracle fallback trusts any api.imd.fun request with the same question [TT-19]
- **Now:** For a plea with no Verdict log (a pending plea), oracleRequest (oracle.ts:9-17, 63-85) takes the newest of api.imd.fun's 100 latest requests whose question text equals CabalGate.question(id). Anyone can post that text, and the page then shows its "30 judges · N agreed · status". The "View oracle request" link puts the API id into the URL unencoded (pages-court.tsx:441-449).
- **Should:** Show only the request the gate paid for: CabalGate.body(id) names `consumer.verifyingContract` = CabalGate and `consumer.chainId` = 11155111 (CabalGate.sol:741-752). The on-chain verdict stays the source of truth.
- **Fix:**
  - Fetch the details of at most 3 text matches, newest first, and accept the first whose consumer.verifyingContract equals the CabalGate address (compare case-insensitively) and whose consumer.chainId is 11155111.
  - The Verdict path keeps decoding requestId with requestUuid.
  - With no verified match, keep "This request is not in the public API's latest requests yet."
  - Wrap the id in encodeURIComponent in the link.

### C23 (P3) 'Copy hex data' stays 'Copied' [FB-28]
- **Now:** In the #/letters checker, `copied` is set once and never reset (pages-info.tsx:252, 378-391). After the letter is edited, the button still says "Copied" while the clipboard holds the old hex. A failed copy is silent.
- **Should:** The letters.html band shows "Copied" for 1.5 s after a click. site.js:189-201 announces success, and on failure says "Copy did not work here: select the text and copy it."
- **Fix:** Reset the label to "Copy hex data" after 1.5 s and whenever the text changes. On failure, show and announce "Copy did not work here: select the text and copy it."

## S. Seasons, Wall, Profile, Claim, Share

Scope: #/seasons, #/wall, #/profile and #/profile/<address>, #/claim, #/share/<id>, and the plea cards those pages and Home share. Home's own content (hero, live numbers, How it works, Contracts) is in section X. Everywhere below, a mockup amount in "IMD" is written with the paired token's symbol (constants.pairSymbol, imdTEST on this run), and every rule number (season length, grace, top 25, 60 points, shares, bonus, windows) is read from chain constants, never copied from the mockup's sample data.

### S1 (P1) One season model for the running, ended-but-not-closed and dead states, with each season's own pot [CT-02, TT-03, TT-04, FB-02]
- **Now:** chain.ts:232-236 reads topOf(currentSeason) and seasonBounds(nextToClose) only, and every pot is Seasons.pot(): the strip (App.tsx:163-164), the Home stat (pages-info.tsx:122), the #/seasons stat (pages-court.tsx:841) and every leaderboard 'Prize now' (pages-court.tsx:1034-1046). Between a season's end and its close (at least the 1-hour grace, and with no limit, since nothing closes a season by itself), #/seasons at any width reads 'Season 2', shows season 1's whole pot as 'Season prize pot', 'A clean docket: No recorded pleas in this season yet' and 'Your standing 0 points', while topOf(0) still holds the wallets about to be paid. After the Cabal dies, currentSeason() returns (false, 0, 0), so the strip says 'Season 1', #/seasons shows season 1's leaderboard, 'PLEA bonus 10,000,000 PLEA' and bestOf(0), and Profile says 'Current season 1' (details.tsx:264, :322), even when about seven seasons ran. Before seeding, seasonBounds is all zero, so pages-court.tsx:875 sets closeAt = 0 + 3600 and the panel reads 'Close season 1 · Available from 1970-01-01 01:00 UTC, after 1h 0m grace.'
- **Should:** Seasons.closeSeason pays (seasonFees[nextToClose] + rollover) × shareBps(rank) / 10,000 to topOf(nextToClose) (Seasons.sol:320-345). pot() is documented as "all prize assets, including later seasons' fees" and is not what a close pays (Seasons.sol:167-172). currentSeason is (false, 0, 0) whenever the Cabal is dead (Seasons.sol:160-166); the last season is ((diedAt − 1) − startedAt) / SEASON, as Seasons.checkpoint numbers it (Seasons.sol:183). seasons.html reference band 'After the Cabal dies': h1 'Season 2' with pill 'Ended with the Cabal', lead 'Season 2 ended at 16:59 UTC, when the Cabal died. No season 3 follows: the leaderboard as it stands is the last one.', and 'Close season 2' with 'Anyone can close it from 17:59 UTC (1-hour grace).' _shell.html: live strip 'Season 2 · 9d 4h left · pot 184.20 IMD + 10,000,000 PLEA', dead strip 'Season 2 ended with the Cabal · close it from 17:59 UTC'.
- **Fix:** add one helper in chain.ts (for example seasonState(s, now)) and use it on the strip, Home, #/seasons, Profile and the share cards:
  - Read in the snapshot: CabalGate.startedAt, diedAt, cabalAlive; Seasons.currentSeason, nextToClose, rollover, closed(nextToClose), seasonBounds(k), seasonFees(k) and topOf(k) for k = nextToClose and k = the displayed season.
  - displayed = currentSeason.season while the Cabal lives; when dead, last = ((diedAt − 1) − startedAt) / SEASON; when startedAt is 0 there is no season.
  - awaiting = nextToClose when seasonBounds(nextToClose) has exists && ended and closed(nextToClose) is false; closeFrom = end + CLOSE_GRACE.
  - potOf(k) = seasonFees(k) + (k == nextToClose ? rollover : 0). Use potOf for 'Season prize pot', the strip's 'pot', the Home stat and every 'Prize now' (potOf(k) × shareBps(i) / 10,000, rounded down). While an older season awaits its close, the running season's pot is seasonFees(current) alone, with the note 'plus what season N rolls over at its close'.
  - #/seasons while alive with awaiting < displayed: above the running season, a section with h2 'Season N ended', pill 'Awaiting close', its own leaderboard from topOf(awaiting) with its own Prize now and PLEA bonus (bonus only if awaiting < BONUS_SEASONS), the connected wallet's standing from bestOf(awaiting, wallet) and its Record my points (a late record still counts until the close), and 'Close season N' with 'Anyone can close it from <closeFrom> UTC (1-hour grace).' The running season below starts with the band's 'No points yet' empty state until its first record. When several seasons wait (possible after the death), show the oldest one with the line 'Seasons N to M wait to be closed, oldest first.'
  - Dead: #/seasons uses the band's dead layout for `last`; the strip prints the _shell.html dead text; Profile's season is `last`.
  - No season yet (startedAt == 0): no Close button and no date; keep the code's own 'No season has begun.' and the existing 'The first season begins when trading opens.'
  - Write the grace as '1-hour grace', never '1h 0m grace'.

### S2 (P1) Seasons page: build it from seasons.html (three panels, a full Your standing, the seat multiplier, Record my points for your own pleas) [FB-05, FB-V2]
- **Now:** #/seasons at every width (pages-court.tsx:889-1100) has h1 'Seasons', a stats--4 row (Season, pot, PLEA bonus, Season length), a Your standing panel with only 'N points' and 'Best three: a · b · c', plus developer copy ('Points are calculated with Seasons.pointsFor and holdsSeat…'), generic 'Closing the season' and 'Bonus and leftovers' panels, and no seat-multiplier panel, pot breakdown, rank, prize or share. The 'Points waiting to record' panel (:957) lists every wallet's unrecorded approvals (the filter at :878-881 has no seller check) under 'Record my points': connected as p4, it listed p1's, p2's and p3's pleas.
- **Should:** brief PAGES 'Seasons (the leaderboard with the seat multiplier)' and MUST HAVE (pointsFor/holdsSeat ×1.2 rounded down, shareBps, the 10,000,000 PLEA bonus in the first six seasons, points held until the objection window ends, then Record my points). pages/seasons.html: h1 'Season 2' with a timer pill 'ends in 9d 4h'; three panels Ends / Season prize pot / PLEA bonus; a Your standing card with Rank, Points and Prize now, the held-points notice and Record my points for the wallet's own plea; the panel 'The seat multiplier' with id="seat"; reference band states 'no recorded plea', 'Not connected', 'Record my points: after 08:19 UTC, busy, recorded', 'No more seasons'.
- **Fix:**
  - Title: h1 'Season N' plus pill role="timer" 'ends in <countdown>' (aria-label in words, e.g. 'Season 2 ends in 4 hours 12 minutes'). Lead: '<Seasons.SEASON in words, e.g. 5 hours>. Your best three approved pleas count, and the top <TOP> with at least <MIN_POINTS> points share the season prize pot and the PLEA bonus.'
  - Three panels, grid spans as in the mockup. Ends: the end as date and time, then Left, Started, Length, 'Grace after the end' (CLOSE_GRACE in words: '1 hour'), 'Anyone can close it' ('from HH:MM UTC'). Season prize pot: potOf(season) (S1) with rows 'Trade fees (0.25% of every trade)', 'Site auto-sell sales (N × 0.35; letters pay none)', 'Overruled stakes (N × 0.35)', 'Rolled over from season N−1' (only when this season is nextToClose and rollover > 0) and Total. Take the auto-sell sales as Σ Letterbox Delivered.fee and the stakes as Σ Tribunal StakeSettled.amount with `to` = Seasons, each counted in the season of the Seasons PrizeFunded log in the same transaction; trade fees = seasonFees(season) minus those two. PLEA bonus: BONUS_PER_SEASON with rows Season 'N of BONUS_SEASONS', Paid to 'top 25, 60+ points', 'Shares, as for the IMD' shareBps(0)/100 to shareBps(24)/100 ('4.50% to 3.50%'), 'Unpaid shares' 'burned at the close', From 'the 6% season bonus'. From season 7 on, show '0 PLEA' and 'The PLEA bonus ran in seasons 1 to 6.'
  - Your standing (card): Rank = index in topOf(season) + 1, or 'none yet'; Points = Σ bestOf; Prize now = potOf × shareBps(rank − 1) / 10,000 with the note '+ <bonus × shareBps / 10,000> PLEA', only at ≥ MIN_POINTS and when not excluded. Then the costs 'Best three' as 'a + b + c = N', for a seat holder 'Judges' scores, before × 1.2' (match each bestOf value to the wallet's Recorded log in that season with that pointsOf and print its `score`), and 'Share at rank R'.
  - Record my points, inside Your standing, for the connected wallet's own approved, unrecorded pleas (p.seller == address) of any season not yet closed. While Tribunal.standing says held: notice--info 'Plea #N's +P points are held until HH:MM UTC.' (verdictAt + OBJECTION_WINDOW, or a pending objection's filedAt + Tribunal.PENDING_EXPIRY if later), with the sentence on what recording makes (new best three, rank, prize at today's pot), the countdown 'Objections close in mm:ss' and a disabled 'Record my points' whose reason is 'Record your +P points after HH:MM UTC, when objections on plea #N close. Nothing records them by itself: anyone can press Record my points.' Once free, enable it. Delete the 'Points waiting to record' panel: other wallets' pleas are not listed. Their points still count because Close season passes plea ids to `Seasons.closeSeason`, which records each one it can (Seasons._tryRecord): keep that argument, but pass only the closing season's approved, unrecorded plea ids (from the Verdict logs) instead of every PleaSubmitted id, to keep the gas down.
  - States from the band: not connected, the notice 'Connect in the top bar to see your rank.' with 'The leaderboard, the season prize pot and past seasons read without a wallet.'; no recorded plea, 'Rank none yet', 'Points 0' with the note '60 to share the season prize pot', the mockup sentence and 'Write a plea' (only while the Cabal lives).
  - The seat multiplier panel, beside Your standing (split--stretch), with id="seat" (Profile links here): the mockup copy, the three examples computed as floor(score × SEAT_MULTIPLIER_BPS / 10,000) (36 → 43, 45 → 54, and 36 without a seat → 36), the seat NFT from Seasons.seat() with a Copy button (label 'Seat NFT'), and notice--ok 'Seat held: every recorded plea earns × 1.2.' when holdsSeat(connected).
  - Replace 'Bonus and leftovers' with the band's 'No more seasons' panel and 'Send leftovers to the buy wall' (Seasons.flushToWall), shown only when Seasons.finished() is true. Remove the developer copy.

### S3 (P2) Leaderboard: no column heads, no 60-point line, no seat brackets, no 'If the season ended now' [FB-22]
- **Now:** #/seasons leaderboard (pages-court.tsx:1001-1063) renders rows only. From 768 px the kit hides each row's .lb__label, so the columns have no visible headings at 768 and 1280. There is no .lb__bar, no seat brackets and no foot note; the prize cell appends '(4.5%)'; there is no 'If the season ended now' panel.
- **Should:** seasons.html: panel--flush with panel__head 'Season 2 leaderboard' and meta 'Season prize pot 184.20 IMD + 10,000,000 PLEA · top 25 with 60+ points'; `<li class="lb__head" aria-hidden="true">` Rank / Player / Best three / Points / Prize now; `<li class="lb__bar">60-point line · below it no prize: the IMD share rolls over to season 3 and the PLEA bonus share is burned</li>`; rows under it are lb__row--out with 'no prize (58 of 60)'; seat holders' judges' scores `<span class="seatx nowrap">(38·37·36 × 1.2)</span>`; panel__foot 'Equal points: the wallet whose newest counted plea is older ranks higher. Seat holders' judges' scores are in brackets (each × 1.2, rounded down).'; then 'If the season ended now' beside 'Closing the season'.
- **Fix:** port that markup exactly. Prize cell '<x> imdTEST + <y> PLEA' (nowrap pairs), without the percentage; the YOU badge on the connected wallet's row; an address without a name in span.mono; the lb__bar after the last row with ≥ MIN_POINTS (drop its PLEA clause when the season pays no bonus). 'If the season ended now' (panel--sunken): 'Paid to N wallets' Σ shares % · Σ prizes; 'Rolls over to season N+1' (100% − Σ shares) · potOf − Σ prizes; 'PLEA bonus paid'; 'PLEA bonus burned' (BONUS_PER_SEASON − paid); the rounding note from the mockup. 'Closing the season' with the mockup copy and its states (not yet: disabled with 'Anyone can close it from … (1-hour grace).'; ready; busy). Loading: the band's skeleton under the real head with 'Reading the leaderboard from Seasons…'; read error: error-box 'Can't read the leaderboard' with Try again.

### S4 (P2) Past seasons shows only pot and paid [CT-16]
- **Now:** #/seasons Past seasons (pages-court.tsx:1103-1125) prints 'Season 1 · Season prize pot · Paid · View closing transaction' and nothing else, at every width. After a close where the chain paid p3, p1 and p4 imdTEST plus 450,000 / 446,000 / 442,000 PLEA, burned 8,662,000 PLEA and rolled 1.3397 over, none of that was shown.
- **Should:** seasons.html Past seasons: an article per season with h3 'Season 1' and pill 'Closed'; meta '<start> to <end> UTC. Closed <time> UTC by 0x3b7e…91d0.'; 'Season prize pot and bonus' costs (Season prize pot, Paid to N wallets, Rolled over to season 2, PLEA bonus paid, PLEA bonus burned) with the rounding note; 'Top three, and you' (rank · name, points, imdTEST + PLEA).
- **Fix:** build each closed season from its logs: SeasonClosedOut(season, pot, paid); PrizePaid and BonusPaid (season, wallet, rank, amount); BonusBurned(season, amount); dates from seasonBounds(season); the close time from the block of the SeasonClosedOut log and the closer from that transaction's `from` (short, mono), with the time linked to sepolia.etherscan.io. Rolled over = pot − paid; points from topOf(season)[rank − 1].points (kept after the close); names from Letterbox.nameOf; add the connected wallet's own row when it is not in the top three. Newest season first.

### S5 (P2) At 320 px the bonus stat breaks inside the number ('10,000,00' / '0 PLEA') [CK-10]
- **Now:** #/seasons at 320 px, light and dark: the PLEA bonus value (a 109 px box) wraps mid-digit, because web/src/site.css:78-80 sets `.stat__value { overflow-wrap: anywhere; }` over components.css:445 (`overflow-wrap: normal`). The same rule wraps Home's "0.00 imdTEST" pot onto two lines.
- **Should:** brief DESIGN SYSTEM: use components.css as it is; PAGE-KIT: PLEA as whole numbers with separators.
- **Fix:** delete the site.css:78-80 rule for every page (an address that must wrap uses .addr__text, which already breaks). Keep each number and its unit in one span.nowrap, and check #/seasons, #/ and #/profile at 320, 360, 768 and 1280.

### S6 (P2) Wall filters: wrong matching, no counts, no Appeals or Sort, wrong count line, load-more and empty states [CK-09, CT-04, FB-13]
- **Now:** #/wall (pages-court.tsx:39-201), every width: seven chips All, Approved, Denied, Pending, Sold, No verdict, Lapsed with no counts (they wrap to two rows at 360), matched literally against pleaState (:57). So 'Approved' shows only status-2 pleas inside their window (sold #1/#6/#8 and lapsed approvals are missing), 'Denied' misses UPHELD appeals, and no chip ever shows OVERTURNED or UPHELD. 'More filters' is an underlined summary.link-btn (:112) that opens three 28 px checkboxes (By letter, Objected, Mine); no Appeals, no Sort. The count line reads 'N pleas loaded' (:145). 'Load older pleas' is left-aligned; with zero pleas the page still says 'The whole record, from the first plea.' (:191) and offers 'Write a plea' before trading opens; with only 'Objected' on and no match it says 'No pleas yet' (the empty test reads only the verdict chip, :178-182).
- **Should:** wall.html: lead 'Every plea and its verdict, newest first; times are when each plea was sent. Open a card for its facts and the judges' note.'; chips in role="group" aria-label="Show pleas by verdict": 'All 215', 'Approved 140', 'Denied 55', 'Pending 1', 'No verdict 19' (span.chip__count; the counts add up, so Approved covers sold, lapsed and overturned approvals and Denied covers upheld); details.wall-tools__more with summary.chip 'More filters' and the caret-down icon, opening 'Show only' chips (Sold, Appeals, By letter, Objected) and 'Sort' chips (Newest, Highest score); band 'More filters · 1 on' and 'Showing pleas sent by letter, newest first'; count line 'Showing #215 to #204: 12 of 215, newest first · 71.8% of judged pleas approved'; centred .wall-more 'Load older pleas' + 'Next: #203 to #192'; busy 'Reading #203 to #192…' + 'The 12 cards above stay put.'; end 'That is every plea, back to #1.' / 'Yours would be #216.' / 'Write a plea'; empty filter 'No objections yet' / 'Every approval so far went unchallenged. Suspicious.' + 'Show all pleas'.
- **Fix:** port wall-tools from wall.html.
  - Verdict families by CabalGate status: Approved = 2, 4, 5 (APPROVED, OVERTURNED, SOLD, LAPSED); Denied = 3 (DENIED, UPHELD); Pending = 1 before submittedAt + PENDING_EXPIRY; No verdict = 6, or 1 past PENDING_EXPIRY.
  - Counts from the full log history, not the loaded pages: total = CabalGate.nextId − 1; approved / denied = Verdict logs with approved true / false; pending = submitted with no Verdict, PleaFailed or PleaExpired and still inside PENDING_EXPIRY; no verdict = the rest. Hide the counts while s.historyError is set. 'judged pleas approved' = approved / (approved + denied), one decimal.
  - Show only: Sold = status 4, Appeals = isAppeal, By letter = flags & 1, Objected = has objections. Sort: Newest (id descending) or Highest score (score descending, unjudged last). The summary reads 'More filters · N on' when N > 0. Drop the Sold and Lapsed top-level chips, the checkboxes and 'Mine'; keep the ?wallet= filter that Profile links to and name it in the count line ('Showing pleas by <name or 0x…>, newest first').
  - Count line (aria-live="polite") in the mockup's form, naming the active filters. Centred .wall-more with 'Next: #X to #Y', the busy text, and the end block with 'Yours would be #<nextId>.' ('Write a plea' only when seeded and alive).
  - Empty: with zero pleas, only the Wall's empty state (no end line, no 'Write a plea' before seeding). With filters and no loaded match, decide on all active filters: if the family count is above zero, keep loading older pages until a match or #1; otherwise a per-filter empty state with 'Show all pleas' that resets every filter (Objected: the mockup's copy; Denied: components.html 'No denied pleas yet' / 'The Cabal is in a good mood. It will not last.').

### S7 (P2) Plea cards (Wall, Home, Profile): per-state foot facts, badges, mono addresses, card names [FB-12, FA-19, FB-V1]
- **Now:** PleaCard (components.tsx:656-725), used on #/wall, #/ 'Latest verdicts', #/profile and #/objections: the foot shows the amount, a points text ('+N points once recorded' is a new wording) and 'Sold for' (status 4 only); no need, expiry, sell-by, appeal-until, 'appealed in', 'no cooldown' or 'not sold in 7 min'. The seller (:702) is plain .strong even for an address; badges carry no icons; a letter plea (flags = BY_LETTER | AUTO_SELL = 3, Letterbox.sol:206, 214) shows both 'BY LETTER' and 'AUTO-SELL' (:705-709). The id line is 'Plea #N · sent 04:12 ago' (:663). The OVERRULED objection line lacks 'counts N points', and the card link's accessible name is all of its text.
- **Should:** wall.html card feet: pending '960,000 PLEA · need 36 · expires 08:17 UTC'; approved '+43 points held · sell by 08:06 UTC'; denied 'no points · appeal until 11:53 UTC' or 'appealed in #207'; no verdict 'no points · no cooldown'; lapsed '+35 points · not sold in 7 min'; sold or overturned '+37 points held' or '+39 points' and 'sold for 25.98 IMD'; sustained 'no points'. Addresses `span.mono.strong`; badges: 'SEAT ×1.2' (no icon on cards), 'BY LETTER' with the envelope-simple icon, 'AUTO-SELL' only for a site auto-sell plea (#204), 'APPEAL OF #205', 'YOU'. Id line `<span class="sr-only">Plea </span>#215 · 2 min ago`; the link has aria-labelledby (id, stamp) and aria-describedby (age, text, nums, who). Objection lines in components.html's one form: 'Objection #9' + 'pending', 'Sustained' + '#8: 29 vs need 33', 'Overruled' + '#7: 33 vs need 33 · counts 39 points'.
- **Fix:** port the foot per state as above, with times from verdictAt + EXECUTE_WINDOW (sell by), submittedAt + PENDING_EXPIRY (expires), verdictAt + COOLDOWN (appeal until; only when not an appeal, not appealed and the Cabal lives) and the appeal's id from the PleaSubmitted log whose originalId is this plea. Points: '+N points held' while Tribunal.standing is held, '+N points' otherwise, 'no points' when sustained or excluded. Sold amount: the same single 'sold for' figure as the plea status page (C16's writer amount). Seller: name in .strong, address in .mono.strong. Badges: AUTO-SELL only when (flags & 2) && !(flags & 1); envelope-simple icon on BY LETTER. Add the OVERRULED points ('counts N points', from pointsOf or pointsFor with the new score) and take every objection line, VOID included, from C8's `objectionLine()`. Card times come from X10: `ago()` for the id line and `clock()` for the deadlines (X10). The link gets aria-labelledby (id and stamp) and aria-describedby (age, text, objections, foot, who), so its name is not all of the card's text.

### S8 (P2) Display name says 'This is your current name' when the wallet has no name [CT-09, FB-16, TR-14, TT-18]
- **Now:** #/profile with a wallet whose nameOf is "" (p3, p4, p6, wallet A), 360/1280, light and dark: components.tsx:222 sets `current = kind === "name" && value === currentName`, true for "" === "", so the empty box shows a green check 'This is your current name', the disabled 'Save name' repeats it as its reason (pages-info.tsx:926-932) and the sr-only status says it a third time. 'Clear name' (:933-942) is a link-btn that looks enabled although disabled.
- **Should:** brief MUST HAVE 'Profile: … "This is your current name" for the wallet's own name'. profile.html Display name card: a preview line 'Shown on the Wall and the leaderboard instead of 0x7a3f…c21e:' with the wall-card__who preview; the field with field__aside '3–20 of a–z, 0–9, _' and hint 'Names are unique. Reserved: cabal, admin, imd, plea and owner.'; a btn-row with 'Save name' (btn--primary, aria-describedby the checks) and 'Clear name' (link-btn); the line 'Or send the letter NAME <name> to the Letterbox from Etherscan; NAME alone clears it. How letters work'. Band: a taken name shows the check row 'kafka_cat is taken. Try another name.', is-invalid, and Save stays disabled.
- **Fix:** `current = kind === "name" && !!currentName && value === currentName`; print 'This is your current name.' once, in the checks list only (Save points at it with aria-describedby instead of repeating it). For a wallet with no name and an empty box, show one idle row 'Type a name: 3–20 of a–z, 0–9, _.', keep Save disabled and hide 'Clear name'. For a named wallet, 'Clear name' empties the box and the row reads 'An empty name clears your display name.' with Save enabled (Letterbox.setName("") deletes it). Port the card layout above, with the taken-name row tied to the input by aria-describedby.

### S9 (P2) Another wallet's profile is written as the viewer's own [CK-16, CT-25]
- **Now:** #/profile/0x4b91…6821 with no wallet, or viewed by a different wallet, at every width: the lead 'Your wallet as PLEA sees it: holdings, your buy record, name, pleas and seasons.' (pages-info.tsx:809), 'Your buy record' (:852), 'Check your next plea', 'Your next plea, at 20%' (details.tsx:295), a 'Plead to sell' button, 'Your seasons' (details.tsx:316), then 'Their pleas' (:947). There is no Read only pill and no notice.
- **Should:** profile.html reference band 'Someone else's profile (kafka_cat), seen by mira_eth: read only, no name box, their pleas': title with the SEAT badge (armchair icon) and pill 'Read only'; the address with Copy ('Copy kafka_cat's address'); four stats (PLEA, 'Season 2' rank with points and best three, 'Season 1' rank with points and the prize paid, 'Next plea'); their latest plea card; notice 'You are viewing kafka_cat's profile.' / 'Balances, pleas and seasons are public and read from the chain. Only kafka_cat can change this name, so there is no name box. Back to your profile'.
- **Fix:** when `mine` is false, render that band layout instead of the owner layout: no name box, no next-plea meter, no 'Plead to sell', third-person copy everywhere, the stats from S10's season data, and the notice (its 'Back to your profile' link only when a wallet is connected).

### S10 (P2) Profile layout and states differ from profile.html [FB-14, FB-15]
- **Now:** #/profile (pages-info.tsx:759-970, details.tsx:255-378), 360-1280: the title has no SEAT badge; the stats have no notes, and 'PoolManager claims' (:836) duplicates the buy record's 'ERC-6909 claims'; no open-plea notice; no profit-or-loss line and no facts grid, only a meter; 'Your next plea', 'Your seasons' (a costs list of 'Current season', best three and points, with no rank or prize) and 'IMD seat' are full-width stacked sections. Without a wallet the page is one empty state, 'Your case file awaits' (:964), with no way to look up an address; info.error is never rendered, so a failed read leaves '— PLEA' forever and no loading state shows.
- **Should:** profile.html: h1 name + SEAT badge; address with Copy; lead 'Your wallet as PLEA sees it: what you hold, the buy record your next plea is scored on, your name, your pleas and your seasons.'; stats with notes: PLEA ('A plea: 62,000 to 2,500,000'), IMD ('For buys and the 0.50 IMD oracle fee'), Cashback earned ('As staked IMD on imdacc.fun'), Next plea ('after #214' / time); the notice 'Plea #214 is open: sell by 08:06 UTC.' with the urgent countdown and 'Open plea #214 to sell'; a split: 'Your buy record' (Cost basis, Held buy-weighted, 'Now, at 14.16 IMD per 1M: −18.0%', then h3 'Your next plea, at 20%' with the facts grid, the meter and the sentence) beside the Display name card (S8); 'Your pleas' (the latest two, 'Season 2 also counts #188 and #171.', 'All pleas on the Wall'); a split: 'Your seasons' table (caption; Season / Points / Rank / Prize; cell notes 'closed, paid', '9d 4h left', 'so far'; the foot note) beside 'IMD seat' with 'How the seat multiplier works'. Band: 'Not connected' (notice plus an 'Any address' field and 'Show profile'), 'Loading', 'Read error' ('Can't read this profile' + Try again), 'No pleas yet', and the next-plea notices after a sale or a lapse.
- **Fix:** rebuild #/profile from profile.html:
  - Stats: PLEA with 'A plea: <1% of balance> to <min(50%, MAX_SELL)>'; imdTEST with 'For buys and the 0.50 imdTEST oracle fee'; Cashback earned; Next plea from the same cooldown rule as Plead (C1's state). Show the ERC-6909 imdTEST claims once, as a row of the buy record (brief MUST HAVE), and drop the 'PoolManager claims' stat.
  - Open-plea notice with the urgent countdown, for the wallet's own approved plea inside EXECUTE_WINDOW.
  - Buy record: P/L = (heldPlea × PleaHook.latestPrice − spent) / spent, labelled 'Now, at <latestPrice per 1M>', so it matches the fact score (the Buy page's panel, T8, uses the spot price, as its Price row does). Next plea at 20% (min(20% of balance, MAX_SELL)): the four-fact grid from the same helper as Plead (C10), the meter, and the sentence with the amount and need. With 0 PLEA show X3's one line instead of the meter, and no 'Plead to sell'; when need > 45, the components.html CannotPass notice (the Meter's clamp is X3).
  - Your pleas: the latest two from the wallet's PleaSubmitted logs (not only the 24 loaded pleas), the 'also counts' line from bestOf's pleas, and 'All pleas on the Wall' linking to #/wall?wallet=<address>.
  - Your seasons table: one row per season with points or a prize. Points = Σ bestOf(k, wallet); Rank from topOf(k); Prize = PrizePaid + BonusPaid for closed seasons, or potOf(k) × share for open ones (S1). Foot as in the mockup.
  - IMD seat panel with Seasons.seat() and Copy, linking to #/seasons with the seat panel scrolled into view (id="seat").
  - States: not connected → the band's notice plus 'Any address' (input--addr, the S12 invalid treatment) and 'Show profile', which routes to #/profile/<address>; loading → loading-label 'Reading <name>'s balances, pleas and seasons from the chain…' plus skeleton; read error → error-box 'Can't read this profile' with Try again (render info.error).

### S11 (P2) Claim: list numbers, delegated vaults and claim states differ from claim.html [FB-17]
- **Now:** #/claim (pages-info.tsx:485-757): h1 'Claim PLEA' with a lead that has no numbers (:545). About the list shows Root, 'Claims on loaded list' and 'Token supply 1,000,000,000 PLEA' (:742), not the distributor's 120,000,000. Delegated vaults is a plain panel with the plain texts 'Reading delegated vaults…' and 'No delegations found.' (:722) and an extra 'Check claim for this vault' button (:715). 'Already claimed' has no date or receipt; the delegate.xyz and distributor addresses print lower-case.
- **Should:** claim.html: h1 'Claim your PLEA'; lead '12% of PLEA (120,000,000) went to a claim list: the IMD swarm's 10% and a 2% airdrop. Anyone can send a claim for any address, and the PLEA always goes to the address on the list.' (README: 12% Merkle distributor, the swarm's 10% and a 2% airdrop; PLEA.init mints TOTAL_SUPPLY × 12 / 100 to it). About the list (panel--flush, head meta 'Final'): the root-set date sentence; Claims on the list, Claimed so far, Still open, IMD swarm (10%) 100,000,000 PLEA, Airdrop (2%) 20,000,000 PLEA, In all (12%) 120,000,000 PLEA; 'The receipt'; 'Pleading with claimed PLEA'; the PleaDistributor address. Delegated vaults (panel--flush, meta 'delegate.xyz'): Vault / Claimable, 'Claim 212,500 PLEA to the vault' + btn__sub 'gas only', the note, the registry with Copy. Band: Checking, Already claimed (date + 'View the receipt'), Not on the list, Claiming, Claimed toasts, vault loading, vault already claimed, 'No delegated vaults' with 'Open delegate.xyz'.
- **Fix:** port claim.html. Numbers: list size = entries in claims.json; claimed = count of PleaDistributor Claimed logs; still open = the difference; the three amounts from PLEA.TOTAL_SUPPLY × 10/100, × 2/100 and × 12/100; the root date from the RootSet log's block (head meta 'Not set' while the root is zero; keep the brief's zero-root empty state). 'Pleading with claimed PLEA' with CabalGate.startedAt as the date. Claimable: notice--ok '<amount> PLEA claimable (claim #<index>)', 'Claim <amount> PLEA' (btn--primary btn--block) + btn__sub 'gas only', and the mockup note with the destination address. Already claimed: the Claimed log for that index gives the date and the receipt link. Not on the list: the band's notice. Each vault from getIncomingDelegations(connected): Vault / Claimable from the list and isClaimed, then 'Claim N PLEA to the vault' or the band's 'Already claimed for the vault…' or 'not on the list'; drop 'Check claim for this vault'. Use the band's loading, empty and error components (error-box 'Can't check the list' + Try again). Print every address checksummed (viem getAddress).

### S12 (P2) Claim: the 'not an address' error is not tied to the field [FB-18]
- **Now:** #/claim once the root is set (pages-info.tsx:566-595): aria-describedby points only at 'claim-hint' (:576); the error is a separate `<p class="bad-text">` with no id (:592); aria-invalid sits on the inner input and the .input wrapper never gets is-invalid, so the red bar never shows (components.css:212).
- **Should:** PAGE-KIT Accessibility (hints and errors tied with aria-describedby, invalid fields get aria-invalid); claim.html band 'Not an address': `.input.input--addr.is-invalid`, input aria-invalid="true" aria-describedby="bad-addr-msg", and `p.field__hint.bad-text#bad-addr-msg` 'That is not an address. Paste one that starts with 0x and has 40 more characters, 0–9 and a–f in either case.'
- **Fix:** give the error an id, list it in aria-describedby (it replaces the hint while it shows), add is-invalid to the wrapper and use that sentence. Use the same treatment on Profile's 'Any address' field (S10).

### S13 (P2) Share card and X post do not follow share-cards.html [CT-15, FB-07]
- **Now:** #/share/<id> for every state, and the downloaded PNG (share.tsx:6-160): the top reads '#214' (:58-59) with no BY LETTER or APPEAL OF badges and a plain seller address; every plea card uses share-card--wide-stamp (:47); the foot is always '<amount> PLEA asks to sell / sold' plus '<points> points held' with no '+' (:96-130), so score, need, rank, appeal deadline, the sold-for amount and the split counts are missing; the URL slot reads 'Sepolia · test tokens / The Cabal decides.' (:131-136), so the image carries no link. The default card has no stamps, 'Sepolia · run 9' as its id and 'Make your case.' in the number style. The post text (:156-157) is 'PLEA #N: “<whole text>” Make your case. The Cabal decides.': no state, no score, the full 280-byte text (it can pass X's 280 characters once the link is added), never 'my plea' or 'by <seller>'.
- **Should:** brief MUST HAVE 'Share card: a 1200 x 675 PNG per plea, in every state, drawn in the browser from the share-card component'. share-cards.html per state: top = logo, seller (mono for an address) with SEAT, BY LETTER (envelope icon) and APPEAL OF #N badges, and 'Plea #214'; foot nums per state (approved: score, need, '+43 points held', '#4 season 2'; denied: score, need, 'Open · appeal until 11:53 UTC' or '#207 · appeal, overturned'; pending: need, PLEA, '20% of the bag'; no verdict: '14 of 29 judges agreed', '17 needed', 'No cooldown'; sold, overturned and objection states: score, need, the imdTEST it sold for, points; lapsed: score, need, '+35 points', season rank; upheld: score, need, the first plea's score, 'Final · no further appeal'; sustained: 'No points'; overruled: '+39 points, 33 × 1.2'); share-card__url = the plea's link; wide stamp only on NO VERDICT and OVERTURNED; the default card: top 'The Cabal is in session.', title 'Buying is open. Selling needs a plea.', Approved + Denied stamps, '30 judges · 0–45 score · 7 min to sell', the site URL. The notice 'One post shape for every state': state in capitals with the score against the need, then the plea's first two sentences in quotes (only the first when two would pass X's 280 characters), then 'Plead your case:' and the link; 'my plea' only for the seller's own post, otherwise 'plea #213 by kafka_cat'; after the death the last part reads 'The Cabal is dead; PLEA trades freely:'.
- **Fix:** port each state's card markup from share-cards.html into ShareCard. Card URL = location.host + location.pathname + '#/p/<id>' without the scheme (plea-test-run-9.sites.imd.fun/#/p/214; the host already says test run). Pending share = amount / CabalGate.pleaBalance(id); season rank from topOf(season of verdictAt); judges agreed and answered from the PleaFailed log, needed = QUORUM; default-card facts from PANEL_SIZE, MAX_PLEA_SCORE and EXECUTE_WINDOW. Build the post from the sentences in share-cards.html for each state (APPROVED, DENIED with the appeal deadline, PENDING 'The Cabal is judging…', NO VERDICT, SOLD, LAPSED, OVERTURNED, UPHELD, OBJECTION, SUSTAINED, OVERRULED); 'my plea' when the connected wallet is the seller; quote two sentences, or one when the whole post (with X counting the link as 23 characters) would pass 280. The intent stays twitter.com/intent/tweet with text and url = the #/p/<id> link. Give the visible card the share-frame role="img" with the mockup's aria-label (state, score, points and link in words). Post panel: label 'Post text (Share on X fills it in)', the text in .chain-text, and 'Attach the image: the link alone shows the default card.'

### S14 (P3) The claims.json loader is fragile [TT-16]
- **Now:** chain.ts:356-375 normalizeClaims keeps an entry when String(amount) matches /^\d+$/ and an index exists. A JSON-number amount converts without an error but has already lost precision; an index like '117a' passes and BigInt throws on click; a list in the hex shape ({claims:{addr:{index, amount:'0x…', proof}}}) is dropped entirely, so every address reads 'Not on the list'. Not exploitable: the proof is checked on chain and claim pays the listed account.
- **Should:** FRONTEND.md:50 documents decimal-string index and amount, an account (or address) and a bytes32 proof array; PleaDistributor leaf = keccak256(abi.encodePacked(index, account, amount)).
- **Fix:** accept only string amounts and indexes, parsed with BigInt inside try (decimal, and 0x hex as a bonus), and reject JS numbers; require index ≥ 0 and amount > 0. Before showing an amount, verify the proof locally against merkleRoot (viem keccak256 + encodePacked, sorted-pair hashing as OpenZeppelin MerkleProof) and treat a failing entry as not on the list. If the file loads but yields no valid entry, show the band's error-box 'Can't check the list' instead of 'Not on the list'.

### S15 (P3) Share page buttons and copy errors [FB-23, FB-24]
- **Now:** #/share and #/share/<id>, 360 and 1280 (share.tsx:222-250): 'Download image' shows a blank icon slot (#i-download-simple is not in the sprite); 'Share on X' is a large btn--primary with share-network; at 360 the three buttons stack in rows of different widths. With clipboard permission denied, Copy prints the raw "Failed to execute 'write' on 'Clipboard': Write permission denied." as inline bad-text (:247). Downloads are named plea-<id>-<status>.png (:189) or plea-link-card.png.
- **Should:** share-cards.html: btn-row of btn--sm buttons with icons x-logo 'Share on X', arrow-down 'Download image', copy 'Copy image', each with an sr-only ' of plea #214'; band toasts 'Saved plea-214.png.' / '1200 × 675. Attach it to your post on X.', 'Image copied.' / 'Paste it into your post on X. The verdict is on your clipboard now.', and toast--bad 'This browser can't copy images.' / 'Use Download image, then attach the file to your post.'; while drawing, Download and Copy wait with 'Download and Copy wait until the image is drawn. Share on X works now.'
- **Fix:** use those icons and btn--sm (no primary), wrapping as a btn-row; map every copy failure (no ClipboardItem, permission denied, write error) to the toast--bad text above and never print the browser's message; name files plea-<id>.png (the default card plea.png) and use the band's download and copy toasts.

## X. Shell and cross-cutting

Scope: Home (#/, #/how, #/contracts), the header, menu, wallet button, status strip, death banner and footer. Also the site-wide parts: toasts and per-button states; duration, number and rounding formats; loading, empty, error and not-found states; RPC fallback, polling and caching; telemetry and security; accessibility. Section T owns Buy, seeding (T2) and Home's "Fees and supply" (T10). Where an item here touches a T, C or S item, it names it. imdTEST replaces the mockups' IMD in every string.

### X1 (P1) A hung or rate-limited RPC stalls every page for minutes, and the third RPC cannot serve the site [CK-02, CK-03, CK-04]
- **Now:** web/src/config.ts:75-81 builds `fallback([http(url, { timeout: 12000, retryCount: 1, batch: { wait: 20 } })…], { rank: false, retryCount: 1 })` over publicnode, ethpandaops and sentio, the RPCs listed in imd-deployment.json. The failures below hit every route at any width:
  - **publicnode hangs:** each request waits 12 s, retries, then moves on, and the next request starts at publicnode again. The strip read "Reading the Cabal…" for about 413 s; a normal load takes 3 to 6 s.
  - **publicnode answers 429 or 503:** every poll still asks it twice before falling back, for as long as the page is open (2:1 traffic; ready at 13 to 15 s).
  - **sentio refuses batches:** it rejects JSON-RPC batches over 5 calls, and the site sends 10 to 68.
  - **sentio limits logs:** it allows eth_getLogs over at most 1,000 blocks, and the site asks for 10,000 (chain.ts:106).
  - **The range never shrinks:** the regex at chain.ts:95-98 reads only `shortMessage`, which viem sets to "HTTP request failed." So with publicnode and ethpandaops down, the site never loads.
- **Should:**
  - Brief: history "from public Sepolia RPCs, at most 10,000 blocks per request, with fallback".
  - components.html error state: "The site tries the next one by itself".
  - Each listed RPC must be able to serve every read.
- **Fix:**
  1. Replace the fallback with a small custom transport (viem `custom({ request })`). Under it, use one `http(url, { timeout: 6000, retryCount: 0, batch: { batchSize: 5, wait: 16 } })` per URL.
     - Try the URLs in list order, skipping any URL marked down.
     - A timeout, a network error or HTTP 429/5xx marks the URL down for 60 s, and the request moves to the next URL at once.
     - A request-level error goes straight back to the caller and marks nothing down. That means an execution revert, or a body naming a block-range limit.
     - Use the same transport for the wallet config (config.ts:113).
  2. In scanLogs, build the error text from `shortMessage`, `details`, `cause.details` and the HTTP body. Also match `limited to (\d+) blocks`. On a match, use that N as the chunk size for the rest of the session; otherwise halve, as now.
  3. Done when all three of these hold:
     - With publicnode routed to a request that never answers, #/ is ready in under 15 s.
     - With publicnode answering 429, it gets no requests in the next 60 s.
     - With publicnode and ethpandaops answering 503, #/ and #/wall load from sentio alone.

### X2 (P1) An idle tab sends about 260 eth_calls a minute to one public RPC, and more as the court gets busy [CK-05]
- **Now:**
  - **Load:** context.tsx:85-98 runs a full `readSnapshot` (chain.ts:173-288) every 15 s on every route, with no Multicall3. Each run makes about 40 single eth_calls, plus 8 calls for each of the latest 24 pleas and up to 64 `Tribunal.objection` reads.
  - **Measured:** an idle #/ sent 32 POSTs carrying 260 calls a minute, all to publicnode, while nothing changed on chain. Every useRead also re-runs on each snapshot.
  - **Skipped refresh:** `refresh()` returns at once while a poll is in flight (:57). So the refresh after a receipt (:249) can be skipped, and the page shows the old state until the next poll.
- **Should:** Brief: reads come from public Sepolia RPCs, which rate-limit, and many visitors will have the site open during the live test.
- **Fix:**
  1. **Multicall3:** add `contracts: { multicall3: { address: "0xcA11bde05977b3631167028862bE2a173976CA11", blockCreated: 751532 } }` to defineChain (config.ts:67-74). Add `batch: { multicall: { wait: 16 } }` to createPublicClient (:82).
  2. **Poll on new blocks:** every 12 s while the tab is visible, read `eth_getBlockByNumber("latest")`. If the block is new, scan logs from the last block, as now. Re-read the snapshot only in three cases:
     - the scan returned logs for the site's contracts;
     - 60 s have passed since the last snapshot;
     - the wallet's own receipt just arrived.
     Time-driven states (PENDING to NO VERDICT, the sell window, countdowns) already follow `now`.
  3. **Back off:** after a failed poll, wait 15 s, then 30 s, then 60 s; reset on success.
  4. **Queue the refresh:** a `refresh()` called while a poll runs queues one more run instead of returning. The post-receipt refresh then always reads the new block.
  5. **Done when:** an idle #/ tab makes at most about 20 RPC requests a minute after the first load.

### X3 (P1) The need marker is drawn past the meter, so every profile page scrolls sideways [CK-01, FB-01, TT-11]
- **Now:**
  - **Profile:** Meter (web/src/components.tsx:727-763) writes the unclamped need into `--need` (:740), and the kit draws `.meter__need` at `var(--need) / 45 × 100%`. A wallet with fact 0, which is any wallet holding 0 PLEA, has need 71. On #/profile and #/profile/<address> (details.tsx:304-307) the marker then sits at 158% of the bar.
  - **Page width:** the document is 426 px wide at 320, 489 at 360, 1098 at 768 and 1872 at 1280. This holds in both themes, with or without a wallet, and the width toggles every 15 s with the refresh (X4).
  - **Label:** the bar's label reads "Score 0, need 71 of 45" (:752).
  - **Plead:** with Max at need 50 (pages-trade.tsx:656-664) the marker sits past the card's edge (the CannotPass copy is C9). The appeal meter (pages-court.tsx:250) has the same flaw.
- **Should:**
  - Brief QA: no horizontal scroll from 320 to 1280.
  - plead.html reference "CannotPass: Max pressed": no meter. The line reads "Need 46 = 71 − fact 25, above the 45 a plea can score."
  - profile.html's meter label: "No score yet. A 20% plea needs 33 of 45 from the judges."
- **Fix:**
  1. Meter clamps `--need` and `--score` to 0..`CabalGate.MAX_PLEA_SCORE`.
  2. When need > MAX_PLEA_SCORE, Meter draws no bar. It shows only the `.small` line "Need N = 71 − fact F, above the 45 a plea can score.", with PASS_MARK and MAX_PLEA_SCORE from chain.
  3. On Plead, C9's CannotPass state uses step 2's line in place of the meter, with its notice--bad and the largest size that passes.
  4. On Profile, a wallet holding 0 PLEA gets one line instead of the meter: "This wallet holds no PLEA, so it has nothing to plead." It gets no "Plead to sell" either.
  5. The bar's aria-label follows the mockups: "No score yet. A 20% plea needs 33 of 45 from the judges." on Profile, "No score yet. Your need is 33 of 45." on Plead. The judged forms ("Score 36 of 45, need 33: passes by 3") come with C6.
  6. Done when the page width equals the viewport on #/profile/0x4b91078b2374c956A65F7Af0999CaE0a935E6821 at 320, 360, 768 and 1280 px, in both themes.

### X4 (P2) Every 15 s refresh blanks what is on screen: sections flash "Reading…", meters vanish, the layout jumps [CK-V1]
- **Now:** useRead (context.tsx:150-181) calls `setData(undefined)` on every run (:161), and `s` is in its deps (:179). So each new snapshot clears the data for about 300 ms. On #/profile/<address> at 360, in both themes, the meter disappears and "Best three recorded pleas" and "Points" read "Reading…". The text shrinks from 1,233 to 1,027 characters, then comes back. The same hook feeds the Buy quote and allowance (pages-trade.tsx:130, 185), Plead's fact and need (:530) and #/p/<id> for older pleas (pages-court.tsx:339), so they blank too.
- **Should:** components.html: the skeleton is for the first read only. Brief MUST HAVE: "nothing else animates".
- **Fix:**
  - **Clear only on new deps:** useRead clears `data` only when the caller's `deps` change (compare a key built from them). When only `s` changes, keep the old data and swap it in when the new read resolves.
  - **Loading:** `loading` is true only while `data` is undefined.
  - **Errors:** a failed re-read keeps the old data and shows no error until two reads in a row fail.
  - With X2, `s` changes only when the chain did.

### X5 (P2) Home live numbers: 4 of 6 cells, "PLEA burned" counts only the hook's burns, the pot is the whole Seasons balance, generic notes [FA-15, TR-13, TT-12]
- **Now:** #/ at 360, 768 and 1280, light and dark. pages-info.tsx:94-133 puts four cells (Price, PLEA burned, Pleas, Season prize pot) in the 6-column `.stats` grid, leaving two cells empty at 1280 and at 768.
  - **Price · 1M PLEA:** no 24h trend, and the note says "Live pool price" even while the value reads "Not open".
  - **Missing cells:** there is no Market cap cell and no Cabal cell.
  - **PLEA burned:** this is `PleaHook.totalBurned` only (:110-113), with the note "Burn fees and inventory trims". Each season close burns the unpaid share of the 10,000,000 PLEA bonus (Seasons._payBonus), so after season 1's close on the fork the stat read 17,861 while 10,017,861 PLEA had been burned.
  - **Pleas:** no breakdown.
  - **Season prize pot:** this is `Seasons.pot()`, the whole Seasons balance, with no bonus and no season end (:120-123). "0.00 imdTEST" (and on the fork "6.33 imdTEST") wraps onto two lines (S5).
  - **Notes:** generic ("Since test run 9 launched", "Recorded points compete for the pot").
  - **Loading:** the cells read "Reading…" and "— PLEA".
- **Should:** index.html section 2, six cells (label, value, note):
  - "Price · 1M PLEA", "14.16 IMD", "24h +0.8%, counts as flat".
  - "Market cap", "13,790 IMD", "Supply 973,865,130 PLEA".
  - "PLEA burned", "26,134,870", "Of 1,000,000,000 at launch": launch supply minus supply now. PLEA.burn is public (PLEA.sol:119) and Seasons.flushToWall burns leftovers, so only the supply difference counts every burn.
  - "Pleas", "215", "140 approved, 55 denied, 19 no verdict, 1 pending".
  - "Season prize pot", "184.20 IMD", "+ 10,000,000 PLEA; season 2 ends in 9d 4h".
  - "Cabal", "● Alive", "Dies in 32h 59m without a verdict".
  - Band "Live strip loading": skeleton lines under the real labels, with "Reading the pool, the Cabal and the season from the chain…".
- **Fix:**
  - **Price:** `priceX96 × 10^24 / 2^96`. The note's percentage compares `latestPrice` with `price24hAgo`, using CabalGate's own rule (CabalGate.sol:296-299):
    - "counts as up" when latest > ago × 102 / 100;
    - "counts as flat" when latest × 100 ≥ ago × 98;
    - "counts as down" otherwise;
    - "no 24h price yet, counts as flat" when ago is 0.
    - Before the seed the value reads "Not open yet" and the note gives the opening time, PleaLaunch.START in X10's clock().
  - **Market cap:** `PLEA.totalSupply() × priceX96 / 2^96` in whole imdTEST, with the note "Supply N PLEA".
  - **PLEA burned:** `PLEA.TOTAL_SUPPLY − PLEA.totalSupply()`, the same as T10's "Burned so far", with the note "Of 1,000,000,000 at launch" (TOTAL_SUPPLY formatted). The Supply panel is T10's: it ports the mockup's "Burned so far" row, with no per-source rows.
  - **Pleas:** `nextId − 1`. Count the note from the logs, with the same families as the Wall's counts (S6):
    - approved and denied from Verdict's `approved`;
    - no verdict from PleaFailed and PleaExpired, plus any plea past PENDING_EXPIRY (as pleaState does);
    - pending is the rest.
  - **Season prize pot:** S1's `potOf(current season)`, never `Seasons.pot()`. The note adds "+ 10,000,000 PLEA" (BONUS_PER_SEASON) while the season index < `BONUS_SEASONS`, then "season N ends in {countdown}". While an older season waits for its close, add S1's "plus what season N rolls over at its close".
  - **Cabal:** `<span class="status-item"><span class="live-dot" aria-hidden="true"></span>Alive</span>`, with the note "Dies in {deadman(lastVerdictAt + DEADMAN − now)} without a verdict" (X10). Before the seed: "Not started" / "Begins when trading opens".
  - **Wrapping:** S5 deletes site.css:78-80, so a value breaks only at the space before its unit. Keep each value and its unit in one `span.nowrap`; if "<n> imdTEST" still does not fit a 1280 cell, set the symbol in a `span.small` inside the value.
  - **Other states:** loading is the band's skeleton (X11), and the dead state follows X16.

### X6 (P2) Status strip and death banner: wrong pot, no season time or bonus, a partial dead state, "1d 9h", a forced second row [FA-25, TR-09, FB-25]
- **Now:** App.tsx:137-193.
  - **Two rows:** the strip always takes two rows, because site.css:94-96 gives `.test-run` a width of 100%. It is 64 px tall; the mockup's strip is 39 px.
  - **Alive:** "Cabal alive · dies in 1d 8h without a verdict" and "Season N · pot X imdTEST". There is no time left and no "+ 10,000,000 PLEA". The pot is `Seasons.pot()`, the whole Seasons balance, which includes an ended but unclosed season's fees (:163-164).
  - **Dead:** only "Cabal dead". The season item stays "Season 1 · pot …", because currentSeason() returns (false, 0, 0).
  - **Banner:** "no verdict for 1d 9h" (:187).
  - **Before the seed:** the dead dot shows next to "Trading not open yet".
- **Should:** _shell.html:
  - **Alive strip:** "● Cabal alive · dies in 32h 59m without a verdict | Season 2 · 9d 4h left · pot 184.20 IMD + 10,000,000 PLEA | 1M PLEA = 14.16 IMD", with `.mono` and `.num` spans.
  - **Dead strip (the commented block):** "Cabal dead · no verdict for 33 hours | Season 2 ended with the Cabal · close it from 17:59 UTC | price".
  - **Banner:** "The Cabal is dead: no verdict for 33 hours. PLEA trades freely forever. Pleas and objections are closed; sell on the Buy page."
  - **Brief:** the strip starts "Sepolia test run 9 · test tokens, no value".
- **Fix:**
  - **One row:** delete site.css:94-96. The test-run text stays the first `.status-item`, and the strip wraps only when it must.
  - **Alive:** "<b>Cabal alive</b> · dies in {deadman(lastVerdictAt + DEADMAN − now)} without a verdict" (X10). Then "<b>Season N</b> · {countdown(endsAt − now)} left · pot X imdTEST + 10,000,000 PLEA", with `endsAt` from `Seasons.currentSeason()`. Show the bonus (`BONUS_PER_SEASON`) only while the season index < `BONUS_SEASONS`.
  - **Season pot:** S1's `potOf(season)`: `Seasons.seasonFees(season)`, plus `Seasons.rollover()` only when that season is `nextToClose` (Seasons.closeSeason pays seasonFees(nextToClose) + rollover); never `Seasons.pot()`. The strip, Home (X5) and Seasons all use S1's helper.
  - **Dead:** "<b>Cabal dead</b> · no verdict for {span(DEADMAN)}".
    - The last season is S1's `last`, `((diedAt − 1) − startedAt) / SEASON`, numbered as Seasons.checkpoint does.
    - Show "<b>Season N</b> ended with the Cabal · close it from {clock(seasonBounds(last).end + CLOSE_GRACE)}".
    - Once `Seasons.closed(last)` is true, show "<b>Season N</b> closed".
  - **Banner:** the shell's sentence, with span(DEADMAN).
  - **Before the seed:** no dot, "<b>Trading not open yet</b>". If the first read fails, see X11.

### X7 (P2) Remove the Coinbase Wallet SDK: it sends telemetry and sets a cookie on every load, and it is a third of the JS [CK-06, TT-13, CK-14] Decision D3
- **Now:** config.ts:111 adds `coinbaseWallet({ appName: "PLEA", preference: "all" })`, and wagmi's reconnect creates the SDK on load. On every route, with no wallet chosen:
  - **Telemetry:** about 8 to 9 s after load, the page POSTs to cca-lite.coinbase.com/amp and /metrics (device_id, session_id, appOrigin, OS, language, web vitals).
  - **Storage:** it sets a `.coinbase.com` `__cf_bm` cookie and writes localStorage `cbwsdk.store` and IndexedDB `cbwsdk` / `keyval-store`.
  - **Stray request:** it sends a HEAD to the site's own origin, which fails with net::ERR_ABORTED.
  - **Size:** every cold load fetches its 295 KB chunk. A cold load is 1.5 MB in 39 requests; JS is served without gzip or brotli, and the hashed /assets/* files have `cache-control: public, max-age=60`.
- **Should:**
  - Brief: everything reads without a wallet, and nothing asks for third-party analytics.
  - Decision D3: remove the connector. EIP-6963 and injected wallets cover Coinbase Wallet's extension.
- **Fix:**
  - **Remove the connector:** delete `coinbaseWallet` and its import (config.ts:13, 111), and the coinbaseWalletSDK branches in wallet.tsx (:188-202).
  - **Keep the mobile link:** the "Open in Coinbase Wallet" deep link (wallet.tsx:13-18) stays. It opens Coinbase Wallet's in-app browser, which injects a provider.
  - **Lazy-load:** load html-to-image only on #/share, with a dynamic import in share.tsx.
  - **Done when:** no built chunk contains "cca-lite", and a cold load of #/ contacts no *.coinbase.com host and writes no cbwsdk storage.
  - **Hosting (IMD's side, if the job can set headers):** serve JS and CSS with br or gzip, and /assets/* with `cache-control: public, max-age=31536000, immutable`. index.html stays `no-cache`.

### X8 (P2) Toasts show raw function names; there are no pending, sold, verdict or ruling toasts [CT-14, FA-22, FB-19, TR-10]
- **Now:**
  - **Text:** useTx (context.tsx:251) toasts `${fn} confirmed.` after every write: "plead confirmed.", "submitSell confirmed.", "executeSell confirmed.", "approve confirmed.", "swap confirmed.", "setName confirmed.", "record confirmed.", "object confirmed.", "seed confirmed.".
  - **Kinds:** only `toast--ok` (i-check-circle) and `toast--bad` exist (:116-123), so `toast--pending` and `toast--sold` are never used.
  - **Behaviour:** one toast replaces the last, nothing toasts when a verdict or a ruling arrives, and Dismiss is a "×" glyph (:141).
  - **Copy toast:** "Address copied." (components.tsx:133).
- **Should:**
  - Brief: "toasts as in components.html".
  - components.html: one toast per transaction, in the state colours, in plain words, with a link to the transaction. Errors name the problem and the fix, and Dismiss is an icon-btn with i-x.
  - The page mockups give each toast's text.
- **Fix:**
  - **Toast shape:** `{ kind: "pending" | "ok" | "sold" | "bad" | "info", icon, title, body?, links? }`.
    - Default icons: pending i-hourglass, ok i-check-circle, sold i-coins, bad i-warning-circle, info i-info.
    - Show up to 3 toasts, newest last. "bad" ones use role="alert".
    - Dismiss is `<button class="icon-btn" type="button" aria-label="Dismiss"><Icon name="x"/></button>`.
    - The transaction link reads "View transaction" and points at sepolia.etherscan.io.
  - **Who writes the text:** `send()` takes a `toast(receipt)` builder from each call site, which reads ids and amounts from the receipt's logs. Remove the `${fn} confirmed.` default; with no builder, the toast is "Transaction confirmed." plus the link. Approvals get no toast of their own, because the button moves to its next step (T12). Error toasts use the decoded title and fix (T4), never a function name. Keep the mockup's one joke line where its toast has one.
  - **After a receipt**, with numbers from the receipt and chain:
    - **Buy:** as T3 and T11.
    - **Plead, manual or auto:** pending, "Plea #214 sent. The Cabal is deliberating." / "Usually 3 to 6 minutes." plus the link "Open plea #214" (the id comes from PleaSubmitted).
    - **Appeal:** pending, "Appeal #N of plea #M sent. The Cabal is deliberating.", then the same body.
    - **Letter:** pending, "Letter received as plea #212. The Cabal is reading your mail.", with letters.html's body (fees in imdTEST and PLEA).
    - **Sell now:** sold, "Sold 1,240,000 PLEA for 17.14 imdTEST." / "Record your +43 points after 08:19 UTC. Next plea at 12:00 UTC."
    - **Record my points:** ok, "+43 points recorded." / "Season 2: 122 points (43 + 40 + 39), rank 3."
    - **Object:** pending, "Objection #10 filed. A new panel is reading plea #211.", with objections.html's body and "Open plea #211".
    - **Claim:** ok, "Claimed 48,210 PLEA for 0x7a3f…c21e." For a vault: "Claimed 212,500 PLEA for the vault 0x5e1d…44b0." Use claim.html's bodies.
    - **Save name:** ok, "Name saved: mira_eth.", with profile.html's body.
    - **Close season:** ok, "Season 2 closed." / "21 wallets paid 157.96 imdTEST + 8,576,000 PLEA. 26.23 imdTEST rolls over to season 3; 1,424,000 PLEA burned." The numbers come from SeasonClosedOut, PrizePaid, BonusPaid and BonusBurned.
    - **flushToWall:** ok, "Leftovers sent to the buy wall.", with seasons.html's body.
    - **Seed:** as T2.
    - **Copy:** info, "<Label> address copied.".
  - **Live toasts** for the connected wallet come from the snapshot diff (context.tsx:66-75), each once:
    - **Its plea is approved:** ok, "Approved, 36 vs need 33." / "Sell within 7 minutes, by 08:06 UTC."
    - **Its plea is denied:** bad with i-x-circle and role="status", "Denied, 31 vs need 36: 5 short." / "One appeal until 11:53 UTC."
    - **A runner sold it (Delivered):** sold, with letters.html's "Approved, 37 vs need 30, and sold for you: …" toast.
    - **Its window closed unsold:** info with i-clock, plea.html's "The window closed at 08:06:12 UTC." toast.
    - **Its objection is ruled (Ruled):** info with i-gavel, objections.html's "Objection #8 sustained, 29 vs need 33." or "Objection #7 overruled, 33 vs need 33." toasts.

### X9 (P2) Action buttons: one busy label for everything, native disabled, lower-cased connect text, no cost sub-label, a done state that disappears [FA-23, FB-27, FB-29, TR-18, CT-23]
- **Now:** Action (components.tsx:395-468):
  - **Busy:** always "Waiting for wallet / confirmation…" (:438-439).
  - **Disabled:** uses the native `disabled` attribute (:431-433). The button leaves the tab order and its reason is never announced; on #/buy with no wallet, Tab skips "Buy PLEA".
  - **No-wallet reason:** `"Connect in the top bar to " + label.toLowerCase()` (:422) gives "…to buy plea.", "…to submit plea." and "…to send letter.".
  - **Look:** no label has a `.btn__sub`, and every action is `btn--block`.
  - **Done state:** "Confirmed" plus "Confirmed on Sepolia" disappears when the refresh changes the panel. Deliver, Sell now, Return escrow, Settle stake and Expire unmount before it shows (context.tsx:249-250). Close season keeps "Confirmed" next to the next season's "Available from".
- **Should:**
  - components.html Buttons: busy "says what it waits for". Disabled is `aria-disabled`, so the button "stays focusable and ignores clicks", with its reason tied by aria-describedby.
  - PAGE-KIT: the cost goes in `.btn__sub` ("Submit plea 0.50 IMD").
  - Brief WALLET: actions say "Connect in the top bar to ...", and each button has a done state "with a sepolia.etherscan.io link".
- **Fix:**
  - **New props:** `sub` (for example "0.50 imdTEST", "0.85 imdTEST", "gas only", "≈ 17.14 imdTEST", "0.75 imdTEST in PLEA"), a required `connectText`, `walletLabel`, `pendingLabel`, and `block` (default false; true only where the mockup uses btn--block).
  - **Connect text** follows the mockups: "Connect in the top bar to buy." / "…to plead." / "…to object." / "…to send a claim. Any wallet will do: it only pays the gas." / "…to send a letter.". Where no mockup exists: "…to record points." and "…to close the season.".
  - **Busy, before the hash:** `walletLabel`, by default "Confirm in your wallet…". Overrides from the mockups: "Approve imdTEST in your wallet…" and "Confirm the buy in your wallet…" (buy.html), "Confirm the claim in your wallet…" (claim.html).
  - **Busy, after the hash:** `pendingLabel`, by default "Waiting for Sepolia…" ("Saving name…" on Profile), plus the existing "View pending transaction" link.
  - **Disabled:** with no wallet, on the wrong chain, while disabled or once done, render `aria-disabled="true"` instead of `disabled`. onClick returns early, and aria-describedby points at the reason. Delete site.css:88-90.
  - **Done:** keep the last receipt per panel in the context, keyed by useTx's resetKey (for example `plea:<id>` or `close:<season>`). After the state changes, the panel shows "<label> confirmed on Sepolia · View transaction" until the route changes. Close season uses `resetKey = close:<nextToClose>`, so the next season's button starts idle. Where the page has better words, the done line uses them, for example after Sell now: "Sold N PLEA for X imdTEST. Record your +P points after HH:MM UTC. Next plea at HH:MM UTC. View transaction". This covers Deliver, Sell now, Return escrow and tip and Expire unanswered plea on #/p/<id>, and Settle objection stake and Expire objection on #/objections, whose buttons unmount after the refresh (CT-23).

### X10 (P2) Rule lengths and plea ages print as clock times ("within 07:00", "Up to 20:00", "sent 04:12 ago", "1d 9h") [FA-20, FB-04, TT-09, TR-16, CT-19]
- **Now:** `duration()` (chain.ts:308-317) prints "mm:ss" under an hour, "Xh Ym" under a day and "Xd Yh" above. It is used for countdowns, but also in prose and for ages:
  - **Home:** steps "sell within 07:00 … one appeal within 4h 0m" (pages-info.tsx:175); dead-man panel "arrives for 1d 9h" and "Seasons last 5h 0m" (:204, 209).
  - **Plead:** "within 07:00", "Up to 20:00; 30 judges" (pages-trade.tsx:688-689, 727, 750, 754).
  - **Other pages:** Buy "After 1d 9h without a verdict"; Letters "within 07:00" (pages-info.tsx:264); Objections "have 20:00 after approval" (pages-court.tsx:825); Seasons "after 1h 0m grace" (:1081); Profile "Held, buy-weighted 29:44".
  - **Shell:** banner "no verdict for 1d 9h" (App.tsx:187); strip "dies in 1d 8h" (:157).
  - **Cards:** "Plea #12 · sent 04:12 ago" (components.tsx:664).
  - **Screen readers:** Countdown's aria-label reads the digits, "05:12 remaining" (components.tsx:163).
  - **Times:** `utc()` always prints the date ("2026-10-21 15:00 UTC").
- **Should:**
  - PAGE-KIT Formats: `mm:ss`, `3h 41m` and `9d 4h` are for countdowns only; times read "08:19 UTC"; card times read "sent 4 min ago", or "approved 48 s ago" at a verdict moment.
  - components.html Countdowns: the dead-man always counts in hours ("32h 59m", never "1d 8h"), and screen readers get a label in words.
  - Mockup prose: "within 7 minutes", "Up to 20 minutes, usually 3 to 6", "one appeal within 4 hours", "after 33 hours without a verdict", "a 4-hour cooldown", "(1-hour grace)".
- **Fix:** add five formatters in chain.ts and use them at every place listed above:
  - **`countdown(s)`:** today's duration(), for running timers only.
  - **`deadman(s)`:** always hours and minutes ("32h 59m"), for the strip, Home's Cabal cell and the dead-man panel.
  - **`span(s)`:** rule lengths in prose.
    - 2 or more whole days: "15 days".
    - Whole hours: "1 hour", "5 hours", "33 hours".
    - Whole minutes: "7 minutes", "20 minutes", "90 minutes".
    - Anything else: seconds.
    - `span(s, "adj")` gives "4-hour", "1-hour", "7-minute".
    - Use it for EXECUTE_WINDOW, PENDING_EXPIRY, COOLDOWN, DEADMAN, SEASON, CLOSE_GRACE, OBJECTION_WINDOW and LAUNCH_WINDOW.
  - **`ago(s)`:** "48 s ago", "4 min ago", "7 h ago", "3 d ago".
    - Cards read "<span class="sr-only">Plea </span>#215 · 2 min ago".
    - Held times read "3d 4h", or "12 min" under an hour.
  - **`clock(t)`:** "08:19 UTC" when the date is today in UTC; otherwise "2026-10-21 15:00 UTC".
  - **Countdown aria-labels in words:** "Sell within 6 minutes 12 seconds, by 08:06 UTC"; "Season 2 ends in 9 days 4 hours".

### X11 (P2) Loading, read errors and unknown routes: false empty states, transaction wording on read failures, no not-found page [FA-V2, FB-06, FA-33, CK-11, CK-13]
- **Now:**
  - **Loading:** until the snapshot arrives, pages show their empty or zero states instead of skeletons:
    - Home: "No pleas yet…" and "Before the first plea", with stats "Reading…" / "— PLEA" (pages-info.tsx:52, 81-92, 141-151).
    - Seasons: "A seat earns ×0 points", "PLEA bonus 0 PLEA", "A clean docket".
    - Objections: "Nothing open", because of the `s && !cabalAlive` guard, and "have 00:00 after approval".
    - Profile: "— PLEA". Claim's vaults: plain text.
    - Only the Wall has skeleton cards.
  - **Read error:** with every RPC failing, App shows one "Cannot read Sepolia" box (App.tsx:195-203).
    - Its body is the transaction text from errors.ts:151 ("…check your wallet is on Sepolia… Nothing is confirmed until a receipt appears."), even with no wallet.
    - The strip still says "Reading the Cabal…" (App.tsx:148-149).
    - #/wall repeats the text in a second box, and the empty states still show under it.
    - Any failed poll also disables every action, because useTx's `ready` requires `!readError` (context.tsx:270-276).
  - **Not found:**
    - #/no-such-page renders Home under the title "No-such-page · PLEA · Sepolia test run 9" (App.tsx:46, 234-235).
    - A missing plea on #/p/<id> or #/share/<id> is C20.
- **Should:**
  - components.html: every list and every number has empty, loading and error states.
    - Loading is a still skeleton with a loading-label (i-hourglass) saying what is being read.
    - The error box is i-plugs "Can't reach Ethereum" (here, Sepolia) / "The public RPC did not answer. The site tries the next one by itself; your funds are not affected.", with a `btn--sm` i-arrow-clockwise "Try again".
  - Reference bands to port:
    - index.html: "Live strip loading", and "Read error" ("Can't read the latest verdicts").
    - wall.html: "Loading". seasons.html: "The leaderboard loading". objections.html: "Loading: reading the open cases".
    - profile.html: "Loading" and "Read error". claim.html: "Checking" and "Delegated vaults: loading".
    - plea.html: "Loading" and "Error". plead.html: "Loading: reading your facts".
- **Fix:**
  - **Separate read errors:** add `explainReadError(e)`.
    - A plain `Error` thrown by the site's own code passes its message through.
    - Timeouts, HTTP errors and RPC errors return the kit text above.
    - useRead and the snapshot use it; the transaction text is for writes only.
  - **Loading, with no snapshot yet:** each section shows its band's loading state, never an empty state or a 0 / "—" number.
    - Home shows "Reading the pool, the Cabal and the season from the chain…" over the six stat cells (skeleton lines under the real labels).
    - In place of the hero card, Home shows a skeleton; Latest verdicts shows the Wall's skeleton cards.
    - Show an empty state only once the snapshot says the list is empty.
  - **Read error, with no snapshot:** one error box per page.
    - Use the page's own title where its band has one: "Can't read the latest verdicts", "Can't read this profile", "Can't read the price" on Buy (T1). Otherwise "Can't reach Sepolia".
    - No app-level box goes on top of it, and no empty states show under it.
    - The strip's Cabal item reads "<b>Can't reach Sepolia</b>". Try again calls refresh().
  - **Read error, with a snapshot already shown:** keep the data and keep actions enabled. `ready` no longer depends on a poll error, and the simulation before sending (context.tsx:233) still guards the write. After two failed polls in a row, show the error box above the page content; drop it on the next success.
  - **Unknown route:** render a not-found view.
    - h1 "Page not found".
    - Empty state "No page at #/no-such-page" / "Check the link, or pick a page from the menu.", with a `btn--sm` "Go to Home".
    - Title "Page not found · PLEA". document.title comes from the known routes only (X14).

### X12 (P2) Empty states: the 48 px icon renders at 20 px, it is always a gavel, and there is no action and no mockup copy [FB-20, FA-29]
- **Now:** Empty (components.tsx:82-96) wraps the svg in `<span class="empty__icon">`, so the svg keeps `.icon`'s size. Every empty icon measures 20×20, against the kit's 48×48 (components.css:580). The icon is always i-gavel, and no empty state has a button. On Home:
  - The hero holds a card with a second dashed box inside it ("The court is quiet", pages-info.tsx:84-91).
  - Latest verdicts reads "Before the first plea / Nobody has asked for the exit yet." (:148-150).
  - Its section head has a link "Every plea →" (:137-139) where the mockup has a meta line.
- **Should:** components.html: `<svg class="icon empty__icon">`, a title, one line of text and an optional `btn--sm`. The mockups' empty states (icon, title, button), with the body text as written there:
  - index.html: i-scales "No pleas yet" [Write the first plea]. profile.html: i-scales "No pleas yet" [Write a plea].
  - seasons.html: i-trophy "No points yet" [Write a plea].
  - objections.html: i-megaphone-simple "No open cases" [See the Wall]; i-gavel "The court has risen" [Sell on the Buy page].
  - plead.html: i-gavel "Plead is closed" [Sell on the Buy page]. letters.html: i-envelope-simple "The Letterbox is closed" [Sell on the Buy page].
  - claim.html: i-wallet "No delegated vaults" [Open delegate.xyz]. wall.html: i-gavel "No objections yet" [Show all pleas].
- **Fix:**
  - **Component:** `Empty({ icon, title, children, action?: { href, label } })` renders `<div class="empty"><svg class="icon empty__icon" aria-hidden="true"><use href="#i-{icon}"/></svg><p class="empty__title">…</p><p>…</p><a class="btn btn--sm" href="…">…</a></div>`.
  - **Pages:** each page passes its mockup's icon, words and button. Rule lengths such as "20 minutes" come from X10's span().
  - **Home, before the first plea:** show index.html's empty state once, in Latest verdicts; this is where T8's Home empty-state copy goes. Before the seed, T8's not-open line replaces the button. Drop the hero's empty card and its `.split`, so the text column spans the row.
  - **Home's section head:** h2 "Latest verdicts" with the meta "Newest plea first, read from the chain; times are when each plea was sent". Below the grid, a `btn` "See the whole Wall" with i-arrow-right.

### X13 (P2) The wallet button is a short address that opens a modal: no name, no seat dot, no profile link, and "Switch to Sepolia" is not yellow [FA-24]
- **Now:** wallet.tsx:93-112.
  - **Connected:** a `<button class="wallet-btn">` always shows `short(address)` ("0x4b91…6821"). It opens a "Your wallet" `<dialog>` with the full address, "Your profile" and "Disconnect".
  - **Wrong chain:** an ink "Switch to Sepolia" (`class="wallet-btn "`).
  - **Sheet:** the close button is a "×" glyph (:127-133).
- **Should:** components.html "Wallet button states" and _shell.html:
  - Connect is `button.wallet-btn.wallet-btn--connect`.
  - Connected is an `a.wallet-btn` linking to the profile. It holds `<span class="seat-dot" aria-hidden="true">` when the wallet has a seat, the Letterbox name ("mira_eth") or "0x51ab…7c3e", and an sr-only ": your profile (holds an IMD seat)" or ": your profile".
  - Wrong chain is `button.wallet-btn.wallet-btn--connect` "Switch to Sepolia".
  - The brief refuses "modals where a page works".
- **Fix:**
  - **Connected:** render `<a class="wallet-btn" href="#/profile">` with the seat dot (`Seasons.holdsSeat(address)`), the name (`Letterbox.nameOf(address)`, else the short address) and the sr-only text. Read both once per snapshot in one shared hook, not once per component.
  - **Wrong chain:** add `wallet-btn--connect`.
  - **Sheet:** keep the dialog only for Connect (choosing a wallet), with an icon-btn holding i-x.
  - **Disconnect:** on the wallet's own #/profile, a `link-btn` "Disconnect this wallet" next to the address. The mockup has no such control, but it is needed once the button is a link.

### X14 (P2) Menu and focus: Escape drops focus on <body>, opening does not move focus, an extra "Profile" item, a sun icon, page titles [CK-07, FA-34]
- **Now:**
  - **Escape:** App.tsx:36-38 only calls setMenu(false). With focus inside the drawer (320, 360, 768), focus lands on BODY.
  - **Focus:** opening the menu leaves focus on the button. Choosing a drawer link, or any route change, leaves focus on BODY, because handle() only scrolls (:30-34).
  - **Drawer:** it adds "Profile" (:127-129).
  - **Theme toggle:** it swaps to i-sun in dark (:73).
  - **Titles:** "Buy · PLEA · Sepolia test run 9", built from any hash segment (:46).
- **Should:**
  - site.js:156-171: opening focuses the first drawer link. Escape closes the menu and, if focus was in the drawer or on the button, focuses the Menu button.
  - _shell.html drawer: the seven pages plus "How it works".
  - components.html: the toggle keeps i-moon and its one name "Dark theme", with aria-pressed.
  - PAGE-KIT titles: "Buy PLEA · PLEA".
- **Fix:**
  - **Menu:** port site.js's menu logic. Opening focuses the first drawer link; Escape closes and returns focus to the Menu button (through a ref).
  - **Route change:** on every hashchange, close the menu and focus `#main` with preventScroll (it already has tabIndex −1), then do the #how / #contracts scroll.
  - **Drawer:** remove its "Profile" item.
  - **Theme toggle:** keep `<Icon name="moon"/>` in both themes.
  - **Titles:** take them from a route map of the mockup titles:
    - "Selling needs a plea · PLEA" for Home, #/how and #/contracts.
    - "Buy PLEA · PLEA", "Plead to sell · PLEA", "The Wall · PLEA", "Seasons · PLEA".
    - "Plead by letter · PLEA", "Objection! · PLEA", "Claim your PLEA · PLEA", "Profile · PLEA".
    - "Plea #214 · PLEA" for #/p/214, "Share cards · PLEA" for Share.
    - "Page not found · PLEA" for anything else.

### X15 (P2) Home hero: the "Latest verdict" card is a wall card with no facts, meter, summary, countdowns or link; the h1 runs together; the lead is short [FA-01, FA-30]
- **Now:** #/ at every width and theme.
  - **Card:** pages-info.tsx:51-52 picks the newest judged plea (else the newest plea), and :82 renders it with `<PleaCard detail>` (components.tsx:719-720). That gives a stamp--lg, "Plea #N · sent mm:ss ago", the text, a nums row and the who row, in an `<article>` with no link. There is no label, head, facts, meter, summary, countdown or meta line, and nothing opens the plea.
  - **h1:** its text is "Buying is open.Selling needs a plea.", with no space after the span (:60), so its accessible name runs the sentences together.
  - **Lead:** "…and the Cabal scores your case." (:64-67).
  - **Links:** link-btns such as "Seasons and prizes" (:213-215) have no arrow icon; step 4 is titled "Sell" (:173).
- **Should:** index.html hero:
  - **h1:** `<span class="hero-line">Buying is open.</span> Selling needs <span class="nowrap">a plea.</span>`.
  - **Lead:** "PLEA is a meme token on Uniswap v4. To sell, you write why, and the Cabal, 30 judges on an IMD oracle panel, scores it from 0 to 45."
  - **Card (`article.card.plea`):** a `p.label` "Latest verdict". A `.plea__head` with h2.plea__id "Plea #214", "by mira_eth", the SEAT badge with i-armchair, YOU, and `.plea__time` "approved 48 s ago". Then `.hero-stamp` with a `stamp--xl`, the text, `.facts`, the meter ("Score 36 of 45, need 33: passes by 3"), and `.plea__summary`: "Sells 1,240,000 PLEA ≈ 17.56 IMD" and "+43 points held (36 × 1.2)".
  - **Seller's view:** `.plea__actions` has the urgent "Sell within 06:12" and "Objections close in 19:12", then the meta "Sell by 08:06 UTC. Record your +43 points after 08:19 UTC.".
  - **Visitor's view (reference band "Hero card for a visitor"):** no YOU, a plain "Seller's window 06:12", then "mira_eth can sell until 08:06 UTC. Anyone else may object until 08:19 UTC.".
  - **Link:** a `link-btn` "Open plea #214" with i-arrow-right. Every link-btn ends with i-arrow-right, and step 4 is "Sell in 7 minutes".
- **Fix:**
  - **New component:** build a `HeroPlea` from that markup, not from PleaCard. It shows the plea with the highest `verdictAt`. If no plea has a verdict yet, it shows the newest plea, with the label "Latest plea" and "sent N min ago". With no plea at all there is no hero card (X12).
  - **Facts:** the same four-fact block as the plea status page (C15: the share cell exact from `CabalGate.pleaBalance(id)`, the other three read at the block before the PleaSubmitted log). When the RPC refuses historical state, show the meter alone, which already prints "Need N = 71 − fact F" from PleaSubmitted.factScore and the plea's need.
  - **Meter:** with the verdict classes of C6 and the clamp of X3.
  - **Summary:** "Sells N PLEA ≈ X imdTEST" from C2's live sale quote while the plea can still sell, or "Sold N PLEA for X imdTEST" once sold (C16's writer amount). Add the points line, with "× 1.2" when the seat counts.
  - **Countdowns:** show only those still running, in components.html's forms. The urgent pair is only for the seller, for an APPROVED plea inside EXECUTE_WINDOW. Everyone else gets plain countdowns. A pending plea shows "Waiting for the Cabal mm:ss" (countdown--wait); a denied plea's seller sees "Appeal until HH:MM UTC". No countdown pair once the windows have passed.
  - **Stamp:** it lands only through landVerdict.
  - **Text:** add the h1 space, and write the lead with PANEL_SIZE and MAX_PLEA_SCORE from chain. Add i-arrow-right to every link-btn on Home ("Seasons and prizes" included). Step 4's title comes with X17.

### X16 (P2) Home after the Cabal dies: only the Plead button goes [FA-16, TR-08]
- **Now:**
  - **Home**, once CabalGate.diedAt > 0: pages-info.tsx:64-78 keeps "Buying is open. Selling needs a plea.", the alive lead ("To sell, you write why, and the Cabal scores your case.") and "Buy PLEA"; only "Plead to sell" is hidden (:73). There is no "See the Wall", no Cabal cell to turn dead, the stats' notes stay as when alive, and the empty card still says "The first case will be heard when trading opens.".
  - **#/plead:** it keeps the whole form and only disables Submit ("The Cabal is dead. Pleas are closed."); that half is C9's Cabal-dead state.
- **Should:** index.html reference "Home after the Cabal died" (index.html:378-403):
  - **Lead:** "PLEA is a meme token on Uniswap v4. The Cabal is dead, so buying and selling are open to everyone, forever."
  - **Buttons:** `btn--primary` "Buy or sell PLEA" and `btn` "See the Wall".
  - **Cells:**
    - Price note "24h +0.8%" (no "counts as").
    - Pleas note "Final count: no new pleas".
    - Season prize pot note "+ 10,000,000 PLEA; close season 2 from 17:59 UTC".
    - Cabal "● Dead" (live-dot--dead) with the note "No verdict for 33 hours: trades freely forever".
  - **Plead:** plead.html reference "The Cabal is dead: plead is closed" (C9).
- **Fix:**
  - **Home:** when `CabalGate.diedAt > 0`, render exactly that in the hero and the X5 cells, with span(DEADMAN). The season and its close time are S1's `last` season and `closeFrom`. Show the bonus part only while that season < BONUS_SEASONS, drop "close season N from …" once it is closed, and once every season is closed write "Season N was the last.".
  - **#/plead:** C9's Cabal-dead empty state (i-gavel "Plead is closed", "Sell on the Buy page").

### X17 (P2) "How it works" lacks most of the mockup: no fact-score table, CannotPass notice, worked example or the four panels [FA-02, TT-15]
- **Now:** #/how and #/ (pages-info.tsx:153-219), every width.
  - **Steps:** four one-line steps. Step 4 is titled "Sell", and its appeal window prints COOLDOWN as "4h 0m".
  - **Panels:** a "Your need" paragraph with a full-width "Check your facts" button, and a "The dead-man" prose panel with no countdown.
  - **Missing:** there is no fact-score table, no CannotPass notice, no worked example, and no Letters, Objection! or Seasons panel. No page on the site shows the four-fact rules. #/objections shows the fee and stake only inside an open form; #/seasons has no share range and no "1 hour" grace.
- **Should:** index.html section 4 "How it works" (meta "Four steps, all on chain"):
  - **Steps:** "Buy", "Plead", "The Cabal judges" and "Sell in 7 minutes", each with its full text (2.25% fee with 0.5% back; 1% to 50%, at most 2,500,000; 1 to 280 bytes; the 0.50 oracle fee; 30 judges, 0 to 45, 17 must agree, 3 to 6 minutes; the 0.25 auto-sell tip, one appeal within 4 hours and the 4-hour cooldown).
  - **"Your need":**
    - The panel--flush "The fact score" table (h4, meta "0 to 45 points"). Its rows are Share sold (≤ 20% 16 / ≤ 35% 9 / more 3), Held, buy-weighted (≥ 7 days 7 / ≥ 3 days 4 / ≥ 1 day 2 / less 0), Profit or loss (at a loss 13 / gain ≤ 50% 12 / ≤ 200% 10 / ≤ 500% 8 / ≤ 1,000% 6 / more 4) and 24h trend (up > 2% 9 / flat ±2% 5 / down 0), followed by the note on PLEA that no buy record covers.
    - The notice--info "A need above 45 cannot pass." / "The contract refuses such a plea before you pay (CannotPass), so no fee is spent. Plead a smaller share or wait for better facts."
    - The panel "Example: a fresh buyer": its facts, "Fact 16 + 0 + 13 + 5 = 34, so the need is 71 − 34 = 37.", and the holding-time table (34 / 36 / 38 / 41 → need 37 / 35 / 33 / 30).
  - **Four info panels** in an auto-grid, each with its icon and link:
    - Letters (i-envelope-simple);
    - Objection! (i-megaphone-simple);
    - Seasons (i-trophy);
    - The dead-man rule (i-hourglass), with the live countdown "Dies without a verdict in 32h 59m" and the link "Read the rule in the code".
  - objections.html header pills "20 minutes after an approval", "0.50 IMD fee + 0.35 IMD stake", "At most 2 per plea".
- **Fix:** port section 4 as written, with every number from chain:
  - **Fees:** the fee is (IMD_FEE_BPS + PLEA_BURN_BPS) / 100 % and the cashback CASHBACK_BPS / 100 %. The step-1 example is 100 × CASHBACK_BPS / (10000 + IMD_FEE_BPS) = 0.49 imdTEST on a 100 imdTEST buy. Drop the mockup's sample sentence about plea #214.
  - **Plead limits:** MIN_SHARE_BPS, MAX_SHARE_BPS, MAX_SELL, MAX_PLEA_BYTES and ORACLE_FEE.
  - **Judges:** PANEL_SIZE, MAX_PLEA_SCORE and QUORUM.
  - **Windows:** span(EXECUTE_WINDOW) for the sell window. span(COOLDOWN) for the appeal window, since CabalGate.appeal checks `verdictAt + COOLDOWN`. span(COOLDOWN, "adj") for the cooldown.
  - **Tip:** C11's TIP constant (0.25 imdTEST), so it shows before the seed too.
  - **Objection:** Tribunal.OBJECTION_WINDOW, plus ORACLE_FEE + Tribunal.STAKE.
  - **Seasons:** span(Seasons.SEASON) ("5 hours each" in this run), Seasons.TOP, MIN_POINTS, BONUS_PER_SEASON, BONUS_SEASONS, and SEAT_MULTIPLIER_BPS / 10000 written as "×".
  - **Need:** PASS_MARK.
  - **Fact bands:** these are fixed in CabalGate._factScoreAt (CabalGate.sol:269-299) and in the README's fact table. Write them as the mockup does.
  - **Dead-man countdown:** deadman(), with a words aria-label. Before the seed, it reads "The clock starts when trading opens."
  - **Letters panel:** say "from Sepolia Etherscan".
  - **Headings:** h3 for the panels and h4 for the table (X21).
  - **Other pages:** the Objections header pills are C18's, and the Seasons share range ("Shares 4.50% to 3.50%" from shareBps(0) and shareBps(TOP − 1)) and "1-hour grace" are S2's.

### X18 (P2) Contracts: eleven big panels in a changing order, "PairToken", no roles, partner contracts missing [FA-17, TR-12, TT-17]
- **Now:** #/contracts (and the Contracts section on #/), every width.
  - **Layout:** pages-info.tsx:222-243 renders one `panel` with an h3 for each entry of `Object.entries(r.addresses)`, about 1,600 px at 1280.
  - **Order:** it changes between loads (PLEA first, or PleaDistributor first), because loadConfig fills `r.addresses` as each ABI fetch finishes (config.ts:85-105).
  - **Labels:** code keys ("PairToken" for imdTEST, "PoolSwapTest"), with no role lines.
  - **Missing:** the imd/acc Stacker, the seat NFT, IMD Intake v2 and delegate.xyz, and the warn notice.
  - **Owner's powers:** a separate h2 section (details.tsx:96-116), without `PLEA.allow(account)`.
  - **Case:** address case is mixed.
- **Should:** index.html section 6 "Contracts":
  - **"PLEA's contracts":** a panel--flush with an `.addr-list` in this order, each with its role:
    - PLEA "· the token; transfers gated while the Cabal lives";
    - CabalGate "· pleas, verdicts, appeals, sells and the dead-man";
    - Seasons "· points, the leaderboard and payouts";
    - PleaHook "· the pool's fees, burns and buy wall";
    - Letterbox "· letters and auto-sell";
    - Tribunal "· objections and the second panel";
    - PleaDistributor "· the 12% claim list";
    - PleaLaunch "· the launch and the seed".
  - **"What PLEA works with":** a panel--flush (meta "Live today") listing the paired token, the imd/acc Stacker, the identity.md seat NFT, the Uniswap v4 PoolManager, IMD Intake v2 and the delegate.xyz registry, each with a Copy button.
  - **Owner:** the panel "The owner's powers, in plain words", with `PLEA.allow(account)`.
  - **Warning:** notice--warn "While the Cabal lives you cannot sell without an approved plea." / "Only buy what you are happy to hold."
  - **Brief:** Ethereum becomes Sepolia, and "[after launch]" becomes the run-9 addresses.
- **Fix:**
  - **Section 6:** port it, with the section meta "Sepolia" and the first panel's meta "Sepolia test run 9 · launch #2234". List the brief's eight addresses in the order above.
  - **Second panel**, in this order:
    - imdTEST, labelled from `pairSymbol`;
    - imd/acc Stacker (`PleaHook.stacker()`);
    - identity.md seat NFT (`Seasons.seat()`; a test NFT on Sepolia);
    - Uniswap v4 PoolManager 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
    - Uniswap v4 PoolSwapTest 0x9b6b46e2c869aa39918db7f52f5557fe577b6eee, with "· the swap router this test run trades through";
    - IMD Intake v2 (`CabalGate.intake()`);
    - delegate.xyz registry 0x00000000000000447e69651d841bD8D104Bed493.
  - **Addresses:** checksum every address (`getAddress`), render it with AddressView and its Copy button, and toast "<Label> address copied." (X8).
  - **Owner:** move the owner's powers into this section as the mockup's three paragraphs. Keep one sentence that the distributor's owner sets the claim list's root once, and keep the PLEA owner's address row.
  - **Warning:** hide the warn notice after the death.

### X19 (P3) Amounts round to nearest, not down; states flip one second early; three ABIs load unchecked [CT-22, TT-23]
- **Now:**
  - **Rounding:** amount() (chain.ts:294-300) uses `Number(formatUnits(…)).toLocaleString`, which rounds to the nearest value. Paid 0.206933 shows "0.21", the pot 1.546586 shows "1.55", a prize of 0.069596 shows "0.07", and 4.646319 shows "Sold for 4.65".
  - **Boundaries:** pleaState (chain.ts:321-331) and canSell (pages-court.tsx:392) use `>=` / `<` at submittedAt + PENDING_EXPIRY and verdictAt + EXECUTE_WINDOW. So NO VERDICT, LAPSED and the Settle / Expire buttons appear one second early.
  - **ABIs:** the hash check (config.ts:96-101) covers only the manifest's five contracts, so the Letterbox, Tribunal and PleaHook ABIs load unchecked.
- **Should:**
  - README: "Prizes and payouts are rounded down, as the chain pays them".
  - seasons.html: "Each IMD amount is rounded down on its own".
  - CabalGate.sol:492, 501, 540 and 620 compare with `block.timestamp > deadline`.
- **Fix:**
  - **amount():** rewrite it with bigints. Truncate to `digits` (`v / 10n ** BigInt(decimals − digits)`), group the integer part with `toLocaleString("en-US")`, and pad the fraction. Add `mode: "down" | "up"`: "up" for costs the wallet pays (fees, You pay, the PLEA fee cap), "down" for everything else.
  - **Boundaries:** NO VERDICT and LAPSED start when `now > deadline`; canSell holds while `now <= deadline`.
  - **ABIs:** put the abiHash of Letterbox, Tribunal and PleaHook in APP.expected, written at build by scripts/manifest.mjs as the manifest's are, and check them the same way.

### X20 (P3) Link previews get no image; the share text can run long; the letter checker says IMD [CK-15, TT-22]
- **Now:**
  - **Preview:** index.html:16 has `<meta property="og:image" content="./og.png">`, with twitter:card summary_large_image and no twitter:image. X and OpenGraph need an absolute URL, so shared links get no image.
  - **Post:** the X intent (share.tsx:156-158, 222) quotes up to 280 bytes of plea, plus a prefix, a suffix and the URL, so it can pass 280 characters.
  - **Letters:** the checker's "Reads as" line shows text-check.js's "for the 0.25 IMD tip" (components.tsx:333-335).
- **Should:** Brief: "Share on X" with the #/p/<id> link; label amounts with imdTEST.
- **Fix:**
  - **Absolute URLs:** write them at build. Set VITE_SITE_URL=https://plea-test-run-9.sites.imd.fun/ in .env.production, and use `%VITE_SITE_URL%og.png` in index.html for both og:image and twitter:image.
  - **More tags:** add og:url, `og:image:width` 1200, `og:image:height` 675 (og.png's size) and og:image:alt. Crawlers ignore the hash, so every link shares this one preview.
  - **Post length:** whatever post text S13 settles on, shorten the quoted plea with "…" so the post fits 280 characters, counting the URL as 23.
  - **Letter checker:** C13's swap of `\bIMD\b` for the pair symbol, when the page renders text-check.js's reads, fixes it. Do not edit text-check.js.

### X21 (P3) Panel titles are h2 inside h2 sections [FA-32]
- **Now:** Panel (components.tsx:49-64) always renders `h2.card__title`. On #/, "Your need", "The dead-man", "Fees on every trade", "Supply" and the hero's "Latest verdict" sit as h2 siblings of their section's h2.
- **Should:**
  - PAGE-KIT: one h1, and headings in order.
  - index.html: section h2, panel h3, and "The fact score" as h4. The hero's label is a `p.label` and its plea id an h2.
- **Fix:** give Panel a `level` prop (2, 3 or 4; default 3), and set it on every page to match the mockup's outline. Check the heading list on each route.

### X22 (P3) Sections sit 72 px apart, and short pages leave a band under the footer [FB-21, FB-30]
- **Now:**
  - **Spacing:** the Wall, Letters, Claim, Objections, Seasons and Profile wrap their sections in `<div className="stack stack--lg">` (pages-court.tsx:82, 732, 888; pages-info.tsx:254, 544, 805). The 24 px gap plus `.section`'s 48 px top padding gives 72 px above each h2.
  - **Footer:** on short pages (#/profile with no wallet, #/share/<missing id>) at 1280×900, about 121 px of paper shows under the footer.
- **Should:** in the mockups, `.section`'s own padding (48 px) is the only gap between sections, and the footer ends the page.
- **Fix:**
  - **Spacing:** render those page roots as fragments, and keep `stack` only inside sections.
  - **Footer:** add `#root { min-height: 100dvh; display: flex; flex-direction: column }` and `#root > .main { flex: 1 0 auto; width: 100% }` to site.css. Check that `.page` keeps its width.

### X23 (P3) The profile's "All pleas for this wallet" link is a 24 px target [CK-08]
- **Now:** on #/profile and #/profile/<address> at 360, a bare `<a>` (pages-info.tsx:946) measures 155×24. The Wall's "More filters" checkbox labels are 28 px tall.
- **Should:** Brief: targets 44 px. profile.html:179 uses an `a.link-btn` "All pleas on the Wall" with i-arrow-right (min-height var(--target)).
- **Fix:**
  - **Profile link:** use that `a.link-btn` and keep the wallet filter in its href.
  - **Wall filters:** they become chips with S6's filter rebuild.
  - **Buy's "Max":** it stays as the kit draws it, because components.css:195 is the design system's own rule.

## Index

Each finding id and the item that fixes it.

| Finding | Item | Finding | Item | Finding | Item |
|---|---|---|---|---|---|
| CK-01 | X3 | FA-11 | C11 | FB-26 | C13 |
| CK-02 | X1 | FA-12 | C9 | FB-27 | X9 |
| CK-03 | X1 | FA-13 | T7 | FB-28 | C23 |
| CK-04 | X1 | FA-14 | T8 | FB-29 | X9 |
| CK-05 | X2 | FA-15 | X5 | FB-30 | X22 |
| CK-06 | X7 | FA-16 | X16 | FB-V1 | S7 |
| CK-07 | X14 | FA-17 | X18 | FB-V2 | S2 |
| CK-08 | X23 | FA-18 | T10 | TR-01 | T1 |
| CK-09 | S6 | FA-19 | S7 | TR-02 | T3 |
| CK-10 | S5 | FA-20 | X10 | TR-03 | T4 |
| CK-11 | X11 | FA-21 | C20 | TR-04 | T5 |
| CK-12 | C20 | FA-22 | X8 | TR-05 | T2 |
| CK-13 | X11 | FA-23 | X9 | TR-06 | T11 |
| CK-14 | X7 | FA-24 | X13 | TR-07 | T6 |
| CK-15 | X20 | FA-25 | X6 | TR-08 | X16 |
| CK-16 | S9 | FA-26 | C15 | TR-09 | X6 |
| CK-V1 | X4 | FA-27 | C10 | TR-10 | X8 |
| CT-01 | C4 | FA-28 | C13 | TR-11 | T5 |
| CT-02 | S1 | FA-29 | X12 | TR-12 | X18 |
| CT-03 | C1 | FA-30 | X15 | TR-13 | X5 |
| CT-04 | S6 | FA-31 | T7 | TR-14 | S8 |
| CT-05 | C1 | FA-32 | X21 | TR-15 | T8 |
| CT-06 | C7 | FA-33 | X11 | TR-16 | X10 |
| CT-07 | C8 | FA-34 | X14 | TR-17 | T7 |
| CT-08 | C5 | FA-V1 | C2 | TR-18 | X9 |
| CT-09 | S8 | FA-V2 | X11 | TR-19 | T10 |
| CT-10 | C16 | FA-V3 | C12 | TR-21 | T11 |
| CT-11 | C15 | FA-V4 | C15 | TR-22 | T12 |
| CT-12 | C10 | FB-01 | X3 | TR-V1 | T9 |
| CT-13 | C14 | FB-02 | S1 | TT-01 | T1 |
| CT-14 | X8 | FB-03 | C19 | TT-02 | C1 |
| CT-15 | S13 | FB-04 | X10 | TT-03 | S1 |
| CT-16 | S4 | FB-05 | S2 | TT-04 | S1 |
| CT-17 | C3 | FB-06 | X11 | TT-05 | C3 |
| CT-18 | C9 | FB-07 | S13 | TT-06 | T4 |
| CT-19 | X10 | FB-08 | C18 | TT-07 | C4 |
| CT-20 | C12 | FB-09 | C19 | TT-08 | T3 |
| CT-21 | C21 | FB-10 | C7 | TT-09 | X10 |
| CT-22 | X19 | FB-11 | C8 | TT-10 | C8 |
| CT-23 | X9 | FB-12 | S7 | TT-11 | X3 |
| CT-24 | C11 | FB-13 | S6 | TT-12 | X5 |
| CT-25 | S9 | FB-14 | S10 | TT-13 | X7 |
| CT-V1 | C17 | FB-15 | S10 | TT-14 | C11 |
| FA-01 | X15 | FB-16 | S8 | TT-15 | X17 |
| FA-02 | X17 | FB-17 | S11 | TT-16 | S14 |
| FA-03 | C12 | FB-18 | S12 | TT-17 | X18 |
| FA-04 | C6 | FB-19 | X8 | TT-18 | S8 |
| FA-05 | C14 | FB-20 | X12 | TT-19 | C22 |
| FA-06 | C15 | FB-21 | X22 | TT-20 | C21 |
| FA-07 | C17 | FB-22 | S3 | TT-21 | T10 |
| FA-08 | C5 | FB-23 | S15 | TT-22 | X20 |
| FA-09 | C10 | FB-24 | S15 | TT-23 | X19 |
| FA-10 | T7 | FB-25 | X6 |  |  |
