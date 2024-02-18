const networkConfig = {
    default: {
        name: "hardhat",
    },
    11155111: {
        name: "sepolia",
    },
    5: {
        name: "goerli",
    },
    31337: {
        name: "localhost",
    },
    mocha: {
        timeout: 200000,
    },
}

const developmentChains = ["hardhat", "localhost"]

module.exports = {
    networkConfig,
    developmentChains,
}
