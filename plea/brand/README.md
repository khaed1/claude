# PLEA brand files (X account @Pleaimd)

## v2: neo-brutal docket (2026-10-19, current)

Redone in the site's new design system (`plea/site-design/tokens.css`, `components.css`; the user chose "redo to match"). The ideas of the first set stay: PLEA as a stamp, "buying is open. selling needs a plea.", the APPROVED and DENIED verdict stamps, the bottom left of the header left empty for the photo, never IMD's diamond, nothing that reads as an official IMD account. The look is the site's: cream paper, ink outlines, the yellow PLEA logo stamp tilted -3° with a hard shadow, flat state colours with ink text, Archivo Expanded 800.

All files are in `v2/`:

| File | What |
|---|---|
| `pleaimd-v2-B-1000.png` | **Profile photo B (recommended)**: the yellow PLEA stamp on ink `#121212`, with the site's dark-theme cream outline and shadow. 1000 x 1000 |
| `pleaimd-v2-A-1000.png` | Profile photo A: the yellow PLEA stamp on cream `#FBF6EA`, ink outline and shadow (the site's light theme). 1000 x 1000 |
| `pleaimd-v2-avatar-preview.png` | A and B circle-cropped at 200, 128, 48 and 32 px on X dark (`#000`) and X light (`#fff`), drawn at 1 device pixel per px (the worst case) |
| `pleaimd-v2-header-1500x500.png` | X header: cream ground, "buying is open. / selling needs a plea." in Archivo Expanded 800, an APPROVED stamp ("36 vs need 33") and a DENIED stamp, and one thin line under an ink rule: "A meme token on Uniswap v4 · 30 IMD oracle judges score every plea to sell". The bottom left (x < 440, y > 300) is empty for the photo, and everything sits at least 64 px from the top and bottom and 96 px from the sides |
| `pleaimd-v2-profile-mock.png` | How X web shows the profile (600 px column, dark mode): the header, photo B over its bottom left, "Plea IMD", @Pleaimd |
| `plea-v2-stamp-light.png` | The PLEA logo stamp on a transparent background, for light backgrounds: ink outline, shadow and letters (1063 x 470) |
| `plea-v2-stamp-dark.png` | The same for dark backgrounds: cream `#F5F0E4` outline and shadow, ink letters, as the site's dark theme draws its logo |
| `src/` | The HTML each PNG is rendered from (`brand.css` holds the tokens, `.logo` and `.stamp`) and `render.mjs`, which renders them all with Playwright: `PLAYWRIGHT=/opt/node-tools/node_modules/playwright/index.mjs node v2/src/render.mjs`. Add `?guide` to an avatar or the header to see X's crop and the empty photo area |

**Recommended photo: B.** On X light its ink circle keeps a hard edge on white. A's cream is 1.08:1 against white, so A loses its circle and looks like a loose sticker. On the profile page the photo sits on the cream header: B stands out against it, while A blends into it in X light mode. The yellow stamp is brightest on ink, and "PLEA" still reads at 48 px and, just, at 32 px on a 1x screen (sharp on 2x and 3x phones). A works well on X dark (a bright cream coin), so it can stand in where the ground is dark.

**Colours** (from `tokens.css`): paper `#FBF6EA`, ink `#121212`, secondary text `#4A463E`, logo yellow `#FFD92E`, approved `#4BE08F`, denied `#FF5A4E`; dark-ground outline `#F5F0E4`. Ink on yellow is 13.6:1, on approved 11.0:1, on denied 6.1:1, on paper 17.4:1; the thin line `#4A463E` on paper is 8.7:1.

**Type**: Archivo Expanded 800 (Archivo at width 125, weight 800) for the wordmark, headline and stamps; Archivo 600 for the thin line; IBM Plex Mono 600 for "36 vs need 33", as on the site's stamp. Loaded from Google Fonts when rendering and baked into the PNGs.

**Licences**: Archivo, SIL Open Font License 1.1 (Omnibus-Type); IBM Plex Mono, SIL Open Font License 1.1 (IBM). Both allow use in images and logos. The profile mock also uses Inter (SIL OFL 1.1), only for X's own interface text.

**Bio**: the bio drafted with the first set (below) ends its line with the old cursor, "plea_". In v2 it would read: "buying is open. selling needs a plea. / meme token on uniswap v4: 30 IMD oracle judges score every plea to sell. / mainnet soon. any PLEA there now isn't ours" (158 characters by a plain count, the same as the v1 draft; X allows 160).

## v1: previous monochrome set (2026-10-18)

Superseded by v2 above; the files stay in this folder.

Made in the site's current design system (`plea/launch-spec.md`, Website: imd.fun's tokens, dark theme default): IBM Plex Mono 600 (SIL OFL 1.1), ink `#fff` on paper `#000`, the `PLEA_` wordmark with its cursor, verdict stamps as outlined boxes rotated -3 degrees; no IMD diamond (the account must not read as an official IMD account).

| File | What |
|---|---|
| `pleaimd-C-stamp-1000.png` | Profile photo option C: PLEA as a verdict stamp (recommended to the user) |
| `pleaimd-B-wordmark-1000.png` | Profile photo option B: the `PLEA_` wordmark (the user asked for this one too) |
| `pleaimd-A-monogram-1000.png` | Option A: `P_` monogram (reads best at 32 px) |
| `pleaimd-avatar-preview.png` | A, B, C circle-cropped at 200/128/48/32 px on X dark and light |
| `pleaimd-header-1500x500.png` | X header: "buying is open. / selling needs a plea_", APPROVED `#3ecf7a` and DENIED `#ff6b62` stamps, background `#141414` so a black avatar keeps its circle in X's dark mode; the bottom-left corner left empty for the photo |
| `profile-mock-pleaimd-B-wordmark.png` | The header with the PLEA_ photo as X shows it |
| `plea-wordmark-white.png`, `plea-wordmark-black.png` | `PLEA_` on a transparent background, for dark and light backgrounds |

Bio drafted for X (154 characters): "buying is open. selling needs a plea_ / meme token on uniswap v4: 30 IMD oracle judges score every plea to sell. / mainnet soon. any PLEA there now isn't ours".

These follow the old monochrome system; if the site's new design system changes the style (e.g. neo-brutalism), redo them to match.
