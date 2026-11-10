# Privacy Pools (0xbow): ASP interface at code level, v1 and v2 — can a panel ASP be an overlay?

Research note for the "Murmuration" panel-ASP design. Read-only work: no transactions, no posts, no commits, and no code from the downloaded repositories was executed.

- Fetch dates: 9 Nov 2026 (about 21:00–21:40 UTC) and 10 Nov 2026 (00:13 UTC) for the L2BEAT and DefiLlama re-check.
- Chain reads: Ethereum mainnet, `eth_call` / `eth_getLogs` / `eth_getStorageAt` on public RPCs, at blocks 26379962–26379993 (block 26379962 timestamp 1794258935 = 9 Nov 2026 21:15:35 UTC).
- "Verified on-chain" below means I read it myself with a read-only call. "L2BEAT" means the page at `l2beat.com/privacy/...`, which now redirects to `ethbeat.org` ("ETHBEAT (formerly L2BEAT)").

## 0. Verdict in one paragraph

A panel ASP cannot replace or sit beside 0xbow's ASP inside the existing contracts unless 0xbow's 2/4 Safe acts. Both versions store one append-only list of roots and accept only the latest one; there is no ASP identifier anywhere in the contracts, the proofs or the public signals. What is possible without 0xbow is an **additive** overlay: a second membership proof over the same deposit labels against a panel root, checked off-chain or by a separate contract. For **v1** this needs nobody's cooperation, because labels are public and deterministic and the deployed verifier answers any caller. For **v2** it needs each depositor to disclose the deposit opening to the panel, because labels are private. An additive overlay can only make a withdrawal "also panel-approved"; it can never unlock a withdrawal that 0xbow's ASP refuses.

## 1. Repositories and versions

| Item | Fact | Source |
| --- | --- | --- |
| v1 repo | `github.com/0xbow-io/privacy-pools-core`, Yarn monorepo: `packages/circuits`, `contracts`, `relayer`, `sdk`, plus `audit/` and `docs/` | clone, `README.md` |
| v1 at launch | No tag at launch. Branch `deploy/mainnet-prod` head `7f5f07af2e6ffe72be395c0c8ce72e991058f89e`, 31 Mar 2025, "mainnet deploy report". Contracts were deployed in block 22153707 (29 Mar 2025 16:19:35 UTC) | `git log`; `packages/contracts/deployments/1.json` on that branch; block timestamp read on-chain |
| v1 tags | `v0.1.0` 09fb59a (25 May 2025), `v1.1.0` 47217ef (31 Jul 2025), `v1.1.1` 7bc392d (2 Sep 2025), `v1.2.0` 0e1de2c and `v1.2.1` a80836a (8 Mar 2026), `v1.3.0` c312dcd (31 Aug 2026). `main` = df4bf73 (24 Oct 2026, a CI change) | `git ls-remote`, `git log` |
| v1 Entrypoint upgrade | Commit 7ccea5c (21 May 2025) added `usedPrecommitments`. It is the last change to `Entrypoint.sol`. `PrivacyPool.sol` was last changed 5 Mar 2025 | `git log -- packages/contracts/src/contracts/` |
| v2 repo | **Separate repository** `github.com/0xbow-io/privacy-pools-v2-monorepo` (pnpm). `packages/`: `circuits`, `contracts`, `contracts-stellar`, `core-sdk`, `evm-sdk`, `stellar-sdk`, `relayer`, `swaps`, `mock-asp`, `e2e-suite`. `privacy-pools-core` contains no v2 code | clone |
| v2 release | Tag `v1.0.0` = a376d3974571a332cf9fd274a6cf6c20e5b43d18 ("release v1", 20 Oct 2026). Tag `v1.0.2` = 1ee57b0. `main` = 61fac03acd1fc306164ddc234f7fac4147d04493 (20 Oct 2026). The history is 5 commits, a squashed release; the Consensys report names the working repo `0xbow-io/v2-monorepo`, branch `v2.0` | `git log`, `CHANGELOG.md`, `audits/2026-09-consensys-diligence.md` line 3 |
| Naming | v2 is a different architecture: `PoolVault`, `Keystore`, `ASPRegistry`, `AccessRouter`, `Entrypoint`, `PrivacyPoolRelay`, 27 verifiers | `packages/contracts/src/contracts/` |

## 2. v1: ASP interface (quoted)

All paths are under `packages/contracts/src/` at `main` (df4bf73); line numbers are from that commit.

### 2.1 Posting a root

`contracts/Entrypoint.sol` lines 40–43, 52, 80–85, 93–104:

```solidity
  /// @dev 0xb19546dff01e856fb3f010c267a7b1c60363cf8a4664e21cc89c26224620214e
  bytes32 internal constant _OWNER_ROLE = keccak256('OWNER_ROLE');
  /// @dev 0xfc84ade01695dae2ade01aa4226dc40bdceaf9d5dbd3bf8630b1dd5af195bbc5
  bytes32 internal constant _ASP_POSTMAN = keccak256('ASP_POSTMAN');
  ...
  AssociationSetData[] public associationSets;
  ...
    _setRoleAdmin(DEFAULT_ADMIN_ROLE, _OWNER_ROLE);
    _setRoleAdmin(_OWNER_ROLE, _OWNER_ROLE); // Owner can manage owner role
    _setRoleAdmin(_ASP_POSTMAN, _OWNER_ROLE); // Owner can manage postman role

    _grantRole(_OWNER_ROLE, _owner);
    _grantRole(_ASP_POSTMAN, _postman);
  ...
  function updateRoot(uint256 _root, string memory _ipfsCID) external onlyRole(_ASP_POSTMAN) returns (uint256 _index) {
    // Check provided values are non-zero
    if (_root == 0) revert EmptyRoot();
    uint256 _cidLength = bytes(_ipfsCID).length;
    if (_cidLength < 32 || _cidLength > 64) revert InvalidIPFSCIDLength();

    // Push new association set and update index
    associationSets.push(AssociationSetData(_root, _ipfsCID, block.timestamp));
    _index = associationSets.length - 1;

    emit RootUpdated(_root, _ipfsCID, block.timestamp);
  }
```

`interfaces/IEntrypoint.sol` lines 51–55: `struct AssociationSetData { uint256 root; string ipfsCID; uint256 timestamp; }`.

- Storage is an **append-only dynamic array on the Entrypoint**, shared by every pool on the chain. It is not a ring buffer. The ring buffer (`ROOT_HISTORY_SIZE = 64`, `State.sol` line 35) holds **state** roots only.
- Roles use OpenZeppelin `AccessControlUpgradeable`. The admin of `ASP_POSTMAN` is `OWNER_ROLE`.
- Views (lines 279–288): `latestRoot()` returns the last element and reverts `NoRootsAvailable` if the array is empty; `rootByIndex(uint256)`.

### 2.2 How a withdrawal checks the ASP root: latest only

`contracts/PrivacyPool.sol` lines 43–61:

```solidity
  modifier validWithdrawal(Withdrawal memory _withdrawal, ProofLib.WithdrawProof memory _proof) {
    // Check caller is the allowed processooor
    if (msg.sender != _withdrawal.processooor) revert InvalidProcessooor();

    // Check the context matches to ensure its integrity
    if (_proof.context() != uint256(keccak256(abi.encode(_withdrawal, SCOPE))) % Constants.SNARK_SCALAR_FIELD) {
      revert ContextMismatch();
    }

    // Check the tree depth signals are less than the max tree depth
    if (_proof.stateTreeDepth() > MAX_TREE_DEPTH || _proof.ASPTreeDepth() > MAX_TREE_DEPTH) revert InvalidTreeDepth();

    // Check the state root is known
    if (!_isKnownRoot(_proof.stateRoot())) revert UnknownStateRoot();

    // Check the ASP root is the latest
    if (_proof.ASPRoot() != ENTRYPOINT.latestRoot()) revert IncorrectASPRoot();
    _;
  }
```

- State root: any of the last 64. ASP root: **exactly the latest**. A new `updateRoot` invalidates every pending proof.
- `ENTRYPOINT` is `immutable` in the pool (`State.sol` line 44), so each pool reads the root from the Entrypoint proxy forever.
- The v1 Auditware report raised this as AW-L-01 and recommended to "Introduce a time-based restriction on how often the **ASP_POSTMAN** can update the root, or alternatively, use a decentralized entity to perform the update." Status in the report: "No Risk (by design)" (`audit/contracts_audit_auditware.md`).

### 2.3 Labels and events: public and deterministic

`contracts/PrivacyPool.sol` lines 92–106 and `State.sol` line 89:

```solidity
    // Compute label
    uint256 _label = uint256(keccak256(abi.encodePacked(SCOPE, ++nonce))) % Constants.SNARK_SCALAR_FIELD;
    // Store depositor
    depositors[_label] = _depositor;

    // Compute commitment hash
    _commitment = PoseidonT4.hash([_value, _label, _precommitmentHash]);
    ...
    emit Deposited(_depositor, _commitment, _label, _value, _precommitmentHash);
```

```solidity
    SCOPE = uint256(keccak256(abi.encodePacked(address(this), block.chainid, _asset))) % Constants.SNARK_SCALAR_FIELD;
```

Event (`interfaces/IPrivacyPool.sol` lines 39–41): `event Deposited(address indexed _depositor, uint256 _commitment, uint256 _label, uint256 _value, uint256 _precommitmentHash);`

Verified on-chain and on IPFS (9 Nov 2026):

- ETH pool `0xF241d57C6DebAe225c0F2e6eA1529373C9A9C9fB`: `SCOPE()` = 4916574638117198869413701114161172350986437430914933850166949084132905299523, `nonce()` = 6498, `MAX_TREE_DEPTH()` = 32, `ROOT_HISTORY_SIZE()` = 64, `currentTreeSize()` = 14286, `dead()` = false.
- `Entrypoint.latestRoot()` = 12874944407671204963163537667349892192953879563194875220025857008830449345699. `associationSets.length` = 3361. The last entry's CID is `bafybeicgyjabcjig5zu2gwrlcills6va6k5gt3c3zzg3o54dmqkx5uajlu`, timestamp 1794255563 (9 Nov 2026 20:19:23 UTC).
- That CID, fetched from `gateway.pinata.cloud`, is a 1.15 MB JSON array of 14 tree levels with **7,260 leaves**; its top node equals the on-chain `latestRoot()`.
- I recomputed `keccak256(abi.encodePacked(SCOPE, n)) % p` for n = 1..6498. **5,581** of those values are leaves of that list. So the leaves are raw labels, and the whole label universe of a pool can be rebuilt from `SCOPE` and the nonce alone.
- Example: deposit tx `0x7846b1b497b7f1f9f417d3748892b12e15c7ed0bb0e2d642cc52acb7ec89ebe9` (block 26376425, 9 Nov 2026 09:26:11 UTC, depositor `0x9925b4e5…d56c`) has label = `keccak(SCOPE, 6494) % p`, and that label was in the list posted at 20:19 UTC.

### 2.4 Withdrawal circuit and verifier

`packages/circuits/circuits/withdraw.circom` (circom 2.2.0), instantiated in `packages/circuits/src/index.ts` as `Withdraw` with `params: [32]` and `pubs: ["withdrawnValue", "stateRoot", "stateTreeDepth", "ASPRoot", "ASPTreeDepth", "context"]`.

```circom
  // 4. Verify label is in ASP tree
  component ASPRootChecker = LeanIMTInclusionProof(maxTreeDepth);
  ASPRootChecker.leaf <== label;
  ASPRootChecker.leafIndex <== ASPIndex;
  ASPRootChecker.siblings <== ASPSiblings;
  ASPRootChecker.actualDepth <== ASPTreeDepth;

  ASPRoot === ASPRootChecker.out;
```

- The ASP tree is a LeanIMT with `Poseidon(2)` nodes, leaf = the raw label, maximum depth 32 (`merkleTree.circom`). A zero sibling means "no sibling".
- Commitment = `Poseidon(value, label, Poseidon(nullifier, secret))`; nullifier hash = `Poseidon(nullifier)` (`commitment.circom`).
- Public signals in verifier order (`contracts/lib/ProofLib.sol` lines 20–28): `[0] newCommitmentHash, [1] existingNullifierHash, [2] withdrawnValue, [3] stateRoot, [4] stateTreeDepth, [5] ASPRoot, [6] ASPTreeDepth, [7] context`.
- `context` is only squared in the circuit (`signal contextSquared <== context * context;`). Its meaning comes from the contract.
- Proving system: **Groth16 over BN254** (`circomkit.json`: `"proofSystem": "groth16", "curve": "bn128"`), snarkjs 0.7.5. Read from the committed `build/withdraw/withdraw.r1cs` header: **36,832 constraints**, 36,901 wires, 2 public outputs, 6 public inputs, 72 private inputs. The commitment (ragequit) circuit has 1,537 constraints.
- Proving and verification keys are committed: `packages/circuits/trusted-setup/final-keys/withdraw.zkey` (17.8 MB) and `withdraw.vkey`.
- `contracts/verifiers/WithdrawalVerifier.sol` line 81: `function verifyProof(uint256[2] calldata _pA, uint256[2][2] calldata _pB, uint256[2] calldata _pC, uint256[8] calldata _pubSignals) public view returns (bool)`. No access control, no state. Deployed at `0x022891F938Ae7fDC8Ab9Ead0FBf50aBA8C897D6d` (1,947 bytes of code).

### 2.5 Experiment: the deployed verifier is callable by anyone and knows nothing about "latest"

I decoded the calldata of relay tx `0xaed26cb52654a019afb2839dd95016b2cdeb6ada64e585ffbc7624d1fe5c6f86` (block 26379217) and sent its proof to the verifier with `eth_call`:

| Call | Result |
| --- | --- |
| `verifyProof` with the original proof, at the latest block | `true` |
| Same proof, `ASPRoot` signal changed by 1 | `false` |
| Same proof, `context` signal changed by 1 | `false` |

At the time of my call the proof's `ASPRoot` (2001332322…7093) was no longer `Entrypoint.latestRoot()`, and its nullifier was already spent (`nullifierHashes(...)` = true). The verifier still returned `true`. The "latest root" rule and the nullifier rule live only in the pool; the verifier is a pure function of proof and public signals. I also recomputed `keccak256(abi.encode(withdrawal, scope)) % p` from the calldata and it equals the proof's `context`.

### 2.6 Ragequit (v1)

`contracts/PrivacyPool.sol` lines 132–150:

```solidity
  function ragequit(ProofLib.RagequitProof memory _proof) external {
    // Check if caller is original depositor
    uint256 _label = _proof.label();
    if (depositors[_label] != msg.sender) revert OnlyOriginalDepositor();

    // Verify proof with Groth16 verifier
    if (!RAGEQUIT_VERIFIER.verifyProof(_proof.pA, _proof.pB, _proof.pC, _proof.pubSignals)) revert InvalidProof();

    // Check commitment exists in state
    if (!_isInState(_proof.commitmentHash())) revert InvalidCommitment();

    // Mark existing commitment nullifier as spent
    _spend(_proof.nullifierHash());

    // Transfer out funds to ragequitter
    _push(msg.sender, _proof.value());

    emit Ragequit(msg.sender, _proof.commitmentHash(), _proof.label(), _proof.value());
  }
```

Conditions: the caller is the original depositing address of that label, the proof is valid, the commitment is in the state tree, and the nullifier is unspent. There is no time condition (the error `NotYetRagequitteable` is declared in `IState.sol` but never used), and the Entrypoint is not involved. Ragequit public signals: `[commitmentHash, nullifierHash, value, label]`.

### 2.7 Relay and fees (v1)

`contracts/Entrypoint.sol` lines 133–176 (shortened):

```solidity
  function relay(
    IPrivacyPool.Withdrawal calldata _withdrawal,
    ProofLib.WithdrawProof calldata _proof,
    uint256 _scope
  ) external nonReentrant {
    if (_proof.withdrawnValue() == 0) revert InvalidWithdrawalAmount();
    // Check allowed processooor is this Entrypoint
    if (_withdrawal.processooor != address(this)) revert InvalidProcessooor();
    ...
    _pool.withdraw(_withdrawal, _proof);
    // Decode relay data
    RelayData memory _data = abi.decode(_withdrawal.data, (RelayData));
    if (_data.relayFeeBPS > assetConfig[_asset].maxRelayFeeBPS) revert RelayFeeGreaterThanMax();
    ...
    // Transfer withdrawn funds to recipient
    _transfer(_asset, _data.recipient, _amountAfterFees);
    // Transfer fees to fee recipient
    _transfer(_asset, _data.feeRecipient, _feeAmount);
    ...
    emit WithdrawalRelayed(msg.sender, _data.recipient, _asset, _withdrawnAmount, _feeAmount);
  }
```

`struct RelayData { address recipient; address feeRecipient; uint256 relayFeeBPS; }` (`IEntrypoint.sol` lines 37–41).

- **Permissionless.** `relay` has no role check and no relayer allowlist. Any address may submit.
- The recipient, the fee recipient and the fee rate are inside `_withdrawal.data`, which is bound into the proof's `context`. The submitting address is not bound.
- The fee is a **public transfer** in the withdrawn asset to `feeRecipient`, in the same transaction, with a public event. In the example tx above, `msg.sender` and `feeRecipient` were both `0xec15c200…fb66` and `relayFeeBPS` was 11 (0.11%).
- A user can skip the Entrypoint: `pool.withdraw` accepts any caller equal to `processooor`. `contracts/BatchRelayer.sol` (added 31 Aug 2026) is a separate contract that calls `_pool.withdraw(_withdrawal, _proofs[i])` itself as processooor. Any third party can deploy a processooor contract of its own.
- Relayer package: `packages/relayer`, Apache-2.0, TypeScript/Express/SQLite, open source. Its own checks (`src/services/privacyPoolRelayer.service.ts` lines 245–260): `processooor` must be the Entrypoint and `feeRecipient` must be the relayer's configured fee receiver; the fee must match a fee commitment it signed. A third party needs a funded key, an RPC, and a `config.json`. Which relayers the hosted website offers is a front-end choice: L2BEAT says it "picks the first of Fast Relay and Cloaked Relay that answers" and "offers no way to submit a withdrawal yourself, while anyone can relay onchain".

### 2.8 Upgradeability, owner, fees (v1)

- The Entrypoint is a UUPS proxy: `contract Entrypoint is AccessControlUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, IEntrypoint` and `function _authorizeUpgrade(address) internal override onlyRole(_OWNER_ROLE) {}` (line 308). The implementation slot now holds `0x15e355024de1cdc74addea7ebdf98418ba5b1a2c`; the original was `0xdd8aa0560a08e39c0b3a84bba356bc025afbd4c1`.
- Pools are **not proxied** and have no admin. `ASSET`, `SCOPE`, `ENTRYPOINT`, `WITHDRAWAL_VERIFIER` and `RAGEQUIT_VERIFIER` are `immutable` (`State.sol` lines 40–48). Verified: ETH pool `ENTRYPOINT()` = `0x6818809E…6b46`, `WITHDRAWAL_VERIFIER()` = `0x022891F9…7D6d`, `RAGEQUIT_VERIFIER()` = `0xa45ACa86…5eC6`.
- Owner, verified on-chain: `hasRole(OWNER_ROLE, 0xAd7f9A19E2598b6eFE0A25C84FB1c87F81eB7159)` = true. That address is a Safe with `getThreshold()` = 2 and 4 owners (`0xd76eEb2A…B52E`, `0xb1A1D5b0…16fc`, `0x652E36f8…13dA`, `0xE8A2cC5c…Af77`). The deployer EOA `0x1f4Fe25C…E187` no longer has `OWNER_ROLE`.
- Postmen, verified on-chain: `hasRole(ASP_POSTMAN, …)` is true for **both** the EOA `0x1f4Fe25Cf802a0605229e0Dc497aAf653E86E187` and the **Safe** `0xAd7f…7159`. A contract already holds the postman role. `getRoleAdmin(ASP_POSTMAN)` = `OWNER_ROLE`.
- Owner functions: `registerPool`, `removePool`, `updatePoolConfiguration(asset, minimumDepositAmount, vettingFeeBPS, maxRelayFeeBPS)`, `windDownPool` (sets `dead = true`, which stops deposits for good; withdrawals and ragequit continue), `withdrawFees`, role grants and revocations, and upgrades. No timelock. v1 has no pause.
- Fee bound (line 396): `if (_vettingFeeBPS >= 10_000 || _maxRelayFeeBPS >= 10_000) revert InvalidFeeBPS();`, so the ceiling is 99.99%. The vetting fee is deducted from the deposit (`_deductFee`).
- Current values, verified on-chain for ETH: `assetConfig(ETH)` = pool `0xF241…C9fB`, minimum 0.01 ETH, **vettingFeeBPS 50**, **maxRelayFeeBPS 1000**. L2BEAT lists 0.5% vetting on BOLD, ETH, USDC, USDT and 0% on the other ten assets, with 5–10% relay caps; it records USDT going from 0 to 0.5% on 3 Nov 2026.
- A consequence: because pools call `ENTRYPOINT.latestRoot()`, an Entrypoint upgrade can change what "the ASP root" means for the existing immutable pools.

## 3. v2: ASP interface (quoted)

Paths are under `packages/contracts/src/` at `main` (61fac03).

### 3.1 Posting a root

`contracts/ASPRegistry.sol` lines 52–71:

```solidity
  function updateASPRoot(uint256 _aspRoot, bytes calldata _ipfsCID) external override checkAccess(POSTMAN_ROLE) {
    require(_aspRoot != 0, ASPRegistry_EmptyASPRoot());
    require(_aspRoot < SNARK_SCALAR_FIELD, ASPRegistry_RootOutOfField());
    require(_ipfsCID.length != 0, ASPRegistry_EmptyIPFSCID());

    _getASPRegistryStorage().associationSets.push(AssociationSetData({root: _aspRoot, ipfsCID: _ipfsCID}));
    emit ASPRootUpdated(_aspRoot, _ipfsCID);
  }

  /// @inheritdoc IASPRegistry
  function registerLabel(bytes calldata _ciphertext) external override {
    emit LabelRegistered(_ciphertext);
  }

  /// @inheritdoc IASPRegistry
  function latestASPRoot() external view override returns (uint256 _root) {
    AssociationSetData[] storage _associationSets = _getASPRegistryStorage().associationSets;
    require(_associationSets.length != 0, ASPRegistry_EmptyAssociationSet());
    _root = _associationSets[_associationSets.length - 1].root;
  }
```

The role check, `abstracts/Permissioned.sol` lines 43–45:

```solidity
  function _checkAccess(bytes32 _role) internal view {
    require(ACCESS_ROUTER.hasRole(_role, msg.sender), Permissioned_NotAuthorized());
  }
```

- `utils/RolesConstants.sol`: `bytes32 constant POSTMAN_ROLE = keccak256('POSTMAN_ROLE');`
- `contracts/AccessRouter.sol` is OpenZeppelin `AccessControl` (not upgradeable, not enumerable). The deploy configuration puts `PAUSER_ROLE`, `ENTRYPOINT_MANAGER_ROLE` and `POSTMAN_ROLE` under `OPS_ADMIN_ROLE` (`script/registries/ChainConfigRegistry.sol` lines 59–61).
- Storage is again an append-only array, in the `ASPRegistry` (ERC-7201 namespaced). The interface comment calls it "Append-only array of all previous ASP roots and their IPFS CIDs".

### 3.2 How a spend checks the ASP root: latest only

`contracts/PoolVault.sol` lines 352–356:

```solidity
  function _validateAndVerify(ProofLibV2.TransactProof calldata _proof) internal {
    PoolVaultStorage storage $ = _getPoolVaultStorage();
    require(isKnownRoot(_proof.stateRoot()), PoolVault_UnknownStateRoot());
    require($.keystore.isKnownRoot(_proof.keyRegistryRoot()), PoolVault_UnknownKeystoreRoot());
    require(_proof.associationSetRoot() == $.aspRegistry.latestASPRoot(), PoolVault_InvalidASPRoot());
```

The design doc repeats it: `docs/tech-design/contracts/batch-withdrawal.md` line 41 ends with the comment `// latest only`. Every private transfer and every withdrawal goes through `transact`, so all of them need the latest root.

The registry is a replaceable pointer (lines 257–262):

```solidity
  function setAspRegistry(IASPRegistry _aspRegistry) external checkAccess(UPGRADER_ROLE) {
    PoolVaultStorage storage $ = _getPoolVaultStorage();
    address _previous = address($.aspRegistry);
    $.aspRegistry = _aspRegistry;
    emit AspRegistrySet(_previous, address(_aspRegistry));
  }
```

### 3.3 Labels are private in v2

`packages/circuits/circuits/templates/Deposit.circom` lines 49–68: `precommitment = Poseidon(noteAddressHash, tokenId, value, 0)`, `label = Poseidon(precommitment, depositSecret)`, `commitment = Poseidon(precommitment, label)`. The label is an intermediate signal, not a public one.

- Deposit events: `Deposited(uint256 outputCommitment, address indexed asset, uint256 depositedValue, address indexed caller)` and `Note(bytes32 indexed hint, bytes data)` on the vault; `Deposited(_asset, _depositor, _value, _fee)` on the Entrypoint. No label.
- The link from deposit to label reaches the ASP as an encrypted blob. `Entrypoint.deposit(proof, noteData, aspCiphertext)` line 91: `if (_aspCiphertext.length != 0) $.poolVault.aspRegistry().registerLabel(_aspCiphertext);`
- `registerLabel` is **permissionless and opaque**: it only emits `LabelRegistered(bytes)`. `docs/tech-design/user-flows.md` says the client encrypts `{noteAddressHash, tokenId, value, depositSecret, metadata}` "for ASP using ASP's public viewing key", with a fresh ephemeral X25519 key per deposit, and that the ASP "adds `Poseidon(label)` (the labelHash) to its off-chain `associationSet` tree".
- The ASP leaf is `Poseidon(label)`, not the label (`Transact.circom` lines 211–224).
- Verified: `ASPRegistry.latestASPRoot()` = 8615913840635781892683956976167782230061038909795359136280476028507833177500, `latestIPFSCID()` = `bafybeibrkak6uiwljaxahkqnfuipmlwfgfdmajwo7kdmdj5tqma3qnkmgy`. That file is a 14-level tree with **4,364 leaves** and a top node equal to the on-chain root.
- L2BEAT counts 583 deposits in total on Ethereum and states that "The ASP adds ten labels per update, decoys included". 4,364 leaves against 583 deposits is consistent with decoys. An outsider cannot map v2 leaves to deposits.
- A label only becomes public on ragequit (`Ragequit(ragequitter, asset, value, commitment, nullifierHash, label)`). Every later holder of a note learns its label ("Every note created from the deposit's funds carries the same label, including notes paid to others, so each recipient learns it", L2BEAT).

### 3.4 Transact circuit and verifiers

`packages/circuits/circuits/templates/Transact.circom`; instances such as `main/transact/transact_1x2.circom`:
`component main {public[stateRoot, keystoreRoot, associationSetRoot, amountOut, tokenIdOut, context]} = Transact(1, 2, 22, 18, 18);`

- Depths: state 22, keystore 18, **association set 18** (at most 262,144 leaves). Merkle gadget: zk-kit `BinaryMerkleRoot`, `Poseidon(2)`.
- Public signals in verifier order (`abstracts/TransactVerifierRouter.sol` lines 94–104): `nullifierHashes[N]`, `outputCommitments[M]`, then `stateRoot, keystoreRoot, associationSetRoot, amountOut, tokenIdOut, context`.
- Nullifier = `Poseidon(privateNullifyingKey, commitment)`, so it is deterministic per note.
- 27 Groth16 circuits (deposit, ragequit, 25 `transact_NxM`), BN254, circom 2.2.3, snarkjs 0.7.5. Constraint counts from `docs/tech-design/circuits/circuits-benchmark.md` ("Config E — current production"): transact_1x1 37,672; transact_2x2 63,916; transact_3x3 90,175; transact_5x5 142,741; deposit about 2.1K. The `.r1cs` files are Git LFS pointers in my clone, so I did not read the headers myself.
- Verified: `PoolVault.verifiers(keccak(1,1))` = `0x21347145497569b34efab7d73952208866520042`, `(1,2)` = `0x0e13d94235d8a0d8f9fc3b63bb41d666ef0677ed`, `(2,2)` = `0xac716f21626994c4264ea457fe208071050611b5`. The vault calls them with `staticcall`.
- The Consensys report (finding #017, root cause RC-04) confirms there is no domain separation: "Groth16 verification is a pure function of two inputs, the verifying key derived from the compiled circuit at trusted setup and the public signals the prover exposes. It reads no chain state ... so bytes that verify once verify anywhere the same verifying key is deployed." It lists every public-signal name across the 27 circuits; none names a chain, a vault or an ASP.

### 3.5 Ragequit (v2)

`contracts/PoolVault.sol` lines 206–218:

```solidity
  function ragequit(ProofLibV2.RagequitProof calldata _proof) external nonReentrant {
    PoolVaultStorage storage $ = _getPoolVaultStorage();
    require(msg.sender == _proof.ownerAddress(), PoolVault_InvalidOwnerAddress());
    require(_proof.value() != 0, PoolVault_ZeroValueRagequit());
    require(_commitmentExists(_proof.commitment()), PoolVault_CommitmentNotFound());

    uint256 _nullifierHash = _proof.nullifierHash();
    require(!_nullifierSpent(_nullifierHash), PoolVault_NullifierAlreadySpent());
    require($.keystore.isKnownRoot(_proof.keystoreRoot()), PoolVault_UnknownKeystoreRoot());
    require(
      $.ragequitVerifier.verifyProof({_pA: _proof.pA, _pB: _proof.pB, _pC: _proof.pC, _pubSignals: _proof.pubSignals}),
      PoolVault_InvalidRagequitProof()
    );
```

The caller must be the note's **current owner** (not the original depositor) and must be registered in the Keystore. Ragequit has no `whenNotPaused`. It also needs `stateTree.size + 1 <= maxStateTreeSize` (line 224), and the upgrader can lower that cap (`setMaxStateTreeSize`), which is the route L2BEAT describes for blocking ragequit.

### 3.6 Relay and fees (v2)

`PoolVault.transact` line 143: `require(_transactParams.processor == msg.sender, PoolVault_InvalidProcessor());`, and the context is `keccak256(abi.encode(_transactParams, _noteData)) % SNARK_SCALAR_FIELD` (line 147).

`contracts/PrivacyPoolRelay.sol` (immutable, no roles): `function relay(ProofLibV2.TransactProof calldata _proof, IPoolVault.TransactParams calldata _transactParams, IPoolVault.NoteData[] calldata _noteData) external payable`. Lines 237–249:

```solidity
    PayoutRouting memory _payout = abi.decode(_transactParams.data, (PayoutRouting));
    require(_payout.recipient != address(0), PrivacyPoolRelay_ZeroRecipient());
    require(msg.value == _payout.nativeGas, PrivacyPoolRelay_NativeGasMismatch());
    ...
    uint256 _maxRelayFee = ENTRYPOINT.assets(_asset).maxRelayFee;
    // `maxRelayFee == 0` means "no cap" per IEntrypoint (0 = no maximum) — matches RelaySwaps/MockPool/SDK.
    require(_maxRelayFee == 0 || _payout.feeAmount <= _maxRelayFee, PrivacyPoolRelay_FeeExceedsMax());
    require(_withdrawnValue >= _payout.feeAmount, PrivacyPoolRelay_FeeExceedsWithdrawal());

    address _feeRecipient = _payout.feeRecipient != address(0) ? _payout.feeRecipient : msg.sender;
```

`struct PayoutRouting { address recipient; address feeRecipient; uint256 feeAmount; uint256 nativeGas; }`

- Permissionless: no allowlist in the contract, and the processor can be any contract (`RelaySwaps` is a second one, owned by a different EOA).
- The fee is a nominal amount, bound into the context, and paid as a public transfer in the withdrawn asset. A relayed private transfer therefore shows a public fee withdrawal (L2BEAT: "A relayed transfer pays its fee as a public withdrawal to the relayer, so transfers are visible as events").
- The relayer package is `packages/relayer` (GPL-3.0-or-later; the launch post credits Fat Solutions). L2BEAT: "The contracts accept a proof from any address, and no relayer can change its recipient. A relayer other than 0xbow's needs the user's own build of the website or another client."

### 3.7 Upgradeability, owner, fees (v2)

- `PoolVault`, `Entrypoint`, `Keystore` and `ASPRegistry` are UUPS proxies with `_authorizeUpgrade(address) internal override checkAccess(UPGRADER_ROLE)`. The vault, which holds all funds, is upgradeable; v1 pools were not. Yield routers and `PrivacyPoolRelay` are immutable.
- Verified on-chain on the AccessRouter `0x40a6bC296D87f71Ab31Ca3Bfb50513441fBD5160`:
  - Safe `0xd563affc5ccA233514426e725c2d0b12C516a3e6` (threshold 2, owners `0x12Dbd633…4c92`, `0x652E36f8…13dA`, `0x98AdDcc7…E3c0`, `0xE8A2cC5c…Af77`) holds `DEFAULT_ADMIN_ROLE`, `OPS_ADMIN_ROLE`, `UPGRADER_ROLE`, `PAUSER_ROLE`, `UNPAUSER_ROLE` and `ENTRYPOINT_MANAGER_ROLE`. It does not hold `POSTMAN_ROLE`.
  - `getRoleAdmin(POSTMAN_ROLE)` = `OPS_ADMIN_ROLE`.
  - `hasRole(POSTMAN_ROLE, 0xa05B43E1dcdCe0c6A40471a602038BC346900758)` = true; that address has no code (an EOA).
  - The Safe's guard storage slot is zero. The design docs describe a Canon Guard timelock; none is installed. L2BEAT: "None of these roles has a delay". Two of the four signers are also signers of the v1 Safe.
- Powers: upgrade the four proxies; `setAspRegistry`, `setKeystore`, `setVerifier`, `setRagequitVerifier`, `setDepositVerifier`, `setMaxStateTreeSize`; `pause()` stops `deposit` and `transact`; `setAssetConfiguration` (enable, minimum, vetting fee, relay cap); `sweep` fees.
- Fee bound (`Entrypoint.sol` line 114): `require(_config.vettingFeeBPS < FeeCalculator.MAX_FEE_BPS, Entrypoint_InvalidFeeBPS());` with `MAX_FEE_BPS = 10_000`. The fee is charged on top of the deposit (`_amountPlusFees = _value + _fee`).
- Current values, verified: `assets()` for native ETH, ppETH, ppUSDT and ppUSDC all return `enabled = true`, **`vettingFeeBPS = 0`**; minimum 0.004 ETH or 10 units; `maxRelayFee` 0.5 ETH or 1,200 units. `rootHistorySize()` = 16, `maxStateTreeSize()` = 4,194,304, `paused()` = false. The yield shares keep up to 20% of Aave yield (L2BEAT).
- Other chains: the Consensys report says that on Arbitrum and Base "A single EOA holds `defaultAdmin`, `opsAdmin`, `upgrader`, `pauser`, `unpauser`, `entrypointManager` and `postman`" (as of Sept 2026). I did not check those chains.

## 4. The key question: verdict table

| Option | v1 (`privacy-pools-core`) | v2 (`privacy-pools-v2-monorepo`) | Verdict |
| --- | --- | --- | --- |
| **(a)** The pool accepts roots from a registry of several ASPs | No. One `associationSets` array on the Entrypoint, `latestRoot()` only, no ASP id in `WithdrawProof` or the circuit | No. One `associationSets` array in one `ASPRegistry`, `latestASPRoot()` only, one `aspRegistry` pointer per vault, no ASP id in `TransactProof`. No multi-ASP text anywhere in the repo; the only related future idea is `docs/tech-design/future-ideas/asp-detachment.md`, which is about hiding the deposit link from the single ASP | **Not available.** |
| **(b)** The postman role is granted to a contract (a Safe or a threshold-signature verifier) so a panel posts the root | Technically yes with no redeploy: `grantRole(ASP_POSTMAN, panelContract)` by the owner Safe. Proven by the fact that the Safe itself already holds `ASP_POSTMAN` on mainnet. The CID must be 32–64 characters | Technically yes: `grantRole(POSTMAN_ROLE, panelContract)` on the AccessRouter by the ops-admin Safe, since the check is `ACCESS_ROUTER.hasRole(_role, msg.sender)`. Alternatively the upgrader can call `setAspRegistry(newRegistry)` to point the vault at a panel-governed registry | **Possible only if 0xbow's 2/4 Safe does it.** It is a delegation, not an overlay. There is one root for all pools and the last writer wins, so 0xbow would also have to revoke its own postmen. It can re-grant, revoke or upgrade at any time with no delay. |
| **(c)** Off-chain or side-contract overlay: a second proof against a panel root | Yes, with no cooperation. Labels, depositors and values are public; labels are `keccak(SCOPE, nonce) % p`; the approved list is public on IPFS. The same circuit, zkey and verifier can prove membership of the same label in a panel tree | Partly. The circuit and verifiers are reusable in the same way, but the panel cannot see labels. Each depositor must give the panel the deposit opening (for example a second `registerLabel` ciphertext encrypted to the panel, or an off-chain message). The panel tree must use `Poseidon(label)` leaves and depth at most 18 | **This is the overlay that exists.** It is additive only. |

### 4.1 What "reuse unchanged" means for (c)

This is my reading of the circuit source plus the experiment in 2.5. I did not generate a new proof.

- In both circuits the ASP root is a public input constrained only by `root === MerkleRoot(leaf, path)`. Nothing ties it to 0xbow. A prover who holds the note secrets and a Merkle path in a panel tree can produce a valid proof with `ASPRoot` (v1) or `associationSetRoot` (v2) equal to the panel root.
- Panel tree format required: v1, LeanIMT, `Poseidon(2)`, leaf = label, depth at most 32. v2, same hashing, leaf = `Poseidon(label)`, depth at most 18.
- Verification: off-chain with `snarkjs.groth16.verify` and the committed vkey (v1 SDK `verifyWithdrawal`, v2 SDK `verifyTransact`), or on-chain by `staticcall` to the deployed verifier (v1 `0x022891F938Ae7fDC8Ab9Ead0FBf50aBA8C897D6d`; v2 one verifier per N×M).
- The verifier of the side proof must add the checks the pool would have made: that `stateRoot` is or was a real root of the pool (old roots are in `LeafInserted(_index, _leaf, _root)` events in v1 and `LeavesInserted(leaves, root, index)` in v2), that the ASP root is a root the panel signed, and whatever `context` means in this setting.
- SDKs already take the ASP data from the caller. v1 `proveWithdrawal(commitment, input)` takes `aspRoot`, `aspTreeDepth` and `aspMerkleProof` in `WithdrawalProofInput` (`packages/sdk/src/core/withdrawal.service.ts`). v2 `WitnessPreparationService` takes `aspLeaves` and derives `associationSetRoot` from them.

Does the side proof reveal the nullifier?

- Yes. It exposes `existingNullifierHash` (v1) or `nullifierHashes[]` (v2). These are deterministic for a note, so they equal the values the real withdrawal publishes (`Withdrawn(_processooor, _value, _spentNullifier, _newCommitment)` in v1, `Transacted(outputCommitments, nullifierHashes, …)` in v2).
- That is useful: it binds the association proof to one specific withdrawal, and after the withdrawal it reveals nothing that is not already on-chain. It does not reveal the label or the deposit.
- If the side proof is shown before the withdrawal, the verifier learns the future nullifier and can recognise the withdrawal when it lands.
- v2 caveat: a transact side proof also exposes output commitments and must be built for a specific N×M shape.
- Use a domain-separated `context` (for example a hash of a panel domain tag, the recipient and a verifier challenge). If the side proof used the real withdrawal context and the panel root happened to equal 0xbow's latest root, the side proof would be a valid withdrawal proof.

### 4.2 An on-chain form of the additive overlay (design inference, not tested)

Both versions let any contract be the withdrawal processor (`msg.sender != _withdrawal.processooor` in v1; `_transactParams.processor == msg.sender` in v2). v1's `BatchRelayer` and v2's `RelaySwaps` are existing examples. A panel could deploy its own processor that calls the pool with the normal 0xbow-root proof, checks a second proof against a panel root through the deployed verifier, and only then forwards the funds and emits an attestation event. This needs no change to 0xbow's contracts. It still requires 0xbow's approval of the same label.

### 4.3 What an overlay cannot do

- It cannot make a pool accept a label that 0xbow's latest root omits. Such funds leave only by ragequit: to the original depositor in v1, to the current note owner in v2.
- It cannot stop 0xbow from revoking. L2BEAT records two incidents on 11 Mar 2026: "The ASP posts a root no deposit belongs to, blocking every private withdrawal for two hours", and approved fxUSD deposits leaving the list for 13 days.
- In v2 it cannot rebuild 0xbow's set by observation (private labels, decoy leaves).

## 5. What 0xbow says about postmen, criteria and other ASPs

- `docs.privacypools.com/layers/asp` (fetched 9 Nov 2026; source file `docs/docs/layers/asp.md`, last changed 28 Feb 2025) still describes v1 only: "Interacts with Entrypoint via authorized postmen", "Only authorized postmen can update roots", "Latest root used for validation", "Labels can be removed from ASP set", "Original depositors can ragequit". It gives no screening criteria, no latency, and nothing on multiple or external ASPs.
- Two statements on that page do not match the code: it shows `bytes32 ipfsHash` (the code has `string ipfsCID`) and says "Circular buffer stores recent roots" (the ASP list is an append-only array; only state roots use a ring buffer).
- `docs/docs/layers/contracts/entrypoint.md`: "`ASP_POSTMAN`: Can update ASP roots that validate withdrawals".
- No public v2 documentation site was found. `docs.privacypools.com/v2` returns 404 and the sitemap lists v1 pages only. The v2 launch post's "docs" link points to `docs.privacypools.com`. The v2 design documents are in the monorepo under `docs/tech-design/`.
- v2 launch post (`0xbow.io/blog/privacy-pools-v2-is-live`, dated 20 Oct 2026): "Only funds approved by the Association Set Provider operated by 0xbow can transact privately, and approval can be revoked so the pool doesn't become tainted over time."
- 0xbow.io home page: "As the ASP is open-source, any privacy protocol or other party can implement their own version of the ASP to bolster their compliance" and "Other privacy protocols can integrate the ASP". This is about other protocols running an ASP, not about a second ASP for Privacy Pools. I found no ASP service source code in either repository; v2 ships only `packages/mock-asp`, a test tool.
- 0xbow also runs a separate "Tornado Cash Proof of Association (PoA)" app (home page; L2BEAT says the ASP "may ask for a Proof of Association").
- Changes after 20 Oct 2026: none to the ASP interface in either repository (v1 `main` last commit 24 Oct 2026 is CI only; v2 `main` last commit 20 Oct 2026). L2BEAT records, for v2, 26 Oct 2026: "Every AccessRouter admin role and the three yield shares moved from an EOA to a 2/4 Safe, without a delay"; for v1, 3 Nov 2026: USDT vetting fee 0 to 0.5%.

## 6. Audits, licences, addresses

### 6.1 Audits

| Version | Firm | Scope | Date | File |
| --- | --- | --- | --- | --- |
| v1 | Oxorio | Circuits | Final report 21 Feb 2025 (commits 56d5d48 to 8da36d5) | `privacy-pools-core/audit/circuits_audit_oxorio.md` |
| v1 | Oxorio | Contracts (7 contracts, 408 lines) | Final report 18 Mar 2025 (commits 2d4627b to 532eaa8) | `audit/contracts_audit_oxorio.md` |
| v1 | Auditware | Contracts | No date in the file; audit commit f0b8fe5; added to the repo 19 Mar 2025 | `audit/contracts_audit_auditware.md` |
| v1 | Oxorio | Entrypoint upgrade | 20 May 2025 (commit 238e359) | `audit/entrypoint_upgrade_audit_oxorio.md` |
| v2 | Auditware | "re-audit ... focused on the changes introduced since the previous review" | Audit commit 71263ca8; retest notes dated 25.8.2026; 1 Medium, 3 Low | `privacy-pools-v2-monorepo/audits/2026-08-auditware.md` |
| v2 | Consensys Diligence | Header: "minr vulnerability mining"; commit 638bf8f | Scanned 14 Sep 2026; 32 findings (1 High, 17 Medium, 14 Low); findings carry "Status: Open" in the file | `audits/2026-09-consensys-diligence.md` |

Repository links: `https://github.com/0xbow-io/privacy-pools-core/tree/main/audit` and `https://github.com/0xbow-io/privacy-pools-v2-monorepo/tree/main/audits`.

Trusted setup: v1 used Perpetual Powers of Tau contribution 80 plus a phase 2 with 514 (withdraw) and 513 (ragequit) contributions, finished March 2025. v2 ran `ppv2-ceremony` on 8–14 Jul 2026 with 500 contributions per circuit plus a RANDAO beacon. v2 beta verifiers used single-contributor keys from 1 Sep 2026 until rotation on 20 Oct 2026 (L2BEAT; `CHANGELOG.md` 1.0.1).

### 6.2 Licences

| Component | v1 | v2 |
| --- | --- | --- |
| Core contracts | **Apache-2.0** (SPDX headers; root `LICENSE`, "Copyright 2025 0XBOW LTD") | **BUSL-1.1**. Additional Use Grant: production use "limited to interacting with a Privacy Pools v2 protocol deployment that the Licensor operates or has authorized in writing"; "This grant does not permit deploying the Licensed Work, or any derivative work of it, as a protocol instance that is not an Authorized Deployment." Change Date 2030-10-14, Change License GPL-2.0-or-later. The interface files are BUSL-1.1 too |
| Generated Groth16 verifiers | GPL-3.0 (snarkjs header) | GPL-3.0-or-later (`NOTICE`) |
| Circuits | `package.json` says Apache-2.0; the `.circom` files have no SPDX header and include circomlib, which is GPL-3.0 | GPL-3.0-or-later |
| SDK | Apache-2.0 | MIT (`core-sdk`, `evm-sdk`, `stellar-sdk`, `mock-asp`) |
| Relayer | Apache-2.0 | GPL-3.0-or-later |

Consequence for the design: v1 code can be forked and redeployed. v2 contracts cannot be redeployed as a separate instance before 2030; a design that needs v2 features has to interact with 0xbow's deployment or write its own contracts.

### 6.3 Mainnet addresses

| Contract | v1 | v2 |
| --- | --- | --- |
| Entrypoint (proxy) | `0x6818809EefCe719E480a7526D76bD3e561526b46` | `0xca1e072236D231130059eeA6Bfceb7F4e9a1F0C3` |
| ETH pool / vault | `PrivacyPoolSimple` ETH `0xF241d57C6DebAe225c0F2e6eA1529373C9A9C9fB` (one pool per asset, 14 assets) | `PoolVault` `0x0Eb42804BF897662aF851370eaeAdcDBEC1b97ed` (one vault for all assets; ETH enters as ppETH `0x66051920D25af4E3596A8a46309F4D045F9D83B7`) |
| ASP roots | on the Entrypoint | `ASPRegistry` `0x259C0BEa1d783c202509BD3b2688d23b8AEf58B0` |
| Withdrawal / spend verifier | `0x022891F938Ae7fDC8Ab9Ead0FBf50aBA8C897D6d` | 25 transact verifiers, e.g. 1x1 `0x21347145497569b34efab7d73952208866520042` |
| Ragequit verifier | `0xa45ACa8604a73D80C551fAad6355A5c3A5565eC6` | `0x5a06582115953e2cabed8e6a0eeae35ba430118f` (deposit verifier `0xee96ca04d2ab2ec9a8803eb78f39b2875dff6fdf`) |
| Roles | on the Entrypoint | `AccessRouter` `0x40a6bC296D87f71Ab31Ca3Bfb50513441fBD5160` |
| Admin Safe (2/4) | `0xAd7f9A19E2598b6eFE0A25C84FB1c87F81eB7159` | `0xd563affc5ccA233514426e725c2d0b12C516a3e6` |
| Postman | EOA `0x1f4Fe25Cf802a0605229e0Dc497aAf653E86E187` and the Safe | EOA `0xa05B43E1dcdCe0c6A40471a602038BC346900758` |
| Relay contract | Entrypoint `relay()`; `BatchRelayer` (address not looked up) | `PrivacyPoolRelay` `0x01a8Fa4dbb60187aD8d3c3d08E7Fb8C14198A461`; `RelaySwaps` `0xd0395c08DD8eA7671a7A65bDca8E473e8E8260a8` |
| Keystore | none | `0x6E463391c79b7e1A88eF26E0B023f9A6C9938a71` |

Sources: v1 `packages/contracts/deployments/1.json` (branch `deploy/mainnet-prod`) and `docs/docs/deployments.md`; v2 L2BEAT and `packages/swaps/contracts/deployments-prod.json`. The cross-references (`ENTRYPOINT()`, `poolVault()`, `aspRegistry()`, `keystore()`, `ACCESS_ROUTER()`, `POOL()`) were read on-chain and agree.

## 7. Numbers

L2BEAT (ETHBEAT), Ethereum only, fetched 10 Nov 2026 00:13 UTC:

| Metric | Privacy Pools v1 | Privacy Pools v2 |
| --- | --- | --- |
| TVL | $8.65 M | $646.75 K |
| Assets tracked | 14 | 4 (ppETH, ppUSDT, ppUSDC, ETH) |
| Deposits 7D / 30D / total | 52 / 507 / 8.19 K | 150 / 460 / 583 |
| Active relayers 30D | 6 | 3 |
| Exit window | Infinite | None |
| Trusted setup | 61 phase-1 contributions; 513–514 phase-2 | 61 phase-1; 500 per circuit, 597 participants |
| Permissions | 2/4 Safe owns the Entrypoint and holds the postman role; an EOA is also postman; pools and verifiers immutable | 2/4 Safe holds all admin roles with no delay; postman is an EOA; another EOA owns RelaySwaps |

A snapshot 3 hours earlier (9 Nov 2026 about 21:10 UTC) showed $8.63 M and $646.64 K, with 580 v2 deposits.

DefiLlama, all chains, fetched 10 Nov 2026 00:13 UTC:

| Slug | TVL |
| --- | --- |
| `privacy-pools` (parent) | $9,335,333 |
| `privacy-pools-v1` | $8,660,399 |
| `privacy-pools-v2` | $674,934 |

Chain split of the parent on 9 Nov 2026: Ethereum $9,284,230; Arbitrum $23,747; Base $10,549; BSC $9,024; OP Mainnet $2,223; Citrea $44; Robinhood Chain $42. v1 holds about 93% of the value; v2 is three weeks old.

## 8. Could not verify

1. **No new side proof was generated.** Running the circuits or SDK would mean executing repository code. The claim that a proof with a panel ASP root verifies rests on the circuit source (the ASP root is a free public input) and on the experiment with an existing mainnet proof.
2. **v2 verifiers were not called.** I did not decode a v2 `transact` proof. The reuse claim for v2 rests on the source, on the `staticcall` in `TransactVerifierRouter`, and on Consensys finding #017.
3. **Deployed bytecode was not compared with the repositories by me.** L2BEAT reports reproducible verifier builds for both versions. That the current v1 implementation `0x15e3…1a2c` is commit 7ccea5c is an inference from dates (L2BEAT: unchanged "since 22 May 2025").
4. **Complete list of postmen.** `AccessControl` is not enumerable and the public RPCs refused the archive log queries. I confirmed the holders named above with `hasRole`; L2BEAT lists the same and no others.
5. **v2 on other chains** (Arbitrum, Base, OP Mainnet, BNB Chain, Robinhood Chain, Citrea): roles, addresses and fees were not read. The single-EOA statement for Arbitrum and Base comes from the September 2026 Consensys report and may be out of date.
6. **Audit completeness.** The earlier Auditware v2 review that the August 2026 "re-audit" refers to is not in the repository. No fix review for the 32 Consensys findings was found. The v1 Auditware report has no date in the file.
7. **0xbow's plans.** No statement about multi-ASP, external ASPs or "bring your own ASP" for Privacy Pools was found in the docs site, the six blog posts or either repository. X, Discord, forums and talks were not searched.
8. **ASP internals.** Screening criteria, the decoy policy (taken from L2BEAT), the ASP's X25519 key and the exact ciphertext layout were not examined. The ASP service itself is not in the public repositories.
9. **Licence questions.** Whether a third-party processor contract that imports the BUSL-1.1 interface files counts as "interacting with" an authorised deployment, and whether the v1 circuits' Apache-2.0 label is consistent with their use of GPL-3.0 circomlib, are legal questions I did not resolve.
10. **v2 constraint counts** come from the benchmark document, not from the `.r1cs` files (Git LFS, not downloaded).
11. **IPFS content** was fetched through one gateway (Pinata). I checked that the top node of each file equals the on-chain root, but did not recompute the Poseidon tree or the CID hash.
12. **L2BEAT v1 fee table** for assets other than ETH was not re-read on-chain.
