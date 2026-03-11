// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28; // Must match your hardhat.config.ts

contract Notepad {
    // State Variable: This is saved "on-disk" in the blockchain (expensive)
    // Similar to a private property in a TS class
    string private message;

    // The Constructor: Runs only ONCE when the contract is deployed
    constructor(string memory initialMessage) {
        message = initialMessage;
    }

    // A "Setter": Modifies state. This will cost GAS on a real network.
    function updateMessage(string memory newMessage) public {
        message = newMessage;
    }

    // A "Getter": Marked as 'view' because it only reads. 
    // Calling 'view' functions is FREE (if not called by another contract).
    function getMessage() public view returns (string memory) {
        return message;
    }
}