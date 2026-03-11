import { test, describe, before } from "node:test";
import assert from "node:assert";
import hre from "hardhat";
import { getAddress } from "viem";

describe("UserProfile Contract", () => {
  let viem: any;
  let userProfile: any;
  let deployerAddress: `0x${string}`;

  before(async () => {
    const { viem: viemClient } = await hre.network.connect();
    viem = viemClient;

    // Get the first wallet (the deployer)
    const [alice] = await viem.getWalletClients();
    deployerAddress = alice.account.address;

    // Deploy with constructor arguments: [Name, Age]
    userProfile = await viem.deployContract("UserProfile", ["Alice", 25n]);
  });

  test("Should set the correct owner address", async () => {
    const savedAddress = await userProfile.read.userAddress();

    // address in Solidity is returned as a checksummed string in Viem
    assert.strictEqual(getAddress(savedAddress), getAddress(deployerAddress));
  });

  test("Should return the correct public profile", async () => {
    // getPublicProfile() returns a tuple (array) in JS/TS
    const [addr, name] = await userProfile.read.getPublicProfile();

    assert.strictEqual(name, "Alice");
    assert.strictEqual(getAddress(addr), getAddress(deployerAddress));
  });

  test("Should have age as private (internal check)", async () => {
    // We check if 'age' is a key inside the read object
    const hasAge = "age" in userProfile.read;

    assert.strictEqual(
      hasAge,
      false,
      "Age should not be accessible via the read interface"
    );
  });
});
