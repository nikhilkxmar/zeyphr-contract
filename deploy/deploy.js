const { network } = require("hardhat")
const { developmentChains } = require('../helper-hardhat.config')
const { verify } = require("../utils/verify")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const {deploy, log} = deployments
    const {deployer} = await getNamedAccounts()

    log("Deploying Admin contract...")
    const feePercent = 1
    const feeAccount = deployer 
    const adminContract = await deploy("ZeyphrAdmin", {
        from: deployer,
        args: [feePercent, feeAccount],
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    log(`Admin contract deployed at: ${adminContract.address}`)

    log("Deploying Marketplace contract...")
    const marketplaceContract = await deploy("ZeyphrMarketplace", {
        from: deployer,
        args: [adminContract.address], 
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    log(`Marketplace contract deployed at: ${marketplaceContract.address}`)

    if(!developmentChains.includes(network.name)) {
        log("Verifying contracts...")
        await verify(adminContract.address, [feePercent, feeAccount]) 
        await verify(marketplaceContract.address, [adminContract.address]) 
    }

    log("Deployment process completed")
}

module.exports.tags = ["all", "Marketplace"]