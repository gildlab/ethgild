import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers"
import 'hardhat-contract-sizer';
import "hardhat-gas-reporter"

export const config = {
  networks: {
    hardhat: {
      blockGasLimit: 100000000,
      allowUnlimitedContractSize: true,
    }
  },
  solidity: {
    compilers: [
      { version: "0.8.4", settings: {
        optimizer: {
          enabled: true
        }
      } },
    ],
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 10,
  }
};
export default config