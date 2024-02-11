const { developmentChains, networkConfig } = require("../helper-hardhat-config")
const { network, getNamedAccounts, deployments, getChainId } = require("hardhat")
const { verify } = require("../utils/verify")

module.exports = async () => {
    const { deployer } = await getNamedAccounts()
    const { deploy, log } = deployments

    log("Getting the addresses of tokens...")
    //GET THE TOKENS AND ADDRESSES
    const simpleToken = await ethers.getContract("SimpleToken", deployer)
    const simpleTokenAddress = simpleToken.target

    args = [simpleTokenAddress]

    const blockConfirmations = developmentChains.includes(network.name) ? 0 : 6
    log("Deploying...")
    const lending = await deploy("Lending", {
        log: true,
        from: deployer,
        waitConfirmations: blockConfirmations,
        args: args,
    })
    log("Deployed!!!")

    if (process.env.ETHERSCAN_API_KEY && !developmentChains.includes(network.name)) {
        log("Verifying...")
        await verify(lending.address, args, "contracts/Lending.sol:Lending")
    }
}

module.exports.tags = ["all", "lending", "pool"]
