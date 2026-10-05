// PondPad testnet attack suite: an attacker wallet tries known attacks against the live contracts and checks that
// each one fails (or is bounded) as THREAT-MODEL.md §2 says. Three groups:
//
//   coins   curve bypass, graduation front-run, outside liquidity, partial fill, fee through an outside router,
//           self-referral, wrong ETH amount
//   sale    wallet-cap bypass by transfer, early graduation, fake market launch; governance: owner-only calls from
//           a stranger (config, controller migrate, hook retained IMD, staking rescues, airdrop claim, growth payJob)
//   market  (after the sale graduates; POOL4 fork) PadBuyer sandwich, backstop placement manipulation, keeper-tip
//           farming, trim avoidance with dust sells, fee through an outside router
//
//   MASTER_KEY=… node attacks.mjs [coins|sale|market|all]     # writes runs/attacks-<group>-<time>.json
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import {
  createPublicClient, createWalletClient, http, defineChain, keccak256, concat, toHex, parseEther, formatEther,
  zeroAddress, parseEventLogs, encodeAbiParameters, decodeErrorResult, BaseError, ContractFunctionRevertedError, pad,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";

const here = (p) => new URL(p, import.meta.url).pathname;
const group = process.argv[2] ?? "all";
const RPC_URL = process.env.RPC_URL ?? "https://rpc.testnet.chain.robinhood.com";
const MASTER_KEY = process.env.MASTER_KEY;
if (!MASTER_KEY) throw new Error("MASTER_KEY is required");
const d = JSON.parse(readFileSync(here("../contracts/deployments/46630.json"), "utf8"));
const s = JSON.parse(readFileSync(here("../contracts/deployments/46630-setup.json"), "utf8"));
const chain = defineChain({ id: Number(d.chainId), name: "Robinhood Chain Testnet", nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 }, rpcUrls: { default: { http: [RPC_URL] } } });
const client = createPublicClient({ chain, transport: http(RPC_URL) });
const derive = (label) => privateKeyToAccount(keccak256(concat([MASTER_KEY, toHex(`pondpad-testnet:${label}`)])));
const master = privateKeyToAccount(MASTER_KEY);
const attacker = derive("attacker");
const mw = createWalletClient({ account: master, chain, transport: http(RPC_URL) });
const aw = createWalletClient({ account: attacker, chain, transport: http(RPC_URL) });

const art = (n) => JSON.parse(readFileSync(here(`../contracts/out/${n}.sol/${n}.json`), "utf8")).abi;
const N = ["PadRouter", "BondingCurve", "PadHook", "PadSale", "PadMarketHook", "MarketController", "PadBuyer", "PadConfig", "StakedPONDPAD", "RewardDripper", "AirdropDistributor", "GrowthFund", "IntegratorVault", "PoolSwapTest", "PoolModifyLiquidityTest", "PoolManager", "TestToken", "PondPadToken", "PadToken"];
const raw = Object.fromEntries(N.map((n) => [n, art(n)]));
const errs = [...Object.values(raw).flat().filter((x) => x.type === "error"),
  // v4-core CustomRevert: wraps a hook's revert (not in any of our ABIs).
  { type: "error", name: "WrappedError", inputs: [{ name: "target", type: "address" }, { name: "selector", type: "bytes4" }, { name: "reason", type: "bytes" }, { name: "details", type: "bytes" }] }];
const A = (n) => [...raw[n], ...errs];
const C = {
  router: { address: d.router, abi: A("PadRouter") }, curve: { address: d.curve, abi: A("BondingCurve") },
  hook: { address: d.hook, abi: A("PadHook") }, sale: { address: d.sale, abi: A("PadSale") },
  market: { address: d.marketHook, abi: A("PadMarketHook") }, controller: { address: d.marketController, abi: A("MarketController") },
  buyer: { address: d.padBuyer, abi: A("PadBuyer") }, config: { address: d.config, abi: A("PadConfig") },
  vault: { address: d.stakedPondpad, abi: A("StakedPONDPAD") }, dripper: { address: d.rewardDripper, abi: A("RewardDripper") },
  airdrop: { address: d.airdrop, abi: A("AirdropDistributor") }, growth: { address: d.growthFund, abi: A("GrowthFund") },
  integrators: { address: d.integratorVault, abi: A("IntegratorVault") },
  swapper: { address: s.swapRouter, abi: A("PoolSwapTest") }, lp: { address: s.liquidityRouter, abi: A("PoolModifyLiquidityTest") },
  pm: { address: s.poolManager, abi: A("PoolManager") }, imd: { address: s.imd, abi: A("TestToken") },
  pondpad: { address: d.pondpad, abi: A("PondPadToken") },
};
const coinC = (a) => ({ address: a, abi: A("PadToken") });
const read = (c, functionName, args = []) => client.readContract({ ...c, functionName, args });
const bal = (tok, who) => read(tok, "balanceOf", [who]);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const E = (v) => Number(formatEther(v)).toLocaleString("en-US", { maximumFractionDigits: 4 });

async function send(wallet, c, functionName, args, value = 0n) {
  const { request } = await client.simulateContract({ ...c, functionName, args, value, account: wallet.account });
  const hash = await wallet.writeContract(request);
  const rc = await client.waitForTransactionReceipt({ hash });
  if (rc.status !== "success") throw new Error(`${functionName} reverted onchain ${hash}`);
  return rc;
}
/// Simulates an attack call; returns the revert reason, or undefined when the call would succeed.
async function attempt(c, functionName, args, value = 0n, account = attacker) {
  try {
    await client.simulateContract({ ...c, functionName, args, value, account });
    return undefined;
  } catch (e) {
    const r = e instanceof BaseError ? e.walk((x) => x instanceof ContractFunctionRevertedError) : undefined;
    // v4 wraps a hook's revert in WrappedError(target, selector, reason, details): report the hook's own error.
    if (r?.data?.errorName === "WrappedError") {
      try { return `${decodeErrorResult({ abi: errs, data: r.data.args[2] }).errorName} (via hook)`; } catch { return "WrappedError"; }
    }
    return r?.data?.errorName ?? r?.signature ?? (e.shortMessage ?? "reverted").slice(0, 80);
  }
}

const results = [];
const check = (id, name, ok, detail) => {
  results.push({ id, group: id[0], name, ok: ok === null ? null : !!ok, detail });
  console.log(`${ok === null ? "SKIP" : ok ? "PASS" : "FAIL"} ${id} ${name}: ${detail}`);
};
const blocked = (id, name, reason, want) => check(id, name, reason !== undefined && (!want || want.includes(reason)), reason === undefined ? "**the attack call would succeed**" : `refused: ${reason}`);

// PoolManager slot0 for a pool key (extsload of the pool's state slot).
const poolId = (k) => keccak256(encodeAbiParameters([{ type: "address" }, { type: "address" }, { type: "uint24" }, { type: "int24" }, { type: "address" }], [k.currency0, k.currency1, k.fee, k.tickSpacing, k.hooks]));
async function sqrtPriceOf(k) {
  const slot = keccak256(concat([poolId(k), pad(toHex(6), { size: 32 })]));
  const word = await read(C.pm, "extsload", [slot]);
  return BigInt(word) & ((1n << 160n) - 1n);
}
const MIN_SQRT = 4295128739n + 1n, MAX_SQRT = 1461446703485210103287273052203988822378723970342n - 1n;
const NO_CLAIMS = { takeClaims: false, settleUsingBurn: false };

// ------------------------------------------------------------------ attacker funding
if ((await client.getBalance({ address: attacker.address })) < parseEther("0.02"))
  await client.waitForTransactionReceipt({ hash: await mw.sendTransaction({ to: attacker.address, value: parseEther("0.05") }) });
if ((await bal(C.imd, attacker.address)) < parseEther("20000")) await send(mw, C.imd, "mint", [attacker.address, parseEther("50000")]);
for (const spender of [d.router, d.sale, s.swapRouter, s.liquidityRouter])
  if ((await read(C.imd, "allowance", [attacker.address, spender])) < 2n ** 200n) await send(aw, C.imd, "approve", [spender, 2n ** 256n - 1n]);
console.log(`attacker ${attacker.address}`);

const coins = [];
for (let i = 0, n = Number(await read(C.curve, "coinCount")); i < n; i++) coins.push(await read(C.curve, "coinAt", [BigInt(i)]));
const status = {};
for (const c of coins) status[c] = Number(await read(C.curve, "statusOf", [c]));
const tradingCoin = coins.findLast((c) => status[c] === 1);
const gradCoin = coins.findLast((c) => status[c] === 3);

// ------------------------------------------------------------------ coins
if (group === "coins" || group === "all") {
  // K1: buy straight from the curve (skipping the router's snipe tax and max-buy, claiming the dev-buy exemption).
  blocked("K1", "Curve bypass: buy directly from BondingCurve with the exemption flag", await attempt(C.curve, "buy", [tradingCoin, parseEther("100"), 0n, attacker.address, attacker.address, true, zeroAddress]));
  // K2: front-run graduation by initializing the coin's pool first.
  // The key graduation would use: IMD and the coin sorted, fee 0, the hook's tick spacing (poolKey() only answers once live).
  const [c0, c1] = BigInt(s.imd) < BigInt(tradingCoin) ? [s.imd, tradingCoin] : [tradingCoin, s.imd];
  const tk = { currency0: c0, currency1: c1, fee: 0, tickSpacing: Number(await read(C.hook, "TICK_SPACING")), hooks: d.hook };
  blocked("K2", "Graduation front-run: initialize a trading coin's pool", await attempt(C.pm, "initialize", [tk, 79228162514264337593543950336n]));
  if (gradCoin) {
    const gk = await read(C.hook, "poolKey", [gradCoin]);
    const imdIs0 = gk.currency0.toLowerCase() === s.imd.toLowerCase();
    // K3: add liquidity next to the locked position (dilute or extract fees).
    blocked("K3", "Outside liquidity in a graduated coin pool", await attempt(C.lp, "modifyLiquidity", [gk, { tickLower: -887200, tickUpper: 887200, liquidityDelta: 10n ** 18n, salt: pad("0x00", { size: 32 }) }, "0x"]));
    // K4: partial fill: IMD-specified buy with a price limit right next to spot (fee overcharge in Pepes, D-26).
    const sp = await sqrtPriceOf(gk);
    const limit = imdIs0 ? sp - sp / 100000n : sp + sp / 100000n;
    blocked("K4", "Partial fill with IMD specified (D-26)", await attempt(C.swapper, "swap", [gk, { zeroForOne: imdIs0, amountSpecified: -parseEther("200"), sqrtPriceLimitX96: limit }, NO_CLAIMS, "0x"]), ["PartialFill (via hook)", "PartialFill"]);
    // K5: trade through an outside router: the fee must still be the coin's full fee on the filled IMD.
    const fees = await read(C.curve, "feesOf", [gradCoin]);
    const rc = await send(aw, C.swapper, "swap", [gk, { zeroForOne: imdIs0, amountSpecified: -parseEther("10"), sqrtPriceLimitX96: imdIs0 ? MIN_SQRT : MAX_SQRT }, NO_CLAIMS, "0x"]);
    const t = parseEventLogs({ abi: C.hook.abi, eventName: "Trade", logs: rc.logs })[0]?.args;
    const bps = t ? Number((t.fee * 10000n) / parseEther("10")) : -1;
    check("K5", "Fee through an outside router (any router pays, D-26)", t && Math.abs(bps - (150 + Number(fees.taxBps))) <= 1, t ? `fee ${E(t.fee)} IMD on 10 IMD = ${bps} bps (coin: ${150 + Number(fees.taxBps)} bps)` : "no Trade event");
  } else check("K3", "Graduated-coin attacks", null, "no graduated coin yet");
  // K6: name yourself as referrer to get a fee discount: unregistered referrers earn nothing (D-33).
  const before = await read(C.integrators, "balanceOf", [attacker.address]);
  const pendingBefore = await read(C.hook, "pendingIntegrator", [attacker.address]);
  await send(aw, C.router, "buyWith", [tradingCoin, s.imd, parseEther("5"), 0n, BigInt(Math.floor(Date.now() / 1000) + 600), attacker.address]);
  const after = await read(C.integrators, "balanceOf", [attacker.address]);
  const pendingAfter = await read(C.hook, "pendingIntegrator", [attacker.address]);
  check("K6", "Self-referral earns nothing (unregistered referrer, D-33)", after === before && pendingAfter === pendingBefore, `vault ${E(after)} IMD, pending ${E(pendingAfter)} IMD`);
  // K7: pay less ETH than declared.
  blocked("K7", "ETH amount mismatch", await attempt(C.router, "buyWith", [tradingCoin, zeroAddress, parseEther("0.01"), 0n, BigInt(Math.floor(Date.now() / 1000) + 600), zeroAddress], parseEther("0.005")));
}

// ------------------------------------------------------------------ sale and governance
if (group === "sale" || group === "all") {
  const saleStatus = Number(await read(C.sale, "status"));
  if (saleStatus === 1) {
    // S1: the 15M cap counts buys, so moving tokens out never frees it (D-35).
    for (let i = 0; i < 6 && (await read(C.sale, "remainingAllowance", [attacker.address])) > parseEther("2000000"); i++) {
      try { await send(aw, C.sale, "buyWith", [s.imd, parseEther("60"), 0n, BigInt(Math.floor(Date.now() / 1000) + 600), zeroAddress]); } catch { break; }
    }
    const left = await read(C.sale, "remainingAllowance", [attacker.address]);
    const held = await bal(C.pondpad, attacker.address);
    if (held > 0n) await send(aw, C.pondpad, "transfer", [derive("attacker-sink").address, held]);
    const leftAfter = await read(C.sale, "remainingAllowance", [attacker.address]);
    check("S1", "Wallet cap not freed by moving tokens away", leftAfter === left, `allowance ${E(left)} before and ${E(leftAfter)} after moving ${E(held)} $PONDPAD out`);
    blocked("S2", "Force the sale to graduate early", await attempt(C.sale, "graduate", []));
  } else check("S1", "Sale attacks", null, `sale status ${saleStatus}, not trading`);
  blocked("S3", "Open the market without the sale", await attempt(C.controller, "launch", [79228162514264337593543950336n, 1n, 1n]));
  blocked("G1", "Stranger changes launch settings", await attempt(C.config, "setIntegratorShareBps", [2_500]));
  blocked("G2", "Stranger migrates the market (D-40)", await attempt(C.controller, "migrate", [attacker.address]));
  blocked("G3", "Stranger withdraws the market's retained IMD", await attempt(C.market, "withdrawRetainedQuote", [attacker.address, 1n]));
  blocked("G4", "Stranger rescues staked $PONDPAD", await attempt(C.vault, "rescueERC20", [d.pondpad, attacker.address, 1n]));
  blocked("G5", "Stranger rescues the dripper's rewards", await attempt(C.dripper, "rescueERC20", [d.pondpad, attacker.address, 1n]));
  blocked("G6", "Fake airdrop claim", await attempt(C.airdrop, "claim", [attacker.address, parseEther("1000000"), []]));
  blocked("G7", "Stranger pays itself from GrowthFund", await attempt(C.growth, "payJob", [parseEther("1"), pad("0x01", { size: 32 }), "attack"]));
  blocked("G8", "Stranger closes the market backstop", await attempt(C.controller, "closeBackstop", []));
}

// ------------------------------------------------------------------ market (POOL4 fork)
if (group === "market" || group === "all") {
  if (!(await read(C.market, "marketOpen"))) {
    check("M1", "Market attacks", null, "market not open yet");
  } else {
    const key = await read(C.market, "poolKey");
    if ((await read(C.pondpad, "allowance", [attacker.address, s.swapRouter])) < 2n ** 200n) await send(aw, C.pondpad, "approve", [s.swapRouter, 2n ** 256n - 1n]);
    const buy = (imd) => send(aw, C.swapper, "swap", [key, { zeroForOne: true, amountSpecified: -imd, sqrtPriceLimitX96: MIN_SQRT }, NO_CLAIMS, "0x"]);
    const sell = (tok) => send(aw, C.swapper, "swap", [key, { zeroForOne: false, amountSpecified: -tok, sqrtPriceLimitX96: MAX_SQRT }, NO_CLAIMS, "0x"]);

    // M5: outside router pays the market's current fee.
    const fee = await read(C.market, "currentFee");
    const q0 = await read(C.market, "feeQuoteClaims");
    await buy(parseEther("100"));
    const q1 = await read(C.market, "feeQuoteClaims");
    const paid = q1 >= q0 ? q1 - q0 : 0n;
    const expected = (parseEther("100") * BigInt(fee)) / 1_000_000n;
    check("M5", "Market fee through an outside router (D-34)", paid > 0n && (paid > expected ? paid - expected : expected - paid) <= expected / 100n,
      `fee ledger +${E(paid)} IMD on 100 IMD at ${Number(fee) / 10000}% (expected ${E(expected)}; 0 means collectFees ran in between)`);

    // M1: sandwich the stakers' buyer: pump $PONDPAD, then trigger PadBuyer.buy() into the pumped price.
    const buyerImd = await bal(C.imd, d.padBuyer);
    await buy(parseEther("2500"));
    const sandwich = await attempt(C.buyer, "buy", []);
    check("M1", "Sandwich PadBuyer after a pump (price guard, D-43)", sandwich === "PriceOutOfRange" ? true : sandwich === undefined ? false : null,
      sandwich === undefined ? `**buyer would buy into the pump** (holds ${E(buyerImd)} IMD)` : `refused: ${sandwich}${sandwich !== "PriceOutOfRange" ? " (guard not reached; inconclusive)" : ""}`);

    // M2: manipulate the backstop placement: with spot pumped, deploy the band; it must not sit below the floor.
    const floorBefore = await read(C.market, "deploymentFloorTick");
    let placed = null;
    if (await read(C.market, "pendingRebalance")) {
      const r = await send(aw, C.market, "rebalance", []);
      placed = parseEventLogs({ abi: C.market.abi, eventName: "BackstopDeployed", logs: r.logs })[0]?.args ?? null;
    }
    check("M2", "Backstop placement can't be dragged below its floor", placed ? placed.tickLower >= floorBefore : null,
      placed ? `band lower tick ${placed.tickLower} ≥ floor ${floorBefore} (spot ${await read(C.market, "currentTick")})` : "no rebalance pending during the pump; not exercised");

    // Unwind the pump (sells above the cap get trimmed: that is the attacker's loss).
    await sleep(1500);
    await sell(await bal(C.pondpad, attacker.address));

    // M3: keeper-tip farming: churn trades to create rebalance work; the tip must stay below the fees paid.
    const fq0 = await read(C.market, "feeQuoteClaims"), ft0 = await read(C.market, "feeTokenClaims");
    for (let i = 0; i < 4 && !(await read(C.market, "pendingRebalance")); i++) {
      await sleep(1200); await buy(parseEther("600")); await sleep(1200); await sell(await bal(C.pondpad, attacker.address));
    }
    let tip = 0n;
    if (await read(C.market, "pendingRebalance")) {
      const b0 = await bal(C.imd, attacker.address);
      await send(aw, C.market, "rebalance", []);
      tip = (await bal(C.imd, attacker.address)) - b0;
    }
    const feesPaidImd = (await read(C.market, "feeQuoteClaims")) - fq0;
    check("M3", "Keeper-tip farming doesn't pay (tip < fees paid)", tip <= feesPaidImd && tip <= parseEther("1"), `tip ${E(tip)} IMD vs ${E(feesPaidImd)} IMD (+${E((await read(C.market, "feeTokenClaims")) - ft0)} $PONDPAD) in fees paid to create it`);

    // M4: dodge the trim with dust: many sells just under minTrimTokens after a ratchet.
    await sleep(1200);
    await buy(parseEther("300"));
    await sleep(1500);
    const minTrim = await read(C.market, "minTrimTokens");
    for (let i = 0; i < 5; i++) {
      const bal0 = await bal(C.pondpad, attacker.address);
      if (bal0 === 0n) break;
      await sell(bal0 < minTrim ? bal0 : (minTrim * 9n) / 10n);
    }
    await sell(await bal(C.pondpad, attacker.address));
    const held = await read(C.market, "tokensInPool"), cap = await read(C.market, "inventoryCap");
    check("M4", "Dust sells can't build up untrimmed inventory", held <= cap + minTrim, `inventory ${E(held)} vs cap ${E(cap)} (+ min trim ${E(minTrim)})`);
  }
}

mkdirSync(here("runs"), { recursive: true });
const out = here(`runs/attacks-${group}-${new Date().toISOString().replace(/[:.]/g, "-")}.json`);
writeFileSync(out, JSON.stringify({ at: new Date().toISOString(), group, attacker: attacker.address, results }, (_, v) => (typeof v === "bigint" ? v.toString() : v), 2));
console.log(`${results.filter((r) => r.ok === true).length} passed, ${results.filter((r) => r.ok === false).length} failed, ${results.filter((r) => r.ok === null).length} skipped; ${out}`);
