// scripts/deploy.js
// @ts-ignore
import { artifacts, ethers } from "hardhat";

import {
  OffchainAssetReceiptVault,
  OffchainAssetReceiptVaultFactory,
  ReceiptFactory,
} from "../../typechain-types";

async function main() {
  await deployOffChainAssetReceiptVaultFactory();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

async function deployOffChainAssetReceiptVaultFactory() {
  const offchainAssetReceiptVaultImplementationFactory =
    await ethers.getContractFactory("OffchainAssetReceiptVault");
  const offchainAssetReceiptVaultImplementation =
    (await offchainAssetReceiptVaultImplementationFactory.deploy()) as OffchainAssetReceiptVault;

  console.log(
    "offchainAssetReceiptVaultImplementation deployed to:",
    offchainAssetReceiptVaultImplementation.address
  );

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
    (await offchainAssetReceiptVaultFactoryFactory.deploy({
      implementation: offchainAssetReceiptVaultImplementation.address,
      receiptFactory: receiptFactoryContract.address,
    })) as OffchainAssetReceiptVaultFactory;
  await offchainAssetReceiptVaultFactory.deployed();

  console.log(
    "OffchainAssetVaultFactory deployed to:",
    offchainAssetReceiptVaultFactory.address
  );
}
