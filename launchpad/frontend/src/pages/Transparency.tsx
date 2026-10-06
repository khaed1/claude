import { useState } from 'react';
import { Link } from 'react-router-dom';
import type { Address } from 'viem';
import { addr, explorerAddr, explorerTx } from '../config';
import { fmtAmount, fmtBps, shortAddr, timeAgo } from '../lib/format';
import { nameOf, OWNED, useFlows, useOwners, useSettings, useTimelockQueue, type FlowEvent, type QueuedCall } from '../lib/transparency';

// Transparency (Pages.md, SITE-COPY §8): every number read straight from the chain.

function Stat({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return <div className="pp-stat"><span>{label}</span><b>{value}</b>{sub && <small>{sub}</small>}</div>;
}
const A = ({ a, label }: { a: Address; label?: string }) => <a className="mono" href={explorerAddr(a)} target="_blank" rel="noreferrer">{label ?? shortAddr(a)}</a>;
const ZERO = '0x0000000000000000000000000000000000000000';
const dur = (s: number) => (s >= 86400 ? `${+(s / 86400).toFixed(1)} days` : s >= 3600 ? `${+(s / 3600).toFixed(1)} h` : `${Math.round(s / 60)} min`);

export function Transparency() {
  const { data: f } = useFlows();
  return (
    <div className="wrap stack-lg">
      <header className="stack-xs pondpad-head">
        <h1 className="t-title">Where every IMD goes</h1>
        <p className="t-lead">We'd rather show you than tell you. Every number below is read straight from the chain.</p>
      </header>
      {!f ? <div className="skeleton" style={{ height: 240, borderRadius: 22 }} /> : <Flows f={f} />}
      <Queue />
      <Owners />
      <Settings />
    </div>
  );
}

function Flows({ f }: { f: NonNullable<ReturnType<typeof useFlows>['data']> }) {
  const total = f.imd.stakers + f.imd.workers + f.imd.growth + f.imd.treasury;
  const buckets = [
    { key: 'stakers', label: 'Into the pond (stakers)', bps: f.shares.stakers, imd: f.imd.stakers, pp: f.pondpad.stakers, cls: 'is-pond' },
    { key: 'workers', label: 'To IMD workers', bps: f.shares.workers, imd: f.imd.workers, pp: f.pondpad.workers, cls: 'is-workers' },
    { key: 'growth', label: 'Growth', bps: f.shares.growth, imd: f.imd.growth, pp: f.pondpad.growth, cls: 'is-growth' },
    { key: 'treasury', label: 'Treasury', bps: f.shares.treasury, imd: f.imd.treasury, pp: f.pondpad.treasury, cls: 'is-treasury' },
  ];
  const workersWaiting = f.workers.address === ZERO;
  return (
    <>
      <div className="pp-stats">
        <Stat label="Protocol fees shared out" value={`${fmtAmount(total)} IMD`} sub={`+ ${fmtAmount(f.pendingImd)} IMD waiting for the next split`} />
        <Stat label="To apps and bots" value={`${fmtAmount(f.integrators)} IMD`} sub="integrators' 15% of the fee on trades they route" />
        <Stat label="$PONDPAD burned" value={fmtAmount(f.burned, 18, { compact: true })} sub="by the market's cap, gone for good" />
        <Stat label="In the Pond" value={fmtAmount(f.stakedValue, 18, { compact: true })} sub={`$PONDPAD staked; ${fmtAmount(f.dripped, 18, { compact: true })} dripped in so far`} />
      </div>

      <section className="stack">
        <h2 className="t-heading">The split</h2>
        <div className="split-bar" role="img" aria-label={buckets.map((b) => `${b.label} ${fmtBps(b.bps)}`).join(', ')}>
          {buckets.map((b) => <span key={b.key} className={b.cls} style={{ flexGrow: b.bps }}>{fmtBps(b.bps)}</span>)}
        </div>
        <p className="t-caption muted">Every protocol fee (1% of each coin trade, launch fees, the sale's 1% and the market's fee) is split this way by the <A a={addr.feeSplitter} label="FeeSplitter" />. The shares can only move within fixed ranges, and only through the 7-day timelock.</p>
        <div className="bucket-grid">
          <div className={`panel stack-xs bucket is-pond`}>
            <h3 className="t-label">{buckets[0].label} · {fmtBps(buckets[0].bps)}</h3>
            <b className="bucket-num">{fmtAmount(buckets[0].imd)} IMD</b>
            <p className="t-caption muted">+ {fmtAmount(buckets[0].pp, 18, { compact: true })} $PONDPAD from market fees</p>
            <p><A a={addr.padBuyer} label="PadBuyer" /> spent <b>{fmtAmount(f.buyer.spent)} IMD</b> buying <b>{fmtAmount(f.buyer.bought, 18, { compact: true })} $PONDPAD</b> for the Pond. {fmtAmount(f.buyer.waiting)} IMD waiting to be spent.</p>
            <Link className="t-caption" to="/pond">See the Pond</Link>
          </div>
          <div className={`panel stack-xs bucket is-workers`}>
            <h3 className="t-label">{buckets[1].label} · {fmtBps(buckets[1].bps)}</h3>
            <b className="bucket-num">{fmtAmount(buckets[1].imd)} IMD</b>
            <p className="t-caption muted">+ {fmtAmount(buckets[1].pp, 18, { compact: true })} $PONDPAD</p>
            {workersWaiting
              ? <p>Held in the <A a={addr.workerFund} label="WorkerFund" /> ({fmtAmount(f.workers.heldImd)} IMD, {fmtAmount(f.workers.heldPondpad, 18, { compact: true })} $PONDPAD) until the IMD team gives the worker rewards address. Then anyone can release it.</p>
              : <p>Released to the IMD worker rewards address <A a={f.workers.address} />: {fmtAmount(f.workers.releasedImd)} IMD and {fmtAmount(f.workers.releasedPondpad, 18, { compact: true })} $PONDPAD. {fmtAmount(f.workers.heldImd)} IMD waiting for the next release.</p>}
          </div>
          <div className={`panel stack-xs bucket is-growth`}>
            <h3 className="t-label">{buckets[2].label} · {fmtBps(buckets[2].bps)}</h3>
            <b className="bucket-num">{fmtAmount(buckets[2].imd)} IMD</b>
            <p className="t-caption muted">plus graduation fees and early-bird taxes, which go straight to growth</p>
            <p>The <A a={addr.growthFund} label="GrowthFund" /> holds {fmtAmount(f.growth.imd)} IMD and {fmtAmount(f.growth.pondpad, 18, { compact: true })} $PONDPAD. This week it can pay at most {fmtAmount(f.growth.relayAvailable)} more IMD in swarm jobs (cap {fmtAmount(f.growth.relayCap)}) and grant {fmtAmount(f.growth.grantAvailImd)} IMD / {fmtAmount(f.growth.grantAvailPondpad, 18, { compact: true })} $PONDPAD.</p>
          </div>
          <div className={`panel stack-xs bucket is-treasury`}>
            <h3 className="t-label">{buckets[3].label} · {fmtBps(buckets[3].bps)}</h3>
            <b className="bucket-num">{fmtAmount(buckets[3].imd)} IMD</b>
            <p className="t-caption muted">+ {fmtAmount(buckets[3].pp, 18, { compact: true })} $PONDPAD</p>
            <p>Paid to the team Safe <A a={f.recipients.treasury} />, which holds {fmtAmount(f.treasury.imd)} IMD and {fmtAmount(f.treasury.pondpad, 18, { compact: true })} $PONDPAD now.</p>
          </div>
        </div>
      </section>

      <section className="stack">
        <h2 className="t-heading">Swarm jobs paid</h2>
        <Events rows={f.growth.payments} empty="No swarm jobs or grants paid yet. Each one shows here with its reason." />
        <h3 className="t-label">PadBuyer purchases for the Pond</h3>
        <Events rows={f.buyer.buys.slice(0, 10)} empty="No purchases yet." />
      </section>
    </>
  );
}

function Events({ rows, empty }: { rows: FlowEvent[]; empty: string }) {
  return (
    <div className="table-wrap"><table className="table">
      <thead><tr><th>What</th><th>Why</th><th className="num">IMD</th><th className="num">$PONDPAD</th><th>When</th></tr></thead>
      <tbody>
        {rows.map((r) => (
          <tr key={r.key}><td>{r.what}</td><td className="wrap-cell">{r.detail}</td><td className="num">{r.imd !== undefined ? fmtAmount(r.imd) : '–'}</td><td className="num">{r.tokens !== undefined ? fmtAmount(r.tokens, 18, { compact: true }) : '–'}</td>
            <td><a href={explorerTx(r.tx)} target="_blank" rel="noreferrer">{timeAgo(r.time)}</a></td></tr>
        ))}
        {!rows.length && <tr><td colSpan={5} className="muted">{empty}</td></tr>}
      </tbody>
    </table></div>
  );
}

const STATUS: Record<QueuedCall['status'], string> = { waiting: 'Waiting', ready: 'Ready, not run yet', done: 'Done', cancelled: 'Cancelled' };

function Queue() {
  const { data: q } = useTimelockQueue();
  const [all, setAll] = useState(false);
  const open = (q ?? []).filter((c) => c.status === 'waiting' || c.status === 'ready');
  const past = (q ?? []).filter((c) => c.status === 'done' || c.status === 'cancelled');
  const row = (c: QueuedCall) => (
    <tr key={c.key}>
      <td><span className={`pp-badge ${c.status === 'waiting' ? 'pp-badge-tax' : ''}`}>{STATUS[c.status]}</span></td>
      <td className="wrap-cell"><b>{c.call}</b>{c.args && <div className="mono muted">{c.args.length > 120 ? `${c.args.slice(0, 120)}…` : c.args}</div>}</td>
      <td>{c.timelock}</td>
      <td>{new Date(c.readyAt * 1000).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' })}</td>
      <td><a href={explorerTx(c.tx)} target="_blank" rel="noreferrer">Scheduled {timeAgo(c.scheduledAt)}</a></td>
    </tr>
  );
  return (
    <section className="stack">
      <h2 className="t-heading">Settings changes waiting in the timelock</h2>
      <p>Nobody can change the rules overnight. Every change waits here first, in public.</p>
      <div className="table-wrap"><table className="table">
        <thead><tr><th>Status</th><th>Change</th><th>Timelock</th><th>Ready from</th><th>Tx</th></tr></thead>
        <tbody>
          {open.map(row)}
          {q && !open.length && <tr><td colSpan={5} className="muted">Nothing waiting right now.</td></tr>}
          {!q && <tr><td colSpan={5} className="muted">Checking the pond…</td></tr>}
          {all && past.map(row)}
        </tbody>
      </table></div>
      {past.length > 0 && <button className="linkish" onClick={() => setAll(!all)}>{all ? 'Hide past changes' : `Show ${past.length} past change${past.length > 1 ? 's' : ''}`}</button>}
    </section>
  );
}

function Owners() {
  const { data: o } = useOwners();
  const who = (a?: Address) => {
    if (!a) return '–';
    const n = nameOf(a);
    return n ?? (a === ZERO ? 'nobody (renounced)' : shortAddr(a));
  };
  return (
    <section className="stack">
      <h2 className="t-heading">Who can change what</h2>
      <p className="muted">Two timelocks hold every admin power{o ? ` (${dur(o.fastDelay)} and ${dur(o.slowDelay)} on this network)` : ''}. The team Safe can only propose; anyone can run a change once its wait is over. The deployer kept nothing. Coins, the bonding curve, pools and locked liquidity have no owner at all.</p>
      <div className="table-wrap"><table className="table">
        <thead><tr><th>Contract</th><th>Owner</th><th>What the owner can do</th></tr></thead>
        <tbody>{OWNED.map((c) => (
          <tr key={c.key}><td><A a={addr[c.key] as Address} label={c.name} /></td><td>{who(o?.owners[c.key])}</td><td className="wrap-cell">{c.can}</td></tr>
        ))}</tbody>
      </table></div>
      <p className="t-caption muted">More in the docs: <Link to="/docs/admin">Admin powers and timelocks</Link> · <Link to="/docs/contracts">Contracts and addresses</Link></p>
    </section>
  );
}

function Settings() {
  const { data: s } = useSettings();
  if (!s) return null;
  const l = s.launch;
  return (
    <section className="stack">
      <h2 className="t-heading">Current settings</h2>
      <dl className="facts">
        <div><dt>Launch fee</dt><dd>{fmtAmount(l.launchFee)} IMD{s.paused ? ' · new launches paused by the guardian' : ''}</dd></div>
        <div><dt>Leap target</dt><dd>{fmtAmount(l.graduationTarget)} IMD raised; {fmtBps(l.graduationFeeBps)} of it goes to growth at the Leap</dd></div>
        <div><dt>Early-bird tax on coins</dt><dd>{fmtBps(l.snipeTaxStartBps)} falling to zero over {l.snipeTaxDuration} seconds</dd></div>
        <div><dt>Early max-buy (Egg stage)</dt><dd>{fmtBps(l.maxBuyBps)} of supply per wallet for the first {l.maxBuyWindow} seconds</dd></div>
        <div><dt>Base fee</dt><dd>1.5% per trade: 1% protocol, 0.5% creator (fixed in code)</dd></div>
        <div><dt>Apps and bots</dt><dd>{fmtBps(s.integratorBps)} of the protocol fee on trades they route</dd></div>
        <div><dt>$PONDPAD market</dt><dd>fee {(s.market.feePips / 10_000).toFixed(2)}% now · cap floor {fmtAmount(s.market.capFloor, 18, { compact: true })} · cap falls at most {fmtAmount(s.market.capDecay, 18, { compact: true })} a day · {fmtBps(s.market.rewardBps)} of trims to the Pond</dd></div>
        <div><dt>PadBuyer</dt><dd>at most {fmtAmount(s.buyer.maxChunk)} IMD every {dur(s.buyer.interval)}, {fmtBps(s.buyer.tipBps)} tip to whoever runs it</dd></div>
      </dl>
    </section>
  );
}
