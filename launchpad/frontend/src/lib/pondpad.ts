import { useQuery } from '@tanstack/react-query';
import { useAccount, usePublicClient } from 'wagmi';
import { getAbiItem, getAddress, type Address, type Hex, type PublicClient } from 'viem';
import { AirdropDistributorAbi, MarketControllerAbi, PadMarketHookAbi, PadSaleAbi, PondPadTokenAbi, QuoterAbi } from '../abi';
import { addr, chain, DEPLOY_BLOCK, QUOTER } from '../config';
import { scan } from './chain';

// Everything the $PONDPAD page reads: the sale (PadSale), the market (PadMarketHook + MarketController) and the
// airdrop (AirdropDistributor + the published claims file). Phases: before → sale → market (+ airdrop wake / claim).

export const SALE_STATUS = { Unfunded: 0, Trading: 1, Full: 2, Graduated: 3 } as const;
export const SALE = {
  curveSupply: 600_000_000n * 10n ** 18n,
  poolSupply: 300_000_000n * 10n ** 18n,
  feeBps: 100n,
  snipeStartBps: 8_000n,
  snipeDuration: 30 * 60,
  maxPerWallet: 15_000_000n * 10n ** 18n,
};
export const AIRDROP_NEEDED = 100;
export const AIRDROP_VESTING = 30 * 86400;
export const AIRDROP_WINDOW = 180 * 86400;
export const MARKET_FEE_DECAY = 7 * 86400;

export type SaleState = {
  status: number; startTime: number; target: bigint; raised: bigint; sold: bigint;
  x: bigint; y: bigint; k: bigint; priceE18: bigint; snipeBps: number;
  bought?: bigint; remaining?: bigint; preview?: boolean;
};

function usePc(): PublicClient {
  const c = usePublicClient();
  if (!c) throw new Error('no public client');
  return c as PublicClient;
}
const S = { address: addr.sale, abi: PadSaleAbi } as const;
const H = { address: addr.marketHook, abi: PadMarketHookAbi } as const;

export function useSale() {
  const pc = usePc();
  const { address } = useAccount();
  return useQuery({
    queryKey: ['sale', address],
    refetchInterval: 8_000,
    queryFn: async (): Promise<SaleState> => {
      const r = <T,>(functionName: string, args: unknown[] = []) => pc.readContract({ ...S, functionName, args } as never) as Promise<T>;
      const [status, startTime, target, raised, sold, x, y, k, priceE18, snipe] = await Promise.all([
        r<number>('status'), r<bigint>('startTime'), r<bigint>('target'), r<bigint>('raised'), r<bigint>('sold'),
        r<bigint>('x'), r<bigint>('y'), r<bigint>('k'), r<bigint>('price'), r<bigint>('snipeTaxBps'),
      ]);
      const [bought, remaining] = address ? await Promise.all([r<bigint>('bought', [address]), r<bigint>('remainingAllowance', [address])]) : [undefined, undefined];
      return { status: Number(status), startTime: Number(startTime), target, raised, sold, x, y, k, priceE18, snipeBps: Number(snipe), bought, remaining };
    },
  });
}

/** PadSale's own curve math (quoteBuy / quoteSell), for the preview and to check the wallet cap. */
export function saleSnipeBps(s: SaleState, now = Date.now() / 1000): number {
  if (now < s.startTime) return Number(SALE.snipeStartBps);
  const el = now - s.startTime;
  return el >= SALE.snipeDuration ? 0 : Math.floor((Number(SALE.snipeStartBps) * (SALE.snipeDuration - el)) / SALE.snipeDuration);
}
const divUp = (a: bigint, b: bigint) => (a + b - 1n) / b;
export function saleQuoteBuy(s: SaleState, grossIn: bigint, snipeBps = s.snipeBps) {
  const fee = (grossIn * SALE.feeBps) / 10_000n;
  const snipe = (grossIn * BigInt(snipeBps)) / 10_000n;
  let out = s.y - divUp(s.k, s.x + grossIn - fee - snipe);
  const left = SALE.curveSupply - s.sold;
  if (out > left) out = left;
  return { out, fee, snipe };
}
export function saleQuoteSell(s: SaleState, tokensIn: bigint) {
  const gross = s.x - divUp(s.k, s.y + tokensIn);
  const fee = (gross * SALE.feeBps) / 10_000n;
  return { out: gross - fee, fee };
}

/** A sale at the given share of its target, built with PadSale's constructor math (preview only). */
export function previewSale(target: bigint, share: number, startTime: number): SaleState {
  const vEnd = (SALE.curveSupply * SALE.poolSupply) / (SALE.curveSupply - SALE.poolSupply);
  const x0 = (target * vEnd) / SALE.poolSupply - target;
  const y0 = SALE.curveSupply + vEnd;
  const k = x0 * y0;
  const raised = (target * BigInt(Math.round(share * 1000))) / 1000n;
  const x = x0 + raised;
  const y = divUp(k, x);
  const s: SaleState = { status: SALE_STATUS.Trading, startTime, target, raised, sold: y0 - y, x, y, k, priceE18: (x * 10n ** 18n) / y, snipeBps: 0, preview: true, bought: 0n, remaining: SALE.maxPerWallet };
  s.snipeBps = saleSnipeBps(s);
  return s;
}

export type SaleTradeLog = { trader: Address; isBuy: boolean; imd: bigint; tokens: bigint; block: bigint; tx: Hex; key: string };

/** Every SaleTrade, oldest first (buyers so far, recent trades). */
export function useSaleTrades() {
  const pc = usePc();
  return useQuery({
    queryKey: ['saleTrades'],
    refetchInterval: 20_000,
    queryFn: async (): Promise<SaleTradeLog[]> => {
      const event = getAbiItem({ abi: PadSaleAbi, name: 'SaleTrade' });
      const logs = await scan(pc, DEPLOY_BLOCK, (fromBlock, toBlock) => pc.getLogs({ address: addr.sale, event, fromBlock, toBlock }));
      return logs
        .map((l) => ({ trader: l.args.trader!, isBuy: l.args.isBuy!, imd: l.args.imdAmount!, tokens: l.args.tokenAmount!, block: l.blockNumber, tx: l.transactionHash, key: `${l.transactionHash}-${l.logIndex}` }))
        .sort((a, b) => (a.block === b.block ? 0 : a.block < b.block ? -1 : 1));
    },
  });
}

export type PoolKey = { currency0: Address; currency1: Address; fee: number; tickSpacing: number; hooks: Address };
export type MarketState = {
  open: boolean; openedAt: number; feePips: number; sqrtPriceX96: bigint; priceE18: bigint; key: PoolKey;
  inventoryCap: bigint; tokensInPool: bigint; quoteInPool: bigint; totalBurned: bigint; totalRewarded: bigint;
  burnedSupply: bigint; backstopQuote: bigint;
};

const Q192 = 2n ** 192n;
/** IMD per $PONDPAD (1e18) from the pool's sqrt price: IMD is currency0, $PONDPAD currency1. */
export const marketPrice = (sqrtPriceX96: bigint) => (sqrtPriceX96 === 0n ? 0n : (Q192 * 10n ** 18n) / (sqrtPriceX96 * sqrtPriceX96));

export function useMarket() {
  const pc = usePc();
  return useQuery({
    queryKey: ['market'],
    refetchInterval: 10_000,
    queryFn: async (): Promise<MarketState> => {
      const r = <T,>(functionName: string) => pc.readContract({ ...H, functionName } as never) as Promise<T>;
      const [open, openedAt, feePips, sqrtPriceX96, key, inventoryCap, tokensInPool, quoteInPool, totalBurned, totalRewarded, supply, retained] = await Promise.all([
        r<boolean>('marketOpen'),
        pc.readContract({ address: addr.marketController, abi: MarketControllerAbi, functionName: 'openedAt' }),
        r<number>('currentFee'), r<bigint>('currentSqrtPriceX96'), r<PoolKey>('poolKey'),
        r<bigint>('inventoryCap'), r<bigint>('tokensInPool'), r<bigint>('quoteInPool'), r<bigint>('totalBurned'), r<bigint>('totalRewarded'),
        pc.readContract({ address: addr.pondpad, abi: PondPadTokenAbi, functionName: 'totalSupply' }),
        r<bigint>('retainedQuote'),
      ]);
      return {
        open, openedAt: Number(openedAt), feePips: Number(feePips), sqrtPriceX96, priceE18: marketPrice(sqrtPriceX96), key,
        inventoryCap, tokensInPool, quoteInPool, totalBurned, totalRewarded, burnedSupply: 10n ** 27n - supply, backstopQuote: retained,
      };
    },
  });
}

/** Exact market quote through the v4 Quoter (runs the hook, so the dynamic fee and trims are included). */
export async function quoteMarket(pc: PublicClient, key: PoolKey, buy: boolean, amountIn: bigint): Promise<bigint> {
  const exactCurrency = buy ? key.currency0 : key.currency1;
  const intermediateCurrency = buy ? key.currency1 : key.currency0;
  const { result } = await pc.simulateContract({
    address: QUOTER, abi: QuoterAbi, functionName: 'quoteExactInput',
    args: [{ exactCurrency, path: [{ intermediateCurrency, fee: key.fee, tickSpacing: key.tickSpacing, hooks: key.hooks, hookData: '0x' }], exactAmount: amountIn }],
  });
  return result[0];
}

const MIN_SQRT = 4295128739n + 1n;
const MAX_SQRT = 1461446703485210103287273052203988822378723970342n - 1n;
/**
 * Price limit for a market swap through the testnet swap router (which has no minimum-out): the swap stops at
 * this price and the rest of the input stays in the wallet. Set so the last unit trades no worse than the quote's
 * average price moved by the slippage (for a constant-product range the marginal price moves about twice the average).
 */
export function marketPriceLimit(m: MarketState, buy: boolean, amountIn: bigint, quotedOut: bigint, slipBps: number): bigint {
  if (quotedOut === 0n || amountIn === 0n) return buy ? MIN_SQRT : MAX_SQRT;
  const p0 = Number(m.priceE18) / 1e18; // IMD per $PONDPAD now
  const avg = buy ? Number(amountIn) / Number(quotedOut) : Number(quotedOut) / Number(amountIn);
  const s = slipBps / 10_000;
  const limit = buy ? p0 * (avg / p0) ** 2 * (1 + s) ** 2 : p0 * (avg / p0) ** 2 * (1 - s) ** 2;
  // sqrtPriceX96 = sqrt($PONDPAD per IMD) · 2^96
  const sq = BigInt(Math.floor(Math.sqrt(1 / limit) * 2 ** 48)) * 2n ** 48n;
  if (buy) return sq <= MIN_SQRT ? MIN_SQRT : sq >= m.sqrtPriceX96 ? m.sqrtPriceX96 - 1n : sq;
  return sq >= MAX_SQRT ? MAX_SQRT : sq <= m.sqrtPriceX96 ? m.sqrtPriceX96 + 1n : sq;
}

// ------------------------------------------------------------------ Airdrop

export type Claims = { distributor: Address; root: Hex; total: string; claims: Record<string, { amount: string; proof: Hex[] }> };

/**
 * The published claims file (`public/airdrop-<chainId>.json`): on mainnet the output of airdrop/snapshot.py,
 * on the testnet the test-only distributor's list (bots/airdrop-claims.mjs, D-72). Its `distributor` is the
 * contract the page uses.
 */
export function useClaims() {
  return useQuery({
    queryKey: ['claims', chain.id],
    staleTime: Infinity,
    queryFn: async (): Promise<Claims & { byAddr: Map<string, { amount: bigint; proof: Hex[] }> }> => {
      const res = await fetch(`./airdrop-${chain.id}.json`);
      if (!res.ok) throw new Error('no claims file');
      const c = (await res.json()) as Claims;
      const byAddr = new Map(Object.entries(c.claims).map(([a, v]) => [a.toLowerCase(), { amount: BigInt(v.amount), proof: v.proof }]));
      return { ...c, distributor: getAddress(c.distributor), byAddr };
    },
  });
}

export type AirdropState = {
  distributor: Address; count: number; activatedAt: number; totalClaimed: bigint; held: bigint;
  me?: { account: Address; amount: bigint; proof: Hex[]; initiated: boolean; claimed: bigint; claimable: bigint; vested: bigint; claimWallet: Address; code: Hex; nonce: bigint };
  /** Listed accounts that named the connected wallet as their claim wallet. */
  delegators: { account: Address; amount: bigint; proof: Hex[]; claimed: bigint; claimable: bigint; vested: bigint }[];
};

export function useAirdrop() {
  const pc = usePc();
  const { address } = useAccount();
  const { data: claims } = useClaims();
  return useQuery({
    queryKey: ['airdrop', address, claims?.distributor],
    enabled: !!claims,
    refetchInterval: 15_000,
    queryFn: async (): Promise<AirdropState> => {
      const A = { address: claims!.distributor, abi: AirdropDistributorAbi } as const;
      const r = <T,>(functionName: string, args: unknown[] = []) => pc.readContract({ ...A, functionName, args } as never) as Promise<T>;
      const [count, activatedAt, totalClaimed, held] = await Promise.all([
        r<bigint>('initiatorCount'), r<bigint>('activatedAt'), r<bigint>('totalClaimed'),
        pc.readContract({ address: addr.pondpad, abi: PondPadTokenAbi, functionName: 'balanceOf', args: [claims!.distributor] }),
      ]);
      const position = async (account: Address, entry: { amount: bigint; proof: Hex[] }) => {
        const [claimed, claimable, vested] = await Promise.all([r<bigint>('claimed', [account]), r<bigint>('claimable', [account, entry.amount]), r<bigint>('vested', [entry.amount])]);
        return { account, ...entry, claimed, claimable, vested };
      };
      let me: AirdropState['me'];
      const delegators: AirdropState['delegators'] = [];
      if (address) {
        const entry = claims!.byAddr.get(address.toLowerCase());
        if (entry) {
          const [p, initiated, claimWallet, code, nonce] = await Promise.all([
            position(address, entry), r<boolean>('initiated', [address]), r<Address>('claimWalletOf', [address]), r<Hex>('initiationCode', [address]), r<bigint>('nonces', [address]),
          ]);
          me = { ...p, initiated, claimWallet, code, nonce };
        }
        // Accounts that made this wallet their claim wallet (ClaimWalletSet, claimWallet indexed), still pointing here.
        const event = getAbiItem({ abi: AirdropDistributorAbi, name: 'ClaimWalletSet' });
        const logs = await scan(pc, DEPLOY_BLOCK, (fromBlock, toBlock) => pc.getLogs({ address: claims!.distributor, event, args: { claimWallet: address }, fromBlock, toBlock }));
        const accounts = [...new Set(logs.map((l) => l.args.account!))];
        for (const account of accounts) {
          const entry2 = claims!.byAddr.get(account.toLowerCase());
          if (!entry2) continue;
          const now = await r<Address>('claimWalletOf', [account]);
          if (now.toLowerCase() === address.toLowerCase()) delegators.push(await position(account, entry2));
        }
      }
      return { distributor: claims!.distributor, count: Number(count), activatedAt: Number(activatedAt), totalClaimed, held, me, delegators };
    },
  });
}

/** EIP-712 typed data a listed wallet signs to name a claim wallet (AirdropDistributor.setClaimWalletBySig). */
export function delegateTypedData(distributor: Address, account: Address, claimWallet: Address, nonce: bigint, deadline: bigint) {
  return {
    domain: { name: 'PondPad Airdrop', version: '1', chainId: chain.id, verifyingContract: distributor },
    types: { Delegate: [{ name: 'account', type: 'address' }, { name: 'claimWallet', type: 'address' }, { name: 'nonce', type: 'uint256' }, { name: 'deadline', type: 'uint256' }] },
    primaryType: 'Delegate' as const,
    message: { account, claimWallet, nonce, deadline },
  };
}

/** A signed claim-wallet handover, carried in a link from the listed wallet to the claim wallet. */
export type Handover = { account: Address; claimWallet: Address; deadline: string; signature: Hex };
export const encodeHandover = (h: Handover) => btoa(JSON.stringify(h)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
export function decodeHandover(s: string | null): Handover | undefined {
  if (!s) return undefined;
  try {
    const h = JSON.parse(atob(s.replace(/-/g, '+').replace(/_/g, '/'))) as Handover;
    return /^0x[0-9a-fA-F]{40}$/.test(h.account) && /^0x[0-9a-fA-F]{40}$/.test(h.claimWallet) && /^0x[0-9a-fA-F]+$/.test(h.signature) && /^\d+$/.test(h.deadline) ? h : undefined;
  } catch {
    return undefined;
  }
}

/** The tweet checker service (D-55): checks the post and signs the initiation voucher. Not built yet. */
export const TWEET_CHECKER_URL: string | undefined = import.meta.env.VITE_TWEET_CHECKER_URL;
export const initiationPost = (code: Hex) => `Initiating the airdrop phase for $PondPad 🐸 ${code.slice(2)}`;
