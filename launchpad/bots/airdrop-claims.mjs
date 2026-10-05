// PondPad testnet: writes the claims file the site's $PONDPAD page reads for the test airdrop (D-72).
// The live testnet distributor has a placeholder root, so the site points at the test-only distributor that
// airdrop.mjs deployed (a real 104-wallet list of wallets derived from the testnet key, already activated).
// Same format as airdrop/snapshot.py's claims.json, plus the distributor address. Addresses and amounts only; no keys.
//   MASTER_KEY=… node airdrop-claims.mjs [distributor]
import { readFileSync, writeFileSync } from "node:fs";
import { concat, createPublicClient, defineChain, encodeAbiParameters, getAddress, http, keccak256, parseEther, toHex } from "viem";
import { privateKeyToAccount } from "viem/accounts";

const here = (p) => new URL(p, import.meta.url).pathname;
const MASTER_KEY = process.env.MASTER_KEY;
if (!MASTER_KEY) throw new Error("MASTER_KEY is required");
const RPC_URL = process.env.RPC_URL ?? "https://rpc.testnet.chain.robinhood.com";
const report = JSON.parse(readFileSync(here("reports/2026-10-05/airdrop-2026-10-05T12-13-21-359Z.json"), "utf8"));
const distributor = getAddress(process.argv[2] ?? report.distributor);

// The list exactly as airdrop.mjs builds it.
const derive = (label) => privateKeyToAccount(keccak256(concat([MASTER_KEY, toHex(`pondpad-testnet:${label}`)])));
const list = Array.from({ length: 104 }, (_, i) => ({ account: derive(`airdrop-${i}`).address, amount: parseEther(String(10_000 + 500 * i)) }));
const leafOf = (a, v) => keccak256(keccak256(encodeAbiParameters([{ type: "address" }, { type: "uint256" }], [a, v])));
const hashPair = (a, b) => (BigInt(a) < BigInt(b) ? keccak256(concat([a, b])) : keccak256(concat([b, a])));
const layers = [list.map((x) => leafOf(x.account, x.amount)).sort((a, b) => (BigInt(a) < BigInt(b) ? -1 : 1))];
while (layers.at(-1).length > 1) {
  const prev = layers.at(-1), next = [];
  for (let i = 0; i < prev.length; i += 2) next.push(i + 1 < prev.length ? hashPair(prev[i], prev[i + 1]) : prev[i]);
  layers.push(next);
}
const root = layers.at(-1)[0];
const proofOf = (a, v) => {
  let idx = layers[0].indexOf(leafOf(a, v));
  const proof = [];
  for (let l = 0; l < layers.length - 1; l++) {
    if ((idx ^ 1) < layers[l].length) proof.push(layers[l][idx ^ 1]);
    idx >>= 1;
  }
  return proof;
};

const d = JSON.parse(readFileSync(here("../contracts/deployments/46630.json"), "utf8"));
const chain = defineChain({ id: Number(d.chainId), name: "Robinhood Chain Testnet", nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 }, rpcUrls: { default: { http: [RPC_URL] } } });
const client = createPublicClient({ chain, transport: http(RPC_URL) });
const onchain = await client.readContract({ address: distributor, abi: [{ type: "function", name: "merkleRoot", inputs: [], outputs: [{ type: "bytes32" }], stateMutability: "view" }], functionName: "merkleRoot" });
if (onchain !== root) throw new Error(`root mismatch: built ${root}, distributor has ${onchain}`);

const claims = Object.fromEntries(list.map((x) => [x.account, { amount: x.amount.toString(), proof: proofOf(x.account, x.amount) }]));
const total = list.reduce((a, x) => a + x.amount, 0n);
const OUT = here("../frontend/public/airdrop-46630.json");
writeFileSync(OUT, JSON.stringify({ distributor, root, total: total.toString(), claims }));
console.log(`wrote ${OUT}: ${list.length} wallets, root ${root} (matches the distributor)`);
