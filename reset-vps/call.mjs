// Minimal model-free MCP client for the RESET signer: call one or more tools in sequence
// and print one JSON line per call. Used by the scheduler for cheap state checks and
// mechanical steps; claim decisions are left to the agent.
// Usage: node call.mjs status [post_headers ...]
import { Client } from '/root/reset/signer/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js';
import { StdioClientTransport } from '/root/reset/signer/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js';

const ALLOWED = new Set(['status', 'address', 'rules', 'post_headers']);
const names = process.argv.slice(2);
if (!names.length || names.some(n => !ALLOWED.has(n))) {
  console.error(`usage: call.mjs <${[...ALLOWED].join('|')}> ...`);
  process.exit(64);
}

// The SDK passes only a minimal environment to the child; keep the network settings it needs.
const env = Object.fromEntries(Object.entries(process.env).filter(([k]) =>
  /^(PATH|HOME|USER|LANG|TZ|https?_proxy|HTTPS?_PROXY|no_proxy|NO_PROXY|NODE_EXTRA_CA_CERTS|NODE_USE_ENV_PROXY|SSL_CERT_FILE|RESET_[A-Z_]+)$/.test(k)));
const transport = new StdioClientTransport({ command: '/root/reset-agent/reset-mcp.sh', env, stderr: 'ignore' });
const client = new Client({ name: 'reset-scheduler', version: '1' });
let code = 0;
try {
  await client.connect(transport);
  for (const name of names) {
    const res = await client.callTool({ name, arguments: {} }, undefined, { timeout: 120000 });
    const text = (res.content || []).map(c => c.text || '').join('');
    let body;
    try { body = JSON.parse(text); } catch { body = text; }
    if (res.isError) code = 1;
    console.log(JSON.stringify({ tool: name, ok: !res.isError, result: body }));
  }
} catch (e) {
  console.log(JSON.stringify({ ok: false, error: String(e && e.message || e) }));
  code = 2;
} finally {
  await client.close().catch(() => {});
}
process.exit(code);
