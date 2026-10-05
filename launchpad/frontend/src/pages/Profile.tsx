import { useMemo, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { useAccount, usePublicClient, useReadContract } from 'wagmi';
import { erc20Abi, isAddress, type Abi, type Address, type PublicClient } from 'viem';
import { CreatorVaultAbi, IntegratorVaultAbi, PadLensAbi, PadTokenAbi, SocialRegistryAbi } from '../abi';
import { addr, explorerAddr, explorerTx } from '../config';
import { useAllTrades, useCoinList, useLaunches, type CoinView } from '../lib/chain';
import { fmtAmount, fmtBps, shortAddr, timeAgo } from '../lib/format';
import { useSend, type Call } from '../lib/tx';
import { CoinImage, StageChip } from '../components/CoinBits';
import { feeLine } from '../components/TradeBox';
import { Icon } from '../components/Icons';

type Tab = 'holdings' | 'created' | 'rewards' | 'activity';

function usePositions(wallet: Address | undefined, coins: readonly CoinView[] | undefined) {
  const pc = usePublicClient() as PublicClient;
  return useQuery({
    queryKey: ['positions', wallet, coins?.length],
    enabled: !!wallet && !!coins?.length,
    refetchInterval: 15_000,
    queryFn: () => pc.readContract({ address: addr.lens, abi: PadLensAbi, functionName: 'positions', args: [wallet!, coins!.map((c) => c.coin)] }),
  });
}

export function Profile() {
  const { address: param } = useParams();
  const { address: me, isConnected } = useAccount();
  const wallet = (param && isAddress(param) ? param : me) as Address | undefined;
  const isMe = !!me && !!wallet && me.toLowerCase() === wallet.toLowerCase();
  const { data: coins } = useCoinList();
  const { data: launches } = useLaunches();
  const { data: trades } = useAllTrades();
  const { data: pos } = usePositions(wallet, coins);
  const { send, pending } = useSend();
  const [tab, setTab] = useState<Tab>('holdings');

  const handle = useReadContract({ address: addr.socialRegistry, abi: SocialRegistryAbi, functionName: 'walletHandle', args: [wallet!], query: { enabled: !!wallet } });
  const integrator = useReadContract({ address: addr.integratorVault, abi: IntegratorVaultAbi, functionName: 'balanceOf', args: [wallet!], query: { enabled: !!wallet } });
  const pad = useReadContract({ address: addr.pondpad, abi: erc20Abi, functionName: 'balanceOf', args: [wallet!], query: { enabled: !!wallet } });
  const spad = useReadContract({ address: addr.stakedPondpad, abi: erc20Abi, functionName: 'balanceOf', args: [wallet!], query: { enabled: !!wallet } });

  const byCoin = useMemo(() => new Map(coins?.map((c) => [c.coin.toLowerCase(), c])), [coins]);
  const holdings = useMemo(() => (pos ?? []).filter((p) => p.balance > 0n || p.pendingDividends > 0n).map((p) => ({ ...p, view: byCoin.get(p.coin.toLowerCase())! }))
    .sort((a, b) => (b.balance * b.view.priceE18 > a.balance * a.view.priceE18 ? 1 : -1)), [pos, byCoin]);
  const value = holdings.reduce((s, h) => s + (h.balance * h.view.priceE18) / 10n ** 18n, 0n);
  const dividends = holdings.reduce((s, h) => s + h.pendingDividends, 0n);
  const created = useMemo(() => {
    if (!wallet || !coins) return [];
    const w = wallet.toLowerCase();
    return coins.filter((c) => c.feeRecipient.toLowerCase() === w || launches?.get(c.coin.toLowerCase())?.creator.toLowerCase() === w);
  }, [coins, launches, wallet]);
  const claimable = created.filter((c) => c.feeRecipient.toLowerCase() === wallet?.toLowerCase() && c.creatorFeesUnclaimed > 0n);
  const creatorTotal = claimable.reduce((s, c) => s + c.creatorFeesUnclaimed, 0n);
  const activity = useMemo(() => (trades ?? []).filter((t) => t.trader.toLowerCase() === wallet?.toLowerCase()).reverse(), [trades, wallet]);

  if (!wallet) {
    return <div className="wrap empty"><img src="./pip.svg" alt="" width={120} /><p>{isConnected ? 'Loading…' : 'Connect a wallet to see your coins, claims and rewards.'}</p></div>;
  }

  const claimAll = () => send(claimable.map((c): Call & { label: string } => ({ address: addr.creatorVault, abi: CreatorVaultAbi as Abi, functionName: 'claim', args: [c.coin], label: `Claiming ${c.symbol}…` })), { ok: `Claimed ${fmtAmount(creatorTotal)} IMD of creator fees.` }).catch(() => {});
  const collectAll = () => send(holdings.filter((h) => h.pendingDividends > 0n).map((h): Call & { label: string } => ({ address: h.coin, abi: PadTokenAbi as Abi, functionName: 'claim', label: `Collecting ${h.view.symbol}…` })), { ok: `Collected ${fmtAmount(dividends)} IMD of dividends.` }).catch(() => {});

  return (
    <div className="wrap stack">
      <header className="coin-head">
        <svg className="coin-head-img" viewBox="0 0 64 64" width={64} height={64} aria-hidden="true"><rect width="64" height="64" fill={`#${wallet.slice(2, 8)}`} /><circle cx="32" cy="36" r="16" fill="var(--lily)" /></svg>
        <div className="stack-xs" style={{ minWidth: 0 }}>
          <h1 className="t-title mono-title">{shortAddr(wallet)}{isMe && <span className="pp-badge">You</span>}</h1>
          <div className="row">
            {handle.data ? <span className="pp-badge pp-badge-x"><Icon name="x" size={12} />@{handle.data}</span> : <span className="t-caption muted">No X account linked</span>}
            <a className="pp-btn pp-btn-ghost pp-btn-sm" href={explorerAddr(wallet)} target="_blank" rel="noreferrer"><Icon name="ext" size={14} />Explorer</a>
          </div>
        </div>
      </header>

      <div className="pp-stats">
        <div className="pp-stat"><span>Holdings value</span><b>{fmtAmount(value)}</b><small>IMD, at current prices</small></div>
        <div className="pp-stat"><span>Creator fees to claim</span><b>{fmtAmount(creatorTotal)}</b><small>IMD across {claimable.length} coin{claimable.length === 1 ? '' : 's'}</small></div>
        <div className="pp-stat"><span>Dividends to collect</span><b>{fmtAmount(dividends)}</b><small>IMD</small></div>
        <div className="pp-stat"><span>$PONDPAD · sPONDPAD</span><b>{fmtAmount(pad.data, 18, { compact: true })} · {fmtAmount(spad.data, 18, { compact: true })}</b><small>wallet · staked in the Pond</small></div>
      </div>

      <div className="pp-tabs" role="tablist">
        {(['holdings', 'created', 'rewards', 'activity'] as Tab[]).map((t) => <button key={t} role="tab" aria-selected={tab === t} onClick={() => setTab(t)}>{t[0].toUpperCase() + t.slice(1)}{t === 'created' && created.length ? ` (${created.length})` : ''}</button>)}
      </div>

      {tab === 'holdings' && (
        holdings.length ? (
          <div className="table-wrap"><table className="table">
            <thead><tr><th>Coin</th><th>Stage</th><th className="num">Balance</th><th className="num">Value (IMD)</th><th className="num">Dividends</th><th /></tr></thead>
            <tbody>{holdings.map((h) => (
              <tr key={h.coin}>
                <td><Link className="cell-coin" to={`/c/${h.coin}`}><CoinImage coin={h.coin} uri={launches?.get(h.coin.toLowerCase())?.metadataURI} size={32} className="cell-img" /><b>{h.view.name}</b> <span className="pp-coin-ticker">${h.view.symbol}</span></Link></td>
                <td><StageChip coin={h.view} /></td>
                <td className="num">{fmtAmount(h.balance, 18, { compact: true })}</td>
                <td className="num">{fmtAmount((h.balance * h.view.priceE18) / 10n ** 18n)}</td>
                <td className="num">{fmtAmount(h.pendingDividends)}</td>
                <td><Link className="pp-btn pp-btn-sm" to={`/c/${h.coin}`}>Trade</Link></td>
              </tr>))}
            </tbody>
          </table></div>
        ) : <p className="muted">No PondPad coins in this wallet yet.</p>
      )}

      {tab === 'created' && (
        <div className="stack">
          {isMe && (
            <div className="panel claim">
              <div><h2 className="t-heading">Creator fees to claim</h2><p className="muted">{fmtAmount(creatorTotal)} IMD across {claimable.length} coin{claimable.length === 1 ? '' : 's'}. One transaction per coin.</p></div>
              <button className="pp-btn pp-btn-primary" disabled={!claimable.length || !!pending} onClick={claimAll}>{pending ?? 'Claim all'}</button>
            </div>
          )}
          {created.length ? (
            <div className="table-wrap"><table className="table">
              <thead><tr><th>Coin</th><th>Stage</th><th>Fee</th><th className="num">To claim (IMD)</th><th className="num">Swarm budget</th><th /></tr></thead>
              <tbody>{created.map((c) => {
                const toHolders = c.feeRecipient.toLowerCase() === c.coin.toLowerCase();
                const mine = c.feeRecipient.toLowerCase() === wallet.toLowerCase();
                return (
                  <tr key={c.coin}>
                    <td><Link className="cell-coin" to={`/c/${c.coin}`}><CoinImage coin={c.coin} uri={launches?.get(c.coin.toLowerCase())?.metadataURI} size={32} className="cell-img" /><b>{c.name}</b> <span className="pp-coin-ticker">${c.symbol}</span></Link></td>
                    <td><StageChip coin={c} /></td>
                    <td title={feeLine(c)}>{fmtBps(c.totalFeeBps)}</td>
                    <td className="num">{toHolders ? 'Fees go to holders' : fmtAmount(c.creatorFeesUnclaimed)}</td>
                    <td className="num">{fmtAmount(c.swarmBudgetAvailable)}</td>
                    <td>{isMe && mine && !toHolders && (
                      <button className="pp-btn pp-btn-sm" disabled={c.creatorFeesUnclaimed === 0n || !!pending}
                        onClick={() => send([{ address: addr.creatorVault, abi: CreatorVaultAbi as Abi, functionName: 'claim', args: [c.coin], label: 'Claiming…' }], { ok: `Claimed ${fmtAmount(c.creatorFeesUnclaimed)} IMD from $${c.symbol}.` }).catch(() => {})}>Claim</button>
                    )}</td>
                  </tr>
                );
              })}</tbody>
            </table></div>
          ) : <div className="empty"><p className="muted">No coins spawned from this wallet yet.</p>{isMe && <Link className="pp-btn pp-btn-primary" to="/spawn">Spawn a coin</Link>}</div>}
          {isMe && created.length > 0 && <p className="t-caption muted">Changing a coin's fee recipient, linking its X account and requesting swarm jobs arrive with the X link service and the Swarm Relay.</p>}
        </div>
      )}

      {tab === 'rewards' && (
        <div className="stack">
          <div className="panel claim">
            <div><h2 className="t-heading">Dividends</h2><p className="muted">{fmtAmount(dividends)} IMD from coins that share their tax with holders.</p></div>
            {isMe && <button className="pp-btn" disabled={dividends === 0n || !!pending} onClick={collectAll}>Collect your IMD</button>}
          </div>
          <div className="panel claim">
            <div><h2 className="t-heading">Integrator earnings</h2><p className="muted">{fmtAmount(integrator.data)} IMD from trades this wallet routed as a registered app or bot.</p></div>
            {isMe && <button className="pp-btn" disabled={!integrator.data || !!pending} onClick={() => send([{ address: addr.integratorVault, abi: IntegratorVaultAbi as Abi, functionName: 'claim', args: [wallet], label: 'Claiming…' }], { ok: 'Integrator earnings claimed.' }).catch(() => {})}>Claim</button>}
          </div>
          <div className="panel claim">
            <div><h2 className="t-heading">The Pond and the airdrop</h2><p className="muted">Staking and airdrop claims live on their own pages.</p></div>
            <div className="row"><Link className="pp-btn" to="/pond">The Pond</Link><Link className="pp-btn" to="/pondpad">$PONDPAD</Link></div>
          </div>
        </div>
      )}

      {tab === 'activity' && (
        <div className="table-wrap"><table className="table">
          <thead><tr><th>When</th><th>Coin</th><th>Side</th><th className="num">IMD</th><th className="num">Tokens</th></tr></thead>
          <tbody>{activity.slice(0, 100).map((t) => {
            const c = byCoin.get(t.coin.toLowerCase());
            return (
              <tr key={t.key}>
                <td><a href={explorerTx(t.tx)} target="_blank" rel="noreferrer">{timeAgo(t.time)}</a></td>
                <td><Link to={`/c/${t.coin}`}>{c ? `$${c.symbol}` : shortAddr(t.coin)}</Link></td>
                <td className={t.isBuy ? 'pp-up' : 'pp-down'}>{t.isBuy ? 'Buy' : 'Sell'}</td>
                <td className="num">{fmtAmount(t.imd)}</td><td className="num">{fmtAmount(t.tokens, 18, { compact: true })}</td>
              </tr>
            );
          })}{!activity.length && <tr><td colSpan={5} className="muted">No trades yet.</td></tr>}</tbody>
        </table></div>
      )}
    </div>
  );
}
