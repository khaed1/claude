// Fork only: buy PLEA with native ETH (or USDC) in one Universal Router v2.1.2 execute, through IMD's ETH/IMD v4 pool then PLEA's pool.
const V = new URL('./node_modules/viem/_esm/index.js', import.meta.url).pathname;
const { createPublicClient, createWalletClient, http, parseEther, parseAbi, encodeAbiParameters, encodePacked, toHex, formatEther, formatUnits, zeroAddress } = await import(V);
const { mainnet } = await import(new URL('./node_modules/viem/_esm/chains/index.js', import.meta.url).pathname);
const [PORT, BUYER, AMT, MODE = 'eth'] = process.argv.slice(2);
const RPC = `http://127.0.0.1:${PORT}`;
const pub = createPublicClient({ transport: http(RPC), chain: mainnet });
const rpc = (m, p = []) => pub.request({ method: m, params: p });
const PLEA = '0x1f158929496162b53fb232536468948e25170ab3', IMD = '0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7', HOOK = '0xf1122bc96AdeA8768CFf2badf02b6D4594f928Cc';
const POOL4 = '0xc6c965bd164c483e87d0b550671798e9a3602840', UR = '0x23617e59a5925b2a4bf75d73ff6711cd0b29de85', QUOTER = '0x52f0e24d1c21c8a0cb1e5a5dd6198556bd9e1203';
const USDC = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48', PERMIT2 = '0x000000000022d473030f116ddee9f6b43ac78ba3';
const erc20 = parseAbi(['function balanceOf(address) view returns (uint256)', 'function approve(address,uint256) returns (bool)']);
const hookAbi = parseAbi(['function poolKey() view returns ((address currency0, address currency1, uint24 fee, int24 tickSpacing, address hooks))']);
const key = await pub.readContract({ address: HOOK, abi: hookAbi, functionName: 'poolKey' });
const buyerData = encodeAbiParameters([{ type: 'address' }], [BUYER]);
const pathKey = { type: 'tuple', components: [{ name: 'intermediateCurrency', type: 'address' }, { name: 'fee', type: 'uint24' }, { name: 'tickSpacing', type: 'int24' }, { name: 'hooks', type: 'address' }, { name: 'hookData', type: 'bytes' }] };
const path = [];
let currencyIn = zeroAddress;
if (MODE === 'usdc') { currencyIn = USDC; path.push({ intermediateCurrency: zeroAddress, fee: 500, tickSpacing: 10, hooks: zeroAddress, hookData: '0x' }); }
path.push({ intermediateCurrency: IMD, fee: 10000, tickSpacing: 60, hooks: POOL4, hookData: '0x' });
path.push({ intermediateCurrency: PLEA, fee: key.fee, tickSpacing: key.tickSpacing, hooks: key.hooks, hookData: buyerData });
const amountIn = MODE === 'usdc' ? BigInt(Math.round(Number(AMT) * 1e6)) : parseEther(AMT);
// Uniswap's V4 Quoter: quoteExactInput((exactCurrency, path, exactAmount)) -> (amountOut, gasEstimate), simulated through both hooks.
const quoterAbi = [{ type: 'function', name: 'quoteExactInput', stateMutability: 'nonpayable', inputs: [{ name: 'params', type: 'tuple', components: [{ name: 'exactCurrency', type: 'address' }, { name: 'path', type: 'tuple[]', components: pathKey.components }, { name: 'exactAmount', type: 'uint128' }] }], outputs: [{ name: 'amountOut', type: 'uint256' }, { name: 'gasEstimate', type: 'uint256' }] }];
let quote;
try { const r = await pub.simulateContract({ address: QUOTER, abi: quoterAbi, functionName: 'quoteExactInput', args: [{ exactCurrency: currencyIn, path: path.slice(0, -1), exactAmount: amountIn }], account: BUYER }); quote = r.result[0]; console.log(`quoter (to IMD): ${AMT} ${MODE} -> ${formatEther(quote)} IMD`); }
catch (e) { console.log('quoter failed:', (e.shortMessage || e.message).slice(0, 400)); }
const exactIn = (withHop) => ({ type: 'tuple', components: [{ name: 'currencyIn', type: 'address' }, { name: 'path', type: 'tuple[]', components: pathKey.components }, ...(withHop ? [{ name: 'minHopPriceX36', type: 'uint256[]' }] : []), { name: 'amountIn', type: 'uint128' }, { name: 'amountOutMinimum', type: 'uint128' }] });
await rpc('anvil_impersonateAccount', [BUYER]);
const w = createWalletClient({ account: BUYER, transport: http(RPC), chain: mainnet });
const before = await pub.readContract({ address: PLEA, abi: erc20, functionName: 'balanceOf', args: [BUYER] });
const ethBefore = await pub.getBalance({ address: BUYER });
if (MODE === 'usdc') {
  await pub.waitForTransactionReceipt({ hash: await w.writeContract({ address: USDC, abi: erc20, functionName: 'approve', args: [PERMIT2, amountIn] }) });
  const now = Number((await pub.getBlock()).timestamp);
  await pub.waitForTransactionReceipt({ hash: await w.writeContract({ address: PERMIT2, abi: parseAbi(['function approve(address,address,uint160,uint48)']), functionName: 'approve', args: [USDC, UR, amountIn, now + 1800] }) });
}
const minOut = 0n; const minPlea = BigInt(process.env.MIN_PLEA || '1');
for (const withHop of [true, false]) {
  const params = { currencyIn, path, ...(withHop ? { minHopPriceX36: path.map(() => 0n) } : {}), amountIn, amountOutMinimum: minOut };
  const actions = encodePacked(['uint8', 'uint8', 'uint8'], [0x07, 0x0c, 0x0f]);
  const swap = encodeAbiParameters([exactIn(withHop)], [params]);
  const settle = encodeAbiParameters([{ type: 'address' }, { type: 'uint256' }], [currencyIn, amountIn]);
  const take = encodeAbiParameters([{ type: 'address' }, { type: 'uint256' }], [PLEA, 0n]);
  const check = encodeAbiParameters([{ type: 'address' }, { type: 'address' }, { type: 'uint256' }], [BUYER, PLEA, before + minPlea]);
  const input = encodeAbiParameters([{ type: 'bytes' }, { type: 'bytes[]' }], [actions, [swap, settle, take]]);
  const now = Number((await pub.getBlock()).timestamp);
  try {
    const hash = await w.writeContract({ address: UR, abi: parseAbi(['function execute(bytes commands, bytes[] inputs, uint256 deadline) payable']), functionName: 'execute', args: ['0x100e', [input, check], BigInt(now + 600)], value: MODE === 'eth' ? amountIn : 0n, gas: 3_000_000n });
    const r = await pub.waitForTransactionReceipt({ hash });
    const got = (await pub.readContract({ address: PLEA, abi: erc20, functionName: 'balanceOf', args: [BUYER] })) - before;
    console.log(`execute (${withHop ? 'with' : 'without'} minHopPriceX36): status ${r.status}, gas ${r.gasUsed}, received ${formatEther(got)} PLEA; ETH spent ${formatEther(ethBefore - (await pub.getBalance({ address: BUYER })))} `);
    if (r.status === 'success') break;
  } catch (e) { console.log(`execute (${withHop ? 'with' : 'without'} minHopPriceX36) failed:`, (e.shortMessage || e.message).slice(0, 300)); }
}
