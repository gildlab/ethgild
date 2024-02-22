import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "hardhat-contract-sizer";
import "hardhat-gas-reporter";
import "@nomiclabs/hardhat-etherscan";

require("dotenv").config();

const {
  RINKEBY_URL,
  PRIVATE_KEY,
  PRIVATE_KEY3,
  POLYGON_URL,
  ETHEREUM_URL,
  MUMBAI_URL,
  POLYGONSCAN_API_KEY,
  GOERLI_URL,
  SEPOLIA_URL,
  ETHERSCAN_API_KEY,
  ARBITRUM_API_KEY,
  ARBITRUM_URL
} = process.env;

export const config = {
  networks: {
    hardhat: {
      blockGasLimit: 100000000,
      allowUnlimitedContractSize: true,
      hardfork: "london",
    },
    rinkeby: {
      url: RINKEBY_URL || "",
      accounts: PRIVATE_KEY ? [`0x${PRIVATE_KEY}`] : [],
      gasPrice: 11000000000,
    },
    matic: {
      url: POLYGON_URL || "",
      accounts: PRIVATE_KEY ? [`0x${PRIVATE_KEY}`] : [],
      gasPrice: 262000000000,
    },
    mumbai: {
      url: MUMBAI_URL || "https://rpc-mumbai.maticvigil.com",
      accounts: PRIVATE_KEY ? [`0x${PRIVATE_KEY}`] : [],
      gasPrice: 53000000000,
    },
    goerli: {
      url: GOERLI_URL || "",
      accounts: PRIVATE_KEY3 ? [`0x${PRIVATE_KEY3}`] : [],
      gasPrice: 22000000000,
    },
    ethereum: {
      url: ETHEREUM_URL || "",
      accounts: PRIVATE_KEY ? [`0x${PRIVATE_KEY}`] : [],
      gasPrice: 22000000000,
    },
    sepolia: {
      url: SEPOLIA_URL || "",
      accounts: PRIVATE_KEY ? [`0x${PRIVATE_KEY}`] : [],
      gasPrice: 22000000000,
    },
    arbitrum: {
      url: ARBITRUM_URL || "",
      accounts: PRIVATE_KEY3 ? [`0x${PRIVATE_KEY3}`] : [],
      gasPrice: 300000000,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 100000,
          },
        },
      },
    ],
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: ARBITRUM_API_KEY,
    customChains: [
      {
        network: "arbitrum sepolia",
        chainId: 421614,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://sepolia.arbiscan.io/"
        }
      }
    ]
  },
  gasReporter: {
    currency: "USD",
    gasPrice: 10,
  },
};
export default config;
