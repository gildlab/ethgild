//run this script to get constructor arguments for ERC20PriceOracleVault

// @ts-ignore
import { ethers, artifacts } from "hardhat";
import type { OffchainAssetReceiptVaultFactory } from "../../typechain";

async function main() {
  //receipt factory contract address 18/11/2022
  let receiptFactoryContract = "0x066cd3d1f37c7156424610ec143b1402c8ae25fa"; //000000000000000000000000066cd3d1f37c7156424610ec143b1402c8ae25fa

  const abi = (await artifacts.readArtifact("OffchainAssetReceiptVaultFactory"))
    .abi;
  const iface = new ethers.utils.Interface(abi);
  const constructorArgs = iface.encodeDeploy([receiptFactoryContract]);

  console.log(constructorArgs);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
