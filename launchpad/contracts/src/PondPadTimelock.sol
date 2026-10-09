// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";

/// @title PondPadTimelock
/// @notice OpenZeppelin 5.0.2 `TimelockController` (the 48-hour and 7-day timelocks, D-57) whose delay can never go
///         below the one it was deployed with (audit R3-A4-4). The stock contract lets one delayed self-call
///         (`updateDelay(0)`) remove the delay, after which every power it owns would act at once. The delay can
///         still be raised, and lowered back to the deploy value, through the timelock itself.
/// @dev OpenZeppelin keeps its delay private, so this contract keeps its own and serves it through `getMinDelay()`,
///      which is what `schedule` checks.
contract PondPadTimelock is TimelockController {
    /// @notice The delay this timelock was deployed with: its delay is never shorter.
    uint256 public immutable minimumDelay;
    uint256 private _delay;

    error DelayBelowMinimum(uint256 requested, uint256 minimum);

    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
        TimelockController(minDelay, proposers, executors, admin)
    {
        minimumDelay = minDelay;
        _delay = minDelay;
    }

    function getMinDelay() public view override returns (uint256) {
        return _delay;
    }

    /// @notice Changes the delay; only through an operation of this timelock, and never below `minimumDelay`.
    function updateDelay(uint256 newDelay) external override {
        if (msg.sender != address(this)) revert TimelockUnauthorizedCaller(msg.sender);
        if (newDelay < minimumDelay) revert DelayBelowMinimum(newDelay, minimumDelay);
        emit MinDelayChange(_delay, newDelay);
        _delay = newDelay;
    }
}
