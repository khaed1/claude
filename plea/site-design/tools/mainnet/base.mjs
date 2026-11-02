// The Ethereum counterpart of fork-base.sh: on a fork made by deploy.mjs (owner impersonated, not seeded), builds a
// seeded PLEA court for the site's Ethereum tests and dumps it.
//   node base.mjs <port> <deploy out dir>       (writes <dir>/base.json, <dir>/base.hex, <dir>/claims.json)
// The owner seeds and makes the 2 IMD opening buy through the Universal Router; players p1..p8 (fixed addresses,
// impersonated, no keys) get 1 ETH and 30 IMD each from an IMD holder; a distributor root gives each 2,500,000 PLEA
// (claimed: "received PLEA") and the owner 20,000,000; the launch window is warped past; p1..p4 buy 5 IMD each
// (a buy record); identity.md seat #558 moves to p5. Only ever against a local anvil.
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import {
  createPublicClient, createWalletClient, http, parseEther, parseAbi, toHex, keccak256, encodePacked, formatEther,
} from "viem";
import { mainnet } from "viem/chains";
import { encodeBuy, universalRouterAbi, permit2Abi, PERMIT2 } from "/home/user/ps-mainnet/web/src/universal-router.ts";

const [PORT, DIR] = process.argv.slice(2);
const RPC = `http://127.0.0.1:${PORT}`;
const S = JSON.parse(readFileSync(join(DIR, "addresses.json"), "utf8"));
const IMD = "0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7";
const WHALE = "0xe54d6571aca515614927f3a70b8957c2b511603c";
const SEAT = "0x0000ec93127baa929e58e97dd0095a2bfb38ec1d", SEAT_ID = 558n, SEAT_HOLDER = "0xf98c3bf5f3544f64e60560304b58dca900a3c4db";
const ROUTER = { address: "0x23617e59a5925b2a4bf75d73ff6711cd0b29de85", minHopPrice: true };
const P = Array.from({ length: 8 }, (_, i) => `0x${(0xa110 + i + 1).toString(16).padStart(4, "0")}${"00".repeat(18)}`.toLowerCase());
const pub = createPublicClient({ transport: http(RPC), chain: mainnet });
const rpc = (m, p = []) => pub.request({ method: m, params: p });
const as = async (a, eth = "10") => {
  await rpc("anvil_impersonateAccount", [a]);
  await rpc("anvil_setBalance", [a, toHex(parseEther(eth))]);
  return createWalletClient({ account: a, transport: http(RPC), chain: mainnet });
};
const erc20 = parseAbi(["function balanceOf(address) view returns (uint256)", "function transfer(address,uint256) returns (bool)", "function approve(address,uint256) returns (bool)"]);
const write = async (w, address, abi, functionName, args) => {
  const gas = await pub.estimateContractGas({ address, abi, functionName, args, account: w.account });
  const r = await pub.waitForTransactionReceipt({ hash: await w.writeContract({ address, abi, functionName, args, gas: (gas * 13n + 9n) / 10n }) });
  if (r.status !== "success") throw Error(`${functionName} reverted`);
  return r;
};
const hookAbi = parseAbi(["function poolKey() view returns ((address currency0, address currency1, uint24 fee, int24 tickSpacing, address hooks))"]);
async function buy(w, imd) {
  const amountIn = parseEther(imd);
  const key = await pub.readContract({ address: S.PleaHook, abi: hookAbi, functionName: "poolKey" });
  const before = await pub.readContract({ address: S.PLEA, abi: erc20, functionName: "balanceOf", args: [w.account.address] });
  await write(w, IMD, erc20, "approve", [PERMIT2, amountIn]);
  const now = Number((await pub.getBlock()).timestamp);
  await write(w, PERMIT2, permit2Abi, "approve", [IMD, ROUTER.address, amountIn, now + 1800]);
  const { commands, inputs } = encodeBuy({ router: ROUTER, key, imd: IMD, buyer: w.account.address, amountIn, minPleaOut: 1n, pleaBalance: before });
  await write(w, ROUTER.address, universalRouterAbi, "execute", [commands, inputs, BigInt(now + 600)]);
  return (await pub.readContract({ address: S.PLEA, abi: erc20, functionName: "balanceOf", args: [w.account.address] })) - before;
}
// The distributor's tree (OpenZeppelin sorted pairs), as plea/tools/distributor_root.py builds it.
const pairHash = (a, b) => keccak256(a < b ? `${a}${b.slice(2)}` : `${b}${a.slice(2)}`);
function tree(rows) {
  const leaves = rows.map(([i, a, amt]) => keccak256(encodePacked(["uint256", "address", "uint256"], [BigInt(i), a, amt])));
  const layers = [leaves];
  while (layers.at(-1).length > 1) {
    const prev = layers.at(-1), next = [];
    for (let i = 0; i < prev.length; i += 2) next.push(i + 1 < prev.length ? pairHash(prev[i], prev[i + 1]) : prev[i]);
    layers.push(next);
  }
  const proof = (i) => layers.slice(0, -1).flatMap((layer) => { const j = i ^ 1; const p = j < layer.length ? [layer[j]] : []; i >>= 1; return p; });
  return { root: layers.at(-1)[0], proof };
}

const owner = await as(S.owner), whale = await as(WHALE);
await write(whale, IMD, erc20, "transfer", [S.owner, parseEther("30")]);
await write(owner, S.PleaLaunch, parseAbi(["function seed()"]), "seed", []);
console.log(`seeded; opening buy ${formatEther(await buy(owner, "2"))} PLEA`);
const players = [];
for (const a of P) { players.push(await as(a, "1")); await write(whale, IMD, erc20, "transfer", [a, parseEther("30")]); }
const rows = [...P.map((a, i) => [i, a, parseEther("2500000")]), [P.length, S.owner.toLowerCase(), parseEther("20000000")]];
const t = tree(rows);
const dist = parseAbi(["function setMerkleRoot(bytes32)", "function claim(uint256 index, address account, uint256 amount, bytes32[] proof)"]);
await write(owner, S.PleaDistributor, dist, "setMerkleRoot", [t.root]);
const claims = rows.map(([i, account, amount]) => ({ index: String(i), account, amount: String(amount), proof: t.proof(i) }));
for (const c of claims) await write(owner, S.PleaDistributor, dist, "claim", [BigInt(c.index), c.account, BigInt(c.amount), c.proof]);
writeFileSync(join(DIR, "claims.json"), JSON.stringify({ root: t.root, claims }, null, 1));
console.log(`distributor root ${t.root}: ${claims.length} claims made`);
await rpc("evm_increaseTime", [91 * 60]);
await rpc("evm_mine");
for (const w of players.slice(0, 4)) console.log(`${w.account.address} bought ${formatEther(await buy(w, "5"))} PLEA`);
const holder = await as(SEAT_HOLDER);
await write(holder, SEAT, parseAbi(["function transferFrom(address,address,uint256)"]), "transferFrom", [SEAT_HOLDER, P[4], SEAT_ID]);
console.log(`seat #${SEAT_ID} moved to p5 ${P[4]}`);
const block = await pub.getBlock();
writeFileSync(join(DIR, "base.json"), JSON.stringify({ ...S, players: Object.fromEntries(P.map((a, i) => [`p${i + 1}`, a])), seat: { id: String(SEAT_ID), holder: P[4] }, baseBlock: Number(block.number), baseTime: Number(block.timestamp) }, null, 1));
writeFileSync(join(DIR, "base.hex"), await rpc("anvil_dumpState"));
console.log(`base state at block ${block.number}, time ${block.timestamp}: ${join(DIR, "base.hex")}`);
