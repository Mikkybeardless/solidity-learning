import hre from "hardhat";

async function main() {
  console.log("Attempting to connect to network...");

  const result = await hre.network.connect();
  console.log("Network connect result:", result);
  console.log("Result keys:", Object.keys(result));
  console.log("viem exists?", result.viem !== undefined);

  const { viem } = result;

  if (!viem) {
    console.error("ERROR: viem is undefined!");
    console.log("Full result object:", JSON.stringify(result, null, 2));
    throw new Error("Viem client not available");
  }

  console.log("Deploying contract...");

  const [deployer] = await viem.getWalletClients();
  console.log("Deploying with account:", deployer.account.address);

  const bank = await viem.deployContract("SimpleBank");

  console.log(`SimpleBank deployed to: ${bank.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
