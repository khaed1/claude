import { createConfig, http } from 'wagmi';
import { injected } from 'wagmi/connectors';
import { chain, rpcUrl } from './config';

// Browser wallets (MetaMask, Rabby, Coinbase extension…). WalletConnect needs a project id and comes later.
export const wagmiConfig = createConfig({
  chains: [chain],
  connectors: [injected({ shimDisconnect: true })],
  transports: { [chain.id]: http(rpcUrl, { batch: { wait: 16 } }) },
});

declare module 'wagmi' {
  interface Register { config: typeof wagmiConfig }
}
