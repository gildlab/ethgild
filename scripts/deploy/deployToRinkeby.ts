// scripts/deploy.js
import { deployERC20PriceOracleVault } from "./deploy";

async function main() {
  const xauUsd = "0x81570059A0cb83888f1459Ec66Aad1Ac16730243";
  const ethUsd = "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e";
  const erc20ContractAddress = "0xc778417E063141139Fce010982780140Aa0cD5Ab";

  const erc20PriceOracleVaultConfig = {
    name: "EthGild",
    symbol: "ETHg",
    uri: "ipfs://bafkreiahuttak2jvjzsd4r62xoxb4e2mhphb66o4cl2ntegnjridtyqnz4",
  };
  const receiptConfig = {
    uri: "https://example.com",
  };

  await deployERC20PriceOracleVault(
    ethUsd,
    xauUsd,
    "Rinkeby",
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
