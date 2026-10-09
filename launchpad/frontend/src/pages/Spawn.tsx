import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAccount, usePublicClient } from 'wagmi';
import { parseEventLogs, toHex, type Abi, type PublicClient } from 'viem';
import { BondingCurveAbi, PadFactoryAbi, PadRouterAbi } from '../abi';
import { addr, BASE_FEE_BPS, ETH, PAY_TOKENS, type PayToken } from '../config';
import { useLaunchSettings } from '../lib/chain';
import { fmtAmount, fmtBps, parseAmount } from '../lib/format';
import { inlineMeta, safeUrl } from '../lib/meta';
import { toImd } from '../lib/quote';
import { approveIfNeeded, useSend, type Call } from '../lib/tx';
import { Icon } from '../components/Icons';

const ABI = [...PadRouterAbi, ...PadFactoryAbi.filter((x) => x.type === 'error'), ...BondingCurveAbi.filter((x) => x.type === 'error')] as Abi;

export function Spawn() {
  const { address, isConnected } = useAccount();
  const pc = usePublicClient() as PublicClient;
  const nav = useNavigate();
  const { data: ls } = useLaunchSettings();
  const { send, pending } = useSend();
  const [f, setF] = useState({ name: '', symbol: '', image: '', description: '', website: '', x: '', telegram: '' });
  const [tax, setTax] = useState('0.5');
  const [split, setSplit] = useState({ holders: 100, creator: 0, swarm: 0 });
  const [devBuy, setDevBuy] = useState(false);
  const [devAmt, setDevAmt] = useState('');
  const [paySym, setPaySym] = useState<PayToken['symbol']>('IMD');
  const pay = PAY_TOKENS.find((t) => t.symbol === paySym)!;
  const set = (k: keyof typeof f) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => setF({ ...f, [k]: e.target.value });

  const taxBps = Math.round(Math.min(Math.max(Number(tax) || 0, 0), 3) * 100);
  const splitSum = split.holders + split.creator + split.swarm;
  const launchFee = ls?.settings.launchFee ?? 10n ** 18n;
  const dev = devBuy ? parseAmount(devAmt, pay.decimals) ?? 0n : 0n;
  const problems = useMemo(() => {
    const p: string[] = [];
    if (!f.name.trim() || f.name.length > 32) p.push('Name: 1–32 characters.');
    if (!f.symbol.trim() || f.symbol.length > 12) p.push('Ticker: 1–12 characters.');
    if (f.image && !safeUrl(f.image)) p.push('Image link must start with https:// or ipfs://.');
    for (const k of ['website', 'x', 'telegram'] as const) if (f[k] && !safeUrl(f[k])) p.push(`${k === 'x' ? 'X' : k[0].toUpperCase() + k.slice(1)} link must start with https://.`);
    if (taxBps > 0 && splitSum !== 100) p.push('The tax split must add up to 100%.');
    if (devBuy && dev === 0n) p.push('Enter a dev buy amount or switch it off.');
    return p;
  }, [f, taxBps, splitSum, devBuy, dev]);

  async function spawn() {
    if (!address) return;
    // Amount to pay: the launch fee (converted when paying in ETH or USDG, plus 3% margin; the rest comes back as IMD) and the dev buy.
    let feeIn = launchFee;
    if (pay.address !== addr.imd) {
      const probe = pay.symbol === 'ETH' ? 10n ** 15n : 10n ** 6n;
      const got = await toImd(pc, pay, probe);
      feeIn = (launchFee * probe * 103n) / (got * 100n) + 1n;
    }
    const amountIn = feeIn + dev;
    const minImd = launchFee + (dev > 0n ? ((await toImd(pc, pay, dev)) * 97n) / 100n : 0n);
    const fees = taxBps === 0 ? { taxBps: 0, taxToCreatorBps: 0, taxToHoldersBps: 0, taxToSwarmBps: 0 }
      : { taxBps, taxToCreatorBps: split.creator * 100, taxToHoldersBps: split.holders * 100, taxToSwarmBps: split.swarm * 100 };
    const metadataURI = inlineMeta({ image: safeUrl(f.image), description: f.description.trim() || undefined, website: safeUrl(f.website), x: safeUrl(f.x), telegram: safeUrl(f.telegram) });
    const salt = toHex(crypto.getRandomValues(new Uint8Array(32)));
    const params = { name: f.name.trim(), symbol: f.symbol.trim().replace(/^\$/, ''), metadataURI, feeRecipient: ETH, fees, salt };
    const calls: (Call & { label: string })[] = [];
    if (pay.address !== ETH) calls.push(...(await approveIfNeeded(pc, pay.address, address, addr.router, amountIn)));
    calls.push({ address: addr.router, abi: ABI, functionName: 'launchWith', args: [params, pay.address, amountIn, devBuy && dev > 0n, minImd, 0n, ETH], value: pay.address === ETH ? amountIn : undefined, label: 'Laying your egg…' });
    const hash = await send(calls, { ok: "It's alive. Your tadpole is swimming." }).catch(() => undefined);
    if (!hash) return;
    const r = await pc.getTransactionReceipt({ hash });
    const ev = parseEventLogs({ abi: PadRouterAbi, logs: r.logs, eventName: 'Launched' })[0];
    if (ev) nav(`/c/${ev.args.coin}`);
  }

  const total = `${fmtAmount(launchFee)} IMD launch fee${devBuy && dev > 0n ? ` + ${fmtAmount(dev, pay.decimals)} ${pay.symbol} dev buy` : ''}`;
  return (
    <div className="wrap spawn">
      <div className="stack">
        <header className="stack-xs">
          <h1 className="t-title">Lay an egg</h1>
          <p className="t-lead muted">Takes about a minute. Costs {fmtAmount(launchFee)} IMD, plus gas. You can pay with IMD, ETH or USDG; we swap it in the same transaction.</p>
        </header>
        {ls?.paused && <div className="pp-notice pp-notice-danger"><Icon name="alert" /><div><b>New launches are paused for a moment.</b> Trading still works.</div></div>}

        <section className="panel stack">
          <h2 className="t-heading">Name it</h2>
          <div className="form-grid">
            <div className="pp-field"><label htmlFor="s-name">Name</label><input className="input" id="s-name" maxLength={32} value={f.name} onChange={set('name')} placeholder="What will the pond call it?" /></div>
            <div className="pp-field"><label htmlFor="s-sym">Ticker</label><input className="input" id="s-sym" maxLength={12} value={f.symbol} onChange={set('symbol')} placeholder="Short and loud: 3–6 letters" /></div>
          </div>
          <div className="pp-field"><label htmlFor="s-img">Image link</label><input className="input" id="s-img" value={f.image} onChange={set('image')} placeholder="https://… or ipfs://… (square works best)" />
            <span className="t-caption muted">This is its face forever, so choose well. Image upload comes with the upload service; on the testnet, paste a link.</span></div>
          <div className="pp-field"><label htmlFor="s-desc">Description</label><textarea className="input" id="s-desc" rows={2} maxLength={500} value={f.description} onChange={set('description')} placeholder="One or two lines. Why should anyone care?" /></div>
          <div className="form-grid three">
            <div className="pp-field"><label htmlFor="s-web">Website</label><input className="input" id="s-web" value={f.website} onChange={set('website')} placeholder="https://" /></div>
            <div className="pp-field"><label htmlFor="s-x">X</label><input className="input" id="s-x" value={f.x} onChange={set('x')} placeholder="https://x.com/…" /></div>
            <div className="pp-field"><label htmlFor="s-tg">Telegram</label><input className="input" id="s-tg" value={f.telegram} onChange={set('telegram')} placeholder="https://t.me/…" /></div>
          </div>
        </section>

        <section className="panel stack">
          <h2 className="t-heading">Want a little extra on every trade?</h2>
          <p className="muted">Every coin pays a {fmtBps(BASE_FEE_BPS)} base fee. You can add up to 3% more, and you decide where it goes. You can't change this after launch, and traders see it on every trade. Keep it fair.</p>
          <div className="pp-field"><label htmlFor="s-tax">Coin tax: {fmtBps(taxBps)}</label>
            <input id="s-tax" type="range" min={0} max={3} step={0.1} value={tax} onChange={(e) => setTax(e.target.value)} /></div>
          {taxBps > 0 && (
            <div className="form-grid three">
              {(['holders', 'creator', 'swarm'] as const).map((k) => (
                <div className="pp-field" key={k}><label htmlFor={`s-${k}`}>{k === 'holders' ? 'To holders (IMD dividends)' : k === 'creator' ? 'To you' : 'To the swarm budget'} %</label>
                  <input className="input" id={`s-${k}`} inputMode="numeric" value={split[k]} onChange={(e) => setSplit({ ...split, [k]: Math.max(0, Math.min(100, parseInt(e.target.value) || 0)) })} /></div>
              ))}
            </div>
          )}
        </section>

        <section className="panel stack">
          <h2 className="t-heading">Buy first?</h2>
          <label className="check"><input type="checkbox" checked={devBuy} onChange={(e) => setDevBuy(e.target.checked)} /> <span>Grab some of your own coin in the same transaction, before any bot can. Skips the early-bird tax.</span></label>
          {devBuy && <div className="pp-field"><label htmlFor="s-dev">Dev buy amount ({pay.symbol})</label><div className="pp-amount"><input id="s-dev" inputMode="decimal" value={devAmt} onChange={(e) => setDevAmt(e.target.value)} placeholder="0.0" /><span className="pp-token is-static">{pay.symbol}</span></div></div>}
        </section>
      </div>

      <aside className="spawn-side">
        <div className="pp-trade">
          <h2 className="t-label muted">Summary</h2>
          <div className="pp-field"><span className="pp-label">Pay with</span>
            <div className="pp-seg" role="group" aria-label="Pay with">{PAY_TOKENS.map((t) => <button key={t.symbol} aria-pressed={t.symbol === paySym} onClick={() => setPaySym(t.symbol)}>{t.symbol}</button>)}</div></div>
          <div className="pp-quote">
            <div><span>You pay</span><b>{total}</b></div>
            <div><span>Paid with</span><b>{pay.symbol}{pay.symbol !== 'IMD' ? ' (swapped to IMD)' : ''}</b></div>
            <div className="pp-fee"><span>Traders will pay</span><b>{fmtBps(BASE_FEE_BPS + taxBps)} per trade</b></div>
            <div><span>Graduates at</span><b>{fmtAmount(ls?.settings.graduationTarget)} IMD</b></div>
          </div>
          {problems.length > 0 && f.name && <ul className="problems">{problems.map((p) => <li key={p}>{p}</li>)}</ul>}
          <button className="pp-btn pp-btn-primary pp-btn-block" disabled={!isConnected || problems.length > 0 || !!pending || ls?.paused} onClick={spawn}>
            {!isConnected ? 'Connect a wallet to spawn' : pending ?? 'Spawn it'}
          </button>
          <p className="t-caption muted center">Website add-on (5 IMD) arrives with the Swarm Relay. Every coin that makes the Leap gets one free.</p>
        </div>
      </aside>
    </div>
  );
}
