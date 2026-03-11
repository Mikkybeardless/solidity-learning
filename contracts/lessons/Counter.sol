// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Counter{

    uint256 private count;

//increase count
function increment() public{
    count += 1;
    }

//decrement count by 1 with a safety check
function decrement() public {
    require(count > 0, "Count cannot go below zero");
    count -= 1;
}


function getCount() public view returns (uint256) {
  return count;
}

}