import { ReadWriteTier } from "../../typechain";
import { ethers } from "hardhat";

import {
  assertError,
} from "../util";

import { deployOffChainAssetVault } from "./deployOffchainAssetVault";

let TierV2TestContract: ReadWriteTier;

describe("OffChainAssetVault Roles", async function () {
  beforeEach(async () => {
    const TierV2Test = await ethers.getContractFactory("ReadWriteTier");
    TierV2TestContract = (await TierV2Test.deploy()) as ReadWriteTier;
    await TierV2TestContract.deployed();
  });

  it("Checks SetERC20Tier role", async function () {
    const [vault] = await deployOffChainAssetVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    const minTier = ethers.BigNumber.from(10);

    await assertError(
        async () =>
            await vault
                .connect(alice)
                .setERC20Tier(TierV2TestContract.address, minTier, []),
        `AccessControl: account ${alice.address.toLowerCase()} is missing role ${await vault
            .connect(alice)
            .ERC20TIERER()}`,
        "Failed to set erc20tier"
    );
  });
  it("Checks setERC1155Tier role", async function () {
    const [vault] = await deployOffChainAssetVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    const minTier = ethers.BigNumber.from(10);

    await assertError(
        async () =>
            await vault
                .connect(alice)
                .setERC1155Tier(TierV2TestContract.address, minTier, []),
        `AccessControl: account ${alice.address.toLowerCase()} is missing role ${await vault
            .connect(alice)
            .ERC1155TIERER()}`,
        "Failed to set erc1155tier"
    );
  });
  it("Checks role for snapshotter", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const [vault] = await deployOffChainAssetVault();

    await assertError(
        async () => await vault.connect(alice).snapshot(),
        `AccessControl: account ${alice.address.toLowerCase()} is missing role ${await vault
            .connect(alice)
            .ERC20SNAPSHOTTER()}`,
        "failed to snapshot"
    );
  });
  it("Checks role for certifier", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const [vault] = await deployOffChainAssetVault();

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const _until = block.timestamp + 100;

    await assertError(
        async () => await vault.connect(alice).certify(_until, [], false),
        `AccessControl: account ${alice.address.toLowerCase()} is missing role ${await vault
            .connect(alice)
            .CERTIFIER()}`,
        "failed to certify"
    );
  });

})