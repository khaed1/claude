// Guarding MCP proxy for unattended RESET runs. The agent connects here instead of to the
// signer. It exposes only the tools the worker needs and enforces the owner's limits in
// code: total deposit cap, no overclaiming, and no transfer/unlock/withdraw at all.
// Limits come from config.json (max_lock, allow_over). Every forwarded move is logged.
import fs from 'node:fs';
import { Server } from '/root/reset/signer/node_modules/@modelcontextprotocol/sdk/dist/esm/server/index.js';
import { StdioServerTransport } from '/root/reset/signer/node_modules/@modelcontextprotocol/sdk/dist/esm/server/stdio.js';
import { Client } from '/root/reset/signer/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js';
import { StdioClientTransport } from '/root/reset/signer/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js';
import { ListToolsRequestSchema, CallToolRequestSchema } from '/root/reset/signer/node_modules/@modelcontextprotocol/sdk/dist/esm/types.js';

const HOME = '/root/reset-agent';
const EXPOSED = new Set(['status', 'rules', 'address', 'post_headers', 'lock', 'mine_claim']);
const MOVES = new Set(['lock', 'mine_claim']);
const config = JSON.parse(fs.readFileSync(`${HOME}/config.json`, 'utf8'));

// Coin strings with up to 8 decimals -> integer units, without floating point.
const units = s => {
  const m = /^(\d+)(?:\.(\d{1,8}))?$/.exec(String(s));
  if (!m) throw new Error(`bad amount ${s}`);
  return BigInt(m[1]) * 100000000n + BigInt((m[2] || '').padEnd(8, '0'));
};
const log = rec => fs.appendFileSync(`${HOME}/logs/activity.jsonl`,
  JSON.stringify({ ts: new Date().toISOString(), src: 'guard', run: process.env.RESET_RUN_ID || null, ...rec }) + '\n');
const text = t => ({ content: [{ type: 'text', text: typeof t === 'string' ? t : JSON.stringify(t) }] });
const refuse = reason => { log({ event: 'refused', reason }); return { ...text(`Refused by owner limits: ${reason}`), isError: true }; };

const env = Object.fromEntries(Object.entries(process.env).filter(([k]) =>
  /^(PATH|HOME|USER|LANG|TZ|https?_proxy|HTTPS?_PROXY|no_proxy|NO_PROXY|NODE_EXTRA_CA_CERTS|SSL_CERT_FILE|RESET_PASSWORD_FILE)$/.test(k)));
const upstream = new Client({ name: 'reset-guard', version: '1' });
await upstream.connect(new StdioClientTransport({ command: `${HOME}/reset-mcp.sh`, env, stderr: 'ignore' }));
const upstreamTools = (await upstream.listTools()).tools.filter(t => EXPOSED.has(t.name));

const call = async (name, args) => upstream.callTool({ name, arguments: args }, undefined, { timeout: 150000 });
const parse = res => { try { return JSON.parse(res.content.map(c => c.text || '').join('')); } catch { return null; } };

async function check(name, args) {
  if (name === 'mine_claim') {
    if (args.allow_over && !config.allow_over) return 'overclaiming (allow_over) is not permitted';
    if (args.level !== undefined && Number(args.level) > 1000 && !config.allow_over) return 'claim level above 1000 is not permitted';
  }
  if (name === 'lock') {
    const st = parse(await call('status', {}));
    if (!st || st.deposit === undefined) return 'could not read current deposit; not locking blind';
    const after = units(st.deposit) + units(args.amount);
    if (after > units(config.max_lock)) return `deposit would be ${Number(after) / 1e8} > cap ${config.max_lock}`;
  }
  return null;
}

const server = new Server({ name: 'reset-guarded', version: '1' }, { capabilities: { tools: {} } });
server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: upstreamTools }));
server.setRequestHandler(CallToolRequestSchema, async req => {
  const { name, arguments: args = {} } = req.params;
  if (!EXPOSED.has(name)) return refuse(`tool ${name} is disabled for unattended runs`);
  if (MOVES.has(name)) {
    const why = await check(name, args).catch(e => `check failed: ${e.message}`);
    if (why) return refuse(why);
    log({ event: 'submit', tool: name, args });
  }
  const res = await call(name, args);
  if (MOVES.has(name)) log({ event: 'result', tool: name, isError: !!res.isError, result: parse(res) ?? res.content });
  return res;
});
await server.connect(new StdioServerTransport());
