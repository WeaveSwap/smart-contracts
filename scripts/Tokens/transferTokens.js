const { ethers, getNamedAccounts } = require("hardhat");

async function transferTokens(address, amount) {
  console.log("Connecting to the contracts...");
  const { deployer } = await getNamedAccounts();
  const token = await ethers.getContract("TestToken1", deployer);
  const token2 = await ethers.getContract("TestToken2", deployer);
  const token3 = await ethers.getContract("TestToken3", deployer);
  console.log("Connected to the contract!");

  console.log(`Transfering token ${token.target} to the address ${address}`);
  await token.transfer(address, ethers.parseEther(amount));
  await token2.transfer(address, ethers.parseEther(amount));
  await token3.transfer(address, ethers.parseEther(amount));
  console.log(`Successfully sent ${amount} tokens!`);
}

transferTokens("0xbf5FfE07d3DCCcb143EE3Fd9F38B1520a34fcB47", "20")
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
