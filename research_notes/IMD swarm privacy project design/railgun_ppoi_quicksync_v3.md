# Railgun: PPOI node reachability and the quick-sync hook (v3)

Fetched 10 Nov 2026, 14:40–15:00 UTC. Read-only: no posts, no accounts, no transactions. Downloaded code was unpacked and grepped, never run. The only traffic to PPOI nodes was one `GET /` per published endpoint (§1d). Anything stated about runtime behaviour is from reading code, not from running it.

Scratch copies: `/tmp/claude-0/-home-user-claude/4107f7be-64fa-56df-982c-ff1f40a87dd3/scratchpad/railgun/` (`pkg_*` = npm tarballs, `src_*` = git archives).

## Verdicts

1. **PPOI node: an operator can use the public node `https://ppoi.fdi.network` without permission.** Railgun's docs call it "a public aggregator node run by the community", Railgun's newest SDK ships it as the default, Railway Wallet uses it, and it answered `GET /` from this machine with HTTP 200 and `access-control-allow-origin: *`. The node software has no client authentication. Self-hosting is possible as a fallback but weaker than it looks: the public source is 21 months old, and a self-run node still has to pull list data from an existing node. Confidence: medium-high. Not tested: an actual JSON-RPC call (not allowed under the task rules), terms of use, who operates the host.
2. **Quick-sync: replaceable by parameter in the engine, hard-wired in the wallet SDK.** `RailgunEngine.initForWallet` takes the two functions as arguments 4 and 5. `@railgun-community/wallet` 11.3.0 `startRailgunEngine` passes its own subgraph implementations and has no argument or setter for them. Without a fork there are two routes: reassign the two fields on the engine instance after `startRailgunEngine` (they are plain writable properties; `readonly` is TypeScript-only), or patch one call in `src/services/railgun/core/init.ts`. The engine checks quick-synced commitments against on-chain merkle roots; it does not check nullifiers or unshield events. Confidence: high on the code reading, medium on the reassignment route because it was not executed.

## Versions confirmed

| Component | Version | Source |
|---|---|---|
| `@railgun-community/engine` | 9.9.1 is `latest` on npm (published 2026-10-12T20:41Z). GitLab `railgun-protocol/community/engine` `main` HEAD is `39cd0e3c` "Release v9.9.1", tag `v9.9.1`. No newer commit. | `https://registry.npmjs.org/@railgun-community/engine`; `https://gitlab.com/api/v4/projects/85566131/repository/commits` |
| `@railgun-community/wallet` | 11.3.0 is `latest` on npm (2026-10-22T16:26Z). GitLab HEAD `dd5c5cc0` "Release v11.3.0". Depends on `engine ^9.9.1`, `shared-models ^8.2.1`. | npm registry; GitLab project 85566179 |
| `@railgun-community/shared-models` | 8.2.1 (2026-09-28) | npm registry |
| Broadcaster `ppoi-safe-broadcaster-example` | `package.json` 8.2.0, HEAD `0a30782b` (2026-10-21). Depends on `wallet ^11.2.0`, Node `>=22.23.4`. | GitLab project 85566239 |
| PPOI node `private-proof-of-innocence` | `packages/node/package.json` 2.0.0. GitHub `main` HEAD `4b1eaf6` (2025-02-13, "Update README.md"); `main` is the only branch, no tags. Not in the GitLab group (37 public projects listed, none is a PPOI node). npm `@railgun-community/proof-of-innocence` has only 1.0.0 from 2023-08-30. | `git clone --depth 1 https://github.com/Railgun-Community/private-proof-of-innocence.git`; GitLab group API |

npm tarball SHA-256: engine-9.9.1 `38cc56af…e4130f`, wallet-11.3.0 `9acd1f77…51e3df`, shared-models-8.2.1 `ce9f519d…75cf93`.

---

## 1. PPOI node reachability

### 1a. How the URL is configured

**Broadcaster 8.2.0** (`src/server/config/config-defaults.ts`, lines 39–44, GitLab `0a30782b`):

```ts
  poi: {
    /** Proof of Innocence aggregator node URL */
    nodeURL: [process.env.POI_NODE_URL ?? ''], // TODO: Add a default from community-run POI aggregator.

    dbDir: process.env.POI_DB ?? 'poi.db',
  },
```

- Env key: `POI_NODE_URL` (one URL). Config key: `configDefaults.poi.nodeURL` (array). Default: empty string.
- `src/MY-CONFIG.ts.example` lines 210–214: `// REQUIRED FOR Running on EVM Networks with POI enabled.` / `// configDefaults.poi.nodeURL = ['FQDN of your POI node'];` / `// NetworkChainID.Ethereum,          // requires poi-node configured, setup & set`.
- It is passed straight to the wallet SDK (`src/server/engine/engine-init.ts` lines 41–49):

```ts
  await startRailgunEngine(
    walletSource,
    levelDB,
    shouldDebug,
    artifactStore,
    false, // useNativeArtifacts
    false, // skipMerkletreeScans
    configDefaults.poi.nodeURL,
  );
```

- Second use, `src/server/transactions/poi-assurance.ts` lines 274–291: `throw new Error('No poi nodeURL configured')` if the first entry is `''`, then `new POINodeRequest(configDefaults.poi.nodeURL)`.
- The README does not document `POI_NODE_URL`; its storage table lists only `POI_DB`.

**Wallet SDK 11.3.0** (`src/services/railgun/core/init.ts`, line 142 onward; same in `dist/services/railgun/core/init.d.ts`):

```ts
export const startRailgunEngine = async (
  walletSource: string,
  db: AbstractLevelDOWN,
  shouldDebug: boolean,
  artifactStore: ArtifactStore,
  useNativeArtifacts: boolean,
  skipMerkletreeScans: boolean,
  poiNodeURLs?: string[],
  customPOILists?: POIList[],
  verboseScanLogging = false,
): Promise<void> => {
```

- `poiNodeURLs` — "List of POI aggregator node URLs, in order of priority." No default.
- A network with a `poi` config will not load without it (`src/services/railgun/core/load-provider.ts` lines 120–123): `throw new Error('This network requires Proof Of Innocence. Pass "poiNodeURL" to startRailgunEngine to initialize POI before loading this provider.')`.
- Transport is JSON-RPC 2.0 by `POST` to the URL itself, with fallback down the list (`dist/services/poi/poi-node-request.js`): `axios_1.default.post(url, payload)` with `payload = { jsonrpc: '2.0', method, params, id: Date.now() }`, 60 s timeout.
- Methods (`shared-models` 8.2.1, `dist/models/proof-of-innocence.js` lines 45–67): `ppoi_health`, `ppoi_node_status`, `ppoi_pois_per_list`, `ppoi_merkle_proofs`, `ppoi_validated_txid`, `ppoi_validate_txid_merkleroot`, `ppoi_validate_poi_merkleroots`, `ppoi_submit_transact_proof`, `ppoi_submit_legacy_transact_proofs`, `ppoi_submit_single_commitment_proofs`, and the node-to-node ones (`ppoi_poi_events`, `ppoi_poi_merkletree_leaves`, `ppoi_transact_proofs`, `ppoi_blocked_shields`, …).
- Required list, same file lines 37–43: one entry, key `efc6ddb59c098a13fb2b618fdae94c1c3a807abc8fb1837c93620c9143ee9e88`, "Chainalysis OFAC Sanctions API".

### 1b. Public PPOI node URLs that are published

| URL | Where | Quote |
|---|---|---|
| `https://ppoi.fdi.network` | Railgun docs, `https://docs.railgun.org/developer-guide/wallet/getting-started/5.-start-the-railgun-privacy-engine.md` | `// This is a public aggregator node run by the community. Depending on your requirements you may want to run your own node, or use a different node.` / `const poiNodeURLs: string[] = args?.ppoiNodes ?? [ "https://ppoi.fdi.network", ];` |
| same | Railgun's new SDK, `gitlab.com/railgun-protocol/reloaded/wallet-sdk`, `src/network-config.ts` lines 109–120, `@railgun-reloaded/wallet-sdk` 1.0.1-pre.15 (HEAD `d898aefe`, 2026-11-10) | `Default PPOI node URLs per chain ID … SDK-selected endpoints that may rotate; RailgunClientOptions.poiNodeUrls replaces them.` then `POI_NODE_URLS = { 1: ['https://ppoi.fdi.network'], 56: […], 137: […], 42161: […], 11155111: […] }` |
| same | Railway Wallet remote config, `https://www.railway.xyz/config/railway-config-v3.3.json` (v3.4, v3.5, v4.0 return 404) | `"proxyPoiAggregatorUrl": "https://ppoi.fdi.network"`, `"publicPoiAggregatorUrls": []`. Railway builds `poiNodeUrls = [remoteConfig.proxyPoiAggregatorUrl, ...remoteConfig.publicPoiAggregatorUrls]` (`desktop/src/services/engine/engine.tsx` lines 44–50, GitHub `Railway-Wallet/Railway-Wallet` `e9398a1`, 2026-10-05). |
| `https://ppoi-agg.horsewithsixlegs.xyz` | Railgun docs, `https://docs.railgun.org/developer-guide/wallet/org.md` (seen in `…/developer-guide/llms-full.txt` lines 367–370) | `// LEAVE THIS OUT IN PRODUCTION. This is a public aggregator node for testing purposes.` |
| `https://poi.us.proxy.railwayapi.xyz/node-status-v2/` and `https://poi-lb.us.proxy.railwayapi.xyz/node-status-v2/` | PPOI dashboard source, `packages/dashboard/src/constants/nodes.ts` lines 1–8, GitHub `4b1eaf6` | `const aggregatorNodeURL = 'https://poi.us.proxy.railwayapi.xyz/node-status-v2/';` `AggregatorDocuDB = 'https://poi-lb.us.proxy.railwayapi.xyz/node-status-v2/'` |

Both docs pages also say: "Please reach out in the RAILGUN builders groups for information on the public aggregator nodes run by the community."

Places with no public URL: broadcaster repo (default is `''`), wallet SDK 11.3.0 source and tests (tests stub the requester; `src/tests/setup.test.ts` passes `undefined, // poiNodeURL`), engine, shared-models, cookbook, waku-broadcaster-client, the PPOI repo README and `.env.example` (placeholders `https://agg-example.com`, `https://node-example.com`).

The earlier note's "no public default was found" is now out of date for the docs and for the reloaded SDK. It is still true for the broadcaster's own config.

### 1c. Is the node software open source and usable by a third party

- **Repo:** `https://github.com/Railgun-Community/private-proof-of-innocence`, monorepo with `packages/node`, `packages/dashboard`, `packages/api-test`.
- **Licence:** inconsistent. Root README: "This project is licensed under [GPL-3.0-only]." Root `package.json`, `packages/node/package.json` and the file `packages/node/LICENSE` all say MIT ("MIT License / Copyright (c) 2023 RAILGUN Community").
- **Requirements:** README: "Node.js version 16.20.x or higher", Yarn, MongoDB. `packages/node/package.json` pins `"@railgun-community/shared-models": "7.3.0"`, `"@railgun-community/wallet": "10.0.1"` (published 2024-05-28) as peer dependencies, and `engines.node >=16.20.1`. It needs an RPC per network and runs the wallet SDK's own engine and quick-sync internally (`src/engine/engine-init.ts`: `startRailgunEngineForPOINode(levelDB, shouldDebug, testArtifactStore, …)`).
- **Config** (`packages/node/src/main.ts`, `.env.example`): `PORT` (default `3010`), `HOST`, `DOCUMENT_DB_URL` (default `mongodb://localhost:27017`), `NODE_CONFIGS` (JSON array of `{name, nodeURL, listKey?}`), `LIST_PROVIDER=1` plus `pkey` for a list provider.
- **No client authentication.** `packages/node/src/api/api.ts`: CORS `origin: '*'`; `GET /` returns `{ status: 'ok' }`; `POST /` is JSON-RPC; the only protected route is `GET /perf` (basic auth). Submit and sync routes check only that the `listKey` is one the node knows (`if (!this.hasListKey(body.listKey)) throw new Error('Invalid listKey')`).
- **No allow-list between nodes, but a peer URL is required.** A node with empty `NODE_CONFIGS` does nothing useful: `sync/round-robin-syncer.ts` — `if (this.nodeConfigs.length === 0) { dbg('No connected nodes - not polling.'); return; }`. With a peer, it pulls by JSON-RPC `POST` to the peer's URL (`api/poi-node-request.ts`, `getNodeStatusAllNetworks`, `getPOIListEventRange`, …) and forwards wallet proofs to the peer registered for that list key (`proof-mempool/transact-proof-mempool.ts` lines 96–133: `const nodeURL = nodeURLForListKey(listKey); … POINodeRequest.submitTransactProof(nodeURL, …)`).
- **Pulled data is signature-checked**, so the peer need not be trusted for list contents: `poi-events/poi-event-list.ts` line 131 `const verified = await verifyPOIEvent(signedPOIEvent, listKey);` (Ed25519 against the list key, `util/ed25519.ts` lines 50–64). Same for blocked shields and validated txid roots.
- **What this means for a self-run aggregator.** It would set `NODE_CONFIGS=[{"name":"…","nodeURL":"https://ppoi.fdi.network","listKey":"efc6ddb5…9e88"}]` and depend on that host anyway for list events and for relaying proofs to the list provider. The list provider's own node URL is not published anywhere I looked. So self-hosting removes the dependency for wallet-facing reads, not for the data source.
- **Docs position:** "Like IPFS, anyone can run a Private Proofs of Innocence node." (`https://docs.railgun.org/wiki/assurance/private-proofs-of-innocence.md`).

### 1d. One status GET per endpoint (10 Nov 2026, from this machine)

| Endpoint | Result |
|---|---|
| `GET https://ppoi.fdi.network/` at 14:50:56Z | **HTTP 200.** Body: `{"status":"ok","message":"All services running normally","uptime":34268,"nodeType":"aggregator","timestamp":"2026-11-10T14:50:57.385Z"}`. Headers: `access-control-allow-origin: *`, `ratelimit-limit: 240`, `ratelimit-policy: 240;w=60`, `via: 1.1 Caddy`. |
| `GET https://ppoi-agg.horsewithsixlegs.xyz/` at 14:50:57Z | No HTTP status. This machine's egress proxy returned 502 on CONNECT ("host allowed, but the gateway could not connect to it"). |
| `GET https://poi.us.proxy.railwayapi.xyz/` at 14:50:57Z | No HTTP status. TLS connection reset after 10 s. |
| `GET https://poi-lb.us.proxy.railwayapi.xyz/` at 14:51:07Z | No HTTP status. TLS connection reset after 10 s. |

Two things to note about the live node. It rate-limits at 240 requests per 60 s. And its status body has fields (`message`, `uptime`, `nodeType`) that do not exist in the public GitHub source, where `getStatus()` returns only `{ status: 'ok' }` (`api/route-logic.ts` lines 75–77). The deployed node is therefore not the public `main`.

---

## 2. Quick-sync hook

### 2a. The hook

**Types** — engine 9.9.1, `src/models/event-types.ts` lines 19–23, 41–49, 74–79 (identical in `dist/models/event-types.d.ts`):

```ts
export type QuickSyncEvents = (
  txidVersion: TXIDVersion,
  chain: Chain,
  startingBlock: number,
) => Promise<AccumulatedEvents>;

export type QuickSyncRailgunTransactionsV2 = (
  chain: Chain,
  latestGraphID: Optional<string>,
) => Promise<RailgunTransactionV2[]>;

export type GetLatestValidatedRailgunTxid = (
  txidVersion: TXIDVersion,
  chain: Chain,
) => Promise<{ txidIndex: Optional<number>; merkleroot: Optional<string> }>;

export type AccumulatedEvents = {
  commitmentEvents: CommitmentEvent[];
  unshieldEvents: UnshieldStoredEvent[];
  nullifierEvents: Nullifier[];
  railgunTransactionEvents?: RailgunTransactionV3[];
};
```

**Injection point** — engine 9.9.1, `src/railgun-engine.ts` lines 163–188. The constructor is private; this static method is the only way in for a wallet:

```ts
  static async initForWallet(
    walletSource: string,
    leveldown: AbstractLevelDOWN,
    artifactGetter: ArtifactGetter,
    quickSyncEvents: QuickSyncEvents,
    quickSyncRailgunTransactionsV2: QuickSyncRailgunTransactionsV2,
    validateRailgunTxidMerkleroot: MerklerootValidator,
    getLatestValidatedRailgunTxid: GetLatestValidatedRailgunTxid,
    engineDebugger: Optional<EngineDebugger>,
    skipMerkletreeScans: boolean = false,
  )
```

Stored as instance fields (lines 104, 106, 138–139): `readonly quickSyncEvents: QuickSyncEvents;` `readonly quickSyncRailgunTransactionsV2: QuickSyncRailgunTransactionsV2;`. Called at line 488 (`await this.quickSyncEvents(txidVersion, chain, startScanningBlockQuickSync)`) and line 1006 (`await this.quickSyncRailgunTransactionsV2(chain, cursorGraphID)`). Both read the field at call time.

**Calling contract for `quickSyncEvents`** (`performQuickSync`, lines 469–520):
- `startingBlock` is the block of the newest valid commitment already stored, or the deployment block on a fresh database.
- Order of processing: `railgunTransactionEvents` (V3 only), unshields, nullifiers, then commitments.
- If it throws, the engine retries once, logs "Failed to quick sync", and carries on.
- A slow sync over RPC always follows, from the last valid commitment block to the chain tip (`scanUTXOHistory`, lines 591–700). A stale snapshot is therefore fine; the gap is filled from RPC. Returning empty arrays makes the whole history come from RPC.

**Calling contract for `quickSyncRailgunTransactionsV2`** (`performSyncRailgunTransactionsV2`):
- `latestGraphID` is the `graphID` of the newest record in the local TXID tree, or `undefined`.
- The engine calls again while a batch has exactly `getEngineTxidSyncBatchSize()` records, default 10,000 (`src/utils/txid-sync-batch-size.ts`: "a full batch implies 'more data remaining'; a partial batch terminates the loop"). A snapshot reader must page the same way.
- `graphID` format matters (`src/contracts/railgun-smart-wallet/V2/action-graph-id.ts`): "three 32-byte-padded big-endian integers concatenated under a single `0x`: block number, then the transaction's index within that block, then the record's index within that transaction. 192 hex characters total."

### 2b. What the function must return, and what the engine checks

Shapes (engine 9.9.1, `src/models/event-types.ts` and `src/models/formatted-types.ts`):

```ts
export type CommitmentEvent = {
  txid: string;
  treeNumber: number;
  startPosition: number;
  commitments: Commitment[];
  blockNumber: number;
};
// Commitment = ShieldCommitment | TransactCommitmentV2 | TransactCommitmentV3
//            | LegacyGeneratedCommitment | LegacyEncryptedCommitment
// shared fields: commitmentType, hash, txid, blockNumber, timestamp, utxoTree, utxoIndex
// ShieldCommitment adds: preImage {npk, token, value}, encryptedBundle[3], shieldKey, fee, from
// TransactCommitmentV2 adds: ciphertext {ciphertext{iv,tag,data[]}, blindedSenderViewingKey,
//   blindedReceiverViewingKey, annotationData, memo}, railgunTxid

export type Nullifier = { nullifier: string; treeNumber: number; txid: string; blockNumber: number };

export type UnshieldStoredEvent = {
  txid: string; timestamp: Optional<number>; toAddress: string; tokenType: number;
  tokenAddress: string; tokenSubID: string; amount: string; fee: string; blockNumber: number;
  eventLogIndex: Optional<number>; railgunTxid: Optional<string>; poisPerList: Optional<POIsPerList>;
};

export type RailgunTransactionV2 = {
  version: RailgunTransactionVersion.V2; graphID: string; commitments: string[]; nullifiers: string[];
  boundParamsHash: string; blockNumber: number; txid: string;
  unshield: Optional<UnshieldRailgunTransactionData>; utxoTreeIn: number; utxoTreeOut: number;
  utxoBatchStartPositionOut: number; timestamp: number; verificationHash: string;
};
```

The exact field encodings (32-byte hex without `0x`, checksummed addresses, hex amounts) are the ones produced by the wallet SDK's formatters in `src/services/railgun/quick-sync/V2/graph-type-formatters-v2.ts` (`formatGraphCommitmentEventsV2`, `formatGraphNullifierEventsV2`, `formatGraphUnshieldEventsV2`). A snapshot should store the output of those formatters.

**Commitments are checked against the chain.** The engine's own test says so (`src/__tests__/railgun-engine-quick-sync-validation.test.ts` lines 50–53): "Quick sync serves history from the subgraph, which is not trusted. Its leaves must pass the same merkleroot validation as leaves from the RPC before they are written."

The check, `src/merkletree/merkletree.ts` lines 549–600 (`insertLeaves`; `dist/merkletree/merkletree.js` lines 473–483):

```js
        const rootNode = hashWriteGroup[merkletree_types_1.TREE_DEPTH][0];
        const validRoot = await this.merklerootValidator(this.txidVersion, this.chain, tree, lastLeafIndex, rootNode);
        if (validRoot) {
            await this.validRootCallback(tree, lastLeafIndex);
        }
        else {
            await this.invalidRootCallback(tree, lastLeafIndex, leaves[leafIndex]);
            throw new Error(`${INVALID_MERKLE_ROOT_ERROR_MESSAGE} [${this.merkletreeType}] Tree ${tree}, startIndex ${startIndex}, group length ${leaves.length}.`);
        }
        // If new root is valid, write to DB.
        await this.writeTreeToDB(tree, hashWriteGroup, dataWriteGroup);
```

For the UTXO tree the validator is an `eth_call` to the Railgun contract. `src/railgun-engine.ts` lines 1802–1815 route to `src/contracts/railgun-smart-wallet/V2/railgun-smart-wallet.ts` lines 168–173:

```ts
  async validateMerkleroot(tree: number, root: string): Promise<boolean> {
    try {
      const isValidMerkleroot = await this.contract.rootHistory(
        tree,
        ByteUtils.formatToByteLength(root, ByteLength.UINT_256, true),
      );
```

A second pass re-checks every tree's current root after the scan (`src/railgun-engine.ts` lines 685–696): `throw new Error(\`Invalid merkleroot: ${root}. Tree: ${treeIndex}. Index: ${index}.\`)`.

Consequence for a snapshot format: **event boundaries must be preserved.** `commitmentListener` comment (`dist/railgun-engine.js` lines 129–132): "The contract records a merkleroot in rootHistory only where an insertLeaves call ends, and each commitment event is one insertLeaves call - so a write that ends on a group boundary has a root that can be validated." Each `CommitmentEvent` in the snapshot must be one on-chain batch, in order, with no gaps.

Decrypted notes are also bound to the validated hash (`src/wallet/abstract-wallet.ts` lines 600–602, 634, 698): `return noteHash === commitmentHash;` and "Discarding decrypted receive note: hash does not match commitment." / "Discarding shield note: preImage hash does not match commitment." A snapshot cannot make a wallet credit a note that is not on chain.

**Nullifiers and unshield events are not checked.** `src/merkletree/utxo-merkletree.ts` lines 140–152 writes them directly:

```ts
  async nullify(nullifiers: Nullifier[]): Promise<void> {
    const nullifierWriteBatch: PutBatch[] = nullifiers.map((nullifier) => ({
      type: 'put',
      key: this.getNullifierDBPath(nullifier.treeNumber, nullifier.nullifier).join(':'),
      value: nullifier.txid,
    }));
    return this.db.batch(nullifierWriteBatch);
  }
```

A wrong snapshot can therefore make a wallet show a spent note as unspent (the spend then fails on chain) or an unspent note as spent (funds hidden until a rescan from a good source). It cannot steal funds. The design should sign or hash-pin snapshot files for this reason.

**Railgun transactions (TXID tree) are checked against the PPOI node, not the chain.**
- Hash chain, `src/railgun-engine.ts` line 1537: `calculateRailgunTransactionVerificationHash(previousVerificationHash, nullifiers[0])` must equal the record's `verificationHash`, else "Stopping queue of Railgun TXIDs - Invalid verification hash." This is self-consistency only; the source supplies both sides.
- Cross-check with UTXO data: each record's commitments must already exist in the validated UTXO tree, else "Stopping queue of Railgun TXIDs - missing a commitment or unshield."
- Root check: line 2034 gives the TXID tree `this.validateRailgunTxidMerkleroot`, which the wallet SDK sets to a PPOI call (`dist/services/poi/wallet-poi.js`: `poiRequester.validateRailgunTxidMerkleroot(…)` → JSON-RPC `ppoi_validate_txid_merkleroot`). With no PPOI URL it returns `false` (`dist/services/poi/wallet-poi-requester.js`: `if (!this.poiNodeRequest) { return false; }`).
- The sync is also capped at the PPOI node's `ppoi_validated_txid` index.

So question 2 depends on question 1: a wallet cannot build its TXID tree, and so cannot make PPOI proofs, without a PPOI node, whatever the quick-sync source.

### 2c. Can an application replace quick-sync in `@railgun-community/wallet` without forking

Not by parameter. `src/services/railgun/core/init.ts` lines 160–171 (wallet 11.3.0, GitLab `dd5c5cc0`):

```ts
    const engine = await RailgunEngine.initForWallet(
      walletSource,
      db,
      artifactGetterDownloadJustInTime,
      quickSyncEventsGraph,
      quickSyncRailgunTransactionsV2,
      WalletPOI.getPOITxidMerklerootValidator(poiNodeURLs),
      WalletPOI.getPOILatestValidatedRailgunTxid(poiNodeURLs),
      shouldDebug ? createEngineDebugger(verboseScanLogging) : undefined,
      skipMerkletreeScans,
    );
    setEngine(engine);
```

`quickSyncEventsGraph` and `quickSyncRailgunTransactionsV2` are module imports (lines 25–26). A search of the SDK source for an override, setter or URL option found none. The endpoints are constants: `https://rail-squid.squids.live/squid-railgun-{ethereum,bsc,polygon,arbitrum,eth-sepolia}-v2/graphql` and, for Base, `https://base-indexer.railgun.org/graphql`. The docs agree: "QuickSync is automatically active during private balance scans and doesn't require any configuration."

Routes that avoid a fork, in order of preference:

1. **Reassign the two fields after start.** `getEngine` is exported from the package root (`src/services/railgun/core/engine.ts` line 6, re-exported through `core/index.ts` → `railgun/index.ts` → `services/index.ts` → `index.ts`). The fields compile to plain class fields (`dist/railgun-engine.js` lines 55–56: `quickSyncEvents;` `quickSyncRailgunTransactionsV2;`), and the engine reads them through `this.` at each call. `startRailgunEngine` does not scan. Scans start from `refreshBalances` (`src/services/railgun/wallets/balances.ts` line 18, `engine.scanContractHistory`) and from the event listeners that `loadProvider` → `engine.loadNetwork` installs, so nothing reads the fields before a network is loaded. So:

   ```ts
   await startRailgunEngine(walletSource, db, shouldDebug, artifactStore, false, false, poiNodeURLs);
   const engine = getEngine() as unknown as {
     quickSyncEvents: QuickSyncEvents;
     quickSyncRailgunTransactionsV2: QuickSyncRailgunTransactionsV2;
   };
   engine.quickSyncEvents = snapshotQuickSyncEvents;
   engine.quickSyncRailgunTransactionsV2 = snapshotQuickSyncRailgunTransactionsV2;
   await loadProvider(/* … */);
   ```

   This bypasses TypeScript's `readonly` and is not a supported API. Not executed here.
2. **Patch one call** in `dist/services/railgun/core/init.js` line 90 (source `init.ts` lines 164–165) with `patch-package` or equivalent. Two identifiers change.
3. **Build the engine yourself** with `RailgunEngine.initForWallet(…)` and call the exported `setEngine(engine)`. This does not work cleanly on PPOI networks: `WalletPOI` and `WalletPOINodeInterface` are not exported (`src/services/poi/index.ts` exports only `poi-required`, `poi-status-info`, `poi-node-request`, `poi-validation`), `package.json` `exports` allows only `"."` and `"./react-native-shims"`, and `loadProvider` throws while `WalletPOI.started` is false.

The broadcaster is in the same position: it calls `startRailgunEngine` and nothing else (`engine-init.ts` above), so route 1 or 2 applies to it too.

**Subgraph calls that the hook does not cover.** Replacing the two functions does not remove every subgraph dependency:
- `getRailgunTransactionsForTxid`, `getRailgunTxDataForUnshields`, `getRailgunTxidsForUnshields`, `getRailgunTransactionDataForUnshieldToAddress` in `src/services/railgun/railgun-txids/railgun-txid-sync-graph-v2.ts` query the same squid directly. The broadcaster calls the first one when submitting its fee-note proof (`src/server/transactions/poi-assurance.ts` lines 293–296).
- Engine 9.9.1 can read recent TXID records from chain logs instead of the subgraph, but only if the app opts in and only above a per-chain activation block: `setUseActionEventTxidSourceV2(enabled)` — "Off by default: the subgraph stays the sole writer until a deployment has opted in." The comment in `V2-action-events.ts` lines 73–79 says the subgraph "stays a hard requirement for `[deploymentBlock, activationBlock)`". Wallet SDK 11.3.0 never calls the setter. A snapshot is the only other way to fill that prefix. Activation blocks (`src/utils/constants.ts` lines 54–61, `ENGINE_V2_ACTION_EVENT_BLOCK_NUMBERS_EVM`): Ethereum 25753685, BNB Chain 115899634, Polygon 92007080, Arbitrum 494497454.

**Related work inside Railgun.** The `reloaded` group on GitLab has its own snapshot system: `@railgun-reloaded/snapshot` ("A package to create snapshot of railgun historical events"; `.rsnap` = brotli-compressed DAG-CBOR, identified by an IPFS CID) and `snapshot-publisher` (a daemon that reads the indexer, seals a range, uploads to IPFS and signs a manifest with Ed25519). It targets the new `@railgun-reloaded/*` SDK, not engine 9.9.1. Only the READMEs were read.

---

## Could not verify

| Item | Why |
|---|---|
| That `ppoi.fdi.network` serves `ppoi_*` JSON-RPC calls to an arbitrary client, and which list keys it carries | Only `GET /` was sent, per the task rules |
| Who operates `fdi.network`, any terms of use or uptime commitment | Nothing published was found. Railway's RPC proxy is on the same domain (`api.fdi.network`) |
| Whether 240 requests per 60 s is enough for a broadcaster, or for a self-run aggregator syncing from it | Not tested |
| What software the live node runs | Its status body does not match public `main`; no newer public source was found |
| Whether a node built from GitHub `main` (wallet SDK 10.0.1, shared-models 7.3.0) still syncs and interoperates | Not built or run |
| The list provider's node URL for the Chainalysis list | Not published in any source read |
| Whether `ppoi-agg.horsewithsixlegs.xyz` and the two `railwayapi.xyz` hosts are down, or only unreachable from this machine | One attempt each; failures were at connection level |
| That reassigning the engine fields works at runtime | Read from compiled output, not executed |
| That the squid and Base indexer endpoints are live | Not probed |
| Private repositories in the GitLab group | Only the public project list is visible |
| The exact contents and trust model of the `reloaded` snapshot manifest | READMEs only |

## Sources

- npm: `https://registry.npmjs.org/@railgun-community/{engine,wallet,shared-models,proof-of-innocence}` and the 9.9.1 / 11.3.0 / 8.2.1 / 10.0.1 tarballs.
- GitLab API: `https://gitlab.com/api/v4/groups/railgun-protocol/projects?include_subgroups=true`; archives of projects 85566131 (engine), 85566179 (wallet), 85566239 (broadcaster), 85566480 (reloaded wallet-sdk), 85566708 and 85843895 (snapshot READMEs), 85566201 (cookbook), 85566255 (waku client), 87672445 (nym-demo).
- GitHub: `Railgun-Community/private-proof-of-innocence` at `4b1eaf6`; `Railway-Wallet/Railway-Wallet` at `e9398a1`.
- Docs: `https://docs.railgun.org/developer-guide/llms-full.txt`, `…/developer-guide/wallet/getting-started/5.-start-the-railgun-privacy-engine.md`, `…/developer-guide/wallet/org.md`, `…/wiki/assurance/private-proofs-of-innocence.md`.
- Railway config: `https://www.railway.xyz/config/railway-config-v3.3.json`.
