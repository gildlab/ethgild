import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "hardhat-contract-sizer";
import "hardhat-gas-reporter";
import "@nomiclabs/hardhat-etherscan";

require("dotenv").config();

const {
    RINKEBY_URL,
    PRIVATE_KEY,
    POLYGON_URL,
    ETHEREUM_URL,
    POLYGONSCAN_API_KEY,
    ETHERSCAN_API_KEY,
    SEPOLIA_URL,
} = process.env;

export const config = {
    networks: {
        // Running 'hardhat test' will use this network, which forks mainnet using the "london" hardfork
        hardhat: {
            blockGasLimit: 100000000,
            allowUnlimitedContractSize: true,
            hardfork: "london",
        },
        matic: {
            url: POLYGON_URL || "",
            accounts: PRIVATE_KEY ? [`0x${PRIVATE_KEY}`] : [],
            gasPrice: 141900000000,
        },
        ethereum: {
            url: ETHEREUM_URL || "",
            accounts: PRIVATE_KEY ? [`0x${PRIVATE_KEY}`] : [],
            gasPrice: 22000000000,
        },
        sepolia: {
            chainId: 11155111,
            url: SEPOLIA_URL || "",
            accounts: PRIVATE_KEY ? [`0x${PRIVATE_KEY}`] : [],
            gasPrice: 22000000000,
        },
        // arbitrumSepolia: {
        //     url: ARBITRUM+SEPOLIA_URL || "",
        //     accounts: PRIVATE_KEY ? [`0x${PRIVATE_KEY}`] : [],
        //     gasPrice: 22000000000,
        // },
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
        apiKey: ETHERSCAN_API_KEY,
    },
    gasReporter: {
        currency: "USD",
        gasPrice: 10,
    },
};
export default config;
