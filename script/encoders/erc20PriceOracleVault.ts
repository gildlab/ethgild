//run this script to get constructor arguments for ERC20PriceOracleVault

import { ethers, artifacts } from "hardhat";
import type { ERC20PriceOracleVault } from "../../typechain";

async function main() {
  //constants of rinkeby network
  const erc20ContractAddress = "0xc778417E063141139Fce010982780140Aa0cD5Ab";
  const priceOracleAddress = "0x6Bc5906f69883DAc8C58296282BcAB26e780fc4D";

  let erc20PriceOracleVaultConfig = {
    asset: erc20ContractAddress,
    name: "PriceOracleVault",
    symbol: "POV",
    uri: "ipfs://bafkreiahuttak2jvjzsd4r62xoxb4e2mhphb66o4cl2ntegnjridtyqnz4",
    priceOracle: priceOracleAddress,
  };

  const abi = (await artifacts.readArtifact("ERC20PriceOracleVault")).abi;
  const iface = new ethers.utils.Interface(abi);
  const constructorArgs = iface.encodeDeploy([erc20PriceOracleVaultConfig]);

  console.log(constructorArgs);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
