import { ethers } from "hardhat";

import { assertError, ONE } from "../util";

import { deployOffChainAssetReceiptVault } from "./deployOffchainAssetReceiptVault";
import { TestErc20, ReadWriteTier } from "../../typechain-types";
import assert from "assert";

let TierV2TestContract: ReadWriteTier;

describe("OffChainAssetReceiptVault Roles", async function () {
  it("Checks Admin roles granted", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const [vault] = await deployOffChainAssetReceiptVault();

    const DEPOSITOR_ADMIN = await vault.connect(alice).DEPOSITOR_ADMIN();
    const WITHDRAWER_ADMIN = await vault.connect(alice).WITHDRAWER_ADMIN();
    const CERTIFIER_ADMIN = await vault.connect(alice).CERTIFIER_ADMIN();
    const HANDLER_ADMIN = await vault.connect(alice).HANDLER_ADMIN();
    const ERC20TIERER_ADMIN = await vault.connect(alice).ERC20TIERER_ADMIN();
    const ERC1155TIERER_ADMIN = await vault
      .connect(alice)
      .ERC1155TIERER_ADMIN();
    const ERC20SNAPSHOTTER_ADMIN = await vault
      .connect(alice)
      .ERC20SNAPSHOTTER_ADMIN();
    const CONFISCATOR_ADMIN = await vault.connect(alice).CONFISCATOR_ADMIN();

    const DEPOSITOR_ADMIN_Granted = await vault
      .connect(alice)
      .hasRole(DEPOSITOR_ADMIN, alice.address);
    const WITHDRAWER_ADMIN_Granted = await vault
      .connect(alice)
      .hasRole(WITHDRAWER_ADMIN, alice.address);
    const CERTIFIER_ADMIN_Granted = await vault
      .connect(alice)
      .hasRole(CERTIFIER_ADMIN, alice.address);
    const HANDLER_ADMIN_Granted = await vault
      .connect(alice)
      .hasRole(HANDLER_ADMIN, alice.address);
    const ERC20TIERER_ADMIN_Granted = await vault
      .connect(alice)
      .hasRole(ERC20TIERER_ADMIN, alice.address);
    const ERC1155TIERER_ADMIN_Granted = await vault
      .connect(alice)
      .hasRole(ERC1155TIERER_ADMIN, alice.address);
    const ERC20SNAPSHOTTER_ADMIN_Granted = await vault
      .connect(alice)
      .hasRole(ERC20SNAPSHOTTER_ADMIN, alice.address);
    const CONFISCATOR_ADMIN_Granted = await vault
      .connect(alice)
      .hasRole(CONFISCATOR_ADMIN, alice.address);

    assert(
      DEPOSITOR_ADMIN_Granted === true,
      `No ${DEPOSITOR_ADMIN_Granted} role granted`
    );
    assert(
      WITHDRAWER_ADMIN_Granted === true,
      `No ${WITHDRAWER_ADMIN_Granted} role granted`
    );
    assert(
      CERTIFIER_ADMIN_Granted === true,
      `No ${CERTIFIER_ADMIN_Granted} role granted`
    );
    assert(
      HANDLER_ADMIN_Granted === true,
      `No ${HANDLER_ADMIN_Granted} role granted`
    );
    assert(
      ERC20TIERER_ADMIN_Granted === true,
      `No ${ERC20TIERER_ADMIN_Granted} role granted`
    );
    assert(
      ERC1155TIERER_ADMIN_Granted === true,
      `No ${ERC1155TIERER_ADMIN_Granted} role granted`
    );
    assert(
      ERC20SNAPSHOTTER_ADMIN_Granted === true,
      `No ${ERC20SNAPSHOTTER_ADMIN_Granted} role granted`
    );
    assert(
      CONFISCATOR_ADMIN_Granted === true,
      `No ${CONFISCATOR_ADMIN_Granted} role granted`
    );
  });
  it("Gets 0 shares for deposit without depositor role", async function () {
    const signers = await ethers.getSigners();
    const [vault] = await deployOffChainAssetReceiptVault();

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const alice = signers[0];
    const bob = signers[1];

    const shareRatio = ONE;
    const aliceAssets = ethers.BigNumber.from(1000);

    await asset.connect(alice).transfer(alice.address, aliceAssets);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAssets);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["deposit(uint256,address,uint256,bytes)"](
            aliceAssets,
            bob.address,
            shareRatio,
            []
          ),
      `MinShareRatio`,
      "Failed to deposit"
    );
  });
  it("Checks depositor role", async function () {
    const signers = await ethers.getSigners();
    const [vault] = await deployOffChainAssetReceiptVault();

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const alice = signers[0];
    const bob = signers[1];

    const shareRatio = ONE;
    const aliceAssets = ethers.BigNumber.from(1000);

    await asset.connect(alice).transfer(alice.address, aliceAssets);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAssets);
    await vault
      .connect(alice)
      ["mint(uint256,address,uint256,bytes)"](
        aliceAssets,
        bob.address,
        shareRatio,
        []
      );
    // await assertError(
    //   async () =>
    //     await vault
    //       .connect(alice)
    //       ["deposit(uint256,address,uint256,bytes)"](
    //         aliceAssets,
    //         bob.address,
    //         shareRatio,
    //         []
    //       ),
    //   `MinShareRatio`,
    //   "Failed to deposit"
    // );
  });
  it("Checks withdraw without depositor role", async function () {
    const signers = await ethers.getSigners();
    const [vault, receipt] = await deployOffChainAssetReceiptVault();

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const alice = signers[0];
    const bob = signers[1];

    const shareRatio = ethers.BigNumber.from(1);
    const aliceAssets = ethers.BigNumber.from(10);

    await asset.connect(alice).transfer(alice.address, aliceAssets);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAssets);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](
        aliceAssets,
        bob.address,
        shareRatio,
        []
      );

    const balance = await receipt
      .connect(alice)
      .balanceOf(bob.address, shareRatio);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).WITHDRAWER(), bob.address);
    await vault
      .connect(bob)
      ["redeem(uint256,address,address,uint256)"](
        balance,
        bob.address,
        bob.address,
        shareRatio
      );

    const balanceAfter = await receipt
      .connect(alice)
      .balanceOf(bob.address, shareRatio);

    assert(
      balanceAfter.isZero(),
      `wrong assets. expected ${ethers.BigNumber.from(0)} got ${balanceAfter}`
    );
  });
  it("Checks Withdrawer role", async function () {
    const signers = await ethers.getSigners();
    const [vault, receipt] = await deployOffChainAssetReceiptVault();

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const alice = signers[0];

    const shareRatio = ethers.BigNumber.from(1);
    const aliceAssets = ethers.BigNumber.from(10);

    await asset.connect(alice).transfer(alice.address, aliceAssets);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAssets);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](
        aliceAssets,
        alice.address,
        shareRatio,
        []
      );

    const balance = await receipt
      .connect(alice)
      .balanceOf(alice.address, shareRatio);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["redeem(uint256,address,address,uint256)"](
            balance,
            alice.address,
            alice.address,
            shareRatio
          ),
      `UnauthorizedWithdraw`,
      "Failed to withdraw"
    );
  });
  it("Checks SetERC20Tier role", async function () {
    const TierV2Test = await ethers.getContractFactory("ReadWriteTier");
    TierV2TestContract = (await TierV2Test.deploy()) as ReadWriteTier;
    await TierV2TestContract.deployed();

    const [vault] = await deployOffChainAssetReceiptVault();

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
    const TierV2Test = await ethers.getContractFactory("ReadWriteTier");
    TierV2TestContract = (await TierV2Test.deploy()) as ReadWriteTier;
    await TierV2TestContract.deployed();
    const [vault] = await deployOffChainAssetReceiptVault();

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
    const [vault] = await deployOffChainAssetReceiptVault();

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
    const [vault] = await deployOffChainAssetReceiptVault();

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const _until = block.timestamp + 100;
    const _referenceBlockNumber = block.number;

    await assertError(
      async () =>
        await vault
          .connect(alice)
          .certify(_until, _referenceBlockNumber, false, []),
      `AccessControl: account ${alice.address.toLowerCase()} is missing role ${await vault
        .connect(alice)
        .CERTIFIER()}`,
      "failed to certify"
    );
  });
});
