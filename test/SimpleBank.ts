import { expect } from "chai";
import hre from "hardhat";
import { parseEther } from "viem";

describe("SimpleBank", function () {
  async function deployBankFixture() {
    const { viem: viemClient } = await hre.network.connect();
    const viem = viemClient;
    // Get test accounts
    const [owner, otherAccount] = await viem.getWalletClients();
    // Deploy the contract
    const bank = await viem.deployContract("SimpleBank");
    const publicClient = await viem.getPublicClient();

    return { bank, owner, otherAccount, publicClient };
  }

  it("Should accept deposits and update balance", async function () {
    const { bank, owner, publicClient } = await deployBankFixture();

    const depositAmount = parseEther("1");

    // 1. Call the deposit function
    await bank.write.deposit([], { value: depositAmount });

    // 2. Check the contract's mapping
    const balance = await bank.read.balances([owner.account.address]);

    expect(balance).to.equal(depositAmount);
  });

  //   it("Should fail if withdrawing more than balance", async function () {
  //     const { bank } = await deployBankFixture();

  //     // We expect this to revert with our require message
  //     await expect(bank.write.withdraw([parseEther("10")])).to.be.rejectedWith(
  //       "Insufficient balance",
  //     );
  //   });
});
