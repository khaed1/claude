# Admin powers and timelocks

PondPad has no upgradeable contracts. The few settings that can change are held by two public timelocks: **48 hours** and **7 days**. The team's Safe can only propose changes; anyone can execute them once the delay has passed, and everyone can watch them wait.

| Can be changed (after the delay) | Can never be changed |
|---|---|
| Settings for **future** launches (launch fee, target, early-bird tax), within hard limits | An existing coin's fees, tax, curve or target |
| The protocol fee split, within fixed ranges | Locked liquidity: there is no way to remove it |
| Payment routes for ETH, USDG and future tokens | Pausing trading, freezing or minting tokens |
| Registering and activating new versions, after a swarm audit | Taking creator fees, dividends or staked funds |
| A move of the $PONDPAD market into a new hook in its first 12 months: approved by the 7-day timelock, then run by the team's Safe, at the same price and guards | Where coin fees go: the fee splitter and growth fund are fixed at deploy |

The team's Safe can pause **new launches** instantly (never trading) and register integrators.
