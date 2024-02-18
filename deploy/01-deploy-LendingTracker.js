const { developmentChains, networkConfig } = require("../helper-hardhat-config")
const { network, getNamedAccounts, deployments, getChainId } = require("hardhat")
const { verify } = require("../utils/verify")

module.exports = async () => {
    const { deployer } = await getNamedAccounts()
    const { deploy, log } = deployments

    args = []

    const blockConfirmations = developmentChains.includes(network.name) ? 0 : 6
    log("Deploying...")
    const lendingTracker = await deploy("LendingTracker", {
        log: true,
        from: deployer,
        waitConfirmations: blockConfirmations,
        args: args,
    })
    log("Deployed!!!")

    if (process.env.ETHERSCAN_API_KEY && !developmentChains.includes(network.name)) {
        log("Verifying...")
        await verify(lendingTracker.address, args, "contracts/Lending/LendingTracker.sol:LendingTracker")
    }
}

module.exports.tags = ["all", "lendingTracker", "tracker"]