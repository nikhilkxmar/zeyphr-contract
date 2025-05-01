const { network } = require("hardhat")
const { developmentChains } = require('../helper-hardhat.config')
const { verify } = require("../utils/verify")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const {deploy, log} = deployments
    const {deployer} = await getNamedAccounts()

    const feePercent = 1
    const args = [feePercent]

    const Contract = await deploy("ZeyphrMarketplace", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    if(!developmentChains.includes(network.name)) {
        log("verifying")
        await verify(Contract.address, args)
    }
    log("_______________________________________")
}

module.exports.tags = ["all", "ZeyphrMarketplace"]