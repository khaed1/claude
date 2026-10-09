// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {PoolKey} from "v4-core/types/PoolKey.sol";

/// @notice One swap through a Uniswap v4 pool.
struct Hop {
    PoolKey key;
    bool zeroForOne;
}
