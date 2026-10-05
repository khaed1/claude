// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "solady/tokens/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";

/// @notice Testnet stand-in for IMD and USDG (Robinhood Chain Testnet has neither). Anyone can take `faucetAmount`
///         once per `faucetCooldown`; the owner (the setup wallet) mints freely to seed pools and bots.
///         Never deployed on mainnet.
contract TestToken is ERC20, Ownable {
    string internal _name;
    string internal _symbol;
    uint8 internal immutable _decimals;
    uint256 public immutable faucetAmount;
    uint256 public constant faucetCooldown = 1 hours;
    mapping(address => uint256) public lastFaucet;

    error FaucetCooldown(uint256 nextAt);

    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 faucetAmount_, address owner_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        faucetAmount = faucetAmount_;
        _initializeOwner(owner_);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /// @notice Public faucet: `faucetAmount` to the caller, once per hour per address.
    function faucet() external {
        uint256 next = lastFaucet[msg.sender] + faucetCooldown;
        if (lastFaucet[msg.sender] != 0 && block.timestamp < next) revert FaucetCooldown(next);
        lastFaucet[msg.sender] = block.timestamp;
        _mint(msg.sender, faucetAmount);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
