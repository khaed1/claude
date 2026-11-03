# IdentityMD (IMD) and enabling technology for a swarm-based privacy infrastructure (status as of 2026-11-03)

Research date: 3 November 2026. All IMD figures are point-in-time snapshots taken on that date unless another date is given. Part 1 relies mostly on IMD's own pages (imd.fun/docs, imd.fun/token, imd.fun/skill.md, explorer.imd.fun, GitHub Identity-md/*), Etherscan, and press (TokenPost, KuCoin, Bankless-derived coverage). Several IMD pages are JS-rendered or Cloudflare-gated, so a few items could not be read (noted in Gaps). Nothing below about IMD is invented; where a claim comes from a third party it is labelled.

---

## Part 1, Q1: What is IMD / IdentityMD, who runs it, history, token, roadmap

### Takeaway
IMD ("identity.md") is an Ethereum-based "network of AI agents that build, review and ship software, paid in IMD, with the record on Ethereum"; it was relaunched in May 2026 from the 2023 Base game token Fren Pet ($FP, later $VIBE), issued 2,000 free "identity.md" NFTs (one per wallet) that act as swarm "seats", and opened the agent network to NFT holders on 20 September 2026. The only named individual tied to it is "Adam" (@surfcoderepeat), Fren Pet's developer; the seat NFT contract was deployed by surfsurf.eth; no formal team, company, whitepaper, or roadmap document was found.

### Cited Findings
- Tagline on official docs: "A network of AI agents that build, review and ship software, paid in IMD, with the record on Ethereum." Workers run on the holder's own Claude Code or Codex plan; requirements: an IMD NFT, a little ETH for one registration transaction, a paid Claude plan, a supported OS. "Running a worker does not guarantee earnings." — [IMD Docs](https://imd.fun/docs/)
- Home page says only: "AI agents: imd.fun/skill.md says how to hire IMD or run a worker." Links: Explorer (explorer.imd.fun), Launch (explorer.imd.fun/launch), $IMD (/token/), Docs (/docs/), "IMD Agents app (Mac and Windows)" (/app/), Telegram (/telegram/). — [imd.fun](https://imd.fun)
- Token history per official token page: Aug 2023 "Fren Pet launched on Base as $FP"; May 2026 "Renamed $FP to $VIBE, then to $IMD. identity.md minted 2,000 free NFTs, one per wallet"; Sep 2026 bridge to Robinhood Chain opened and liquidity moved to Uniswap v4 (POOL4 hook live). — [IMD Token page](https://imd.fun/token/)
- KuCoin (Sep 29, 2026): Fren Pet launched Aug 2023 on Base "by developer Adam (@surfcoderepeat)"; bridged to Ethereum via LayerZero Oct 2025; renamed VIBE Jan 2026; relaunched as IMD May 2026 with free mint of 2,000 NFTs; staking contract ownership renounced mid-Sep 2026; "September 20, 2026: Agent network opened to NFT holders." The article "names no founding team"; project describes itself as "a zero-person company owned by token and NFT holders." — [KuCoin blog](https://www.kucoin.com/blog/ru-imd-token-community-owned-ai-agents)
- TokenPost (Sep 25, 2026, Simon Yoon): 2,000 identity.md NFTs each functioning as one swarm seat; holders must run the worker client and provide their own AI-model subscription; "The network remains experimental"; "The public documentation does not show recurring production work for outside protocols"; article names no operators or founders. — [TokenPost](https://www.tokenpost.com/news/technology/24260)
- Bankless (Sep 25, 2026) covered IMD as "A new kind of AI workforce ... replete with experimental tokenomics"; the article itself was Cloudflare-gated when fetched. — [Bankless on X](https://x.com/Bankless/status/2104546260195713113); [Bankless article (unreadable)](https://www.bankless.com/read/inside-imd-ethereum-s-new-ai-swarm-experiment)
- Odaily (summarising Bankless): "A lead orchestrator agent posts work to the network, after which seats can pick up tasks, then build, and then submit their results"; Bankless snapshot listed ~380 of 2,000 seats enrolled on Sep 25, 2026. — [Odaily](https://www.odaily.news/en/post/5213272)
- Seat NFT contract on Etherscan: contract name "IdentityMD", token tracker "identity.md (IDMD)", ERC-721 ABI, creator 0x047f606fd5b2baa5f5c6c4ab8958e45cb6b054b7 (ENS surfsurf.eth), created 2026-05-14 01:28:23 via CREATE2 factory, source verified (solc 0.8.26, cancun), "No Contract Security Audit Submitted", 7,813 txns as of Nov 3, 2026. — [Etherscan](https://etherscan.io/address/0x0000ec93127baa929e58e97dd0095a2bfb38ec1d)
- Worker release notes mention "the custody Safe's deployment, and a fork rehearsal that moves surfsurf.eth roles to it" (i.e. admin roles being moved from an EOA/ENS to a Safe). — [RELEASE_NOTES.md](https://raw.githubusercontent.com/Identity-md/worker/main/RELEASE_NOTES.md)
- Official X account: "Superintelligent Identity.md (@SuperIMD_eth)" (page returned HTTP 402 when fetched; content unread). — [X](https://x.com/superimd_eth)
- A separate Robinhood-Chain token "Identity.md 6900" (IMD6900) exists, created Oct 2026, whose stated design is a 10% trade fee feeding a pot that buys identity.md NFTs and relists them at 1.5x; third-party aggregator claims only. — [Phantom](https://phantom.com/tokens/robinhood/0xe3e3df8bfb891d269a78ee33a456d36fb7344ec1); [Blockspot](https://blockspot.io/coin/identitymd-6900-imd6900/)
- An IMD job brief (launch #2479) refers to an incident: "SIMD was a token on Ethereum (old supply 1,000,000,000) built on the Identity.md (IMD) ecosystem. On Oct 17 2026 the external developer who contr..." (truncated) and a "Robinhood loss ledger" that is "unverified." — [identity-md-launches/launch-2479](https://github.com/identity-md-launches/launch-2479-independent-tokenomics-review-choose)

### Inferences
- IMD is operated by a very small, pseudonymous team (the Fren Pet developer "Adam"/surfsurf.eth appears to control deployments) with a centralised backend ("control plane") and open-source-ish client; the "zero-person company" framing is marketing, not a legal/organisational fact.
- The project is only ~6 weeks into live operation (network opened Sep 20, 2026), so stability, policies and contracts are likely to change.

### Gaps
- No whitepaper, litepaper, formal roadmap, legal entity, or named founding team was found anywhere (official site, docs, press). The X account and Bankless article could not be read (402/Cloudflare).
- The "GitHub: Identity-md/worker" repo is a release mirror; "Backend source and service credentials are not distributed" (README), so backend logic is not publicly auditable.

---

## Part 1, Q2: NFT collection, contracts, "Register my agent" transaction, ERC-8004 binding

### Takeaway
The seat NFT is the ERC-721 "identity.md (IDMD)" collection at 0x0000ec93127baa929e58e97dd0095a2bfb38ec1d on Ethereum mainnet (1,999–2,000 items, ~790 owners); "Register my agent" is a mainnet transaction that registers the seat as an agent in the canonical ERC-8004 Identity Registry (0x8004a169fb4a3325136eb29fa0ceb6d2e539a432, not deployed by IMD), after which pairing binds the token to a device key.

### Cited Findings
- Official docs: "The IMD NFT, the seat contract that workers pair to, is 0x0000ec93127baa929e58e97dd0095a2bfb38ec1d on Ethereum." "Ethereum IdentityRegistry: 0x8004a169fb4a3325136eb29fa0ceb6d2e539a432. ReputationRegistry: 0x8004baa17c55a88189ae136b182e5fda19de9b63. Neither is deployed by IMD." A seat is "bound to an ERC-8004 agent"; `/agents/register-intent` returns the calldata for the registration transaction. — [IMD Docs](https://imd.fun/docs/)
- Other official addresses: IMD token Ethereum 0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7; IMD on Robinhood Chain 0x5f7bb59365ce557c26dbcaa4ee9d39a4b95b7127; imdTEST (Sepolia) 0x56bcf2a5f47710649a4091219ef0b56e2d1b58bf; Intake v2 (all chains) 0xa43e6f75ee006411f79ac1c84120606c2330de82; Intake v1 0x1397434cd35e8a9c8ac312a61d3a285eb31dea56; IntakeDelivery v1 0xce0e6a670aa75e161d02aca3c7f00b94ca428ccb. A "WorkRegistry holds append-only receipts and reviews on Ethereum" (address not shown in the readable text). — [IMD Docs](https://imd.fun/docs/)
- Worker README: "Pairing uses the wallet that owns an eligible IdentityMD NFT, which must be registered as an ERC-8004 agent. An unregistered token cannot take work." "One NFT authorizes one active device. Independent reviewers must use different wallets." The pairing page checks for an existing registration before offering the wallet transaction. — [Identity-md/worker README](https://github.com/Identity-md/worker)
- Official docs flow: "the worker prints a link, you connect the wallet that holds the NFT and sign, then you send one transaction to register the agent." — [IMD Docs](https://imd.fun/docs/)
- VPS manual: requires "An eligible IMD NFT in a browser wallet, plus some Ethereum mainnet ETH for registration gas if the NFT isn't registered yet"; pairing via `imd pair` and approval at api.imd.fun/pair. — [imd-worker-vps-manual](https://github.com/identitynode40/imd-worker-vps-manual)
- Third-party writeup (snapshot 24 Sep 2026): seat holders "own ERC-8004 NFT seats, identified by tokenId"; pairing is `POST /pair/start` then `POST /pair/complete` with an EIP-712 `WorkerAuthorization` signature; `POST /agents/bind` also wallet-EIP-712; device writes (`POST /bundles`, `POST /artifacts`) use Ed25519 signatures from the paired device key; the daemon claims jobs over `wss://api.imd.fun/agent`; lists "Seat collection (ERC-8004): 0x0000ec93127baa929e58e97dd0095a2bfb38ec1d". — [mtezy/imd-writeup](https://github.com/mtezy/imd-writeup)
- Desktop app: wallet "signs once, in your browser" at explorer.imd.fun/link; the app creates a P-256 key in the OS credential store that signs only pause/resume/unlink; "No wallet keys, ever"; "A seat runs on one machine at a time. Pairing it locally moves it off other machines." — [Identity-md/desktop](https://github.com/Identity-md/desktop)
- ERC-8004 explorers list IMD seats as ERC-8004 agents on Ethereum, e.g. "IdentityMD #1584" = agent 51379, "IdentityMD #202" = agent 52100, "IdentityMD #1042" = agent 51487 (pages were JS-only when fetched; titles only). — [8004agents.ai agent 51379](https://8004agents.ai/ethereum/agent/51379); [agent 52100](https://8004agents.ai/ethereum/agent/52100)
- OpenSea collection "identitymd": 1,999 items, 792 owners, floor 0.796 ETH on Nov 3, 2026. — [OpenSea](https://opensea.io/collection/identitymd). KuCoin reported a floor around 1.99 ETH and ~780 unique owners in late Sep 2026. — [KuCoin](https://www.kucoin.com/blog/ru-imd-token-community-owned-ai-agents)
- ERC-8004 spec: Identity Registry is ERC-721 (URIStorage); agentId is the tokenId; `agentWallet` metadata key reserved for payments, requires EIP-712/ERC-1271 signature to set and is cleared on transfer. — [EIP-8004](https://eips.ethereum.org/EIPS/eip-8004)

### Inferences
- Because the seat NFT and the ERC-8004 agent are separate ERC-721s (IMD collection vs. canonical Identity Registry), "Register my agent" most likely mints an ERC-8004 agent token whose metadata/URI references the IMD seat tokenId; the exact calldata is only obtainable from the `/agents/register-intent` endpoint. This linkage (NFT seat -> ERC-8004 agentId -> Ed25519 device key) is the "on-chain identified worker" primitive a privacy project could reuse.
- Any sybil resistance derives from seat scarcity (2,000 seats) and the cost of a seat (~0.8–2 ETH on secondary market), not from ERC-8004 itself.

### Gaps
- Exact ERC-8004 registration calldata, the agentURI/registration-file content for an IMD seat, and the WorkRegistry contract address could not be read (JS-rendered explorer pages, docs text beyond 157k chars not fully parsed).
- No Etherscan-verified "registry transaction" example was captured.

---

## Part 1, Q3: Tiers, task types, skills, routing, verification, oracle

### Takeaway
Worker config has three inference tiers (economy/standard/premium) that map to model/effort requirements rather than to pay grades; premium (contract and frontend work) requires Claude Fable 5.1 (high+) / Opus 5.5 (medium+) or GPT-6 Astra (high+) / GPT-6.1 Sol (medium+). Verification is centralised: a "verifier" service (judge types `verifier-rerun`, `verifier-paths`) checks results before they are recorded on-chain, audits use a 4-specialist + judge panel, peer reviews use ~5 agents, and oracle answers require unanimous panel agreement signed via EIP-712.

### Cited Findings
- Tiers: "Inference config has three tiers: economy, standard, and premium. Each can set a Codex model and effort." "A premium entry that doesn't meet its model requirements disables that capability." — [imd-worker-vps-manual](https://github.com/identitynode40/imd-worker-vps-manual)
- Premium model requirements: "Contract and frontend work requires an approved premium model: Claude Fable 5.1 (high effort or above) or Opus 5.5 (medium or above) on Claude Code, or GPT-6 Astra (high or above) or GPT-6.1 Sol (medium or above) on Codex 0.154+." Other tasks can use Claude Sonnet 5 low effort or GPT-6 Luna high effort. Requires Node 22+, Claude Code 2.1.295+. — [worker README](https://raw.githubusercontent.com/Identity-md/worker/main/README.md)
- Work categories: contract builds, tests and audits; websites; images; video and audio; research, oracle and other tasks. Job templates: `single`, `impl_tests`, `audit`, `fuzz`, `research`. Job shapes: `chain`, `fan_out_join`, `dag`. Skills named: `build-contract-project`, `adversarial-review`, `build-website`, `create-image`, `research-report`. — [IMD Docs](https://imd.fun/docs/)
- skill.md "skill types": build-website, research-report, create-image, create-audio, create-video, repo audit, EVM contracts, EVM token project, Uniswap v4 hook launch, workflow, job continuation, oracle request, oracle group, schedule. — [imd.fun/skill.md](https://imd.fun/skill.md)
- Third-party writeup: "The 30 fixed skills each use a judge: verifier-rerun, verifier-paths, or none (for reference skills)"; internal roles: verifier, publisher, deployer services; accepted output goes to a GitHub repo, IPFS site, ENS name, or on-chain deployment; protocol version 1. — [mtezy/imd-writeup](https://github.com/mtezy/imd-writeup)
- Routing/verification (official): "Work goes to the machine that ranks best on tools, load, recent failures, and time since its last similar task. Audits and security work go to Claude first." "Nobody reviews their own work. Three failures in a row pause a machine for 15 minutes." Contract work uses 30-day probation: two bad results out of last three drops the machine to the back of the line for 24 h. "A verifier checks each result before it goes onchain under the agent." Audits "use four specialists (math, permissions, economics, control flow) and a judge who merges and ranks their findings." — [IMD Docs](https://imd.fun/docs/)
- Explorer shows audit/review jobs "reviewed by 5 agents" with severity tallies (e.g. "1 high, 1 medium, 3 low, 4 info"); a "design critic"; a preflight gas check (a launch failed needing 102,074,935 gas vs cap 99,902,344 = half block gas limit). — [explorer.imd.fun](https://explorer.imd.fun/)
- Fuzz campaigns: `GET /jobs/:id/fuzz` returns campaign state, runs, confirmed count, results; devices sign `fuzz.result` with outcome `counterexample`, `exhausted`, or `failed`. Foundry is required for contract work. — [IMD Docs](https://imd.fun/docs/); [worker README](https://github.com/Identity-md/worker)
- Media tools: `create-image/video/audio` need a locally declared MCP-style tool (`imd tools add`); keys stay in `~/.identitymd/tools.env`; video needs ffmpeg; accepted media pinned to IPFS with a `MEDIA.md` index. — [worker README](https://raw.githubusercontent.com/Identity-md/worker/main/README.md)
- Sandboxing: "Oracle, research, and contract-build tasks run in a read jail ... Other tasks are not jailed"; Linux runtimes sandbox commands with bubblewrap; desktop app runs the worker in "IMD Box" (Docker; nothing mounted from host; firewall; capabilities dropped). — [worker README](https://raw.githubusercontent.com/Identity-md/worker/main/README.md); [Identity-md/desktop](https://github.com/Identity-md/desktop)
- Oracle: "You pose a typed question. A panel of agents answers it, and the answer is signed in EIP-712 for your contract. Every panel member must match for the quorum to be met ... If the panel disagrees, there is no answer." Answer types bool..bytes32[]; chain-evidence recipes `log-sum`, `log-count`, `log-rank`, `call-compare`, `v4-volume-rank`, `univ4-spot`; "The deployer reruns the agreed recipe at the pinned blocks before signing"; reads wait 3 blocks on Ethereum; oracle work recorded once per UTC day as a Merkle root; attestation endpoint `/oracle/requests/:id/attestation`. — [IMD Docs](https://imd.fun/docs/); [mtezy/imd-writeup](https://github.com/mtezy/imd-writeup)
- Subagents: "Some skills use read-only subagents on Claude Code. --subagents sets the count (0 to 4)." Own RPC: `imd rpc add <chain>` serves RPC locally; "Tasks never see the URL." — [worker README](https://github.com/Identity-md/worker)
- Open issues analysed by a third party: #5 own-RPC relay splitting wide `eth_getLogs`; #6 review-node dependency `clone_failed`; #1 Codex on Windows workspace writes; #4 "promise" assurance kind for launches; #2 ACP runtime; patches target worker 0.1.2+cf06456a; repo "generated from a private source." — [RobertKodes/imd-worker-fixes](https://github.com/RobertKodes/imd-worker-fixes)
- Latest worker version in RELEASE_NOTES: 0.1.11+27f56808; adds "keeper.claim and keeper.result envelopes." — [RELEASE_NOTES.md](https://raw.githubusercontent.com/Identity-md/worker/main/RELEASE_NOTES.md)

### Inferences
- "Consensus among agents" exists only in the oracle path (unanimous panel) and in multi-reviewer audits; code deliverables are gated by a centrally operated verifier that re-runs tests/checks paths. The network is therefore trust-the-operator for verification today, not trustless.
- The oracle's EIP-712 signed answers plus `agreed >= quorum` check are the closest existing primitive to an "attestation by a swarm" that a contract can consume; a privacy project could model association-set or proof-of-innocence attestations on this pattern.
- Tiers are capability gates (which model you run), not economic tiers; there is no evidence of differential pay per tier.

### Gaps
- No full enumerated list of the "30 fixed skills" was found (the README lists only examples; the explorer/docs pages are JS-rendered).
- Internals of `verifier-rerun`/`verifier-paths`, reviewer selection, and the reputation score formula are not documented publicly.
- No evidence of any privacy feature or privacy stance from IMD (no mention of privacy, encrypted tasks, or private delivery anywhere in the fetched docs; "Job briefs are public and visible to builders").

---

## Part 1, Q4: Payments, token, marketplace economics, rewards to workers, explorer stats

### Takeaway
Hiring the swarm costs a flat 0.5 IMD per request (job/launch/workflow/oracle question), paid by x402 + Permit2 on Ethereum mainnet or Robinhood Chain; IMD is a 10M fixed-supply (now ~7.1M) deflationary token with Uniswap v4 "POOL4" burn hook and sIMD staking; worker rewards are not a per-task wage but come from (a) a 10% "swarm share" of every token launched through IMD (claimed from a Merkle distributor) and (b) 4.5% of POOL4 "trims" to NFT-holding node operators. On Nov 3, 2026 the explorer showed 1,136 registered agents, ~913–921 online, 8 working, 6,570 jobs total.

### Cited Findings
- "Each request costs 0.5 IMD. Actions include job.open, launch.open, workflow.open, oracle.request, and schedules. Payment is by x402 with Permit2 through the web app, the API, or the Intake contract onchain." — [IMD Docs](https://imd.fun/docs/)
- Flow: `POST /requests/quote`, then `POST /requests/:id/submit` (x402 challenge, Permit2 payment, EIP-712 quote approval), poll `GET /requests/:id` until `admitted`; "The server wallet pays gas"; quotes expire after 10 minutes; rate limits 120 req/min, 10 quotes/min; observed errors include `payment_permission_expired` (7 of 38 payments) and 86 expired quotes. — [mtezy/imd-writeup](https://github.com/mtezy/imd-writeup); [imd.fun/skill.md](https://imd.fun/skill.md)
- Token: "10M minted in 2023, with none minted since"; split across Ethereum, Base, Robinhood Chain bridged 1:1; "The supply only goes down"; every sell burns; staking IMD -> sIMD, "no lock and no claim"; "0.5 IMD buys a job, a launch, or an oracle question"; "Buying a seat (2,000 seats available) lets you run an agent." — [IMD Token page](https://imd.fun/token/)
- POOL4 trim split per 100 IMD trimmed: 85 burned, 6 to orchestrator compute reserve, 4.5 to sIMD stakers, 4.5 to NFT-holding node operators; cap decreases ~1,000 IMD/day; circulating ~7.1M; ~2.3M IMD staked (~32%) around Sep 25, 2026; sIMD is ERC-4626; market cap briefly >$39M on Sep 26, 2026 (Bankless all-chain snapshot ~$69M); "unaudited and experimental." — [KuCoin](https://www.kucoin.com/blog/ru-imd-token-community-owned-ai-agents); TokenPost confirms "CappedBurnHook burns 85% of tokens trimmed above the pool's cap." — [TokenPost](https://www.tokenpost.com/news/technology/24260)
- Launches: fixed supply 1,000,000,000 (18 decimals); "The swarm takes 10% of the supply. Swarm share is claimed from a Merkle distributor: 2% split among wallets with accepted work, and 8% split among seats connected at admission." Pool trading fee 1.25% (1% to paying wallet, 0.25% to network). Launch kinds `univ4_hook`, `evm_project`, `custom_token`, `evm_contracts`; chains Sepolia (default), Ethereum mainnet, Robinhood Chain; "The launch deployer wallet is the only wallet either factory accepts launches from." — [IMD Docs](https://imd.fun/docs/)
- Earnings API: `GET /wallets/:address/earnings` pages a wallet's earnings by launch number; a launch's `rewardSnapshot` with `claims=1` returns a frozen reward tree whose proofs a wallet sends to the launch's distributor. Desktop app shows "rewards, with a Claim action." — [IMD Docs](https://imd.fun/docs/); [Identity-md/desktop](https://github.com/Identity-md/desktop)
- Explorer stats (Nov 3, 2026): "Agents 1,136"; "921 online"; "8 working"; "1.9K steps in 24h"; totals 6,570 jobs (207 companies, 6,363 parts), 9,012 oracle entries, 692 tokens; "Today: 51 jobs finished, 1 failed, 3 running." Agent cards show accepted jobs, acceptance rate, hours, holder; "Agents build their reputation onchain, one accepted job at a time." Top agents: #760 3,655 accepted/99%; #446 3,633/98%; #312 3,506/99%; several seats (e.g. 0x6d2f…be9e) hold ~10 agents. — [explorer.imd.fun/agents](https://explorer.imd.fun/agents); [explorer.imd.fun](https://explorer.imd.fun/)
- Late-Sep 2026 metrics (KuCoin): >370 agents active within five days; ~43,800 accepted submissions, ~86% acceptance; ~17.3B inference tokens; "Largely limited to Sepolia testnet; mainnet is described as forthcoming." — [KuCoin](https://www.kucoin.com/blog/ru-imd-token-community-owned-ai-agents)
- Job briefs are public; "Payments are non-refundable and don't guarantee results." — [imd.fun/skill.md](https://imd.fun/skill.md)
- Explorer job sample shows mostly small web apps/games (Squeek* series), audits, Sepolia deployments, research mapping ("Map humanoid robot companies: built by about 290 agents"), trading indicator tuning, logos. — [explorer.imd.fun](https://explorer.imd.fun/)

### Inferences
- The economic model is launchpad-centric: IMD earns from token launches (10% swarm share + 0.25% pool fee) more than from the 0.5 IMD request fee; a privacy project built "on top of IMD" would be a *customer* (paying 0.5 IMD per request) or would need to repurpose the seat/agent identity layer rather than the payment rail.
- Agent count tripled from ~380 (Sep 25) to 1,136 (Nov 3) in ~5 weeks; roughly 80% online at any time, but only ~0.7% "working" at the snapshot, i.e. the swarm has large idle capacity.

### Gaps
- No per-task payout rate to workers is published; the 4.5% node-operator share's distribution formula is undocumented.
- "Reputation" is displayed (accepted count, rate) but whether/what is written to the ERC-8004 Reputation Registry could not be verified (explorer pages are JS-only).
- No security audit of IMD contracts (Etherscan "No Contract Security Audit Submitted"; press: "unaudited").

---

## Part 2, Q1: Agent identity standards (ERC-8004, x402, ERC-7857, Olas, Virtuals, Fetch.ai) and NFT-bound identity for sybil resistance

### Takeaway
ERC-8004 (Draft; registries live on Ethereum mainnet since Jan 29, 2026, with hundreds of thousands to >1M registrations by Oct 2026 but only 3–15% exposing working services) is the de-facto agent identity layer; it explicitly says "Sybil attacks are possible" and leaves validation/slashing to external protocols, so sybil resistance must come from a scarce, costly NFT (as IMD does) plus staking/attestation.

### Cited Findings
- ERC-8004 "Trustless Agents": Draft, Standards Track; authors Marco De Rossi, Davide Crapis, Jordan Ellis, Erik Reppel; created 2025-08-13; requires EIP-155/712/721/1271; three per-chain singleton registries (Identity = ERC-721 URIStorage; Reputation with `giveFeedback()` int128 value, tags, revoke/appendResponse; Validation with `validationRequest()`/`validationResponse()` score 0–100, updatable for progressive finality). Validation methods named but not implemented: "stake-secured re-execution, zkML verifiers, TEE oracles, and trusted judges. Incentives and slashing are left to the specific validation protocol." Registration file requires `type`, `name`, `description`, `image`, `services` (A2A, MCP, OASF, ENS, DID, email), `x402Support`, `active`, `registrations`; optional `supportedTrust`. "Sybil attacks are possible ... It expects reputation systems to emerge that filter or weight reviewers." Feedback submitter cannot be the agent owner/operator. — [EIP-8004](https://eips.ethereum.org/EIPS/eip-8004)
- Mainnet deployment of the core registries on Jan 29, 2026 (Forbes). — [Forbes](https://www.forbes.com/sites/digital-assets/2026/02/05/ai-agents-gain-trust-via-ethereum-erc-8004-on-mainnet/); pre-launch coverage [The Block](https://www.theblock.co/news/ecosystems/2026-01-28-ethereum-ai-agentic-economy-mainnet-387345)
- Adoption counts conflict: 8004scan counted 519,333 agents across 30 networks on Sep 18, 2026, but "research found only 3% to 15% expose working services"; one source claims 1,333,878 agents across 24 chains on Oct 23, 2026 (uncorroborated). Standard still Draft as of Oct 6, 2026. — [Datawallet](https://www.datawallet.com/crypto/erc-8004-explained); [awesome-erc8004](https://github.com/sudeepb02/awesome-erc8004)
- Validation Registry maturity: "the stricter tier for stake, zkML and TEE checks has no canonical mainnet deployment"; maintainers say a follow-up spec will revise it. — [Datawallet](https://www.datawallet.com/crypto/erc-8004-explained)
- Empirical study "Can Trustless Agents Be Trusted? An Empirical Study of the ERC-8004 Decentralized AI Agent Ecosystem" (arXiv 2606.26028). — [arXiv](https://arxiv.org/pdf/2606.26028)
- Phala ships an "ERC-8004 Compliant TEE Agent with a TEE Registry Extension" running in a CVM (Intel TDX via dstack) on Phala Cloud. — [Phala-Network/erc-8004-tee-agent](https://github.com/Phala-Network/erc-8004-tee-agent)
- x402: HTTP-402-based settlement rail; Linux Foundation "x402 Foundation" announced Apr 2, 2026; CoinDesk (Mar 2026) daily x402 volume ~$28k; it "does not resolve which human or company authorized the paying agent." Security analysis: "Free-Riding the Agentic Web: A Systematic Security Analysis of x402 Payments" (arXiv 2605.30998). — [Tobira](https://blog.tobira.ai/ai-agent-payments-identity-gap/); [agentlux](https://agentlux.ai/blog/the-agent-payment-stack-in-2026-x402-ap2-and-the-race-to-pay-agents); [arXiv](https://arxiv.org/pdf/2605.30998). IMD uses x402 + Permit2 for its 0.5 IMD fee. — [IMD Docs](https://imd.fun/docs/)
- ERC-7857 (0G Labs "iNFT"): extends ERC-721 with encrypted metadata and continuous metadata updates; "under review" as an EIP; AIverse marketplace launched Mar 2026 on 0G mainnet. — [0G blog](https://0g.ai/blog/0g-introducing-erc-7857); [BlockEden](https://blockeden.xyz/blog/2026/03/14/erc-7857-0g-aiverse-web4-marketplace-ai-agents-ownable-tradeable-infts/)
- Olas: 9M+ agent-to-agent transactions, 600+ daily active agents, 9 chains by Q3 2025 (Cobo). Virtuals and Fetch.ai only get passing mentions in 2026 sources. — [Cobo](https://www.cobo.com/post/agentic-ai-crypto-strategies-2026)
- Bankless podcast with Austin Griffith and Davide Crapis "AI on Ethereum: ERC-8004, x402, OpenClaw and the Botconomy" (context on the ecosystem). — [Pocket Casts](https://pocketcasts.com/podcast/bankless/3a2c0740-35e1-0138-9706-0acc26574db2/ai-on-ethereum-erc-8004-x402-openclaw-and-the-botconomy-austin-griffith-davide-crapis/4d3ca71d-1f4e-4653-9451-400e906c0804)

### Inferences
- For a relayer/prover set, "one IMD seat = one ERC-8004 agentId = one Ed25519 device key" gives a ready-made, costly-to-forge identity: sybil cost ≈ seat price (0.8–2 ETH) + a Claude/Codex subscription; this is far stronger than bare ERC-8004 registration (free) but weaker than stake that can be slashed.
- ERC-8004's `agentWallet` (signature-gated, cleared on transfer) and Reputation Registry can be used to pay and rate relayers without IMD's backend, but any on-chain feedback leaks relayer-client links, so reputation must be designed carefully for a privacy system.

### Gaps
- No source quantified ERC-8004 registrations specifically on Ethereum mainnet (vs all chains) in Oct/Nov 2026.
- No 2026-dated primary sources on Virtuals or Fetch.ai identity features were found.

---

## Part 2, Q2: Decentralised relayer/broadcaster networks (Railgun, Tornado registry, 4337 bundlers, Gelato) and permissionless rotation

### Takeaway
Existing designs are: Railgun broadcasters (fee discovery and encrypted tx hand-off over Waku; broadcaster sees only its fee; user picks lowest fee; swap if refused), Tornado's TORN-staked relayer registry with frontend-side weighted random selection, and ERC-4337's alt-mempool bundlers (P2P mempool still maturing). None uses on-chain VRF/commit-reveal for relayer selection; selection is client-side.

### Cited Findings
- Railgun: broadcasters are independent nodes that submit transactions for users and pay gas; "Broadcasters communicate with clients via the Waku decentralized messaging protocol"; "Transactions are encrypted, and the relayer can read only the fee packaged for its service"; premiums "published over the Waku network"; client "waits for relayers to broadcast fees, and selects the lowest-fee relayer"; relayers can be swapped if one refuses; protocol fee 0.25% on shield/unshield to treasury; relayer fees off-chain. — [Railgun community relayers docs](https://docs.railgun.org/wiki/learn/privacy-system/community-relayers); [waku-relayer-client npm](https://www.npmjs.com/package/@railgun-community/waku-relayer-client); [L2BEAT Railgun](https://l2beat.com/privacy/projects/railgun)
- Railgun moved traffic to its own Waku subtopic and noted "an ERC-4337 model would give more predictable broadcaster behavior." — [Railgun Medium update](https://medium.com/@Railgun_Project/refactors-relayers-and-reliability-railgun-update-b78b84364a40)
- Railgun handles ~71% of mixer transaction volume (2026 report); Feb 2026: ZachXBT traced a Bittensor hacker through Railgun, which Vitalik cited as the screening working as intended. — [NewsBTC](https://www.newsbtc.com/altcoin/crypto-mixing-is-back-and-criminals-adapted-faster-than-the-rules-did); [Cambridge JBS](https://www.jbs.cam.ac.uk/2026/crypto-privacy-after-sanctions-the-return-of-coin-mixers/)
- Tornado Cash relayer registry: TORN holders govern the registry; relayers lock TORN (docs cite 300 TORN originally; later 2000 TORN to lock, 0.3% registry fee per withdrawal, 500 TORN minimum to stay active); "the UI randomly picks a relayer, weighted by its calculated score"; L2BEAT: removing relayers from the registry hides them from the app but "the pools still accept any relayer." — [Tornado staking docs](https://tornado-cash-2.gitbook.io/docs/general/staking); [How to become a relayer](https://tornado-cash-2.gitbook.io/docs/general/how-to-become-a-relayer); [L2BEAT Tornado](https://l2beat.com/privacy/projects/tornado-cash)
- ERC-4337: bundlers gossip UserOperations on a separate alt-mempool; the canonical mempool sees only `handleOps`; staged decentralisation framework (Stage 0 independent -> Stage 3 fully permissionless mempool); Candide's Voltaire P2P routes ops to Etherspot Skandha and Silus; no source states the stage reached in 2026. Commentary claims dominant bundlers (Pimlico, Stackup) run at a loss. — [Unified mempool (Yoav)](https://notes.ethereum.org/@yoav/unified-erc-4337-mempool); [ERC-4337 mempool stages](https://erc4337.substack.com/p/erc-4337-mempool-stages-a-framework); [Candide](https://docs.candide.dev/blog/bundler-mempool-now-live/); [Chainscore opinion](https://www.chainscorelabs.com/blog/wallet-wars-smart-accounts-vs-embedded-wallets/smart-account-standards-governance/why-erc-4337s-success-hinges-on-solving-the-bundler-incentive-problem)
- 4337 gas accounting: `verificationGasLimit` meters validation (where a SNARK check would sit); `preVerificationGas` is charged as reported by the bundler and not refunded; Stackup decomposes it into batch share + batch variable + per-op overhead. — [ERC-4337 spec](https://github.com/ethereum/ercs/blob/master/ERCS/erc-4337.md); [Alchemy gas estimation](https://alchemy.com/blog/erc-4337-gas-estimation); [Stackup preVerificationGas](https://www.stackup.fi/resources/an-analysis-of-preverificationgas)
- Waku RLN: publishers register on-chain and attach a membership proof to each message; relays verify before forwarding; current network limit 1 msg/s per publisher with 20 s grace; Waku is being rebranded under Logos Messaging; RLN v2 membership contract (register/extend/erase/withdraw); Linea hinted as the chain but not confirmed. — [Waku network](https://waku.org/about/waku-network/); [RLN relay paper](https://arxiv.org/abs/2207.00117); [Logos RLN](https://research.logos.co/rln); [RLN v2 contract spec](https://github.aipraa306.workers.dev/waku-org/specs/blob/master/standards/core/rln-contract.md)

### Inferences
- A swarm of IMD-identified agents could run Railgun-style broadcasters: fee quotes over Waku, encrypted tx payload, fee paid inside the shielded pool; the seat NFT/ERC-8004 id replaces Tornado's TORN stake as the admission credential, and the IMD oracle/probation pattern (three failures -> pause) could be mirrored on-chain for rotation.
- Relayer selection via VRF/commit-reveal was not found in any production privacy relayer; client-side random weighted choice is the norm, so this would be novel work.

### Gaps
- No 2026 count of active Railgun broadcasters or Tornado relayers was found.
- No source on Gelato's relayer specifically in a privacy context, and no measured total gas of a 4337 userOp with a SNARK verifier.

---

## Part 2, Q3: Decentralised and private proving (SP1 network, Boundless, coSNARKs/MPC, TEE proving)

### Takeaway
Public prover markets (Succinct SP1 network, Boundless) are live on mainnet with Ethereum-block proofs costing on the order of $0.01–0.04 in late 2025/2026, but a plain delegated proof exposes the witness to the prover; witness-hiding delegation exists via (a) MPC/collaborative SNARKs (Ozdemir–Boneh 2022, zkSaaS 2023, TACEO coSNARKs, TACEO:Proof in production with 3-party honest-majority) and (b) TEE proving (Succinct "Private Proving" on Phala Cloud with Intel TDX + confidential H200 GPUs, enterprise private beta).

### Cited Findings
- Succinct prover network: proofs paid in PROVE from a deposited requester balance; example request shows base fee 0.2 PROVE and max 2.0 PROVE per bPGU, auction strategy with 300 s timeout, optional prover whitelist; `NetworkMode::Mainnet`. — [Succinct quickstart](https://docs.succinct.xyz/docs/sp1/prover-network/quickstart); [network architecture + PROVE](https://blog.succinct.xyz/network/introducing-the-succinct-network-architecture-and-the-prove-token/)
- Succinct TEE Private Proving: requests go to a TEE app at tee.sp1-lumiere.xyz; "encrypted proof inputs" kept from third parties "including Succinct"; "currently powered by the Phala Cloud solution"; Zero-Trust TLS and dstack-verifier for attestation; "private beta ... only available through the Enterprise offering"; SDK: add `.private()`. Succinct's blog says Private Proving "is live and ready for production applications" (conflict on availability). Phala: NVIDIA H200 confidential computing + Intel TDX; "no one, not even the prover, can see the witness." Separate SP1-2FA uses AWS Nitro for verification, not privacy. — [Succinct private proving docs](https://docs.succinct.xyz/docs/sp1/prover-network/private-proving); [Succinct blog](https://blog.succinct.xyz/private-proving/); [Phala post](https://phala.com/posts/private-proving-succinct-sets-new-standard-for-zk-privacy-with-phala-cloud)
- Boundless (RISC Zero): mainnet activated Sep 15, 2025; Proof of Verifiable Work rewards in ZKC; provers stake ZKC (>=10x max request fee per an older analysis); RISC Zero terminated its hosted proof service Dec 2025 forcing all proving through Boundless; no public requester price schedule found; one snapshot 542.7T cycles, 399K orders; ZKC ~$0.03–0.04 (Aug–Oct 2026). — [crypto.news](https://crypto.news/boundless-mainnet-launches-with-vision-of-internet-scale-for-blockchains/); [BlockEden](https://blockeden.xyz/blog/2026/01/14/boundless-risc-zero-decentralized-proof-market-zk/); [h33](https://h33.ai/blog/zk-companies/)
- Per-proof cost: ~$0.04 per Ethereum block proof averaged across the Ethproofs leaderboard by late 2025 (down 45x in a year); ~$0.02 best case on 16x RTX 5090; Axiom OpenVM 2.0 Beta claims 4.4 s avg and $0.01 per block on 16x 5090 (vendor); SP1 Hypercube proves 99.7% of blocks <12 s on 16x 5090; EF target: 99% of blocks in <10 s on ~$100k/10 kW hardware; 128-bit security + <=300 kB proofs by end-2026. — [BlockEden Cysic](https://blockeden.xyz/blog/2026/04/17/cysic-venus-multi-gpu-zk-proving-real-time-verification-bottleneck/); [Axiom OpenVM 2.0](https://axiom.xyz/blog/openvm-2-beta); [CryptoSlate EF 128-bit](https://cryptoslate.com/ethereum-foundation-refocuses-to-security-over-speed-sets-strict-128-bit-rule-for-2026/); RISC Zero vs Succinct cost claims disputed — [Rumble Fish](https://www.rumblefish.dev/blog/post/top-zkp-2026/)
- Collaborative zk-SNARKs: Ozdemir & Boneh, USENIX Security 2022, "proofs over the secrets of multiple, mutually distrusting parties"; MPC-friendly Groth16/Plonk/Marlin/Fractal; near single-prover runtime with malicious-minority over 3 Gb/s link. — [ePrint 2021/1530](https://eprint.iacr.org/2021/1530); [USENIX](https://www.usenix.org/conference/usenixsecurity22/presentation/ozdemir)
- zkSaaS (Garg et al., USENIX Sec 2023): "a client delegates proof computation to a group of untrusted servers in a privacy preserving manner" (Groth16, Plonk PoC). Scalable collaborative zk-SNARK (Liu et al., ePrint 2024/143, USENIX Sec 2025) lifts Libra to fully distributed proving. — [ePrint 2024/143](https://eprint.iacr.org/2024/143.pdf); [NUS feature](https://www.comp.nus.edu.sg/features/zero-knowledge-proofs)
- TACEO: coCircom (Groth16, "performance comparable to snarkJS"), coNoir (ACIR, Barretenberg-compatible); TACEO:Proof delegated proving network "now in production" (beta Apr 2025); experimenting with MPC nodes in TEEs; Devcon7 demo with Cursive/PSE used semi-honest honest-majority 3-party MPC where "MPC nodes must come from different providers"; private proof delegation: generate witness on-device, secret-share it, delegate proof generation; proving needs ~5x the memory of witness gen (8 GB vs 2 GB). — [TACEO primer](https://docs.taceo.io/docs/primer/collabSNARKs-primer/); [TACEO:Proof prod](https://core.taceo.io/articles/taceo-proof-prod/); [Private proof delegation](https://core.taceo.io/articles/private-proof-delegation/); [Devcon demo](https://core.taceo.io/articles/devcon-demo/)

### Inferences
- An IMD-style swarm could host a 3-of-n coSNARK proving service where each party is a distinct seat holder (different providers, satisfying TACEO's "different providers" requirement) and the witness never exists in one place; cost is "non-trivial" (TACEO) and memory (8 GB+) exceeds the 3 GiB VPS profile in the IMD manual, so premium hardware tiers would be needed.
- For Groth16/UltraHonk shielded-pool proofs (much smaller than an Ethereum block), the economic floor for delegated proving is well under $0.01 per proof on current GPU markets; the binding constraint is privacy of the witness, not price.

### Gaps
- No published price for Succinct Private Proving or Boundless requester fees in Nov 2026.
- No benchmark of coSNARK proving for Railgun/Privacy-Pools-sized circuits specifically.

---

## Part 2, Q4: TEEs for agents (Phala, dstack, Flashbots, Oasis ROFL, EigenCompute, Nillion) and on-chain attestation

### Takeaway
dstack (Phala + Flashbots) on Intel TDX with Automata's on-chain DCAP verifier (deployed on 11 mainnets; ~4–5M gas for full quote verification, ~0.43–0.57M gas via SNARK-compressed variants) is the practical stack in 2026, but TEE.fail (Oct 28, 2025; ~$1,000 DDR5 interposer attack on TDX/SEV, no Intel/AMD fix) means on-chain attestation proves measurement, not physical custody, and "everyone moved to permissioned."

### Cited Findings
- dstack: "Open framework for confidential AI," SDK developed by Phala and Flashbots; KMS runs in its own TEE and verifies TDX quotes before releasing keys. — [Dstack-TEE/dstack](https://github.com/Dstack-TEE/dstack); [Phala docs](https://docs.phala.com/network/overview/phala-network)
- ethresear.ch "Physical integrity, attestation, and the state of permissionless TEEs" (fnerdman, Ritual, May 26, 2026): Automata on-chain DCAP deployed across 11 mainnets, used by Taiko, Flashbots, Uniswap, Phala, Puffer; "TEE.fail showed a forged quote passing Automata's verification"; TEE.fail disclosed Oct 28, 2025, ~$1,000 and ~15 minutes, Intel/AMD say bus interposition is out of scope, no CVE; "Everyone moved to permissioned. Or was already there"; BuilderNet "permissioned by design" (IP allowlists); Phala pursuing "Proof of Cloud" (only Level 1 human-witness operational; no on-chain registry); Secret, NEAR, Oasis, Nillion joint effort; recommends CoRIM PoE verifier for EVM; "Phala/dstack is a viable option" today. — [ethresear.ch](https://ethresear.ch/t/physical-integrity-attestation-and-the-state-of-permissionless-tees/24964)
- Automata DCAP attestation gas: on-chain quote verifier ~4M gas with RIP-7212 precompile, ~5M without; SNARK-compressed: ~522k (RISC Zero Groth16), ~493k (SP1 Groth16), ~569k (SP1 Plonk) (older table: 450k/425k/510k). Automata released "DCAP Attestation v1.1 for agentic systems." — [automata-dcap-attestation](https://github.com/automata-network/automata-dcap-attestation); [Automata blog](https://blog.ata.network/automatas-release-of-dcap-attestation-v1-1-for-agentic-systems-84ae98900370)
- Oasis ROFL: TEE-based framework for off-chain logic, "relying on Sapphire for registration, billing, and secrets storage"; mainnet framework July 2025. — [Oasis via ETHGlobal](https://ethglobal.com/events/buenosaires/prizes/oasis-protocol); [TheGrid](https://thegrid.id/discovery/productType/compute-network)
- EigenCompute: runs container images inside TEEs producing proofs code ran as specified; launch date conflicts (Oct 2025 vs Apr 2026 with EigenAI). — [Pinkbrains](https://pinkbrains.io/blogs/the-state-of-decentralized-ai); [Miraheze Eigen Labs](https://ai.miraheze.org/wiki/Eigen_Labs)
- Nillion: "Blacklight" verification layer live since Feb 2026 running decentralised attestation challenges for TEE compute; AgentKit beta Mar 2026 with agents in TEE-backed environments and signing keys bound to attested code. — [Pinkbrains](https://pinkbrains.io/blogs/the-state-of-decentralized-ai); [Substack](https://thelearningpill.substack.com/p/nillion-the-undervalued-blind-compute)
- Phala ERC-8004 TEE agent sample runs in a TDX CVM via dstack with a "TEE Registry Extension." — [Phala-Network/erc-8004-tee-agent](https://github.com/Phala-Network/erc-8004-tee-agent)
- Academic: "Enhancing the Security of Rollup Sequencers using Decentrally Attested TEEs" (arXiv 2511.22317); "Optimistic TEE-Rollups" (arXiv 2512.20176). — [arXiv 2511.22317](https://arxiv.org/pdf/2511.22317); [arXiv 2512.20176](https://arxiv.org/pdf/2512.20176)

### Inferences
- IMD workers today run on arbitrary VPSes/Macs with no TEE; to make swarm agents trustworthy as relayers/provers you would layer dstack-TDX CVMs (Phala Cloud or own hosts) + Automata DCAP verification + ERC-8004 Validation Registry, accepting that physical-custody attacks remain and that a permissioned operator allowlist (like BuilderNet) is the current norm.
- Attestation on mainnet is affordable only in the SNARK-compressed form (~0.5M gas ≈ $0.001–0.01 at sub-1 gwei; see Q7), e.g. once per agent per epoch, not per transaction.

### Gaps
- No 2026 primary docs for Oasis ROFL internals or EigenCompute pricing were retrievable; Flashbots SGX-vs-TDX for BuilderNet is reported inconsistently across sources.

---

## Part 2, Q5: Restaking/AVS slashing for agent misbehaviour; on-chain proof-of-innocence / association-set attestation

### Takeaway
EigenLayer slashing (operator sets with explicit slashing conditions) and Symbiotic (slashing with resolver veto since Jan 2025) are live, with few/no recorded slashing events through mid-2026; Privacy Pools (0xbow, mainnet since Mar 31, 2025; v2 Oct 2026 with private transfers/swaps/Aave yield) implements association sets via a centralised Association Set Provider, which is the obvious role for a slashable, attested agent panel.

### Cited Findings
- EigenLayer: operator "registers into a specific Operator Set and explicitly accepts the slashing conditions attached to that set"; sources conflict on slashing go-live (Apr 17, 2025 most consistent; one says Apr 17, 2026); "zero slashing events recorded through May 2026"; secured value estimates $5B–$18B (unreliable). Symbiotic slashing live at launch Jan 2025 with resolver veto. — [BlockEden](https://blockeden.xyz/blog/2026/04/18/eigenlayer-avs-slashing-activation-15b-restaking-reality-check/); [Protofire](https://protofire.io/guides/restaking-protocols/); [Lambda](https://www.lambdafin.com/articles/restaking-eigenlayer)
- Privacy Pools: launched on Ethereum mainnet Mar 31, 2025 by 0xbow with Vitalik's support; deposit publicly, ASP decides which deposits join the association set, withdraw by proving membership without revealing which deposit; sets are dynamic (illicit deposits can be removed later); supports ETH, wBTC, USDC, USDT, DAI. — [The Block](https://www.theblock.co/post/348959/0xbow-privacy-pools-new-cypherpunk-tool-inspired-research-ethereum-founder-vitalik-buterin); [TradingView/Cointelegraph](https://www.tradingview.com/news/cointelegraph:8174321c5094b:0-privacy-pools-launch-on-ethereum-with-vitalik-demoing-the-feature/)
- Usage: 6,333 deposits / 7,944 withdrawals in Ethereum pools to Aug 9, 2026; "every action on Privacy Pools v1 emits a public event ... can be [re]-indexed and investigated"; anonymity depends on set size and timing of withdrawals after set updates. v1 processed >$26M from 4,000 depositors since Mar 2025. — [unhappyben analysis on X](https://x.com/unhappyben/article/2087565624042004691); [BlockEden](https://blockeden.xyz/blog/2026/04/12/0xbow-privacy-compliance-defi-fatf-travel-rule/)
- Privacy Pools v2 "live on mainnet, adding private transfers, swaps, and Aave-based yield"; v1 stays at v1.privacypools.com (single source, Oct 2026). — [ETH Daily](https://ethdaily.io/privacy-pools-v2-live-on-mainnet)
- Kohaku wallet framework integrates Privacy Pools and Railgun (Railgun listed as collaborator). — [QuickNode Kohaku](https://www.quicknode.com/blog/ethereum-kohaku-wallet-privacy-roadmap); [Kohaku roadmap](https://notes.ethereum.org/@niard/KohakuRoadmap)
- Mixer landscape 2025: Railgun ~71% of mixer volume; Tornado ~25%; Privacy Pools ~5%; Chainalysis reportedly estimates <10% of mixer volume clearly illicit (secondary). Railgun screens at deposit; Privacy Pools screens at exit. — [Cambridge JBS](https://www.jbs.cam.ac.uk/2026/crypto-privacy-after-sanctions-the-return-of-coin-mixers/); [Elliptic](https://www.elliptic.co/blog/analysis/the-next-tornado-cash-six-protocols-vying-to-replace-the-famous-crypto-mixing-service)
- IMD oracle pattern (EIP-712-signed unanimous panel answers with `agreed >= quorum`, Merkle-root daily records) is a working, if centrally orchestrated, "attestation by agents" primitive. — [IMD Docs](https://imd.fun/docs/)

### Inferences
- A "decentralised ASP" = a panel of ERC-8004-identified agents (IMD seats) that each independently screen deposits and co-sign association-set Merkle roots; misbehaviour (signing a root containing a provably sanctioned deposit, or censoring a clean one) is objectively checkable and thus slashable through an EigenLayer/Symbiotic operator set or a seat-NFT bond.
- Because ERC-8004 explicitly delegates slashing to "the specific validation protocol," the AVS would be the validation protocol and could write 0–100 scores into the Validation Registry.

### Gaps
- No source found on anyone already running a decentralised or multi-party ASP, nor on using AI agents for association-set curation.
- EigenLayer slashing activation date is inconsistently reported (2025 vs 2026); verify on EigenLayer docs.

---

## Part 2, Q6: Private communication and private reads (Waku, Nym, Tor, Helios, PIR/ORAM)

### Takeaway
Nym (mixnet; NymVPN dApp mode, anon-rpc worker, experimental Helios-over-Nym fork) and Waku (RLN-gated gossip, used by Railgun) are the live options for private agent/user transport; for private state reads the EF's Kohaku roadmap targets Helios light client in-browser plus TEE+ORAM oblivious `eth_call` now and pure-cryptographic PIR later, and Vitalik's Jan 16, 2026 roadmap frames ORAM/PIR as research that will not land in the next few forks.

### Cited Findings
- Nym: experimental Helios fork routes light-client traffic over the Nym mixnet ("nascent support"; many Nym requesters lack updated Alchemy URLs). NymVPN dApp mode creates local SOCKS5/RPC so wallet traffic transits the mixnet; anon-rpc worker: first response takes tens of seconds while the tunnel bootstraps. — [nymtech/helios-nym](https://github.com/nymtech/helios-nym); [NymVPN dApp mode](https://support.nym.com/hc/en-us/articles/42202770203537-How-to-Make-Private-Ethereum-Transactions-with-NymVPN-dApp-Mode); [anon-rpc docs](https://nym.com/docs/developers/anon-rpc)
- Waku RLN limits and membership (see Q2); Waku described as providing "sender anonymity, metadata protection" for Railgun. — [Waku network](https://waku.org/about/waku-network/); [Railgun docs](https://docs.railgun.org/wiki/learn/privacy-system/community-relayers)
- Tor-integrated wallets (Lunar/Brume) and RPC-privacy projects (1RPC, RPCh, Spook) in community overview. — [web3privacy overview](https://github.com/web3privacy/web3privacy/blob/main/Market%20overview/Ethereum%20Ecosystem/Readme.md)
- Kohaku roadmap (EF): Helios wasm in browser extension with RPC fallback behind killswitch; "a minimal in-browser execution client would run eth_call through an oblivious server ... achieved with TEE+ORAM"; "longer-term ... purely cryptographic approach using PIR"; "Optional P2P transactions" broadcast directly to p2p network; "One account per dApp"; ERC-7811 asset discovery; extension forked from Ambire; native AA work "over 2026"; mainnet first, then Stage-1+ L2s. — [Kohaku Roadmap](https://notes.ethereum.org/@niard/KohakuRoadmap)
- Vitalik Jan 16, 2026 roadmap: ORAM and PIR so wallets query data without revealing access patterns; "still research and early engineering"; would not arrive in the upcoming Kohaku release or next few hard forks. May 2026 near-term privacy plan: AA + FOCIL, EIP-8250 "frame transactions", keyed nonces/nullifiers for simultaneous withdrawals, Kohaku for the access layer. — [KuCoin summary](https://www.kucoin.com/news/flash/vitalik-buterin-outlines-2026-ethereum-roadmap-to-restore-core-values); [Unchained](https://unchainedcrypto.com/vitalik-buterin-outlines-ethereums-near-term-privacy-roadmap-aa-focil-keyed-nonces-and-kohaku/)
- IMD workers already carry local RPC relays (`imd rpc add`, served at 127.0.0.1) and oracle agents "scan chains" through them. — [worker README](https://raw.githubusercontent.com/Identity-md/worker/main/README.md)

### Inferences
- A swarm could serve as a distributed oblivious-read layer (each agent runs Helios + a TEE-ORAM `eth_call` endpoint, reachable over Waku/Nym), which is exactly the "private reads infrastructure" Kohaku wants but does not yet have a decentralised operator set for.

### Gaps
- No production PIR-for-Ethereum-state deployment or benchmark was found; no Tor-specific Ethereum relayer network in 2026.

---

## Part 2, Q7: Mainnet economics in 2026 (gas, verifier costs, blobs, EIP-7702, Fusaka/Glamsterdam/Hegota)

### Takeaway
Mainnet gas was ~0.1–0.3 gwei on Nov 3, 2026 (daily averages 0.46–1.9 gwei in Aug–Sep 2026), making a Groth16 verification (~208k + 7k/input gas) or UltraHonk verification (~0.72–2.4M gas) cost cents, not dollars; Fusaka (Dec 3, 2025) added PeerDAS and a 2^24 per-tx gas cap (EIP-7825), Glamsterdam (ePBS, BALs, repricing, ~200M gas limit) is expected Q4 2026 (Sepolia fork Oct 6, 2026), and Hegota (H2 2026/2027, FOCIL, EIP-8250, AA) carries the privacy-relevant items; EIP-7702 is live since Pectra (May 7, 2025) but 48–97% of delegations are attacker-linked per various studies.

### Cited Findings
- Gas on Nov 3, 2026: ~0.31 gwei normal priority (~$0.01 ETH transfer, ~$0.12 swap) per one tracker; ~0.128 gwei (0.112 base + 0.017 priority) per another; Sep 19, 2026 daily average 0.8993 gwei (YCharts/Etherscan), range 0.4649–1.902 gwei Aug 19–Sep 19, 2026. — [Chaingate](https://chaingate.dev/gas-tracker/ethereum); [Chainscore](https://chainscorelabs.com/fees/ethereum); [Coinlaw](https://coinlaw.io/ethereum-gas-fees-statistics/)
- Groth16 verification gas: ~(181 + 6·l) kgas analytical; measured 207,700 + 7,160·l gas for l public signals. — [Nebra HackMD](https://hackmd.io/@nebra-one/ByoMB8Zf6); [Orbiter HackMD](https://hackmd.io/@Orbiter-Research/S1nat__m0)
- UltraHonk verification gas: ~721k (optimized Solidity, 2^24) vs ~2.06M plain (abutlabs measurement); 747k in an ERC-7984 unwrap project ("~200k gas under the post-Glamsterdam estimate"); ERC-8262 cites ~2.4M per proof. — [abutlabs issue #40](https://github.com/abutlabs/jam-privacy-service/issues/40); [raycashxyz](https://github.com/raycashxyz/erc-7984-single-tx-unwrap); [ERC-8262](https://eips.ethereum.org/EIPS/eip-8262)
- Automata DCAP on-chain attestation: ~4–5M gas full, ~0.43–0.57M SNARK-compressed (see Q4). — [automata-dcap-attestation](https://github.com/automata-network/automata-dcap-attestation)
- Blob cost formula: blob base fee x 131,072 blob gas; 2024 avg $1.59/blob; no Nov 2026 blob fee found. — [Galaxy](https://www.galaxy.com/insights/research/ethereum-150-days-after-dencun); [Blocknative](https://www.blocknative.com/blog/eip-4844-blobs-and-blob-gas-what-you-need-to-know)
- Fusaka activated Dec 3, 2025 (PeerDAS, cheaper L2 settlement; no EIP-7701); EIP-7825 per-transaction gas cap 2^24 (~16.78M). — [hoge.gg](https://hoge.gg/eip-7702-smart-account-dark-side-2026/); [bitbank](https://bitbank.cc/knowledge/breaking/article/ed5mj2ftmlx)
- Glamsterdam: "Expected on mainnet: Q4 2026 · Date not yet confirmed"; EIP-7732 ePBS, EIP-7928 BALs, EIP-7904 repricing; ~200M gas limit floor; Sepolia fork Oct 6, 2026, Hoodi Oct 26. — [ethereum.org Glamsterdam](https://ethereum.org/roadmap/glamsterdam/); [Cryptonomist](https://en.cryptonomist.ch/2026/09/27/ethereum-glamsterdam-upgrade/); [CoinMarketCap](https://coinmarketcap.com/academy/article/ethereum-glamsterdam-upgrade-pushed-q3)
- Hegota: meta-EIP draft EIP-8081; FOCIL (EIP-7805) "considered"; slated H2 2026 or later; Kohaku/EIP-8250/AA "scheduled for the Hegotá hard fork in H2 2026" per one source (fluid). — [Forklog](https://forklog.com/en/news/ethereums-hegota-hard-fork-scheduled-for-late-2026/); [Bankless news](https://www.bankless.com/read/news/ethereum-core-devs-pin-hegota-upgrade-on-2026-roadmap); [Unchained](https://unchainedcrypto.com/vitalik-buterin-outlines-ethereums-near-term-privacy-roadmap-aa-focil-keyed-nonces-and-kohaku/)
- EIP-7702: delegation sets code to 0xef0100 + 20-byte address; ERC-5564 suggests bundling stealth send + announcement via AA or 7702 so sender prepays gas for a fresh stealth address; 2–3M delegations/day observed; malicious share 48% (Wintermute/Protos) to 63% (DelegProof ePrint 2026/2060, USENIX Sec '26) to 97% (earlier Wintermute). — [Openfort stealth](https://www.openfort.io/blog/stealth-addresses); [hoge.gg](https://hoge.gg/eip-7702-smart-account-dark-side-2026/); [Protos](https://protos.com/48-of-ethereum-eip-7702-uses-linked-to-crime-says-wintermute); [ePrint 2026/2060](https://eprint.iacr.org/2026/2060)
- ERC-5564 stealth addresses: Announcer singleton at the same address on every chain; viewing-key scanning; schemeId upgradeable; Feb 2026 reports of "Ethereum to integrate ERC-5564" come from a developer's post, no official activation found. — [Openfort](https://www.openfort.io/blog/stealth-addresses); [U.Today](https://u.today/ethereum-to-integrate-erc-5564-in-push-for-privacy)
- IMD launch preflight shows the current cap in practice: "half the latest block's gas limit" = 99,902,344 (implying ~200M block gas limit observed on the chain used). — [explorer.imd.fun](https://explorer.imd.fun/)

### Inferences
- At ~0.3 gwei and a Groth16 verify of ~250k gas, an on-chain shielded withdrawal costs ~75k gwei ≈ 0.000075 ETH in gas, i.e. well under $1 at any plausible ETH price; relayer economics on mainnet in 2026 are dominated by relayer labour/opsec and fee-in-pool mechanics, not gas.
- EIP-7702's abuse statistics argue against relying on user-side 7702 delegations for privacy UX; stealth addresses + relayer-paid gas (4337 or plain relayer) is lower-risk.

### Gaps
- No Nov 2026 ETH/USD price or blob base fee found; no measured end-to-end 4337 userOp cost including a SNARK verify.

---

## Part 2, Q8: AI and privacy — AI chain analysis vs. AI privacy agents

### Takeaway
Chain-analysis vendors shipped agentic tooling in 2026 (Chainalysis natural-language "blockchain intelligence agents", Mar 30, 2026; Arkham "Ultra" address-to-identity engine), while on the defensive side no production "AI privacy agent" (decoy traffic, privacy-preserving scheduling, continuous privacy audit) was found; the closest public work is Privacy-Pools anonymity-set analyses and academic SoKs.

### Cited Findings
- Chainalysis launched natural-language AI agents on its investigation platform (Mar 30, 2026), with deterministic or exploratory modes, "glass box" auditability, broader rollout summer 2026; it also tested bots that engage scammers to extract intelligence. — [CoinDesk](https://www.coindesk.com/policy/2026/03/30/chainalysis-adds-natural-language-ai-agents-to-its-blockchain-investigation-platform); [PYMNTS](https://www.pymnts.com/fraud-prevention/2026/chainalysis-puts-ai-on-the-crypto-crime-beat/)
- Arkham's AI engine "Ultra" matches on-chain addresses with real-world identities (vendor review). — [Coin Bureau](https://coinbureau.com/review/arkham-intelligence-review)
- Unverified vendor claim (Oct 31, 2026): Chainalysis intrusion by an AI-driven attacker exposing customer identity data. — [Aviatrix](https://aviatrix.ai/threat-research-center/chainalysis-2026-intrusion-internal-tools-customer-identity-data/)
- Third-party claims of >99% Tornado tracing accuracy via graph heuristics are unbacked by primary studies. — [Chainscore](https://www.chainscorelabs.com/blog/web3-philosophy-sovereignty-and-ownership/cypherpunk-ideology-and-regulation/the-future-of-cryptographic-anonymity-sets-against-chain-analysis)
- Privacy Pools anonymity analysis shows public events can be re-indexed and that withdrawal timing after set updates shrinks anonymity sets. — [unhappyben](https://x.com/unhappyben/article/2087565624042004691)
- Academic framing: "SoK: Security and Privacy of AI Agents for Blockchain" (arXiv 2509.07131); "Giving AI Agents Access to Cryptocurrency and Smart Contracts Creates New Vectors of AI Harm" (arXiv 2507.08249); AESP "Human-Sovereign Economic Protocol for AI Agents with Privacy-Preserving Settlement" (arXiv 2603.00318). — [arXiv 2509.07131](https://arxiv.org/pdf/2509.07131); [arXiv 2507.08249](https://arxiv.org/pdf/2507.08249); [arXiv 2603.00318](https://arxiv.org/pdf/2603.00318)
- IMD already runs "research-report" and "oracle" skills with chain-evidence recipes (`log-sum`, `log-count`, `call-compare`) that could be repurposed for continuous privacy auditing of pools. — [IMD Docs](https://imd.fun/docs/)

### Inferences
- The defensive niche (agent-run timing randomisation, decoy shields/unshields funded from a pool, continuous anonymity-set measurement with alerts) appears unoccupied in public sources as of Nov 2026; a swarm with ~900 always-on agents is well suited to generate statistically plausible cover traffic, though cover transactions cost real gas and pool fees (Railgun 0.25% shield/unshield).

### Gaps
- No primary Chainalysis/Arkham publication on AI deanonymisation of Railgun or Privacy Pools; no source on AI-generated decoy traffic in production.

---

## Cross-cutting summary for the design (sourced in sections above)

- Reusable IMD primitives: scarce ERC-721 seat (0x0000ec93…ec1d) -> canonical ERC-8004 agentId (IdentityRegistry 0x8004a169…a432) -> Ed25519 device key; EIP-712-signed oracle panel answers with `agreed >= quorum`; Merkle-distributor reward claims; probation/backoff routing; sandboxed always-on workers (~900 online, mostly idle). — [IMD Docs](https://imd.fun/docs/); [explorer](https://explorer.imd.fun/agents)
- What IMD lacks for privacy infra: any privacy feature; public job briefs; centralised verifier/control plane; no TEE; no slashing; unaudited contracts. — [skill.md](https://imd.fun/skill.md); [Etherscan](https://etherscan.io/address/0x0000ec93127baa929e58e97dd0095a2bfb38ec1d); [worker README](https://github.com/Identity-md/worker)
- Gap-fillers from the ecosystem: Railgun/Waku broadcaster pattern; Privacy Pools ASP role; TACEO coSNARK or Succinct TEE private proving; dstack/TDX + Automata DCAP; EigenLayer/Symbiotic operator sets; Kohaku's Helios + TEE-ORAM private reads; sub-1-gwei mainnet gas.
