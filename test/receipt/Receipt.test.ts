import { artifacts, ethers } from "hardhat";
import { fixedPointDiv, fixedPointMul, getEventArgs, ONE } from "../util";
import { deployOffChainAssetVault } from "../offchainAsset/deployOffchainAssetVault";
import { Receipt, ReceiptFactory, TestErc20 } from "../../typechain-types";
import { Contract } from "ethers";

const assert = require("assert");

describe("Receipt vault", async function () {
  it("Mints with data", async function () {
    const [vault, receipt] = await deployOffChainAssetVault();
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

    const receiptConfig = {
      uri: "example.com",
    };
    let tx = await receiptFactoryContract.createChildTyped(receiptConfig);

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
    assert(
      uri === receiptConfig.uri,
      `wrong uri expected ${receiptConfig.uri} got ${uri}`
    );
  });
  it("check owner", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const receiptFactoryFactory = await ethers.getContractFactory(
      "ReceiptFactory"
    );
    const receiptFactoryContract =
      (await receiptFactoryFactory.deploy()) as ReceiptFactory;
    await receiptFactoryContract.deployed();

    const receiptConfig = {
      uri: "example.com",
    };
    let tx = await receiptFactoryContract.createChildTyped(receiptConfig);

    const { child } = await getEventArgs(
      tx,
      "NewChild",
      receiptFactoryContract
    );

    let receipt = new Contract(
      child,
      (await artifacts.readArtifact("Receipt")).abi
    ) as Receipt;

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const testErc20Contract = (await testErc20.deploy()) as TestErc20;
    await testErc20Contract.deployed();

    const assets = ethers.BigNumber.from(30);
    await testErc20Contract.transfer(alice.address, assets);
    await testErc20Contract
      .connect(alice)
      .increaseAllowance(receipt.address, assets);

    // const shares = ethers.BigNumber.from(10);
    // await receipt.connect(alice).ownerMint(alice.address, 1,shares,[])

    let owner = await receipt.connect(alice).owner();
    let caller = await receipt.connect(alice).signer.getAddress();

    assert(
      owner === caller,
      `Ownable: caller is not the owner. owner ${owner}, caller ${caller}`
    );
  });
  it("Preview Mint", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const receiptFactoryFactory = await ethers.getContractFactory(
      "ReceiptFactory"
    );
    const receiptFactoryContract =
      (await receiptFactoryFactory.deploy()) as ReceiptFactory;
    await receiptFactoryContract.deployed();

    const receiptConfig = {
      uri: "example.com",
    };
    let tx = await receiptFactoryContract.createChildTyped(receiptConfig);

    const { child } = await getEventArgs(
      tx,
      "NewChild",
      receiptFactoryContract
    );

    let receipt = new Contract(
      child,
      (await artifacts.readArtifact("Receipt")).abi
    ) as Receipt;

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const testErc20Contract = (await testErc20.deploy()) as TestErc20;
    await testErc20Contract.deployed();

    const assets = ethers.BigNumber.from(30);
    await testErc20Contract.transfer(alice.address, assets);
    await testErc20Contract
      .connect(alice)
      .increaseAllowance(receipt.address, assets);

    const shares = ethers.BigNumber.from(10);
    // await receipt.connect(alice).ownerMint(alice.address, 1,shares,[])

    // const expectedAssets = fixedPointDiv(shares,ONE)
    // const aliceBalanceAfter = await receipt
    //     .connect(alice)
    //     ["balanceOf(address,uint256)"](alice.address, 1);
    //
    // assert(
    //     aliceBalanceAfter.eq(expectedAssets),
    //     `wrong assets. expected ${expectedAssets} got ${aliceBalanceAfter}`
    // );
  });
});
