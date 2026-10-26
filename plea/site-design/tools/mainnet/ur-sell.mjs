// After the Cabal's death: an exact-input PLEA sell through the Universal Router on the mainnet fork.
//   node ur-sell.mjs <port> <addresses.json> <router> <hop 0|1> <seller> <plea amount|all>
import { readFileSync } from 'node:fs';
import { createPublicClient, createWalletClient, http, parseEther, encodeAbiParameters, encodePacked, parseAbi, toHex, formatEther, maxUint256 } from 'viem';
import { mainnet } from 'viem/chains';
const [PORT, ADDR, ROUTER, HOP, SELLER, AMT] = process.argv.slice(2);
const S = JSON.parse(readFileSync(ADDR, 'utf8'));
const RPC = `http://127.0.0.1:${PORT}`;
const IMD = '0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7';
const PERMIT2 = '0x000000000022d473030f116ddee9f6b43ac78ba3';
const pub = createPublicClient({ transport: http(RPC), chain: mainnet });
const rpc = (m, p = []) => pub.request({ method: m, params: p });
await rpc('anvil_impersonateAccount', [SELLER]);
const w = createWalletClient({ account: SELLER, transport: http(RPC), chain: mainnet });
const erc20 = parseAbi(['function balanceOf(address) view returns (uint256)', 'function approve(address,uint256) returns (bool)']);
const permit2 = parseAbi(['function approve(address token, address spender, uint160 amount, uint48 expiration)']);
const hookAbi = parseAbi(['function poolKey() view returns ((address currency0, address currency1, uint24 fee, int24 tickSpacing, address hooks))']);
const gateAbi = parseAbi(['function cabalAlive() view returns (bool)']);
const urAbi = parseAbi(['function execute(bytes commands, bytes[] inputs, uint256 deadline) payable']);
const send = async (address, abi, functionName, args) => { const h = await w.writeContract({ address, abi, functionName, args, gas: 3_000_000n }); return pub.waitForTransactionReceipt({ hash: h }); };
console.log('cabalAlive', await pub.readContract({ address: S.CabalGate, abi: gateAbi, functionName: 'cabalAlive' }));
const key = await pub.readContract({ address: S.PleaHook, abi: hookAbi, functionName: 'poolKey' });
const plea = key.currency0.toLowerCase() === IMD ? key.currency1 : key.currency0;
const bal = await pub.readContract({ address: plea, abi: erc20, functionName: 'balanceOf', args: [SELLER] });
const amountIn = AMT === 'all' ? bal : parseEther(AMT);
await send(plea, erc20, 'approve', [PERMIT2, maxUint256]);
await send(PERMIT2, permit2, 'approve', [plea, ROUTER, amountIn, 2 ** 47]);
const zeroForOne = key.currency0.toLowerCase() !== IMD; // a sell pays PLEA
const keyT = { type: 'tuple', components: [{ name: 'currency0', type: 'address' }, { name: 'currency1', type: 'address' }, { name: 'fee', type: 'uint24' }, { name: 'tickSpacing', type: 'int24' }, { name: 'hooks', type: 'address' }] };
const comps = [{ name: 'poolKey', ...keyT }, { name: 'zeroForOne', type: 'bool' }, { name: 'amountIn', type: 'uint128' }, { name: 'amountOutMinimum', type: 'uint128' }, ...(HOP === '1' ? [{ name: 'minHopPriceX36', type: 'uint256' }] : []), { name: 'hookData', type: 'bytes' }];
const minOut = BigInt(process.env.MIN_OUT ?? '1');
const p = { poolKey: key, zeroForOne, amountIn, amountOutMinimum: minOut, ...(HOP === '1' ? { minHopPriceX36: 0n } : {}), hookData: encodeAbiParameters([{ type: 'address' }], [SELLER]) };
const actions = encodePacked(['uint8', 'uint8', 'uint8'], [0x06, 0x0c, 0x0f]);
const v4 = encodeAbiParameters([{ type: 'bytes' }, { type: 'bytes[]' }], [actions, [
  encodeAbiParameters([{ type: 'tuple', components: comps }], [p]),
  encodeAbiParameters([{ type: 'address' }, { type: 'uint256' }], [plea, amountIn]),
  encodeAbiParameters([{ type: 'address' }, { type: 'uint256' }], [IMD, minOut]),
]]);
const before = await pub.readContract({ address: IMD, abi: erc20, functionName: 'balanceOf', args: [SELLER] });
try {
  const deadline = BigInt((await pub.getBlock()).timestamp) + 600n;
  const g = await pub.estimateContractGas({ address: ROUTER, abi: urAbi, functionName: 'execute', args: [encodePacked(['uint8'], [0x10]), [v4], deadline], account: SELLER });
  const r = await send(ROUTER, urAbi, 'execute', [encodePacked(['uint8'], [0x10]), [v4], deadline]);
  const after = await pub.readContract({ address: IMD, abi: erc20, functionName: 'balanceOf', args: [SELLER] });
  console.log(JSON.stringify({ status: r.status, gasEstimate: String(g), gasUsed: String(r.gasUsed), sold: formatEther(amountIn), imdOut: formatEther(after - before) }));
} catch (e) { console.log(JSON.stringify({ error: (e.shortMessage || e.message).slice(0, 300) })); }
