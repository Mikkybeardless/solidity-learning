// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract UserProfile{
// 1. Data Types
    // uint256 is the standard for numbers (unsigned integer)
    // address is a unique Ethereum wallet ID
    address public userAddress;
    string public userName;
    uint256 private age;

    // 2. Visibility Modifiers
    // public: anyone can call (Internal + External)
    // external: ONLY callable from outside the contract (saves gas!)
    // internal: ONLY this contract and its children (inheritance)
    // private: ONLY this contract

    constructor( string memory _name, uint256 _age){
        userAddress = msg.sender; // msg.sender is a global variable for the caller
        userName = _name;
        age = _age;
    }
    // This is 'external' because we don't need to call it inside the contract

    function getPublicProfile() external view returns (address, string memory){
        return (userAddress, userName);
    }


}