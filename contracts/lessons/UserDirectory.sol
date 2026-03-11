// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract UserDirectory {
    // 1. Define the "Schema" (Like a TS Interface)
    struct User {
        string name;
        uint256 joinedAt;
        bool isActive;
    }

    // 2. The "Database" (A mapping from Address to our User struct)
    // In JS: const users = new Map<string, User>();
    mapping(address => User) public users;

    // 3. Logic to save a user
    function register(string memory _name) public {
        // Create the user and save it to the mapping using msg.sender as the key
        users[msg.sender] = User({
            name: _name,
            joinedAt: block.timestamp, // The time this block was mined
            isActive: true
        });
    }

    // 4. Check if a user exists
    function isUserRegistered(address _user) public view returns (bool) {
        return users[_user].isActive;
    }
}