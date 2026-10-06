import { HashRouter, Route, Routes } from 'react-router-dom';
import { Layout } from './components/Layout';
import { Explore } from './pages/Explore';
import { Coin } from './pages/Coin';
import { Spawn } from './pages/Spawn';
import { Profile } from './pages/Profile';
import { Docs } from './pages/Docs';
import { Pondpad } from './pages/Pondpad';
import { Pond } from './pages/Pond';
import { Transparency } from './pages/Transparency';
import { Faucet, Legal, NotFound } from './pages/Simple';

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
          <Route path="/pond" element={<Pond />} />
          <Route path="/transparency" element={<Transparency />} />
          <Route path="*" element={<NotFound />} />
        </Routes>
      </Layout>
    </HashRouter>
  );
}
