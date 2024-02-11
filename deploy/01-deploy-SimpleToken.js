const { developmentChains } = require("../helper-hardhat-config")
const { network, getNamedAccounts, deployments } = require("hardhat")
const { verify } = require("../utils/verify")

module.exports = async () => {
    const { deployer } = await getNamedAccounts()
    const { deploy, log } = deployments
    const args = []
    const blockConfirmations = developmentChains.includes(network.name) ? 0 : 6

    log(`Deploying to ${network.name} ...`)
    const simpleToken = await deploy("SimpleToken", {
        log: true,
        from: deployer,
        waitConfirmations: blockConfirmations,
        args: args,
    })
    log("Deployed!!!")

    if (process.env.ETHERSCAN_API_KEY && !developmentChains.includes(network.name)) {
        log("Verifying...")
        await verify(simpleToken.address, args, "contracts/SimpleToken.sol:SimpleToken")
    }
}

module.exports.tags = ["all", "token", "simpleToken"]
