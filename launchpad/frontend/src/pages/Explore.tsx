import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { changes24h, STATUS, useAllTrades, useBadges, useCoinList, useLaunches, volumeSince, type CoinView } from '../lib/chain';
import { CoinCard, mcapOf } from '../components/CoinBits';
import { pct } from '../lib/format';

type Tab = 'new' | 'leap' | 'frogs' | 'trending';
type Sort = 'recent' | 'newest' | 'mcap' | 'volume' | 'progress';
const TABS: { id: Tab; label: string }[] = [
  { id: 'new', label: 'New' }, { id: 'leap', label: 'About to Leap' }, { id: 'frogs', label: 'Frogs' }, { id: 'trending', label: 'Trending' },
];

export function Explore() {
  const { data: coins, isLoading, error } = useCoinList();
  const { data: trades } = useAllTrades();
  const { data: launches } = useLaunches();
  const { data: badges } = useBadges(coins);
  const [tab, setTab] = useState<Tab>('new');
  const [sort, setSort] = useState<Sort>('recent');
  const [onlyX, setOnlyX] = useState(false);
  const [noTax, setNoTax] = useState(false);
  const [shown, setShown] = useState(24);

  const change = useMemo(() => changes24h(trades), [trades]);
  const vol1h = useMemo(() => volumeSince(trades, 3600), [trades]);
  const vol24 = useMemo(() => volumeSince(trades, 86400), [trades]);
  const lastTrade = useMemo(() => { const m = new Map<string, number>(); for (const t of trades ?? []) m.set(t.coin.toLowerCase(), t.time); return m; }, [trades]);

  const tadpoles = (coins ?? []).filter((c) => c.status === STATUS.Trading);
  const spotlight = [...tadpoles].filter((c) => pct(c.raised, c.target) >= 75).sort((a, b) => pct(b.raised, b.target) - pct(a.raised, a.target)).slice(0, 8);

  const list = useMemo(() => {
    const k = (c: CoinView) => c.coin.toLowerCase();
    let l = [...(coins ?? [])];
    if (tab === 'new') l = l.filter((c) => c.status !== STATUS.Graduated);
    if (tab === 'leap') l = l.filter((c) => c.status === STATUS.Trading).sort((a, b) => pct(b.raised, b.target) - pct(a.raised, a.target));
    if (tab === 'frogs') l = l.filter((c) => c.status === STATUS.Graduated);
    if (onlyX) l = l.filter((c) => badges?.get(k(c))?.linked);
    if (noTax) l = l.filter((c) => c.fees.taxBps === 0);
    const by: Record<Sort, (a: CoinView, b: CoinView) => number> = {
      recent: (a, b) => (lastTrade.get(k(b)) ?? Number(b.launchedAt)) - (lastTrade.get(k(a)) ?? Number(a.launchedAt)),
      newest: (a, b) => Number(b.launchedAt) - Number(a.launchedAt),
      mcap: (a, b) => (mcapOf(b) > mcapOf(a) ? 1 : -1),
      volume: (a, b) => ((vol24.get(k(b)) ?? 0n) > (vol24.get(k(a)) ?? 0n) ? 1 : -1),
      progress: (a, b) => pct(b.raised, b.target) - pct(a.raised, a.target),
    };
    if (tab === 'trending') l.sort((a, b) => ((vol1h.get(k(b)) ?? 0n) > (vol1h.get(k(a)) ?? 0n) ? 1 : -1));
    else if (tab !== 'leap') l.sort(by[sort]);
    return l;
  }, [coins, tab, sort, onlyX, noTax, badges, lastTrade, vol1h, vol24]);

  const card = (c: CoinView, spot = false) => (
    <CoinCard key={c.coin} coin={c} uri={launches?.get(c.coin.toLowerCase())?.metadataURI} change={change.get(c.coin.toLowerCase())}
      verified={badges?.get(c.coin.toLowerCase())?.linked} spotlight={spot} />
  );

  return (
    <div className="wrap stack-lg">
      <section className="hero">
        <h1 className="t-hero">Every frog starts as a tadpole.</h1>
        <p className="t-lead muted">Spawn a coin on Robinhood Chain, paired with IMD. Get it to the Leap and the IMD swarm builds its website for you.</p>
        <div className="row">
          <Link className="pp-btn pp-btn-primary" to="/spawn">Spawn a coin</Link>
          <Link className="pp-btn" to="/docs">How it works</Link>
        </div>
      </section>

      {spotlight.length > 0 && (
        <section aria-labelledby="leap-h">
          <h2 id="leap-h" className="t-heading">About to Leap</h2>
          <div className="spotlight">{spotlight.map((c) => card(c, true))}</div>
        </section>
      )}

      <section aria-label="Coins" className="stack">
        <div className="toolbar">
          <div className="pp-tabs" role="tablist">
            {TABS.map((t) => <button key={t.id} role="tab" aria-selected={tab === t.id} onClick={() => { setTab(t.id); setShown(24); }}>{t.label}</button>)}
          </div>
          <div className="row filters">
            <button className={`chip-toggle${onlyX ? ' on' : ''}`} aria-pressed={onlyX} onClick={() => setOnlyX(!onlyX)}>X verified</button>
            <button className={`chip-toggle${noTax ? ' on' : ''}`} aria-pressed={noTax} onClick={() => setNoTax(!noTax)}>No coin tax</button>
            {tab !== 'trending' && tab !== 'leap' && (
              <label className="select"><span className="sr">Sort</span>
                <select id="sort" value={sort} onChange={(e) => setSort(e.target.value as Sort)}>
                  <option value="recent">Recent trades</option><option value="newest">Newest</option><option value="mcap">Market cap</option>
                  <option value="volume">Volume 24h</option><option value="progress">% to the Leap</option>
                </select>
              </label>
            )}
          </div>
        </div>
        {error && <div className="pp-notice pp-notice-danger"><div><b>Can't reach the pond right now.</b> The RPC didn't answer; this page retries by itself.</div></div>}
        {isLoading && <div className="grid">{Array.from({ length: 6 }, (_, i) => <div key={i} className="pp-coin skeleton" />)}</div>}
        {!isLoading && list.length === 0 && (
          <div className="empty"><img src="./pip.svg" alt="" width={120} /><p>Quiet pond today. Be the first to spawn something.</p><Link className="pp-btn pp-btn-primary" to="/spawn">Spawn a coin</Link></div>
        )}
        <div className="grid">{list.slice(0, shown).map((c) => card(c))}</div>
        {shown < list.length && <button className="pp-btn more" onClick={() => setShown(shown + 24)}>Show more ({list.length - shown} left)</button>}
      </section>
    </div>
  );
}
