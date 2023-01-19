import { artifacts, ethers } from "hardhat";
import {
  ADDRESS_ZERO,
  expectedUri,
  fixedPointDiv,
  fixedPointMul,
  getEventArgs,
  ONE,
} from "../util";
import { deployOffChainAssetReceiptVault } from "../offchainAsset/deployOffchainAssetReceiptVault";
import {
  Receipt,
  ReceiptFactory,
  TestErc20,
  TestReceipt, TestReceiptOwner,
} from "../../typechain-types";
import { Contract } from "ethers";

const assert = require("assert");

describe("Receipt vault", async function () {
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
  it("Initializes with factory", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const receiptFactoryFactory = await ethers.getContractFactory(
      "ReceiptFactory"
    );
    const receiptFactoryContract =
      (await receiptFactoryFactory.deploy()) as ReceiptFactory;
    await receiptFactoryContract.deployed();

    let tx = await receiptFactoryContract.createChild([]);

    const { child } = await getEventArgs(
      tx,
      "NewChild",
      receiptFactoryContract
    );

    let childContract = new Contract(
      child,
      (await artifacts.readArtifact("Receipt")).abi
    ) as Receipt;

    let uri = await childContract.connect(alice).uri(1);
    assert(uri === expectedUri, `wrong uri expected ${expectedUri} got ${uri}`);
  });
  it("Check owner", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const receiptFactoryFactory = await ethers.getContractFactory(
      "ReceiptFactory"
    );
    const receiptFactoryContract =
      (await receiptFactoryFactory.deploy()) as ReceiptFactory;
    await receiptFactoryContract.deployed();

    let tx = await receiptFactoryContract.createChild([]);

    const { child } = await getEventArgs(
      tx,
      "NewChild",
      receiptFactoryContract
    );

    let receipt = new Contract(
      child,
      (await artifacts.readArtifact("Receipt")).abi
    ) as Receipt;

    let owner = await receipt.connect(alice).owner();
    let sender = await receipt.connect(alice).signer.getAddress();

    assert(
      owner === sender,
      `Ownable: sender is not the owner. owner ${owner}, sender ${sender}`
    );
  });
  it("Check OwnerMint mints correct amount", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const testReceipt = await ethers.getContractFactory("TestReceipt");
    const receipt = (await testReceipt.deploy()) as TestReceipt;
    await receipt.deployed();

    const testReceiptOwner = await ethers.getContractFactory("TestReceiptOwner");
    const receiptOwner = (await testReceiptOwner.deploy()) as TestReceiptOwner;
    await receiptOwner.deployed();

    await receipt.setOwner(receiptOwner.address)

    await receiptOwner.setFrom(ADDRESS_ZERO)
    await receiptOwner.setTo(alice.address)

    const assets = ethers.BigNumber.from(30);
    await asset.transfer(alice.address, assets);
    await asset
        .connect(alice)
        .increaseAllowance(receiptOwner.address, assets);

    const receiptId  = ethers.BigNumber.from(1)

    const balanceBefore = await receipt.balanceOf(alice.address, receiptId)
    const shares = ethers.BigNumber.from(10);
    await receiptOwner.connect(alice).ownerMint(receipt.address, alice.address, receiptId,shares,[])

    const balanceAfter = await receipt.balanceOf(alice.address, receiptId)

    assert(
        balanceAfter.eq(balanceBefore.add(shares)),
        `Wrong balance. Expected ${balanceBefore.add(shares)}, got ${balanceAfter}`
    );
  });
  it("Check OwnerBurn burns correct amount", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const testReceipt = await ethers.getContractFactory("TestReceipt");
    const receipt = (await testReceipt.deploy()) as TestReceipt;
    await receipt.deployed();

    const testReceiptOwner = await ethers.getContractFactory("TestReceiptOwner");
    const receiptOwner = (await testReceiptOwner.deploy()) as TestReceiptOwner;
    await receiptOwner.deployed();

    await receipt.setOwner(receiptOwner.address)

    await receiptOwner.setFrom(ADDRESS_ZERO)
    await receiptOwner.setTo(alice.address)

    const assets = ethers.BigNumber.from(30);
    await asset.transfer(alice.address, assets);
    await asset
        .connect(alice)
        .increaseAllowance(receiptOwner.address, assets);

    const receiptId  = ethers.BigNumber.from(1)
    const toMint = ethers.BigNumber.from(10);
    await receiptOwner.connect(alice).ownerMint(receipt.address, alice.address, receiptId,toMint,[])

    const toBurn = ethers.BigNumber.from(5);
    await receiptOwner.setFrom(alice.address)
    await receiptOwner.setTo(ADDRESS_ZERO)

    const balanceBefore = await receipt.balanceOf(alice.address, receiptId)

    await receiptOwner.connect(alice).ownerBurn(receipt.address, alice.address, receiptId, toBurn)

    const balanceAfter = await receipt.balanceOf(alice.address, receiptId)


    assert (
        balanceAfter.eq(balanceBefore.sub(toBurn)),
        `Wrong balance. Expected ${balanceBefore.add(toBurn)}, got ${balanceAfter}`
    );
  });
});
