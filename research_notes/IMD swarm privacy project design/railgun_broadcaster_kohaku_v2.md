# Railgun broadcasters, Kohaku, Helios: re-verification and code-level facts (v2)

Fetched 9 Nov 2026 (most sources) and 10 Nov 2026 00:13 UTC (TVL, fees, npm, GitLab activity, Helios release page). Read-only: no posts, no transactions, no code executed from downloads. On-chain values are `eth_call` / `eth_getStorageAt` reads against public RPCs.

Supersedes the Railgun, broadcaster, Kohaku, Helios parts of `ethereum_privacy_ecosystem.md` and `imd_and_swarm_tech.md` where they differ.

## 0. The three findings that change the Murmuration design

1. **Railway Wallet now allowlists broadcasters.** Since v5.26.1 (released 5 Oct 2026) the wallet only selects broadcasters whose 0zk address is in the `trustedFeeSigner` list of its remote config, which holds 4 addresses today. Anyone can still publish fee messages on Waku, but an independent broadcaster gets no traffic from Railway Wallet unless it is added to that list. The earlier note "anyone can run one … wallets pick the lowest fee" is no longer true for the main wallet.
2. **Railgun's code moved to GitLab, and the GitHub broadcaster repo is stale.** Current source is `gitlab.com/railgun-protocol/*` (group created May 2026, repos imported 19 Aug 2026). The GitHub `ppoi-safe-broadcaster-example` stopped at v8.0.0 on 10 Dec 2025 and points at Waku cluster 0; the live network is cluster 5, shard 1. An operator who follows the GitHub README joins the wrong network.
3. **Kohaku's Railgun package is a stub.** On `ethereum/kohaku` master, `@kohaku-eth/railgun` is "Placeholder package … Do not depend on this stub". Kohaku's working plugins are Privacy Pools and Tornado Cash. The Rust Railgun client is an experiment on a feature branch of `ethereum/kohaku-rs`.

## 1. Changed since the 3–8 Nov notes

"Changed" covers both real changes and corrections of what the earlier notes said. No Railgun or Kohaku commit, release or config change was found dated 8–10 Nov 2026.

| Topic | Earlier notes | Verified now | Source |
|---|---|---|---|
| Who gets broadcaster traffic | Anyone can run one; wallet picks lowest fee | Railway Wallet ≥5.26.1 uses an allowlist of 4 trusted fee signers; the client library also drops fees outside −10% / +30% of the trusted signers' average | §3 |
| Where the code lives | GitHub `Railgun-Community` | GitLab `railgun-protocol/{community,contracts,reloaded}`; GitHub copies are behind (broadcaster 8.0.0 vs 8.2.0, wallet 10.9.0 vs 11.3.0, engine 9.6.0 vs 9.9.1) | §2 |
| Waku network | "Waku (RLN-gated gossip, used by Railgun)" | Private cluster 5, shard 1 (`/waku/2/rs/5/1`), `rln-relay=false`, 3 bootstrap nodes under `rootedinprivacy.com` | §4 |
| What the broadcaster sees | "can read only the fee" (docs) | The whole populated transaction (`to`, full calldata, POI proofs) before anyone else; it can decrypt only its own fee note | §4 |
| PPOI lists | Five list providers | Docs still name five; the SDK constant that broadcasters and wallets enforce has one required list (Chainalysis OFAC Sanctions API) | §6 |
| EIP-7702 | Not mentioned | Broadcasters relay Type 4 transactions through `RelayAdapt7702` (mainnet `0x1F74b4339990Db761bC0168F20D294A3a141497e`) | §2, §5 |
| Proxy implementation | Not recorded | Upgraded at block 25,641,630 (29 Jul 2026) to `0xD662C4B1F22AcEb0BEaCdf3A493De6f478686A0C` | §5 |
| Kohaku × Railgun | "operational 4337 mempool relaying" | JS package is a placeholder; Rust client is an experiment branch with a `kohaku-railgun-paymaster` crate | §8 |
| Private reads in Kohaku | TEE + ORAM now, PIR later | Roadmap text unchanged (last edited 9 Oct 2025). Code that exists: a PIR + Tor experiment branch and a Tor provider. No TEE-ORAM code found | §8, §9 |
| Wallet transport privacy | Nym dApp mode | New EF standard `anon-rpc` (spec 0.4.0, 23 Oct 2026) with Tor, Nym and Nox workers; Railgun published a Nym demo on 15 Oct 2026. Railway Wallet itself ships neither | §10 |
| Railgun TVL | $109.9M | $106.0M (10 Nov 2026) | §7 |
| Helios | No version recorded | 0.12.0, 5 Oct 2026, MIT | §9 |

## 2. Broadcaster software today

### Repos and packages

| Component | Current location | Latest version and date | Licence |
|---|---|---|---|
| Broadcaster node (`ppoi-safe-broadcaster-example`) | https://gitlab.com/railgun-protocol/community/ppoi-safe-broadcaster-example | `package.json` 8.2.0; last commit `0a30782b`, 21 Oct 2026. Not on npm. Only git tags are from 2022 | `"license": "ISC"` in `package.json`; no LICENSE file in the repo |
| Wallet-side client (`waku-broadcaster-client`) | https://gitlab.com/railgun-protocol/community/waku-broadcaster-client | npm `@railgun-community/waku-broadcaster-client-node` and `-web` 10.0.1, 23 Sep 2026 | MIT |
| Wallet SDK | https://gitlab.com/railgun-protocol/community/wallet | npm `@railgun-community/wallet` 11.3.0, 22 Oct 2026 | MIT |
| Engine | https://gitlab.com/railgun-protocol/community/engine | npm `@railgun-community/engine` 9.9.1, 12 Oct 2026 | MIT |
| Shared models | https://gitlab.com/railgun-protocol/community/shared-models | npm 8.2.1, 28 Sep 2026 | MIT |
| Contracts | https://gitlab.com/railgun-protocol/contracts/contract | No tags; `main` last commit 15 Aug 2026 | UNLICENSED (§5) |
| PPOI node | https://github.com/Railgun-Community/private-proof-of-innocence (not in the GitLab group) | `packages/node` 2.0.0 | README says GPL-3.0-only; `package.json` says MIT |
| Old client `@railgun-community/waku-relayer-client` | npm | 4.8.3, 20 Dec 2023 (dead) | MIT |

Not found: any npm package named `railgun-broadcaster`, `@railgun-community/waku-broadcaster-client` (without `-node`/`-web`), or packages under `@railgun-privacy` (all 404 on the registry, 9 Nov 2026).

Sources: npm registry `https://registry.npmjs.org/<pkg>`; GitLab API `https://gitlab.com/api/v4/groups/railgun-protocol/projects?include_subgroups=true`; GitHub raw files for the stale copies (`https://raw.githubusercontent.com/Railgun-Community/ppoi-safe-broadcaster-example/main/package.json` shows `"version": "8.0.0"`, `"node": ">=16.15.0"`); GitHub commits page shows the last GitHub commit on 10 Dec 2025.

### What a node needs

From the GitLab README (`README.md`, commit `0a30782b`):

> - node 22.23.4+ (`.nvmrc` pins it; this release carries the October 2026 security fixes)
> - docker, if using docker
> - jq (cli utility for parsing json)
> - At least 1GB of RAM, at least 20GB of disk space

- **Start command heap.** `package.json`: `"start": "node --max-old-space-size=8192 dist/main.js"`. The README minimum is 1 GB, but the process is allowed 8 GB of heap. Real memory use was not measured.
- **Processes.** The docker stack runs one `nwaku` node (`wakuorg/nwaku:v0.37.1`) and one broadcaster container (`node:22.23.4-bookworm-slim`). Ports 60000/tcp, 8000/tcp (websocket) and 9000/udp must be reachable; the nwaku REST port 8645 stays internal.
- **Hot wallet.** A mnemonic (docker secret `MNEMONIC`) derives both the 0zk address that receives fees and the 0x wallets that pay gas. `config-networks.ts`: `// 0.15 ETH minimum for L1 availability.` A wallet below that is advertised as unavailable. Several HD indices can be used so more than one transaction is in flight.
- **RPC.** `fallbackProviderConfig` per chain; the operator is expected to add its own endpoint.
- **PPOI node URL.** Required for Ethereum and has no default. `config-defaults.ts`: `nodeURL: [process.env.POI_NODE_URL ?? ''], // TODO: Add a default from community-run POI aggregator.` `MY-CONFIG.ts.example`: `// NetworkChainID.Ethereum,          // requires poi-node configured, setup & set`.
- **Price feeds.** CoinGecko, DefiLlama, 0x and Uniswap price fetchers are in `src/server/api/`; API keys are optional.
- **Supported networks.** README: "Ethereum, BNB Chain, Polygon, Arbitrum and Base."

## 3. Is there an allowlist, and how does a wallet pick?

### Publishing is permissionless

Any node on the Waku cluster can publish a signed fee message. The client checks only the signature against the viewing key embedded in the advertised 0zk address (`handle-fees-message.ts`):

```ts
const { railgunAddress } = feeMessageData;
const { viewingPublicKey } = getRailgunWalletAddressData(railgunAddress);
const verified = await verifyBroadcasterSignature(signature, data, viewingPublicKey);
```

There is no on-chain broadcaster registry, stake or bond. The `RailgunRegistry` contract (mainnet `0xF361d49b40E44CB23e6138B4cB32607322d9B595`) is used to look up RelayAdapt7702 deployments, not broadcasters.

### Selection is gated in three layers

**Layer 1: trusted fee band (client library, all wallets that use it).** `trustedFeeSigner` is a required option of `WakuBroadcasterClient.start`. A fee from any other broadcaster is kept only if it is within −10% / +30% of the trusted signers' average fee for that token, and dropped when no trusted fee is present (`broadcaster-config.ts`, `handle-fees-message.ts`):

```ts
static authorizedFeeVariancePercentageLower = 0.10; // 10% lower variance
static authorizedFeeVariancePercentageUpper = 0.30; // 30% upper variance
...
if (feeAmount < minFee || feeAmount > maxFee) { return; }
} else {
  // No authorized fee, and we require one.
  return;
}
```

So an independent broadcaster cannot undercut by more than 10%.

**Layer 2: address allowlist (Railway Wallet).** `useBroadcasterAddressFilterUpdater.tsx` at tag `v5.26.1` and on `main`:

```ts
const allowlist = useMemo<Optional<string[]>>(() => {
  const trustedFeeSigner = remoteConfig.current?.trustedFeeSigner;
  ...
  return trustedFeeSigners.length > 0 ? trustedFeeSigners : undefined;
}, [remoteConfig]);
...
updateBroadcasterAddressFilters(allowlist, blocklist);
```

At tags `v5.24.21` and earlier the same file had `const allowlist: Optional<string[]> = undefined;`. The GitHub history of the file shows two commits: 27 May 2024 and 5 Oct 2026.

The production remote config (`https://www.railway.xyz/config/railway-config-v3.3.json`, fetched 9 Nov 2026) holds `"trustedFeeSigner"` with 4 `0zk1…` addresses, `"minVersionNumberWeb": "5.26.1"`, and `"minVersionNumberIOS"` / `"minVersionNumberAndroid"`: `"5.22.4"`. Web and desktop users are therefore forced onto the allowlisting version. Whether the current iOS and Android builds carry the same code was not checked directly; the mobile app shares `react-shared` with desktop, so it probably does once updated.

The wallet UI offers a block list only (`SettingsBroadcastersModal.tsx`: "Blocked Broadcasters"). There is no setting to add a broadcaster.

**Layer 3: ranking among those left.** `best-broadcaster.ts`:

```ts
const feeAmount = BigInt(a.tokenFee.feePerUnitGas) - BigInt(b.tokenFee.feePerUnitGas);
if (feeAmount === BigInt(0)) {
  return b.tokenFee.reliability - a.tokenFee.reliability;
}
return feeAmount > BigInt(0) ? 1 : -1;
```

- `findBestBroadcaster` takes the lowest fee; reliability only breaks ties. Railway calls this one (`useBestBroadcaster.tsx`) and re-checks every 30 s.
- `findRandomBroadcasterForToken(…, percentageThreshold = 5)` exists in the library: random choice among broadcasters within 5% of the cheapest. Railway's default flow does not use it.
- `reliability` is **self-reported** by the broadcaster in its own fee message (`getReliabilityRatio` from its local counters). `MIN_BROADCASTER_RELIABILITY_SCORE = 0.75` is defined in shared-models; where it is enforced was not traced.
- Also filtered out: `availableWallets === 0`, fee expiring within 40 s, broadcaster version outside 8.0.0–8.999.0, a RelayAdapt address not in the network's known list, and any broadcaster that requires a POI list key the wallet has not activated.

Other wallets built on the SDK set their own `trustedFeeSigner` and filters. Which values they use was not checked.

## 4. Wire protocol

### Transport

`docker/nwaku/config.toml` (GitLab):

```
relay=true
filter=true
lightpush=true
rln-relay=false
dns-discovery-url=["enrtree://APMYHUVNQWHJNPI5L2KQ765EMCKUAMRWPUH3U2QIKPK6XEV3OW442@discovery.rootedinprivacy.com"]
shard=[1]
cluster-id=5
num-shards-in-network=8
```

- **No RLN.** Railgun runs its own Waku cluster (id 5), not The Waku Network (cluster 1). Spam control is the fee-band and version filters above.
- **Broadcaster side:** nwaku relay node, driven over its REST API (`pubSubTopic: '/waku/2/rs/5/1'`, poll every 2 s, fee broadcast every 15 s).
- **Wallet side:** a Waku light node (`createLightNode`). It sends with light push (`this.waku.lightPush.send(encoder, { payload })`), receives with filter, and back-fills with store queries.
- **Fleet.** The DNS discovery tree resolved to 3 nodes on 9 Nov 2026 (45.76.230.253, 104.207.139.10, 45.76.18.7). Web clients default to `relay-a`, `relay-b` and `client-edge.rootedinprivacy.com` over WSS; the nwaku config adds two static nodes. Who operates `rootedinprivacy.com` was not established (the website did not answer).

### Content topics

`topics.ts` (identical on both sides):

```ts
fees: (chain) => `/railgun/v2/${chain.type}-${chain.id}-fees/json`,
transact: (chain) => `/railgun/v2/${chain.type}-${chain.id}-transact/json`,
transactResponse: (chain) => `/railgun/v2/${chain.type}-${chain.id}-transact-response/json`,
metrics: () => `/railgun/v2/metrics/json`,
```

Ethereum mainnet is `/railgun/v2/0-1-fees/json`, `/railgun/v2/0-1-transact/json`, `/railgun/v2/0-1-transact-response/json`.

### Fee message

`shared-models/src/models/broadcaster.ts`:

```ts
export type BroadcasterFeeMessageData = {
  fees: MapType<string>;        // token address -> hex fee per 1e18 wei of gas token
  feeExpiration: number;        // Date.now() + 5 minutes by default
  feesID: string;
  railgunAddress: string;
  identifier: Optional<string>;
  availableWallets: number;
  version: string;
  relayAdapt: string;
  relayAdapt7702?: string;
  requiredPOIListKeys: string[];
  reliability: number;
};
```

Sent as `{ data: <hex of the JSON>, signature }`, signed with the broadcaster wallet's viewing key (`signWithWalletViewingKey`).

### Transact request and what the broadcaster sees

Client (`wallet/src/services/railgun/util/crypto.ts`):

```ts
const randomPrivKey = ByteUtils.hexStringToBytes(getRandomBytes(32));
const randomPubKeyUint8Array = await getPublicViewingKey(randomPrivKey);
const sharedKey = await ed.getSharedSecret(randomPrivKey, externalPubKey);
const encryptedData = encryptJSONDataWithSharedKey(data, sharedKey);
```

The message is `{ method: 'transact', params: { pubkey, encryptedData } }`. Every broadcaster tries to decrypt every transact message with `ed.getSharedSecret(viewingPrivateKey, clientPubKey)`; failure means "Not intended receiver". The reply (`{ txHash }` or `{ error }`) is encrypted with the same shared key (AES-GCM-256) and published on the response topic.

Decrypted payload fields (`transact-method.ts`): `chainType, chainID, feesID, to, data, broadcasterViewingKey, useRelayAdapt, devLog, minVersion, maxVersion, minGasPrice, txidVersion, preTransactionPOIsPerTxidLeafPerList`, plus `authorization, maxFeePerGas, maxPriorityFeePerGas, gasLimit` for EIP-7702.

So the broadcaster holds:

- **The complete transaction it is about to publish:** `to` and full calldata, meaning nullifiers, commitments, note ciphertexts, the unshield preimage (recipient 0x address, token, amount) and, for RelayAdapt, the whole list of external calls. All of this becomes public on-chain; the broadcaster sees it first.
- **Its own fee note in clear.** It decrypts commitment index 0 with its viewing key (`extract-transaction-data-v2.ts`: `// Extract first commitment (index 0)`), checks token and amount, and rejects with `NO_BROADCASTER_FEE` or `REJECTED_PACKAGED_FEE` otherwise.
- **The pre-transaction POI proofs.**
- **Not** the sender's 0zk address, balance, or other notes, and not the sender's IP (the Waku service node the wallet light-pushes through sees that instead).

The Railgun docs sentence "its contents cannot be read by the Broadcaster, except for an amount of gas" (`https://docs.railgun.org/wiki/learn/privacy-system/community-broadcasters`) is true of the shielded note contents, not of the calldata.

### The user's payment

A shielded note to the broadcaster's 0zk address, created inside the same Railgun transaction as its first output commitment. The contract never names or pays a broadcaster.

## 5. Contract: binding, fees, upgradeability

### BoundParams

`contracts/logic/Globals.sol` (GitLab `contracts/contract`, `main`):

```solidity
struct BoundParams {
  uint16 treeNumber;
  uint72 minGasPrice; // Only for type 0 transactions
  UnshieldType unshield;
  uint64 chainID;
  address adaptContract;
  bytes32 adaptParams;
  // For unshields do not include an element in ciphertext array
  // Ciphertext array length = commitments - unshields
  CommitmentCiphertext[] commitmentCiphertext;
}
```

`RailgunLogic.validateTransaction`:

```solidity
if (tx.gasprice < _transaction.boundParams.minGasPrice) return (false, "Gas price too low", "");

// Adapt contract must either equal 0 or msg.sender
if (
  _transaction.boundParams.adaptContract != address(0) &&
  _transaction.boundParams.adaptContract != msg.sender
) return (false, "Invalid Adapt Contract as Sender", "");

if (_transaction.boundParams.chainID != block.chainid) return (false, "ChainID mismatch", "");
```

`Verifier.hashBoundParams` is `keccak256(abi.encode(_boundParams)) % SNARK_SCALAR_FIELD` and is a public input of the proof, alongside the merkle root, nullifiers and commitments.

What this means:

- **The transaction is not bound to a broadcaster's 0x address.** With `adaptContract == 0`, anyone may submit it. With RelayAdapt, `adaptParams` must equal `keccak256(abi.encode(nullifiers, _transactions.length, _actionData))`, which fixes the external calls but again not the sender.
- **The fee cannot be stolen or redirected.** The fee note is one of the commitments, and the commitments and ciphertexts are covered by the proof. A mempool copier who resubmits pays the gas and the fee note still goes to the original broadcaster's 0zk address.
- **Front-running can waste the broadcaster's gas.** If a copy lands first, the broadcaster's own transaction fails on the spent nullifiers. The broadcaster still receives the fee note. This is an inference from the code, not an observed event.
- **`minGasPrice` stops a broadcaster from underpaying gas.** It only works for legacy pricing, so broadcaster transactions are sent as Type 1 (`getEVMGasTypeForTransaction`: "Broadcaster transactions require overallBatchMinGasPrice. This is only supported by type 1 transactions."), or Type 4 for EIP-7702.

### Protocol fee

Read from the mainnet proxy `0xFA7093CDD9EE6932B4eb2c9e1cde7CE00B1FA4b9` on 9 Nov 2026 (two RPCs, block ≈ 26,379,950):

| Call | Result |
|---|---|
| `shieldFee()` | 25 (0.25%) |
| `unshieldFee()` | 25 (0.25%) |
| `nftFee()` | 0 |
| `treasury()` | `0xE8A8B458BcD1Ececc6b6b58F80929b29cCecFF40` |
| `owner()` | `0xB6d513f6222Ee92Fff975E901bd792E2513fB53B` (Delegator) |

The fee goes to the treasury, not to broadcasters:

```solidity
// Transfer fee to treasury
token.safeTransferFrom(address(msg.sender), treasury, fee);   // shield
...
// Transfer fee to treasury
token.safeTransfer(treasury, fee);                             // unshield
```

`changeFee` is `onlyOwner` and capped: `require(_shieldFee <= BASIS_POINTS / 2, "RailgunLogic: Shield Fee exceeds 50%")`.

### Upgradeability and governance

| Read | Result |
|---|---|
| EIP-1967 admin slot of the proxy | `0x4F8E20f55f879beE7Bc010Bd6bD2138B34aC65c8` (ProxyAdmin) |
| EIP-1967 implementation slot | `0xD662C4B1F22AcEb0BEaCdf3A493De6f478686A0C` |
| `ProxyAdmin.owner()` | Delegator `0xB6d5…B53B` |
| `Delegator.owner()` | Voting `0xc480F68A3dcC3EdD82134FAB45C14A0FcF1dA3CC` |

- The contract is upgradeable, and both upgrades and fee changes run through Delegator, which the RAIL staker Voting contract owns.
- `Voting.sol` constants: `QUORUM = 2000000e18`, `PROPOSAL_SPONSOR_THRESHOLD = 500000e18`, voting starts 2 days after sponsorship, yay window ends day 5, nay day 6, execution from day 7 to day 14.
- The `deployments` package lists the implementation at block 25,641,630, which is 29 Jul 2026 22:58 UTC. DefiLlama's methodology note for Railgun also mentions a treasury distribution change on 29 Jul 2026.
- Delegator can grant per-function permissions to other callers (`setPermission`). The current permission table was not read.

### Licence

Every Solidity file carries `// SPDX-License-Identifier: UNLICENSED`, and `package.json` has `"license": "UNLICENSED"`. The contract source grants no reuse rights. The TypeScript SDKs are MIT. This matters for "reuse": Murmuration can call the deployed contracts and run the MIT/ISC software, but cannot fork or redeploy the contracts under a licence.

### V3 and Railgun Connect

- `shared-models` 8.2.1: `supportsV3: false` for Ethereum, BNB Chain, Polygon, Arbitrum and Base; `true` only for Polygon Amoy, the deprecated Mumbai entry and Hardhat. V3 contract addresses for mainnet are `'' // TODO`.
- Docs (`/wiki/learn/common-misconceptions`): "Live contract version: RAILGUN V2, on Ethereum, Polygon, BSC, and Arbitrum." and "RAILGUN Connect is a WalletConnect-style plugin for RAILGUN wallets, currently in development."
- A rewrite called "reloaded" is in progress (`@railgun-reloaded/wallet-sdk` 1.0.1-pre.13). It is a new SDK, not a new contract.

### Audits

Not re-verified. The old docs URL `/wiki/assurance/audits-and-security` returns "Page Not Found" and the current wiki index lists no audits page. The earlier list (ABDK 07.2021, Zokyo 11.2021 and 02.2023) came from a secondary source.

## 6. PPOI

- **Still enforced at the broadcaster.** `process-transaction.ts`: `// DO NOT MODIFY. // WARNING: If you modify POI validation, you risk fees that aren't spendable, as they won't have valid POIs.` `validatePOI` calls `POIValidator.isValidSpendableTransaction` and throws `POI_INVALID` on failure. It is skipped only on networks where POI has not launched; mainnet launch block is 18,514,200.
- **Required lists are not an operator setting.** `waku-broadcaster.ts`: `requiredPOIListKeys, // DO NOT CHANGE : Required in order to make broadcaster fees spendable`. The value is `POI.getActiveListKeys()`, which is `POI_REQUIRED_LISTS` from shared-models plus any `customPOILists` passed at engine start. The reference broadcaster passes none.
- **One required list in code.** `shared-models/src/models/proof-of-innocence.ts`:

```ts
export const POI_REQUIRED_LISTS: POIList[] = [
  {
    key: 'efc6ddb59c098a13fb2b618fdae94c1c3a807abc8fb1837c93620c9143ee9e88',
    type: POIListType.Active,
    name: 'Chainalysis OFAC Sanctions API',
```

- **Docs still name five providers** (Elliptic, ScamSniffer, PureFi, SlowMist, Chainalysis Sanctions Oracle) at `/wiki/assurance/private-proofs-of-innocence`. Whether the other four run live list nodes was not verified.
- **What an operator can change.** Only by editing code. Dropping the list makes received fees unspendable in PPOI wallets. Adding a list makes wallets ignore the broadcaster unless they activated that list (`broadcaster-fee-cache.ts`: "requires POI list key …, which is not active").
- **List key type.** Ed25519. The PPOI node derives it from an env secret: `// Set env "LIST_PROVIDER=1" and "pkey=0xXXXX" to load a list provider.` and `throw new Error('You must configure ed25519 "pkey" variable in .env file.')`. A list provider subclasses `ListProvider` and implements `shouldAllowShield`.
- **How a provider is "added".** There is no on-chain registry. Anyone can run a list node; it becomes required only when its key is added to `POI_REQUIRED_LISTS` in a shared-models release, or when a wallet passes it as a custom list.
- **PPOI node requirements.** "Node.js version 16.20.x or higher", Yarn, MongoDB (README of `private-proof-of-innocence`).
- **Aggregators.** Railway uses `"proxyPoiAggregatorUrl": "https://ppoi.fdi.network"` and `"publicPoiAggregatorUrls": []`. Whether a third-party broadcaster may use that URL, or must run its own node, was not verified.
- **Shield wait.** `POI_SHIELD_PENDING_SEC = 60 * 60; // 1 hour`.

## 7. What a broadcaster earns, and Railgun numbers

### Fee formula (defaults, Ethereum)

Broadcaster quote (`calculate-token-fee.ts`, `config-fees.ts`, `config-networks.ts`):

```ts
const priceRatio = gasTokenPrice / tokenPrice;
const adjustedPriceRatio = priceRatio / fees.gasEstimateLimitToActualRatio;   // 1.25 on Ethereum
const profit = adjustedPriceRatio * fees.profit;                               // profitMargin: 0.15
const totalFeeRatio = adjustedPriceRatio + profit;
```

Wallet payment (`tx-gas-broadcaster-fee-estimator.ts`, `shared-models/src/utils/gas.ts`):

```ts
const maximumGas = calculateMaximumGas(gasDetails);          // gasEstimate * 1.2 * gasPrice
const tokenFee = (tokenFeePerUnitGas * maximumGas) / oneUnitGas;
```

Putting the defaults together, in gas-token value:

- Fee ≈ gasEstimate × gasPrice × 1.2 × 1.15 / 1.25 = **1.104 × (gas estimate × gas price)**.
- The broadcaster accepts down to 10% below its own calculation (`gasEstimateVarianceBuffer = 0.1`).
- Margin is therefore about 10% of estimated gas cost when the transaction uses its full estimate, and more when it uses less. Railgun docs say the same in words: "generally they are ~10% of the total gas."
- The margin scales with gas, not with the amount moved. At the 0.15 gwei base fee seen on 9 Nov 2026, a 1,000,000-gas relay costs 0.00015 ETH and earns roughly 0.000016 ETH. The gas figure is illustrative; typical gas per Railgun transaction was not measured.
- Fees arrive as shielded tokens. Turning them back into gas ETH means an unshield, which pays the 0.25% protocol fee, plus a swap. The built-in top-up does this but is off by default (`shouldTopUp: false`).
- All of these values are operator-configurable, but the client's −10% / +30% band around the trusted signers limits how far an operator can move.

### Railgun numbers

| Metric | Value | Source and date |
|---|---|---|
| TVL | $106,002,805 | `https://api.llama.fi/tvl/railgun`, 10 Nov 2026 00:13 UTC |
| TVL by chain | Ethereum $101.9M, Arbitrum $3.0M, BNB $0.89M, Polygon $0.43M | `https://api.llama.fi/protocol/railgun`, 9 Nov 2026 |
| Peak TVL | $137.9M on 14 Aug 2025 | same |
| Fees, 30 days | $311,998 | `https://api.llama.fi/summary/fees/railgun`, 10 Nov 2026 |
| Fees, 7 days / 24 h | $66,621 / $8,560 | same |
| Fees, 1 year / all time | $4,059,019 / $14,138,951 | same |
| Implied 30-day shield + unshield volume | about $125M | $311,998 ÷ 0.25%; an inference, not a reported figure |
| Active broadcasters | No dashboard found | See below |

Proxies for the broadcaster count: Railway's allowlist has 4 addresses, and the Waku discovery tree has 3 bootstrap nodes. Counting live fee messages would need a Waku node on cluster 5, which was not run.

At a 10% margin on gas, total broadcaster income is a small fraction of the $312k per month of protocol fees, because protocol fees scale with volume and broadcaster income scales with gas. The total was not measured.

## 8. Kohaku on 10 Nov 2026

- **No stable release.** Every GitHub release is marked pre-release. Newest: `@kohaku-eth/tornado-cash@0.1.0-alpha.36` (7 Nov 2026) and `@kohaku-eth/privacy-pools@0.1.0-alpha.38` (5 Nov 2026). Last commit on `master`: 7 Nov 2026, "Version Packages (alpha) (#384)". Nothing dated 8–10 Nov.
- **README warning:** "Some parts of this project are work in progress and NOT READY FOR PRODUCTION USE. Packages contain UNAUDITED CODE." A 2 Nov 2026 commit is titled "fix: final audit fixes (#376)"; which audit, and its scope, were not found.
- **npm packages (`@kohaku-eth/*`), all MIT:**

| Package | Newest publish | State per README |
|---|---|---|
| `privacy-pools` | 0.1.0-alpha.38, 5 Nov 2026 | Working |
| `tornado-cash` | 0.1.0-alpha.36, 7 Nov 2026 | Working |
| `plugins` | 0.0.1-alpha.20, 28 Oct 2026 | Working (common plugin interface) |
| `provider` | 0.1.0-alpha.14, 28 Oct 2026 | Working: "Omni provider helpers that wrap Ethers, Viem, Helios, and Colibri", plus an `anon` adapter |
| `railgun` | 0.0.1-alpha.31, 22 Sep 2026 | "railgun shielded pool protocol lib (currently under mainenance)"; the package on master is a placeholder with `"private": true` |
| `social-recovery` | 0.0.1-alpha.1, 30 Oct 2026 | Interfaces only |
| `pq-account` | Not on npm | Post-quantum 4337 account |

- **Docs landing page:** "Add shield and unshield for Privacy Pools and Tornado Cash." Railgun is not offered.
- **Rust side (`ethereum/kohaku-rs`, first release 26 Oct 2026, last commit 29 Oct 2026):** crates for Tornado Cash, `kohaku-userop-kit` (4337), `kohaku-tor-rpc` ("Alloy JSON-RPC over Arti"). Listed as experiments: `kohaku-privacy-rpc` (PIR + Tor) and `kohaku-railgun` (branch `feat/kohaku-railgun`, with `railgun-poi` and `railgun-paymaster` crates).
- **Modules asked about:**

| Module | State |
|---|---|
| Railgun | Stub in JS; experiment branch in Rust |
| Privacy Pools | Alpha, active |
| Helios / Colibri light client | Provider adapters exist (`@a16z/helios >=0.11`, `@corpus-core/colibri-stateless >=3.0.0 <4`) |
| Oblivious reads (TEE + ORAM) | No code found in the Kohaku repos |
| PIR reads | Experiment branch `experiments/pir-v1` in kohaku-rs |
| P2P broadcast bypassing RPC | No code found; relaying is via 4337 bundler (`@pimlico/alto` dev dependency, paymaster broadcasters for Tornado Cash and Privacy Pools) |

- **Reference wallet (`ethereum/kohaku-extension`):** GPL-3.0, no releases or tags. README: "It's a work in progress and currently under active development." and "The only network it supports is Sepolia Testnet."; the demo is a "pre-built version (March 2026)". Its `package.json` still pins old alphas (`@kohaku-eth/railgun` 0.0.1-alpha.8).
- **Roadmap note** (`https://notes.ethereum.org/@niard/KohakuRoadmap`): text unchanged from the earlier notes; page metadata shows the last edit on 9 Oct 2025. No release date in it.
- **Announcements since 8 Nov / Devconnect or Devcon dates:** not searched this session.

## 9. Helios and private reads

- **Helios 0.12.0**, released 5 Oct 2026 (GitHub release marked Latest; npm `@a16z/helios` 0.12.0 published the same day). Release notes: "glamsterdam support", "bug fixes". Licence MIT ("Copyright (c) 2022-2026 a16z").
- **Headless local RPC:** yes by design. `helios ethereum --execution-rpc $ETH_RPC_URL` serves JSON-RPC on port 8545, bound to 127.0.0.1 unless `--rpc-bind-ip 0.0.0.0`. The upstream RPC must support `eth_getProof`. Default consensus source is `https://www.lightclientdata.org`, "run by us" (a16z).
- **Footprint:** README says it "syncs in seconds, requires no storage, and is lightweight enough to run on mobile devices"; the only disk state is a 32-byte checkpoint. No RAM figure is documented and none was measured, so "fits a 2 vCPU / 4 GB VPS" is plausible but not verified.
- **Helios verifies, it does not hide.** The upstream RPC still sees every query. Kohaku's Helios adapter can also bypass verification for logs: "`eth_getLogs` is only possible for requests within the latest 8,191 blocks range and it may be very slow."
- **Oblivious `eth_call` (TEE + ORAM):** no maintained public implementation was found in the repos read. It remains a roadmap sentence with Oblivious Labs named as collaborator. Other candidates (Flashbots TDX RPC, PSE projects) were not searched this session.
- **What exists instead:**
  - `kohaku-privacy-rpc` (experiment): "dual-endpoint Ethereum provider: PIR for private account reads, fallback JSON-RPC for everything else. Can also enable Tor". It covers balance, nonce and code for accounts, `balanceOf` for USDC, USDT, DAI and WETH, and name lookups. It is not general `eth_call`. It needs a PIR server; who runs one publicly was not established.
  - Colibri (`@corpus-core/colibri-stateless`): a stateless verifying client, the default provider in the Kohaku extension. It verifies; it is not oblivious.

## 10. Transport privacy for wallets

- **Railway Wallet:** no Tor or mixnet. A file-name search of all 1,464 files on `main` for tor, socks, nym, onion, vpn, mixnet and i2p found nothing, and no such dependency is in the desktop or mobile `package.json`. RPC goes through `"proxyApiUrl": "https://api.fdi.network"` and PPOI through `https://ppoi.fdi.network`; the Waku light node connects straight to the `rootedinprivacy.com` peers. Those operators see the user's IP.
- **Railgun + Nym demo** (`gitlab.com/railgun-protocol/reloaded/nym-demo`, 15 Oct 2026): "shields native ETH on Sepolia or Ethereum mainnet, over a direct connection or over the Nym mixnet". It passes `@nymproject/mix-fetch ^3.0.0` as the fetch function for indexer, PPOI and RPC calls. Browser only, a demo of the new SDK, not a wallet default, and it does not cover Waku.
- **anon-rpc** (`github.com/ethereum/anon-rpc`, MIT, spec 0.4.0 dated 23 Oct 2026): "A standard that lets a wallet or application make anonymized RPC requests by running hash-pinned client code inside a sandboxed worker". `adopters.json5` lists workers `tor-js` (Tor in WebAssembly), `nym` (about 18 MB bundle) and `nox` (Sphinx mixnet, specifier on Sepolia). Apps listed: Privacy Pools v2 web app ("Connect with Tor … Off by default") and Kiwi News. No wallet is listed. Kohaku's provider has an `anon` adapter for it.
- **tor-js** (`github.com/ethereum/tor-js`, npm 0.4.4 on 29 Oct 2026, MIT OR Apache-2.0, status "Experimental"): browsers need a **gateway**, "a small server that proxies relay connections and serves a fast-bootstrap snapshot of the Tor directory". Gateway README: "The gateway never sees your traffic or knows your destination — it just relays encrypted bytes to Tor relays." The public demo gateway is "for demonstration only … run your own for anything real". It builds with Rust 1.91+ and listens on one UDP port.
- **Nym dApp mode / SDK price and production status:** not re-verified this session.
- **Waku RLN on mainnet, membership price:** not re-verified this session. It does not affect Railgun, which does not use RLN.

## 11. What an independent operator can run TODAY with zero new contracts and zero new protocol code

Ordered by how much real use it would get.

| # | Component | Software | Works unchanged? | Caveat |
|---|---|---|---|---|
| 1 | tor-js gateway | `ethereum/tor-js`, `crates/tor-js-gateway` | Yes | Experimental. Apps choose their gateways, so the address must be handed to wallets or apps out of band. No payment mechanism |
| 2 | Helios as a local verified RPC | `a16z/helios` 0.12.0 | Yes | Verifies upstream data; does not hide queries. Needs an upstream with `eth_getProof` |
| 3 | Waku relay node on Railgun's cluster 5 | `wakuorg/nwaku:v0.37.1` with the repo's `config.toml` | Yes | Adds relay capacity. Wallets only reach it if it is discoverable (peer exchange, or added to the DNS tree by its owner). No payment |
| 4 | Railgun broadcaster | GitLab `ppoi-safe-broadcaster-example` 8.2.0 | Runs unchanged | **Receives no Railway Wallet traffic unless its 0zk address is added to Railway's `trustedFeeSigner` list**, and must price within −10% / +30% of the trusted signers. Needs ≥0.15 ETH per gas wallet, an RPC and a PPOI node URL |
| 5 | PPOI node (non-list) | `private-proof-of-innocence` | Yes | Needs MongoDB. Lets a broadcaster avoid depending on someone else's aggregator |
| 6 | PPOI list provider | same repo, `LIST_PROVIDER=1` | Runs | Has no effect until a wallet activates its Ed25519 list key |
| 7 | PIR read server | `kohaku-rs` experiment branch | Not ready | Experiment; server side not examined |

Reuse verdict:

- **Reusable unchanged:** nwaku, the broadcaster node, the waku-broadcaster-client library, the wallet SDK, Helios, the tor-js gateway, the deployed Railgun contracts (as a service to call).
- **Needs a thin wrapper (configuration and ops, no protocol change):** packaging the broadcaster with its own RPC, PPOI node and gas top-up; a wallet build or wallet configuration whose `trustedFeeSigner` and allowlist include the swarm's broadcasters (the library accepts an array, so this is a config value in any wallet Murmuration controls); publishing gateway addresses.
- **Would be new code or needs someone else's decision:** getting traffic from Railway Wallet (their remote config, not ours); any on-chain registry, stake or rotation for broadcasters (none exists); random or reliability-weighted selection as a default (the function exists, wallets do not call it); Waku traffic over Tor or a mixnet; oblivious `eth_call`.
- **Cannot be reused as source:** the Railgun contracts are UNLICENSED.

## 12. Could not verify

| Item | Why |
|---|---|
| Number of active broadcasters; who operates the 4 allowlisted addresses | No public dashboard found; counting needs a live Waku node on cluster 5, which was not run |
| Who operates `rootedinprivacy.com` and `fdi.network` | Website unreachable through the proxy; no ownership statement in the repos read |
| Whether Railway's iOS and Android builds enforce the allowlist | Only the shared desktop code and the remote config were read; mobile minimum version is 5.22.4, which predates the change |
| `trustedFeeSigner` values and filters in wallets other than Railway | Not checked |
| Real RAM use of the broadcaster and of Helios | Not measured; downloads were read, not run. README says 1 GB, start script allows an 8 GB heap |
| Whether `https://ppoi.fdi.network` or any public aggregator is open to third-party broadcasters | Not tested |
| Whether Elliptic, ScamSniffer, PureFi and SlowMist run live lists | Only the SDK constant (one list) and the docs page (five names) were read |
| Where `MIN_BROADCASTER_RELIABILITY_SCORE = 0.75` is enforced | Constant found; usage not traced |
| Current Delegator permission table (who besides Voting can call what) | Not read on-chain |
| Railgun audit list and dates | Old docs page is gone; not found in the current wiki index |
| Licence of the broadcaster repo beyond `"license": "ISC"` | No LICENSE file in the repo |
| Licence of the PPOI node | README says GPL-3.0-only, `package.json` says MIT |
| Total broadcaster income per month; typical gas per Railgun transaction | Not measured |
| Which audit Kohaku's "final audit fixes" commit refers to | Commit title only |
| Kohaku announcements since 8 Nov; Devconnect / Devcon dates | Not searched this session |
| Maintained TEE-ORAM RPC outside the Kohaku repos (Flashbots, PSE, Oblivious Labs) | Not searched this session |
| Nym dApp mode / SDK price and production status; Waku RLN mainnet status and membership price | Not re-checked this session |
| What changed in Helios 0.12.0 beyond "glamsterdam support" and "bug fixes" | Release page summary only |
| Whether a front-run copy of a broadcaster transaction has ever happened | Inference from contract code only |
