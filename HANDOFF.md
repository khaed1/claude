# Handoff: PLEA + imd/acc (2026-10-09)

Repo `khaed1/claude`, branch **`claude/adoring-goodall-pn3jyz`**. Develop and push on this branch only.

## The two projects

**PLEA** is a relaunch of TokenWorks' CabalCoin (2025) through the IMD swarm. Buying is open to everyone. Selling needs a plea (up to 280 characters) approved by the IdentityMD oracle panel, "the Cabal": 30 judges, with 20 needing to agree.
- **Score:** 55 points come from facts the contract computes; the plea earns up to 45; 70 passes.
- **After a verdict:** an approval opens a 7-minute window to sell. A denial starts a 4h wait, with one appeal for 0.85 IMD.
- **Dead-man rule:** if there's no verdict for 48h, the Cabal dies and PLEA trades freely.
- **Token:** transfer-restricted. Holders can only send PLEA to the gate, which blocks selling through other pools.
- **Hook:** one hook, a fork of POOL4's `CappedBurnHook` converted to the IMD side. It is the only liquidity provider, its liquidity is locked forever, and it includes cap/trim burns and an IMD buy wall.
- **Fees:** 0.5% cashback to the trader as sIMD, 0.5% to the owner, 0.25% to pool liquidity, plus 0.25% of the PLEA burned.
- **Supply:** 90% into the pool, 10% to a swarm Merkle distributor.
- **Launch type:** IMD `evm_contracts` (smart contracts), **Sepolia first**.

**imd/acc** is trading cashback in staked IMD, inspired by TokenWorks' btc/acc. Participating projects send 0.5% of each trade, taken from their existing fees, to the trader as sIMD with `sIMD.deposit(amount, trader)`.
- No token in v1; points are tracked instead.
- The ETH-fee batch route (through POOL4) is planned for v2.
- The first projects are PLEA (Ethereum) and PondPad (Robinhood Chain, planned).

## Files to read
- `plea/launch-spec.md` is the full PLEA spec. Sections were appended over time: **later sections override earlier ones**. Read "Decisions after the first Check", "Oracle findings", "IMD dev answers" and "v2 design: smart-contracts launch" last.
- `plea/job-sepolia.md` is the current PLEA Sepolia job prompt (about 4,650 characters).
- `plea/job-1-launch.md` and `plea/job-2-website.md` are **outdated** v1 prompts (custom token with the IMD factory). Keep them only for the website design system and the full judge question and definitions text.
- `plea/cabal-2025-pleas.json` holds all 2,449 original CabalCoin pleas. The red-team examples come from it.
- `imd-acc/README.md` is the imd/acc spec. `imd-acc/index.html` is its page, published at https://claude.ai/artifact/J6ZsSLedCQsJ88o8pnsFTw; republish the same file path to update it.

## Key facts (verified)
- **Launch page limit:** the request, context and draft together must fit **8,000 characters**, so keep a prompt at or under about 5,000.
- **Intake** `0x1397434cd35e8a9c8ac312a61d3a285eb31dea56` (Ethereum and Robinhood Chain only). An oracle request costs 0.5 IMD. The callback selector is `0x510379c7` and gets 200k gas.
- **Oracle signer** `0x5598aa9146215bc13eb26f2c692ad1461fd32982`. The EIP-712 domain is "IdentityMD Oracle", version "2", with the consumer's chainId and contract.
- **`questionHash`** = `keccak256(canonical JSON {answerType, chainId, definitions, evidence, question, v, window:{fromBlock, toBlock}})`, with sorted keys, no spaces, and JavaScript `JSON.stringify` escaping.
- **A Sepolia consumer is accepted** by IMD (a quote validated). Sepolia has no Intake, so oracle requests are paid on mainnet by a relayer and delivered with `deliverVerdict`.
- **sIMD vault** `0x9efa934d9fad4ae28c998a40195646b965a97247` (Ethereum only): ERC-4626, owner renounced, not paused (checked 2026-10-09), with a one-block hold.
- **POOL4 hook** `0xc6c965bd164c483e87d0b550671798e9a3602840`. Its source can be read through `https://eth.blockscout.com/api/v2/smart-contracts/<addr>`. **IMD** on Ethereum: `0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7`.
- **IMD dev:** `custom_token` locks the fee at 1.25%, so use `evm_contracts` and pass our own hook. A major IMD upgrade is coming.
- **IMD docs:** https://imd.fun/docs/ · **API:** https://api.imd.fun (`/requests/capabilities`, `/requests/check`, `/skills`, `/oracle/requests/:id`).

## Rules
- **PondPad** (branch `claude/bold-gauss-qhlw86`) is **read-only**. Never commit PondPad code or internal details, only one-line public descriptions.
- The user makes the decisions. Explain simply, recommend one option, and don't change the agreed numbers without asking.
- Commit with clear messages and push to this branch.
