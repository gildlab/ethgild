import chai from "chai";
import { solidity } from "ethereum-waffle";
import { artifacts, ethers } from "hardhat";
import { fixedPointDiv, fixedPointMul, getEventArgs, ONE } from "../util";
import { deployOffChainAssetVault } from "../offchainAsset/deployOffchainAssetVault";
import { Receipt, ReceiptFactory, TestErc20 } from "../../typechain";
import { Contract } from "ethers";

chai.use(solidity);

const { assert } = chai;

describe("Receipt vault", async function () {
  it.only("Mints with data", async function () {
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
      `wrong confiscated expected ${receiptConfig.uri} got ${uri}`
    );
  });
});
