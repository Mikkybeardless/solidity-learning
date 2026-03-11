// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// 1. Import the standard implementation
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 2. Inherit from ERC20
contract MyToken is ERC20 {
    // 3. Define the Name and Symbol in the constructor
    constructor(uint256 initialSupply) ERC20("GeminiToken", "GEM") {
        // 4. Minting sends tokens to the deployer
        // _mint is an internal function provided by OpenZeppelin
        // (initialSupply * 10 ** decimals()) handles the 18 decimal places
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }
}