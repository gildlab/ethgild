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
  it("PreviewWithdraw returns 0 shares if no withdrawer role", async function () {
    const [vault] = await deployOffChainAssetReceiptVault();
    const assets = ethers.BigNumber.from(100);

    const signers = await ethers.getSigners();
    const alice = signers[0];

    const id = ethers.BigNumber.from(1);

    const expectedShares = ethers.BigNumber.from(0);

    const shares = await vault
      .connect(alice)
      ["previewWithdraw(uint256,uint256)"](assets, id);

    assert(
      shares.eq(expectedShares),
      `Wrong shares: expected ${expectedShares} got ${shares} `
    );
  });
  it("PreviewWithdraw returns correct shares", async function () {
    const [vault] = await deployOffChainAssetReceiptVault();
    const assets = ethers.BigNumber.from(10);

    const signers = await ethers.getSigners();
    const alice = signers[0];

    //assets are always deposited 1:1 with shares
    const id = ONE;

    //grant withdrawer role to alice
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).WITHDRAWER(), alice.address);

    const expectedShares = fixedPointMul(assets, id);

    const shares = await vault
      .connect(alice)
      ["previewWithdraw(uint256,uint256)"](assets, id);

    assert(
      shares.eq(expectedShares),
      `Wrong shares: expected ${expectedShares} got ${shares} `
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
  it("Cannot Deposit to someone else if recipient is not DEPOSITOR or system not certified for them", async function () {
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

    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["deposit(uint256,address,uint256,bytes)"](assets, bob.address, ONE, [
            1,
          ]),
      `CertificationExpired`,
      "Failed to mint"
    );
  });
  it("Deposits to someone else if recipient is not DEPOSITOR but system certified for them", async function () {
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
      ["deposit(uint256,address,uint256,bytes)"](assets, bob.address, ONE, [1]);
    const bobBalanceAfter = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](bob.address, 1);

    assert(
      bobBalanceAfter.eq(assets),
      `wrong assets. expected ${assets} got ${bobBalanceAfter}`
    );
  });
  it("Deposits to someone else if recipient is DEPOSITOR", async function () {
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

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), bob.address);

    await vault
      .connect(alice)
      ["mint(uint256,address,uint256,bytes)"](assets, bob.address, ONE, [1]);
    const bobBalanceAfter = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](bob.address, 1);

    assert(
      bobBalanceAfter.eq(assets),
      `wrong assets. expected ${assets} got ${bobBalanceAfter}`
    );
  });
  it("PreviewRedeem returns correct assets", async function () {
    const [vault] = await deployOffChainAssetReceiptVault();
    const shares = ethers.BigNumber.from(100);

    const signers = await ethers.getSigners();
    const alice = signers[0];

    const id = ONE;

    const hasRoleDepositor = await vault
      .connect(alice)
      .hasRole(await vault.connect(alice).WITHDRAWER(), alice.address);

    //Alice does not have role of withdrawer, so it should throw an error unless role is granted
    assert(
      !hasRoleDepositor,
      `AccessControl: account ${alice.address.toLowerCase()} is missing role WITHDRAWER`
    );

    //grant withdrawer role to alice
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).WITHDRAWER(), alice.address);

    const expectedAssets = fixedPointDiv(shares, id);
    const assets = await vault
      .connect(alice)
      ["previewRedeem(uint256,uint256)"](shares, id);

    assert(
      assets.eq(expectedAssets),
      `Wrong assets: expected ${expectedAssets} got ${assets} `
    );
  });
  it("PreviewRedeem returns 0 shares if no withdrawer role", async function () {
    const [vault] = await deployOffChainAssetReceiptVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const receiptId = ethers.BigNumber.from(1);
    const aliceAssets = ethers.BigNumber.from(20);

    const shares = fixedPointMul(aliceAssets, receiptId);

    await asset.connect(alice).transfer(alice.address, aliceAssets);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAssets);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const assetToDeposit = aliceAssets.div(2);
    await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](
        assetToDeposit,
        alice.address,
        receiptId,
        []
      );

    const expectedAssets = ethers.BigNumber.from(0);
    const assets = await vault
      .connect(alice)
      ["previewRedeem(uint256,uint256)"](shares, receiptId);

    assert(
      assets.eq(expectedAssets),
      `Wrong assets: expected ${expectedAssets} got ${assets} `
    );
  });
  it("Redeposits", async function () {
    const signers = await ethers.getSigners();
    const [vault, receipt] = await deployOffChainAssetReceiptVault();

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const alice = signers[0];

    const receiptId = ethers.BigNumber.from(1);
    const aliceAssets = ethers.BigNumber.from(20);

    await asset.connect(alice).transfer(alice.address, aliceAssets);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAssets);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const assetToDeposit = aliceAssets.div(2);
    const assetToReDeposit = ethers.BigNumber.from(10);
    await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](
        assetToDeposit,
        alice.address,
        receiptId,
        []
      );

    const aliceReceiptBalance = await receipt
      .connect(alice)
      .balanceOf(alice.address, receiptId);

    await vault
      .connect(alice)
      .redeposit(assetToReDeposit, alice.address, 1, [1]);

    const aliceReceiptBalanceAfterRedeposit = await receipt
      .connect(alice)
      .balanceOf(alice.address, receiptId);

    assert(
      aliceReceiptBalanceAfterRedeposit.eq(
        aliceReceiptBalance.add(assetToReDeposit)
      ),
      `Incorrect balance ${aliceReceiptBalance.add(
        assetToReDeposit
      )} got ${aliceReceiptBalanceAfterRedeposit}`
    );
  });
  it("Prevents redeposit to someone else while not certified or recipient is not depositor", async function () {
    const signers = await ethers.getSigners();
    const [vault] = await deployOffChainAssetReceiptVault();

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const alice = signers[0];
    const bob = signers[1];

    const receiptId = ethers.BigNumber.from(1);
    const aliceAssets = ethers.BigNumber.from(20);

    await asset.connect(alice).transfer(alice.address, aliceAssets);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAssets);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const assetToDeposit = aliceAssets.div(2);
    const assetToReDeposit = ethers.BigNumber.from(10);
    await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](
        assetToDeposit,
        alice.address,
        receiptId,
        []
      );

    await assertError(
      async () =>
        await vault
          .connect(alice)
          .redeposit(assetToReDeposit, bob.address, 1, [1]),
      `CertificationExpired`,
      "Failed to redeposit"
    );
  });
  it("Redeposits to someone else while certified", async function () {
    const signers = await ethers.getSigners();
    const [vault, receipt] = await deployOffChainAssetReceiptVault();

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const alice = signers[0];
    const bob = signers[1];

    const receiptId = ethers.BigNumber.from(1);
    const aliceAssets = ethers.BigNumber.from(20);

    await asset.connect(alice).transfer(alice.address, aliceAssets);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAssets);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const assetToDeposit = aliceAssets.div(2);
    const assetToReDeposit = ethers.BigNumber.from(10);
    await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](
        assetToDeposit,
        alice.address,
        receiptId,
        []
      );

    const bobReceiptBalance = await receipt
      .connect(alice)
      .balanceOf(bob.address, receiptId);

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const _certifiedUntil = block.timestamp + 100;
    const _referenceBlockNumber = block.number;
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CERTIFIER(), alice.address);
    await vault
      .connect(alice)
      .certify(_certifiedUntil, _referenceBlockNumber, false, []);

    await vault.connect(alice).redeposit(assetToReDeposit, bob.address, 1, [1]);

    const bobReceiptBalanceAfterRedeposit = await receipt
      .connect(alice)
      .balanceOf(bob.address, receiptId);

    assert(
      bobReceiptBalanceAfterRedeposit.eq(
        bobReceiptBalance.add(assetToReDeposit)
      ),
      `Incorrect balance ${bobReceiptBalance.add(
        assetToReDeposit
      )} got ${bobReceiptBalanceAfterRedeposit}`
    );
  });
  it("Prevents Redeposit on receipt with id 0", async function () {
    const signers = await ethers.getSigners();
    const [vault] = await deployOffChainAssetReceiptVault();

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const alice = signers[0];

    const assetToReDeposit = ethers.BigNumber.from(10);

    const id = 0;

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          .redeposit(assetToReDeposit, alice.address, id, [1]),
      `InvalidId`,
      "Failed to redeposit"
    );
  });
  it("Prevents Redeposit on non-existing receipt", async function () {
    const signers = await ethers.getSigners();
    const [vault] = await deployOffChainAssetReceiptVault();

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const alice = signers[0];

    const assetToReDeposit = ethers.BigNumber.from(10);

    const id = 2;

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          .redeposit(assetToReDeposit, alice.address, id, [1]),
      `InvalidId(${id})`,
      "Failed to prevent redeposit"
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
  it("Checks Certify event is emitted", async function () {
    const [vault] = await deployOffChainAssetReceiptVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    //get block timestamp and add 100 to get _until
    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const _until = block.timestamp + 100;
    const _referenceBlockNumber = block.number;

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CERTIFIER(), alice.address);

    const { sender, certifyUntil, referenceBlockNumber } = (await getEventArgs(
      await vault
        .connect(alice)
        .certify(_until, _referenceBlockNumber, false, []),
      "Certify",
      vault
    )) as CertifyEvent["args"];

    assert(
      sender === alice.address,
      `wrong sender expected ${alice.address} got ${sender}`
    );
    assert(
      certifyUntil.eq(_until),
      `wrong until expected ${_until} got ${certifyUntil}`
    );
    assert(
      referenceBlockNumber.eq(_referenceBlockNumber),
      `wrong referenceBlockNumber expected ${_referenceBlockNumber} got ${referenceBlockNumber}`
    );
  });
  it("Certifies with data", async function () {
    const [vault] = await deployOffChainAssetReceiptVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    //get block timestamp and add 100 to get _until
    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const _until = block.timestamp + 100;
    const _referenceBlockNumber = block.number;

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CERTIFIER(), alice.address);

    const { sender, certifyUntil, referenceBlockNumber, data } =
      (await getEventArgs(
        await vault
          .connect(alice)
          .certify(_until, _referenceBlockNumber, false, [1, 7]),
        "Certify",
        vault
      )) as CertifyEvent["args"];

    assert(
      sender === alice.address,
      `wrong sender expected ${alice.address} got ${sender}`
    );
    assert(data === "0x0107", `wrong data expected 0x0107 got ${data}`);
    assert(
      certifyUntil.eq(_until),
      `wrong until expected ${_until} got ${certifyUntil}`
    );
    assert(
      referenceBlockNumber.eq(_referenceBlockNumber),
      `wrong referenceBlockNumber expected ${_referenceBlockNumber} got ${referenceBlockNumber}`
    );
  });
  it("Certify in the past relative to the existing certification time with forceUntil true", async function () {
    const [vault] = await deployOffChainAssetReceiptVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const _until = block.timestamp + 100;
    const _referenceBlockNumber = block.number;

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CERTIFIER(), alice.address);

    const { certifyUntil } = (await getEventArgs(
      await vault
        .connect(alice)
        .certify(_until, _referenceBlockNumber, false, []),
      "Certify",
      vault
    )) as CertifyEvent["args"];

    const _untilPast = certifyUntil.sub(100);

    const eventArgs = (await getEventArgs(
      await vault
        .connect(alice)
        .certify(_untilPast, _referenceBlockNumber, true, []),
      "Certify",
      vault
    )) as CertifyEvent["args"];

    assert(
      eventArgs.certifyUntil.eq(_untilPast),
      `wrong until expected ${_untilPast} got ${eventArgs.certifyUntil}`
    );
  });
  it("Checks certifiedUntil is not zero", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const [vault] = await deployOffChainAssetReceiptVault();

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const _certifiedUntil = ethers.BigNumber.from(0);
    const _referenceBlockNumber = block.number;

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CERTIFIER(), alice.address);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          .certify(_certifiedUntil, _referenceBlockNumber, false, []),
      `ZeroCertifyUntil`,
      "failed to certify"
    );
  });
  it("Checks referenceBlockNumber is less than block number", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const [vault] = await deployOffChainAssetReceiptVault();

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const _certifiedUntil = block.timestamp + 100;
    const _referenceBlockNumber = blockNum + 10;

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CERTIFIER(), alice.address);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          .certify(_certifiedUntil, _referenceBlockNumber, false, []),
      `FutureReferenceBlock`,
      "failed to certify"
    );
  });
  it("Certifies", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const [vault] = await deployOffChainAssetReceiptVault();

    const blockNum = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNum);
    const _certifiedUntil = block.timestamp + 100;
    const _referenceBlockNumber = block.number;

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).CERTIFIER(), alice.address);

    const { certifyUntil } = (await getEventArgs(
      await vault
        .connect(alice)
        .certify(_certifiedUntil, _referenceBlockNumber, false, []),
      "Certify",
      vault
    )) as CertifyEvent["args"];

    assert(
      certifyUntil.eq(_certifiedUntil),
      `wrong until expected ${_certifiedUntil} got ${certifyUntil}`
    );
  });
  it("AuthorizeReceiptTransfer reverts if certification expired", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const [vault] = await deployOffChainAssetReceiptVault();

    await assertError(
      async () =>
        await vault
          .connect(alice)
          .authorizeReceiptTransfer(alice.address, alice.address),
      `CertificationExpired`,
      "failed to AuthorizeReceiptTransfer"
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
  it("Should not withdraw on more than balance", async function () {
    const [vault, receipt] = await deployOffChainAssetReceiptVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];
    const id = ethers.BigNumber.from(1);

    //grant depositor role to alice
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const testErc20Contract = (await testErc20.deploy()) as TestErc20;
    await testErc20Contract.deployed();

    const assets = ethers.BigNumber.from(30);
    await testErc20Contract.transfer(alice.address, assets);
    await testErc20Contract
      .connect(alice)
      .increaseAllowance(vault.address, assets);

    const shares = ethers.BigNumber.from(10);
    await vault
      .connect(alice)
      ["mint(uint256,address,uint256,bytes)"](shares, alice.address, 1, []);

    const balance = await receipt.connect(alice).balanceOf(alice.address, id);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).WITHDRAWER(), alice.address);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["redeem(uint256,address,address,uint256,bytes)"](
            balance.add(1),
            alice.address,
            alice.address,
            id,
            []
          ),
      "ERC20: burn amount exceeds balance",
      "failed to prevent withdraw on more than balance"
    );
  });
  it("User not being able to withdraw someone else's share", async function () {
    const [vault, receipt] = await deployOffChainAssetReceiptVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];
    const id = ethers.BigNumber.from(1);

    //grant depositor role to alice
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const testErc20Contract = (await testErc20.deploy()) as TestErc20;
    await testErc20Contract.deployed();

    const assets = ethers.BigNumber.from(30);
    await testErc20Contract.transfer(alice.address, assets);
    await testErc20Contract
      .connect(alice)
      .increaseAllowance(vault.address, assets);

    const shares = ethers.BigNumber.from(10);
    await vault
      .connect(alice)
      ["mint(uint256,address,uint256,bytes)"](shares, alice.address, 1, []);

    const balance = await receipt.connect(alice).balanceOf(alice.address, id);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).WITHDRAWER(), alice.address);

    await assertError(
      async () =>
        await vault
          .connect(bob)
          ["redeem(uint256,address,address,uint256,bytes)"](
            balance,
            alice.address,
            alice.address,
            id,
            []
          ),
      "ERC20: insufficient allowance",
      "failed to prevent withdraw on someone else's shares"
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
  it("Withdraw on someone else", async function () {
    const [vault, receipt] = await deployOffChainAssetReceiptVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];
    const id = 1;

    //grant depositor role to alice
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const testErc20Contract = (await testErc20.deploy()) as TestErc20;
    await testErc20Contract.deployed();

    const assets = ethers.BigNumber.from(30);
    await testErc20Contract.transfer(alice.address, assets);
    await testErc20Contract
      .connect(alice)
      .increaseAllowance(vault.address, assets);

    const shares = ethers.BigNumber.from(10);
    await vault
      .connect(alice)
      ["mint(uint256,address,uint256,bytes)"](shares, alice.address, id, []);

    const balance = await receipt.connect(alice).balanceOf(alice.address, id);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).WITHDRAWER(), alice.address);

    let bobBalanceVault = await vault.connect(alice).balanceOf(bob.address);
    let aliceBalanceVault = await vault.connect(alice).balanceOf(alice.address);

    await vault
      .connect(alice)
      ["withdraw(uint256,address,address,uint256,bytes)"](
        balance,
        bob.address,
        alice.address,
        id,
        []
      );

    let bobBalanceVaultAft = await vault.connect(alice).balanceOf(bob.address);
    let aliceBalanceVaultAft = await vault
      .connect(alice)
      .balanceOf(alice.address);

    assert(
      bobBalanceVaultAft.eq(bobBalanceVault),
      `Wrong shares for bob ${bobBalanceVaultAft} got ${bobBalanceVaultAft}`
    );
    assert(
      aliceBalanceVaultAft.eq(aliceBalanceVault.sub(balance)),
      `Wrong shares for alice ${aliceBalanceVault.sub(
        balance
      )} got ${aliceBalanceVaultAft}`
    );
  });
  it("Check withdraw for alice", async function () {
    const [vault, receipt] = await deployOffChainAssetReceiptVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];
    const id = 1;

    //grant depositor role to alice
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const testErc20Contract = (await testErc20.deploy()) as TestErc20;
    await testErc20Contract.deployed();

    const assets = ethers.BigNumber.from(30);
    await testErc20Contract.transfer(alice.address, assets);
    await testErc20Contract
      .connect(alice)
      .increaseAllowance(vault.address, assets);

    const shares = ethers.BigNumber.from(10);
    await vault
      .connect(alice)
      ["mint(uint256,address,uint256,bytes)"](shares, alice.address, id, []);

    const balance = await receipt.connect(alice).balanceOf(alice.address, id);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).WITHDRAWER(), alice.address);

    let aliceSharesBef = await receipt
      .connect(alice)
      .balanceOf(alice.address, id);

    await vault
      .connect(alice)
      ["withdraw(uint256,address,address,uint256,bytes)"](
        balance,
        alice.address,
        alice.address,
        id,
        []
      );

    let aliceSharesAft = await receipt
      .connect(alice)
      .balanceOf(alice.address, id);
    let aliceAssetsAft = await vault.connect(alice).balanceOf(alice.address);

    assert(
      aliceSharesBef.eq(balance),
      `Wrong shares ${balance} got ${aliceSharesBef}`
    );
    assert(
      aliceAssetsAft.eq(0),
      `Wrong assets after withdraw ${0} got ${aliceAssetsAft}`
    );
    assert(
      aliceSharesAft.eq(0),
      `Wrong shares after withdraw ${0} got ${aliceSharesAft}`
    );
  });
  it("Redeems on someone else", async function () {
    const [vault, receipt] = await deployOffChainAssetReceiptVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];
    const id = 1;

    //grant depositor role to alice
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const testErc20Contract = (await testErc20.deploy()) as TestErc20;
    await testErc20Contract.deployed();

    const assets = ethers.BigNumber.from(30);
    await testErc20Contract.transfer(alice.address, assets);
    await testErc20Contract
      .connect(alice)
      .increaseAllowance(vault.address, assets);

    const shares = ethers.BigNumber.from(10);
    await vault
      .connect(alice)
      ["mint(uint256,address,uint256,bytes)"](shares, alice.address, id, []);

    const balance = await receipt.connect(alice).balanceOf(alice.address, id);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).WITHDRAWER(), alice.address);

    let bobBalanceVault = await vault.connect(alice).balanceOf(bob.address);
    let aliceBalanceVault = await vault.connect(alice).balanceOf(alice.address);

    await vault
      .connect(alice)
      ["redeem(uint256,address,address,uint256,bytes)"](
        balance,
        bob.address,
        alice.address,
        id,
        []
      );

    let bobBalanceVaultAft = await vault.connect(alice).balanceOf(bob.address);
    let aliceBalanceVaultAft = await vault
      .connect(alice)
      .balanceOf(alice.address);

    assert(
      bobBalanceVaultAft.eq(bobBalanceVault),
      `Wrong shares for bob ${bobBalanceVaultAft} got ${bobBalanceVaultAft}`
    );
    assert(
      aliceBalanceVaultAft.eq(aliceBalanceVault.sub(balance)),
      `Wrong shares for alice ${aliceBalanceVault.sub(
        balance
      )} got ${aliceBalanceVaultAft}`
    );
  });
  it("Check redeem for alice", async function () {
    const [vault, receipt] = await deployOffChainAssetReceiptVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];
    const id = 1;

    //grant depositor role to alice
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const testErc20Contract = (await testErc20.deploy()) as TestErc20;
    await testErc20Contract.deployed();

    const assets = ethers.BigNumber.from(30);
    await testErc20Contract.transfer(alice.address, assets);
    await testErc20Contract
      .connect(alice)
      .increaseAllowance(vault.address, assets);

    const shares = ethers.BigNumber.from(10);
    await vault
      .connect(alice)
      ["mint(uint256,address,uint256,bytes)"](shares, alice.address, id, []);

    const balance = await receipt.connect(alice).balanceOf(alice.address, id);

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).WITHDRAWER(), alice.address);

    let aliceSharesBef = await receipt
      .connect(alice)
      .balanceOf(alice.address, id);

    await vault
      .connect(alice)
      ["redeem(uint256,address,address,uint256,bytes)"](
        balance,
        alice.address,
        alice.address,
        id,
        []
      );

    let aliceSharesAft = await receipt
      .connect(alice)
      .balanceOf(alice.address, id);
    let aliceAssetsAft = await vault.connect(alice).balanceOf(alice.address);

    assert(
      aliceSharesBef.eq(balance),
      `Wrong shares ${balance} got ${aliceSharesBef}`
    );
    assert(
      aliceAssetsAft.eq(0),
      `Wrong assets after withdraw ${0} got ${aliceAssetsAft}`
    );
    assert(
      aliceSharesAft.eq(0),
      `Wrong shares after withdraw ${0} got ${aliceSharesAft}`
    );
  });
});
