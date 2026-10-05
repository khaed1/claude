import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// The design system lives in ../design (tokens, fonts, pp- components); the site imports it directly.
// Dev only: /rpc is proxied to the testnet RPC so a local browser without the chain's CORS / TLS setup works.
export default defineConfig({
  plugins: [react()],
  base: './',
  server: {
    fs: { allow: ['..'] },
    proxy: { '/rpc': { target: 'https://rpc.testnet.chain.robinhood.com', changeOrigin: true, rewrite: () => '/' } },
  },
  build: { target: 'es2020', sourcemap: true },
});
