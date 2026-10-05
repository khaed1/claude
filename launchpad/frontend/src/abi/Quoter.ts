// Uniswap v4 Quoter (v4-periphery V4Quoter): only the multi-hop exact-in quote the site uses.
export const QuoterAbi = [
  {
    type: 'function', name: 'quoteExactInput', stateMutability: 'nonpayable',
    inputs: [{ name: 'params', type: 'tuple', components: [
      { name: 'exactCurrency', type: 'address' },
      { name: 'path', type: 'tuple[]', components: [
        { name: 'intermediateCurrency', type: 'address' }, { name: 'fee', type: 'uint24' }, { name: 'tickSpacing', type: 'int24' },
        { name: 'hooks', type: 'address' }, { name: 'hookData', type: 'bytes' } ] },
      { name: 'exactAmount', type: 'uint128' } ] }],
    outputs: [{ name: 'amountOut', type: 'uint256' }, { name: 'gasEstimate', type: 'uint256' }],
  },
] as const;
