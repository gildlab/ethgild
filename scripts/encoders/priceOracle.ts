//run this script to get constructor arguments for ERC20PriceOracleVault

import { ethers, artifacts } from "hardhat";

async function main() {

  // base and quote of rinkeby address
  const TwoPriceOracleConfig = {
    base: "0x7d77cf76F53390EB8E84465B89f2f96b7454f298",
    quote: "0x1e8052C0a307B470400822e2fC8b987113184595",
  }

  const abi = (await artifacts.readArtifact("TwoPriceOracle")).abi
  const iface = new ethers.utils.Interface( abi )
  const constructorArgs = iface.encodeDeploy([TwoPriceOracleConfig])

  console.log(constructorArgs)

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
