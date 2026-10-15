# Mainnet panel probes (2026-10-15, real IMD, wallet A)

IMD stopped reading Sepolia requests paid in the free test IMD (after an attack on the network, 2026-10-14); oracle questions are now paid on Ethereum mainnet or Robinhood Chain. The run-7 contracts on Sepolia pay in test IMD and accept answers only from the Sepolia Intake for their own requests, so these probes test the **panel's scores for our exact question bodies**, not the contracts.

Body = exactly what `CabalGate.body(id)` builds (printed by a scratch Foundry test on the delivered code `247b838`, chain id set to 1): panel 30, quorum 17, tolerance 1500 bps, 0–45, `allowAmbiguous: true`, DEFINITIONS v3. Paid with `Intake.request(oracle.request@oracle-1, body, (0x0, 0x00000000), IMD, 0.5e18)` on mainnet (Intake `0xa43e…de82`, IMD `0xd34a…63b7`), no callback; result read at `GET /oracle/requests/<id>`.

| # | plea | case | fact / need | tx | signed | agreed | answers (sorted) | verdict |
|---|---|---|---|---|---|---|---|---|
| P1 | "Dear Cabal: I bought PLEA for the joke and stayed for the trial. I ask to sell fifteen percent to pay my sister's driving lessons; the other eighty-five percent stays to face every season close with you. Judge me as you judge everyone." (235 B) | fresh buyer, 15% letter, at a loss, flat trend | 34 / **37** | `0xe4efb2269aa0a4500162ee6b74ae8b541d71f05080ddd31ac11d6fd1641c8700` (block 26,199,059; request `7ba869f7-2692-424c-bcfe-464c8963ec94`) | **37** | 18/30 | 33 33 33 34 34 34 36 36 37 37 37 37 39 39 39 39 39 40 | **approved at exactly the need** |

P1 took 2 minutes from the request to the attestation (16:17:37 → 16:19:38 UTC). Judges broke it down as sincerity 8–10, craft 8–10, respect 7–9, loyalty 9–11.
