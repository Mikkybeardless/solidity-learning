import { test, describe, before } from "node:test";
import assert from "node:assert";
import hre from "hardhat";

describe("Owner access control", () => {
  let viem: any;
  let ownerContract: any;
  let ownerWallet: any;
  let strangerWallet: any;

  before(async () => {
    const { viem: viemClient } = await hre.network.connect();
    viem = viemClient;

    const [allies, bob] = await viem.getWalletClients();
    ownerWallet = allies;
    strangerWallet = bob;

    ownerContract = await viem.deployContract("Owner");
  });

  test("Should allow owner to change owner", async () => {
    const newOwnerAddress = strangerWallet.account.address;
    //perform write as owner
    await ownerContract.write.changeOwner([newOwnerAddress]);
    const currentOwner = await ownerContract.read.getOwner();
    assert.strictEqual(
      currentOwner.toLowerCase(),
      newOwnerAddress.toLowerCase()
    );
  });
  test("Should not allow non-owner to change owner", async () => {
    const randomAddr = "0x0000000000000000000000000000000000000000";
    try {
      await ownerContract.write.changeOwner([randomAddr], {
        account: ownerWallet.account.address,
      });
      assert.fail("Should not allow non-owner to change owner");
    } catch (error) {
      // 4. Verify the revert message matches our Solidity 'require'
      assert.ok((error as Error).message.includes("Not the owner"));
    }
  });
});
