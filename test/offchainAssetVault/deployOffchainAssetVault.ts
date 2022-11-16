import { ethers } from "hardhat";

import type { OffchainAssetReceiptVault } from "../../typechain";
import type { Receipt } from "../../typechain";
import { OffchainAssetVaultInitializedEvent } from "../../typechain/OffchainAssetReceiptVault";
import { getEventArgs } from "../util";

export const ADDRESS_ZERO = ethers.constants.AddressZero;

export const deployOffChainAssetVault = async (): Promise<
  [OffchainAssetReceiptVault, Receipt, any]
> => {
  const signers = await ethers.getSigners();
  const alice = signers[0];

  const receipt = await ethers.getContractFactory("Receipt");
  const receiptContract = (await receipt.deploy()) as Receipt;
  await receiptContract.deployed();

  await receiptContract.initialize({
    uri: "ipfs://bafkreiahuttak2jvjzsd4r62xoxb4e2mhphb66o4cl2ntegnjridtyqnz4",
  });

  const constructionConfig = {
    admin: alice.address,
    receiptVaultConfig: {
      receipt: receiptContract.address,
      vaultConfig: {
        asset: ADDRESS_ZERO,
        name: "EthGild",
        symbol: "ETHg",
      }
    },
  };

  const offChainAssetVaultFactory = await ethers.getContractFactory(
    "OffchainAssetReceiptVault"
  );

  const offChainAssetVault =
    (await offChainAssetVaultFactory.deploy()) as OffchainAssetReceiptVault;
  await offChainAssetVault.deployed();

  const eventArgs = (await getEventArgs(
    await offChainAssetVault.initialize(constructionConfig),
    "OffchainAssetVaultInitialized",
    offChainAssetVault
  )) as OffchainAssetVaultInitializedEvent["args"];

  return [offChainAssetVault, receiptContract, eventArgs];
};
