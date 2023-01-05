// scripts/deploy.js
import { deployERC20PriceOracleVault } from "./deploy";

async function main() {
  const xauUsd = "0x0C466540B2ee1a31b441671eac0ca886e051E410";
  const maticUsd = "0xab594600376ec9fd91f8e885dadf0ce036862de0";
  const erc20ContractAddress = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";

  const erc20PriceOracleVaultConfig = {
    name: "PriceOracleVault",
    symbol: "POV",
    uri: "ipfs://bafkreiahuttak2jvjzsd4r62xoxb4e2mhphb66o4cl2ntegnjridtyqnz4",
  };

  const receiptConfig = {
    uri: "https://example.com",
  };

  await deployERC20PriceOracleVault(
    maticUsd,
    xauUsd,
    "Polygon",
    erc20ContractAddress,
    erc20PriceOracleVaultConfig,
    receiptConfig
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
