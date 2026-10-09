// PondPad testnet: POOL4 mechanics test for the $PONDPAD market (PadMarketHook, our fork of POOL4's CappedBurnHook).
// Runs once the sale has graduated. A dedicated tester wallet (derived from MASTER_KEY) walks through every
// mechanism on the live market and checks it against THREAT-MODEL invariants 11-14 and D-21 / D-34 / D-38 / D-41:
//
//   A fee schedule      currentFee() follows 3% → 1% linearly over 7 days from openedAt
//   B ratchet           a buy draws the position below the cap and the cap follows it down (never below capFloor)
//   C trim              a sell above the cap leaves tokensInPool ≤ cap; the excess is split 85% burn / 15% stakers
//   D settle            next swap in a later block settles claims: burner and dripper receive their $PONDPAD
//   E burn              PadBurner.burn() lowers $PONDPAD's total supply by what it held
//   F backstop          retained IMD ≥ 40 → rebalance() deploys a single-sided IMD band above spot, tip ≤ 1 IMD
//   G backstop fill     a dump into the band converts it; rebalance() settles (burns what it bought) and redeploys
//   H fees              collectFees() empties both fee ledgers into the splitter (IMD and $PONDPAD)
//   I guards            outsiders can't add liquidity to the market pool or initialize a pool with the hook
//
//   MASTER_KEY=… node pool4.mjs          # writes runs/pool4-<time>.json, read by report.mjs
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import {
  createPublicClient, createWalletClient, http, defineChain, keccak256, concat, toHex, parseEther, formatEther,
  zeroAddress, parseEventLogs, BaseError, ContractFunctionRevertedError,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";

const here = (p) => new URL(p, import.meta.url).pathname;
const RPC_URL = process.env.RPC_URL ?? "https://rpc.testnet.chain.robinhood.com";
const MASTER_KEY = process.env.MASTER_KEY;
if (!MASTER_KEY) throw new Error("MASTER_KEY is required");
const d = JSON.parse(readFileSync(here("../contracts/deployments/46630.json"), "utf8"));
const s = JSON.parse(readFileSync(here("../contracts/deployments/46630-setup.json"), "utf8"));
const chain = defineChain({ id: Number(d.chainId), name: "Robinhood Chain Testnet", nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 }, rpcUrls: { default: { http: [RPC_URL] } } });
const client = createPublicClient({ chain, transport: http(RPC_URL) });
const master = privateKeyToAccount(MASTER_KEY);
const derive = (label) => privateKeyToAccount(keccak256(concat([MASTER_KEY, toHex(`pondpad-testnet:${label}`)])));
const tester = derive("pool4-tester");
const mw = createWalletClient({ account: master, chain, transport: http(RPC_URL) });
const tw = createWalletClient({ account: tester, chain, transport: http(RPC_URL) });

const art = (n) => JSON.parse(readFileSync(here(`../contracts/out/${n}.sol/${n}.json`), "utf8")).abi;
const errors = ["PadMarketHook", "PoolSwapTest", "PoolModifyLiquidityTest", "MarketController", "PadBurner"].flatMap((n) => art(n)).filter((x) => x.type === "error");
const withErr = (n) => [...art(n), ...errors];
const C = {
  market: { address: d.marketHook, abi: withErr("PadMarketHook") },
  controller: { address: d.marketController, abi: withErr("MarketController") },
  burner: { address: d.burner, abi: withErr("PadBurner") },
  swapper: { address: s.swapRouter, abi: withErr("PoolSwapTest") },
  lp: { address: s.liquidityRouter, abi: withErr("PoolModifyLiquidityTest") },
  imd: { address: s.imd, abi: art("TestToken") },
  pondpad: { address: d.pondpad, abi: art("PondPadToken") },
  pm: { address: s.poolManager, abi: art("PoolManager") },
};
const read = (c, functionName, args = []) => client.readContract({ ...c, functionName, args });
const bal = (tok, who) => read(tok, "balanceOf", [who]);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const E = (v) => Number(formatEther(v)).toLocaleString("en-US", { maximumFractionDigits: 4 });

async function send(wallet, c, functionName, args, value = 0n) {
  const { request } = await client.simulateContract({ ...c, functionName, args, value, account: wallet.account });
  // 50% gas headroom: the market hook's afterSwap does more work when claims mature between estimate and inclusion.
  const gas = await client.estimateContractGas({ ...c, functionName, args, value, account: wallet.account });
  const hash = await wallet.writeContract({ ...request, gas: (gas * 3n) / 2n });
  const rc = await client.waitForTransactionReceipt({ hash });
  if (rc.status !== "success") throw new Error(`${functionName} reverted onchain ${hash}`);
  return rc;
}
async function reverts(wallet, c, functionName, args, value = 0n) {
  try {
    await client.simulateContract({ ...c, functionName, args, value, account: wallet.account });
    return undefined;
  } catch (e) {
    const r = e instanceof BaseError ? e.walk((x) => x instanceof ContractFunctionRevertedError) : undefined;
    return r?.data?.errorName ?? r?.signature ?? "reverted";
  }
}

const results = [];
const check = (id, name, ok, detail) => {
  results.push({ id, name, ok: ok === null ? null : !!ok, detail });
  console.log(`${ok === null ? "SKIP" : ok ? "PASS" : "FAIL"} ${id} ${name}: ${detail}`);
};

const MIN_SQRT = 4295128739n + 1n, MAX_SQRT = 1461446703485210103287273052203988822378723970342n - 1n;
const NO_CLAIMS = { takeClaims: false, settleUsingBurn: false };
const key = await read(C.market, "poolKey");
const buy = (imdIn) => send(tw, C.swapper, "swap", [key, { zeroForOne: true, amountSpecified: -imdIn, sqrtPriceLimitX96: MIN_SQRT }, NO_CLAIMS, "0x"]);
const sell = (tokensIn) => send(tw, C.swapper, "swap", [key, { zeroForOne: false, amountSpecified: -tokensIn, sqrtPriceLimitX96: MAX_SQRT }, NO_CLAIMS, "0x"]);
const snap = async () => ({
  fee: await read(C.market, "currentFee"), held: await read(C.market, "tokensInPool"), cap: await read(C.market, "inventoryCap"),
  floor: await read(C.market, "capFloor"), retained: await read(C.market, "retainedQuote"), burned: await read(C.market, "totalBurned"),
  rewarded: await read(C.market, "totalRewarded"), burnClaims: await read(C.market, "burnClaims"), rewardClaims: await read(C.market, "rewardClaims"),
  principal: await read(C.market, "backstopQuotePrincipal"), tick: await read(C.market, "currentTick"),
  feeTok: await read(C.market, "feeTokenClaims"), feeQuote: await read(C.market, "feeQuoteClaims"),
  supply: await read(C.pondpad, "totalSupply"), burnerBal: await bal(C.pondpad, d.burner), dripperBal: await bal(C.pondpad, d.rewardDripper),
  splitterImd: await bal(C.imd, d.feeSplitter), splitterTok: await bal(C.pondpad, d.feeSplitter),
});

// ------------------------------------------------------------------ setup
if (!(await read(C.market, "marketOpen"))) throw new Error("the market is not open yet (the sale has not graduated)");
if ((await client.getBalance({ address: tester.address })) < parseEther("0.01"))
  await client.waitForTransactionReceipt({ hash: await mw.sendTransaction({ to: tester.address, value: parseEther("0.03") }) });
if ((await bal(C.imd, tester.address)) < parseEther("5000")) await send(mw, C.imd, "mint", [tester.address, parseEther("20000")]);
for (const tok of [C.imd, C.pondpad]) if ((await read(tok, "allowance", [tester.address, s.swapRouter])) < 2n ** 200n) await send(tw, tok, "approve", [s.swapRouter, 2n ** 256n - 1n]);
console.log(`tester ${tester.address}`);

// A. Fee schedule (D-34)
{
  const opened = await read(C.controller, "openedAt");
  const block = await client.getBlock();
  const fee = await read(C.market, "currentFee");
  const elapsed = block.timestamp - opened;
  const expected = elapsed >= 604800n ? 10000n : 30000n - (20000n * elapsed) / 604800n;
  check("A", "Fee schedule 3% → 1% over 7 days", fee >= expected - 1n && fee <= expected + 1n, `${Number(fee) / 10000}% at ${Number(elapsed)} s after open (expected ${Number(expected) / 10000}%)`);
}

// Gathers $PONDPAD from the sale crowd's wallets (our own testnet wallets) so the tester can sell above the cap.
async function gather(target, to) {
  for (let i = 0; i < 80 && (await bal(C.pondpad, to)) < target; i++) {
    const w = derive(`crowd-${i}`);
    const b = await bal(C.pondpad, w.address);
    if (b === 0n) continue;
    const need = target - (await bal(C.pondpad, to));
    await send(createWalletClient({ account: w, chain, transport: http(RPC_URL) }), C.pondpad, "transfer", [to, b < need ? b : need]);
  }
  return bal(C.pondpad, to);
}
// "A later block" in the hook means a later block.number, which on Robinhood is the Ethereum block (~12 s).
const nextL1Block = async () => {
  const n0 = await client.readContract({ address: "0xcA11bde05977b3631167028862bE2a173976CA11", abi: [{ type: "function", name: "getBlockNumber", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] }], functionName: "getBlockNumber" });
  for (let i = 0; i < 30; i++) {
    await sleep(2000);
    const n = await client.readContract({ address: "0xcA11bde05977b3631167028862bE2a173976CA11", abi: [{ type: "function", name: "getBlockNumber", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] }], functionName: "getBlockNumber" });
    if (n > n0) return;
  }
};

// B. Ratchet: a buy draws inventory down; the cap follows no faster than capDecayTokensPerDay (500k/day, D-21).
let s0 = await snap();
const decayAt = await read(C.market, "lastCapDecayAt"), perDay = await read(C.market, "capDecayTokensPerDay");
await buy(parseEther("500"));
let s1 = await snap();
const now1 = (await client.getBlock()).timestamp;
const allowance = (perDay * (now1 - decayAt)) / 86400n + parseEther("1");
check("B", "Ratchet: cap follows buys down at most 500k/day, never below the floor", s1.held < s0.held && s1.cap <= s0.cap && s0.cap - s1.cap <= allowance && s1.cap >= s1.floor,
  `inventory ${E(s0.held)} → ${E(s1.held)}; cap ${E(s0.cap)} → ${E(s1.cap)} (allowed drop ${E(allowance)}), floor ${E(s1.floor)}`);

// C. Trim: sell enough to push inventory above the cap; the excess leaves the pool, split 85% burn / 15% stakers.
const gap = s1.cap > s1.held ? s1.cap - s1.held : 0n;
const have = await gather(gap + parseEther("25000000"), tester.address);
const rc = await sell(have);
const trims = parseEventLogs({ abi: C.market.abi, eventName: "Trimmed", logs: rc.logs });
let s2 = await snap();
const tBurn = trims.reduce((a, l) => a + l.args.tokensBurned, 0n), tReward = trims.reduce((a, l) => a + l.args.tokensRewarded, 0n);
const tQuote = trims.reduce((a, l) => a + l.args.quoteRetained, 0n);
check("C1", "Trim: inventory back at the cap after a sell above it", trims.length > 0 && s2.held <= s2.cap + parseEther("1000"), `sold ${E(have)}; inventory ${E(s2.held)}, cap ${E(s2.cap)}; trimmed ${E(tBurn + tReward)} $PONDPAD + ${E(tQuote)} IMD retained`);
const share = tBurn + tReward > 0n ? Number((tReward * 10000n) / (tBurn + tReward)) / 100 : 0;
check("C2", "Trim split 85% burn / 15% stakers (D-21)", trims.length > 0 && Math.abs(share - 15) < 0.1, `to burn ${E(tBurn)}, to stakers ${E(tReward)} (${share}%)`);

// D. Settle: the trimmed tokens are claims until a swap in a later (Ethereum) block redeems them.
await nextL1Block();
await buy(parseEther("1"));
if ((await read(C.market, "burnClaims")) > 0n) { await nextL1Block(); await send(tw, C.market, "settleClaims", []); }
let s3 = await snap();
check("D", "Claims settle to the burner and the stakers' dripper", s3.burnClaims === 0n && s3.burnerBal > s2.burnerBal && s3.dripperBal > s2.dripperBal,
  `burner ${E(s2.burnerBal)} → ${E(s3.burnerBal)}, dripper ${E(s2.dripperBal)} → ${E(s3.dripperBal)}, open burn claims ${E(s3.burnClaims)}`);

// E. Burn: the burner retires everything it holds.
const held = await bal(C.pondpad, d.burner);
if (held > 0n) await send(tw, C.burner, "burn", []);
let s4 = await snap();
check("E", "PadBurner burns: $PONDPAD supply falls by what it held", held > 0n && s3.supply - s4.supply === held && s4.burnerBal === 0n, `burned ${E(held)}, supply ${E(s3.supply)} → ${E(s4.supply)}`);

// F. Backstop: IMD retained by trims is redeployed by a keeper as a single-sided band above spot.
let s5 = await snap();
const pending = await read(C.market, "pendingRebalance");
let tip = 0n, deployed;
if (pending) {
  const before = await bal(C.imd, tester.address);
  const r = await send(tw, C.market, "rebalance", []);
  tip = (await bal(C.imd, tester.address)) - before;
  deployed = parseEventLogs({ abi: C.market.abi, eventName: "BackstopDeployed", logs: r.logs })[0]?.args;
}
let s6 = await snap();
check("F1", "Trims retain IMD for the backstop (≥ 40 IMD → rebalance due)", pending, `retained ${E(s5.retained)} IMD, pendingRebalance ${pending}`);
check("F2", "rebalance() deploys a single-sided IMD band above spot", !!deployed && deployed.tickLower > s6.tick && s6.principal > 0n,
  deployed ? `band ticks ${deployed.tickLower}…${deployed.tickUpper} above spot ${s6.tick}, ${E(deployed.quoteDeployed)} IMD` : "no deployment");
check("F3", "Keeper tip ≤ 1 IMD and ≤ the fee on the work (D-41)", tip <= parseEther("1"), `${E(tip)} IMD`);

// G. Dump into the band: sell more so the price rises into it; the next rebalance settles it.
let filled = false, settled;
if (s6.principal > 0n) {
  const more = await gather(parseEther("40000000"), tester.address);
  await sell(more);
  filled = await read(C.market, "backstopIsFilled");
  if (filled) {
    await nextL1Block();
    if (await read(C.market, "pendingRebalance")) {
      const r = await send(tw, C.market, "rebalance", []);
      settled = parseEventLogs({ abi: C.market.abi, eventName: "BackstopSettled", logs: r.logs })[0]?.args;
    }
  }
}
const converted = await read(C.market, "backstopConvertedQuote");
check("G", "A dump fills the backstop; rebalance settles it (burns what it bought)", filled ? !!settled : null,
  filled ? `settled: to burn ${E(settled?.tokensBurned ?? 0n)}, to stakers ${E(settled?.tokensRewarded ?? 0n)}, IMD back ${E(settled?.quoteReturned ?? 0n)}` : `the dump did not reach the band (converted ${E(converted)} IMD)`);

// H. Fees: collectFees empties both ledgers into the splitter (D-38).
let s7 = await snap();
await send(tw, C.controller, "collectFees", []);
let s8 = await snap();
check("H", "collectFees: both fee ledgers to the 40/25/20/15 split", s8.feeQuote === 0n && s8.feeTok === 0n && (s7.feeQuote > 0n || s7.feeTok > 0n),
  `collected ${E(s7.feeQuote)} IMD + ${E(s7.feeTok)} $PONDPAD`);

// I. Guards: no outside liquidity, no other pool with this hook.
const addLp = await reverts(tw, C.lp, "modifyLiquidity", [key, { tickLower: -887200, tickUpper: 887200, liquidityDelta: 10n ** 18n, salt: "0x" + "00".repeat(32) }, "0x"]);
const otherKey = { ...key, tickSpacing: 60 };
const init = await reverts(tw, C.pm, "initialize", [otherKey, 79228162514264337593543950336n]);
check("I", "Outsiders can't add liquidity or open another pool on the hook", !!addLp && !!init, `addLiquidity → ${addLp}; initialize → ${init}`);

// Price neutrality of trims is structural (liquidity removal, not a swap); record the end state.
const final = await snap();
mkdirSync(here("runs"), { recursive: true });
const out = here(`runs/pool4-${new Date().toISOString().replace(/[:.]/g, "-")}.json`);
writeFileSync(out, JSON.stringify({ at: new Date().toISOString(), tester: tester.address, results, final }, (_, v) => (typeof v === "bigint" ? v.toString() : v), 2));
console.log(`${results.filter((r) => r.ok).length}/${results.length} passed; ${out}`);
