# PondPad UX research: Pump.fun and Pons

What the two closest launchpads do, what works for users, what doesn't, and what PondPad takes from each. The page layouts that follow from it are in [`system/Pages.md`](system/Pages.md); the look in [`system/README.md`](system/README.md) (brand book) and [`moodboard.html`](moodboard.html).

Sources (5 Oct 2026): pump.fun (live site and its help centre, CoinGecko's and DappRadar's guides), ponsfamily.com (live launchpad page and docs). Both apps render in the browser, so parts of this rely on their public guides and on how pump.fun has worked since 2024; anything we couldn't see directly is marked as such.

## 1. Pump.fun (Solana; the category leader)

**Layout.**
- **Navigation:** a left sidebar or top navigation (Home, Explore, Leaderboard, Live, Discover with sub-products), search with ⌘K, deposit and sign-in buttons.
- **Home:** a hero illustration (a smiling green character running across a hill with meme animals) and one line: "Pump lets anyone create coins, giving everyone equal access to buy and sell from the start. Prices can move quickly, so trade carefully."
- **Feed:** under the hero, trending coins and sortable tabs. Historically: the "King of the Hill" spotlight for the coin closest to graduating, a live flashing feed of buys and new coins, and a grid of cards (image, name, ticker, creator, market cap, replies) sorted by bump order, last reply, creation time or market cap.
- **Coin page:**
  - left: a TradingView chart, then tabs for the comment thread and live trades
  - right: the trade panel (Buy / Sell, SOL amount presets, slippage), the bonding-curve progress bar with the market cap goal, the King-of-the-Hill progress and the holder distribution (each wallet's %, the curve labelled)
- **Create:** name, ticker, image, description, socials (optional) and an optional first buy.
- **Profile:** coins held, coins created, replies, followers.
- **Gate:** a terms / 18+ acknowledgement before trading.

**What works:**
- **Instant feedback.** The live feed and moving progress bars make the place feel alive; people come back to watch.
- **Short path.** One click from a card to a trade box; buying takes a preset and one button.
- **One goal.** The progress bar makes graduation the shared goal of every holder ("help it graduate").
- **Holder distribution** next to the trade box answers "is this a rug?" quickly.
- **Spawning is easy.** Creating a coin is a one-minute form.

**What doesn't:**
- **Noise.** The flashing feed, crowded cards and spammy comment threads make it hard to judge a coin. The comment threads need heavy moderation and attract scams.
- **Hidden costs.** Fees and where they go are not on the trade box, so users find out after the trade.
- **Weak trust signals.** Nothing distinguishes a creator who linked real socials from one who pasted links.
- **Phones.** On phones the coin page is long and the trade panel ends up under the chart.
- **Tone.** A meme-casino tone that invites gambling more than understanding.

## 2. Pons (Robinhood Chain; direct competitor)

**Layout:**
- **Navigation:** a top bar with Explore, Stocks and Create, search with ⌘K, and a product menu (Explore, Analytics, Create, Profile, Docs).
- **Explore:** opens with one line ("Tokens still climbing toward graduation on Robinhood Chain") and a token list sorted by recent buys, newest, oldest, market cap or volume, with All / 24h / 7d filters.
- **Token page:** pool price and market numbers, a graduation progress line, creator and protocol fees, social links and the trade box.
- **Analytics:** a separate page.
- **Docs:** a separate site with Protocol (overview, launch, trading, graduation, fees, risks) and Integration (network, contracts, events, reading state, pricing).
- **Risk lines:** the same kind of line repeats across pages: "Transactions are submitted through your wallet and may be irreversible", "can be volatile or lose all value".
- **Graduation copy:** "graduation only confirms the threshold was reached. It is not a quality signal".

**What works:**
- **Calm and clean.** Pons reads as a serious product, and the fees are stated.
- **Honest risk lines and graduation framing.** They build trust.
- **Integration docs.** Contracts, events and pricing give apps and bots what they need.
- **Profile in the main menu.**

**What doesn't:**
- **Little personality.** Nothing to remember it by, and little sense of activity (no live feed, no moment when a coin graduates).
- **Docs live elsewhere.** They are a separate site, so the page you're on can't explain itself in place.
- **Thin lists.** The list shows few signals per token (no badges, no website, no progress on the row; from what we could see).

## 3. What PondPad takes, and what it adds

| Take | From | How PondPad does it |
|---|---|---|
| Live activity | Pump.fun | **Ripples**: one calm line of buys, sells, spawns and Leaps under the top bar; it scrolls slowly and pauses on hover. No flashing |
| A shared goal with a spotlight | Pump.fun (King of the Hill) | **About to Leap** row on Explore (gold spotlight cards, ≥ 75% of the target), and the **Leap meter** on every tadpole card |
| Short path to a trade | Pump.fun | The card links straight to the coin page; the trade box sits in the first screen with presets; on phones a fixed Buy / Sell bar opens a bottom sheet |
| Holder distribution next to trading | Pump.fun | Holders tab, with the curve, pool, creator and burn addresses labelled |
| Calm, legible base and stated fees | Pons | Dark-water UI with color only for state; **fee line always visible** in the trade box, broken down (base + tax and where it goes) |
| Risk lines in plain view | Pons | One line on every trade box, Spawn and the sale page; full Risks page in Docs |
| "Graduation is not a quality signal" | Pons | Leap modal and Docs say it in our voice |
| Docs with integration pages | Pons | **Docs inside the site** (same nav, same style), with contracts, events and the integrator programme (15% of the protocol fee) |
| Profile in the main nav | Pons | **Profile** in the tab bar: holdings, created coins with a **claim section for creator fees**, rewards, activity |

What neither does, and PondPad adds:
- **The coin's own life story:** Egg → Tadpole → Frog chips, the Leap moment and the free Chorus-built website card.
- **Trust signals that mean something:** "X verified" comes from an onchain voucher (`SocialRegistry`), "Site by the Chorus" links to a public swarm job, and the takeover status is shown as a banner.
- **Where the money goes:** a Transparency page reading the splitter, funds and timelocks.
- **Three ways to pay:** IMD, ETH or USDG everywhere, with the route shown ("ETH → IMD → $RIBBIT").

What PondPad leaves out in v1:
- **On-site comment threads.** They are pump.fun's biggest spam and moderation cost. The coin page links the coin's verified X account instead. *(Proposal; see Pages.md.)*
- **Leaderboards of traders**, which encourage gambling over judgment.
- **A blocking "terms" modal.** Risk is stated in context instead; terms live in the footer.

## 4. Principles for every page

1. **Answer three questions above the fold:** what is this, what can I do, what does it cost.
2. **Show the fee and route before the button, always.**
3. **Give every state a word** (Egg, Tadpole, Frog, Sell, Takeover), not color alone.
4. **One primary action per view** (one lily button).
5. **Phones are first-class.** A bottom tab bar, the trade box as a sheet, 44px touch targets, no hover-only information.
6. **Movement means something happened.** Nothing moves for decoration.
7. **Everything shown is read onchain or from the indexer,** with its source in Docs. Nothing is typed in by hand.
