// PondPad testnet report: activity from the bot and keeper logs plus a health check from live onchain state.
//
//   MASTER_KEY=… node report.mjs [runs/*.jsonl …] > report.md
//
// Env: RPC_URL (default testnet), DEPLOYMENT / SETUP (default ../contracts/deployments/46630*.json), BOTS (default 24),
// KEEPER_LOG (optional keeper output to count its calls). Read-only: sends nothing.
import { readFileSync, existsSync } from "node:fs";
import { createPublicClient, http, defineChain, keccak256, concat, toHex, formatEther, formatUnits } from "viem";
import { privateKeyToAccount } from "viem/accounts";

const here = (p) => new URL(p, import.meta.url).pathname;
const RPC_URL = process.env.RPC_URL ?? "https://rpc.testnet.chain.robinhood.com";
const d = JSON.parse(readFileSync(process.env.DEPLOYMENT ?? here("../contracts/deployments/46630.json"), "utf8"));
const s = JSON.parse(readFileSync(process.env.SETUP ?? here("../contracts/deployments/46630-setup.json"), "utf8"));
const chain = defineChain({ id: Number(d.chainId), name: "Robinhood Chain Testnet", nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 }, rpcUrls: { default: { http: [RPC_URL] } }, contracts: { multicall3: { address: "0xcA11bde05977b3631167028862bE2a173976CA11" } } });
const client = createPublicClient({ chain, transport: http(RPC_URL) });
const art = (n) => JSON.parse(readFileSync(here(`../contracts/out/${n}.sol/${n}.json`), "utf8")).abi;
const c = (address, n) => ({ address, abi: art(n) });
// Every read is pinned to one block, so the snapshot is consistent while bots keep trading.
const blockNumber = BigInt(process.env.BLOCK ?? (await client.getBlockNumber()));
const read = (x, functionName, args = []) => client.readContract({ ...x, functionName, args, blockNumber });
const E = (v, dp = 2) => Number(formatEther(v)).toLocaleString("en-US", { maximumFractionDigits: dp });
const U = (v) => Number(formatUnits(v, 6)).toLocaleString("en-US", { maximumFractionDigits: 2 });

const imd = c(s.imd, "TestToken"), usdg = c(s.usdg, "TestToken"), pondpad = c(d.pondpad, "PondPadToken");
const curve = c(d.curve, "BondingCurve"), sale = c(d.sale, "PadSale"), market = c(d.marketHook, "PadMarketHook");
const controller = c(d.marketController, "MarketController"), vault = c(d.stakedPondpad, "StakedPONDPAD");
const bal = (tok, who) => read(tok, "balanceOf", [who]);

// ------------------------------------------------------------------ activity from the logs
const files = process.argv.slice(2).filter(existsSync);
const lines = files.flatMap((f) => readFileSync(f, "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l)));
const count = (pred) => lines.filter(pred).length;
const byLabel = {};
for (const l of lines) if (l.kind === "tx" || l.kind.includes("REVERT")) {
  const k = `${l.label.replace(/ \d+$/, "")}${l.kind === "tx" ? "" : ` → ${l.error}`}`;
  byLabel[k] = (byLabel[k] ?? 0) + 1;
}
const rounds = count((l) => l.kind === "round");
const checks = count((l) => l.kind === "invariants");
const unexpected = lines.filter((l) => l.kind === "UNEXPECTED-REVERT" || l.kind === "BOT-ERROR");
const violations = lines.filter((l) => l.kind === "INVARIANT-VIOLATION");
const t0 = lines[0]?.t, t1 = lines.at(-1)?.t;

let keeper = {};
if (process.env.KEEPER_LOG && existsSync(process.env.KEEPER_LOG))
  for (const m of readFileSync(process.env.KEEPER_LOG, "utf8").matchAll(/ ok (\S+)/g)) keeper[m[1]] = (keeper[m[1]] ?? 0) + 1;

// ------------------------------------------------------------------ onchain state
const n = Number(await read(curve, "coinCount"));
let trading = 0, graduated = 0, raised = 0n, coinsToken = 0n;
for (let i = 0; i < n; i++) {
  const coin = await read(curve, "coinAt", [BigInt(i)]);
  const info = await read(curve, "coinInfo", [coin]);
  if (Number(info.status) === 1) { trading++; raised += info.raised; }
  if (Number(info.status) === 3) graduated++;
}
const curveImd = await bal(imd, d.curve);
const saleStatus = ["Unfunded", "Trading", "Full", "Graduated"][Number(await read(sale, "status"))];
const saleRaised = await read(sale, "raised"), saleSold = await read(sale, "sold"), saleImd = await bal(imd, d.sale);
const opened = await read(controller, "openedAt");
const mk = {
  open: await read(market, "marketOpen"), fee: await read(market, "currentFee"),
  burned: await read(market, "totalBurned"), rewarded: await read(market, "totalRewarded"),
  retained: await read(market, "retainedQuote"), feeTok: await read(market, "feeTokenClaims"), feeQuote: await read(market, "feeQuoteClaims"),
};
const pp = { supply: await read(pondpad, "totalSupply"), sale: await bal(pondpad, d.sale), airdrop: await bal(pondpad, d.airdrop), vesting: await bal(pondpad, d.teamVesting), reserve: await bal(pondpad, d.fastTimelock), dripper: await bal(pondpad, d.rewardDripper), deployer: await bal(pondpad, "0x4b91078b2374c956A65F7Af0999CaE0a935E6821") };
const st = { assets: await read(vault, "totalAssets"), shares: await read(vault, "totalSupply"), price: await read(vault, "convertToAssets", [10n ** 18n]) };
const flows = {
  splitter: await bal(imd, d.feeSplitter), buyer: await bal(imd, d.padBuyer), workers: await bal(imd, d.workerFund),
  growth: await bal(imd, d.growthFund), creator: await bal(imd, d.creatorVault), swarm: await bal(imd, d.swarmBudget),
  integrators: await bal(imd, d.integratorVault),
};
const router = { imd: await bal(imd, d.router), usdg: await bal(usdg, d.router), eth: await client.getBalance({ address: d.router, blockNumber }) };
const safe = await read(c(d.feeSplitter, "FeeSplitter"), "recipients");
const treasury = await bal(imd, safe.treasury);
const fast = c(d.fastTimelock, "TimelockController"), slow = c(d.slowTimelock, "TimelockController");
const delays = [await read(fast, "getMinDelay"), await read(slow, "getMinDelay")];

const MK = process.env.MASTER_KEY;
let botEth = 0n, botCount = Number(process.env.BOTS ?? 24);
if (MK) for (let i = 0; i < botCount; i++) botEth += await client.getBalance({ address: privateKeyToAccount(keccak256(concat([MK, toHex(`pondpad-testnet:bot-${i}`)]))).address });
const masterEth = await client.getBalance({ address: "0x4b91078b2374c956A65F7Af0999CaE0a935E6821" });

// ------------------------------------------------------------------ health checks
const health = [
  ["Curve solvency (I1)", curveImd >= raised, `curve holds ${E(curveImd)} IMD, coins still trading raised ${E(raised)} IMD`],
  ["Router holds nothing (I9)", router.imd === 0n && router.usdg === 0n && router.eth === 0n, `IMD ${E(router.imd)}, USDG ${U(router.usdg)}, ETH ${E(router.eth, 6)}`],
  ["Sale solvency (I10)", saleStatus !== "Trading" || saleImd >= saleRaised, `${saleStatus}: holds ${E(saleImd)} IMD, raised ${E(saleRaised)} IMD, sold ${E(saleSold, 0)} $PONDPAD`],
  ["$PONDPAD supply (I22)", pp.supply <= 10n ** 27n && pp.deployer === 0n, `supply ${E(pp.supply, 0)}, deployer holds ${E(pp.deployer)}`],
  ["Market opened once, at graduation (I11)", saleStatus !== "Graduated" || (mk.open && opened > 0n), mk.open ? `open since ${new Date(Number(opened) * 1000).toISOString()}, fee ${Number(mk.fee) / 10000}%` : "not open yet"],
  ["Staking value per share (I13)", st.price >= 10n ** 12n, `${formatUnits(st.price, 12)} $PONDPAD-units per sPONDPAD unit (starts at 1.0)`],
  ["Timelocks", delays[0] === 600n && delays[1] === 1800n, `${delays[0]} s / ${delays[1]} s`],
  ["Bots: unexpected reverts", unexpected.length === 0, `${unexpected.length}`],
  ["Bots: invariant violations", violations.length === 0, `${violations.length} in ${checks} checks`],
];

// POOL4 mechanics (pool4.mjs): the latest run, if any.
const { readdirSync } = await import("node:fs");
const pool4File = existsSync(here("runs")) ? readdirSync(here("runs")).filter((f) => f.startsWith("pool4-")).sort().at(-1) : undefined;
const pool4 = pool4File ? JSON.parse(readFileSync(here(`runs/${pool4File}`), "utf8")) : undefined;
if (pool4) health.push(["POOL4 mechanics (market)", pool4.results.every((x) => x.ok), `${pool4.results.filter((x) => x.ok).length}/${pool4.results.length} checks`]);

const out = [];
const p = (x = "") => out.push(x);
p(`# PondPad testnet report`);
p();
p(`Robinhood Chain Testnet (46630), state at block ${blockNumber}, generated ${new Date().toISOString()}. Bot logs: ${t0 ?? "–"} → ${t1 ?? "–"}.`);
p();
p(`## Health: ${health.every((h) => h[1]) ? "HEALTHY" : "ATTENTION NEEDED"}`);
p();
p(`| Check | Result | Detail |`);
p(`|---|---|---|`);
for (const [name, ok, detail] of health) p(`| ${name} | ${ok ? "OK" : "**FAIL**"} | ${detail} |`);
p();
p(`## Activity`);
p();
p(`- Rounds: ${rounds}, invariant checks: ${checks}, actions: ${count((l) => l.kind === "tx")} sent, ${count((l) => l.kind === "expected-revert")} expected reverts, ${unexpected.length} unexpected.`);
p(`- Coins: ${n} launched, ${graduated} graduated, ${trading} still on the curve.`);
p(`- Keeper calls: ${Object.entries(keeper).map(([k, v]) => `${k} ×${v}`).join(", ") || "–"}.`);
p();
p(`| Action | Count |`);
p(`|---|---|`);
for (const [k, v] of Object.entries(byLabel).sort((a, b) => b[1] - a[1])) p(`| ${k} | ${v} |`);
p();
p(`## $PONDPAD`);
p();
p(`| | |`);
p(`|---|---|`);
p(`| Sale | ${saleStatus}, raised ${E(saleRaised)} IMD, sold ${E(saleSold, 0)} |`);
p(`| Market | ${mk.open ? `open, fee ${Number(mk.fee) / 10000}%` : "not open"}; burned ${E(mk.burned, 0)}, rewarded to stakers ${E(mk.rewarded, 0)}, backstop IMD ${E(mk.retained)}; unclaimed fees ${E(mk.feeQuote)} IMD + ${E(mk.feeTok, 0)} $PONDPAD |`);
p(`| Supply | ${E(pp.supply, 0)} (sale ${E(pp.sale, 0)}, airdrop ${E(pp.airdrop, 0)}, vesting ${E(pp.vesting, 0)}, reserve ${E(pp.reserve, 0)}, dripper ${E(pp.dripper, 0)}) |`);
p(`| Staking | ${E(st.assets, 0)} $PONDPAD staked, value per share ×${formatUnits(st.price, 12)} |`);
p();
p(`## Fee flows (IMD held now)`);
p();
p(`| Splitter | PadBuyer (stakers) | WorkerFund | GrowthFund | Treasury (Safe) | CreatorVault | SwarmBudget | IntegratorVault |`);
p(`|---|---|---|---|---|---|---|---|`);
p(`| ${E(flows.splitter)} | ${E(flows.buyer)} | ${E(flows.workers)} | ${E(flows.growth)} | ${E(treasury)} | ${E(flows.creator)} | ${E(flows.swarm)} | ${E(flows.integrators)} |`);
p();
p(`## ETH`);
p();
p(`Testnet wallet ${E(masterEth, 4)} ETH; bots ${E(botEth, 4)} ETH in total.`);
if (pool4) {
  p();
  p(`## POOL4 mechanics ($PONDPAD market, ${pool4.at})`);
  p();
  p(`${pool4.results.filter((x) => x.ok).length} of ${pool4.results.length} checks passed (tester ${pool4.tester}).`);
  p();
  p(`| # | Mechanism | Result | Detail |`);
  p(`|---|---|---|---|`);
  for (const x of pool4.results) p(`| ${x.id} | ${x.name} | ${x.ok ? "OK" : "**FAIL**"} | ${x.detail} |`);
}
if (unexpected.length || violations.length) {
  p();
  p(`## Problems`);
  p();
  for (const l of [...violations, ...unexpected].slice(0, 50)) p(`- ${l.t} ${l.kind} ${l.id ?? l.label ?? ""}: ${l.detail ?? l.error ?? ""}`);
}
console.log(out.join("\n"));
