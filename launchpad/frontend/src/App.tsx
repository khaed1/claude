import { HashRouter, Route, Routes } from 'react-router-dom';
import { Layout } from './components/Layout';
import { Explore } from './pages/Explore';
import { Coin } from './pages/Coin';
import { Spawn } from './pages/Spawn';
import { Profile } from './pages/Profile';
import { Docs } from './pages/Docs';
import { Pondpad } from './pages/Pondpad';
import { Faucet, Legal, NotFound, Soon } from './pages/Simple';

// Hash routes: the site is static and served from IPFS, where there is no server to rewrite paths.
export function App() {
  return (
    <HashRouter>
      <Layout>
        <Routes>
          <Route path="/" element={<Explore />} />
          <Route path="/c/:address" element={<Coin />} />
          <Route path="/spawn" element={<Spawn />} />
          <Route path="/me" element={<Profile />} />
          <Route path="/u/:address" element={<Profile />} />
          <Route path="/docs" element={<Docs />} />
          <Route path="/docs/:slug" element={<Docs />} />
          <Route path="/terms" element={<Legal which="terms" />} />
          <Route path="/privacy" element={<Legal which="privacy" />} />
          <Route path="/faucet" element={<Faucet />} />
          <Route path="/pondpad" element={<Pondpad />} />
          <Route path="/pond" element={<Soon title="The Pond"><p>Stake $PONDPAD, get sPONDPAD. Part of every trade on PondPad buys $PONDPAD and drips it into the pond, so each sPONDPAD is slowly worth more $PONDPAD. Nothing to claim. Leave when you like (a few seconds after joining).</p></Soon>} />
          <Route path="/transparency" element={<Soon title="Where every IMD goes"><p>We'd rather show you than tell you. Every number on this page will be read straight from the chain: fees in, the 40/25/20/15 split, swarm jobs paid, $PONDPAD burned, and settings changes waiting in the timelocks.</p></Soon>} />
          <Route path="*" element={<NotFound />} />
        </Routes>
      </Layout>
    </HashRouter>
  );
}
