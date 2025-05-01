require("@nomiclabs/hardhat-waffle")
require("@nomiclabs/hardhat-etherscan")
require("hardhat-deploy")
require("hardhat-gas-reporter")
require("hardhat-contract-sizer")
require("dotenv").config()

module.exports = {
  solidity: "0.8.20",

  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 31337,
      blockConfirmations: 1,
    },
    iota: {
      chainId: 1075,
      blockConfirmations: 6,
      url: process.env.IOTA_RPC_URL,
      accounts: [process.env.PRIVATE_KEY],
    },
  },

  etherscan: {
      apiKey: {
            'iota': 'empty',
        },
      customChains: [
            {
                network: "iota",
                chainId: 1075,
                urls: {
                    apiURL: process.env.EXPLORER_API,
                    browserURL: process.env.EXPLORER,
                },
            },
      ],
  },

  namedAccounts: {
    deployer: {
      default: 0,
    },
    player: {
      default: 1,
    },
  },
};
