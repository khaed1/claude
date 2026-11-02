// One Dollar Audit (onedollaraudit.com, LeftClaw Services' audit pipeline): commission one $1 audit per
// description file through the x402 endpoint (a gasless EIP-3009 USDC signature on Base), save the job id,
// or read a job's status. The payer key comes from the environment and is never printed.
//
//   npm install --prefix /tmp/oda viem @x402/core @x402/evm @x402/fetch
//   NODE_PATH=/tmp/oda/node_modules PAYER_KEY="$PONDPAD_TESTNET_KEY" node plea/tools/submit_onedollaraudit.mjs submit plea/onedollaraudit/job1-hook.txt
//   node plea/tools/submit_onedollaraudit.mjs status <jobId>
//   (check <file> loads everything and shows the payer without contacting the endpoint)
//
// Each submit pays $1 USDC (read from the 402 response) from the payer's Base wallet. Job ids are appended
// to plea/onedollaraudit/jobs.json; never re-submit a description to "check" a job, read its status instead.
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const JOBS = new URL("../onedollaraudit/jobs.json", import.meta.url);
const [mode, arg] = process.argv.slice(2);

async function status(jobId) {
  const r = await fetch(`https://onedollaraudit.com/api/jobs/${jobId}`);
  console.log(r.status, JSON.stringify(await r.json(), null, 1));
}

async function submit(file, dryRun = false) {
  const description = readFileSync(file, "utf8");
  if (description.length > 12000) throw new Error(`description is ${description.length} chars; the limit is ~12,000`);
  const key = process.env.PAYER_KEY;
  if (!key) throw new Error("set PAYER_KEY");
  const { createWalletClient, createPublicClient, http } = require("viem");
  const { base } = require("viem/chains");
  const { privateKeyToAccount } = require("viem/accounts");
  const { wrapFetchWithPaymentFromConfig } = require("@x402/fetch");
  const { ExactEvmScheme, toClientEvmSigner } = require("@x402/evm");
  const account = privateKeyToAccount(key.startsWith("0x") ? key : `0x${key}`);
  const transport = http("https://mainnet.base.org");
  const publicClient = createPublicClient({ chain: base, transport });
  const walletClient = createWalletClient({ account, chain: base, transport });
  const signer = { ...toClientEvmSigner(walletClient, publicClient), address: account.address };
  const pay = wrapFetchWithPaymentFromConfig(fetch, {
    schemes: [{ network: "eip155:8453", client: new ExactEvmScheme(signer) }],
  });
  console.log(`payer ${account.address}, ${description.length} chars from ${file}`);
  if (dryRun) return console.log("check only: libraries load, nothing sent");
  const r = await pay("https://leftclaw.services/api/audit", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ description }),
  });
  if (!r.ok) throw new Error(`failed ${r.status}: ${await r.text()}`);
  const res = await r.json();
  const jobs = existsSync(JOBS) ? JSON.parse(readFileSync(JOBS, "utf8")) : [];
  jobs.push({ file, jobId: res.jobId, jobUrl: res.jobUrl, at: new Date().toISOString() });
  writeFileSync(JOBS, JSON.stringify(jobs, null, 1) + "\n");
  console.log(`job ${res.jobId} ${res.jobUrl ?? ""} (saved to jobs.json)`);
}

if (mode === "submit" && arg) await submit(arg);
else if (mode === "check" && arg) await submit(arg, true);
else if (mode === "status" && arg) await status(arg);
else console.log("usage: submit <description file> | check <description file> | status <jobId>");
