import { ethers } from "hardhat";

import type { OffchainAssetVault } from "../../typechain";
import type { Receipt } from "../../typechain";

export const ADDRESS_ZERO = ethers.constants.AddressZero;

export const deployOffChainAssetVault = async (): Promise<[OffchainAssetVault, Receipt]> => {
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

  const offChainAssetVault = ( await offChainAssetVaultFactory.deploy(
      constructionConfig
  ) ) as OffchainAssetVault;
  await offChainAssetVault.deployed();

  return [offChainAssetVault, receiptContract];
};
