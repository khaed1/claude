// Hand-written: the parts of Uniswap's Universal Router and Permit2 the site calls (D-77).
export const UniversalRouterAbi = [
  { type: 'function', name: 'execute', stateMutability: 'payable', inputs: [{ name: 'commands', type: 'bytes' }, { name: 'inputs', type: 'bytes[]' }, { name: 'deadline', type: 'uint256' }], outputs: [] },
  { type: 'error', name: 'V4TooLittleReceived', inputs: [{ name: 'minAmountOutReceived', type: 'uint256' }, { name: 'amountReceived', type: 'uint256' }] },
  { type: 'error', name: 'TransactionDeadlinePassed', inputs: [] },
] as const;

export const Permit2Abi = [
  { type: 'function', name: 'allowance', stateMutability: 'view', inputs: [{ name: 'user', type: 'address' }, { name: 'token', type: 'address' }, { name: 'spender', type: 'address' }], outputs: [{ name: 'amount', type: 'uint160' }, { name: 'expiration', type: 'uint48' }, { name: 'nonce', type: 'uint48' }] },
  { type: 'function', name: 'approve', stateMutability: 'nonpayable', inputs: [{ name: 'token', type: 'address' }, { name: 'spender', type: 'address' }, { name: 'amount', type: 'uint160' }, { name: 'expiration', type: 'uint48' }], outputs: [] },
] as const;
