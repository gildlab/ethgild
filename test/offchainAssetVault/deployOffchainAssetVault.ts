import { ethers } from "hardhat";

import type { OffchainAssetVault } from "../../typechain";
export const ADDRESS_ZERO = ethers.constants.AddressZero;

export const deployOffChainAssetVault = async (): Promise<
  [OffchainAssetVault]
> => {
  const signers = await ethers.getSigners();
  const alice = signers[0];

  const constructionConfig = {
    admin: alice.address,
    receiptVaultConfig: {
      asset: ADDRESS_ZERO,
      name: "EthGild",
      symbol: "ETHg",
      uri: "ipfs://bafkreiahuttak2jvjzsd4r62xoxb4e2mhphb66o4cl2ntegnjridtyqnz4",
    },
  };

  const offChainAssetVaultFactory = await ethers.getContractFactory(
    "OffchainAssetVault"
  );

  const offChainAssetVault = (await offChainAssetVaultFactory.deploy(
    constructionConfig
  )) as OffchainAssetVault;
  await offChainAssetVault.deployed();

  return [offChainAssetVault];
};
