# PLEA promo video: shot list (16:9, 78.4 s, on the beat grid)

Music: the 78.37-s edit of "The Builder" (`tools/make_music.sh`); 122.4 BPM, a beat every 0.49 s, a bar every 1.956 s. Bar downbeats (video seconds), from `data/beats-16x9.json`:

| Bar | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| s | 1.98 | 3.94 | 5.89 | 7.84 | 9.79 | 11.74 | 13.70 | 15.65 | 17.61 | 19.55 | 21.50 | 23.45 | 25.43 | 27.59 | 29.56 | 31.50 | 33.45 | 35.40 | 37.35 | 39.30 |

| Bar | 20 | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 | 30 | 31 | 32 | 33 | 34 | 35 | 36 | 37 | 38 | end |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| s | 41.26 | 43.20 | 45.16 | 47.10 | 49.06 | 51.01 | 52.96 | 54.91 | 56.87 | 58.81 | 60.77 | 62.73 | 64.67 | 66.62 | 68.58 | 70.53 | 72.48 | 74.43 | 76.38 | 78.37 |

The music's shape: 0–1.98 one quiet bar; 1.98 the band comes in; **break 1** hits 27.6–29.6, silence 29.9–32.4, a drum roll 31.8–33.4, the band back at 33.45; the splice at 56.87 (inaudible); **break 3** hits 57.85, 58.82, 59.31, 60.77, silence 61.2–62.6, a roll 62.6–64.6, the band back at 64.67; **the hard stop** at 76.38.

Sources: S = a real capture of the run 9 site (Playwright; the site's chain reads sent to a Sepolia fork at the named block, the clock set to that block); A = an animation built from the site's own components with real data.

## 1 · Opening (0.00–5.89, bars −1 to 1) · A
- 0.00–1.0: on paper, "buying is open." drops in word by word on the beats. 1.0–1.9: "selling needs a plea." the same way (huge, left-aligned, ink).
- **1.98 (the band comes in):** the yellow PLEA stamp slams onto the right half. Thud, camera jolt. Hold, slow push-in to 5.89.
- SFX: a soft key per word, the thud.

## 2 · Writing the plea (5.89–11.74, bars 2–4) · S
- The Plead page as player p2 sees it before plea #14 (fork at block 11,971,312, Thu 2026-10-22 18:25 UTC). The amount field takes "90,000"; then plea #14's real text is typed letter by letter (each frame a real state of the page): *"Dear judges, today your server took a long lunch and my plea came back from it with a 33. No complaint: I bought a day ago, I am still under water, and I need 90,000 PLEA, about 3%, to pay the fees of staying in this game. Everything else I hold stays for the seasons."* The byte counter climbs to 268 / 280.
- **11.74:** the cursor presses **Send plea**.
- Caption (bars 3–4): **"Want to sell? Write the Cabal a plea."** · small: "280 bytes".
- SFX: key clicks on 16ths, the button click on 11.74.

## 3 · Sent (11.74–15.65, bars 5–6) · A
- The typed text lifts out of the form into the plea card (Plea #14 · by 0xB45A…1811 · Sepolia test run 9), folds in two on the beat, slides right into the docket: a stack of the day's real pleas (#13, #15) with PENDING stripes. A receipt drops: "oracle fee paid".
- Caption (bar 6): **"The Cabal takes no bribes. Just a 0.5 IMD fee."**
- SFX: paper fold, whoosh, a stamp-pad tap for the receipt.

## 4 · The Cabal judges (15.65–23.45, bars 7–10) · A
- 15.65: 30 seat tiles in a 6 × 5 grid, numbered with the judges' real seat NFT ids. 17 of them light up one by one on 16ths and drop their real score (30, 33, 33, 33, 34, 34, 34, 35 × 7, 37, 38, 39); 13 stay empty (17 matching answers were enough).
- 19.55: the 17 scores fly into one sorted row; the middle one, **35**, lifts out and grows (that is IMD's answer: 17 agreed within 15%).
- 21.50: one judge's real note slides in as a wink: *"9/12: … a light server-lunch joke make the plea well made."* (seat 1039).
- Caption (bar 7): **"30 IMD oracle judges score it 0–45. 17 must agree."**
- SFX: a tick per seat, a shuffle for the sort, a bell when 35 lifts out.

## 5 · The bar (23.45–27.59, bars 11–12) · A
- The site's four fact cards for #14 drop in on beats: share sold 3.32% (+16), held 1d 3h (+2), profit or loss −2.18% (+13), 24h trend flat (+5) → fact 36 → **need 35** (= 71 − 36). The meter draws itself with the need marker; the score 35 slides up to it.
- Caption: **"The facts set your bar."**
- SFX: a card drop per beat, a ratchet as the marker moves.

## 6 · DENIED (27.59–33.45, break 1) · S, then A
- 27.6–29.6 (the hits): hard cut, beat by beat, to plea #1's card (Wed 13:22, airdrop only, 15 minutes held): *"I got 2.5M PLEA from the airdrop when trading opened today and have held it for about 15 minutes…"*; its meter: 27 against need 40.
- **~29.9 (into the silence):** the DENIED stamp, "27 vs need 40", lands. The thud is the only sound.
- 30.5: caption **"Denied. Wait 4 hours. One appeal."** 31.3: small wink line: **"On Sepolia, 4 of 25 pleas got through."**
- 31.8–33.4 (the roll): the caption wipes off.

## 7 · APPROVED → SOLD (33.45–39.30, bars 16–18) · S
- **33.45 (the band is back):** plea #14's page (fork at block 11,971,32x, Thu 18:28 UTC); the APPROVED stamp lands, "35 vs need 35".
- 35.40: the black urgent box, "Sell within 06:5x" in yellow digits, ticking; the cursor presses **Sell now** at 37.35; the stamp turns to **SOLD** on the next downbeat.
- Caption: **"Approved: 7 minutes to sell."**
- SFX: thud, ticks, click, a second, lighter stamp.

## 8 · OBJECTION! (39.30–45.16, bars 19–21) · A, then S
- **39.30:** "OBJECTION!" slams diagonally over #14's card (objection purple, display type).
- 41.26: a second grid of 30 seats flickers and settles on **32**; the stamp **SUSTAINED · 32 vs need 35** lands; the points "+35" are struck through. A small line: "the sale stands".
- 43.20: the real #14 page after the objections: "A second panel sustained an objection. No points; the sale stands."
- Caption: **"Think it got off easy? Anyone can object for 20 minutes."**
- SFX: the slam, ticks, thud, a pen strike.

## 9 · Letters (45.16–51.01, bars 22–24) · A
- A transaction card in our style (not Etherscan): To: Letterbox · Value: 0 · Input data. The input field shows hex that flips, character by character, into letter #4's real text: *"Dear judges, a letter from a holder of one afternoon. … gas does not take IOUs and my wallet is thirsty. …"* (tx `0x412e…7e92`).
- 49.06: the card is sent (whoosh) and lands in the docket with PENDING stripes and a small "20% of my PLEA in escrow" tag.
- Caption: **"No site? Plead in a transaction."** · small: "If it wins, it sells itself."
- SFX: hex ticks, whoosh.

## 10 · Seasons (51.01–56.87, bars 25–27) · S
- The run 9 Seasons leaderboard (fork at block 11,986,640, Sat 22:09 UTC); rows slide into rank as the season closes; the top row reaches **79 points · 1st**; a small **PRIZE PAID** stamp lands on it at 54.91.
- Caption: **"Every win scores. Top 25 split the pot + 10,000,000 PLEA."** · small: "IMD seat holders score 1.2×".
- SFX: row clicks, a thud for the prize stamp.

## 11 · The dead-man (56.87–64.67, break 3) · A, then S
- 56.87: a huge mono clock, **33:00:00**. On the hits it jumps: 57.85 → 24:00:00, 58.82 → 12:00:00, 59.31 → 01:00:00, 60.77 → 00:00:01.
- **61.2 (silence):** 00:00:00. The 30 seats go dark one by one; the ground turns to the site's dark theme (the lights go out).
- 62.6 (the roll): the run 9 site's real dead banner slides in (dark theme): "The Cabal is dead: no verdict for 33 hours. PLEA trades freely forever." and its Plead page line: "Court is adjourned."
- Caption: **"33 hours with no verdict and the Cabal dies."** · small: "Run 9: Mon 07:28:12 UTC".
- **64.67 (the band is back):** **"Trading is free. Forever."** slams in.
- SFX: clock rattle on each hit, seat clicks in the silence.

## 12 · Proof and end card (64.67–78.37, bars 32–38) · A
- 66.62, 68.58, 70.53: three paper receipts drop on downbeats (mono type): **852 tests** · **8 swarm audit rounds** · **5 days live on Sepolia: 25 pleas, 3 objections**.
- 72.48: the receipts slide off; ink ground (brand v2 B). **"Make your case."** (display, cream), then **"Coming to Ethereum"** and **@Pleaimd**.
- **76.38 (the hard stop):** the yellow PLEA stamp slams onto the ink. Hold to 78.37.
- Fine print (from 72.48): "Not financial advice. Not an official IMD page. Music: "The Builder" Kevin MacLeod (incompetech.com), CC BY 4.0."

## 9:16 cut
After the 16:9 is approved: a ~45-s music edit on the same grid and shots 1, 2 (shorter), 3, 4, 7, 8, 11 and 12, laid out for 1080 × 1920.

## Captures to make (run 9 site on a Sepolia fork)
| Shot | Page | Block | Clock (UTC) | Wallet |
|---|---|---|---|---|
| 2 | Plead | 11,971,312 − 1 | Thu 2026-10-22 18:25 | p2 (address only) |
| 6 | Plea #1 | ~11,962,690 | Wed 2026-10-21 13:25 | none |
| 7 | Plea #14 | 11,971,32x (approved, window open) | Thu 18:28 | p2 |
| 8 | Plea #14 | after both objections (~11,971,345) | Thu 18:50 | none |
| 10 | Seasons | 11,986,640 | Sat 2026-10-24 22:09 | none |
| 11 | Home / Plead, dark theme | live (dead) | now | none |
