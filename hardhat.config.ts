import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-contract-sizer";
import "hardhat-gas-reporter";

require("dotenv").config();

const {
  RINKEBY_URL,
  PRIVATE_KEY,
  POLYGON_URL,
  MUMBAI_URL,
  POLYGONSCAN_API_KEY,
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
      gasPrice: 53000000000,
    },
    mumbai: {
      url: MUMBAI_URL || "https://rpc-mumbai.maticvigil.com",
      accounts: PRIVATE_KEY ? [`0x${PRIVATE_KEY}`] : [],
      gasPrice: 53000000000,
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
    apiKey: POLYGONSCAN_API_KEY,
  },
  gasReporter: {
    currency: "USD",
    gasPrice: 10,
  },
};
export default config;
