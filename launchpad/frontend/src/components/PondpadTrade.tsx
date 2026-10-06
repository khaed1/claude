import { useEffect, useState } from 'react';
import { useAccount, useBalance, usePublicClient, useReadContract } from 'wagmi';
import { useQuery } from '@tanstack/react-query';
import { erc20Abi, formatUnits, type Abi, type PublicClient } from 'viem';
import { PadSaleAbi, UniversalRouterAbi } from '../abi';
import { addr, ETH, MARKET_GAS_HEADROOM, PAY_TOKENS, UNIVERSAL_ROUTER, type PayToken } from '../config';
import { fmtAmount, parseAmount } from '../lib/format';
import { fromImd, toImd } from '../lib/quote';
import { approveIfNeeded, approveViaPermit2, useSend, type Call } from '../lib/tx';
import { marketRoute, marketSwapArgs, quoteMarket, saleQuoteBuy, saleQuoteSell, type MarketState, type SaleState } from '../lib/pondpad';

// Trade boxes for $PONDPAD: the sale curve (IMD / ETH / USDG, gold button) and, after the Leap, the market pool.

function remember<T extends string>(key: string, initial: T): [T, (v: T) => void] {
  const [v, set] = useState<T>(() => { try { return (localStorage.getItem(key) as T) ?? initial; } catch { return initial; } });
  return [v, (x: T) => { set(x); try { localStorage.setItem(key, x); } catch { /* private mode */ } }];
}

function Amount({ id, label, text, setText, balance, unit, decimals, presets }: {
  id: string; label: string; text: string; setText: (s: string) => void; balance?: bigint; unit: string; decimals: number; presets: string[];
}) {
  return (
    <div className="pp-field">
      <div className="field-head">
        <label htmlFor={id}>{label}</label>
        {balance !== undefined && <span className="t-caption muted">Balance {fmtAmount(balance, decimals)} {unit}</span>}
      </div>
      <div className="pp-amount">
        <input id={id} inputMode="decimal" autoComplete="off" placeholder="0.0" value={text} onChange={(e) => setText(e.target.value.replace(',', '.'))} />
        <span className="pp-token is-static">{unit}</span>
      </div>
      <div className="pp-presets">
        {presets.map((p) => (
          <button key={p} onClick={() => {
            if (p.endsWith('%') && balance !== undefined) setText(formatUnits((balance * BigInt(parseInt(p))) / 100n, decimals));
            else setText(p);
          }}>{p}</button>
        ))}
      </div>
    </div>
  );
}

function Slippage({ slip, setSlip }: { slip: string; setSlip: (s: string) => void }) {
  return <div><span>Slippage</span><b><input className="slip" aria-label="Slippage percent" inputMode="decimal" value={slip} onChange={(e) => setSlip(e.target.value)} />%</b></div>;
}
const slipOf = (slip: string) => Math.round(Math.min(Math.max(Number(slip) || 1, 0.1), 50) * 100);

/** The sale: buy or sell $PONDPAD on its curve with IMD, ETH or USDG. */
export function SaleTradeBox({ sale }: { sale: SaleState }) {
  const { address, isConnected } = useAccount();
  const pc = usePublicClient() as PublicClient;
  const [side, setSide] = useState<'buy' | 'sell'>('buy');
  const [paySym, setPaySym] = remember<PayToken['symbol']>('pp-pay', 'IMD');
  const [slip, setSlip] = remember<string>('pp-slippage', '1');
  const [text, setText] = useState('');
  const pay = PAY_TOKENS.find((t) => t.symbol === paySym) ?? PAY_TOKENS[0];
  const inDecimals = side === 'buy' ? pay.decimals : 18;
  const amount = parseAmount(text, inDecimals);
  const { send, pending } = useSend();
  useEffect(() => setText(''), [side, paySym]);

  // Live: PadSale's own quotes (after converting ETH / USDG along PadConfig's route). Preview: the same math locally.
  const { data: q, isFetching, error: qErr } = useQuery({
    queryKey: ['saleQuote', side, pay.symbol, amount?.toString(), sale.preview, sale.raised.toString()],
    enabled: !!amount && amount > 0n,
    refetchInterval: 10_000,
    retry: false,
    queryFn: async () => {
      if (side === 'buy') {
        const imd = sale.preview ? amount! : await toImd(pc, pay, amount!);
        if (sale.preview) { const r = saleQuoteBuy(sale, imd); return { out: r.out, fee: r.fee, snipe: r.snipe, imd }; }
        const [out, fee, snipe] = await pc.readContract({ address: addr.sale, abi: PadSaleAbi, functionName: 'quoteBuy', args: [imd] });
        return { out, fee, snipe, imd };
      }
      if (sale.preview) { const r = saleQuoteSell(sale, amount!); return { out: r.out, fee: r.fee, snipe: 0n, imd: r.out }; }
      const [imdOut, fee] = await pc.readContract({ address: addr.sale, abi: PadSaleAbi, functionName: 'quoteSell', args: [amount!] });
      const out = await fromImd(pc, pay, imdOut);
      return { out, fee, snipe: 0n, imd: imdOut };
    },
  });

  const ethBal = useBalance({ address, query: { enabled: !!address } });
  const tokBal = useReadContract({ address: pay.address === ETH ? addr.imd : pay.address, abi: erc20Abi, functionName: 'balanceOf', args: [address!], query: { enabled: !!address && pay.address !== ETH } });
  const ppBal = useReadContract({ address: addr.pondpad, abi: erc20Abi, functionName: 'balanceOf', args: [address!], query: { enabled: !!address } });
  const balance = side === 'sell' ? ppBal.data : pay.address === ETH ? ethBal.data?.value : tokBal.data;

  const slipBps = slipOf(slip);
  const minOut = q ? (q.out * BigInt(10000 - slipBps)) / 10000n : 0n;
  const outSym = side === 'buy' ? '$PONDPAD' : pay.symbol;
  const over = amount !== undefined && balance !== undefined && amount > balance;
  const overCap = side === 'buy' && q && sale.remaining !== undefined && q.out > sale.remaining;
  const presets = side === 'sell' ? ['25%', '50%', '100%'] : pay.symbol === 'ETH' ? ['0.05', '0.1', '0.5'] : pay.symbol === 'USDG' ? ['50', '100', '500'] : ['10', '50', '100', '250'];
  const notStarted = Date.now() / 1000 < sale.startTime;

  async function go() {
    if (!address || !amount || !q) return;
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 600);
    const calls: (Call & { label: string })[] = [];
    if (side === 'buy') {
      if (pay.address !== ETH) calls.push(...(await approveIfNeeded(pc, pay.address, address, addr.sale, amount)));
      calls.push({ address: addr.sale, abi: PadSaleAbi as Abi, functionName: 'buyWith', args: [pay.address, amount, minOut, deadline, ETH], value: pay.address === ETH ? amount : undefined, label: 'Buying…' });
      await send(calls, { ok: `Bought ${fmtAmount(q.out)} $PONDPAD.` }).catch(() => {});
    } else {
      calls.push(...(await approveIfNeeded(pc, addr.pondpad, address, addr.sale, amount)));
      calls.push({ address: addr.sale, abi: PadSaleAbi as Abi, functionName: 'sellFor', args: [pay.address, amount, minOut, deadline, ETH], label: 'Selling…' });
      await send(calls, { ok: `Sold for ${fmtAmount(q.out, pay.decimals)} ${pay.symbol}.` }).catch(() => {});
    }
    setText('');
  }

  let button = side === 'buy' ? 'Buy $PONDPAD' : 'Sell $PONDPAD';
  let disabled = !q || isFetching || !amount;
  if (sale.preview) { button = 'Preview only'; disabled = true; }
  else if (!isConnected) { button = 'Connect a wallet to hop in'; disabled = true; }
  else if (notStarted) { button = 'The sale hasn’t opened yet'; disabled = true; }
  else if (pending) { button = pending; disabled = true; }
  else if (over) { button = side === 'buy' ? `Not enough ${pay.symbol}` : 'Not enough $PONDPAD'; disabled = true; }
  else if (overCap) { button = 'Over your 15M limit'; disabled = true; }

  return (
    <div className="pp-trade">
      <div className="pp-seg is-trade" role="group" aria-label="Buy or sell">
        <button data-side="buy" aria-pressed={side === 'buy'} onClick={() => setSide('buy')}>Buy</button>
        <button data-side="sell" aria-pressed={side === 'sell'} onClick={() => setSide('sell')}>Sell</button>
      </div>
      <Amount id="sale-amount" label={side === 'buy' ? 'You pay' : 'You sell'} text={text} setText={setText} balance={sale.preview ? undefined : balance} unit={side === 'buy' ? pay.symbol : '$PONDPAD'} decimals={inDecimals} presets={presets} />
      <div className="pp-field">
        <span className="pp-label">{side === 'buy' ? 'Pay with' : 'Receive'}</span>
        <div className="pp-seg" role="group" aria-label="Payment token">
          {PAY_TOKENS.map((t) => <button key={t.symbol} aria-pressed={t.symbol === pay.symbol} disabled={sale.preview && t.symbol !== 'IMD'} onClick={() => setPaySym(t.symbol)}>{t.symbol}</button>)}
        </div>
      </div>
      <div className="pp-quote" aria-live="polite">
        <div><span>You get (at least)</span><b>{q ? `${fmtAmount(minOut, side === 'buy' ? 18 : pay.decimals)} ${outSym}` : amount ? (qErr ? 'No quote' : '…') : '–'}</b></div>
        <div><span>Route</span><b>{side === 'buy' ? `${pay.symbol}${pay.symbol === 'IMD' ? '' : ' → IMD'} → sale curve` : `sale curve → IMD${pay.symbol === 'IMD' ? '' : ` → ${pay.symbol}`}`}</b></div>
        <Slippage slip={slip} setSlip={setSlip} />
        <div className="pp-fee"><span>Fee</span><b>1.0% to the fee split{q ? ` (${fmtAmount(q.fee)} IMD)` : ''}</b></div>
        {side === 'buy' && q && q.snipe > 0n && <div><span>Early-bird tax</span><b className="pp-down">{fmtAmount(q.snipe)} IMD</b></div>}
        {side === 'buy' && sale.remaining !== undefined && <div><span>Your limit left</span><b>{fmtAmount(sale.remaining, 18, { compact: true })} of 15M $PONDPAD</b></div>}
      </div>
      <button className={`pp-btn pp-btn-block ${side === 'buy' ? 'pp-btn-leap' : 'pp-btn-sell'}`} disabled={disabled} onClick={go}>{button}</button>
      <p className="t-caption muted center">You can sell back to the curve anytime before the Leap. Your wallet signs every transaction.</p>
    </div>
  );
}

/** The market after the Leap: buy or sell $PONDPAD with IMD, ETH or USDG through Uniswap's Universal Router (D-77). */
export function MarketTradeBox({ market }: { market: MarketState }) {
  const { address, isConnected } = useAccount();
  const pc = usePublicClient() as PublicClient;
  const [side, setSide] = useState<'buy' | 'sell'>('buy');
  const [paySym, setPaySym] = remember<PayToken['symbol']>('pp-pay', 'IMD');
  const [slip, setSlip] = remember<string>('pp-slippage', '1');
  const [text, setText] = useState('');
  const pay = PAY_TOKENS.find((t) => t.symbol === paySym) ?? PAY_TOKENS[0];
  const buy = side === 'buy';
  const inDecimals = buy ? pay.decimals : 18;
  const amount = parseAmount(text, inDecimals);
  const { send, pending } = useSend();
  useEffect(() => setText(''), [side, paySym]);

  // One quote along the whole path (what the router swaps), plus the IMD that enters or leaves the market for the impact.
  const { data: q, isFetching, error: qErr } = useQuery({
    queryKey: ['marketQuote', side, pay.symbol, amount?.toString()],
    enabled: !!amount && amount > 0n,
    refetchInterval: 10_000,
    retry: false,
    queryFn: async () => {
      const route = await marketRoute(pc, market.key, buy, pay.address);
      const out = await quoteMarket(pc, route, amount!);
      let imd = buy ? amount! : out;
      if (pay.address !== addr.imd) imd = buy ? await toImd(pc, pay, amount!) : await quoteMarket(pc, await marketRoute(pc, market.key, false, addr.imd), amount!);
      return { route, out, imd };
    },
  });

  const ethBal = useBalance({ address, query: { enabled: !!address } });
  const tokBal = useReadContract({ address: pay.address === ETH ? addr.imd : pay.address, abi: erc20Abi, functionName: 'balanceOf', args: [address!], query: { enabled: !!address && pay.address !== ETH } });
  const ppBal = useReadContract({ address: addr.pondpad, abi: erc20Abi, functionName: 'balanceOf', args: [address!], query: { enabled: !!address } });
  const balance = buy ? (pay.address === ETH ? ethBal.data?.value : tokBal.data) : ppBal.data;
  const slipBps = slipOf(slip);
  const minOut = q ? (q.out * BigInt(10000 - slipBps)) / 10000n : 0n;
  const outSym = buy ? '$PONDPAD' : pay.symbol;
  const outDecimals = buy ? 18 : pay.decimals;
  const over = amount !== undefined && balance !== undefined && amount > balance;
  const feePct = (market.feePips / 10_000).toFixed(2);
  // Impact of the market leg only, after its fee (the IMD / ETH / USDG legs have their own pool fees and depth).
  const marketOut = q ? (buy ? q.out : q.imd) : undefined;
  const marketIn = q ? (buy ? q.imd : amount!) : undefined;
  const spot = marketIn && market.priceE18 > 0n ? (buy ? (marketIn * 10n ** 18n) / market.priceE18 : (marketIn * market.priceE18) / 10n ** 18n) : 0n;
  const ideal = (spot * BigInt(1_000_000 - market.feePips)) / 1_000_000n;
  const impactBps = marketOut !== undefined && ideal > 0n && marketOut < ideal ? Number(((ideal - marketOut) * 10000n) / ideal) : 0;
  const presets = !buy ? ['25%', '50%', '100%'] : pay.symbol === 'ETH' ? ['0.05', '0.1', '0.5'] : pay.symbol === 'USDG' ? ['50', '100', '500'] : ['10', '50', '100', '250'];
  const legs = pay.symbol === 'IMD' ? '' : pay.symbol === 'ETH' ? 'ETH → IMD' : 'USDG → ETH → IMD';
  const routeText = buy ? `${legs ? `${legs} → ` : 'IMD → '}$PONDPAD pool` : `$PONDPAD pool → ${legs ? legs.split(' → ').reverse().join(' → ') : 'IMD'}`;

  async function go() {
    if (!address || !amount || !q) return;
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 600);
    const tokenIn = buy ? pay.address : addr.pondpad;
    const calls: (Call & { label: string })[] = tokenIn === ETH ? [] : await approveViaPermit2(pc, tokenIn, address, UNIVERSAL_ROUTER, amount);
    calls.push({
      address: UNIVERSAL_ROUTER, abi: UniversalRouterAbi as Abi, functionName: 'execute', args: marketSwapArgs(q.route, amount, minOut, deadline),
      value: tokenIn === ETH ? amount : undefined, gasPct: MARKET_GAS_HEADROOM, label: buy ? 'Buying…' : 'Selling…',
    });
    await send(calls, { ok: buy ? `Bought about ${fmtAmount(q.out)} $PONDPAD.` : `Sold for about ${fmtAmount(q.out, pay.decimals)} ${pay.symbol}.` }).catch(() => {});
    setText('');
  }

  let button = buy ? 'Buy $PONDPAD' : 'Sell $PONDPAD';
  let disabled = !q || isFetching || !amount;
  if (!isConnected) { button = 'Connect a wallet to hop in'; disabled = true; }
  else if (pending) { button = pending; disabled = true; }
  else if (over) { button = buy ? `Not enough ${pay.symbol}` : 'Not enough $PONDPAD'; disabled = true; }

  return (
    <div className="pp-trade">
      <div className="pp-seg is-trade" role="group" aria-label="Buy or sell">
        <button data-side="buy" aria-pressed={buy} onClick={() => setSide('buy')}>Buy</button>
        <button data-side="sell" aria-pressed={!buy} onClick={() => setSide('sell')}>Sell</button>
      </div>
      <Amount id="market-amount" label={buy ? 'You pay' : 'You sell'} text={text} setText={setText} balance={balance} unit={buy ? pay.symbol : '$PONDPAD'} decimals={inDecimals} presets={presets} />
      <div className="pp-field">
        <span className="pp-label">{buy ? 'Pay with' : 'Receive'}</span>
        <div className="pp-seg" role="group" aria-label="Payment token">
          {PAY_TOKENS.map((t) => <button key={t.symbol} aria-pressed={t.symbol === pay.symbol} onClick={() => setPaySym(t.symbol)}>{t.symbol}</button>)}
        </div>
      </div>
      <div className="pp-quote" aria-live="polite">
        <div><span>You get (at least)</span><b>{q ? `${fmtAmount(minOut, outDecimals)} ${outSym}` : amount ? (qErr ? 'No quote' : '…') : '–'}</b></div>
        <div><span>Route</span><b>{routeText}</b></div>
        {q && <div><span>Price impact</span><b className={impactBps > 500 ? 'pp-down' : ''}>{(impactBps / 100).toFixed(2)}%</b></div>}
        <Slippage slip={slip} setSlip={setSlip} />
        <div className="pp-fee"><span>Fee</span><b>{feePct}% today, falling to 1% by day 7{pay.symbol === 'IMD' ? '' : `, plus the ${pay.symbol} route's pool fees`}</b></div>
      </div>
      <button className={`pp-btn pp-btn-block ${buy ? 'pp-btn-leap' : 'pp-btn-sell'}`} disabled={disabled} onClick={go}>{button}</button>
      <p className="t-caption muted center">Trades go through Uniswap's router in one transaction. If the price moves past your slippage, nothing is swapped. Sells above the pool's cap are partly burned.</p>
    </div>
  );
}
