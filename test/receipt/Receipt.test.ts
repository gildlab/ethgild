import { artifacts, ethers } from "hardhat";
import {
  expectedUri,
  fixedPointDiv,
  fixedPointMul,
  getEventArgs,
  ONE,
} from "../util";
import { deployOffChainAssetReceiptVault } from "../offchainAsset/deployOffchainAssetReceiptVault";
import { Receipt, ReceiptFactory, TestErc20, TestReceipt } from "../../typechain-types";
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
  it.only("Check OwnerMint", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const testReceipt = await ethers.getContractFactory("TestReceipt");
    const receipt = (await testReceipt.deploy()) as TestReceipt;
    await receipt.deployed();

    await receipt.setOwner(alice.address)

    // let owner = await receipt.connect(alice).owner();
    // let sender = await receipt.connect(alice).signer.getAddress();

    const assets = ethers.BigNumber.from(30);
    await asset.transfer(alice.address, assets);
    await asset
        .connect(alice)
        .increaseAllowance(receipt.address, assets);

    const shares = ethers.BigNumber.from(10);
    await receipt.connect(alice).ownerMint(alice.address, 1,shares,[])

  });
});
