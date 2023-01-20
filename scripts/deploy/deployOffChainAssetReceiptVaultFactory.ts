// scripts/deploy.js
// @ts-ignore
import { artifacts, ethers } from "hardhat";

import {
  OffchainAssetReceiptVaultFactory,
  ReceiptFactory,
} from "../../typechain";

async function main() {
  await deployOffChainReceiptAssetVaultFactory("Mumbai");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

async function deployOffChainAssetReceiptVaultFactory(network: string) {
  console.log(network);

  const receiptFactoryFactory = await ethers.getContractFactory(
    "ReceiptFactory"
  );
  const receiptFactoryContract =
    (await receiptFactoryFactory.deploy()) as ReceiptFactory;
  await receiptFactoryContract.deployed();

  console.log(
    "receiptFactoryContract deployed to:",
    receiptFactoryContract.address
  );

  const offchainAssetReceiptVaultFactoryFactory =
    await ethers.getContractFactory("OffchainAssetReceiptVaultFactory");

  const offchainAssetReceiptVaultFactory =
    (await offchainAssetReceiptVaultFactoryFactory.deploy(
      receiptFactoryContract.address
    )) as OffchainAssetReceiptVaultFactory;
  await offchainAssetReceiptVaultFactory.deployed();

  console.log(
    "OffchainAssetVaultFactory deployed to:",
    offchainAssetReceiptVaultFactory.address
  );
}
