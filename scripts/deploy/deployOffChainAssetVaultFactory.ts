// scripts/deploy.js
import { ethers } from "hardhat";

import { OffchainAssetVaultFactory } from "../../typechain";

async function main() {

  await deployOffChainAssetVaultFactory(
      "Mumbai",
  );
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });


async function deployOffChainAssetVaultFactory (
  network: string,
) {
  console.log(network);

  const offchainAssetVaultFactoryFactory = await ethers.getContractFactory(
    "OffchainAssetVaultFactory"
  );

  const offchainAssetVaultFactory =
    (await offchainAssetVaultFactoryFactory.deploy()) as OffchainAssetVaultFactory;
  await offchainAssetVaultFactory.deployed();

  console.log(
    "OffchainAssetVaultFactory deployed to:",
      offchainAssetVaultFactory.address
  );

}
