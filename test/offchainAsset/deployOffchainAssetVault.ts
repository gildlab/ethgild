import { artifacts, ethers } from "hardhat";

import type { OffchainAssetReceiptVault } from "../../typechain-types";
import type { Receipt } from "../../typechain-types";
import { OffchainAssetReceiptVaultInitializedEvent } from "../../typechain-types/contracts/vault/offchainAsset/OffchainAssetReceiptVault";
import { expectedUri, getEventArgs } from "../util";
import {
  OffchainAssetReceiptVaultFactory,
  ReceiptFactory,
} from "../../typechain-types";
import { Contract } from "ethers";

export const deployOffchainAssetVaultFactory =
  async (): Promise<OffchainAssetReceiptVaultFactory> => {
    const offchainAssetReceiptVaultImplementationFactory =
      await ethers.getContractFactory("OffchainAssetReceiptVault");
    const offchainAssetReceiptVaultImplementation =
      (await offchainAssetReceiptVaultImplementationFactory.deploy()) as OffchainAssetReceiptVault;

    const receiptFactoryFactory = await ethers.getContractFactory(
      "ReceiptFactory"
    );
    const receiptFactoryContract =
      (await receiptFactoryFactory.deploy()) as ReceiptFactory;
    await receiptFactoryContract.deployed();

    const offchainAssetReceiptVaultFactoryFactory =
      await ethers.getContractFactory("OffchainAssetReceiptVaultFactory");

    const offchainAssetReceiptVaultFactory =
      (await offchainAssetReceiptVaultFactoryFactory.deploy({
        implementation: offchainAssetReceiptVaultImplementation.address,
        receiptFactory: receiptFactoryContract.address,
      })) as OffchainAssetReceiptVaultFactory;
    await offchainAssetReceiptVaultFactory.deployed();

    return offchainAssetReceiptVaultFactory;
  };

export const deployOffChainAssetVault = async (): Promise<
  [OffchainAssetReceiptVault, Receipt, any]
> => {
  const signers = await ethers.getSigners();
  const alice = signers[0];

  const offchainAssetReceiptVaultFactory =
    await deployOffchainAssetVaultFactory();

  const constructionConfig = {
    admin: alice.address,
    vaultConfig: {
      asset: ethers.constants.AddressZero,
      name: "OffchainAssetVaul",
      symbol: "OAV",
    },
  };

  let tx = await offchainAssetReceiptVaultFactory.createChildTyped(
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
    "OffchainAssetReceiptVaultInitialized",
    childContract
  )) as OffchainAssetReceiptVaultInitializedEvent["args"];

  let receiptContractAddress = config.receiptVaultConfig.receipt;

  let receiptContract = new Contract(
    receiptContractAddress,
    (await artifacts.readArtifact("Receipt")).abi
  ) as Receipt;

  return [childContract, receiptContract, config];
};
