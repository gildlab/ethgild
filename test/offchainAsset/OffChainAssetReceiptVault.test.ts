import { ReadWriteTier, TestErc20 } from "../../typechain-types";
import { ethers } from "hardhat";

import {
  getEventArgs,
  ADDRESS_ZERO,
  assertError,
  fixedPointMul,
  ONE,
  fixedPointDiv,
  fixedPointDivRound,
} from "../util";

import {
  SetERC20TierEvent,
  CertifyEvent,
  SnapshotEvent,
  SetERC1155TierEvent,
  SnapshotWithDataEvent,
} from "../../typechain-types/contracts/vault/offchainAsset/OffchainAssetReceiptVault";
import {
  deployOffChainAssetReceiptVault,
} from "./deployOffchainAssetReceiptVault";
import { ReceiptInformationEvent } from "../../typechain-types/contracts/vault/receipt/Receipt";

const assert = require("assert");

let TierV2TestContract: ReadWriteTier;

describe("OffChainAssetReceiptVault", async function () {
  beforeEach(async () => {
    const TierV2Test = await ethers.getContractFactory("ReadWriteTier");
    TierV2TestContract = (await TierV2Test.deploy()) as ReadWriteTier;
    await TierV2TestContract.deployed();
  });
  it("Checks SetERC20Tier event is emitted", async function() {
    const [vault] = await deployOffChainAssetReceiptVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).ERC20TIERER(), alice.address);
    const minTier = ethers.BigNumber.from(10);

    const { sender, tier, minimumTier, data } = (await getEventArgs(
      await vault
        .connect(alice)
        .setERC20Tier(TierV2TestContract.address, minTier, [], [1]),
      "SetERC20Tier",
      vault
    )) as SetERC20TierEvent["args"];

    assert(
      sender === alice.address,
      `wrong sender expected ${alice.address} got ${sender}`
    );
    assert(
      tier === TierV2TestContract.address,
      `wrong tier expected ${TierV2TestContract.address} got ${tier}`
    );
    assert(
      minimumTier.eq(minTier),
      `wrong minimumTier expected ${minTier} got ${minimumTier}`
    );
    assert(data === "0x01", `wrong data expected 0x01 got ${data}`);
  });
  it("Checks setERC1155Tier event is emitted", async function () {
    const [vault] = await deployOffChainAssetReceiptVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).ERC1155TIERER(), alice.address);
    const minTier = ethers.BigNumber.from(100);

    const { sender, tier, minimumTier, data } = (await getEventArgs(
      await vault
        .connect(alice)
        .setERC1155Tier(TierV2TestContract.address, minTier, [], [1]),
      "SetERC1155Tier",
      vault
    )) as SetERC1155TierEvent["args"];

    assert(
      sender === alice.address,
      `wrong sender expected ${alice.address} got ${sender}`
    );
    assert(
      tier === TierV2TestContract.address,
      `wrong tier expected ${TierV2TestContract.address} got ${tier}`
    );
    assert(
      minimumTier.eq(minTier),
      `wrong minimumTier expected ${minTier} got ${minimumTier}`
    );
    assert(data === "0x01", `wrong data expected 0x01 got ${data}`);
  });
  it("Checks totalAssets", async function () {
    const signers = await ethers.getSigners();
    const [vault] = await deployOffChainAssetReceiptVault();

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const alice = signers[0];
    const bob = signers[2];

    const shareRatio = ONE;
    const aliceAssets = ethers.BigNumber.from(1000);

    await asset.connect(alice).transfer(alice.address, aliceAssets);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAssets);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const _until = block.timestamp + 100;
    const _referenceBlockNumber = block.number;

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CERTIFIER(), bob.address);

    await vault.connect(bob).certify(_until, _referenceBlockNumber, false, []);

    await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](
        aliceAssets,
        bob.address,
        shareRatio,
        []
      );

    const totalSupply = await vault.connect(alice).totalSupply();
    const totalAssets = await vault.connect(alice).totalAssets();

    assert(
      totalSupply.eq(totalAssets),
      `Wrong total assets. Expected ${totalSupply} got ${totalAssets}`
    );
  });
  it("PreviewDeposit returns correct shares", async function () {
    const [vault] = await deployOffChainAssetReceiptVault();
    const assets = ethers.BigNumber.from(100);

    const signers = await ethers.getSigners();
    const alice = signers[0];

    const hasRoleDepositor = await vault
      .connect(alice)
      .hasRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    //Alice does not have role of depositor, so it should throw an error unless role is granted
    assert(
      !hasRoleDepositor,
      `AccessControl: account ${alice.address.toLowerCase()} is missing role DEPOSITOR`
    );

    //grant depositor role to alice
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const shares = await vault.connect(alice).previewDeposit(assets);

    assert(
      shares.eq(assets),
      `Wrong shares: expected ${assets} got ${shares} `
    );
  });
  it("PreviewMint returns correct assets", async function () {
    const [vault] = await deployOffChainAssetReceiptVault();
    const shares = ethers.BigNumber.from(10);

    const signers = await ethers.getSigners();
    const alice = signers[0];

    //grant depositor role to alice
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const assets = await vault.connect(alice).previewMint(shares);
    const expectedAssets = fixedPointDivRound(shares, ONE);
    assert(
      assets.eq(expectedAssets),
      `Wrong assets: expected ${expectedAssets} got ${assets}`
    );
  });
  it("Mints with data", async function () {
    const [vault, receipt] = await deployOffChainAssetReceiptVault();
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const assets = ethers.BigNumber.from(5000);
    await asset.transfer(alice.address, assets);
    await asset.connect(alice).increaseAllowance(vault.address, assets);

    const shares = fixedPointMul(assets, ONE).add(1);

    await vault
      .connect(alice)
      ["mint(uint256,address,uint256,bytes)"](shares, alice.address, ONE, [1]);

    const expectedAssets = fixedPointDiv(shares, ONE);
    const aliceBalanceAfter = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](alice.address, 1);

    assert(
      aliceBalanceAfter.eq(expectedAssets),
      `wrong assets. expected ${expectedAssets} got ${aliceBalanceAfter}`
    );
  });
  it("Cannot Mint to someone else if recipient is not DEPOSITOR or system not certified for them", async function () {
    const [vault] = await deployOffChainAssetReceiptVault();
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const assets = ethers.BigNumber.from(5000);
    await asset.transfer(alice.address, assets);
    await asset.connect(alice).increaseAllowance(vault.address, assets);

    const shares = fixedPointMul(assets, ONE).add(1);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["mint(uint256,address,uint256,bytes)"](shares, bob.address, ONE, [
          1,
        ]),
      `CertificationExpired`,
      "Failed to mint"
    );
  });
  it("Mints to someone else if recipient is not DEPOSITOR but system certified for them", async function () {
    const [vault, receipt] = await deployOffChainAssetReceiptVault();
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const assets = ethers.BigNumber.from(5000);
    await asset.transfer(alice.address, assets);
    await asset.connect(alice).increaseAllowance(vault.address, assets);

    const shares = fixedPointMul(assets, ONE).add(1);

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const _until = block.timestamp + 100;
    const _referenceBlockNumber = block.number;

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CERTIFIER(), bob.address);

    await vault.connect(bob).certify(_until, _referenceBlockNumber, false, []);

    await vault
      .connect(alice)
      ["mint(uint256,address,uint256,bytes)"](shares, bob.address, ONE, [1]);
    const expectedAssets = fixedPointDiv(shares, ONE);
    const bobBalanceAfter = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](bob.address, 1);

    assert(
      bobBalanceAfter.eq(expectedAssets),
      `wrong assets. expected ${expectedAssets} got ${bobBalanceAfter}`
    );
  });
  it("Mints to someone else if recipient is DEPOSITOR", async function () {
    const [vault, receipt] = await deployOffChainAssetReceiptVault();
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const assets = ethers.BigNumber.from(5000);
    await asset.transfer(alice.address, assets);
    await asset.connect(alice).increaseAllowance(vault.address, assets);

    const shares = fixedPointMul(assets, ONE).add(1);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), bob.address);

    await vault
      .connect(alice)
      ["mint(uint256,address,uint256,bytes)"](shares, bob.address, ONE, [1]);
    const expectedAssets = fixedPointDiv(shares, ONE);
    const bobBalanceAfter = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](bob.address, 1);

    assert(
      bobBalanceAfter.eq(expectedAssets),
      `wrong assets. expected ${expectedAssets} got ${bobBalanceAfter}`
    );
  });
  it("Sets correct erc20Tier and mintier", async function () {
    const [vault] = await deployOffChainAssetReceiptVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).ERC20TIERER(), alice.address);
    const minTier = ethers.BigNumber.from(10);

    const { tier, minimumTier } = (await getEventArgs(
      await vault
        .connect(alice)
        .setERC20Tier(TierV2TestContract.address, minTier, [], []),
      "SetERC20Tier",
      vault
    )) as SetERC20TierEvent["args"];

    await vault
      .connect(alice)
      .setERC20Tier(TierV2TestContract.address, minTier, [], []);

    assert(
      tier === TierV2TestContract.address,
      `wrong tier expected ${TierV2TestContract.address} got ${tier}`
    );
    assert(
      minimumTier.eq(minTier),
      `wrong minimumTier expected ${minTier} got ${minimumTier}`
    );
  });
  it("Sets correct erc11Tier and mintier", async function () {
    const [vault] = await deployOffChainAssetReceiptVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).ERC1155TIERER(), alice.address);
    const minTier = ethers.BigNumber.from(10);

    const { tier, minimumTier } = (await getEventArgs(
      await vault
        .connect(alice)
        .setERC1155Tier(TierV2TestContract.address, minTier, [], []),
      "SetERC1155Tier",
      vault
    )) as SetERC20TierEvent["args"];

    await vault
      .connect(alice)
      .setERC1155Tier(TierV2TestContract.address, minTier, [], []);

    assert(
      tier === TierV2TestContract.address,
      `wrong tier expected ${TierV2TestContract.address} got ${tier}`
    );
    assert(
      minimumTier.eq(minTier),
      `wrong minimumTier expected ${minTier} got ${minimumTier}`
    );
  });
  it("Should call multicall", async () => {
    this.timeout(0);
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const [vault, receipt] = await deployOffChainAssetReceiptVault();
    const testErc20 = await ethers.getContractFactory("TestErc20");
    const testErc20Contract = (await testErc20.deploy()) as TestErc20;
    await testErc20Contract.deployed();

    const assets = ethers.BigNumber.from(30);
    await testErc20Contract.transfer(bob.address, assets);
    await testErc20Contract
      .connect(bob)
      .increaseAllowance(vault.address, assets);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), bob.address);

    const shares = ethers.BigNumber.from(10);
    const shares2 = ethers.BigNumber.from(20);
    await vault
      .connect(bob)
      ["mint(uint256,address,uint256,bytes)"](shares, bob.address, 1, []);
    await vault
      .connect(bob)
      ["mint(uint256,address,uint256,bytes)"](shares2, bob.address, 2, []);

    let ABI = [
      "function redeem(uint256 shares_, address receiver_, address owner_, uint256 id_, bytes receiptInformation_)",
    ];
    let iface = new ethers.utils.Interface(ABI);
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).WITHDRAWER(), bob.address);

    await vault
      .connect(bob)
      .multicall(
        [
          iface.encodeFunctionData("redeem", [
            ethers.BigNumber.from(10),
            bob.address,
            bob.address,
            1,
            [],
          ]),
          iface.encodeFunctionData("redeem", [
            ethers.BigNumber.from(20),
            bob.address,
            bob.address,
            2,
            [],
          ]),
        ],
        { from: bob.address }
      );

    let balance1 = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](bob.address, 1);
    let balance2 = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](bob.address, 2);

    assert(
      balance1.eq(ethers.BigNumber.from(0)) &&
        balance2.eq(ethers.BigNumber.from(0)),
      `Shares has not been redeemed`
    );
  });
  it("Prevent authorizeReceiptTransfer if system not certified", async function () {
    const [vault] = await deployOffChainAssetReceiptVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    await assertError(
      async () =>
        await vault
          .connect(alice)
          .authorizeReceiptTransfer(alice.address, bob.address),
      "CertificationExpired",
      "failed to prevent authorizeReceiptTransfer"
    );
  });
  it("Prevent authorizeReceiptTransfer if unauthorizedSenderTier", async function () {
    const [vault] = await deployOffChainAssetReceiptVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);

    const _until = block.timestamp + 100;
    const _referenceBlockNumber = block.number;

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CERTIFIER(), alice.address);

    await vault
      .connect(alice)
      .certify(_until, _referenceBlockNumber, false, []);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).ERC1155TIERER(), alice.address);
    const minTier = ethers.BigNumber.from(1);

    await vault
      .connect(alice)
      .setERC1155Tier(TierV2TestContract.address, minTier, [], []);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          .authorizeReceiptTransfer(alice.address, bob.address),
      "UnauthorizedSenderTier",
      "failed to prevent UnauthorizedSenderTier"
    );
  });
  it("Check negative overflow", async () => {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const [vault] = await deployOffChainAssetReceiptVault();
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), bob.address);

    const shares = ethers.BigNumber.from(-1);

    await assertError(
      async () =>
        await vault
          .connect(bob)
          ["mint(uint256,address,uint256,bytes)"](shares, bob.address, 1, []),
      "out-of-bounds",
      "Failed to mint"
    );
  });
  it("Check positive overflow", async () => {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const [vault] = await deployOffChainAssetReceiptVault();
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), bob.address);

    const shares = ethers.BigNumber.from(ethers.constants.MaxUint256).add(1);

    await assertError(
      async () =>
        await vault
          .connect(bob)
          ["mint(uint256,address,uint256,bytes)"](shares, bob.address, 1, []),
      "out-of-bounds",
      "Failed to mint"
    );
  });
  it("Check the receipt info sender when depositor mints for a different receiver", async () => {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const [vault, receipt] = await deployOffChainAssetReceiptVault();

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const aliceAmount = ethers.BigNumber.from(5000);
    await asset.transfer(alice.address, aliceAmount);
    await asset.connect(alice).increaseAllowance(vault.address, aliceAmount);

    const expectedId = 1;

    const informationBytes = [125, 126];
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const _until = block.timestamp + 100;
    const _referenceBlockNumber = block.number;

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CERTIFIER(), bob.address);

    await vault.connect(bob).certify(_until, _referenceBlockNumber, false, []);

    const { sender } = (await getEventArgs(
      await vault
        .connect(alice)
        ["deposit(uint256,address,uint256,bytes)"](
          aliceAmount,
          bob.address,
          expectedId,
          informationBytes
        ),
      "ReceiptInformation",
      receipt
    )) as ReceiptInformationEvent["args"];

    assert(
      sender === alice.address,
      `wrong receipt information sender ${alice.address} got ${sender}`
    );
  });
  it("Check the receipt info sender when withdrawer burns for a different receiver", async () => {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const [vault, receipt] = await deployOffChainAssetReceiptVault();

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const aliceAmount = ethers.BigNumber.from(5000);
    await asset.transfer(alice.address, aliceAmount);
    await asset.connect(alice).increaseAllowance(vault.address, aliceAmount);

    const expectedId = 1;

    const informationBytes = [125, 126];
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).WITHDRAWER(), alice.address);

    await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](
        aliceAmount,
        alice.address,
        expectedId,
        informationBytes
      );

    const { sender } = (await getEventArgs(
      await vault
        .connect(alice)
        ["redeem(uint256,address,address,uint256,bytes)"](
          aliceAmount,
          bob.address,
          alice.address,
          expectedId,
          informationBytes
        ),
      "ReceiptInformation",
      receipt
    )) as ReceiptInformationEvent["args"];

    assert(
      sender === alice.address,
      `wrong receipt information sender ${alice.address} got ${sender}`
    );
  });
});
