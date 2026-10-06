// PondPad keeper: calls the permissionless upkeep functions on a timer (HANDOFF §6).
//
// Every call is permissionless and safe to skip or repeat; this script only saves people from doing it by hand.
// Each job checks a cheap view first, then simulates the call, and sends it only if the simulation succeeds.
//
//   RPC_URL=https://rpc.mainnet.chain.robinhood.com KEEPER_KEY=0x… node keeper.mjs          # loop every 5 min
//   … node keeper.mjs --once                                                              # one pass (cron)
//   … node keeper.mjs --once --dry                                                        # simulate only
//
// Env: RPC_URL, KEEPER_KEY (a hot wallet with a little ETH), DEPLOYMENT (default
// ../contracts/deployments/4663.json), STATE (default ./state.json), INTERVAL_SECONDS (default 300),
// MAX_COINS_PER_PASS (default 500).
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { createPublicClient, createWalletClient, http, parseAbi, defineChain, formatEther } from "viem";
import { privateKeyToAccount } from "viem/accounts";

const args = new Set(process.argv.slice(2));
const ONCE = args.has("--once");
const DRY = args.has("--dry");
const RPC_URL = process.env.RPC_URL ?? "https://rpc.mainnet.chain.robinhood.com";
const DEPLOYMENT = process.env.DEPLOYMENT ?? new URL("../contracts/deployments/4663.json", import.meta.url).pathname;
const STATE = process.env.STATE ?? new URL("./state.json", import.meta.url).pathname;
const INTERVAL = Number(process.env.INTERVAL_SECONDS ?? 300);
const MAX_COINS = Number(process.env.MAX_COINS_PER_PASS ?? 500);

const MIN = 60, HOUR = 3600, DAY = 86400, WEEK = 7 * DAY;

const a = JSON.parse(readFileSync(DEPLOYMENT, "utf8"));
const chain = defineChain({
  id: Number(a.chainId ?? 4663),
  name: "Robinhood Chain",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: { default: { http: [RPC_URL] } },
  contracts: { multicall3: { address: "0xcA11bde05977b3631167028862bE2a173976CA11" } },
});
const client = createPublicClient({ chain, transport: http(RPC_URL) });
const key = process.env.KEEPER_KEY;
if (!key && !DRY) throw new Error("KEEPER_KEY is required (or run with --dry)");
const account = key ? privateKeyToAccount(key) : undefined;
const wallet = account ? createWalletClient({ account, chain, transport: http(RPC_URL) }) : undefined;

const abi = {
  erc20: parseAbi(["function balanceOf(address) view returns (uint256)"]),
  buyer: parseAbi(["function buy() returns (uint256)", "function lastBuyAt() view returns (uint256)", "function interval() view returns (uint256)"]),
  dripper: parseAbi(["function drip() returns (uint256, uint256)", "function canDrip() view returns (bool)"]),
  market: parseAbi([
    "function rebalance()",
    "function pendingRebalance() view returns (bool)",
    "function settleClaims()",
    "function marketOpen() view returns (bool)",
    "function burnClaims() view returns (uint256)",
    "function rewardClaims() view returns (uint256)",
    "function quoteClaims() view returns (uint256)",
  ]),
  burner: parseAbi(["function burn() returns (uint256)"]),
  controller: parseAbi(["function collectFees()"]),
  splitter: parseAbi(["function distribute()"]),
  sale: parseAbi(["function graduate()", "function status() view returns (uint8)"]),
  curve: parseAbi(["function graduate(address)", "function coinCount() view returns (uint256)", "function coinAt(uint256) view returns (address)", "function statusOf(address) view returns (uint8)"]),
  hook: parseAbi(["function flush(address)", "function pending(address) view returns (uint128 protocol, uint128 creator, uint128 holders, uint128 swarm)"]),
  cto: parseAbi([
    "function execute(address)",
    "function pendingOf(address) view returns ((address newRecipient, address proposer, uint64 executableAt, uint64 expiresAt, bool byCouncil, bool contested, bool confirmed))",
  ]),
  workerFund: parseAbi(["function release() returns (uint256, uint256)", "function workerRewards() view returns (address)"]),
  vault: parseAbi(["function claim(address) returns (uint256)", "function recipientOf(address) view returns (address)", "function balanceOf(address) view returns (uint256)"]),
  budget: parseAbi(["function sweepToHolders(address) returns (uint256)", "function balanceOf(address) view returns (uint256)"]),
  vesting: parseAbi(["function release() returns (uint256)", "function releasable() view returns (uint256)"]),
  airdrop: parseAbi(["function sweep() returns (uint256)", "function claimDeadline() view returns (uint256)"]),
};

const CURVE_FULL = 2, CURVE_GRADUATED = 3, SALE_FULL = 2;

// ------------------------------------------------------------------ state (last run per job)

const state = existsSync(STATE) ? JSON.parse(readFileSync(STATE, "utf8")) : {};
const due = (name, every, now) => !state[name] || now - state[name] >= every;
const saveState = () => writeFileSync(STATE, JSON.stringify(state, null, 2));

const read = (address, kind, functionName, args = []) => client.readContract({ address, abi: abi[kind], functionName, args });
const erc20 = (token, who) => read(token, "erc20", "balanceOf", [who]);

/** Simulates `functionName`; sends it unless --dry. Returns true if it would succeed. */
async function send(label, address, kind, functionName, args = []) {
  try {
    await client.simulateContract({ address, abi: abi[kind], functionName, args, account: account?.address ?? address });
  } catch (e) {
    log(`skip ${label}: ${short(e)}`);
    return false;
  }
  if (DRY) {
    log(`would call ${label}`);
    return true;
  }
  // 50% gas headroom: the market hook's rebalance / settle work depends on state that can change between the
  // estimate and inclusion (seen on the testnet: a rebalance ran out of gas at 98% of its estimate).
  const gas = await client.estimateContractGas({ address, abi: abi[kind], functionName, args, account });
  const hash = await wallet.writeContract({ address, abi: abi[kind], functionName, args, gas: (gas * 3n) / 2n });
  const r = await client.waitForTransactionReceipt({ hash });
  log(`${r.status === "success" ? "ok" : "FAILED"} ${label} ${hash} (gas ${r.gasUsed})`);
  return r.status === "success";
}

const log = (m) => console.log(`${new Date().toISOString()} ${m}`);
const short = (e) => (e.shortMessage ?? e.message ?? String(e)).split("\n")[0];

// ------------------------------------------------------------------ jobs

async function coins() {
  const n = Number(await read(a.curve, "curve", "coinCount"));
  const from = Math.max(0, n - MAX_COINS); // newest first if there are more than MAX_COINS
  const calls = [];
  for (let i = from; i < n; i++) calls.push({ address: a.curve, abi: abi.curve, functionName: "coinAt", args: [BigInt(i)] });
  return calls.length ? (await client.multicall({ contracts: calls, allowFailure: false })) : [];
}

async function multi(list, kind, address, functionName) {
  if (!list.length) return [];
  return client.multicall({
    contracts: list.map((c) => ({ address: address ?? c, abi: abi[kind], functionName, args: [c] })),
    allowFailure: false,
  });
}

async function pass() {
  const block = await client.getBlock();
  const now = Number(block.timestamp);
  const marketOpen = await read(a.marketHook, "market", "marketOpen");

  const jobs = [
    // $PONDPAD sale and market (fees are collected and split before the stakers' buyer spends them)
    ["PadSale.graduate", MIN, async () => (Number(await read(a.sale, "sale", "status")) === SALE_FULL ? send("PadSale.graduate", a.sale, "sale", "graduate") : null)],
    ["MarketController.collectFees", DAY, async () => (marketOpen ? send("MarketController.collectFees", a.marketController, "controller", "collectFees") : null)],
    ["FeeSplitter.distribute", DAY, async () => ((await erc20(a.imd, a.feeSplitter)) > 0n ? send("FeeSplitter.distribute", a.feeSplitter, "splitter", "distribute") : null)],
    // Checked every pass; sends when PadBuyer's own interval (set by the 48 h timelock, 10 min by default) has passed.
    ["PadBuyer.buy", MIN, async () => {
      if (!marketOpen || (await erc20(a.imd, a.padBuyer)) < 10n ** 18n) return null;
      const [last, every] = await Promise.all([read(a.padBuyer, "buyer", "lastBuyAt"), read(a.padBuyer, "buyer", "interval")]);
      return BigInt(Math.floor(Date.now() / 1000)) >= last + every ? send("PadBuyer.buy", a.padBuyer, "buyer", "buy") : null;
    }],
    ["RewardDripper.drip", HOUR, async () => ((await read(a.rewardDripper, "dripper", "canDrip")) ? send("RewardDripper.drip", a.rewardDripper, "dripper", "drip") : null)],
    ["PadMarketHook.rebalance", 5 * MIN, async () => (marketOpen && (await read(a.marketHook, "market", "pendingRebalance")) ? send("PadMarketHook.rebalance", a.marketHook, "market", "rebalance") : null)],
    ["PadMarketHook.settleClaims", HOUR, async () => {
      if (!marketOpen) return null;
      const c = await Promise.all(["burnClaims", "rewardClaims", "quoteClaims"].map((f) => read(a.marketHook, "market", f)));
      return c.some((x) => x > 0n) ? send("PadMarketHook.settleClaims", a.marketHook, "market", "settleClaims") : null;
    }],
    ["PadBurner.burn", HOUR, async () => ((await erc20(a.pondpad, a.burner)) > 0n ? send("PadBurner.burn", a.burner, "burner", "burn") : null)],
    // Funds and distributions
    ["WorkerFund.release", WEEK, async () => {
      const to = await read(a.workerFund, "workerFund", "workerRewards");
      if (to === "0x0000000000000000000000000000000000000000") return null;
      const [i, t] = await Promise.all([erc20(a.imd, a.workerFund), erc20(a.pondpad, a.workerFund)]);
      return i + t > 0n ? send("WorkerFund.release", a.workerFund, "workerFund", "release") : null;
    }],
    ["TeamVesting.release", DAY, async () => ((await read(a.teamVesting, "vesting", "releasable")) > 0n ? send("TeamVesting.release", a.teamVesting, "vesting", "release") : null)],
    ["AirdropDistributor.sweep", DAY, async () => {
      const deadline = Number(await read(a.airdrop, "airdrop", "claimDeadline"));
      if (deadline === 0 || now < deadline || (await erc20(a.pondpad, a.airdrop)) === 0n) return null;
      return send("AirdropDistributor.sweep", a.airdrop, "airdrop", "sweep");
    }],
    // Per coin
    ["coins", 5 * MIN, async () => {
      const list = await coins();
      const statuses = await multi(list, "curve", a.curve, "statusOf");
      for (let i = 0; i < list.length; i++) {
        if (Number(statuses[i]) === CURVE_FULL) await send(`BondingCurve.graduate(${list[i]})`, a.curve, "curve", "graduate", [list[i]]);
      }
      const graduated = list.filter((_, i) => Number(statuses[i]) === CURVE_GRADUATED);
      if (due("coins.flush", HOUR, now)) {
        const pend = await multi(graduated, "hook", a.hook, "pending");
        for (let i = 0; i < graduated.length; i++) {
          if (pend[i].some((x) => x > 0n)) await send(`PadHook.flush(${graduated[i]})`, a.hook, "hook", "flush", [graduated[i]]);
        }
        state["coins.flush"] = now;
      }
      if (due("coins.cto", HOUR, now)) {
        const pend = await multi(list, "cto", a.ctoModule, "pendingOf");
        for (let i = 0; i < list.length; i++) {
          const t = pend[i];
          if (t.executableAt > 0n && BigInt(now) >= t.executableAt && BigInt(now) < t.expiresAt) {
            await send(`CTOModule.execute(${list[i]})`, a.ctoModule, "cto", "execute", [list[i]]);
          }
        }
        state["coins.cto"] = now;
      }
      if (due("coins.holders", WEEK, now)) {
        // Coins whose takeover routed fees to holders (recipient = the coin itself, D-52).
        const recipients = await multi(list, "vault", a.creatorVault, "recipientOf");
        const toHolders = list.filter((c, i) => recipients[i].toLowerCase() === c.toLowerCase());
        const [owed, budget] = await Promise.all([multi(toHolders, "vault", a.creatorVault, "balanceOf"), multi(toHolders, "budget", a.swarmBudget, "balanceOf")]);
        for (let i = 0; i < toHolders.length; i++) {
          if (owed[i] > 0n) await send(`CreatorVault.claim(${toHolders[i]})`, a.creatorVault, "vault", "claim", [toHolders[i]]);
          if (budget[i] > 0n) await send(`SwarmBudget.sweepToHolders(${toHolders[i]})`, a.swarmBudget, "budget", "sweepToHolders", [toHolders[i]]);
        }
        state["coins.holders"] = now;
      }
      return true;
    }],
  ];

  for (const [name, every, run] of jobs) {
    if (!due(name, every, now)) continue;
    try {
      // A job counts as done for its period once it tried to send (sent, or its simulation said no). When its
      // cheap precondition is false (null), it is checked again next pass.
      if ((await run()) !== null) state[name] = now;
    } catch (e) {
      log(`error ${name}: ${short(e)}`);
    }
  }
  saveState();
}

async function main() {
  if (account) {
    const bal = await client.getBalance({ address: account.address });
    log(`keeper ${account.address}, ${formatEther(bal)} ETH, ${DRY ? "dry run" : "live"}`);
  }
  for (;;) {
    try {
      await pass();
    } catch (e) {
      log(`pass failed: ${short(e)}`);
    }
    if (ONCE) return;
    await new Promise((r) => setTimeout(r, INTERVAL * 1000));
  }
}

main();
