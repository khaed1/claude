import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAccount, useDisconnect } from 'wagmi';
import { accept, hasAccepted } from '../lib/legal';

/** Blocks the site for a connected wallet until it accepts the current Terms and Privacy Policy (D-69). */
export function LegalGate() {
  const { address } = useAccount();
  const { disconnect } = useDisconnect();
  const [accepted, setAccepted] = useState(() => hasAccepted(address));
  const [terms, setTerms] = useState(false);
  const [privacy, setPrivacy] = useState(false);
  const [place, setPlace] = useState(false);
  const dialog = useRef<HTMLDivElement>(null);

  useEffect(() => { setAccepted(hasAccepted(address)); setTerms(false); setPrivacy(false); setPlace(false); }, [address]);
  const open = !!address && !accepted;
  useEffect(() => { if (open) dialog.current?.querySelector<HTMLElement>('input')?.focus(); }, [open]);
  if (!open) return null;

  return (
    <div className="gate" role="dialog" aria-modal="true" aria-labelledby="gate-title" ref={dialog}>
      <div className="gate-card">
        <h2 id="gate-title" className="t-heading">Before you hop in</h2>
        <p>To use PondPad with this wallet, please review and accept the current Terms of Use and Privacy Policy.</p>
        <label className="check"><input type="checkbox" checked={terms} onChange={(e) => setTerms(e.target.checked)} /> <span>I have read and accept the <Link to="/terms" target="_blank">Terms of Use</Link>.</span></label>
        <label className="check"><input type="checkbox" checked={privacy} onChange={(e) => setPrivacy(e.target.checked)} /> <span>I have read and accept the <Link to="/privacy" target="_blank">Privacy Policy</Link>.</span></label>
        <label className="check"><input type="checkbox" checked={place} onChange={(e) => setPlace(e.target.checked)} /> <span>I am 18 or older and not located in, or acting for anyone in, a restricted jurisdiction listed in the Terms.</span></label>
        <div className="gate-actions">
          <button className="pp-btn pp-btn-primary" disabled={!(terms && privacy && place)} onClick={() => { accept(address!); setAccepted(true); }}>Accept and continue</button>
          <button className="pp-btn pp-btn-ghost" onClick={() => disconnect()}>Disconnect wallet</button>
        </div>
        <p className="t-caption muted">You'll be asked again when your browser session ends, when you clear cookies, or when these texts change.</p>
      </div>
    </div>
  );
}
