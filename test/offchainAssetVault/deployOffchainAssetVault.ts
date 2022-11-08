import { ethers } from "hardhat";

import type { OffchainAssetVault } from "../../typechain";
import type { Receipt } from "../../typechain";
import { OffchainAssetVaultConstructionEvent } from "../../typechain/OffchainAssetVault";
import { getEventArgs } from "../util";

export const ADDRESS_ZERO = ethers.constants.AddressZero;

export const deployOffChainAssetVault = async (): Promise<[OffchainAssetVault, Receipt, any]> => {
  const signers = await ethers.getSigners();
  const alice = signers[ 0 ];

  const receipt = await ethers.getContractFactory("Receipt");
  const receiptContract = ( await receipt.deploy() ) as Receipt;
  await receiptContract.deployed();

  await receiptContract.initialize({ uri: "ipfs://bafkreiahuttak2jvjzsd4r62xoxb4e2mhphb66o4cl2ntegnjridtyqnz4" })

  const constructionConfig = {
    admin: alice.address,
    receiptVaultConfig: {
      asset: ADDRESS_ZERO,
      receipt: receiptContract.address,
      name: "EthGild",
      symbol: "ETHg",
    },
  };

  const offChainAssetVaultFactory = await ethers.getContractFactory(
      "OffchainAssetVault"
  );

  const offChainAssetVault = ( await offChainAssetVaultFactory.deploy() ) as OffchainAssetVault;
  await offChainAssetVault.deployed();

  const eventArgs = (await getEventArgs(
      await offChainAssetVault.initialize(constructionConfig),
      "OffchainAssetVaultConstruction",
      offChainAssetVault
  )) as OffchainAssetVaultConstructionEvent["args"];

  return [offChainAssetVault, receiptContract, eventArgs];
};
