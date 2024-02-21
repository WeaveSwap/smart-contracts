const { developmentChains } = require("../helper-hardhat-config");
const { network, getNamedAccounts, deployments } = require("hardhat");
const { verify } = require("../utils/verify");

module.exports = async () => {
  const { deployer } = await getNamedAccounts();
  const { deploy, log } = deployments;

  const token1 = await ethers.getContract("TestToken1", deployer);

  args = [token1.target];

  const blockConfirmations = developmentChains.includes(network.name) ? 0 : 6;
  log("Deploying...");
  const lendingPool = await deploy("Lending", {
    log: true,
    from: deployer,
    waitConfirmations: blockConfirmations,
    args: args,
  });
  log("Deployed!!!");

  if (!developmentChains.includes(network.name)) {
    log("Verifying...");
    await verify(
      lendingTracker.address,
      args,
      "contracts/Lending/LendingTracker.sol:LendingTracker"
    );
  }
};

module.exports.tags = ["Lending", "Lendingpool"];
