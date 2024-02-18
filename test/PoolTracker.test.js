const { getNamedAccounts, deploymetns, deployments, ethers } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")
const { assert, expect } = require("chai")

describe("Pool tracker test", () => {
    let poolTracker, deployer, token1, token2, mintAmount, approveAmount, user
    beforeEach(async () => {
        mintAmount = ethers.parseEther("1000")
        approveAmount = ethers.parseEther("5000")
        await deployments.fixture(["all"])
        const accounts = await ethers.getSigners()
        user = accounts[1]
        deployer = (await getNamedAccounts()).deployer
        token1 = await ethers.getContract("SimpleToken", deployer)
        token2 = await ethers.getContract("SampleToken", deployer)
        poolTracker = await ethers.getContract("PoolTracker", deployer)
    })
    describe("Creates a pool", () => {
        it("adds Pool to mapping", async () => {
            await token1.approve(poolTracker.target, approveAmount)
            await token2.approve(poolTracker.target, approveAmount)
            await poolTracker.createPool(token1.target, token2.target, mintAmount, mintAmount)
            const array = await poolTracker.poolOwner(deployer, 0)
            expect(array).to.not.equal(undefined)
            await expect(poolTracker.poolOwner(deployer, 1)).to.be.reverted
        })
        it("emits the event", async () => {
            await token1.approve(poolTracker.target, approveAmount)
            await token2.approve(poolTracker.target, approveAmount)
            const transaction = await poolTracker.createPool(
                token1.target,
                token2.target,
                mintAmount,
                mintAmount
            )
            const txReceipt = await transaction.wait(1)
            const array = await poolTracker.poolOwner(deployer, 0)
            expect(txReceipt.logs[11].args.pool).to.equal(array)
            expect(txReceipt.logs[11].args.assetOne).to.equal(token1.target)
            expect(txReceipt.logs[11].args.assetTwo).to.equal(token2.target)
        })
        it("Enables liquidity Pool functionalities", async () => {
            await token1.approve(poolTracker.target, approveAmount)
            await token2.approve(poolTracker.target, approveAmount)
            const transaction = await poolTracker.createPool(
                token1.target,
                token2.target,
                mintAmount,
                mintAmount
            )
            const txReceipt = await transaction.wait(1)
            const poolAddress = txReceipt.logs[11].args.pool
            const poolContract = await ethers.getContractAt("LiquidityPool", poolAddress)
            expect(await poolContract.assetOneAddress()).to.equal(token1.target)
            expect(await poolContract.assetTwoAddress()).to.equal(token2.target)
        })
        it("Sets the deployer as the owner of the liquidity pool", async () => {
            await token1.approve(poolTracker.target, approveAmount)
            await token2.approve(poolTracker.target, approveAmount)
            const transaction = await poolTracker.createPool(
                token1.target,
                token2.target,
                mintAmount,
                mintAmount
            )
            const txReceipt = await transaction.wait(1)
            const poolAddress = txReceipt.logs[11].args.pool
            const poolContract = await ethers.getContractAt("LiquidityPool", poolAddress)
            expect(await poolContract.owner()).to.equal(poolTracker.target)
        })
        it("Populates the mappings and arrays", async () => {
            await token1.approve(poolTracker.target, approveAmount)
            await token2.approve(poolTracker.target, approveAmount)
            const transaction = await poolTracker.createPool(
                token1.target,
                token2.target,
                mintAmount,
                mintAmount
            )
            const txReceipt = await transaction.wait(1)
            const poolAddress = txReceipt.logs[11].args.pool

            expect(await poolTracker.poolPairs(token1.target, 0)).to.equal(token2.target)
            expect(await poolTracker.poolPairs(token2.target, 0)).to.equal(token1.target)
            expect(await poolTracker.tokens(0)).to.equal(token1.target)
            expect(await poolTracker.tokens(1)).to.equal(token2.target)
            expect(await poolTracker.pairToPool(token1.target, token2.target)).to.equal(poolAddress)
            expect(await poolTracker.pairToPool(token2.target, token1.target)).to.equal(poolAddress)
        })
        it("Revert if pool pair exists", async () => {
            await token1.approve(poolTracker.target, approveAmount)
            await token2.approve(poolTracker.target, approveAmount)
            const transaction = await poolTracker.createPool(
                token1.target,
                token2.target,
                mintAmount,
                mintAmount
            )
            await transaction.wait(1)
            await expect(
                poolTracker.createPool(token1.target, token2.target, mintAmount, mintAmount)
            ).to.be.reverted
            await expect(
                poolTracker.createPool(token2.target, token1.target, mintAmount, mintAmount)
            ).to.be.reverted
        })
    })
    describe("Routing", () => {
        it("Add a routing token", async () => {
            await poolTracker.addRoutingAddress(deployer, deployer)
            expect((await poolTracker.routingAddresses(0)).tokenAddress).to.equal(deployer)
            expect((await poolTracker.routingAddresses(0)).priceFeed).to.equal(deployer)
            await poolTracker.addRoutingAddress(deployer, token1)
            expect((await poolTracker.routingAddresses(0)).tokenAddress).to.equal(deployer)
            expect((await poolTracker.routingAddresses(0)).priceFeed).to.equal(token1.target)
        })
        it("Reverts if user not an owner", async () => {
            const userConnected = await poolTracker.connect(user)
            await expect(userConnected.addRoutingAddress(deployer, deployer)).to.be.reverted
        })
    })
})
