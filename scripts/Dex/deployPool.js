const { ethers, getNamedAccounts } = require("hardhat");

async function deployPool() {
  console.log("Connecting to the contracts...");
  const { deployer } = await getNamedAccounts();
  const accounts = await ethers.getSigners();
  // console.log(accounts[0]);
  // console.log(deployer);
  const poolTracker = await ethers.getContract("PoolTracker", deployer);
  const token1 = await ethers.getContract("TestToken1", deployer);
  const token2 = await ethers.getContract("TestToken2", deployer);
  console.log(`This is the pool tracker address ${poolTracker.target}`);
  console.log(`This is the token1 address ${token1.target}`);
  console.log(`This is the token2 address ${token2.target}`);
  console.log("Connected to the contract!");

  console.log("Deploying the pool...");
  console.log("Approving token...");
  console.log(poolTracker.target);
  await token1.approve(poolTracker.target, ethers.parseEther("1000"));
  await token2.approve(poolTracker.target, ethers.parseEther("1000"));
  console.log(
    `This is the deployer token1 balance ${await token1.balanceOf(deployer)}`
  );
  console.log(
    `This is the deployer token2 balance ${await token2.balanceOf(deployer)}`
  );
  console.log(
    `This is the deployer token1 allowance ${await token1.allowance(
      deployer,
      poolTracker.target
    )}`
  );
  console.log(
    `This is the deployer token2 allowance ${await token2.allowance(
      deployer,
      poolTracker.target
    )}`
  );
  console.log("Tokens approved!");
  console.log("Creating Pool...");
  await poolTracker.createPool(
    token1.target,
    token2.target,
    ethers.parseEther("10"),
    ethers.parseEther("10")
  );
  console.log("Pool deployed!");
}

deployPool()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
