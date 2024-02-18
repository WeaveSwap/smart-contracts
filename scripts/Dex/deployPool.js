const { ethers, getNamedAccounts } = require("hardhat");

async function deployPool() {
  console.log("Connecting to the contracts...");
  const { deployer } = await getNamedAccounts();
  const poolTracker = await ethers.getContract("PoolTracker", deployer);
  const token1 = await ethers.getContract("TestToken1", deployer);
  const token2 = await ethers.getContract("TestToken2", deployer);
  console.log("Connected to the contract!");

  console.log("Deploying the pool...");
  await token1.approve(poolTracker.target, ethers.parseEther("100"));
  await token2.approve(poolTracker.target, ethers.parseEther("100"));
  await poolTracker.createPool(
    token1.target,
    token2.target,
    ethers.parseEther("100"),
    ethers.parseEther("100")
  );
  console.log("Pool deployed!");
}

deployPool()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
