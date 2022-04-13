import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "hardhat-contract-sizer";
import "hardhat-gas-reporter";

require('dotenv').config();

export const config = {
  networks: {
    hardhat: {
      blockGasLimit: 100000000,
      allowUnlimitedContractSize: true,
      hardfork: "london",
    },
    rinkeby: {
      url: process.env.RINKEBY_URL,
      accounts: [ process.env.PRIVATE_KEY ],
    },    
    matic: {
      url: process.env.POLYGON_URL,
      accounts: [ process.env.PRIVATE_KEY ],
      gasPrice: 50000000000
    },   
  },
  solidity: {
    compilers: [
      {
        version: "0.8.10",
        settings: {
          optimizer: {
            enabled: true,
            runs: 100000,
          },
        },
      },
    ],
  },
  gasReporter: {
    currency: "USD",
    gasPrice: 10,
  },
};
export default config;
