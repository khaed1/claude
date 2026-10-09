import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { Link, NavLink, useLocation, useNavigate } from 'react-router-dom';
import { useAccount, useConnect, useDisconnect, useSwitchChain } from 'wagmi';
import { chain } from '../config';
import { useAllTrades, useCoinList, useGraduations, useLaunches } from '../lib/chain';
import { fmtAmount, shortAddr } from '../lib/format';
import { Icon, LilyMark, type IconName } from './Icons';
import { LegalGate } from './LegalGate';

const NAV: { to: string; label: string; icon: IconName }[] = [
  { to: '/', label: 'Explore', icon: 'home' },
  { to: '/pondpad', label: '$PONDPAD', icon: 'coin' },
  { to: '/pond', label: 'The Pond', icon: 'pond' },
  { to: '/docs', label: 'Docs', icon: 'book' },
];

function useTheme() {
  const [theme, setTheme] = useState<string>(() => { try { return localStorage.getItem('pp-theme') ?? 'system'; } catch { return 'system'; } });
  useEffect(() => {
    const root = document.documentElement;
    if (theme === 'system') root.removeAttribute('data-theme'); else root.setAttribute('data-theme', theme);
    try { localStorage.setItem('pp-theme', theme); } catch { /* private mode */ }
  }, [theme]);
  return [theme, setTheme] as const;
}

function Wallet() {
  const { address, isConnected } = useAccount();
  const { connectors, connect, isPending, error } = useConnect();
  const { disconnect } = useDisconnect();
  const [open, setOpen] = useState(false);
  const [theme, setTheme] = useTheme();
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const close = (e: MouseEvent) => { if (!ref.current?.contains(e.target as Node)) setOpen(false); };
    document.addEventListener('click', close);
    return () => document.removeEventListener('click', close);
  }, []);

  if (!isConnected) {
    const injected = connectors[0];
    const hasWallet = typeof window !== 'undefined' && 'ethereum' in window;
    return hasWallet ? (
      <button className="pp-btn pp-btn-sm" disabled={isPending} onClick={() => connect({ connector: injected, chainId: chain.id })} title={error?.message}>
        {isPending ? 'Connecting…' : 'Connect wallet'}
      </button>
    ) : (
      <a className="pp-btn pp-btn-sm" href="https://ethereum.org/en/wallets/find-wallet/" target="_blank" rel="noreferrer">Get a wallet</a>
    );
  }
  return (
    <div className="menu" ref={ref}>
      <button className="pp-btn pp-btn-sm" aria-haspopup="menu" aria-expanded={open} onClick={() => setOpen((o) => !o)}>{shortAddr(address)}</button>
      {open && (
        <div className="menu-pop" role="menu">
          <Link role="menuitem" to="/me" onClick={() => setOpen(false)}>Profile</Link>
          <Link role="menuitem" to="/transparency" onClick={() => setOpen(false)}>Transparency</Link>
          <div className="menu-row" role="group" aria-label="Theme">
            {(['system', 'night', 'day'] as const).map((t) => (
              <button key={t} aria-pressed={theme === t} onClick={() => setTheme(t)}>{t === 'system' ? 'Auto' : t === 'night' ? 'Night' : 'Day'}</button>
            ))}
          </div>
          <button role="menuitem" onClick={() => { disconnect(); setOpen(false); }}>Disconnect</button>
        </div>
      )}
    </div>
  );
}

function Search() {
  const { data: coins } = useCoinList();
  const [q, setQ] = useState('');
  const nav = useNavigate();
  const hits = useMemo(() => {
    const t = q.trim().toLowerCase().replace(/^\$/, '');
    if (!t || !coins) return [];
    if (/^0x[0-9a-f]{40}$/.test(t)) return coins.filter((c) => c.coin.toLowerCase() === t || c.feeRecipient.toLowerCase() === t).slice(0, 6);
    return coins.filter((c) => c.name.toLowerCase().includes(t) || c.symbol.toLowerCase().includes(t)).slice(0, 6);
  }, [q, coins]);
  const go = (to: string) => { setQ(''); nav(to); };
  return (
    <div className="search">
      <label className="pp-search">
        <Icon name="search" />
        <input id="search" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search coins, tickers, creators"
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              if (hits[0]) go(`/c/${hits[0].coin}`);
              else if (/^0x[0-9a-fA-F]{40}$/.test(q.trim())) go(`/u/${q.trim()}`);
            }
          }} aria-label="Search coins" />
      </label>
      {q && (
        <div className="search-pop" role="listbox">
          {hits.length ? hits.map((c) => (
            <button key={c.coin} role="option" aria-selected="false" onClick={() => go(`/c/${c.coin}`)}><b>{c.name}</b> <span className="pp-coin-ticker">${c.symbol}</span></button>
          )) : <div className="muted search-empty">No frogs by that name. Maybe it's still an egg?</div>}
        </div>
      )}
    </div>
  );
}

function Ripples() {
  const { data: trades } = useAllTrades();
  const { data: coins } = useCoinList();
  const { data: launches } = useLaunches();
  const { data: grads } = useGraduations();
  const sym = useMemo(() => new Map(coins?.map((c) => [c.coin.toLowerCase(), c.symbol])), [coins]);
  type R = { key: string; time: number; node: ReactNode; cls: string; to: string };
  const items: R[] = [];
  for (const t of trades?.slice(-14) ?? []) items.push({
    key: t.key, time: t.time, cls: t.isBuy ? 'is-buy' : 'is-sell', to: `/c/${t.coin}`,
    node: <>{shortAddr(t.trader)} <b>{t.isBuy ? 'bought' : 'sold'}</b> {fmtAmount(t.imd)} IMD of <span className="pp-coin-ticker">${sym.get(t.coin.toLowerCase()) ?? '…'}</span></>,
  });
  for (const l of [...(launches?.values() ?? [])].slice(-5)) items.push({ key: `l${l.coin}`, time: l.time, cls: '', to: `/c/${l.coin}`, node: <>{shortAddr(l.creator)} spawned <span className="pp-coin-ticker">${l.symbol}</span></> });
  for (const [coin, g] of [...(grads?.entries() ?? [])].slice(-4)) items.push({ key: `g${coin}`, time: g.time, cls: 'is-leap', to: `/c/${coin}`, node: <><Icon name="leap" /><span className="pp-coin-ticker">${sym.get(coin) ?? '…'}</span> just leapt</> });
  items.sort((a, b) => b.time - a.time);
  if (!items.length) return null;
  return (
    <div className="pp-ripples" aria-label="Live activity">
      <div className="ripples-track">
        {items.slice(0, 18).map((r) => <Link key={r.key} to={r.to} className={`pp-ripple ${r.cls}`}>{r.node}</Link>)}
      </div>
    </div>
  );
}

function WrongNetwork() {
  const { isConnected, chainId } = useAccount();
  const { switchChain, isPending } = useSwitchChain();
  if (!isConnected || chainId === chain.id) return null;
  return (
    <div className="wrap"><div className="pp-notice pp-notice-danger" role="alert">
      <Icon name="alert" />
      <div><b>You're in the wrong pond.</b> Switch to {chain.name}. <button className="pp-btn pp-btn-sm" disabled={isPending} onClick={() => switchChain({ chainId: chain.id })}>Switch network</button></div>
    </div></div>
  );
}

export function Layout({ children }: { children: ReactNode }) {
  const { pathname } = useLocation();
  useEffect(() => window.scrollTo(0, 0), [pathname]);
  return (
    <>
      <a className="skip" href="#main">Skip to content</a>
      <header className="pp-top">
        <Link className="pp-logo" to="/" aria-label="PondPad home"><LilyMark />pondpad</Link>
        <nav className="pp-nav desktop" aria-label="Main">
          {NAV.map((n) => <NavLink key={n.to} to={n.to} end={n.to === '/'} className={({ isActive }) => (isActive ? 'active' : '')}>{n.label}</NavLink>)}
        </nav>
        <Search />
        <Link className="pp-btn pp-btn-primary pp-btn-sm desktop" to="/spawn">Spawn</Link>
        <Wallet />
      </header>
      <div className={pathname === '/' ? '' : 'desktop'}><Ripples /></div>
      <div className="testnet-bar">Robinhood Chain Testnet: test tokens with no value. Get test IMD and USDG from the <Link to="/faucet">faucet</Link>.</div>
      <WrongNetwork />
      <main id="main">{children}</main>
      <footer className="foot wrap">
        <div className="foot-links">
          <Link to="/docs">Docs</Link><Link to="/docs/contracts">Contracts</Link><Link to="/docs/risks">Risks</Link>
          <Link to="/transparency">Transparency</Link><Link to="/terms">Terms</Link><Link to="/privacy">Privacy</Link>
        </div>
        <p>PondPad · Built with the IMD swarm. Coins here are made by anyone. Do your own research. Ribbit responsibly.</p>
      </footer>
      <nav className="pp-tabbar mobile" aria-label="Main">
        <NavLink to="/" end><span><Icon name="home" size={22} /></span><span>Explore</span></NavLink>
        <NavLink to="/pondpad"><span><Icon name="coin" size={22} /></span><span>$PONDPAD</span></NavLink>
        <NavLink to="/spawn" className="is-spawn"><span><Icon name="plus" size={20} /></span><span>Spawn</span></NavLink>
        <NavLink to="/pond"><span><Icon name="pond" size={22} /></span><span>Pond</span></NavLink>
        <NavLink to="/me"><span><Icon name="user" size={22} /></span><span>Profile</span></NavLink>
      </nav>
      <LegalGate />
    </>
  );
}
