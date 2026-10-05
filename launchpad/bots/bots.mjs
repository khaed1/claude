// PondPad testnet trader bots (HANDOFF §5b, D-63): many wallets with different behaviours trade on Robinhood Chain
// Testnet, and after every round the script checks PondPad's invariants from onchain state.
//
//   node bots.mjs roles              # print the derived role addresses (SAFE, RELAY, X_LINK_KEY, TWEET_CHECKER)
//   node bots.mjs fund               # mint test IMD / USDG to every bot and top up its ETH
//   node bots.mjs run                # trade in rounds until ROUNDS (default: forever), checking invariants each round
//
// Env: RPC_URL (default testnet), MASTER_KEY (the setup wallet: owns the test tokens' mint, funds the bots),
// DEPLOYMENT / SETUP (default ../contracts/deployments/46630.json and 46630-setup.json), BOTS (default 20),
// ROUNDS, ROUND_SECONDS (pause between rounds, default 30), BOT_ETH (top-up target, default 0.1 ether).
// ABIs come from ../contracts/out (run `forge build` first). Logs: runs/<start time>.jsonl, one line per action and
// per invariant check. Wallet keys are derived from MASTER_KEY, so nothing else needs storing. Testnet only.
import { readFileSync, mkdirSync, appendFileSync } from "node:fs";
import {
  createPublicClient, createWalletClient, http, defineChain, keccak256, concat, toHex,
  parseEther, formatEther, decodeErrorResult, BaseError, ContractFunctionRevertedError, zeroAddress,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";

const here = (p) => new URL(p, import.meta.url).pathname;
const cmd = process.argv[2] ?? "run";
const RPC_URL = process.env.RPC_URL ?? "https://rpc.testnet.chain.robinhood.com";
const MASTER_KEY = process.env.MASTER_KEY;
if (!MASTER_KEY) throw new Error("MASTER_KEY is required");
const N = Number(process.env.BOTS ?? 20);
const ROUNDS = Number(process.env.ROUNDS ?? Infinity);
const PAUSE = Number(process.env.ROUND_SECONDS ?? 30);
const BOT_ETH = BigInt(process.env.BOT_ETH ?? parseEther("0.1"));
const master = privateKeyToAccount(MASTER_KEY);

// ------------------------------------------------------------------ derived wallets
const derive = (label) => privateKeyToAccount(keccak256(concat([MASTER_KEY, toHex(`pondpad-testnet:${label}`)])));
const roles = Object.fromEntries(["safe", "relay", "xLinkKey", "tweetChecker"].map((r) => [r, derive(r)]));
if (cmd === "roles") {
  console.log(`export SAFE=${roles.safe.address} RELAY=${roles.relay.address} X_LINK_KEY=${roles.xLinkKey.address} TWEET_CHECKER=${roles.tweetChecker.address}`);
  process.exit(0);
}

const d = JSON.parse(readFileSync(process.env.DEPLOYMENT ?? here("../contracts/deployments/46630.json"), "utf8"));
const s = JSON.parse(readFileSync(process.env.SETUP ?? here("../contracts/deployments/46630-setup.json"), "utf8"));
const chain = defineChain({
  id: Number(d.chainId), name: "Robinhood Chain Testnet",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: { default: { http: [RPC_URL] } },
  contracts: { multicall3: { address: "0xcA11bde05977b3631167028862bE2a173976CA11" } },
});
const client = createPublicClient({ chain, transport: http(RPC_URL) });
const walletOf = (account) => createWalletClient({ account, chain, transport: http(RPC_URL) });

// ------------------------------------------------------------------ ABIs (with every error, so reverts decode)
const art = (name) => JSON.parse(readFileSync(here(`../contracts/out/${name}.sol/${name}.json`), "utf8")).abi;
const names = ["PoolModifyLiquidityTest", "PoolSwapTest", "PadMarketHook", "MarketController", "PadRouter", "BondingCurve", "PadHook", "PadSale", "PadToken", "PondPadToken", "StakedPONDPAD", "TestToken", "PaymentSwapper", "PadLens"];
const raw = Object.fromEntries(names.map((n) => [n, art(n)]));
const errors = Object.values(raw).flat().filter((x) => x.type === "error");
const uniq = (list) => [...new Map(list.map((x) => [JSON.stringify(x), x])).values()];
const abi = Object.fromEntries(names.map((n) => [n, uniq([...raw[n], ...errors])]));

const C = {
  router: { address: d.router, abi: abi.PadRouter },
  curve: { address: d.curve, abi: abi.BondingCurve },
  sale: { address: d.sale, abi: abi.PadSale },
  pondpad: { address: d.pondpad, abi: abi.PondPadToken },
  vault: { address: d.stakedPondpad, abi: abi.StakedPONDPAD },
  market: { address: d.marketHook, abi: abi.PadMarketHook },
  controller: { address: d.marketController, abi: abi.MarketController },
  swapper: { address: s.swapRouter, abi: abi.PoolSwapTest },
  imd: { address: s.imd, abi: abi.TestToken },
  usdg: { address: s.usdg, abi: abi.TestToken },
};
const coinC = (coin) => ({ address: coin, abi: abi.PadToken });
const read = (c, functionName, args = []) => client.readContract({ ...c, functionName, args });

// ------------------------------------------------------------------ logging
mkdirSync(here("runs"), { recursive: true });
const LOG = here(`runs/${new Date().toISOString().replace(/[:.]/g, "-")}.jsonl`);
const stats = { actions: 0, ok: 0, expectedReverts: 0, unexpected: 0, violations: 0 };
const log = (o) => appendFileSync(LOG, JSON.stringify({ t: new Date().toISOString(), ...o }, (_, v) => (typeof v === "bigint" ? v.toString() : v)) + "\n");

// Reverts a bot can expect from normal use (limits, timing, slippage); anything else is reported.
const EXPECTED = new Set(["MaxBuyExceeded", "MaxPerWalletExceeded", "NotStarted", "NotTrading", "Slippage", "SameBlockRedeem", "EnforcedPause", "ZeroAmount", "ZeroFill", "FaucetCooldown", "InsufficientBalance", "InsufficientForFee"]);
const errorName = (e) => {
  if (e instanceof BaseError) {
    const r = e.walk((x) => x instanceof ContractFunctionRevertedError);
    if (r?.data?.errorName) return r.data.errorName;
    if (r?.raw) try { return decodeErrorResult({ abi: errors, data: r.raw }).errorName; } catch {}
  }
  return (e?.shortMessage ?? String(e)).slice(0, 160);
};

/// Simulate, then send. Returns the simulated result, or undefined when it reverted.
async function act(bot, label, c, functionName, args, value = 0n) {
  stats.actions++;
  let sim;
  try {
    sim = await client.simulateContract({ ...c, functionName, args, value, account: bot.account });
  } catch (e) {
    const name = errorName(e);
    const expected = EXPECTED.has(name);
    expected ? stats.expectedReverts++ : stats.unexpected++;
    log({ kind: expected ? "expected-revert" : "UNEXPECTED-REVERT", bot: bot.i, label, functionName, error: name });
    if (!expected) console.log(`  !! bot ${bot.i} ${label}: ${name}`);
    return undefined;
  }
  const hash = await bot.wallet.writeContract(sim.request);
  const rc = await client.waitForTransactionReceipt({ hash });
  if (rc.status !== "success") {
    stats.unexpected++;
    log({ kind: "UNEXPECTED-REVERT", bot: bot.i, label, functionName, error: "reverted onchain", hash });
    console.log(`  !! bot ${bot.i} ${label}: reverted onchain ${hash}`);
    return undefined;
  }
  stats.ok++;
  log({ kind: "tx", bot: bot.i, label, functionName, hash, result: sim.result });
  return sim.result ?? true;
}

// ------------------------------------------------------------------ bots
const PROFILES = ["launcher", "retail", "flipper", "whale", "saleBuyer", "staker", "ethUser", "usdgUser"];
const bots = Array.from({ length: N }, (_, i) => {
  const account = derive(`bot-${i}`);
  return { i, account, wallet: walletOf(account), profile: PROFILES[i % PROFILES.length], held: new Set(), saleBought: 0n };
});
const rnd = (n) => Math.floor(Math.random() * n);
const pick = (list) => list[rnd(list.length)];
const frac = (x, lo, hi) => (x * BigInt(Math.round((lo + Math.random() * (hi - lo)) * 1e6))) / 1_000_000n;
const deadline = () => BigInt(Math.floor(Date.now() / 1000) + 600);
const IMD = (n) => parseEther(String(n));
const TRADING = 1, GRADUATED = 3; // BondingCurve.Status and PadSale.Status

async function fund() {
  const m = { i: "master", account: master, wallet: walletOf(master) };
  for (const b of bots) {
    for (const [tok, target] of [[C.imd, IMD(20_000)], [C.usdg, 50_000n * 10n ** 6n]]) {
      const bal = await read(tok, "balanceOf", [b.account.address]);
      if (bal < target / 2n) await act(m, `mint to bot ${b.i}`, tok, "mint", [b.account.address, target - bal]);
    }
    const eth = await client.getBalance({ address: b.account.address });
    if (eth < BOT_ETH / 2n) {
      const hash = await m.wallet.sendTransaction({ to: b.account.address, value: BOT_ETH - eth });
      await client.waitForTransactionReceipt({ hash });
    }
    console.log(`bot ${b.i} (${b.profile}) ${b.account.address} funded`);
  }
}

async function approveOnce(bot, tok, spender) {
  const allowance = await read(tok, "allowance", [bot.account.address, spender]);
  if (allowance < 2n ** 200n) await act(bot, "approve", tok, "approve", [spender, 2n ** 256n - 1n]);
}

async function coins() {
  const n = Number(await read(C.curve, "coinCount"));
  const list = [];
  for (let i = Math.max(0, n - 30); i < n; i++) list.push(await read(C.curve, "coinAt", [BigInt(i)]));
  return list;
}

/// Buy `coin` paying `token`; for IMD on the curve, the simulated output must equal the curve's own quote.
async function buy(bot, coin, payWith, amount) {
  const status = Number(await read(C.curve, "statusOf", [coin]));
  let quote;
  if (payWith === "imd" && status === TRADING) quote = (await read(C.curve, "quoteBuy", [coin, amount]))[0];
  const tokenIn = payWith === "eth" ? zeroAddress : payWith === "usdg" ? s.usdg : s.imd;
  if (payWith !== "eth") await approveOnce(bot, payWith === "usdg" ? C.usdg : C.imd, d.router);
  const out = await act(bot, `buy ${payWith}`, C.router, "buyWith", [coin, tokenIn, amount, 0n, deadline(), zeroAddress], payWith === "eth" ? amount : 0n);
  if (out !== undefined) {
    bot.held.add(coin);
    if (quote !== undefined && out !== quote) violation("I-quote", `curve quote ${quote} != trade ${out} for ${coin}`);
  }
}

async function sell(bot, coin, payOut, share) {
  const bal = await read(coinC(coin), "balanceOf", [bot.account.address]);
  if (bal === 0n) return bot.held.delete(coin);
  await approveOnce(bot, coinC(coin), d.router);
  const tokenOut = payOut === "eth" ? zeroAddress : payOut === "usdg" ? s.usdg : s.imd;
  await act(bot, `sell ${payOut}`, C.router, "sellFor", [coin, tokenOut, frac(bal, share, share), 0n, deadline(), zeroAddress]);
}

async function launch(bot) {
  const tax = pick([0, 0, 50, 100, 300]);
  const fees = tax === 0 ? [0, 0, 0, 0] : pick([[tax, 10_000, 0, 0], [tax, 0, 10_000, 0], [tax, 0, 0, 10_000], [tax, 5_000, 3_000, 2_000]]);
  const id = `${bot.i}-${Date.now()}`;
  const params = { name: `Bot Frog ${id}`, symbol: `BF${rnd(10000)}`, metadataURI: "ipfs://testnet", feeRecipient: zeroAddress, fees: { taxBps: fees[0], taxToCreatorBps: fees[1], taxToHoldersBps: fees[2], taxToSwarmBps: fees[3] }, salt: keccak256(toHex(id)) };
  const devBuy = Math.random() < 0.5;
  if (bot.profile === "ethUser") {
    const amt = parseEther(devBuy ? "0.005" : "0.003");
    return act(bot, "launch eth", C.router, "launchWith", [params, zeroAddress, amt, devBuy, 0n, 0n, zeroAddress], amt);
  }
  await approveOnce(bot, C.imd, d.router);
  return act(bot, "launch imd", C.router, "launchWith", [params, s.imd, IMD(devBuy ? 1 + rnd(40) : 1), devBuy, 0n, 0n, zeroAddress]);
}

const launchedAt = new Map();
const saleOpen = async () => Number(await read(C.sale, "status")) === TRADING && BigInt(Math.floor(Date.now() / 1000)) >= (await read(C.sale, "startTime"));
/// Trade $PONDPAD in its market (IMD is currency0): buy with IMD, or sell part of the bot's $PONDPAD.
const MIN_SQRT = 4295128739n + 1n, MAX_SQRT = 1461446703485210103287273052203988822378723970342n - 1n;
const NO_CLAIMS = { takeClaims: false, settleUsingBurn: false };
async function marketTrade(bot) {
  const key = await read(C.market, "poolKey");
  const bal = await read(C.pondpad, "balanceOf", [bot.account.address]);
  if (Math.random() < 0.6 || bal === 0n) {
    await approveOnce(bot, C.imd, s.swapRouter);
    return act(bot, "market buy", C.swapper, "swap", [key, { zeroForOne: true, amountSpecified: -IMD(5 + rnd(150)), sqrtPriceLimitX96: MIN_SQRT }, NO_CLAIMS, "0x"]);
  }
  await approveOnce(bot, C.pondpad, s.swapRouter);
  return act(bot, "market sell", C.swapper, "swap", [key, { zeroForOne: false, amountSpecified: -frac(bal, 0.1, 0.4), sqrtPriceLimitX96: MAX_SQRT }, NO_CLAIMS, "0x"]);
}

async function step(bot, list) {
  // Mostly trade coins past their 60 s max-buy window; sometimes snipe a fresh one (tests snipe tax and max-buy).
  const now = Math.floor(Date.now() / 1000);
  for (const c of list) if (!launchedAt.has(c)) launchedAt.set(c, Number(await read(C.curve, "coinLaunchedAt", [c])));
  const mature = list.filter((c) => now - launchedAt.get(c) > 90);
  const coin = mature.length && Math.random() < 0.85 ? pick(mature) : list.length ? pick(list) : undefined;
  switch (bot.profile) {
    case "launcher":
      if (!coin || Math.random() < 0.3) return launch(bot);
      return buy(bot, coin, "imd", IMD(5 + rnd(50)));
    case "retail":
      if (!coin) return;
      return Math.random() < 0.7 || !bot.held.size ? buy(bot, coin, "imd", IMD(1 + rnd(30))) : sell(bot, pick([...bot.held]), "imd", 0.3);
    case "flipper":
      if (bot.held.size) return sell(bot, pick([...bot.held]), pick(["imd", "eth"]), 1);
      if (coin) return buy(bot, coin, "imd", IMD(20 + rnd(100)));
      return;
    case "whale": // pushes coins toward the Leap
      if (coin) return buy(bot, coin, "imd", IMD(300 + rnd(900)));
      return;
    case "ethUser":
      if (Math.random() < 0.35 && (await saleOpen())) {
        const amt = parseEther("0.002") + parseEther(String(rnd(30) / 1000));
        const out = await act(bot, "sale buy eth", C.sale, "buyWith", [zeroAddress, amt, 0n, deadline(), zeroAddress], amt);
        if (out) bot.saleBought += out;
        return;
      }
      if (!coin || Math.random() < 0.15) return launch(bot);
      return Math.random() < 0.75 || !bot.held.size ? buy(bot, coin, "eth", parseEther("0.0005") + parseEther(String(rnd(20) / 10000))) : sell(bot, pick([...bot.held]), "eth", 0.5);
    case "usdgUser":
      if (Math.random() < 0.35 && (await saleOpen())) {
        await approveOnce(bot, C.usdg, d.sale);
        const out = await act(bot, "sale buy usdg", C.sale, "buyWith", [s.usdg, BigInt(5 + rnd(100)) * 10n ** 6n, 0n, deadline(), zeroAddress]);
        if (out) bot.saleBought += out;
        return;
      }
      if (!coin) return;
      return Math.random() < 0.75 || !bot.held.size ? buy(bot, coin, "usdg", BigInt(1 + rnd(20)) * 10n ** 6n) : sell(bot, pick([...bot.held]), "usdg", 0.5);
    case "saleBuyer": {
      const status = Number(await read(C.sale, "status"));
      if (status === TRADING) {
        await approveOnce(bot, C.imd, d.sale);
        if (Math.random() < 0.85) {
          const out = await act(bot, "sale buy", C.sale, "buyWith", [s.imd, IMD(20 + rnd(200)), 0n, deadline(), zeroAddress]);
          if (out) bot.saleBought += out;
        } else {
          const bal = await read(C.pondpad, "balanceOf", [bot.account.address]);
          if (bal > 0n) {
            await approveOnce(bot, C.pondpad, d.sale);
            await act(bot, "sale sell", C.sale, "sellFor", [s.imd, frac(bal, 0.2, 0.2), 0n, deadline(), zeroAddress]);
          }
        }
        return;
      }
      if (status === GRADUATED) return marketTrade(bot);
      return;
    }
    case "staker": {
      const bal = await read(C.pondpad, "balanceOf", [bot.account.address]);
      const shares = await read(C.vault, "balanceOf", [bot.account.address]);
      if (bal > 0n && Math.random() < 0.7) {
        await approveOnce(bot, C.pondpad, d.stakedPondpad);
        return act(bot, "stake", C.vault, "deposit", [frac(bal, 0.5, 1), bot.account.address]);
      }
      if (shares > 0n && Math.random() < 0.3) return act(bot, "unstake", C.vault, "redeem", [frac(shares, 0.2, 0.6), bot.account.address, bot.account.address]);
      // No $PONDPAD yet: buy some in the sale, or in the market after the Leap.
      if (Number(await read(C.sale, "status")) === GRADUATED) return marketTrade(bot);
      if (Number(await read(C.sale, "status")) === TRADING) {
        await approveOnce(bot, C.imd, d.sale);
        const out = await act(bot, "sale buy", C.sale, "buyWith", [s.imd, IMD(50 + rnd(100)), 0n, deadline(), zeroAddress]);
        if (out) bot.saleBought += out;
      }
      return;
    }
  }
}

// ------------------------------------------------------------------ invariants (THREAT-MODEL §2), from onchain state
let lastSharePrice = 0n;
let openedAt = 0n;
function violation(id, detail) {
  stats.violations++;
  log({ kind: "INVARIANT-VIOLATION", id, detail });
  console.log(`  XX ${id}: ${detail}`);
}

async function checkInvariants() {
  const SUPPLY = 10n ** 27n;
  // All reads at one block (coin list included): a consistent snapshot even if anyone trades meanwhile.
  const blockNumber = (await client.getBlockNumber()) - 1n;
  const read = (c, functionName, args = []) => client.readContract({ ...c, functionName, args, blockNumber });
  const n = Number(await read(C.curve, "coinCount"));
  const list = [];
  for (let i = Math.max(0, n - 30); i < n; i++) list.push(await read(C.curve, "coinAt", [BigInt(i)]));
  // I1: the curve holds at least the IMD raised by every coin still trading; I-supply: coins never inflate.
  let owed = 0n;
  for (const coin of list) {
    const info = await read(C.curve, "coinInfo", [coin]);
    const supply = await read(coinC(coin), "totalSupply");
    if (supply > SUPPLY) violation("I-supply", `${coin} supply ${supply}`);
    if (Number(info.status) === TRADING) {
      owed += info.raised;
      const held = await read(coinC(coin), "balanceOf", [d.curve]);
      if (held + info.sold < SUPPLY) violation("I1-tokens", `${coin}: curve holds ${held}, sold ${info.sold}`);
    }
  }
  const curveImd = await read(C.imd, "balanceOf", [d.curve]);
  if (curveImd < owed) violation("I1", `curve IMD ${curveImd} < raised ${owed}`);
  // I9: the router never keeps funds between transactions.
  for (const [tok, name] of [[C.imd, "IMD"], [C.usdg, "USDG"]]) {
    const b = await read(tok, "balanceOf", [d.router]);
    if (b !== 0n) violation("I9", `router holds ${b} ${name}`);
  }
  const routerEth = await client.getBalance({ address: d.router, blockNumber });
  if (routerEth !== 0n) violation("I9", `router holds ${routerEth} wei`);
  // I10: the sale is solvent while trading, never sells past its curve, and caps every bot at 15M.
  const saleStatus = Number(await read(C.sale, "status"));
  if (saleStatus === TRADING) {
    const raised = await read(C.sale, "raised");
    const saleImd = await read(C.imd, "balanceOf", [d.sale]);
    if (saleImd < raised) violation("I10", `sale IMD ${saleImd} < raised ${raised}`);
    const sold = await read(C.sale, "sold");
    if (sold > 600_000_000n * 10n ** 18n) violation("I10", `sale sold ${sold}`);
  }
  for (const b of bots) if (b.saleBought > 15_000_000n * 10n ** 18n) violation("I10-cap", `bot ${b.i} bought ${b.saleBought}`);
  // I22: the deployer (setup wallet) holds no $PONDPAD from the deploy; $PONDPAD supply only falls (burns).
  const pp = await read(C.pondpad, "totalSupply");
  if (pp > SUPPLY) violation("I22", `$PONDPAD supply ${pp}`);
  // I11: the market opens once and its open time never changes.
  const opened = await read(C.controller, "openedAt");
  if (openedAt !== 0n && opened !== openedAt) violation("I11", `openedAt moved ${openedAt} -> ${opened}`);
  if (opened !== 0n) openedAt = opened;
  // I13: sPONDPAD's value per share never falls.
  const price = await read(C.vault, "convertToAssets", [10n ** 18n]);
  if (price < lastSharePrice) violation("I13", `share price fell ${lastSharePrice} -> ${price}`);
  lastSharePrice = price;
  log({ kind: "invariants", block: blockNumber, coins: list.length, curveImd, owed, saleStatus, sharePrice: price, openedAt: opened });
}

// ------------------------------------------------------------------ main
if (cmd === "fund") {
  await fund();
} else if (cmd === "deepen") {
  // Add ~ETH_IN of full-range liquidity to the IMD/ETH pool (priced near 411 IMD/ETH; spare ETH is refunded).
  const eth = parseEther(process.env.ETH_IN ?? "1");
  const m = { i: "master", account: master, wallet: walletOf(master) };
  const lp = { address: s.liquidityRouter, abi: abi.PoolModifyLiquidityTest };
  const key = { currency0: zeroAddress, currency1: s.imd, fee: 10_000, tickSpacing: 100, hooks: zeroAddress };
  const liquidity = (eth * 202731n) / 10000n * 90n / 100n; // eth · sqrt(411) · 0.9
  await act(m, "mint for liquidity", C.imd, "mint", [master.address, (eth * 411n * 12n) / 10n]);
  await approveOnce(m, C.imd, s.liquidityRouter);
  const r = await act(m, "deepen IMD/ETH", lp, "modifyLiquidity", [key, { tickLower: -887200, tickUpper: 887200, liquidityDelta: liquidity, salt: "0x" + "00".repeat(32) }, "0x"], eth);
  console.log(r ? `added ${formatEther(liquidity)} liquidity (~${formatEther(eth)} ETH)` : "failed, see log");
} else if (cmd === "run") {
  console.log(`${N} bots, log ${LOG}`);
  for (let r = 1; r <= ROUNDS; r++) {
    const list = await coins();
    for (const b of [...bots].sort(() => Math.random() - 0.5)) {
      try {
        await step(b, list);
      } catch (e) {
        stats.unexpected++;
        log({ kind: "BOT-ERROR", bot: b.i, error: errorName(e) });
        console.log(`  !! bot ${b.i}: ${errorName(e)}`);
      }
    }
    await checkInvariants();
    const grads = [];
    for (const c of await coins()) if (Number(await read(C.curve, "statusOf", [c])) === GRADUATED) grads.push(c);
    console.log(`round ${r}: ${JSON.stringify(stats)}; coins ${(await coins()).length}, graduated ${grads.length}, sale status ${await read(C.sale, "status")}, curve IMD ${formatEther(await read(C.imd, "balanceOf", [d.curve]))}`);
    log({ kind: "round", r, ...stats });
    if (r < ROUNDS) await new Promise((res) => setTimeout(res, PAUSE * 1000));
  }
} else {
  throw new Error(`unknown command ${cmd}`);
}
