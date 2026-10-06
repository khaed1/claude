import { useQuery } from '@tanstack/react-query';
import { usePublicClient } from 'wagmi';
import { decodeFunctionData, erc20Abi, getAbiItem, parseAbi, type Abi, type Address, type Hex, type PublicClient } from 'viem';
import {
  AirdropDistributorAbi, AttestationVerifierAbi, CTOModuleAbi, FeeSplitterAbi, GrowthFundAbi, IntegratorVaultAbi, MarketControllerAbi,
  PadBuyerAbi, PadConfigAbi, PadMarketHookAbi, PondPadTokenAbi, RewardDripperAbi, SocialRegistryAbi, StakedPONDPADAbi, SwarmBudgetAbi,
  TimelockControllerAbi, VersionRegistryAbi, WorkerFundAbi,
} from '../abi';
import { addr, DEPLOY_BLOCK } from '../config';
import { scan, timesFor } from './chain';

// Transparency (Pages.md): where every IMD goes, read straight from the chain. Fee flows from the FeeSplitter's
// events, what each bucket did with it (PadBuyer, WorkerFund, GrowthFund, treasury), $PONDPAD burned, current
// settings, who owns what, and every change waiting in (or passed through) the two timelocks.

type Pc = PublicClient;
const bal = (pc: Pc, token: Address, who: Address) => pc.readContract({ address: token, abi: erc20Abi, functionName: 'balanceOf', args: [who] });
const logs = <T,>(pc: Pc, fetch: (fromBlock: bigint, toBlock: bigint) => Promise<T[]>) => scan(pc, DEPLOY_BLOCK, fetch);

export type Split = { stakers: bigint; workers: bigint; growth: bigint; treasury: bigint };
export type FlowEvent = { what: string; detail: string; imd?: bigint; tokens?: bigint; time: number; tx: Hex; key: string };

export type Flows = {
  shares: { stakers: number; workers: number; growth: number; treasury: number };
  recipients: { stakers: Address; workers: Address; growth: Address; treasury: Address };
  imd: Split; pondpad: Split; pendingImd: bigint; pendingPondpad: bigint; integrators: bigint;
  buyer: { spent: bigint; bought: bigint; waiting: bigint; buys: FlowEvent[] };
  workers: { address: Address; releasedImd: bigint; releasedPondpad: bigint; heldImd: bigint; heldPondpad: bigint };
  growth: { imd: bigint; pondpad: bigint; relayCap: bigint; relayAvailable: bigint; grantCapImd: bigint; grantAvailImd: bigint; grantCapPondpad: bigint; grantAvailPondpad: bigint; payments: FlowEvent[] };
  treasury: { imd: bigint; pondpad: bigint };
  burned: bigint; dripped: bigint; stakedValue: bigint;
};

export function useFlows() {
  const pc = usePublicClient() as Pc;
  return useQuery({
    queryKey: ['flows'],
    refetchInterval: 30_000,
    queryFn: async (): Promise<Flows> => {
      const S = { address: addr.feeSplitter, abi: FeeSplitterAbi } as const;
      const [shares, recipients, distributed, tokenDistributed, credited, bought, jobs, grants, dripped, at] = await Promise.all([
        pc.readContract({ ...S, functionName: 'shares' }),
        pc.readContract({ ...S, functionName: 'recipients' }),
        logs(pc, (fromBlock, toBlock) => pc.getLogs({ address: addr.feeSplitter, event: getAbiItem({ abi: FeeSplitterAbi, name: 'Distributed' }), fromBlock, toBlock })),
        logs(pc, (fromBlock, toBlock) => pc.getLogs({ address: addr.feeSplitter, event: getAbiItem({ abi: FeeSplitterAbi, name: 'TokenDistributed' }), args: { token: addr.pondpad }, fromBlock, toBlock })),
        logs(pc, (fromBlock, toBlock) => pc.getLogs({ address: addr.integratorVault, event: getAbiItem({ abi: IntegratorVaultAbi, name: 'Credited' }), fromBlock, toBlock })),
        logs(pc, (fromBlock, toBlock) => pc.getLogs({ address: addr.padBuyer, event: getAbiItem({ abi: PadBuyerAbi, name: 'Bought' }), fromBlock, toBlock })),
        logs(pc, (fromBlock, toBlock) => pc.getLogs({ address: addr.growthFund, event: getAbiItem({ abi: GrowthFundAbi, name: 'JobPaid' }), fromBlock, toBlock })),
        logs(pc, (fromBlock, toBlock) => pc.getLogs({ address: addr.growthFund, event: getAbiItem({ abi: GrowthFundAbi, name: 'Granted' }), fromBlock, toBlock })),
        logs(pc, (fromBlock, toBlock) => pc.getLogs({ address: addr.rewardDripper, event: getAbiItem({ abi: RewardDripperAbi, name: 'Dripped' }), fromBlock, toBlock })),
        timesFor(pc),
      ]);
      const sum = (rows: readonly { args: { stakers?: bigint; workers?: bigint; growth?: bigint; treasury?: bigint } }[]): Split => rows.reduce(
        (a, l) => ({ stakers: a.stakers + (l.args.stakers ?? 0n), workers: a.workers + (l.args.workers ?? 0n), growth: a.growth + (l.args.growth ?? 0n), treasury: a.treasury + (l.args.treasury ?? 0n) }),
        { stakers: 0n, workers: 0n, growth: 0n, treasury: 0n });
      const G = { address: addr.growthFund, abi: GrowthFundAbi } as const;
      const W = { address: addr.workerFund, abi: WorkerFundAbi } as const;
      const [pendingImd, pendingPondpad, waiting, workerAddr, relImd, relPp, heldImd, heldPp, gImd, gPp, relayCap, relayAvailable, grantCapImd, grantAvailImd, grantCapPondpad, grantAvailPondpad, tImd, tPp, supply, staked] = await Promise.all([
        bal(pc, addr.imd, addr.feeSplitter), bal(pc, addr.pondpad, addr.feeSplitter), bal(pc, addr.imd, addr.padBuyer),
        pc.readContract({ ...W, functionName: 'workerRewards' }), pc.readContract({ ...W, functionName: 'totalReleased', args: [addr.imd] }), pc.readContract({ ...W, functionName: 'totalReleased', args: [addr.pondpad] }),
        bal(pc, addr.imd, addr.workerFund), bal(pc, addr.pondpad, addr.workerFund),
        bal(pc, addr.imd, addr.growthFund), bal(pc, addr.pondpad, addr.growthFund),
        pc.readContract({ ...G, functionName: 'relayCap' }), pc.readContract({ ...G, functionName: 'relayAvailable' }),
        pc.readContract({ ...G, functionName: 'grantCap', args: [addr.imd] }), pc.readContract({ ...G, functionName: 'grantAvailable', args: [addr.imd] }),
        pc.readContract({ ...G, functionName: 'grantCap', args: [addr.pondpad] }), pc.readContract({ ...G, functionName: 'grantAvailable', args: [addr.pondpad] }),
        bal(pc, addr.imd, recipients.treasury), bal(pc, addr.pondpad, recipients.treasury),
        pc.readContract({ address: addr.pondpad, abi: PondPadTokenAbi, functionName: 'totalSupply' }),
        pc.readContract({ address: addr.stakedPondpad, abi: StakedPONDPADAbi, functionName: 'totalAssets' }),
      ]);
      const ev = (l: { transactionHash: Hex; logIndex: number; blockNumber: bigint }) => ({ time: at(l.blockNumber), tx: l.transactionHash, key: `${l.transactionHash}-${l.logIndex}` });
      const payments: FlowEvent[] = [
        ...jobs.map((l) => ({ what: 'Swarm job', detail: l.args.reason || `job ${l.args.jobRef?.slice(0, 10)}`, imd: l.args.amount, ...ev(l) })),
        ...grants.map((l) => ({ what: 'Grant', detail: l.args.reason || 'no reason given', ...(l.args.token?.toLowerCase() === addr.imd.toLowerCase() ? { imd: l.args.amount } : { tokens: l.args.amount }), ...ev(l) })),
      ].sort((a, b) => b.time - a.time);
      return {
        shares: { stakers: shares.stakers, workers: shares.workers, growth: shares.growth, treasury: shares.treasury },
        recipients,
        imd: sum(distributed), pondpad: sum(tokenDistributed), pendingImd, pendingPondpad,
        integrators: credited.reduce((a, l) => a + (l.args.amount ?? 0n), 0n),
        buyer: {
          spent: bought.reduce((a, l) => a + (l.args.imdSpent ?? 0n), 0n), bought: bought.reduce((a, l) => a + (l.args.tokensOut ?? 0n), 0n), waiting,
          buys: bought.map((l) => ({ what: 'Bought $PONDPAD', detail: 'for the Pond', imd: l.args.imdSpent, tokens: l.args.tokensOut, ...ev(l) })).reverse(),
        },
        workers: { address: workerAddr, releasedImd: relImd, releasedPondpad: relPp, heldImd, heldPondpad: heldPp },
        growth: { imd: gImd, pondpad: gPp, relayCap, relayAvailable, grantCapImd, grantAvailImd, grantCapPondpad, grantAvailPondpad, payments },
        treasury: { imd: tImd, pondpad: tPp },
        burned: 10n ** 27n - supply, dripped: dripped.reduce((a, l) => a + (l.args.toVault ?? 0n), 0n), stakedValue: staked,
      };
    },
  });
}

// ------------------------------------------------------------------ Who owns what, and the timelock queue

/** Contracts with an owner, and what that owner can do (D-57, D-59; HANDOFF §5). */
export const OWNED: { key: keyof typeof addr; name: string; can: string }[] = [
  { key: 'config', name: 'PadConfig', can: 'launch settings within fixed bounds, payment routes, integrators (fee splitter and growth fund are fixed)' },
  { key: 'feeSplitter', name: 'FeeSplitter', can: 'the 40/25/20/15 split within fixed ranges, recipients' },
  { key: 'growthFund', name: 'GrowthFund', can: 'relay, granter and weekly caps' },
  { key: 'workerFund', name: 'WorkerFund', can: 'set the IMD worker rewards address' },
  { key: 'swarmBudget', name: 'SwarmBudget', can: 'the Swarm Relay address' },
  { key: 'socialRegistry', name: 'SocialRegistry', can: 'the X link service key' },
  { key: 'marketController', name: 'MarketController', can: 'market settings within bounds; approve a move to a new hook that the Safe then runs (first 12 months)' },
  { key: 'stakedPondpad', name: 'StakedPONDPAD', can: 'pause up to 3 days; never move stake; ends after 12 months' },
  { key: 'rewardDripper', name: 'RewardDripper', can: 'drip pace within bounds; never move rewards; ends after 12 months' },
  { key: 'padBuyer', name: 'PadBuyer', can: 'chunk size, interval, price guards within bounds' },
  { key: 'attestationVerifier', name: 'AttestationVerifier', can: 'the oracle signer and panel bar within bounds' },
  { key: 'ctoModule', name: 'CTOModule', can: 'retire the council fallback (one way)' },
  { key: 'versionRegistry', name: 'VersionRegistry', can: 'register, activate or roll back versions' },
  { key: 'airdrop', name: 'AirdropDistributor', can: 'replace the tweet checker key only' },
];
const OWNER_ABI = parseAbi(['function owner() view returns (address)']);

export function useOwners() {
  const pc = usePublicClient() as Pc;
  return useQuery({
    queryKey: ['owners'],
    staleTime: 300_000,
    queryFn: async () => {
      const owners = await Promise.all(OWNED.map((o) => pc.readContract({ address: addr[o.key] as Address, abi: OWNER_ABI, functionName: 'owner' }).catch(() => undefined)));
      const [fastDelay, slowDelay] = await Promise.all([addr.fastTimelock, addr.slowTimelock].map((t) => pc.readContract({ address: t, abi: TimelockControllerAbi, functionName: 'getMinDelay' })));
      return { owners: Object.fromEntries(OWNED.map((o, i) => [o.key, owners[i]])) as Record<string, Address | undefined>, fastDelay: Number(fastDelay), slowDelay: Number(slowDelay) };
    },
  });
}

// Every ABI an owned contract has, to name the function a timelock call runs.
const DECODE: { name: string; abi: Abi }[] = [
  { name: 'PadConfig', abi: PadConfigAbi as Abi }, { name: 'FeeSplitter', abi: FeeSplitterAbi as Abi }, { name: 'GrowthFund', abi: GrowthFundAbi as Abi },
  { name: 'WorkerFund', abi: WorkerFundAbi as Abi }, { name: 'SwarmBudget', abi: SwarmBudgetAbi as Abi }, { name: 'SocialRegistry', abi: SocialRegistryAbi as Abi },
  { name: 'MarketController', abi: MarketControllerAbi as Abi }, { name: 'StakedPONDPAD', abi: StakedPONDPADAbi as Abi }, { name: 'RewardDripper', abi: RewardDripperAbi as Abi },
  { name: 'PadBuyer', abi: PadBuyerAbi as Abi }, { name: 'AttestationVerifier', abi: AttestationVerifierAbi as Abi }, { name: 'CTOModule', abi: CTOModuleAbi as Abi },
  { name: 'VersionRegistry', abi: VersionRegistryAbi as Abi }, { name: 'AirdropDistributor', abi: AirdropDistributorAbi as Abi }, { name: 'PadMarketHook', abi: PadMarketHookAbi as Abi },
  { name: 'Timelock', abi: TimelockControllerAbi as Abi },
];
const NAME_OF = new Map<string, string>([...OWNED.map((o) => [String(addr[o.key]).toLowerCase(), o.name] as [string, string]), [addr.fastTimelock.toLowerCase(), '48 h timelock'], [addr.slowTimelock.toLowerCase(), '7-day timelock']]);
export const nameOf = (a: string) => NAME_OF.get(a.toLowerCase());

function describe(target: Address, data: Hex): { call: string; args: string } {
  for (const d of DECODE) {
    try {
      const f = decodeFunctionData({ abi: d.abi, data });
      const args = (f.args ?? []).map((a) => (typeof a === 'bigint' ? a.toString() : typeof a === 'object' ? JSON.stringify(a, (_, v) => (typeof v === 'bigint' ? v.toString() : v)) : String(a))).join(', ');
      return { call: `${nameOf(target) ?? d.name}.${f.functionName}`, args };
    } catch { /* try the next ABI */ }
  }
  return { call: `${nameOf(target) ?? target}: a call this page can't read (${data.slice(0, 10)})`, args: '' };
}

export type QueuedCall = {
  timelock: '48 h' | '7 days' | string; id: Hex; target: Address; call: string; args: string;
  scheduledAt: number; readyAt: number; status: 'waiting' | 'ready' | 'done' | 'cancelled'; tx: Hex; key: string;
};

/** Every call ever scheduled in either timelock, newest first, with its status now. */
export function useTimelockQueue() {
  const pc = usePublicClient() as Pc;
  return useQuery({
    queryKey: ['timelocks'],
    refetchInterval: 30_000,
    queryFn: async (): Promise<QueuedCall[]> => {
      const at = await timesFor(pc);
      const out: QueuedCall[] = [];
      for (const [t, label] of [[addr.fastTimelock, '48 h'], [addr.slowTimelock, '7 days']] as const) {
        const scheduled = await logs(pc, (fromBlock, toBlock) => pc.getLogs({ address: t, event: getAbiItem({ abi: TimelockControllerAbi, name: 'CallScheduled' }), fromBlock, toBlock }));
        const ids = [...new Set(scheduled.map((l) => l.args.id!))];
        const stamps = new Map(await Promise.all(ids.map(async (id) => [id, Number(await pc.readContract({ address: t, abi: TimelockControllerAbi, functionName: 'getTimestamp', args: [id] }))] as const)));
        const now = Date.now() / 1000;
        for (const l of scheduled) {
          const ts = stamps.get(l.args.id!) ?? 0;
          const scheduledAt = at(l.blockNumber);
          const status = ts === 1 ? 'done' : ts === 0 ? 'cancelled' : ts <= now ? 'ready' : 'waiting';
          out.push({ timelock: label, id: l.args.id!, target: l.args.target!, ...describe(l.args.target!, l.args.data!), scheduledAt, readyAt: ts > 1 ? ts : scheduledAt + Number(l.args.delay ?? 0n), status, tx: l.transactionHash, key: `${l.transactionHash}-${l.logIndex}` });
        }
      }
      return out.sort((a, b) => b.scheduledAt - a.scheduledAt);
    },
  });
}

export function useSettings() {
  const pc = usePublicClient() as Pc;
  return useQuery({
    queryKey: ['settings'],
    staleTime: 60_000,
    queryFn: async () => {
      const [launch, paused, integratorBps, buyer, market] = await Promise.all([
        pc.readContract({ address: addr.config, abi: PadConfigAbi, functionName: 'launchSettings' }),
        pc.readContract({ address: addr.config, abi: PadConfigAbi, functionName: 'launchesPaused' }),
        pc.readContract({ address: addr.config, abi: PadConfigAbi, functionName: 'integratorShareBps' }),
        Promise.all((['maxChunk', 'interval', 'keeperTipBps'] as const).map((f) => pc.readContract({ address: addr.padBuyer, abi: PadBuyerAbi, functionName: f }))),
        Promise.all((['capFloor', 'capDecayTokensPerDay', 'rewardShareBps', 'currentFee'] as const).map((f) => pc.readContract({ address: addr.marketHook, abi: PadMarketHookAbi, functionName: f }))),
      ]);
      return { launch, paused, integratorBps: Number(integratorBps), buyer: { maxChunk: buyer[0] as bigint, interval: Number(buyer[1]), tipBps: Number(buyer[2]) }, market: { capFloor: market[0] as bigint, capDecay: market[1] as bigint, rewardBps: Number(market[2]), feePips: Number(market[3]) } };
    },
  });
}
