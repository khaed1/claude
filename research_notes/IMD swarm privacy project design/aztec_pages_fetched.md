# Aztec / zk.money — direct page fetch notes (fetched 2026-11-03)

## Fetch results
- https://launch.zk.money/ → HTTP 302 redirect to https://wallet.zk.money/, which is a JS shell ("Loading zk.money…"). No launch copy in HTML; needs headless render.
- https://zk.money/ → placeholder: "Please follow this link (https://launch.zk.money) if you are not redirected automatically."
- https://aztec.network/ → "Aztec is the platform for unstoppable private apps: a decentralized Ethereum L2 where developers build without gatekeepers and users keep their privacy." Publisher: Aztec Foundation.
- https://docs.aztec.network/ and https://aztec.network/blog read in full; https://aztec.network/blog/introducing-aztec-tierra (3 Nov 2026) read.

## Product
docs: "Aztec is a decentralized Ethereum L2 with fully programmable privacy. Private functions run and prove on the user's device, public functions run on the network, and you decide which is which." Not EVM compatible: contracts in Noir with Aztec.nr; public functions run in the Aztec Virtual Machine.
Tierra post: "Aztec is a decentralized Ethereum Layer 2 with more than 3,000 validators and fully programmable private smart contracts. Unlike networks controlled by centralized operators, Aztec has no privileged viewing keys or centralized sequencer." (project's own claims)

## Status as of 3 Nov 2026
- Aztec Tierra (Alpha V6) announced 3 Nov 2026: "The platform for unstoppable private apps is live." "a major network upgrade delivering stronger security, formal verification of the proving system, and faster Ethereum deposits." "1 second client side proofs on a native device, a 2x speedup"; L1→Aztec message delivery "as low as 12 seconds" (was avg 2 min).
- Still labeled "Alpha"; the word "mainnet" does not appear in pages read.
- $AZTEC: used "for staking, governance, and fees." "The ticker is $AZTEC" (13 Nov 2025: "community-first, fair-access token sale with up to a 75% discount for long-term aligned contributors"); "$AZTEC TGE: Next Steps For Holders" (6 Dec 2025); "The $AZTEC TGE Vote" (22 Jan 2026): tokens "could be withdrawn from the sale website into your personal Token Vault smart contracts on the Ethereum mainnet", TGE vote unlocks tradability.
- Ignition: "Aztec Ignition Chain Update" (30 Jan 2026): "The first decentralized L2 on Ethereum reaches 75k block height with 30M $AZTEC distributed through block rewards." "Testnet Retro - 2.0.3" (24 Sep 2025) "the Last Stop Before Ignition."
- "Announcing the Alpha Network" (31 Mar 2026): "The First Feature Complete Privacy Stack is Here." "Alpha Network Security: What to Expect" (10 Mar 2026): transactions enabled "if the governance system successfully passes a vote on the upgrade."
- "Roadmap Update" (4 Mar 2026): "The first fully decentralized, privacy-preserving L2 on Ethereum is ready to ship." "How Aztec Governance Works" (18 Mar 2026).
- Sequencers: "run by thousands of independent sequencers" (21 Sep 2026 post). ZKPassport Case Study (26 Jun 2025): ZK identity used to admit testnet node operators.

## Privacy model
- Private functions "execute and are proven on the user's device, so sensitive data never reaches the network." Public functions in the AVM.
- Private state: "Store data as encrypted UTXOs that only the owner can decrypt and access." Public state in a public Merkle tree.
- "No network-wide viewing key and no special access for operators."
- Composability: "private calls stay confidential across entire contract call chains."
- "How Gas Works on Aztec" (22 Jul 2026): gas "works in two ways: public or private."
- "Inside an Aztec Transaction" (30 Jun 2026): "a private half that executes on your own device, and a public half that executes on the network."
- Credible neutrality essays: "Privacy is only as good as whoever can turn it off" (21 Sep 2026); "The Devil's Bargain - Privacy Without Credible Neutrality" (23 Jun 2026, Zac Williamson): "a settlement layer that can see and censor everything cannot become durable financial infrastructure."
- "Post-Quantum Aztec" (15 Oct 2026).

## zk.money
- Tierra era: "zk.money: Private payments and savings, built by Aztec Labs." "users can deposit directly from any Ethereum wallet into zk.money." Joe Andrews (Co-Founder & CEO, Aztec Labs): "make lightning-fast private transactions without complicated bridging workflows."
- launch.zk.money: redirects to wallet.zk.money app; content not determinable without render.
- Historical timeline from blog index: $17M Series A from Paradigm (16 Dec 2021); Noir beta (20 Dec 2021); Aztec.nr (18 Sep 2023); NoirJS (25 Oct 2023); Devnet (13 Aug 2024); Public Testnet (1 May 2025); Adversarial Testnet with slashing + on-chain governance (22 Jul 2025); Alpha V5 (21 Jul 2026); Alpha V6 Tierra (3 Nov 2026). "History of Aztec" post (22 Apr 2025) covers 2017–2024 (not opened).

## Weaknesses / incidents
- "Alpha V5 Proving System Vulnerability" (7 Aug 2026): "a critical vulnerability in Aztec's V5 Alpha proving system... fix planned for V6." Tierra "resolves identified vulnerabilities from previous versions, including the critical issue discovered in V5."
- "Critical Vulnerability in Alpha v4" (27 Mar 2026).
- Tierra: "a new AI-powered security testing harness, formal verification of core cryptographic components."
- Audits (Dec 2024): ZKSecurity, Zellic, Spearbit ("Audits of Bigfield").

## Unread candidates
https://aztec.network/blog/aztec-ignition-chain-update ; .../the-aztec-tge-vote-what-you-need-to-know ; .../history-of-aztec-pioneering-privacy-in-web3 ; .../how-gas-works-on-aztec ; .../alpha-network-security-what-to-expect ; https://aztec.network/apps
