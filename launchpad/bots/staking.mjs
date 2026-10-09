// PondPad testnet: staking exploit suite (StakedPONDPAD + RewardDripper + PadBuyer, THREAT-MODEL invariants 6, 13, 14).
// A staker-attacker wallet tries each exploit on the live vault and checks it fails or stays bounded.
//
//   ST1 redeem in the same block as the deposit (flash stake)        → SameBlockRedeem
//   ST2 move the shares to a fresh wallet and redeem there at once   → the hold travels with the shares
//   ST3 a normal stake / redeem round trip loses nothing but rounding
//   ST4 stake right before a drip, redeem right after                → profit bounded by the stake's share of one drip
//   ST5 donate $PONDPAD straight into the vault                      → a gift to all stakers, nothing to take back
//   ST6 owner-only staking calls from a stranger                     → refused
//   ST7 reward flow: dripper → vault raised the value per share since staking opened
//
//   MASTER_KEY=… node staking.mjs        # writes runs/staking-<time>.json
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import {
  createPublicClient, createWalletClient, http, defineChain, keccak256, concat, toHex, parseEther, formatEther,
  BaseError, ContractFunctionRevertedError,
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
const st = derive("staking-attacker");
const mw = createWalletClient({ account: master, chain, transport: http(RPC_URL) });
const sw = createWalletClient({ account: st, chain, transport: http(RPC_URL) });

const art = (n) => JSON.parse(readFileSync(here(`../contracts/out/${n}.sol/${n}.json`), "utf8")).abi;
const errs = ["StakedPONDPAD", "RewardDripper", "PadBuyer"].flatMap(art).filter((x) => x.type === "error");
const C = {
  vault: { address: d.stakedPondpad, abi: [...art("StakedPONDPAD"), ...errs] },
  dripper: { address: d.rewardDripper, abi: [...art("RewardDripper"), ...errs] },
  pondpad: { address: d.pondpad, abi: art("PondPadToken") },
};
const read = (c, functionName, args = [], blockNumber) => client.readContract({ ...c, functionName, args, ...(blockNumber ? { blockNumber } : {}) });
const bal = (tok, who) => read(tok, "balanceOf", [who]);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const E = (v) => Number(formatEther(v)).toLocaleString("en-US", { maximumFractionDigits: 4 });
const walletOf = (a) => createWalletClient({ account: a, chain, transport: http(RPC_URL) });

async function send(wallet, c, functionName, args) {
  const { request } = await client.simulateContract({ ...c, functionName, args, account: wallet.account });
  const gas = await client.estimateContractGas({ ...c, functionName, args, account: wallet.account });
  const hash = await wallet.writeContract({ ...request, gas: (gas * 3n) / 2n });
  const rc = await client.waitForTransactionReceipt({ hash });
  if (rc.status !== "success") throw new Error(`${functionName} reverted onchain ${hash}`);
  return rc;
}
async function attempt(c, functionName, args, account, blockNumber) {
  try {
    await client.simulateContract({ ...c, functionName, args, account, ...(blockNumber ? { blockNumber } : {}) });
    return undefined;
  } catch (e) {
    const r = e instanceof BaseError ? e.walk((x) => x instanceof ContractFunctionRevertedError) : undefined;
    return r?.data?.errorName ?? r?.signature ?? (e.shortMessage ?? "reverted").slice(0, 80);
  }
}
const mc = { address: "0xcA11bde05977b3631167028862bE2a173976CA11", abi: [{ type: "function", name: "getBlockNumber", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] }] };
const evmBlock = () => read(mc, "getBlockNumber");
const nextL1Block = async () => { const n0 = await evmBlock(); for (let i = 0; i < 30 && (await evmBlock()) === n0; i++) await sleep(2000); };

const results = [];
const OUT = here(`runs/staking-${new Date().toISOString().replace(/[:.]/g, "-")}.json`);
mkdirSync(here("runs"), { recursive: true });
const save = () => writeFileSync(OUT, JSON.stringify({ at: new Date().toISOString(), group: "staking", attacker: st.address, results }, (_, v) => (typeof v === "bigint" ? v.toString() : v), 2));
const check = (id, name, ok, detail) => {
  results.push({ id, name, ok: ok === null ? null : !!ok, detail });
  save();
  console.log(`${ok === null ? "SKIP" : ok ? "PASS" : "FAIL"} ${id} ${name}: ${detail}`);
};

// ------------------------------------------------------------------ funding: $PONDPAD from the sale crowd (our wallets)
if ((await client.getBalance({ address: st.address })) < parseEther("0.01"))
  await client.waitForTransactionReceipt({ hash: await mw.sendTransaction({ to: st.address, value: parseEther("0.03") }) });
for (let i = 40; i < 80 && (await bal(C.pondpad, st.address)) < parseEther("30000000"); i++) {
  const w = derive(`crowd-${i}`);
  const b = await bal(C.pondpad, w.address);
  if (b > 0n) await send(walletOf(w), C.pondpad, "transfer", [st.address, b]);
}
const funds = await bal(C.pondpad, st.address);
console.log(`staking attacker ${st.address}, ${E(funds)} $PONDPAD`);
if ((await read(C.pondpad, "allowance", [st.address, d.stakedPondpad])) < 2n ** 200n) await send(sw, C.pondpad, "approve", [d.stakedPondpad, 2n ** 256n - 1n]);
const price0 = await read(C.vault, "convertToAssets", [10n ** 18n]);

// ST1: flash stake: deposit and redeem in one block.
await nextL1Block();
const amt = parseEther("1000000");
const rc1 = await send(sw, C.vault, "deposit", [amt, st.address]);
const shares = await read(C.vault, "balanceOf", [st.address]);
const sameBlock = await attempt(C.vault, "redeem", [shares, st.address, st.address], st, rc1.blockNumber);
const evmAtDeposit = await read(mc, "getBlockNumber", [], rc1.blockNumber);
check("ST1", "Flash stake: redeem in the deposit's block", ["SameBlockRedeem", "RedeemMoreThanMax"].includes(sameBlock), `refused: ${sameBlock ?? "**allowed**"} (deposit at block.number ${evmAtDeposit}, the Ethereum block; Robinhood block ${rc1.blockNumber})`);

// ST2: hand the fresh shares to another wallet and redeem from there in the same block.
const fresh = derive(`staking-fresh-${Date.now()}`);
const rc2 = await send(sw, C.vault, "transfer", [fresh.address, shares / 2n]);
const viaFresh = await attempt(C.vault, "redeem", [shares / 2n, fresh.address, fresh.address], fresh, rc2.blockNumber);
check("ST2", "The one-block hold travels with transferred shares", ["SameBlockRedeem", "RedeemMoreThanMax"].includes(viaFresh), `fresh wallet's redeem refused: ${viaFresh ?? "**allowed**"}`);

// ST3: after the hold, the round trip returns the stake (minus rounding).
await nextL1Block();
const sharesLeft = await read(C.vault, "balanceOf", [st.address]);
const before3 = await bal(C.pondpad, st.address);
await send(sw, C.vault, "redeem", [sharesLeft, st.address, st.address]);
const back = (await bal(C.pondpad, st.address)) - before3;
check("ST3", "Stake / redeem round trip loses nothing but rounding", back + 2n >= amt / 2n, `deposited ${E(amt / 2n)} (kept half the shares), got back ${E(back)}`);

// ST4: drip sniping: stake big just before a drip, redeem right after.
const canDrip = await read(C.dripper, "canDrip");
if (canDrip) {
  const big = (await bal(C.pondpad, st.address)) - parseEther("2000000");
  const total0 = await read(C.vault, "totalAssets");
  await send(sw, C.vault, "deposit", [big, st.address]);
  const sh = await read(C.vault, "balanceOf", [st.address]);
  const rd = await send(sw, C.dripper, "drip", []);
  const dripped = (await read(C.vault, "totalAssets")) - total0 - big;
  await nextL1Block();
  const b0 = await bal(C.pondpad, st.address);
  await send(sw, C.vault, "redeem", [sh, st.address, st.address]);
  const out = (await bal(C.pondpad, st.address)) - b0;
  const profit = out > big ? out - big : 0n;
  const fair = (dripped * big) / (total0 + big);
  check("ST4", "Drip sniping is bounded to the stake's share of one drip (smoothed over 7 days, D-44)", profit <= fair + parseEther("1"),
    `staked ${E(big)} next to ${E(total0)}; one drip added ${E(dripped)}; profit ${E(profit)} vs fair share ${E(fair)} (${((Number(profit) / Number(big)) * 100).toFixed(4)}% of the stake)`);
} else check("ST4", "Drip sniping", null, "no drip due right now (canDrip false); not exercised");

// ST5: donate straight into the vault: everyone's shares gain, the donor can't take it back.
const myShares = await read(C.vault, "balanceOf", [st.address]);
if (myShares === 0n) { await send(sw, C.vault, "deposit", [parseEther("100000"), st.address]); await nextL1Block(); }
const sh5 = await read(C.vault, "balanceOf", [st.address]);
const supply5 = await read(C.vault, "totalSupply");
const value0 = await read(C.vault, "convertToAssets", [sh5]);
const gift = parseEther("1000000");
await send(sw, C.pondpad, "transfer", [d.stakedPondpad, gift]);
const value1 = await read(C.vault, "convertToAssets", [sh5]);
const gain = value1 - value0;
const fairGain = (gift * sh5) / supply5;
check("ST5", "Donation is a gift to all stakers (donor gets back only its own share)", gain <= fairGain + parseEther("1") && gain + parseEther("1") >= fairGain,
  `donated ${E(gift)}; donor's value +${E(gain)} (its ${((Number(sh5) / Number(supply5)) * 100).toFixed(2)}% share of the gift), the rest went to other stakers`);

// ST6: owner-only calls from a stranger.
const r6 = [
  ["pause the vault", await attempt(C.vault, "setPaused", [true], st)],
  ["rescue staked $PONDPAD", await attempt(C.vault, "rescueERC20", [d.pondpad, st.address, 1n], st)],
  ["shorten the drip smoothing", await attempt(C.dripper, "setSmoothingPeriod", [1n], st)],
  ["rescue the dripper's rewards", await attempt(C.dripper, "rescueERC20", [d.pondpad, st.address, 1n], st)],
  ["raise the keeper reward", await attempt(C.dripper, "setKeeperReward", [parseEther("100000")], st)],
];
check("ST6", "Owner-only staking calls refused for strangers", r6.every(([, r]) => r !== undefined), r6.map(([n, r]) => `${n}: ${r ?? "**allowed**"}`).join("; "));

// ST7: rewards actually reached stakers since the vault opened.
const price1 = await read(C.vault, "convertToAssets", [10n ** 18n]);
check("ST7", "Rewards reached stakers: value per share rose", price1 > 10n ** 12n && price1 >= price0, `value per share ×${(Number(price1) / 1e12).toFixed(6)} (×1 at open; ×${(Number(price0) / 1e12).toFixed(6)} when this test started)`);

// Leave nothing staked.
await nextL1Block();
const rest = await read(C.vault, "balanceOf", [st.address]);
if (rest > 0n) await send(sw, C.vault, "redeem", [rest, st.address, st.address]);
save();
console.log(`${results.filter((r) => r.ok === true).length} passed, ${results.filter((r) => r.ok === false).length} failed, ${results.filter((r) => r.ok === null).length} skipped; ${OUT}`);
