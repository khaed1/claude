// Probes Uniswap's Universal Router buy (and after the death, sell) path for PLEA on the mainnet fork.
//   node ur-buy.mjs <port> <addresses.json> <router> <with minHopPriceX36: 0|1> <buyer> <imd in> [seed]
import { readFileSync } from 'node:fs';
import { createPublicClient, createWalletClient, http, parseEther, encodeAbiParameters, encodePacked, parseAbi, toHex, formatEther, maxUint256, decodeErrorResult } from 'viem';
import { mainnet } from 'viem/chains';

const [PORT, ADDR, ROUTER, HOP, BUYER, AMT, SEED] = process.argv.slice(2);
const S = JSON.parse(readFileSync(ADDR, 'utf8'));
const RPC = `http://127.0.0.1:${PORT}`;
const IMD = '0xD34a99Bc0f67aE1bbd63C660e6d0b0dd03E263B7';
const PERMIT2 = '0x000000000022d473030f116ddee9f6b43ac78ba3';
const WHALE = '0xE54d6571aCa515614927F3A70B8957c2B511603C';
const pub = createPublicClient({ transport: http(RPC), chain: mainnet });
const rpc = (m, p = []) => pub.request({ method: m, params: p });
const as = async (a) => { await rpc('anvil_impersonateAccount', [a]); await rpc('anvil_setBalance', [a, toHex(parseEther('100'))]); return createWalletClient({ account: a, transport: http(RPC), chain: mainnet }); };
const erc20 = parseAbi(['function balanceOf(address) view returns (uint256)', 'function transfer(address,uint256) returns (bool)', 'function approve(address,uint256) returns (bool)']);
const permit2 = parseAbi(['function approve(address token, address spender, uint160 amount, uint48 expiration)']);
const hookAbi = parseAbi(['function poolKey() view returns ((address currency0, address currency1, uint24 fee, int24 tickSpacing, address hooks))', 'function seeded() view returns (bool)']);
const launchAbi = parseAbi(['function seed()']);
const urAbi = parseAbi(['function execute(bytes commands, bytes[] inputs, uint256 deadline) payable', 'error ExecutionFailed(uint256 commandIndex, bytes message)']);
const send = async (w, address, abi, functionName, args) => {
  const h = await w.writeContract({ address, abi, functionName, args, gas: 5_000_000n });
  const r = await pub.waitForTransactionReceipt({ hash: h });
  if (r.status !== 'success') throw new Error(functionName + ' reverted');
  return r;
};
if (SEED && !(await pub.readContract({ address: S.PleaHook, abi: hookAbi, functionName: 'seeded' }))) {
  await send(await as(S.owner), S.PleaLaunch, launchAbi, 'seed', []);
  console.log('seeded by the owner');
}
const whale = await as(WHALE);
await send(whale, IMD, erc20, 'transfer', [BUYER, parseEther('50')]);
const b = await as(BUYER);
await send(b, IMD, erc20, 'approve', [PERMIT2, maxUint256]);
const amountIn = parseEther(AMT);
await send(b, PERMIT2, permit2, 'approve', [IMD, ROUTER, amountIn, 2 ** 47]);
const key = await pub.readContract({ address: S.PleaHook, abi: hookAbi, functionName: 'poolKey' });
const zeroForOne = key.currency0.toLowerCase() === IMD.toLowerCase(); // a buy pays IMD
const hookData = encodeAbiParameters([{ type: 'address' }], [BUYER]);
const keyT = { type: 'tuple', components: [{ name: 'currency0', type: 'address' }, { name: 'currency1', type: 'address' }, { name: 'fee', type: 'uint24' }, { name: 'tickSpacing', type: 'int24' }, { name: 'hooks', type: 'address' }] };
const swapT = HOP === '1'
  ? { type: 'tuple', components: [{ name: 'poolKey', ...keyT }, { name: 'zeroForOne', type: 'bool' }, { name: 'amountIn', type: 'uint128' }, { name: 'amountOutMinimum', type: 'uint128' }, { name: 'minHopPriceX36', type: 'uint256' }, { name: 'hookData', type: 'bytes' }] }
  : { type: 'tuple', components: [{ name: 'poolKey', ...keyT }, { name: 'zeroForOne', type: 'bool' }, { name: 'amountIn', type: 'uint128' }, { name: 'amountOutMinimum', type: 'uint128' }, { name: 'hookData', type: 'bytes' }] };
const swapParams = HOP === '1'
  ? { poolKey: key, zeroForOne, amountIn, amountOutMinimum: 0n, minHopPriceX36: 0n, hookData }
  : { poolKey: key, zeroForOne, amountIn, amountOutMinimum: 0n, hookData };
const pleaToken = zeroForOne ? key.currency1 : key.currency0;
const before = await pub.readContract({ address: pleaToken, abi: erc20, functionName: 'balanceOf', args: [BUYER] });
const minOut = BigInt(process.env.MIN_OUT ?? '1');
const actions = encodePacked(['uint8', 'uint8', 'uint8'], [0x06, 0x0c, 0x0f]);
const params = [
  encodeAbiParameters([swapT], [swapParams]),
  encodeAbiParameters([{ type: 'address' }, { type: 'uint256' }], [IMD, amountIn]),
  encodeAbiParameters([{ type: 'address' }, { type: 'uint256' }], [pleaToken, 0n]),
];
const v4 = encodeAbiParameters([{ type: 'bytes' }, { type: 'bytes[]' }], [actions, params]);
const check = encodeAbiParameters([{ type: 'address' }, { type: 'address' }, { type: 'uint256' }], [BUYER, pleaToken, before + minOut]);
const commands = encodePacked(['uint8', 'uint8'], [0x10, 0x0e]);
const deadline = BigInt((await pub.getBlock()).timestamp) + 600n;
try {
  const g = await pub.estimateContractGas({ address: ROUTER, abi: urAbi, functionName: 'execute', args: [commands, [v4, check], deadline], account: BUYER });
  const h = await b.writeContract({ address: ROUTER, abi: urAbi, functionName: 'execute', args: [commands, [v4, check], deadline], gas: g * 13n / 10n });
  const r = await pub.waitForTransactionReceipt({ hash: h });
  const after = await pub.readContract({ address: pleaToken, abi: erc20, functionName: 'balanceOf', args: [BUYER] });
  console.log(JSON.stringify({ router: ROUTER, hop: HOP, status: r.status, gasEstimate: String(g), gasUsed: String(r.gasUsed), plea: formatEther(after - before), logs: r.logs.length }));
} catch (e) {
  console.log(JSON.stringify({ router: ROUTER, hop: HOP, error: (e.shortMessage || e.message).slice(0, 400), details: String(e.details || e.cause?.data || '').slice(0, 300) }));
}
