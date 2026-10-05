import { Link } from 'react-router-dom';
import { useAccount, useReadContract } from 'wagmi';
import { erc20Abi, parseAbi, type Abi } from 'viem';
import { addr, explorerAddr } from '../config';
import { Markdown } from '../components/Markdown';
import { fmtAmount } from '../lib/format';
import { useSend } from '../lib/tx';
import terms from '../../../legal/TERMS.md?raw';
import privacy from '../../../legal/PRIVACY.md?raw';

export function Legal({ which }: { which: 'terms' | 'privacy' }) {
  return <div className="wrap prose"><Markdown text={which === 'terms' ? terms : privacy} /></div>;
}

export function NotFound() {
  return <div className="wrap empty"><img src="./pip.svg" alt="" width={120} /><p>This page sank to the bottom of the pond. Swim back up.</p><Link className="pp-btn" to="/">Back to Explore</Link></div>;
}

/** Pages designed (design/system/Pages.md) but not built yet. */
export function Soon({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="wrap prose">
      <h1 className="t-title">{title}</h1>
      {children}
      <div className="pp-notice"><span /><div><b>Being built.</b> This page is next on the list; the contracts behind it are live on the testnet.</div></div>
    </div>
  );
}

const FAUCET = parseAbi(['function faucet()', 'function faucetAmount() view returns (uint256)']);

export function Faucet() {
  const { address, isConnected } = useAccount();
  const { send, pending } = useSend();
  const imd = useReadContract({ address: addr.imd, abi: erc20Abi, functionName: 'balanceOf', args: [address!], query: { enabled: !!address } });
  const usdg = useReadContract({ address: addr.usdg, abi: erc20Abi, functionName: 'balanceOf', args: [address!], query: { enabled: !!address } });
  const drip = (token: `0x${string}`, sym: string) => send([{ address: token, abi: FAUCET as Abi, functionName: 'faucet', label: `Getting ${sym}…` }], { ok: `Test ${sym} is in your wallet.` }).catch(() => {});
  return (
    <div className="wrap prose">
      <h1 className="t-title">Testnet faucet</h1>
      <p>Test IMD and test USDG for Robinhood Chain Testnet. They have no value. Each wallet can take 500 tIMD and 5,000 tUSDG once an hour. You also need a little testnet ETH for gas (Sepolia ETH bridged to Robinhood Chain Testnet).</p>
      <div className="pp-stats">
        <div className="pp-stat"><span>Your test IMD</span><b>{fmtAmount(imd.data)}</b><small><a href={explorerAddr(addr.imd)} target="_blank" rel="noreferrer">{addr.imd}</a></small></div>
        <div className="pp-stat"><span>Your test USDG</span><b>{fmtAmount(usdg.data, 6)}</b><small><a href={explorerAddr(addr.usdg)} target="_blank" rel="noreferrer">{addr.usdg}</a></small></div>
      </div>
      <div className="row">
        <button className="pp-btn pp-btn-primary" disabled={!isConnected || !!pending} onClick={() => drip(addr.imd, 'IMD')}>Get 500 test IMD</button>
        <button className="pp-btn" disabled={!isConnected || !!pending} onClick={() => drip(addr.usdg, 'USDG')}>Get 5,000 test USDG</button>
      </div>
      {!isConnected && <p className="muted">Connect a wallet first.</p>}
    </div>
  );
}
