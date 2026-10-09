import { formatUnits } from 'viem';

const nf = (max: number) => new Intl.NumberFormat('en-US', { maximumFractionDigits: max });

/** A token amount for display: thousands separators, at most 4 significant decimals, compact above 10M. */
export function fmtAmount(x: bigint | undefined, decimals = 18, opts: { compact?: boolean } = {}): string {
  if (x === undefined) return '…';
  const n = Number(formatUnits(x, decimals));
  if (n === 0) return '0';
  const a = Math.abs(n);
  if (opts.compact && a >= 1e6) return new Intl.NumberFormat('en-US', { notation: 'compact', maximumFractionDigits: 2 }).format(n);
  if (a >= 1000) return nf(0).format(n);
  if (a >= 1) return nf(2).format(n);
  if (a >= 0.0001) return nf(4).format(n);
  return '<0.0001';
}

export const fmtImd = (x: bigint | undefined) => `${fmtAmount(x)} IMD`;
/** Basis points as a percent with one decimal, two only when needed: 150 → 1.5%, 100 → 1.0%, 25 → 0.25%. */
export const fmtBps = (bps: bigint | number) => `${(Number(bps) / 100).toFixed(2).replace(/(\.\d)0$/, '$1')}%`;
export const shortAddr = (a?: string) => (a ? `${a.slice(0, 6)}…${a.slice(-4)}` : '');
export const pct = (num: bigint, den: bigint) => (den === 0n ? 0 : Math.min(100, Number((num * 10000n) / den) / 100));

export function timeAgo(unixSeconds: number | bigint, now = Date.now() / 1000): string {
  const s = Math.max(0, Math.round(now - Number(unixSeconds)));
  if (s < 60) return `${s}s ago`;
  if (s < 3600) return `${Math.floor(s / 60)} min ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return `${Math.floor(s / 86400)}d ago`;
}

/** Parses a user-typed decimal amount; undefined when empty or invalid. */
export function parseAmount(s: string, decimals: number): bigint | undefined {
  const t = s.trim();
  if (!/^\d*\.?\d*$/.test(t) || t === '' || t === '.') return undefined;
  const [i, f = ''] = t.split('.');
  if (f.length > decimals) return undefined;
  return BigInt(i || '0') * 10n ** BigInt(decimals) + BigInt((f + '0'.repeat(decimals)).slice(0, decimals) || '0');
}
