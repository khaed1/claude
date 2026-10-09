import { useQuery } from '@tanstack/react-query';
import { usePublicClient } from 'wagmi';
import type { Address, PublicClient } from 'viem';
import { PadConfigAbi, PadLensAbi, QuoterAbi } from '../abi';
import { addr, QUOTER, type PayToken } from '../config';

type Hop = { key: { currency0: Address; currency1: Address; fee: number; tickSpacing: number; hooks: Address }; zeroForOne: boolean };

const routeCache = new Map<string, Promise<readonly Hop[]>>();
function routeToImd(pc: PublicClient, token: Address) {
  if (!routeCache.has(token)) routeCache.set(token, pc.readContract({ address: addr.config, abi: PadConfigAbi, functionName: 'routeToImd', args: [token] }) as Promise<readonly Hop[]>);
  return routeCache.get(token)!;
}

/** One hop of a v4 path (v4-periphery PathKey), as the Quoter and the Universal Router take it. */
export type PathKey = { intermediateCurrency: Address; fee: number; tickSpacing: number; hooks: Address; hookData: `0x${string}` };

/** Exact-in quote along a v4 path. */
export async function quoter(pc: PublicClient, exactCurrency: Address, path: PathKey[], amount: bigint) {
  const { result } = await pc.simulateContract({ address: QUOTER, abi: QuoterAbi, functionName: 'quoteExactInput', args: [{ exactCurrency, path, exactAmount: amount }] });
  return result[0];
}

/** v4 path from a payment token to IMD along PadConfig's route (empty for IMD). */
export async function pathToImd(pc: PublicClient, token: Address): Promise<PathKey[]> {
  if (token === addr.imd) return [];
  const hops = await routeToImd(pc, token);
  return hops.map((h) => ({ intermediateCurrency: h.zeroForOne ? h.key.currency1 : h.key.currency0, fee: h.key.fee, tickSpacing: h.key.tickSpacing, hooks: h.key.hooks, hookData: '0x' as const }));
}

/** v4 path from IMD to a payment token: the route reversed (empty for IMD). */
export async function pathFromImd(pc: PublicClient, token: Address): Promise<PathKey[]> {
  if (token === addr.imd) return [];
  const hops = [...(await routeToImd(pc, token))].reverse();
  return hops.map((h) => ({ intermediateCurrency: h.zeroForOne ? h.key.currency0 : h.key.currency1, fee: h.key.fee, tickSpacing: h.key.tickSpacing, hooks: h.key.hooks, hookData: '0x' as const }));
}

/** IMD received for `amount` of a payment token, along PadConfig's route (what PadRouter swaps through). */
export async function toImd(pc: PublicClient, token: PayToken, amount: bigint): Promise<bigint> {
  if (token.address === addr.imd || amount === 0n) return amount;
  return quoter(pc, token.address, await pathToImd(pc, token.address), amount);
}

/** Payment token received for `imd` IMD, along the route reversed. */
export async function fromImd(pc: PublicClient, token: PayToken, imd: bigint): Promise<bigint> {
  if (token.address === addr.imd || imd === 0n) return imd;
  return quoter(pc, addr.imd, await pathFromImd(pc, token.address), imd);
}

export type Quote = {
  side: 'buy' | 'sell';
  amountIn: bigint;
  imd: bigint; // IMD entering the coin's curve/pool (buy) or leaving it net of fees (sell)
  out: bigint; // tokens (buy) or payment token (sell)
  fee: bigint; // in IMD
  snipeTax: bigint; // in IMD (buys on the curve only)
  graduated: boolean;
  fullFill: boolean;
  impactBps: number; // price impact against the current price, fees excluded
};

export function useQuote(coin: Address | undefined, side: 'buy' | 'sell', token: PayToken, amountIn: bigint | undefined, priceE18: bigint | undefined) {
  const pc = usePublicClient() as PublicClient;
  return useQuery({
    queryKey: ['quote', coin, side, token.symbol, amountIn?.toString()],
    enabled: !!coin && !!amountIn && amountIn > 0n,
    refetchInterval: 10_000,
    retry: false,
    queryFn: async (): Promise<Quote> => {
      if (side === 'buy') {
        const imd = await toImd(pc, token, amountIn!);
        const [tokens, fee, snipeTax, graduated, fullFill] = await pc.readContract({ address: addr.lens, abi: PadLensAbi, functionName: 'quoteBuy', args: [coin!, imd] });
        const net = imd - fee - snipeTax;
        const ideal = priceE18 && priceE18 > 0n ? (net * 10n ** 18n) / priceE18 : 0n;
        const impactBps = ideal > 0n && tokens < ideal ? Number(((ideal - tokens) * 10000n) / ideal) : 0;
        return { side, amountIn: amountIn!, imd, out: tokens, fee, snipeTax, graduated, fullFill, impactBps };
      }
      const [imdOut, fee, graduated, fullFill] = await pc.readContract({ address: addr.lens, abi: PadLensAbi, functionName: 'quoteSell', args: [coin!, amountIn!] });
      const out = await fromImd(pc, token, imdOut);
      const gross = imdOut + fee;
      const ideal = priceE18 ? (amountIn! * priceE18) / 10n ** 18n : 0n;
      const impactBps = ideal > 0n && gross < ideal ? Number(((ideal - gross) * 10000n) / ideal) : 0;
      return { side, amountIn: amountIn!, imd: imdOut, out, fee, snipeTax: 0n, graduated, fullFill, impactBps };
    },
  });
}
