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
contracts/src/FixedOwnable.sol
contracts/src/PondPadTimelock.sol
contracts/src/PadToken.sol
contracts/script/Deploy.s.sol
CTO-RULES.md
FOCUS:
AttestationVerifier checks IMD oracle v2 EIP-712 attestations (domain "IdentityMD Oracle", version "2", chain 4663, verifyingContract = the verifier); consumers rebuild the question text onchain and its hash = keccak256 of canonical JSON {answerType, chainId, evidence, question, v:1, window:{fromBlock,toBlock}}. Bar: approved signer, panel >= 51, agreed >= 2/3 and >= quorum, validity window. CTOModule moves a coin's creator-fee recipient after an oracle "yes" (or the team council, until retired), with notice, contest, cooldown and guards; the new recipient is a multisig or the coin itself (fees to holders). VersionRegistry activates launchpad versions by audit attestation over an onchain code hash. SocialRegistry links X handles by vouchers. Deploy.s.sol deploys and wires everything in one run, hands every power to two OpenZeppelin TimelockControllers (48 h, 7 days; Safe proposes, anyone executes) and must leave the deployer with nothing.
Changed since round 1 (D-78): CTOModule stores the proposer handle and contestedAt (confirmation issued after the contest), 90-day council cooldown per coin after a cancel, attested proposals replace pending council ones, retired council proposals can't execute, EIP-7702 wallets refused; VersionRegistry activation moves currentVersion only forward; exact two thirds accepted; PadConfig fee splitter and growth fund immutable; CreatorVault holder stream and hook flush before a takeover switch; SwarmBudget requests of holder-routed coins cancellable by anyone; Deploy reuses an existing contract at a CREATE2 address.
Changed since round 2 (D-79): AttestationVerifier refuses fromBlock > toBlock and consumers emit the attestation window; the confirmation question names contestedAt (and doesn't exist before a contest); execute re-checks the recipient's code (hash stored at propose) and is refused inside an outside PoolManager unlock; coins whose fees go to holders can't be taken over again; rules link <= 256 characters; Deploy funds LiquidityReserve (30M, released to the 48 h timelock after market open) and reads the airdrop root from claims.json (AIRDROP_CLAIMS).
Changed since round 3 (D-80): every timelock-owned contract is FixedOwnable (only the deployer's one handoff) and the timelocks are PondPadTimelock (delay never below the deploy value); CTOModule records valid "no" answers (recordNo, recordConfirmNo: a "yes" issued within 90 days after a "no" doesn't count, a later-asked pending "yes" ends, a confirmation "no" ends a contested takeover, an ended takeover blocks the coin 90 days) and a contested council proposal that lapses waits 90 days; VersionRegistry moves currentVersion only above the highest version ever activated; SocialRegistry revocations consume the nonce and a coin's badge ends when its linker stops being the fee recipient; AttestationVerifier's agreement is an exact fraction; Deploy pauses launches until fee routing is final and rebuilds the airdrop root; CTO-RULES rewritten; the holder stream lives in PadToken (time-weighted).
Changed since our own check before round 4 (D-81, audit/PRECHECK-4.md, P4-1 to P4-5 in FINDINGS): CTOModule.announce(coin, newRecipient) by the proposer's linked wallet, recorded once per question; a "yes" and a "no" to the takeover question count only if issued at least 7 days after it (CTO-RULES R1 / R5 count from it); a "yes" doesn't count while a recorded "no" was issued after it or less than 90 days before it; the proposer's X handle is lowercased in questions, keys and storage; only a confirmation "no" blocks the coin for 90 days. PondPadTimelock's own role admin, its uncapped delay and the Safe's instant renounce are accepted and documented (THREAT-MODEL section 3).
Look hardest at:
- Attestation binding: can one attestation be reused for another coin, recipient, proposer, version, window or consumer? JSON escaping of question text built from user input (names, symbols, handles, links): can a crafted string make two different questions hash the same, or inject fields?
- CTO state machine: announce / propose / contest / confirm / execute / cancel ordering, windows and their edges, cooldown, fallback retirement being truly one-way, interaction with CreatorVault recipient changes and SwarmBudget.sweepToHolders. Recorded "no" answers: can anyone still re-ask until one panel says yes, or use a "no" (any order, any casing, before the notice) to block or end a takeover it shouldn't?
- VersionRegistry code hash and rollback; SocialRegistry nonces, deadlines, flags.
- PadConfig bounds and who may call each setter (owner vs. guardian).
- Deploy.s.sol: compare every owner, role, address and amount with DECISIONS.md D-57 and THREAT-MODEL.md section 1; anything left with the deployer; CREATE2 salt mining and hook flags; ordering bugs (a contract initialized with a wrong or zero address).
