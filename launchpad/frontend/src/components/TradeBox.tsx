import { useEffect, useState } from 'react';
import { useAccount, useBalance, usePublicClient, useReadContract } from 'wagmi';
import { erc20Abi, formatUnits, type Abi, type PublicClient } from 'viem';
import { BondingCurveAbi, PadHookAbi, PadRouterAbi } from '../abi';
import { addr, BASE_FEE_BPS, ETH, PAY_TOKENS, type PayToken } from '../config';
import type { CoinView } from '../lib/chain';
import { fmtAmount, fmtBps, parseAmount } from '../lib/format';
import { useQuote } from '../lib/quote';
import { approveIfNeeded, useSend, type Call } from '../lib/tx';
import { Icon } from './Icons';

// Router ABI plus the curve's and hook's errors, so a revert inside them decodes to a friendly message.
const ROUTER_ABI = [...PadRouterAbi, ...BondingCurveAbi.filter((x) => x.type === 'error'), ...PadHookAbi.filter((x) => x.type === 'error')] as Abi;

function remember<T extends string>(key: string, initial: T): [T, (v: T) => void] {
  const [v, set] = useState<T>(() => { try { return (localStorage.getItem(key) as T) ?? initial; } catch { return initial; } });
  return [v, (x: T) => { set(x); try { localStorage.setItem(key, x); } catch { /* private mode */ } }];
}

export function feeLine(c: CoinView) {
  const parts: string[] = [];
  const tax = c.fees.taxBps;
  if (tax > 0) {
    const to = [
      c.fees.taxToHoldersBps && `${fmtBps((tax * c.fees.taxToHoldersBps) / 10000)} to holders`,
      c.fees.taxToCreatorBps && `${fmtBps((tax * c.fees.taxToCreatorBps) / 10000)} to the creator`,
      c.fees.taxToSwarmBps && `${fmtBps((tax * c.fees.taxToSwarmBps) / 10000)} to the swarm budget`,
    ].filter(Boolean);
    parts.push(...(to as string[]));
  }
  return `${fmtBps(c.totalFeeBps)} (${fmtBps(BASE_FEE_BPS)} base${parts.length ? ' + ' + parts.join(' + ') : ''})`;
}

export function TradeBox({ coin, initialSide = 'buy' }: { coin: CoinView; initialSide?: 'buy' | 'sell' }) {
  const { address, isConnected } = useAccount();
  const pc = usePublicClient() as PublicClient;
  const [side, setSide] = useState<'buy' | 'sell'>(initialSide);
  const [paySym, setPaySym] = remember<PayToken['symbol']>('pp-pay', 'IMD');
  const [slip, setSlip] = remember<string>('pp-slippage', '1');
  const [text, setText] = useState('');
  const pay = PAY_TOKENS.find((t) => t.symbol === paySym) ?? PAY_TOKENS[0];
  const inDecimals = side === 'buy' ? pay.decimals : 18;
  const amount = parseAmount(text, inDecimals);
  const { data: q, isFetching, error: qErr } = useQuote(coin.coin, side, pay, amount, coin.priceE18);
  const { send, pending } = useSend();
  useEffect(() => setText(''), [side, paySym]);

  const ethBal = useBalance({ address, query: { enabled: !!address } });
  const tokBal = useReadContract({ address: pay.address === ETH ? addr.imd : pay.address, abi: erc20Abi, functionName: 'balanceOf', args: [address!], query: { enabled: !!address && pay.address !== ETH } });
  const coinBal = useReadContract({ address: coin.coin, abi: erc20Abi, functionName: 'balanceOf', args: [address!], query: { enabled: !!address } });
  const balance = side === 'sell' ? coinBal.data : pay.address === ETH ? ethBal.data?.value : tokBal.data;

  const slipBps = Math.round(Math.min(Math.max(Number(slip) || 1, 0.1), 50) * 100);
  const minOut = q ? (q.out * BigInt(10000 - slipBps)) / 10000n : 0n;
  const outSym = side === 'buy' ? `$${coin.symbol}` : pay.symbol;
  const outDecimals = side === 'buy' ? 18 : pay.decimals;
  const over = amount !== undefined && balance !== undefined && amount > balance;
  const route = side === 'buy'
    ? `${pay.symbol}${pay.symbol === 'IMD' ? '' : pay.symbol === 'USDG' ? ' → ETH → IMD' : ' → IMD'} → $${coin.symbol}`
    : `$${coin.symbol} → IMD${pay.symbol === 'IMD' ? '' : pay.symbol === 'USDG' ? ' → ETH → USDG' : ' → ETH'}`;
  const presets = side === 'sell' ? ['25%', '50%', '100%'] : pay.symbol === 'ETH' ? ['0.01', '0.05', '0.1'] : pay.symbol === 'USDG' ? ['10', '50', '100'] : ['5', '10', '25', '50'];
  const snipe = Number(coin.snipeTaxBps);
  const graduated = coin.status === 3;

  async function go() {
    if (!address || !amount || !q) return;
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 600);
    const calls: (Call & { label: string })[] = [];
    if (side === 'buy') {
      if (pay.address !== ETH) calls.push(...(await approveIfNeeded(pc, pay.address, address, addr.router, amount)));
      calls.push({ address: addr.router, abi: ROUTER_ABI, functionName: 'buyWith', args: [coin.coin, pay.address, amount, minOut, deadline, ETH], value: pay.address === ETH ? amount : undefined, label: 'Buying…' });
      await send(calls, { ok: `Bought ${fmtAmount(q.out)} $${coin.symbol}.` }).catch(() => {});
    } else {
      calls.push(...(await approveIfNeeded(pc, coin.coin, address, addr.router, amount)));
      calls.push({ address: addr.router, abi: ROUTER_ABI, functionName: 'sellFor', args: [coin.coin, pay.address, amount, minOut, deadline, ETH], label: 'Selling…' });
      await send(calls, { ok: `Sold for ${fmtAmount(q.out, pay.decimals)} ${pay.symbol}.` }).catch(() => {});
    }
    setText('');
  }

  let button = side === 'buy' ? `Buy $${coin.symbol}` : `Sell $${coin.symbol}`;
  let disabled = !q || isFetching || !amount;
  if (!isConnected) { button = 'Connect a wallet to hop in'; disabled = true; }
  else if (pending) { button = pending; disabled = true; }
  else if (over) { button = side === 'buy' ? `Not enough ${pay.symbol}` : `Not enough $${coin.symbol}`; disabled = true; }
  else if (q && !q.fullFill) { button = graduated ? 'Too big for the pool right now' : 'The curve is full'; disabled = true; }

  return (
    <div className="pp-trade">
      {snipe > 0 && !graduated && (
        <div className="pp-notice pp-notice-tax"><Icon name="clock" /><div><b>Early-bird tax is {fmtBps(snipe)} right now.</b> It drops to zero in the first seconds after launch, to keep bots honest.</div></div>
      )}
      <div className="pp-seg is-trade" role="group" aria-label="Buy or sell">
        <button data-side="buy" aria-pressed={side === 'buy'} onClick={() => setSide('buy')}>Buy</button>
        <button data-side="sell" aria-pressed={side === 'sell'} onClick={() => setSide('sell')}>Sell</button>
      </div>
      <div className="pp-field">
        <div className="field-head">
          <label htmlFor="trade-amount">{side === 'buy' ? 'You pay' : 'You sell'}</label>
          {balance !== undefined && <span className="t-caption muted">Balance {fmtAmount(balance, inDecimals)} {side === 'buy' ? pay.symbol : `$${coin.symbol}`}</span>}
        </div>
        <div className="pp-amount">
          <input id="trade-amount" inputMode="decimal" autoComplete="off" placeholder="0.0" value={text} onChange={(e) => setText(e.target.value.replace(',', '.'))} />
          <span className="pp-token is-static">{side === 'buy' ? pay.symbol : `$${coin.symbol}`}</span>
        </div>
        <div className="pp-presets">
          {presets.map((p) => (
            <button key={p} onClick={() => {
              if (p.endsWith('%') && balance !== undefined) {
                const v = (balance * BigInt(parseInt(p))) / 100n;
                setText(formatUnits(v, 18));
              } else setText(p);
            }}>{p}</button>
          ))}
        </div>
      </div>
      <div className="pp-field">
        <span className="pp-label">{side === 'buy' ? 'Pay with' : 'Receive'}</span>
        <div className="pp-seg" role="group" aria-label="Payment token">
          {PAY_TOKENS.map((t) => <button key={t.symbol} aria-pressed={t.symbol === pay.symbol} onClick={() => setPaySym(t.symbol)}>{t.symbol}</button>)}
        </div>
      </div>
      <div className="pp-quote" aria-live="polite">
        <div><span>You get (at least)</span><b>{q ? `${fmtAmount(minOut, outDecimals)} ${outSym}` : amount ? (qErr ? 'No quote' : '…') : '–'}</b></div>
        <div><span>Route</span><b>{route}</b></div>
        {q && <div><span>Price impact</span><b className={q.impactBps > 500 ? 'pp-down' : ''}>{(q.impactBps / 100).toFixed(2)}%</b></div>}
        <div><span>Slippage</span><b><input className="slip" id="slippage" aria-label="Slippage percent" inputMode="decimal" value={slip} onChange={(e) => setSlip(e.target.value)} />%</b></div>
        <div className="pp-fee"><span>Fee</span><b>{feeLine(coin)}</b></div>
        {q && q.snipeTax > 0n && <div><span>Early-bird tax</span><b>{fmtAmount(q.snipeTax)} IMD</b></div>}
      </div>
      <button className={`pp-btn pp-btn-block ${side === 'buy' ? 'pp-btn-buy' : 'pp-btn-sell'}`} disabled={disabled} onClick={go}>{button}</button>
      <p className="t-caption muted center">Coins can go to zero. Your wallet signs every transaction.</p>
    </div>
  );
}
