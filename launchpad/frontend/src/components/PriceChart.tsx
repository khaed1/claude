import { useMemo, useState } from 'react';
import type { TradeLog } from '../lib/chain';

const RANGES = [{ id: '1h', s: 3600 }, { id: '6h', s: 21600 }, { id: '1d', s: 86400 }, { id: 'All', s: Infinity }] as const;

/** Price in IMD per token after each trade, as a line with an area fill and an emphasized last point. */
export function PriceChart({ trades, symbol }: { trades: TradeLog[] | undefined; symbol: string }) {
  const [range, setRange] = useState<(typeof RANGES)[number]['id']>('All');
  const pts = useMemo(() => {
    const since = Date.now() / 1000 - RANGES.find((r) => r.id === range)!.s;
    return (trades ?? []).filter((t) => t.tokens > 0n && t.time >= since).map((t) => ({ t: t.time, p: Number(t.imd) / Number(t.tokens), buy: t.isBuy }));
  }, [trades, range]);

  const W = 640, H = 240, L = 8, R = 64, T = 12, B = 24;
  let body;
  if (pts.length < 2) {
    body = <text x={W / 2} y={H / 2} textAnchor="middle" className="chart-empty">{pts.length ? 'One trade so far. The line starts with the second.' : 'No trades in this range yet.'}</text>;
  } else {
    const t0 = pts[0].t, t1 = pts[pts.length - 1].t || t0 + 1;
    const ps = pts.map((x) => x.p);
    const lo = Math.min(...ps) * 0.97, hi = Math.max(...ps) * 1.03;
    const x = (t: number) => L + ((t - t0) / Math.max(1, t1 - t0)) * (W - L - R);
    const y = (p: number) => T + (1 - (p - lo) / (hi - lo || 1)) * (H - T - B);
    const d = pts.map((q, i) => `${i ? 'L' : 'M'}${x(q.t).toFixed(1)},${y(q.p).toFixed(1)}`).join('');
    const ticks = [lo, (lo + hi) / 2, hi];
    const fmt = (p: number) => (p * 1e9 >= 1000 ? `${(p * 1e9 / 1000).toFixed(1)}k` : (p * 1e9).toFixed(p * 1e9 < 10 ? 2 : 0));
    const last = pts[pts.length - 1];
    body = (
      <>
        {ticks.map((v, i) => <g key={i}><line x1={L} x2={W - R} y1={y(v)} y2={y(v)} className="chart-grid" /><text x={W - R + 6} y={y(v) + 4} className="chart-label">{fmt(v)}</text></g>)}
        <path d={`${d}L${x(last.t)},${H - B}L${x(pts[0].t)},${H - B}Z`} className="chart-area" />
        <path d={d} className="chart-line" />
        <circle cx={x(last.t)} cy={y(last.p)} r={4} className="chart-dot" />
      </>
    );
  }
  return (
    <figure className="chart">
      <div className="chart-head">
        <figcaption className="t-label muted">Market cap in IMD (price × 1B ${symbol})</figcaption>
        <div className="pp-seg" role="group" aria-label="Range">{RANGES.map((r) => <button key={r.id} aria-pressed={range === r.id} onClick={() => setRange(r.id)}>{r.id}</button>)}</div>
      </div>
      <svg viewBox={`0 0 ${W} ${H}`} role="img" aria-label={`${symbol} price chart`} preserveAspectRatio="none">{body}</svg>
    </figure>
  );
}
