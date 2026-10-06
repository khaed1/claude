ID: A4
TITLE: Governance, takeovers and deployment
FILES:
contracts/src/AttestationVerifier.sol
contracts/src/CTOModule.sol
contracts/src/VersionRegistry.sol
contracts/src/SocialRegistry.sol
contracts/src/CreatorVault.sol
contracts/src/SwarmBudget.sol
contracts/src/PadConfig.sol
contracts/src/BondingCurve.sol
contracts/script/Deploy.s.sol
CTO-RULES.md
FOCUS:
AttestationVerifier checks IMD oracle v2 EIP-712 attestations (domain "IdentityMD Oracle", version "2", chain 4663, verifyingContract = the verifier); consumers rebuild the question text onchain and its hash = keccak256 of canonical JSON {answerType, chainId, evidence, question, v:1, window:{fromBlock,toBlock}}. Bar: approved signer, panel >= 51, agreed >= 2/3 and >= quorum, validity window. CTOModule moves a coin's creator-fee recipient after an oracle "yes" (or the team council, until retired), with notice, contest, cooldown and guards; the new recipient is a multisig or the coin itself (fees to holders). VersionRegistry activates launchpad versions by audit attestation over an onchain code hash. SocialRegistry links X handles by vouchers. Deploy.s.sol deploys and wires everything in one run, hands every power to two OpenZeppelin TimelockControllers (48 h, 7 days; Safe proposes, anyone executes) and must leave the deployer with nothing.
Changed since round 1 (D-78): CTOModule stores the proposer handle and contestedAt (confirmation issued after the contest), 90-day council cooldown per coin after a cancel, attested proposals replace pending council ones, retired council proposals can't execute, EIP-7702 wallets refused; VersionRegistry activation moves currentVersion only forward; exact two thirds accepted; PadConfig fee splitter and growth fund immutable; CreatorVault holder stream and hook flush before a takeover switch; SwarmBudget requests of holder-routed coins cancellable by anyone; Deploy reuses an existing contract at a CREATE2 address.
Changed since round 2 (D-79): AttestationVerifier refuses fromBlock > toBlock and consumers emit the attestation window; the confirmation question names contestedAt (and doesn't exist before a contest); execute re-checks the recipient's code (hash stored at propose) and is refused inside an outside PoolManager unlock; coins whose fees go to holders can't be taken over again; rules link <= 256 characters; Deploy funds LiquidityReserve (30M, released to the 48 h timelock after market open) and reads the airdrop root from claims.json (AIRDROP_CLAIMS).
Look hardest at:
- Attestation binding: can one attestation be reused for another coin, recipient, proposer, version, window or consumer? JSON escaping of question text built from user input (names, symbols, handles, links): can a crafted string make two different questions hash the same, or inject fields?
- CTO state machine: propose / contest / confirm / execute / cancel ordering, windows and their edges, cooldown, fallback retirement being truly one-way, interaction with CreatorVault recipient changes and SwarmBudget.sweepToHolders.
- VersionRegistry code hash and rollback; SocialRegistry nonces, deadlines, flags.
- PadConfig bounds and who may call each setter (owner vs. guardian).
- Deploy.s.sol: compare every owner, role, address and amount with DECISIONS.md D-57 and THREAT-MODEL.md section 1; anything left with the deployer; CREATE2 salt mining and hook flags; ordering bugs (a contract initialized with a wrong or zero address).
