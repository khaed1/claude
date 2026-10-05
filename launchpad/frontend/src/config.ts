import { defineChain, type Address } from 'viem';
import testnet from '../../contracts/deployments/46630.json';
import testnetSetup from '../../contracts/deployments/46630-setup.json';

// Which deployment the site runs against. Testnet only until mainnet is deployed (deployments/4663.json).
export const robinhoodTestnet = defineChain({
  id: 46630,
  name: 'Robinhood Chain Testnet',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: { default: { http: ['https://rpc.testnet.chain.robinhood.com'] } },
  blockExplorers: { default: { name: 'Explorer', url: 'https://explorer.testnet.chain.robinhood.com' } },
  contracts: { multicall3: { address: '0xcA11bde05977b3631167028862bE2a173976CA11' } },
  testnet: true,
});

export const chain = robinhoodTestnet;
// In dev the RPC goes through Vite's /rpc proxy; a build can point anywhere with VITE_RPC_URL.
export const rpcUrl: string = import.meta.env.VITE_RPC_URL ?? (import.meta.env.DEV ? '/rpc' : chain.rpcUrls.default.http[0]);

type Deployment = typeof testnet;
export const addr = testnet as unknown as { [K in keyof Deployment]: K extends 'chainId' ? number : Address };
export const setup = testnetSetup as unknown as { swapRouter: Address; liquidityRouter: Address };

export const ETH = '0x0000000000000000000000000000000000000000' as Address;
export const QUOTER = '0x8Dc178eFB8111BB0973Dd9d722ebeFF267c98F94' as Address; // v4 Quoter, same address on mainnet and testnet

export type PayToken = { symbol: 'IMD' | 'ETH' | 'USDG'; address: Address; decimals: number };
export const PAY_TOKENS: PayToken[] = [
  { symbol: 'IMD', address: addr.imd, decimals: 18 },
  { symbol: 'ETH', address: ETH, decimals: 18 },
  { symbol: 'USDG', address: addr.usdg, decimals: 6 },
];

// Fee wording and numbers the chain does not expose (D-9, D-14, D-64).
export const BASE_FEE_BPS = 150;
export const MARKET_GAS_HEADROOM = 150n; // percent of the estimate for $PONDPAD market swaps and keeper-type calls

// Bump when the Terms or Privacy Policy change: everyone accepts again (legal/TERMS.md, legal/PRIVACY.md).
export const LEGAL_VERSION = '2026-10-05';

export const explorerTx = (h: string) => `${chain.blockExplorers.default.url}/tx/${h}`;
export const explorerAddr = (a: string) => `${chain.blockExplorers.default.url}/address/${a}`;

// First block of the testnet deployment (VersionRegistry's first event); log scans start here.
export const DEPLOY_BLOCK = 129_197_000n;
// Robinhood RPCs cap eth_getLogs ranges; scan in chunks this size.
export const LOG_CHUNK = 2_000_000n;
