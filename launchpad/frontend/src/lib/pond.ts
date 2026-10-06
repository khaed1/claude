import { useQuery } from '@tanstack/react-query';
import { useAccount, usePublicClient } from 'wagmi';
import { erc20Abi, type PublicClient } from 'viem';
import { PadBuyerAbi, PondPadTokenAbi, RewardDripperAbi, StakedPONDPADAbi } from '../abi';
import { addr } from '../config';

// The Pond: StakedPONDPAD (sPONDPAD, ERC-4626, 24 decimals = 18 + a 6-decimal offset), fed by RewardDripper,
// which PadBuyer fills with $PONDPAD bought from the stakers' 40% of protocol fees (D-42 to D-44).

export const SHARE_DECIMALS = 24;
const ONE_SHARE = 10n ** 24n;

export type PondState = {
  totalAssets: bigint; totalShares: bigint; perShare: bigint; paused: boolean; pausedUntil: number;
  dripBuffer: bigint; smoothing: number; perDay: bigint; lastDripAt: number; drippable: bigint; canDrip: boolean; keeperReward: bigint;
  buyerImd: bigint; burned: bigint;
  me?: { shares: bigint; assets: bigint; wallet: bigint; maxRedeem: bigint };
};

export function usePond() {
  const pc = usePublicClient() as PublicClient;
  const { address } = useAccount();
  return useQuery({
    queryKey: ['pond', address],
    refetchInterval: 6_000,
    queryFn: async (): Promise<PondState> => {
      const V = { address: addr.stakedPondpad, abi: StakedPONDPADAbi } as const;
      const D = { address: addr.rewardDripper, abi: RewardDripperAbi } as const;
      const v = <T,>(functionName: string, args: unknown[] = []) => pc.readContract({ ...V, functionName, args } as never) as Promise<T>;
      const d = <T,>(functionName: string) => pc.readContract({ ...D, functionName } as never) as Promise<T>;
      const bal = (token: `0x${string}`, who: `0x${string}`) => pc.readContract({ address: token, abi: erc20Abi, functionName: 'balanceOf', args: [who] });
      const [totalAssets, totalShares, perShare, paused, pausedUntil, dripBuffer, smoothing, lastDripAt, drippable, canDrip, keeperReward, buyerImd, supply] = await Promise.all([
        v<bigint>('totalAssets'), v<bigint>('totalSupply'), v<bigint>('convertToAssets', [ONE_SHARE]), v<boolean>('paused'), v<bigint>('pausedUntil'),
        bal(addr.pondpad, addr.rewardDripper), d<bigint>('smoothingPeriod'), d<bigint>('lastDripAt'), d<bigint>('drippable'), d<boolean>('canDrip'), d<bigint>('keeperReward'),
        bal(addr.imd, addr.padBuyer),
        pc.readContract({ address: addr.pondpad, abi: PondPadTokenAbi, functionName: 'totalSupply' }),
      ]);
      let me: PondState['me'];
      if (address) {
        const [shares, wallet, maxRedeem] = await Promise.all([v<bigint>('balanceOf', [address]), bal(addr.pondpad, address), v<bigint>('maxRedeem', [address])]);
        me = { shares, wallet, maxRedeem, assets: shares ? await v<bigint>('convertToAssets', [shares]) : 0n };
      }
      return {
        totalAssets, totalShares, perShare, paused, pausedUntil: Number(pausedUntil),
        dripBuffer, smoothing: Number(smoothing), perDay: (dripBuffer * 86_400n) / (smoothing || 1n), lastDripAt: Number(lastDripAt), drippable, canDrip, keeperReward,
        buyerImd, burned: 10n ** 27n - supply, me,
      };
    },
  });
}

/** Whether PadBuyer.buy() would go through right now (it has IMD, its interval passed, the price is in range). */
export function useBuyerReady() {
  const pc = usePublicClient() as PublicClient;
  return useQuery({
    queryKey: ['buyerReady'],
    refetchInterval: 30_000,
    queryFn: async () => {
      try {
        await pc.simulateContract({ address: addr.padBuyer, abi: PadBuyerAbi, functionName: 'buy', account: '0x000000000000000000000000000000000000dEaD' });
        return true;
      } catch {
        return false;
      }
    },
  });
}
