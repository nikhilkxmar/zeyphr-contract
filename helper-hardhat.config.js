const { ethers } = require("hardhat")

const networkConfig = {
    1075: {
        name: 'iota',
    },
    31337: {
        name: 'hardhat',
    }
}

developmentChains = ['hardhat', 'localhost']

module.exports = {
    networkConfig,
    developmentChains,
}