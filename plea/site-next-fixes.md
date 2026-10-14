# PLEA site: fixes for the next version (testnet run 2 site job)

Collected 2026-10-11 from the live IMD site https://plea-make-your-case.sites.imd.fun/ (job d456a90e, source launch-1242 `web/` at e1a93f13).

## Must fix
1. **Verdict stamps all red.** `web/src/style.css` `.stamp` uses `--error` for every state; only `.stamp.gold` (Laureate) differs. Give each state its own colour, with tokens for light and dark themes and readable contrast:
   - Approved / Executed: green
   - Denied / Upheld: red
   - Pending: amber (with the 20-min countdown)
   - No verdict / Expired / Lapsed: neutral grey
   - Laureate: gold (as now)
   The stamp text carries the state too, so colour is never the only signal.
2. **sIMD decimals.** sIMD has 24 decimals; the profile showed the sIMD wallet balance ×1e6. `Stacker.stackedBy` is tIMD credited, not sIMD. Patch: `khaed1/plea-site` `source/simd-decimals.diff`.

## Polish
3. **Text too large overall.** Plea quotes use `--text-title` (1.5rem) in the display serif; on cards that's too big and makes cards very tall. Scale down: plea text on cards ~1.125rem (detail page can stay larger), display/heading sizes one step smaller, tighter card padding. Check 360 / 768 / 1280 px.
4. Profile: "This name is available to you" shows for the name the wallet already owns; say "This is your current name".
5. 360 px: the nav wraps to two rows (all visible); a single scrollable-free row with smaller items would save space.

## New in testnet run 2 (contracts)
- Season PLEA bonus: show "+ 5,000,000 PLEA bonus" per season for the first 4 seasons (shares per rank in PLEA next to the IMD prize), `Seasons.bonusBurned()`, `BonusPaid` / `BonusBurned` events on the Seasons page.
- Intake v2: a plea with no verdict is cleared automatically (`PleaFailed(id, status, reason, agreed, answered)`); show the reason and keep "Clear" (`expire`) only as the fallback after 20 min.
- New addresses from the run-2 launch; supply split 88 / 2 / 10.
- imd/acc #1294 Stacker has no per-trader `stackedBy`: show "Cashback earned" from `Stacked(project=hook, trader)` events (sum `imd`), or the sIMD balance.
- Stacker for run 2: `0x0457276d7b036818b3eddc1a4a3fceda61e9314d`.

## Claim page for the 12% (swarm 10% + airdrop 2%) — user, 2026-10-14
- `PleaDistributor.claim(index, account, amount, proof)` is permissionless and pays `account`: **anyone may claim for any address**, so a holder never has to connect or sign with the wallet that receives the PLEA. That is the "delegate" flow people ask for: paste the address, send the claim from any wallet (a burner that only pays gas), or let us push it.
- Page: an address box (any address; pre-filled from the connected wallet if one is connected) → "X PLEA claimable" / "claimed on <date>" / "not on the list", from a published `claims.json` (index, account, amount, proof per leaf; built by `plea/tools/distributor_root.py`, the same tree the owner set as the root) and `isClaimed(index)`; a **Claim** button that sends `claim(...)` from whatever wallet is connected (gas only, the PLEA goes to the typed address); a note that the root is set once and the list is final; the `Claimed(index, account, amount)` event as a receipt link.
- Fallback without the site: the runner pushes every claim from wallet A (482 claims on run 5/6's list at ~70k gas each); on mainnet a `claimMany` helper (loop over `claim`) saves the per-tx overhead if we do it ourselves. No contract change is needed for either.
- **Claiming for others (user, 2026-10-14):** `plea/tools/claim_for.py --claims root.json --distributor <addr> --rpc <url> --accounts a,b,c | --all [--send]` pushes the claims of chosen wallets (dry run by default; checks the on-chain root against the file and skips claimed leaves; the key from the environment, never printed). The dev can run it for the 2% wallets, we run it for everyone from wallet A. A `claimMany(index[], account[], amount[], proof[][])` helper contract (a loop over `claim`) only saves the per-tx base gas on mainnet; not needed for Sepolia.
- **delegate.xyz (user, 2026-10-14: "delegate the wallet provider"):** the v2 registry is live at `0x00000000000000447e69651d841bD8D104Bed493` on Sepolia and mainnet (same code). Site support needs no contract change: the connected hot wallet asks `getIncomingDelegations(hot)` for the vaults that delegated to it, the page shows each vault's claimable amount and sends `claim(index, vault, amount, proof)` from the hot wallet; the PLEA lands on the vault, which never connects. Contract-level support (tokens to the delegate instead of the vault: `claimFor` that checks `checkDelegateForContract(msg.sender, vault, distributor, "")` and pays `msg.sender`) would be a run-7 / mainnet change to PleaDistributor; only if people ask for the PLEA on the hot wallet.
