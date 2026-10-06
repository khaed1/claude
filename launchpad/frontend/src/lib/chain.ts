import { useQuery } from '@tanstack/react-query';
import { usePublicClient } from 'wagmi';
import { getAbiItem, type Address, type Hex, type PublicClient } from 'viem';
import { BondingCurveAbi, PadFactoryAbi, PadHookAbi, PadLensAbi, PadConfigAbi, PadTokenAbi, SocialRegistryAbi } from '../abi';
import { addr, DEPLOY_BLOCK, LOG_CHUNK } from '../config';

export type CoinView = Awaited<ReturnType<typeof readCoin>>;
export const STATUS = { None: 0, Trading: 1, Full: 2, Graduated: 3 } as const;

function usePc(): PublicClient {
  const c = usePublicClient();
  if (!c) throw new Error('no public client');
  return c as PublicClient;
}

export async function readCoin(pc: PublicClient, coin: Address) {
  return pc.readContract({ address: addr.lens, abi: PadLensAbi, functionName: 'coinView', args: [coin] });
}

/** Every coin, newest first, from PadLens in pages of 40. */
export function useCoinList() {
  const pc = usePc();
  return useQuery({
    queryKey: ['coins'],
    refetchInterval: 15_000,
    queryFn: async () => {
      const n = await pc.readContract({ address: addr.lens, abi: PadLensAbi, functionName: 'coinCount' });
      const pages: Promise<readonly CoinView[]>[] = [];
      for (let off = 0n; off < n; off += 40n) {
        pages.push(pc.readContract({ address: addr.lens, abi: PadLensAbi, functionName: 'coins', args: [off, 40n, true] }));
      }
      return (await Promise.all(pages)).flat();
    },
  });
}

export function useCoin(coin?: Address) {
  const pc = usePc();
  return useQuery({
    queryKey: ['coin', coin],
    enabled: !!coin,
    refetchInterval: 8_000,
    queryFn: () => readCoin(pc, coin!),
  });
}

export function useLaunchSettings() {
  const pc = usePc();
  return useQuery({
    queryKey: ['launchSettings'],
    staleTime: 300_000,
    queryFn: async () => ({
      settings: await pc.readContract({ address: addr.config, abi: PadConfigAbi, functionName: 'launchSettings' }),
      paused: await pc.readContract({ address: addr.config, abi: PadConfigAbi, functionName: 'launchesPaused' }),
    }),
  });
}

// ------------------------------------------------------------------ Logs

/** eth_getLogs in chunks (Robinhood RPCs cap the range). */
export async function scan<T>(pc: PublicClient, from: bigint, fetch: (from: bigint, to: bigint) => Promise<T[]>): Promise<T[]> {
  const head = await pc.getBlockNumber();
  const ranges: [bigint, bigint][] = [];
  for (let a = from; a <= head; a += LOG_CHUNK) ranges.push([a, a + LOG_CHUNK - 1n > head ? head : a + LOG_CHUNK - 1n]);
  return (await Promise.all(ranges.map(([a, b]) => fetch(a, b)))).flat();
}

// The RPC returns blockTimestamp = 0 in logs, so times come from sampled block headers, interpolated
// (exact to the block at each sample; Robinhood makes several blocks a second, so the error is seconds).
const anchors = new Map<bigint, number>();
async function timeline(pc: PublicClient, from: bigint, head: bigint) {
  const step = (head - from) / 24n || 1n;
  const want: bigint[] = [];
  for (let b = from; b < head; b += step) want.push((b / 1000n) * 1000n); // round so samples are reused across calls
  want.push(head);
  await Promise.all(want.filter((b) => !anchors.has(b)).map(async (b) => anchors.set(b, Number((await pc.getBlock({ blockNumber: b })).timestamp))));
  const pts = [...anchors.entries()].sort((a, b) => (a[0] < b[0] ? -1 : 1));
  return (block: bigint): number => {
    let i = pts.findIndex(([b]) => b >= block);
    if (i === -1) return pts[pts.length - 1][1];
    if (i === 0) return pts[0][1];
    const [b0, t0] = pts[i - 1], [b1, t1] = pts[i];
    return t0 + ((t1 - t0) * Number(block - b0)) / Number(b1 - b0 || 1n);
  };
}
export async function timesFor(pc: PublicClient) {
  return timeline(pc, DEPLOY_BLOCK, await pc.getBlockNumber());
}

export type Launch = { coin: Address; creator: Address; name: string; symbol: string; metadataURI: string; feeRecipient: Address; time: number; block: bigint };

/** Every CoinLaunched event: creator and metadata per coin. */
export function useLaunches() {
  const pc = usePc();
  return useQuery({
    queryKey: ['launches'],
    refetchInterval: 30_000,
    queryFn: async () => {
      const event = getAbiItem({ abi: PadFactoryAbi, name: 'CoinLaunched' });
      const [logs, at] = await Promise.all([scan(pc, DEPLOY_BLOCK, (fromBlock, toBlock) => pc.getLogs({ address: addr.factory, event, fromBlock, toBlock })), timesFor(pc)]);
      const map = new Map<string, Launch>();
      for (const l of logs) {
        const a = l.args;
        map.set(a.coin!.toLowerCase(), {
          coin: a.coin!, creator: a.creator!, name: a.name!, symbol: a.symbol!, metadataURI: a.metadataURI!,
          feeRecipient: a.feeRecipient!, time: at(l.blockNumber), block: l.blockNumber,
        });
      }
      return map;
    },
  });
}

export type TradeLog = {
  coin: Address; trader: Address; isBuy: boolean; imd: bigint; tokens: bigint; fee: bigint; pool: boolean;
  time: number; block: bigint; tx: Hex; key: string;
};

async function tradeLogs(pc: PublicClient, from: bigint, coin?: Address): Promise<TradeLog[]> {
  const curveEv = getAbiItem({ abi: BondingCurveAbi, name: 'CurveTrade' });
  const poolEv = getAbiItem({ abi: PadHookAbi, name: 'Trade' });
  const args = coin ? { coin } : undefined;
  const [c, p, at] = await Promise.all([
    scan(pc, from, (fromBlock, toBlock) => pc.getLogs({ address: addr.curve, event: curveEv, args, fromBlock, toBlock })),
    scan(pc, from, (fromBlock, toBlock) => pc.getLogs({ address: addr.hook, event: poolEv, args, fromBlock, toBlock })),
    timesFor(pc),
  ]);
  const out: TradeLog[] = [
    ...c.map((l) => ({ coin: l.args.coin!, trader: l.args.trader!, isBuy: l.args.isBuy!, imd: l.args.imdAmount!, tokens: l.args.tokenAmount!, fee: l.args.fee!, pool: false, time: at(l.blockNumber), block: l.blockNumber, tx: l.transactionHash, key: `${l.transactionHash}-${l.logIndex}` })),
    ...p.map((l) => ({ coin: l.args.coin!, trader: l.args.trader!, isBuy: l.args.isBuy!, imd: l.args.imdAmount!, tokens: l.args.tokenAmount!, fee: l.args.fee!, pool: true, time: at(l.blockNumber), block: l.blockNumber, tx: l.transactionHash, key: `${l.transactionHash}-${l.logIndex}` })),
  ];
  return out.sort((a, b) => (a.block === b.block ? 0 : a.block < b.block ? -1 : 1));
}

/** All trades of one coin, oldest first (chart, trades tab). */
export function useCoinTrades(coin?: Address) {
  const pc = usePc();
  return useQuery({ queryKey: ['trades', coin], enabled: !!coin, refetchInterval: 10_000, queryFn: () => tradeLogs(pc, DEPLOY_BLOCK, coin) });
}

/** Every trade since deploy (Explore stats, ripples, profile activity). Testnet scale; the indexer replaces this. */
export function useAllTrades() {
  const pc = usePc();
  return useQuery({ queryKey: ['trades', 'all'], refetchInterval: 12_000, queryFn: () => tradeLogs(pc, DEPLOY_BLOCK) });
}

export function useGraduations() {
  const pc = usePc();
  return useQuery({
    queryKey: ['graduations'],
    refetchInterval: 30_000,
    queryFn: async () => {
      const event = getAbiItem({ abi: BondingCurveAbi, name: 'Graduated' });
      const [logs, at] = await Promise.all([scan(pc, DEPLOY_BLOCK, (fromBlock, toBlock) => pc.getLogs({ address: addr.curve, event, fromBlock, toBlock })), timesFor(pc)]);
      return new Map(logs.map((l) => [l.args.coin!.toLowerCase(), { time: at(l.blockNumber), tx: l.transactionHash }]));
    },
  });
}

/** X badge per coin (SocialRegistry.badgeOf): linked, and whether the handle is also on another coin. */
export function useBadges(coins?: readonly CoinView[]) {
  const pc = usePc();
  return useQuery({
    queryKey: ['badges', coins?.length],
    enabled: !!coins?.length,
    refetchInterval: 60_000,
    queryFn: async () => {
      const res = await pc.multicall({ contracts: coins!.map((c) => ({ address: addr.socialRegistry, abi: SocialRegistryAbi, functionName: 'badgeOf', args: [c.coin] }) as const), allowFailure: true });
      const map = new Map<string, { linked: boolean; duplicate: boolean }>();
      res.forEach((r, i) => {
        if (r.status === 'success') {
          const [h, dup] = r.result as readonly [`0x${string}`, boolean];
          map.set(coins![i].coin.toLowerCase(), { linked: BigInt(h) !== 0n, duplicate: dup });
        }
      });
      return map;
    },
  });
}

/** % change of each coin's trade price over the last 24 hours, from trade logs (indexer later). */
export function changes24h(trades: TradeLog[] | undefined): Map<string, number> {
  const out = new Map<string, number>();
  if (!trades) return out;
  const since = Date.now() / 1000 - 86400;
  const base = new Map<string, number>(), last = new Map<string, number>();
  for (const t of trades) {
    if (t.tokens === 0n) continue;
    const p = Number(t.imd) / Number(t.tokens);
    const k = t.coin.toLowerCase();
    if (t.time < since || !base.has(k)) base.set(k, p); // the last price before the window, else the first in it
    last.set(k, p);
  }
  const n = new Map<string, number>();
  for (const t of trades) n.set(t.coin.toLowerCase(), (n.get(t.coin.toLowerCase()) ?? 0) + 1);
  for (const [k, a] of base) if ((n.get(k) ?? 0) > 1) out.set(k, ((last.get(k)! - a) / a) * 100);
  return out;
}

/** IMD volume per coin over the last `seconds`. */
export function volumeSince(trades: TradeLog[] | undefined, seconds: number): Map<string, bigint> {
  const out = new Map<string, bigint>();
  const since = Date.now() / 1000 - seconds;
  for (const t of trades ?? []) if (t.time >= since) out.set(t.coin.toLowerCase(), (out.get(t.coin.toLowerCase()) ?? 0n) + t.imd);
  return out;
}

/** Holders of a coin from its Transfer events (indexer later): balances, largest first. */
export function useHolders(coin?: Address) {
  const pc = usePc();
  return useQuery({
    queryKey: ['holders', coin],
    enabled: !!coin,
    refetchInterval: 30_000,
    queryFn: async () => {
      const event = getAbiItem({ abi: PadTokenAbi, name: 'Transfer' });
      const logs = await scan(pc, DEPLOY_BLOCK, (fromBlock, toBlock) => pc.getLogs({ address: coin!, event, fromBlock, toBlock }));
      const bal = new Map<string, bigint>();
      for (const l of logs) {
        const { from, to, amount } = l.args as { from: Address; to: Address; amount: bigint };
        bal.set(from.toLowerCase(), (bal.get(from.toLowerCase()) ?? 0n) - amount);
        bal.set(to.toLowerCase(), (bal.get(to.toLowerCase()) ?? 0n) + amount);
      }
      bal.delete('0x0000000000000000000000000000000000000000');
      return [...bal.entries()].filter(([, b]) => b > 0n).sort((a, b) => (b[1] > a[1] ? 1 : -1)).map(([a, b]) => ({ address: a as Address, balance: b }));
    },
  });
}
