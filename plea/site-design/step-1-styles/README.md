# PLEA site design, step 1: three style directions

The same screen in each direction: a plea card with its verdict stamp, the buy box and three leaderboard rows. Open the `.html` files in a browser, or look at the `.png` files (1200 px wide). The canvas with all three is a private Design artifact: https://claude.ai/artifact/LWsbA9rpFZ1y2GhhNGPECP.

| | A · Neo-brutal docket (recommended) | B · Night ledger | C · Parchment chambers |
|---|---|---|---|
| Mood | A notice nailed to the courthouse door: bold, flat and plain about the money. | A night-shift ledger: numbers first, and the stamp is the only colour. | A private court after hours: parchment, ink and a wax seal; calm, and a little absurd. |
| Type | Archivo Expanded 800 (headlines, stamps, buttons), Archivo 400–600 (body), IBM Plex Mono (countdowns, inputs, addresses) | IBM Plex Mono 400–600 for everything | Fraunces 600 (headlines, plea quotes, stamps), Geist (body), Geist Mono (numbers) |
| Ground | cream `#FBF6EA`, white cards, ink `#121212`, 3 px outlines | black `#0A0A0A`, cards `#141414`, ink `#F2F2F2`, 1.5 px rules | parchment `#F3ECDF`, cards `#FCF8F0`, ink `#29231E`, hairlines |
| Action colour | yellow `#FFD92E` (never used for a state) | white pill | wax red `#8E2A24` |
| Stamp | flat state fill, black text, 3 px outline, hard shadow, -3° | outline and text in the state colour, -3° | double rule, tinted fill, serif capitals, -3° |
| Picture | [a-neo-brutal-docket.png](a-neo-brutal-docket.png) | [b-night-ledger.png](b-night-ledger.png) | [c-parchment-chambers.png](c-parchment-chambers.png) |

State colours (A / B / C): approved `#4BE08F` / `#3ECF7A` / `#2E6B3C`, denied `#FF5A4E` / `#FF6B62` / `#9B2A23`, pending `#FFC247` striped / `#F2B84B` dashed / `#7F5300`, no verdict `#C9C3B6` / `#A6A6A6` / `#5E5347`, lapsed dashed outline in all three, sold (executed) `#6FA8FF` / `#7AB0FF` / `#24507F`. Every text pair is at least 4.5:1 (checked with a WCAG contrast script; the lowest is B's lapsed grey at 5.48:1). The stamp always says its state in words, so colour is never the only signal.

**Restraint in A (it moves money):** hard shadows only on what you can press, on cards and on the stamp; one action colour, never a state colour; black text on every colour; pending is striped, so it reads without colour; amounts in tabular figures, countdowns and inputs in mono.

**Recommendation: A.** Each verdict gets a flat colour and a stamp you can read across the room (the last site's biggest miss was one red for every state). Thick outlines and big buttons are easy to see and hit, focus rings come for free, and the meme energy fits a meme token. It also looks nothing like imd.fun, so nobody takes it for an official IMD page. B is the current X look but sits too close to imd.fun's own style, and long pleas are tiring in mono. C is calm and distinctive but slow for numbers, and its wax red is the same red as DENIED.

**Sample data** follows `NEXT_SESSION.md`'s agreed numbers (mainnet): a 20% plea held 3 days at an 18% loss in a flat market scores fact 16 + 4 + 13 + 5 = 38, so it needs 71 - 38 = 33; the judges gave 36, approved; with a seat that is 36 × 1.2 = 43 points (rounded down). Fees 2.25% (0.50 IMD of 100 back as staked IMD). Season shares from `Seasons.SHARES`: rank 3, 4, 5 = 4.42%, 4.38%, 4.33% of a 184.20 IMD pot and of the 10,000,000 PLEA bonus. Price 1M PLEA = 14.16 IMD (near the 14,000 IMD opening market cap). The names (`mira_eth`, `kafka_cat`) and the plea text are made up for the sample.

**Waiting on the user:** the pick, plus light or dark (or both), how loud the colours, mono or display headlines, the tone, how much motion, and whether to redo the X logo and header in `plea/brand/`.
