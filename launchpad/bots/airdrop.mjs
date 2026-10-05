// PondPad testnet: airdrop test (AirdropDistributor, D-53, D-55, THREAT-MODEL invariant 20).
// The live testnet airdrop has a placeholder root, so this deploys a test-only AirdropDistributor with a real Merkle
// list of 104 derived wallets (same constructor as Deploy.s.sol: owner = 10-minute timelock, market = the live
// MarketController, unclaimed sink = the live RewardDripper, verifier = the testnet tweet checker key), funds it
// with $PONDPAD from the sale crowd, then runs the whole flow and the attacks on it:
//
//   AD1  claims before activation                          AD8  100th initiation activates; 101st refused
//   AD2  initiation by a wallet not on the list            AD9  first claim pays exactly amount × elapsed / 30 days
//   AD3  voucher signed by someone else than the checker   AD10 claim with an inflated amount
//   AD4  a stranger initiates for a listed wallet          AD11 a stranger claims for someone else
//   AD5  the (leaked) checker key initiates by itself      AD12 claim wallet by gasless signature, then replay it
//   AD6  reused X account / reused tweet / repeat wallet   AD13 sweep before 180 days
//   AD7  expired voucher; 99 initiations activate nothing  AD14 stranger replaces the checker key; claims ≤ funded
//
//   MASTER_KEY=… node airdrop.mjs       # writes runs/airdrop-<time>.json; the distributor address goes in it
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { execFileSync } from "node:child_process";
import {
  createPublicClient, createWalletClient, http, defineChain, keccak256, concat, toHex, parseEther, formatEther,
  encodeAbiParameters, BaseError, ContractFunctionRevertedError,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";

const here = (p) => new URL(p, import.meta.url).pathname;
const RPC_URL = process.env.RPC_URL ?? "https://rpc.testnet.chain.robinhood.com";
const MASTER_KEY = process.env.MASTER_KEY;
if (!MASTER_KEY) throw new Error("MASTER_KEY is required");
const d = JSON.parse(readFileSync(here("../contracts/deployments/46630.json"), "utf8"));
const chain = defineChain({ id: Number(d.chainId), name: "Robinhood Chain Testnet", nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 }, rpcUrls: { default: { http: [RPC_URL] } } });
const client = createPublicClient({ chain, transport: http(RPC_URL) });
const derive = (label) => privateKeyToAccount(keccak256(concat([MASTER_KEY, toHex(`pondpad-testnet:${label}`)])));
const master = privateKeyToAccount(MASTER_KEY);
const checker = derive("tweetChecker");
const stranger = derive("airdrop-stranger");
const walletOf = (a) => createWalletClient({ account: a, chain, transport: http(RPC_URL) });
const mw = walletOf(master);

const art = (n) => JSON.parse(readFileSync(here(`../contracts/out/${n}.sol/${n}.json`), "utf8")).abi;
const pondpad = { address: d.pondpad, abi: art("PondPadToken") };
const read = (c, functionName, args = []) => client.readContract({ ...c, functionName, args });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const E = (v) => Number(formatEther(v)).toLocaleString("en-US", { maximumFractionDigits: 4 });

async function send(wallet, c, functionName, args) {
  const { request } = await client.simulateContract({ ...c, functionName, args, account: wallet.account });
  const gas = await client.estimateContractGas({ ...c, functionName, args, account: wallet.account });
  const hash = await wallet.writeContract({ ...request, gas: (gas * 3n) / 2n });
  const rc = await client.waitForTransactionReceipt({ hash });
  if (rc.status !== "success") throw new Error(`${functionName} reverted onchain ${hash}`);
  return rc;
}
async function attempt(c, functionName, args, account) {
  try {
    await client.simulateContract({ ...c, functionName, args, account });
    return undefined;
  } catch (e) {
    const r = e instanceof BaseError ? e.walk((x) => x instanceof ContractFunctionRevertedError) : undefined;
    return r?.data?.errorName ?? r?.signature ?? (e.shortMessage ?? "reverted").slice(0, 80);
  }
}

const results = [];
const OUT = here(`runs/airdrop-${new Date().toISOString().replace(/[:.]/g, "-")}.json`);
mkdirSync(here("runs"), { recursive: true });
let distributor;
const save = () => writeFileSync(OUT, JSON.stringify({ at: new Date().toISOString(), group: "airdrop", distributor, results }, (_, v) => (typeof v === "bigint" ? v.toString() : v), 2));
const check = (id, name, ok, detail) => {
  results.push({ id, name, ok: ok === null ? null : !!ok, detail });
  save();
  console.log(`${ok === null ? "SKIP" : ok ? "PASS" : "FAIL"} ${id} ${name}: ${detail}`);
};
const refused = (id, name, r, want) => check(id, name, r !== undefined && (!want || want.includes(r)), r === undefined ? "**the call would succeed**" : `refused: ${r}`);

// ------------------------------------------------------------------ the list and its Merkle tree (OZ StandardMerkleTree leaves)
const N = 104;
const list = Array.from({ length: N }, (_, i) => ({ account: derive(`airdrop-${i}`), amount: parseEther(String(10_000 + 500 * i)) }));
const leafOf = (addr, amount) => keccak256(keccak256(encodeAbiParameters([{ type: "address" }, { type: "uint256" }], [addr, amount])));
const hashPair = (a, b) => (BigInt(a) < BigInt(b) ? keccak256(concat([a, b])) : keccak256(concat([b, a])));
const layers = [list.map((x) => leafOf(x.account.address, x.amount)).sort((a, b) => (BigInt(a) < BigInt(b) ? -1 : 1))];
while (layers.at(-1).length > 1) {
  const prev = layers.at(-1), next = [];
  for (let i = 0; i < prev.length; i += 2) next.push(i + 1 < prev.length ? hashPair(prev[i], prev[i + 1]) : prev[i]);
  layers.push(next);
}
const root = layers.at(-1)[0];
const proofOf = (addr, amount) => {
  let idx = layers[0].indexOf(leafOf(addr, amount));
  const proof = [];
  for (let l = 0; l < layers.length - 1; l++) {
    const sib = idx ^ 1;
    if (sib < layers[l].length) proof.push(layers[l][sib]);
    idx >>= 1;
  }
  return proof;
};
const total = list.reduce((a, x) => a + x.amount, 0n);

// ------------------------------------------------------------------ deploy and fund the test distributor
const args = [d.fastTimelock, d.pondpad, root, d.marketController, d.rewardDripper, checker.address];
let outp;
for (let tries = 0; !outp && tries < 4; tries++) {
  try { outp = execFileSync("forge", ["create", "src/AirdropDistributor.sol:AirdropDistributor", "--broadcast", "--rpc-url", RPC_URL, "--private-key", MASTER_KEY, "--constructor-args", ...args], { cwd: here("../contracts"), env: { ...process.env, PATH: `${process.env.HOME}/.foundry/bin:${process.env.PATH}` }, stdio: ["ignore", "pipe", "pipe"] }).toString(); } catch { await sleep(3000); }
}
distributor = outp.match(/Deployed to: (0x[0-9a-fA-F]{40})/)[1];
const A = { address: distributor, abi: art("AirdropDistributor") };
console.log(`test distributor ${distributor}, root ${root}, ${N} wallets, ${E(total)} $PONDPAD`);
for (let i = 0; i < 80 && (await read(pondpad, "balanceOf", [distributor])) < total; i++) {
  const w = derive(`crowd-${i}`);
  const b = await read(pondpad, "balanceOf", [w.address]);
  if (b === 0n) continue;
  const need = total - (await read(pondpad, "balanceOf", [distributor]));
  await send(walletOf(w), pondpad, "transfer", [distributor, b < need ? b : need]);
}
const funded = await read(pondpad, "balanceOf", [distributor]);
save();

// Gas for the listed wallets and the stranger, from a funder wallet of its own (the bots use the master's nonce).
const funder = derive("airdrop-funder"), fw = walletOf(funder);
for (let tries = 0; (await client.getBalance({ address: funder.address })) < parseEther("0.05") && tries < 5; tries++) {
  try { await client.waitForTransactionReceipt({ hash: await mw.sendTransaction({ to: funder.address, value: parseEther("0.08") }) }); } catch { await sleep(3000); }
}
const fund = async (a) => {
  if ((await client.getBalance({ address: a.address })) < parseEther("0.0002"))
    await client.waitForTransactionReceipt({ hash: await fw.sendTransaction({ to: a.address, value: parseEther("0.0005") }) });
};
for (const a of [...list.map((x) => x.account), stranger]) await fund(a);

// Vouchers: EIP-712 Initiation signed by the tweet checker after it "saw" the post.
const domain = { name: "PondPad Airdrop", version: "1", chainId: Number(d.chainId), verifyingContract: distributor };
const types = { Initiation: [{ name: "account", type: "address" }, { name: "handleHash", type: "bytes32" }, { name: "tweetHash", type: "bytes32" }, { name: "deadline", type: "uint256" }] };
const voucher = (signer, account, handleHash, tweetHash, deadline) => signer.signTypedData({ domain, types, primaryType: "Initiation", message: { account, handleHash, tweetHash, deadline } });
const deadline = () => BigInt(Math.floor(Date.now() / 1000) + 3600);
const handle = (i) => keccak256(toHex(`@pondpad_test_${i}`));
const tweet = (i) => keccak256(toHex(`tweet-${i}`));
const initArgs = async (i, opts = {}) => {
  const x = list[i];
  const dl = opts.deadline ?? deadline();
  const h = opts.handle ?? handle(i), t = opts.tweet ?? tweet(i);
  return [x.account.address, x.amount, proofOf(x.account.address, x.amount), h, t, dl, await voucher(opts.signer ?? checker, x.account.address, h, t, dl)];
};

// AD1: nothing claimable before activation.
refused("AD1", "Claim before activation", await attempt(A, "claim", [list[0].account.address, list[0].amount, proofOf(list[0].account.address, list[0].amount)], list[0].account), ["NotActive"]);
// AD2: a wallet not on the list, even with a valid voucher.
{
  const amt = parseEther("1000000"), dl = deadline(), h = keccak256(toHex("@stranger")), t = keccak256(toHex("stranger-tweet"));
  refused("AD2", "Initiation by a wallet not on the list", await attempt(A, "initiate", [stranger.address, amt, [], h, t, dl, await voucher(checker, stranger.address, h, t, dl)], stranger), ["InvalidProof"]);
}
// AD3: voucher not signed by the tweet checker.
refused("AD3", "Voucher signed by someone else", await attempt(A, "initiate", await initArgs(0, { signer: stranger }), list[0].account), ["BadVoucher"]);
// AD4: a stranger submits a listed wallet's valid voucher.
refused("AD4", "A stranger initiates for a listed wallet", await attempt(A, "initiate", await initArgs(0), stranger), ["NotAuthorized"]);
// AD5: the checker key alone (leaked) can't initiate: the listed wallet must send it.
refused("AD5", "Leaked checker key initiates by itself", await attempt(A, "initiate", await initArgs(0), checker), ["NotAuthorized"]);
// AD7a: expired voucher.
refused("AD7a", "Expired voucher", await attempt(A, "initiate", await initArgs(0, { deadline: BigInt(Math.floor(Date.now() / 1000) - 60) }), list[0].account), ["Expired"]);

// 99 initiations: nothing activates.
for (let i = 0; i < 99; i++) await send(walletOf(list[i].account), A, "initiate", await initArgs(i));
// AD6: reused X account, reused tweet, repeat wallet.
const reuseHandle = await attempt(A, "initiate", await initArgs(99, { handle: handle(5) }), list[99].account);
const reuseTweet = await attempt(A, "initiate", await initArgs(99, { tweet: tweet(5) }), list[99].account);
const repeat = await attempt(A, "initiate", await initArgs(5, { handle: keccak256(toHex("new")), tweet: keccak256(toHex("new")) }), list[5].account);
check("AD6", "Each X account, tweet and wallet counts once", reuseHandle === "HandleUsed" && reuseTweet === "TweetUsed" && repeat === "AlreadyInitiated", `reused X account: ${reuseHandle}; reused tweet: ${reuseTweet}; same wallet again: ${repeat}`);
const count99 = await read(A, "initiatorCount"), active99 = await read(A, "activatedAt");
check("AD7b", "99 initiations activate nothing (no fallback, D-55)", count99 === 99n && active99 === 0n, `count ${count99}, activatedAt ${active99}`);
refused("AD7c", "Still no claims at 99", await attempt(A, "claim", [list[0].account.address, list[0].amount, proofOf(list[0].account.address, list[0].amount)], list[0].account), ["NotActive"]);

// AD8: the 100th activates; a 101st is refused.
const rcAct = await send(walletOf(list[99].account), A, "initiate", await initArgs(99));
const activatedAt = await read(A, "activatedAt");
const actBlock = await client.getBlock({ blockNumber: rcAct.blockNumber });
const late = await attempt(A, "initiate", await initArgs(100), list[100].account);
check("AD8", "The 100th initiation activates the airdrop; later ones are refused", activatedAt === actBlock.timestamp && late === "AlreadyActive", `activatedAt ${activatedAt} (the 100th's block); 101st: ${late}`);

// AD9: linear vesting over 30 days from activation, for everyone on the list (initiator or not).
await sleep(20_000);
const x = list[102]; // never initiated
const rcClaim = await send(walletOf(x.account), A, "claim", [x.account.address, x.amount, proofOf(x.account.address, x.amount)]);
const tClaim = (await client.getBlock({ blockNumber: rcClaim.blockNumber })).timestamp;
const got = await read(pondpad, "balanceOf", [x.account.address]);
const expect = (x.amount * (tClaim - activatedAt)) / (30n * 86400n);
check("AD9", "A non-initiator claims exactly amount × elapsed / 30 days", got === expect && got > 0n, `allocation ${E(x.amount)}; ${tClaim - activatedAt} s after activation got ${E(got)} (expected ${E(expect)})`);
// AD10: inflate the amount.
refused("AD10", "Claim with an inflated amount", await attempt(A, "claim", [x.account.address, x.amount * 10n, proofOf(x.account.address, x.amount)], x.account), ["InvalidProof"]);
// AD11: claim someone else's airdrop.
refused("AD11", "A stranger claims for someone else", await attempt(A, "claim", [list[3].account.address, list[3].amount, proofOf(list[3].account.address, list[3].amount)], stranger), ["NotAuthorized"]);

// AD12: name a claim wallet by gasless signature and claim in one transaction; replaying the signature fails.
{
  const owner = list[103], claimWallet = derive("airdrop-claim-wallet");
  await fund(claimWallet);
  const dl = deadline();
  const nonce = await read(A, "nonces", [owner.account.address]);
  const sig = await owner.account.signTypedData({ domain, types: { Delegate: [{ name: "account", type: "address" }, { name: "claimWallet", type: "address" }, { name: "nonce", type: "uint256" }, { name: "deadline", type: "uint256" }] }, primaryType: "Delegate", message: { account: owner.account.address, claimWallet: claimWallet.address, nonce, deadline: dl } });
  const b0 = await read(pondpad, "balanceOf", [claimWallet.address]);
  await send(walletOf(claimWallet), A, "setClaimWalletAndClaim", [owner.account.address, dl, sig, owner.amount, proofOf(owner.account.address, owner.amount)]);
  const paid = (await read(pondpad, "balanceOf", [claimWallet.address])) - b0;
  const replay = await attempt(A, "setClaimWalletBySig", [owner.account.address, stranger.address, dl, sig], stranger);
  const ownerBal = await read(pondpad, "balanceOf", [owner.account.address]);
  check("AD12", "Gasless claim wallet works; its signature can't be replayed", paid > 0n && ownerBal === 0n && replay === "BadSignature", `claim wallet received ${E(paid)}, the listed wallet never sent a transaction; replay: ${replay}`);
}
// AD13: sweep is locked for 180 days.
refused("AD13", "Sweep before the 180-day claim window ends", await attempt(A, "sweep", [], stranger), ["ClaimWindowNotOver"]);
// AD14: only the timelock replaces the checker key; claims never exceed the funding.
const setV = await attempt(A, "setVerifier", [stranger.address], stranger);
const claimedTotal = await read(A, "totalClaimed");
check("AD14", "Stranger can't replace the checker key; claims ≤ funding", setV === "Unauthorized" && claimedTotal <= funded, `setVerifier: ${setV}; claimed ${E(claimedTotal)} of ${E(funded)} funded`);

save();
console.log(`${results.filter((r) => r.ok === true).length} passed, ${results.filter((r) => r.ok === false).length} failed; ${OUT}`);
