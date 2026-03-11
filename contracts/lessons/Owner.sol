// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Owner {
    address public owner;

// emit event when the owner is changed
    event OwnerChanged(address indexed _oldOwner, address indexed _newOwner);
    constructor() {
        owner = msg.sender;
        emit OwnerChanged(address(0), owner);
    }

// works like middleware in express.js
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    function changeOwner(address _newOwner) external onlyOwner {
        // check if the new owner is not the zero address, juat like "if statement" in js
        require(_newOwner != address(0), "Invalid address");
        emit OwnerChanged(owner, _newOwner);
        owner = _newOwner;
    }

    function getOwner() external view returns (address) {
        return owner;
    }
}