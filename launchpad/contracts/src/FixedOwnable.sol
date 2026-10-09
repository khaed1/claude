// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "solady/auth/Ownable.sol";

/// @title FixedOwnable
/// @notice Solady `Ownable` whose owner is fixed once the deployment hands it over (audits R3-A2-2, R3-A4-4). Every
///         PondPad contract owned by a timelock uses it: a delayed owner can't hand its powers to an undelayed
///         address, give them up, or start a handover, so every owner action keeps going through the delay that
///         D-57 promises.
/// @dev The only transfer allowed is by the account that created the contract, while it is still the owner: the
///      deploy script builds a few contracts it must configure first and then hands each to its timelock once. A
///      contract created with its timelock as owner can never change owner.
abstract contract FixedOwnable is Ownable {
    address private immutable _creator = msg.sender;

    error OwnerIsFixed();

    /// @notice Only the deployment's one handoff: the creator, while it owns the contract.
    function transferOwnership(address newOwner) public payable virtual override {
        if (msg.sender != _creator) revert OwnerIsFixed();
        super.transferOwnership(newOwner);
    }

    function renounceOwnership() public payable virtual override {
        revert OwnerIsFixed();
    }

    function requestOwnershipHandover() public payable virtual override {
        revert OwnerIsFixed();
    }

    function completeOwnershipHandover(address) public payable virtual override {
        revert OwnerIsFixed();
    }
}
