import { Link } from 'react-router-dom';
import { keccak256, type Address } from 'viem';
import type { CoinView } from '../lib/chain';
import { STATUS } from '../lib/chain';
import { useMeta } from '../lib/meta';
import { fmtAmount, fmtBps, pct, timeAgo } from '../lib/format';
import { Icon } from './Icons';

/** The coin's own image, or a frog face drawn from its address while there is none. */
export function CoinImage({ coin, uri, size = 64, className = 'pp-coin-img' }: { coin: Address; uri?: string; size?: number; className?: string }) {
  const { data } = useMeta(uri);
  if (data?.image) return <img className={className} src={data.image} width={size} height={size} alt="" loading="lazy" referrerPolicy="no-referrer" />;
  const h = keccak256(coin);
  const hue = parseInt(h.slice(2, 6), 16) % 360;
  const bg = `hsl(${hue} 38% 30%)`, fg = `hsl(${(hue + 30) % 360} 70% 82%)`;
  return (
    <svg className={className} viewBox="0 0 64 64" width={size} height={size} aria-hidden="true" style={{ display: 'block' }}>
      <rect width="64" height="64" fill={bg} />
      <circle cx="22" cy="25" r="9" fill={fg} /><circle cx="42" cy="25" r="9" fill={fg} />
      <circle cx="22" cy="25" r="4" fill={bg} /><circle cx="42" cy="25" r="4" fill={bg} />
      <path d="M15 45q17 10 34 0" stroke={fg} strokeWidth="5" fill="none" strokeLinecap="round" />
    </svg>
  );
}

export type Stage = 'egg' | 'tadpole' | 'frog';
export function stageOf(c: CoinView, maxBuyWindow = 60): Stage {
  if (c.status === STATUS.Graduated) return 'frog';
  return Date.now() / 1000 - Number(c.launchedAt) < maxBuyWindow ? 'egg' : 'tadpole';
}

export function StageChip({ coin, graduatedAt }: { coin: CoinView; graduatedAt?: number }) {
  const s = stageOf(coin);
  if (s === 'frog') return <span className="pp-stage pp-stage-frog">Frog{graduatedAt ? ` · leapt ${timeAgo(graduatedAt)}` : ''}</span>;
  if (s === 'egg') return <span className="pp-stage pp-stage-egg">Egg</span>;
  return <span className="pp-stage pp-stage-tadpole">Tadpole · {Math.floor(pct(coin.raised, coin.target))}%</span>;
}

export function LeapMeter({ raised, target }: { raised: bigint; target: bigint }) {
  const p = pct(raised, target);
  const cls = p >= 100 ? 'pp-leap is-done' : p >= 90 ? 'pp-leap is-near' : 'pp-leap';
  return (
    <div className={cls} role="progressbar" aria-valuenow={Math.floor(p)} aria-valuemin={0} aria-valuemax={100} aria-label="Progress to the Leap">
      <div className="pp-leap-track">
        <div className="pp-leap-pads"><i style={{ left: '25%' }} /><i style={{ left: '50%' }} /><i style={{ left: '75%' }} /></div>
        <div className="pp-leap-fill" style={{ width: `${p}%` }} />
        <div className="pp-leap-head" style={{ left: `${p}%` }} />
      </div>
      <div className="pp-leap-row"><span><b>{fmtAmount(raised)}</b> / {fmtAmount(target)} IMD</span><span>{p >= 100 ? 'Leapt' : `${Math.floor(p)}% to the Leap`}</span></div>
    </div>
  );
}

/** Market cap in IMD: price × 1B supply. */
export const mcapOf = (c: CoinView) => c.priceE18 * 1_000_000_000n;

export function CoinCard({ coin, uri, change, verified, website, spotlight }: { coin: CoinView; uri?: string; change?: number; verified?: boolean; website?: boolean; spotlight?: boolean }) {
  const { data: meta } = useMeta(uri);
  const s = stageOf(coin);
  return (
    <Link className={`pp-coin${spotlight ? ' is-spotlight' : ''}`} to={`/c/${coin.coin}`}>
      <CoinImage coin={coin.coin} uri={uri} />
      <div className="pp-coin-body">
        <div className="pp-coin-top"><span className="pp-coin-name">{coin.name}</span><span className="pp-coin-ticker">${coin.symbol}</span><span className="pp-spacer" /><StageChip coin={coin} /></div>
        {meta?.description && <div className="pp-coin-desc">{meta.description}</div>}
        <div className="pp-coin-stats">
          <span>MC <b>{fmtAmount(mcapOf(coin), 18, { compact: true })} IMD</b></span>
          {change !== undefined && <span className={change >= 0 ? 'pp-up' : 'pp-down'}>{change >= 0 ? '▲' : '▼'} {Math.abs(change).toFixed(1)}%</span>}
          <span>Fee {fmtBps(coin.totalFeeBps)}</span>
          <span>{timeAgo(coin.launchedAt)}</span>
        </div>
        {s !== 'frog' && <LeapMeter raised={coin.raised} target={coin.target} />}
        {(verified || website) && (
          <div className="pp-coin-badges">
            {verified && <span className="pp-badge pp-badge-x"><Icon name="x" size={12} />X verified</span>}
            {website && <span className="pp-badge pp-badge-chorus"><Icon name="web" size={12} />Site by the Chorus</span>}
          </div>
        )}
      </div>
    </Link>
  );
}
