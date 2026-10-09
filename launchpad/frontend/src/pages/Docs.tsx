import { NavLink, useParams } from 'react-router-dom';
import { Markdown } from '../components/Markdown';
import { addr, chain, explorerAddr } from '../config';
import { NotFound } from './Simple';

const files = import.meta.glob('../docs/*.md', { query: '?raw', import: 'default', eager: true }) as Record<string, string>;
const page = (slug: string) => files[`../docs/${slug}.md`];

const NAV: { group: string; items: [string, string][] }[] = [
  { group: 'Start here', items: [['', 'What is PondPad'], ['first-trade', 'Your first trade'], ['spawn', 'Spawn a coin']] },
  { group: 'How it works', items: [['curve', 'The curve and the Leap'], ['fees', 'Fees and where they go']] },
  { group: '$PONDPAD', items: [['pondpad-sale', 'The sale'], ['pondpad-market', 'The market: fee, cap, burns'], ['pond', 'Staking: the Pond'], ['airdrop', 'The airdrop']] },
  { group: 'Safety', items: [['risks', 'Risks'], ['admin', 'Admin powers and timelocks'], ['contracts', 'Contracts and addresses']] },
  { group: 'Testnet', items: [['testnet', 'Testnet and faucet']] },
];

const LABELS: Record<string, string> = {
  router: 'PadRouter (trade entry point)', curve: 'BondingCurve', hook: 'PadHook (coin pools)', factory: 'PadFactory', lens: 'PadLens (read-only views)',
  config: 'PadConfig', feeSplitter: 'FeeSplitter', creatorVault: 'CreatorVault', swarmBudget: 'SwarmBudget', integratorVault: 'IntegratorVault',
  pondpad: '$PONDPAD', sale: 'PadSale ($PONDPAD sale)', marketHook: 'PadMarketHook ($PONDPAD market)', marketController: 'MarketController',
  stakedPondpad: 'StakedPONDPAD (sPONDPAD)', rewardDripper: 'RewardDripper', padBuyer: 'PadBuyer', burner: 'PadBurner',
  workerFund: 'WorkerFund', growthFund: 'GrowthFund', airdrop: 'AirdropDistributor', teamVesting: 'TeamVesting',
  attestationVerifier: 'AttestationVerifier', ctoModule: 'CTOModule', versionRegistry: 'VersionRegistry', socialRegistry: 'SocialRegistry',
  fastTimelock: 'Timelock (fast)', slowTimelock: 'Timelock (slow)', imd: 'IMD', usdg: 'USDG', poolManager: 'Uniswap v4 PoolManager',
};

function Contracts() {
  return (
    <div className="md">
      <h1>Contracts and addresses</h1>
      <p>{chain.name} (chain {chain.id}). Read from the deployment file the site is built with. No contract is a proxy.</p>
      <div className="md-table"><table><thead><tr><th>Contract</th><th>Address</th></tr></thead><tbody>
        {Object.entries(LABELS).map(([k, label]) => {
          const a = (addr as Record<string, unknown>)[k] as string | undefined;
          return a ? <tr key={k}><td>{label}</td><td><a className="mono" href={explorerAddr(a)} target="_blank" rel="noreferrer">{a}</a></td></tr> : null;
        })}
      </tbody></table></div>
    </div>
  );
}

export function Docs() {
  const { slug = '' } = useParams();
  const text = page(slug || 'index');
  return (
    <div className="wrap docs">
      <nav className="docs-nav" aria-label="Docs">
        {NAV.map((g) => (
          <div key={g.group}><h2 className="t-label muted">{g.group}</h2>
            {g.items.map(([s, label]) => <NavLink key={s} to={s ? `/docs/${s}` : '/docs'} end>{label}</NavLink>)}
          </div>
        ))}
      </nav>
      <article className="prose">{slug === 'contracts' ? <Contracts /> : text ? <Markdown text={text} /> : <NotFound />}</article>
    </div>
  );
}
