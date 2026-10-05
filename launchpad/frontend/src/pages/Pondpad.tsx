import { useEffect, useMemo, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { useQueryClient } from '@tanstack/react-query';
import { useAccount, useSignTypedData } from 'wagmi';
import { isAddress, type Abi, type Address, type Hex } from 'viem';
import { AirdropDistributorAbi } from '../abi';
import { addr, chain, explorerAddr, explorerTx } from '../config';
import { fmtAmount, shortAddr } from '../lib/format';
import { useSend } from '../lib/tx';
import { useToast } from '../components/Toasts';
import { LeapMeter } from '../components/CoinBits';
import { Icon } from '../components/Icons';
import { MarketTradeBox, SaleTradeBox } from '../components/PondpadTrade';
import {
  AIRDROP_NEEDED, AIRDROP_VESTING, AIRDROP_WINDOW, decodeHandover, delegateTypedData, encodeHandover, initiationPost,
  MARKET_FEE_DECAY, previewSale, SALE, SALE_STATUS, saleSnipeBps, TWEET_CHECKER_URL, useAirdrop, useClaims, useMarket,
  useSale, useSaleTrades, type AirdropState, type SaleState,
} from '../lib/pondpad';

// $PONDPAD: one address, three phases (Pages.md): before the sale → sale live → the market after the Leap,
// with the airdrop (wake, then claim) once the market is open. On the testnet the sale has already leapt, so a
// preview switch shows the earlier phases with the sale's own math (D-72).

type Phase = 'before' | 'sale' | 'market';
type Preview = 'live' | 'before' | 'sale' | 'wake';

function useNow(ms = 1000) {
  const [now, setNow] = useState(() => Date.now() / 1000);
  useEffect(() => { const t = setInterval(() => setNow(Date.now() / 1000), ms); return () => clearInterval(t); }, [ms]);
  return now;
}
function countdown(seconds: number) {
  const s = Math.max(0, Math.floor(seconds));
  const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
  return d > 0 ? `${d}d ${h}h ${m}m` : h > 0 ? `${h}h ${m}m ${sec}s` : `${m}m ${String(sec).padStart(2, '0')}s`;
}
const day = (t: number) => new Date(t * 1000).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' });

function Stat({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return <div className="pp-stat"><span>{label}</span><b>{value}</b>{sub && <small>{sub}</small>}</div>;
}

const SPLIT = [
  ['60%', 'sold on the curve (this sale)'],
  ['30%', 'into the pool at the Leap, locked'],
  ['5%', 'airdropped to the IMD community: 70% to active IMD workers, 30% to IMD holders with at least 7,000 IMD'],
  ['3%', 'kept for adding liquidity later (48 h timelock)'],
  ['2%', 'team: nothing for the first month after the Leap, fully released by month 6'],
];

export function Pondpad() {
  const { data: liveSale } = useSale();
  const { data: market } = useMarket();
  const [preview, setPreview] = useState<Preview>('live');
  const now = useNow();

  // The preview sale sits at 63% of the real target, opened 12 minutes ago (early-bird tax still on).
  const [previewStart] = useState(() => Math.floor(Date.now() / 1000) - 12 * 60);
  const sale: SaleState | undefined = useMemo(() => {
    if (!liveSale) return undefined;
    if (preview === 'sale') return previewSale(liveSale.target, 0.63, previewStart);
    if (preview === 'before') return { ...previewSale(liveSale.target, 0, previewStart + 2 * 3600 + 12 * 60), status: SALE_STATUS.Trading };
    return liveSale;
  }, [liveSale, preview, previewStart]);

  if (!sale || !market) return <div className="wrap"><div className="skeleton" style={{ height: 320, borderRadius: 22 }} /></div>;

  const phase: Phase = preview === 'wake' ? 'market'
    : sale.status === SALE_STATUS.Graduated ? 'market'
    : sale.status === SALE_STATUS.Unfunded || now < sale.startTime ? 'before' : 'sale';

  return (
    <div className="wrap stack-lg">
      {chain.testnet && (
        <div className="preview-bar" role="group" aria-label="Preview a phase">
          <span className="t-caption muted">Testnet: the sale already leapt. Preview another phase:</span>
          <div className="pp-seg">
            {([['live', 'Live'], ['before', 'Before'], ['sale', 'Sale'], ['wake', 'Wake']] as [Preview, string][]).map(([k, l]) => (
              <button key={k} aria-pressed={preview === k} onClick={() => setPreview(k)}>{l}</button>
            ))}
          </div>
        </div>
      )}

      <header className="stack-xs pondpad-head">
        <div className="row"><h1 className="t-title">$PONDPAD</h1><span className="pp-badge pp-badge-tax">{phase === 'before' ? 'Opens soon' : phase === 'sale' ? 'Sale live' : 'Leapt'}</span></div>
        {phase === 'market'
          ? <p className="t-lead">$PONDPAD has leapt into its own pool. Part of every trade on PondPad buys it for the Pond, and the pool burns part of every big sell.</p>
          : <p className="t-lead">Get in early, the fair way. No presale, no VCs, no whitelist. $PONDPAD sells on a bonding curve, the same way every coin here starts. The earlier you buy, the cheaper it is. When the curve fills (about {fmtAmount(sale.target)} IMD), it leaps into its own pool, and that pool burns part of every sell.</p>}
      </header>

      {phase === 'before' && <Before sale={sale} now={now} />}
      {phase === 'sale' && <SaleLive sale={sale} now={now} />}
      {phase === 'market' && <Market />}
      {phase === 'market' && market.open && <Airdrop preview={preview === 'wake'} />}
      {phase !== 'market' && <ListChecker />}

      <section className="stack">
        <h2 className="t-heading">Where the 1,000,000,000 $PONDPAD go</h2>
        <ul className="split-list">{SPLIT.map(([p, t]) => <li key={p}><b>{p}</b><span>{t}</span></li>)}</ul>
        <dl className="facts">
          <div><dt>Token</dt><dd><a className="mono" href={explorerAddr(addr.pondpad)} target="_blank" rel="noreferrer">{addr.pondpad}</a> · fixed supply, no owner, no mint</dd></div>
          <div><dt>Sale</dt><dd><a className="mono" href={explorerAddr(addr.sale)} target="_blank" rel="noreferrer">{shortAddr(addr.sale)}</a> · 1% fee, early-bird tax 80% → 0 over 30 minutes, 15M per wallet for the whole sale</dd></div>
          <div><dt>Market</dt><dd><a className="mono" href={explorerAddr(addr.marketHook)} target="_blank" rel="noreferrer">{shortAddr(addr.marketHook)}</a> · fee 3% → 1% over 7 days, cap and burn, liquidity can't be withdrawn</dd></div>
        </dl>
        <p className="t-caption muted">More in the docs: <Link to="/docs/pondpad-sale">The sale</Link> · <Link to="/docs/pondpad-market">The market</Link> · <Link to="/docs/airdrop">The airdrop</Link> · <Link to="/docs/fees">Fees and where they go</Link> · <Link to="/docs/admin">What we can and can never change</Link> · <Link to="/docs/risks">Risks</Link></p>
      </section>
    </div>
  );
}

function Before({ sale, now }: { sale: SaleState; now: number }) {
  return (
    <section className="phase-grid">
      <div className="panel stack center-text">
        <span className="t-label muted">The sale opens in</span>
        <div className="countdown" aria-live="off">{countdown(sale.startTime - now)}</div>
        <span className="t-caption muted">{day(sale.startTime)} · your time</span>
      </div>
      <div className="stack-xs">
        <h2 className="t-heading">How the sale works</h2>
        <ul className="plain-list">
          <li>Buy with IMD, ETH or USDG. The price rises as the curve fills, and you can sell back anytime before the Leap.</li>
          <li>The first 30 minutes carry an early-bird tax that starts at 80% and falls to zero, so bots don't get the cheapest tokens. The tax goes to growth.</li>
          <li>Each wallet can buy up to 15,000,000 $PONDPAD over the whole sale. Selling doesn't free up room.</li>
          <li>At {fmtAmount(sale.target)} IMD the curve is full: the IMD it raised and 300M $PONDPAD open the market in the same transaction, at the curve's last price.</li>
        </ul>
      </div>
    </section>
  );
}

function SaleLive({ sale, now }: { sale: SaleState; now: number }) {
  const { data: trades } = useSaleTrades();
  const tax = sale.preview ? saleSnipeBps(sale, now) : sale.snipeBps;
  const taxEnds = sale.startTime + SALE.snipeDuration;
  const buyers = useMemo(() => new Set((trades ?? []).filter((t) => t.isBuy).map((t) => t.trader.toLowerCase())).size, [trades]);
  return (
    <section className="coin-grid">
      <div className="stack" style={{ minWidth: 0 }}>
        <LeapMeter raised={sale.raised} target={sale.target} />
        <div className="pp-stats">
          <Stat label="Price now" value={`${fmtAmount(sale.priceE18 * 1_000_000n)} IMD`} sub="per 1M $PONDPAD" />
          <Stat label="Sold" value={`${fmtAmount(sale.sold, 18, { compact: true })}`} sub="of 600M on the curve" />
          <Stat label="Buyers so far" value={sale.preview ? '–' : String(buyers)} />
          {sale.remaining !== undefined && <Stat label="Your limit left" value={fmtAmount(sale.remaining, 18, { compact: true })} sub="of 15M; sells don't free it" />}
        </div>
        {tax > 0 && (
          <div className="pp-notice pp-notice-tax"><Icon name="clock" /><div><b>Early-bird tax is {(tax / 100).toFixed(1)}% right now.</b> It falls to zero in {countdown(taxEnds - now)}. Waiting is cheaper; the tax goes to growth.</div></div>
        )}
        {!sale.preview && (
          <div className="table-wrap"><table className="table">
            <thead><tr><th>Wallet</th><th>Side</th><th className="num">IMD</th><th className="num">$PONDPAD</th><th>Tx</th></tr></thead>
            <tbody>{[...(trades ?? [])].reverse().slice(0, 20).map((t) => (
              <tr key={t.key}>
                <td><Link className="mono" to={`/u/${t.trader}`}>{shortAddr(t.trader)}</Link></td>
                <td className={t.isBuy ? 'pp-up' : 'pp-down'}>{t.isBuy ? 'Buy' : 'Sell'}</td>
                <td className="num">{fmtAmount(t.imd)}</td><td className="num">{fmtAmount(t.tokens, 18, { compact: true })}</td>
                <td><a href={explorerTx(t.tx)} target="_blank" rel="noreferrer">View</a></td>
              </tr>))}
              {!trades?.length && <tr><td colSpan={5} className="muted">No trades yet. Be the first.</td></tr>}
            </tbody>
          </table></div>
        )}
      </div>
      <aside className="stack coin-side pondpad-side"><SaleTradeBox sale={sale} /></aside>
    </section>
  );
}

function Market() {
  const { data: m } = useMarket();
  const now = useNow(10_000);
  if (!m) return null;
  const daysLeft = Math.max(0, (m.openedAt + MARKET_FEE_DECAY - now) / 86400);
  const overCap = m.tokensInPool > m.inventoryCap;
  return (
    <section className="coin-grid">
      <div className="stack" style={{ minWidth: 0 }}>
        <div className="pp-stats">
          <Stat label="Price now" value={`${fmtAmount(m.priceE18 * 1_000_000n)} IMD`} sub="per 1M $PONDPAD" />
          <Stat label="Fee today" value={`${(m.feePips / 10_000).toFixed(2)}%`} sub={daysLeft > 0 ? `1% in ${daysLeft.toFixed(1)} days` : 'settled at 1%'} />
          <Stat label="Burned so far" value={fmtAmount(m.burnedSupply, 18, { compact: true })} sub="$PONDPAD, gone for good" />
          <Stat label="To the Pond" value={fmtAmount(m.totalRewarded, 18, { compact: true })} sub="$PONDPAD from trims" />
        </div>
        <p className="burn-line">Sell into the pool and part of it never comes back. <b>{fmtAmount(m.burnedSupply)} $PONDPAD burned so far.</b></p>
        <div className="explain">
          <div className="stack-xs">
            <h3 className="t-label">The cap</h3>
            <p>The pool may only hold so much $PONDPAD: the cap, now <b>{fmtAmount(m.inventoryCap, 18, { compact: true })}</b> (the pool holds {fmtAmount(m.tokensInPool, 18, { compact: true })}). When sells push it above the cap, the extra is trimmed: 85% is burned and 15% goes to the Pond. Buys lower the cap, by at most 500,000 a day, never below 150M. So burns start only once sells push the pool above where it opened.{overCap ? ' Right now the pool is above its cap: the next swap trims it.' : ''}</p>
          </div>
          <div className="stack-xs">
            <h3 className="t-label">The backstop</h3>
            <p>The IMD from trims ({fmtAmount(m.backstopQuote)} IMD waiting now) goes back into the pool as a buy wall a little above the price, placed by anyone who calls the public rebalance. When sellers fill it, the $PONDPAD it bought is burned and shared the same way.</p>
          </div>
          <div className="stack-xs">
            <h3 className="t-label">The fee</h3>
            <p>3% when the market opened, falling evenly to 1% at day 7, then 1% for good. It's split like every protocol fee: 40% to the Pond, 25% to IMD workers, 20% growth, 15% treasury.</p>
          </div>
        </div>
      </div>
      <aside className="stack coin-side pondpad-side"><MarketTradeBox market={m} /></aside>
    </section>
  );
}

function ListChecker() {
  const { data: claims, isError } = useClaims();
  const { address } = useAccount();
  const [text, setText] = useState('');
  const who = text.trim() || address || '';
  const entry = isAddress(who) ? claims?.byAddr.get(who.toLowerCase()) : undefined;
  return (
    <section className="panel stack-xs">
      <h2 className="t-heading">Am I on the airdrop list?</h2>
      <p className="muted">5% of $PONDPAD goes to the IMD community. The snapshot is taken in secret and announced only after it's taken. After the Leap, 100 wallets from the list wake the airdrop, then everyone on it claims over 30 days.</p>
      <div className="row">
        <div className="pp-amount checker"><input aria-label="Wallet address" placeholder={address ?? '0x… wallet address'} value={text} onChange={(e) => setText(e.target.value)} /></div>
      </div>
      {isError || !claims ? <p className="t-caption muted">The list isn't published yet.</p>
        : !isAddress(who) ? <p className="t-caption muted">Paste a wallet address, or connect one.</p>
        : entry ? <p><b className="pp-up">On the list:</b> {fmtAmount(entry.amount)} $PONDPAD.</p>
        : <p className="muted">Not on this list. {chain.testnet ? 'On the testnet the list is 104 test wallets.' : ''}</p>}
    </section>
  );
}

function Airdrop({ preview }: { preview: boolean }) {
  const { data: live } = useAirdrop();
  const { data: claims } = useClaims();
  if (!live || !claims) return null;
  const a: AirdropState = preview ? { ...live, count: 63, activatedAt: 0, me: live.me && { ...live.me, initiated: false } } : live;
  return a.activatedAt === 0 ? <Wake a={a} preview={preview} /> : <Claim a={a} />;
}

function Wake({ a, preview }: { a: AirdropState; preview: boolean }) {
  const { address } = useAccount();
  const [tweet, setTweet] = useState('');
  const { send, pending } = useSend();
  const toast = useToast();
  const me = a.me;
  const post = me ? initiationPost(me.code) : undefined;

  async function wake() {
    if (!me || !TWEET_CHECKER_URL) return;
    try {
      const res = await fetch(`${TWEET_CHECKER_URL.replace(/\/$/, '')}/voucher`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ account: me.account, tweetUrl: tweet.trim() }) });
      if (!res.ok) throw new Error(await res.text());
      const v = (await res.json()) as { handleHash: Hex; tweetHash: Hex; deadline: string; voucher: Hex };
      await send([{ address: a.distributor, abi: AirdropDistributorAbi as Abi, functionName: 'initiate', args: [me.account, me.amount, me.proof, v.handleHash, v.tweetHash, BigInt(v.deadline), v.voucher], label: 'Waking…' }], { ok: 'You croaked. One more frog awake.' });
    } catch (e) {
      if (e instanceof Error && !/reverted|rejected|denied/i.test(e.message)) toast({ kind: 'error', text: `The tweet checker couldn't confirm that post. ${e.message.slice(0, 120)}` });
    }
  }

  return (
    <section className="panel stack airdrop">
      <div className="airdrop-head">
        <img src="./pip.svg" alt="" width={88} height={88} />
        <div className="stack-xs">
          <h2 className="t-heading">Wake the pond</h2>
          <p>The airdrop sleeps until 100 wallets from the snapshot wake it up. Post the line below on X with your code, paste the link, and sign with the wallet that's on the list. When the 100th frog croaks, everyone on the list can claim, not just the 100.</p>
        </div>
      </div>
      <div className="stack-xs">
        <div className="pp-leap" role="progressbar" aria-valuenow={a.count} aria-valuemin={0} aria-valuemax={AIRDROP_NEEDED} aria-label="Frogs awake">
          <div className="pp-leap-track"><div className="pp-leap-fill" style={{ width: `${(a.count / AIRDROP_NEEDED) * 100}%` }} /></div>
          <div className="pp-leap-row"><span><b>{a.count} / {AIRDROP_NEEDED}</b> frogs awake</span><span>{preview ? 'Preview' : ''}</span></div>
        </div>
      </div>
      {!address ? <p className="muted">Connect the wallet that's on the list to get your code.</p>
        : !me ? <p className="muted">{shortAddr(address)} isn't on the list. Anyone on it can wake the pond; you can still watch the count.</p>
        : me.initiated ? <p><b className="pp-up">You're awake.</b> Your post counted. Now we wait for the rest of the pond.</p>
        : (
          <div className="stack-xs">
            <span className="t-label">1. Post this on X</span>
            <div className="post"><span>{post}</span><button className="pp-btn pp-btn-sm" onClick={() => navigator.clipboard?.writeText(post!).catch(() => {})}><Icon name="copy" size={14} />Copy</button>
              <a className="pp-btn pp-btn-sm" href={`https://x.com/intent/post?text=${encodeURIComponent(post!)}`} target="_blank" rel="noreferrer"><Icon name="x" size={14} />Post</a></div>
            <span className="t-caption muted">Your code <span className="mono">{me.code.slice(2)}</span> is tied to your wallet, so anyone can check it. One X account per wallet.</span>
            <label className="t-label" htmlFor="tweet-link">2. Paste the link to your post</label>
            <div className="pp-amount"><input id="tweet-link" placeholder="https://x.com/you/status/…" value={tweet} onChange={(e) => setTweet(e.target.value)} /></div>
            <button className="pp-btn pp-btn-leap" disabled={preview || !TWEET_CHECKER_URL || !/^https:\/\/(x|twitter)\.com\/[^/]+\/status\/\d+/.test(tweet.trim()) || !!pending} onClick={wake}>{pending ?? '3. Sign and wake the pond'}</button>
            {!TWEET_CHECKER_URL && <p className="t-caption muted">The tweet checker isn't running yet, so posts can't be confirmed here.</p>}
          </div>
        )}
    </section>
  );
}

function Claim({ a }: { a: AirdropState }) {
  const { address } = useAccount();
  const [params, setParams] = useSearchParams();
  const handover = decodeHandover(params.get('handover'));
  const { send, pending } = useSend();
  const [claimed, setClaimed] = useState(false);
  const [justSet, setJustSet] = useState<Address>();
  const qc = useQueryClient();
  const deadline = a.activatedAt + AIRDROP_WINDOW;
  const fullyAt = a.activatedAt + AIRDROP_VESTING;
  const share = `https://x.com/intent/post?text=${encodeURIComponent('Just claimed my $PondPad airdrop 🐸 Every frog starts as a tadpole. pondpad.fun')}`;
  const ok = () => setClaimed(true);

  const claimFor = (account: Address, amount: bigint, proof: Hex[]) =>
    send([{ address: a.distributor, abi: AirdropDistributorAbi as Abi, functionName: 'claim', args: [account, amount, proof], label: 'Claiming…' }], { ok: 'Claimed. It’s in your wallet.' }).then(ok).catch(() => {});

  return (
    <section className="panel stack airdrop">
      <div className="airdrop-head">
        <img src="./pip.svg" alt="" width={88} height={88} />
        <div className="stack-xs">
          <h2 className="t-heading">The pond is awake</h2>
          <p>Your share unlocks a little every day for 30 days. Claim as often as you like. Unclaimed tokens go to the Pond (stakers) 180 days after the airdrop woke up.</p>
          <p className="t-caption muted">Woke {day(a.activatedAt)} · fully unlocked {day(fullyAt)} · claims close {day(deadline)} · {fmtAmount(a.totalClaimed, 18, { compact: true })} claimed so far</p>
        </div>
      </div>

      {handover && <HandoverClaim a={a} h={handover} onDone={() => {
        // The RPC can index the new ClaimWalletSet log a few seconds after the receipt: say so, then look again.
        ok(); setJustSet(handover.account); params.delete('handover'); setParams(params);
        setTimeout(() => qc.invalidateQueries({ queryKey: ['airdrop'] }), 6000);
      }} />}
      {justSet && !a.delegators.some((d) => d.account.toLowerCase() === justSet.toLowerCase()) && (
        <p><b className="pp-up">This wallet now claims for {shortAddr(justSet)}.</b> Its airdrop shows here in a moment.</p>)}

      {!address ? <p className="muted">Connect the wallet that's on the list, or its claim wallet.</p>
        : a.me ? (
          <div className="stack-xs">
            <Position amount={a.me.amount} vested={a.me.vested} claimed={a.me.claimed} claimable={a.me.claimable} />
            {a.me.claimWallet.toLowerCase() !== a.me.account.toLowerCase() && <p className="t-caption muted">Claims go to your claim wallet {shortAddr(a.me.claimWallet)}.</p>}
            <div className="row">
              <button className="pp-btn pp-btn-leap" disabled={!a.me.claimable || !!pending} onClick={() => claimFor(a.me!.account, a.me!.amount, a.me!.proof)}>{pending ?? `Claim ${fmtAmount(a.me.claimable)} $PONDPAD`}</button>
              {claimed && <a className="pp-btn" href={share} target="_blank" rel="noreferrer"><Icon name="x" size={14} />Share on X</a>}
            </div>
            <ClaimWalletSigner a={a} />
          </div>
        )
        : a.delegators.length ? a.delegators.map((d) => (
          <div className="stack-xs" key={d.account}>
            <p>You're the claim wallet for <span className="mono">{shortAddr(d.account)}</span>.</p>
            <Position amount={d.amount} vested={d.vested} claimed={d.claimed} claimable={d.claimable} />
            <button className="pp-btn pp-btn-leap" disabled={!d.claimable || !!pending} onClick={() => claimFor(d.account, d.amount, d.proof)}>{pending ?? `Claim ${fmtAmount(d.claimable)} $PONDPAD`}</button>
          </div>
        ))
        : !handover && !justSet && <p className="muted">{shortAddr(address)} isn't on the list and isn't anyone's claim wallet.</p>}
    </section>
  );
}

function Position({ amount, vested, claimed, claimable }: { amount: bigint; vested: bigint; claimed: bigint; claimable: bigint }) {
  return (
    <div className="pp-quote">
      <div><span>Your airdrop</span><b>{fmtAmount(amount)} $PONDPAD</b></div>
      <div><span>Unlocked so far</span><b>{fmtAmount(vested)} ({amount ? ((Number((vested * 10000n) / amount) / 100).toFixed(1)) : 0}%)</b></div>
      <div><span>Claimed</span><b>{fmtAmount(claimed)}</b></div>
      <div><span>Ready to claim</span><b>{fmtAmount(claimable)}</b></div>
    </div>
  );
}

/** The listed wallet names a claim wallet with one signature (no gas); the claim wallet opens the link and claims. */
function ClaimWalletSigner({ a }: { a: AirdropState }) {
  const [open, setOpen] = useState(false);
  const [to, setTo] = useState('');
  const [link, setLink] = useState('');
  const { signTypedDataAsync, isPending } = useSignTypedData();
  const toast = useToast();
  const me = a.me!;
  async function sign() {
    if (!isAddress(to)) return;
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 7 * 86400);
    try {
      const signature = await signTypedDataAsync(delegateTypedData(a.distributor, me.account, to as Address, me.nonce, deadline));
      const h = encodeHandover({ account: me.account, claimWallet: to as Address, deadline: deadline.toString(), signature });
      setLink(`${location.origin}${location.pathname}#/pondpad?handover=${h}`);
    } catch {
      toast({ kind: 'error', text: 'You cancelled it in your wallet. Nothing was signed.' });
    }
  }
  if (!open) return <button className="linkish" onClick={() => setOpen(true)}>Want to keep this wallet off the trading side? Name a claim wallet with one signature, no gas.</button>;
  return (
    <div className="stack-xs subpanel">
      <label className="t-label" htmlFor="claim-wallet">Claim wallet</label>
      <div className="pp-amount"><input id="claim-wallet" placeholder="0x… the wallet that will claim and receive" value={to} onChange={(e) => setTo(e.target.value.trim())} /></div>
      <button className="pp-btn pp-btn-sm" disabled={!isAddress(to) || to.toLowerCase() === me.account.toLowerCase() || isPending} onClick={sign}>{isPending ? 'Signing…' : 'Sign'}</button>
      {link && (
        <div className="stack-xs">
          <p className="t-caption">Open this link with the claim wallet connected. It works for 7 days, and only for {shortAddr(to)}.</p>
          <div className="post"><span className="mono">{link.slice(0, 64)}…</span><button className="pp-btn pp-btn-sm" onClick={() => navigator.clipboard?.writeText(link).catch(() => {})}><Icon name="copy" size={14} />Copy link</button></div>
        </div>
      )}
    </div>
  );
}

function HandoverClaim({ a, h, onDone }: { a: AirdropState; h: ReturnType<typeof decodeHandover> & object; onDone: () => void }) {
  const { address } = useAccount();
  const { data: claims } = useClaims();
  const { send, pending } = useSend();
  const entry = claims?.byAddr.get(h.account.toLowerCase());
  const mine = address?.toLowerCase() === h.claimWallet.toLowerCase();
  const expired = Number(h.deadline) < Date.now() / 1000;
  return (
    <div className="pp-notice pp-notice-chorus"><Icon name="info" /><div className="stack-xs">
      <b>{shortAddr(h.account)} named {shortAddr(h.claimWallet)} as its claim wallet.</b>
      {!entry ? <span>That wallet isn't on the list.</span>
        : expired ? <span>This link has expired. Ask for a new signature.</span>
        : !mine ? <span>Connect {shortAddr(h.claimWallet)} to claim with it.</span>
        : <button className="pp-btn pp-btn-leap pp-btn-sm" disabled={!!pending} onClick={() => send([{ address: a.distributor, abi: AirdropDistributorAbi as Abi, functionName: 'setClaimWalletAndClaim', args: [h.account, BigInt(h.deadline), h.signature, entry.amount, entry.proof], label: 'Claiming…' }], { ok: 'Claim wallet set and claimed.' }).then(onDone).catch(() => {})}>{pending ?? 'Set this wallet and claim'}</button>}
    </div></div>
  );
}
