# Docket: questions for the IMD dev

**Status: ready to send, 4 October 2026.** Docket relies on IMD oracle answers to move project money, so these answers decide how much a Docket module can safely be trusted with. The first three groups block a mainnet launch; the rest shape the design.

What we already know (from https://imd.fun/docs, https://api.imd.fun/openapi.json and PondPad's work, `../launchpad/DECISIONS.md` D-49):
- Attestations are EIP-712, domain `{"IdentityMD Oracle", "2", chainId, verifyingContract}`, where chain and contract are the request's `consumer`. Each Docket module is its own consumer.
- `questionHash` = keccak256 of the canonical JSON `{"answerType","chainId","evidence","question","v":1,"window":{fromBlock,toBlock}}` when there are no definitions or guards.
- `oracle.request` costs a flat 0.5 IMD, paid on Ethereum mainnet via x402 + Permit2; panels of 5 to 100, one member per seat. A panel that disagrees ends with no attestation.
- Every attestation so far is signed by one key, `0x5598aa9146215bc13eb26f2c692ad1461fd32982`.

---

## 1. Signing (blocks mainnet)

1. Is `0x5598…2982` a single hot key? Where is it kept, and who can use it?
2. Are there plans for **threshold signing** (for example 3 of 5 signers) or several independent attesters? If so, will the attestation carry several signatures, or one aggregated signature? Docket can require *k* of *n* signers per mandate if each signs the same `OracleAttestation`.
3. If the key is rotated or leaked, how will consumers be told, and how quickly? Is there a public revocation list or an onchain registry of current signers?
4. Does the signer sign anything other than panel results, such as recipe reruns for chain evidence (the docs say the deployer reruns and may decide when members split)? For `evidence: "panel"` questions, can the deployer change the outcome in any way?

## 2. Panels (blocks mainnet)

5. How are panel members chosen: a random draw from online seats, first to accept, or something else? Can the requester influence who sits on a panel?
6. Can one owner hold many seats, and is there a cap per owner? A group holding many seats could otherwise steer answers that move money.
7. Do members answer **independently** (no sight of other answers before submitting)?
8. Can a requester require a minimum track record for members (for example `accepted` count from `/seats/:tokenId`)? Docket would use this for large mandates.
9. Live attestations show `panelSize: 200` while capabilities say 5 to 100. What is the real range, and will the price stay flat for large panels?

## 3. Consumer chains and payments (blocks Robinhood launch)

10. Will the oracle sign for **consumer chain 4663 (Robinhood)** with any `verifyingContract`? (Same open item as PondPad.) Any limits on which consumer chains or contracts are allowed?
11. Is **4663 a configured evidence chain** (the `chainId` field "needs a configured RPC")? Docket's questions set `chainId` to the consumer chain.
12. When can requests be **paid on Robinhood and Base**? Today a Docket proposer needs IMD on Ethereum mainnet to ask.
13. Can a **contract** pay for a request (an escrow that pays per proposal), or must it be an EOA signing x402 + Permit2?

## 4. Question format

14. Will `questionHash` stay the canonical JSON above? If we add `definitions` or `guards`, how are they included in the hash (key order, escaping), so a contract can rebuild it?
15. Will Docket's template questions pass the **wording screen** (it refuses questions with more than one reasonable reading)? Example question below. If not, does `allowAmbiguous: true` change the hash?
16. Is the 2,000-character limit counted in bytes or characters? Docket keeps to printable ASCII without `"` or `\`.

Example Docket question (about 700 characters):

> Docket proposal 4 for PondPad on chain id 4663, module 0x…: under the charter at ipfs://…, section Grants, should the growth grant mandate make the Safe 0x… call grant(address,address,uint256,bytes32,string) on 0x… with token=0x…, to=0x…, amount_wei=400000000000000000000, ref=4, reason=ipfs://…? Evidence: ipfs://…. Answer true only if every rule that applies is met.

## 5. Answers

17. Is a **"false"** answer signed like a "true" one (`answer` = 0)? Docket records "no" answers onchain and uses them against answer shopping.
18. **Answer shopping:** a proposer could ask the same question several times and only submit a "yes". Docket cancels a queued action if anyone submits a "no" to the same question issued no later than the "yes". To make that complete we'd like either:
    - an index of all requests by `questionHash` (or exact question text) with their outcomes, including panels that ended with no answer; or
    - the request's **creation time** in the attestation, so "asked before" can be checked rather than "signed before".
19. What does `issuedAt` mean exactly: the time of signing, or of the panel's last answer? Can it be earlier than the request's creation?
20. Is `requestId` unique across all consumers and chains?

## 6. Work and delivery (for `WorkEscrow`, later)

21. Can an oracle question reference a job (`/jobs/:id`) so a second panel judges "was this delivered to spec?" with the job's delivery as evidence?
22. Can a contract on Robinhood open and pay for a job (`job.open`), or will a relay always be needed?

## 7. Running it

23. Is there a status page or uptime record for the oracle? Docket stays safe when IMD is down (nothing executes, vetoes still work), but projects will ask.
24. Any rate limits per requester on `oracle.request`?
