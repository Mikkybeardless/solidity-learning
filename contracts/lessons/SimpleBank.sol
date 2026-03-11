// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract SimpleBank {
    address public owner;
    uint public lastTransactionTime;
    mapping(address => uint256) public balance;

    event Deposit(address indexed _from, uint256 _value);
    event Withdraw(address indexed _from, uint256 _value);
    constructor() {
        owner = msg.sender;
    }

    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        balance[msg.sender] += msg.value;
        lastTransactionTime = block.timestamp;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 _amount) public {
        require(msg.sender == owner, "Not the owner");
        require(balance[msg.sender] >= _amount, "Insufficient balance");
        balance[msg.sender] -= _amount;
        lastTransactionTime = block.timestamp;
        emit Withdraw(msg.sender, _amount);
    }

    function getBalance() public view returns (uint256) {
        require(block.timestamp - lastTransactionTime < 1 minutes, "Transaction too frequent");
        return balance[msg.sender];
    }
}