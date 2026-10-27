// PLEA's mainnet build deployed on a local anvil fork of Ethereum, for testing the site's Ethereum version.
// Adapted from khaed1/plea keeper/rehearsal/run.mjs (keeper @ 08bbe5a). Nothing leaves the fork.
//   node deploy.mjs <port> <out dir>       env: ARTIFACTS (default /home/user/plea-mainnet/out),
//                                            FORK_URL (default tenderly's archive gateway), FORK_BLOCK
// The owner is the real mainnet owner address, impersonated (no key); the gate's and the Tribunal's attestation
// signer is a test key (0xa11ce) so verdicts can be signed on the fork; START is the agreed 1795532400.
// Writes <out>/addresses.json, <out>/state.hex (anvil_dumpState) and leaves anvil running (pid printed).
import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import {
  createPublicClient, createWalletClient, http, parseEther, encodeAbiParameters, keccak256, toHex,
  getContractAddress, concat, padHex, parseAbi,
} from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { mainnet } from 'viem/chains';

const [PORT = '8701', OUT = '/tmp/claude-0/mainnet-fork'] = process.argv.slice(2);
const ARTIFACTS = process.env.ARTIFACTS ?? '/home/user/plea-mainnet/out';
const FORK_URL = process.env.FORK_URL ?? 'https://mainnet.gateway.tenderly.co';
const RPC = `http://127.0.0.1:${PORT}`;
export const M = {
  INTAKE: '0xa43e6F75ee006411F79Ac1C84120606C2330DE82',
  WRITER: '0x3d3C0Df7C1a17d384545e9D7C8228897bD9625CB',
  IMD: '0xD34a99Bc0f67aE1bbd63C660e6d0b0dd03E263B7',
  PM: '0x000000000004444c5dc75cB358380D2e3dE08A90',
  STACKER: '0x06909f672301f28a810f78cfe7a754851269f4f0',
  SEAT: '0x0000eC93127BAA929E58E97dd0095A2BFb38ec1D',
  WHALE: '0xE54d6571aCa515614927F3A70B8957c2B511603C',
  OWNER: '0x5BF3597216f9019Cf10CF680783289Efc8639Bf0',
  START: 1795532400n,
  SEASON: 15n * 86_400n,
  DEADMAN: 118_800n,
  CREDIT_GAS: 400_000n,
  SIGNER_KEY: padHex('0xa11ce', { size: 32 }),
};
const art = (file, name = file) => JSON.parse(readFileSync(join(ARTIFACTS, `${file}.sol`, `${name}.json`), 'utf8'));
const A = Object.fromEntries(['PLEA', 'CabalGate', 'Seasons', 'PleaDistributor', 'PleaLaunch', 'Letterbox', 'Tribunal', 'PleaHook'].map((n) => [n, art(n)]));
const code = (a) => a.bytecode.object;
const erc20 = parseAbi(['function balanceOf(address) view returns (uint256)', 'function transfer(address,uint256) returns (bool)']);
const pub = createPublicClient({ transport: http(RPC), chain: mainnet });
const rpc = (method, params = []) => pub.request({ method, params });
const as = async (addr) => {
  await rpc('anvil_impersonateAccount', [addr]);
  await rpc('anvil_setBalance', [addr, toHex(parseEther('100'))]);
  return createWalletClient({ account: addr, transport: http(RPC), chain: mainnet });
};
const send = async (w, address, abi, functionName, args = []) => {
  const hash = await w.writeContract({ address, abi, functionName, args, gas: 30_000_000n });
  const r = await pub.waitForTransactionReceipt({ hash });
  if (r.status !== 'success') throw new Error(`${functionName} reverted`);
  return r;
};
const read = (address, abi, functionName, args = []) => pub.readContract({ address, abi, functionName, args });

const args = ['--fork-url', FORK_URL, '--port', PORT, '--silent', '--gas-limit', '200000000', '--chain-id', '1'];
if (process.env.FORK_BLOCK) args.push('--fork-block-number', process.env.FORK_BLOCK);
// Public archive RPCs rate-limit a fork's burst of state reads: retry with backoff and pace the requests.
args.push(...(process.env.ANVIL_ARGS ?? '--retries 12 --fork-retry-backoff 1500 --compute-units-per-second 120').split(' ').filter(Boolean));
const anvil = spawn('anvil', args, { stdio: 'ignore', detached: true });
anvil.unref();
for (let i = 0; ; i++) {
  try { await pub.getBlockNumber(); break; } catch { if (i > 120) throw new Error('anvil did not start'); await new Promise((r) => setTimeout(r, 500)); }
}
const block = await pub.getBlock();
const d = await as(M.OWNER);
const o = M.OWNER;
const n0 = await pub.getTransactionCount({ address: o });
const at = (i) => getContractAddress({ from: o, nonce: BigInt(n0 + i) });
const [plea, gate, seasons, distributor, launch] = [0, 1, 2, 3, 4].map(at);
await rpc('evm_setAutomine', [false]);
const signer = privateKeyToAccount(M.SIGNER_KEY).address;
const txs = [
  [A.PLEA, [o]],
  [A.CabalGate, [plea, M.INTAKE, M.IMD, M.IMD, signer, M.SEASON, M.DEADMAN]],
  [A.Seasons, [plea, gate, M.IMD, M.SEAT]],
  [A.PleaDistributor, [plea, o]],
  [A.PleaLaunch, [plea, gate, seasons, distributor, M.PM, M.IMD, M.STACKER, M.CREDIT_GAS, M.START, M.IMD, false,
    keccak256(code(A.Letterbox)), keccak256(code(A.Tribunal))]],
];
const hashes = [];
for (const [i, [a, ctor]] of txs.entries()) hashes.push(await d.deployContract({ abi: a.abi, bytecode: code(a), args: ctor, nonce: n0 + i, gas: 16_000_000n }));
await rpc('evm_mine');
await rpc('evm_setAutomine', [true]);
for (const h of hashes) if ((await pub.getTransactionReceipt({ hash: h })).status !== 'success') throw new Error('launch tx failed');
await send(d, launch, A.PleaLaunch.abi, 'deployLetterbox', [code(A.Letterbox)]);
await send(d, launch, A.PleaLaunch.abi, 'deployTribunal', [code(A.Tribunal)]);
const initCode = concat([code(A.PleaHook), encodeAbiParameters(
  [{ type: 'address' }, { type: 'address' }, { type: 'address' }, { type: 'address' }, { type: 'address' }, { type: 'address' }, { type: 'uint256' }],
  [M.PM, plea, M.IMD, M.STACKER, o, seasons, M.CREDIT_GAS],
)]);
const want = await read(launch, A.PleaLaunch.abi, 'hookInitCodeHash');
if (keccak256(initCode) !== want) throw new Error('hook init code hash differs');
const flags = BigInt(await read(launch, A.PleaLaunch.abi, 'FLAGS'));
let salt = 0n;
for (;; salt++) {
  const addr = getContractAddress({ opcode: 'CREATE2', from: launch, salt: padHex(toHex(salt), { size: 32 }), bytecodeHash: want });
  if ((BigInt(addr) & 0x3fffn) === flags) break;
}
await send(d, launch, A.PleaLaunch.abi, 'deployHook', [padHex(toHex(salt), { size: 32 }), initCode]);
const sys = {
  chainId: 1, forkBlock: Number(block.number), forkTime: Number(block.timestamp),
  PLEA: plea, CabalGate: gate, Seasons: seasons, PleaDistributor: distributor, PleaLaunch: launch,
  PleaHook: await read(launch, A.PleaLaunch.abi, 'hook'),
  Letterbox: await read(launch, A.PleaLaunch.abi, 'letterbox'),
  Tribunal: await read(launch, A.PleaLaunch.abi, 'tribunal'),
  deployBlock: Number((await pub.getTransactionReceipt({ hash: hashes[0] })).blockNumber),
  owner: o, signer, signerKey: 'test key 0xa11ce (fork only)',
};
mkdirSync(OUT, { recursive: true });
writeFileSync(join(OUT, 'addresses.json'), JSON.stringify(sys, null, 1));
writeFileSync(join(OUT, 'state.hex'), await rpc('anvil_dumpState'));
console.log(JSON.stringify(sys, null, 1));
console.log(`anvil pid ${anvil.pid} on ${RPC}`);
