import { useMemo, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { useAccount, useReadContract } from 'wagmi';
import { isAddress, type Address, type Abi } from 'viem';
import { PadTokenAbi, CreatorVaultAbi } from '../abi';
import { addr, explorerAddr, explorerTx } from '../config';
import { STATUS, useBadges, useCoin, useCoinTrades, useGraduations, useHolders, useLaunches } from '../lib/chain';
import { useMeta } from '../lib/meta';
import { fmtAmount, fmtBps, shortAddr, timeAgo } from '../lib/format';
import { useSend } from '../lib/tx';
import { CoinImage, LeapMeter, mcapOf, StageChip } from '../components/CoinBits';
import { TradeBox, feeLine } from '../components/TradeBox';
import { PriceChart } from '../components/PriceChart';
import { Icon } from '../components/Icons';

type Tab = 'trades' | 'holders' | 'creator' | 'about';

function Copy({ text }: { text: string }) {
  const [done, setDone] = useState(false);
  return (
    <button className="pp-btn pp-btn-ghost pp-btn-sm" onClick={() => navigator.clipboard?.writeText(text).then(() => { setDone(true); setTimeout(() => setDone(false), 1500); }).catch(() => {})}>
      <Icon name="copy" size={14} />{done ? 'Copied' : 'Copy address'}
    </button>
  );
}

export function Coin() {
  const { address: param } = useParams();
  const coinAddr = param && isAddress(param) ? (param as Address) : undefined;
  const { data: c, isLoading } = useCoin(coinAddr);
  const { data: launches } = useLaunches();
  const { data: trades } = useCoinTrades(coinAddr);
  const { data: grads } = useGraduations();
  const { data: holders } = useHolders(coinAddr);
  const { data: badges } = useBadges(c ? [c] : undefined);
  const launch = coinAddr ? launches?.get(coinAddr.toLowerCase()) : undefined;
  const { data: meta } = useMeta(launch?.metadataURI);
  const [tab, setTab] = useState<Tab>('trades');
  const [sheet, setSheet] = useState<null | 'buy' | 'sell'>(null);
  const { address } = useAccount();
  const { send, pending } = useSend();

  const bal = useReadContract({ address: coinAddr, abi: PadTokenAbi, functionName: 'balanceOf', args: [address!], query: { enabled: !!address && !!coinAddr, refetchInterval: 10_000 } });
  const div = useReadContract({ address: coinAddr, abi: PadTokenAbi, functionName: 'withdrawableDividendOf', args: [address!], query: { enabled: !!address && !!coinAddr, refetchInterval: 10_000 } });

  const change = useMemo(() => {
    const ts = (trades ?? []).filter((t) => t.tokens > 0n);
    if (ts.length < 2) return undefined;
    const since = Date.now() / 1000 - 86400;
    const base = [...ts].reverse().find((t) => t.time < since) ?? ts[0];
    const p0 = Number(base.imd) / Number(base.tokens), p1 = Number(ts[ts.length - 1].imd) / Number(ts[ts.length - 1].tokens);
    return ((p1 - p0) / p0) * 100;
  }, [trades]);

  if (!coinAddr) return <div className="wrap empty"><p>That isn't a coin address.</p><Link className="pp-btn" to="/">Back to Explore</Link></div>;
  if (isLoading || !c) return <div className="wrap"><div className="skeleton" style={{ height: 320, borderRadius: 22 }} /></div>;
  if (c.status === STATUS.None) return <div className="wrap empty"><img src="./pip.svg" alt="" width={120} /><p>No frogs at this address. Maybe it's still an egg?</p><Link className="pp-btn" to="/">Back to Explore</Link></div>;

  const graduated = c.status === STATUS.Graduated;
  const grad = grads?.get(c.coin.toLowerCase());
  const badge = badges?.get(c.coin.toLowerCase());
  const label = (a: string) => {
    const l = a.toLowerCase();
    if (l === addr.curve.toLowerCase()) return 'Bonding curve';
    if (l === addr.poolManager.toLowerCase()) return 'Pool (locked)';
    if (l === addr.hook.toLowerCase()) return 'PondPad hook';
    if (l === '0x000000000000000000000000000000000000dead') return 'Burned';
    if (launch && l === launch.creator.toLowerCase()) return 'Creator';
    if (address && l === address.toLowerCase()) return 'You';
    return undefined;
  };

  return (
    <div className="wrap stack">
      <header className="coin-head">
        <CoinImage coin={c.coin} uri={launch?.metadataURI} size={72} className="coin-head-img" />
        <div className="stack-xs" style={{ minWidth: 0 }}>
          <div className="row wrap-row">
            <h1 className="t-title coin-title">{c.name}</h1>
            <span className="pp-coin-ticker">${c.symbol}</span>
            <StageChip coin={c} graduatedAt={grad?.time} />
            {badge?.linked && <span className="pp-badge pp-badge-x"><Icon name="x" size={12} />X verified</span>}
            {badge?.duplicate && <span className="pp-badge pp-badge-warn">Handle also on another coin</span>}
          </div>
          <div className="pp-coin-stats">
            <span>MC <b>{fmtAmount(mcapOf(c), 18, { compact: true })} IMD</b></span>
            {change !== undefined && <span className={change >= 0 ? 'pp-up' : 'pp-down'}>{change >= 0 ? '▲' : '▼'} {Math.abs(change).toFixed(1)}% 24h</span>}
            <span>Fee <b>{fmtBps(c.totalFeeBps)}</b></span>
            {launch && <span>created by <Link to={`/u/${launch.creator}`}>{shortAddr(launch.creator)}</Link> · {timeAgo(launch.time)}</span>}
          </div>
        </div>
        <div className="row head-actions"><Copy text={c.coin} /><a className="pp-btn pp-btn-ghost pp-btn-sm" href={explorerAddr(c.coin)} target="_blank" rel="noreferrer"><Icon name="ext" size={14} />Explorer</a></div>
      </header>

      <div className="coin-grid">
        <div className="stack" style={{ minWidth: 0 }}>
          {!graduated && <LeapMeter raised={c.raised} target={c.target} />}
          {graduated && <div className="pp-notice pp-notice-tax"><Icon name="leap" /><div><b>Leapt{grad ? ` ${timeAgo(grad.time)}` : ''}.</b> Its liquidity is locked in a PondPad pool forever. Graduation only means the curve filled; it isn't a quality signal.</div></div>}
          <PriceChart trades={trades} symbol={c.symbol} />
          <div className="pp-tabs" role="tablist">
            {(['trades', 'holders', 'creator', 'about'] as Tab[]).map((t) => <button key={t} role="tab" aria-selected={tab === t} onClick={() => setTab(t)}>{t[0].toUpperCase() + t.slice(1)}</button>)}
          </div>
          {tab === 'trades' && (
            <div className="table-wrap"><table className="table">
              <thead><tr><th>Wallet</th><th>Side</th><th className="num">IMD</th><th className="num">${c.symbol}</th><th>Where</th><th>When</th></tr></thead>
              <tbody>{[...(trades ?? [])].reverse().slice(0, 50).map((t) => (
                <tr key={t.key}>
                  <td><Link className="mono" to={`/u/${t.trader}`}>{shortAddr(t.trader)}</Link></td>
                  <td className={t.isBuy ? 'pp-up' : 'pp-down'}>{t.isBuy ? 'Buy' : 'Sell'}</td>
                  <td className="num">{fmtAmount(t.imd)}</td><td className="num">{fmtAmount(t.tokens, 18, { compact: true })}</td>
                  <td>{t.pool ? 'Pool' : 'Curve'}</td>
                  <td><a href={explorerTx(t.tx)} target="_blank" rel="noreferrer">{timeAgo(t.time)}</a></td>
                </tr>))}
                {!trades?.length && <tr><td colSpan={6} className="muted">No trades yet. Be the first.</td></tr>}
              </tbody>
            </table></div>
          )}
          {tab === 'holders' && (
            <div className="table-wrap"><table className="table">
              <thead><tr><th>#</th><th>Holder</th><th className="num">Share</th><th className="num">${c.symbol}</th></tr></thead>
              <tbody>{(holders ?? []).slice(0, 20).map((h, i) => (
                <tr key={h.address}>
                  <td>{i + 1}</td>
                  <td><Link className="mono" to={`/u/${h.address}`}>{shortAddr(h.address)}</Link> {label(h.address) && <span className="pp-badge">{label(h.address)}</span>}</td>
                  <td className="num">{(Number((h.balance * 10000n) / 10n ** 27n) / 100).toFixed(2)}%</td>
                  <td className="num">{fmtAmount(h.balance, 18, { compact: true })}</td>
                </tr>))}
              </tbody>
            </table><p className="t-caption muted">{holders?.length ?? '…'} holders. Out of 1,000,000,000 ${c.symbol}.</p></div>
          )}
          {tab === 'creator' && (
            <dl className="facts">
              <div><dt>Fee recipient</dt><dd><Link className="mono" to={`/u/${c.feeRecipient}`}>{shortAddr(c.feeRecipient)}</Link>{c.feeRecipient.toLowerCase() === c.coin.toLowerCase() && ' (fees go to holders)'}</dd></div>
              <div><dt>Creator fees waiting to be claimed</dt><dd>{fmtAmount(c.creatorFeesUnclaimed)} IMD</dd></div>
              <div><dt>Fee on every trade</dt><dd>{feeLine(c)}</dd></div>
              <div><dt>Swarm budget</dt><dd>{fmtAmount(c.swarmBudgetAvailable)} IMD available for swarm jobs</dd></div>
              <div><dt>Paid to holders so far</dt><dd>{fmtAmount(c.dividendsDistributed)} IMD in dividends</dd></div>
            </dl>
          )}
          {tab === 'about' && (
            <div className="stack-xs">
              {meta?.description ? <p>{meta.description}</p> : <p className="muted">The creator didn't add a description.</p>}
              <div className="row">
                {meta?.website && <a className="pp-btn pp-btn-sm" href={meta.website} target="_blank" rel="noreferrer nofollow">Website</a>}
                {meta?.x && <a className="pp-btn pp-btn-sm" href={meta.x} target="_blank" rel="noreferrer nofollow"><Icon name="x" size={14} />X</a>}
                {meta?.telegram && <a className="pp-btn pp-btn-sm" href={meta.telegram} target="_blank" rel="noreferrer nofollow">Telegram</a>}
              </div>
              <dl className="facts">
                <div><dt>Contract</dt><dd className="mono">{c.coin}</dd></div>
                <div><dt>Supply</dt><dd>1,000,000,000, fixed. No owner, no mint.</dd></div>
                <div><dt>Curve</dt><dd>800M sold on the curve; 200M go to the pool at the Leap ({fmtAmount(c.target)} IMD target)</dd></div>
                <div><dt>Coin tax</dt><dd>{c.fees.taxBps ? `${fmtBps(c.fees.taxBps)}, fixed at launch` : 'None'}</dd></div>
              </dl>
            </div>
          )}
        </div>

        <aside className="stack coin-side">
          <div className="desktop-block"><TradeBox coin={c} /></div>
          {address && (
            <div className="panel stack-xs">
              <h2 className="t-label muted">Your position</h2>
              <div className="pp-quote">
                <div><span>Balance</span><b>{fmtAmount(bal.data)} ${c.symbol}</b></div>
                <div><span>Value now</span><b>≈ {fmtAmount(bal.data !== undefined ? (bal.data * c.priceE18) / 10n ** 18n : undefined)} IMD</b></div>
                <div><span>Dividends to collect</span><b>{fmtAmount(div.data)} IMD</b></div>
              </div>
              <button className="pp-btn pp-btn-sm" disabled={!div.data || !!pending}
                onClick={() => send([{ address: c.coin, abi: PadTokenAbi as Abi, functionName: 'claim', label: 'Collecting…' }], { ok: 'Collected your IMD.' }).catch(() => {})}>Collect your IMD</button>
              {address.toLowerCase() === c.feeRecipient.toLowerCase() && c.creatorFeesUnclaimed > 0n && (
                <button className="pp-btn pp-btn-primary pp-btn-sm" disabled={!!pending}
                  onClick={() => send([{ address: addr.creatorVault, abi: CreatorVaultAbi as Abi, functionName: 'claim', args: [c.coin], label: 'Claiming…' }], { ok: 'Creator fees claimed.' }).catch(() => {})}>Claim {fmtAmount(c.creatorFeesUnclaimed)} IMD creator fees</button>
              )}
            </div>
          )}
          <div className="panel">
            <h2 className="t-label muted">Website</h2>
            <p className="t-caption">{graduated ? 'The Chorus builds the site after the Leap; it shows here once it passes our safety check.' : 'No website yet. It gets one free at the Leap.'}</p>
          </div>
        </aside>
      </div>

      <div className="mobile trade-bar">
        <button className="pp-btn pp-btn-buy" onClick={() => setSheet('buy')}>Buy</button>
        <button className="pp-btn pp-btn-sell" onClick={() => setSheet('sell')}>Sell</button>
      </div>
      {sheet && (
        <div className="sheet" role="dialog" aria-modal="true" aria-label={`Trade $${c.symbol}`} onClick={(e) => e.target === e.currentTarget && setSheet(null)}>
          <div className="sheet-body">
            <div className="sheet-grab" />
            <button className="pp-btn pp-btn-ghost pp-btn-sm sheet-close" onClick={() => setSheet(null)}>Close</button>
            <TradeBox coin={c} initialSide={sheet} />
          </div>
        </div>
      )}
    </div>
  );
}
