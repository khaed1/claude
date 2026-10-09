import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAccount, usePublicClient } from 'wagmi';
import { useQuery } from '@tanstack/react-query';
import { formatUnits, type Abi, type PublicClient } from 'viem';
import { PadBuyerAbi, RewardDripperAbi, StakedPONDPADAbi } from '../abi';
import { addr, explorerAddr, MARKET_GAS_HEADROOM } from '../config';
import { fmtAmount, parseAmount, timeAgo } from '../lib/format';
import { approveIfNeeded, useSend, type Call } from '../lib/tx';
import { SHARE_DECIMALS, useBuyerReady, usePond, type PondState } from '../lib/pond';
import { Icon } from '../components/Icons';

// The Pond (Pages.md): stats, stake / leave, the short hold after joining (D-65, D-70), where rewards come from,
// and the two permissionless calls that keep it flowing.

function Stat({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return <div className="pp-stat"><span>{label}</span><b>{value}</b>{sub && <small>{sub}</small>}</div>;
}

export function Pond() {
  const { data: p } = usePond();
  if (!p) return <div className="wrap"><div className="skeleton" style={{ height: 320, borderRadius: 22 }} /></div>;
  const growth = Number(p.perShare) / 1e18;
  return (
    <div className="wrap stack-lg">
      <header className="stack-xs pondpad-head">
        <h1 className="t-title">The Pond</h1>
        <p className="t-lead">Stake $PONDPAD, get sPONDPAD. Part of every trade on PondPad buys $PONDPAD and drips it into the pond, so each sPONDPAD is slowly worth more $PONDPAD. Nothing to claim. Leave when you like (a few seconds after joining).</p>
      </header>

      {p.paused && (
        <div className="pp-notice pp-notice-danger"><Icon name="alert" /><div><b>The pond is paused.</b> Staking and leaving are stopped for at most 3 days (until {new Date(p.pausedUntil * 1000).toLocaleString()}). Nobody can take staked $PONDPAD, paused or not.</div></div>
      )}

      <section className="coin-grid">
        <div className="stack" style={{ minWidth: 0 }}>
          <div className="pp-stats">
            {p.me && <Stat label="Your sPONDPAD" value={fmtAmount(p.me.shares, SHARE_DECIMALS, { compact: true })} sub={`≈ ${fmtAmount(p.me.assets)} $PONDPAD`} />}
            <Stat label="1 sPONDPAD is worth" value={`${growth.toFixed(4)}`} sub={`$PONDPAD (started at 1.0000)`} />
            <Stat label="Dripping in now" value={`~${fmtAmount(p.perDay, 18, { compact: true })}`} sub="$PONDPAD a day" />
            <Stat label="Total staked" value={fmtAmount(p.totalAssets, 18, { compact: true })} sub="$PONDPAD in the pond" />
            {!p.me && <Stat label="Burned so far" value={fmtAmount(p.burned, 18, { compact: true })} sub="$PONDPAD, gone for good" />}
          </div>
          <div className="explain">
            <div className="stack-xs">
              <h3 className="t-label">Where rewards come from</h3>
              <p>40% of every protocol fee on PondPad belongs to the Pond. It arrives as IMD; <b>PadBuyer</b> buys $PONDPAD with it in small, price-guarded chunks ({fmtAmount(p.buyerImd)} IMD waiting now). The market's $PONDPAD fees and 15% of every trim come here too.</p>
            </div>
            <div className="stack-xs">
              <h3 className="t-label">How it drips</h3>
              <p>The <b>RewardDripper</b> holds what was bought ({fmtAmount(p.dripBuffer, 18, { compact: true })} $PONDPAD now) and releases about 1/7 of it a week, a little at a time, whatever the volume. Each drip raises what every sPONDPAD is worth. Last drip {p.lastDripAt ? timeAgo(p.lastDripAt) : 'not yet'}.</p>
            </div>
            <div className="stack-xs">
              <h3 className="t-label">The short wait</h3>
              <p>You can leave once the next Ethereum block arrives after you join, usually within 12 seconds. That rule stops anyone borrowing a pile of $PONDPAD, catching a drip and leaving in the same moment.</p>
            </div>
          </div>
          <Upkeep p={p} />
          <p className="t-caption muted">{p.me && <>{fmtAmount(p.burned)} $PONDPAD burned so far by the market. </>}Rewards depend on how much trading happens. Some weeks are busy, some aren't. We don't promise a number, and anyone who does is guessing. Contracts: <a href={explorerAddr(addr.stakedPondpad)} target="_blank" rel="noreferrer">sPONDPAD</a> · <a href={explorerAddr(addr.rewardDripper)} target="_blank" rel="noreferrer">RewardDripper</a> · <a href={explorerAddr(addr.padBuyer)} target="_blank" rel="noreferrer">PadBuyer</a>. Get $PONDPAD on the <Link to="/pondpad">$PONDPAD page</Link>.</p>
        </div>
        <aside className="stack coin-side pondpad-side"><StakeBox p={p} /></aside>
      </section>
    </div>
  );
}

function StakeBox({ p }: { p: PondState }) {
  const { address, isConnected } = useAccount();
  const pc = usePublicClient() as PublicClient;
  const [side, setSide] = useState<'stake' | 'leave'>('stake');
  const [text, setText] = useState('');
  const { send, pending } = useSend();
  useEffect(() => setText(''), [side]);
  const stake = side === 'stake';
  const decimals = stake ? 18 : SHARE_DECIMALS;
  const amount = parseAmount(text, decimals);
  const balance = stake ? p.me?.wallet : p.me?.shares;
  const over = amount !== undefined && balance !== undefined && amount > balance;
  const waiting = !stake && !!p.me && p.me.shares > 0n && p.me.maxRedeem === 0n && !p.paused;

  const { data: preview } = useQuery({
    queryKey: ['pondPreview', side, amount?.toString(), p.perShare.toString()],
    enabled: !!amount && amount > 0n,
    queryFn: () => pc.readContract({ address: addr.stakedPondpad, abi: StakedPONDPADAbi, functionName: stake ? 'previewDeposit' : 'previewRedeem', args: [amount!] }) as Promise<bigint>,
  });

  async function go() {
    if (!address || !amount) return;
    if (stake) {
      const calls: (Call & { label: string })[] = [...(await approveIfNeeded(pc, addr.pondpad, address, addr.stakedPondpad, amount))];
      calls.push({ address: addr.stakedPondpad, abi: StakedPONDPADAbi as Abi, functionName: 'deposit', args: [amount, address], label: 'Joining the pond…' });
      await send(calls, { ok: `You're in the pond with ${fmtAmount(amount)} $PONDPAD.` }).catch(() => {});
    } else {
      // Leaving everything redeems the exact share balance, so no dust is left behind.
      const shares = p.me && amount >= p.me.shares ? p.me.shares : amount;
      await send([{ address: addr.stakedPondpad, abi: StakedPONDPADAbi as Abi, functionName: 'redeem', args: [shares, address, address], label: 'Leaving the pond…' }],
        { ok: `You left the pond with ${fmtAmount(preview)} $PONDPAD.` }).catch(() => {});
    }
    setText('');
  }

  let button = stake ? 'Stake $PONDPAD' : 'Leave the pond';
  let disabled = !amount || amount === 0n;
  if (!isConnected) { button = 'Connect a wallet to hop in'; disabled = true; }
  else if (p.paused) { button = 'The pond is paused'; disabled = true; }
  else if (pending) { button = pending; disabled = true; }
  else if (over) { button = stake ? 'Not enough $PONDPAD' : 'Not enough sPONDPAD'; disabled = true; }
  else if (waiting) { button = 'Ready in a few seconds'; disabled = true; }

  return (
    <div className="pp-trade">
      <div className="pp-seg is-trade" role="group" aria-label="Stake or leave">
        <button data-side="buy" aria-pressed={stake} onClick={() => setSide('stake')}>Stake</button>
        <button data-side="sell" aria-pressed={!stake} onClick={() => setSide('leave')}>Leave</button>
      </div>
      <div className="pp-field">
        <div className="field-head">
          <label htmlFor="pond-amount">{stake ? 'You stake' : 'You leave with'}</label>
          {balance !== undefined && <span className="t-caption muted">Balance {fmtAmount(balance, decimals)} {stake ? '$PONDPAD' : 'sPONDPAD'}</span>}
        </div>
        <div className="pp-amount">
          <input id="pond-amount" inputMode="decimal" autoComplete="off" placeholder="0.0" value={text} onChange={(e) => setText(e.target.value.replace(',', '.'))} />
          <span className="pp-token is-static">{stake ? '$PONDPAD' : 'sPONDPAD'}</span>
        </div>
        <div className="pp-presets">
          {['25%', '50%', '100%'].map((x) => (
            <button key={x} disabled={!balance} onClick={() => balance !== undefined && setText(formatUnits((balance * BigInt(parseInt(x))) / 100n, decimals))}>{x}</button>
          ))}
        </div>
      </div>
      <div className="pp-quote" aria-live="polite">
        <div><span>You get</span><b>{preview !== undefined && amount ? (stake ? `${fmtAmount(preview, SHARE_DECIMALS)} sPONDPAD` : `${fmtAmount(preview)} $PONDPAD`) : '–'}</b></div>
        <div><span>1 sPONDPAD</span><b>{(Number(p.perShare) / 1e18).toFixed(4)} $PONDPAD</b></div>
        <div className="pp-fee"><span>Fee</span><b>None to join or leave</b></div>
      </div>
      {waiting && <div className="pp-notice"><Icon name="clock" /><div>You just joined. You can leave after the next Ethereum block, usually within 12 seconds.</div></div>}
      <button className={`pp-btn pp-btn-block ${stake ? 'pp-btn-primary' : 'pp-btn-sell'}`} disabled={disabled} onClick={go}>{button}</button>
      <p className="t-caption muted center">Your wallet signs every transaction. Only you can withdraw your staked $PONDPAD.</p>
    </div>
  );
}

/** Anyone can run the two upkeep calls; each pays the caller a small tip. A keeper does it too (keeper/). */
function Upkeep({ p }: { p: PondState }) {
  const { isConnected } = useAccount();
  const { data: buyReady } = useBuyerReady();
  const { send, pending } = useSend();
  if (!p.canDrip && !buyReady) return null;
  return (
    <div className="pp-notice"><Icon name="pond" /><div className="stack-xs">
      <span><b>Keep the pond flowing.</b> These run by themselves when a keeper is up, but anyone can push them along.</span>
      <div className="row">
        {p.canDrip && <button className="pp-btn pp-btn-sm" disabled={!isConnected || !!pending}
          onClick={() => send([{ address: addr.rewardDripper, abi: RewardDripperAbi as Abi, functionName: 'drip', gasPct: MARKET_GAS_HEADROOM, label: 'Dripping…' }], { ok: 'Dripped into the pond.' }).catch(() => {})}>
          Drip {fmtAmount(p.drippable, 18, { compact: true })} $PONDPAD in (you get {fmtAmount(p.keeperReward)})</button>}
        {buyReady && <button className="pp-btn pp-btn-sm" disabled={!isConnected || !!pending}
          onClick={() => send([{ address: addr.padBuyer, abi: PadBuyerAbi as Abi, functionName: 'buy', gasPct: MARKET_GAS_HEADROOM, label: 'Buying for the pond…' }], { ok: 'Bought $PONDPAD for the pond.' }).catch(() => {})}>
          Buy $PONDPAD for the pond (0.5% tip)</button>}
      </div>
    </div></div>
  );
}
