import { artifacts, ethers } from "hardhat";

import type { OffchainAssetReceiptVault } from "../../typechain";
import type { Receipt } from "../../typechain";
import { OffchainAssetVaultInitializedEvent } from "../../typechain/OffchainAssetReceiptVault";
import { expectedUri, getEventArgs } from "../util";
import {
  OffchainAssetReceiptVaultFactory,
  ReceiptFactory,
} from "../../typechain";
import { Contract } from "ethers";

export const deployOffChainAssetVault = async (): Promise<
  [OffchainAssetReceiptVault, Receipt, any]
> => {
  const signers = await ethers.getSigners();
  const alice = signers[0];

  const receiptFactoryFactory = await ethers.getContractFactory(
    "ReceiptFactory"
  );
  const receiptFactoryContract =
    (await receiptFactoryFactory.deploy()) as ReceiptFactory;
  await receiptFactoryContract.deployed();

  const offchainAssetReceiptVaultFactoryFactory =
    await ethers.getContractFactory("OffchainAssetReceiptVaultFactory");

  const offchainAssetReceiptVaultFactory =
    (await offchainAssetReceiptVaultFactoryFactory.deploy(
      receiptFactoryContract.address
    )) as OffchainAssetReceiptVaultFactory;
  await offchainAssetReceiptVaultFactory.deployed();

  const constructionConfig = {
    admin: alice.address,
    vaultConfig: {
      asset: ethers.constants.AddressZero,
      name: "OffchainAssetVaul",
      symbol: "OAV",
    },
  };

  const receiptConfig = {
    uri: expectedUri,
  };

  let tx = await offchainAssetReceiptVaultFactory.createChildTyped(
    receiptConfig,
    constructionConfig
  );

  const { child } = await getEventArgs(
    tx,
    "NewChild",
    offchainAssetReceiptVaultFactory
  );

  let childContract = new Contract(
    child,
    (await artifacts.readArtifact("OffchainAssetReceiptVault")).abi
  ) as OffchainAssetReceiptVault;

  let { config } = (await getEventArgs(
    tx,
    "OffchainAssetVaultInitialized",
    childContract
  )) as OffchainAssetVaultInitializedEvent["args"];

  let receiptContractAddress = config.receiptVaultConfig.receipt;

  let receiptContract = new Contract(
    receiptContractAddress,
    (await artifacts.readArtifact("Receipt")).abi
  ) as Receipt;

  return [childContract, receiptContract, config];
};
