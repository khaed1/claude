import { useState } from 'react';
import { useAccount, usePublicClient, useWalletClient } from 'wagmi';
import { BaseError, ContractFunctionRevertedError, erc20Abi, type Abi, type Address, type PublicClient } from 'viem';
import { chain, explorerTx, PERMIT2 } from '../config';
import { Permit2Abi } from '../abi';
import { useToast } from '../components/Toasts';
import { useQueryClient } from '@tanstack/react-query';

export type Call = {
  address: Address;
  abi: Abi;
  functionName: string;
  args?: readonly unknown[];
  value?: bigint;
  /** Percent of the gas estimate to send: 120 by default, 150 for $PONDPAD market swaps and keeper-type calls (D-64). */
  gasPct?: bigint;
};

/** Friendly words for the reverts people actually hit (SITE-COPY §10). */
const ERRORS: Record<string, string> = {
  Slippage: 'The price moved while you were deciding. Try again or raise slippage a little.',
  Expired: 'That quote expired. Try again.',
  LaunchesPaused: 'New launches are paused for a moment. Trading still works.',
  InsufficientForFee: 'That payment doesn’t cover the launch fee.',
  MaxBuyExceeded: 'That’s over this coin’s early max-buy. Try a smaller amount or wait a minute.',
  PartialFill: 'The pool can’t fill all of that at once. Try a smaller amount.',
  V4TooLittleReceived: 'The price moved while you were deciding. Try again or raise slippage a little.',
  TransactionDeadlinePassed: 'That quote expired. Try again.',
  TransferFromFailed: 'Not enough balance or allowance for that.',
  InvalidName: 'Name must be 1–32 characters and ticker 1–12.',
};

export function explain(e: unknown): string {
  if (e instanceof BaseError) {
    const revert = e.walk((x) => x instanceof ContractFunctionRevertedError) as ContractFunctionRevertedError | null;
    const name = revert?.data?.errorName;
    if (name && ERRORS[name]) return ERRORS[name];
    if (/rejected|denied/i.test(e.shortMessage)) return 'You cancelled it in your wallet. Nothing was sent.';
    if (/insufficient funds/i.test(e.message)) return 'Not enough ETH for gas.';
    return name ? `That didn't go through (${name}).` : e.shortMessage;
  }
  return 'That didn’t go through. Nothing was lost except a bit of gas.';
}

/** Sends one or more calls in order (approve, then the action): simulate, estimate, add headroom, send, wait. */
export function useSend() {
  const { address, chainId } = useAccount();
  const { data: wallet } = useWalletClient();
  const pc = usePublicClient() as PublicClient;
  const toast = useToast();
  const qc = useQueryClient();
  const [pending, setPending] = useState<string | null>(null);

  async function send(calls: (Call & { label: string })[], done: { ok: string; href?: (h: string) => string }) {
    if (!wallet || !address) throw new Error('Connect a wallet to hop in.');
    if (chainId !== chain.id) await wallet.switchChain({ id: chain.id });
    let last: `0x${string}` | undefined;
    try {
      for (const c of calls) {
        setPending(c.label);
        const { request } = await pc.simulateContract({ ...c, account: address } as never);
        const est = await pc.estimateContractGas({ ...c, account: address } as never);
        last = await wallet.writeContract({ ...(request as object), gas: (est * (c.gasPct ?? 120n)) / 100n } as never);
        const r = await pc.waitForTransactionReceipt({ hash: last });
        if (r.status !== 'success') throw new Error('reverted');
      }
      toast({ kind: 'ok', text: done.ok, href: done.href ? done.href(last!) : explorerTx(last!), linkText: done.href ? 'Open' : 'View' });
      qc.invalidateQueries();
      return last;
    } catch (e) {
      toast({ kind: 'error', text: explain(e), href: last ? explorerTx(last) : undefined });
      throw e;
    } finally {
      setPending(null);
    }
  }
  return { send, pending };
}

/** An exact-amount ERC-20 approval step, only when the allowance is short (ARCHITECTURE §6: exact approvals). */
export async function approveIfNeeded(pc: PublicClient, token: Address, owner: Address, spender: Address, amount: bigint): Promise<(Call & { label: string })[]> {
  const allowance = await pc.readContract({ address: token, abi: erc20Abi, functionName: 'allowance', args: [owner, spender] });
  return allowance >= amount ? [] : [{ address: token, abi: erc20Abi as Abi, functionName: 'approve', args: [spender, amount], label: 'Approving…' }];
}

/**
 * Approval steps for a router that pulls through Permit2 (Uniswap's Universal Router): an exact ERC-20 approval to
 * Permit2 and an exact Permit2 allowance for the router, valid 30 minutes, each only when short.
 */
export async function approveViaPermit2(pc: PublicClient, token: Address, owner: Address, spender: Address, amount: bigint): Promise<(Call & { label: string })[]> {
  const steps = await approveIfNeeded(pc, token, owner, PERMIT2, amount);
  const [allowed, expiration] = await pc.readContract({ address: PERMIT2, abi: Permit2Abi, functionName: 'allowance', args: [owner, token, spender] });
  const now = Math.floor(Date.now() / 1000);
  if (allowed < amount || expiration < now + 120) {
    steps.push({ address: PERMIT2, abi: Permit2Abi as Abi, functionName: 'approve', args: [token, spender, amount, now + 1800], label: 'Approving…' });
  }
  return steps;
}
