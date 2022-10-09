import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "hardhat-contract-sizer";
import "hardhat-gas-reporter";

require("dotenv").config();

const { RINKEBY_URL, PRIVATE_KEY, POLYGON_URL, MUMBAI_URL } = process.env;

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
        version: "0.8.15",
        settings: {
          optimizer: {
            enabled: true,
            runs: 100,
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
