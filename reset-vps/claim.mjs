// Submit this round's Mine claim at the level the agent decided, through the guard (which enforces the
// owner's limits and logs every submission). Busy windows make the gateway refuse reads and moves while
// many miners act at once, so this retries every few seconds, always re-reading status first, and stops
// once a claim is recorded, the gateway says it is a duplicate, the window closes or the round changes.
// Usage: node claim.mjs <level> <round>   Prints one JSON line: {"result": ..., "attempts": n, ...}
import { Client } from '/root/reset/signer/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js';
import { StdioClientTransport } from '/root/reset/signer/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js';

const level = Number(process.argv[2]), round = Number(process.argv[3]);
if (!Number.isInteger(level) || level < 0 || level > 1000 || !Number.isInteger(round)) {
  console.log(JSON.stringify({ result: 'bad_arguments' })); process.exit(64);
}
const MAX_MS = 8 * 60 * 1000, MAX_SUBMITS = 25;
const sleep = ms => new Promise(r => setTimeout(r, ms));
const env = Object.fromEntries(Object.entries(process.env).filter(([k]) =>
  /^(PATH|HOME|USER|LANG|TZ|https?_proxy|HTTPS?_PROXY|no_proxy|NO_PROXY|NODE_EXTRA_CA_CERTS|SSL_CERT_FILE|RESET_RUN_ID)$/.test(k)));
const client = new Client({ name: 'reset-claim', version: '1' });
await client.connect(new StdioClientTransport({ command: process.execPath, args: ['/root/reset-agent/guard-mcp.mjs'], env, stderr: 'ignore' }));

const tool = async (name, args = {}) => {
  const res = await client.callTool({ name, arguments: args }, undefined, { timeout: 150000 });
  const text = (res.content || []).map(c => c.text || '').join('');
  let body; try { body = JSON.parse(text); } catch { body = text; }
  return { error: !!res.isError, body };
};

const started = Date.now();
let submits = 0, reads = 0, last = null, result = 'gave_up';
while (Date.now() - started < MAX_MS) {
  const st = await tool('status'); reads++;
  if (st.error || typeof st.body !== 'object') { await sleep(3000); continue; }     // busy block: read again shortly
  const s = st.body;
  if (s.mine.round !== round || !s.mine.window_open) { result = 'window_closed'; break; }
  if (s.claim) { result = 'claimed'; break; }                                        // recorded on the network
  if (submits >= MAX_SUBMITS) break;
  if (last === 'unknown') { last = null; await sleep(15000); continue; }             // may have landed: re-read first
  const r = await tool('mine_claim', { level }); submits++;
  const b = r.body;
  if (b && b.outcome === 'accepted') { last = 'accepted'; await sleep(8000); continue; }   // confirm via status
  if (b && b.outcome === 'unknown') { last = 'unknown'; continue; }
  if (typeof b?.message === 'string' && /already claimed/i.test(b.message)) { result = 'duplicate'; break; }
  if (typeof b === 'string' && /Refused by owner limits/.test(b)) { result = 'refused_by_guard'; break; }
  last = 'retry'; await sleep(3000 + Math.floor(Math.random() * 3000));             // stale block, busy, etc.
}
console.log(JSON.stringify({ result, attempts: submits, reads, level, round, seconds: Math.round((Date.now() - started) / 1000) }));
await client.close().catch(() => {});
process.exit(0);
