import { ethers } from "hardhat";
import {
  OffchainAssetReceiptVaultFactory,
  ReceiptFactory,
} from "../../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expectedUri, getEventArgs } from "../util";
const assert = require("assert");

let offchainAssetReceiptVaultFactory: OffchainAssetReceiptVaultFactory;
let alice: SignerWithAddress;

describe("OffchainAssetVaultFactory Test", () => {
  before(async () => {
    const signers = await ethers.getSigners();
    alice = signers[0];

    const receiptFactoryFactory = await ethers.getContractFactory(
      "ReceiptFactory"
    );
    const receiptFactoryContract =
      (await receiptFactoryFactory.deploy()) as ReceiptFactory;
    await receiptFactoryContract.deployed();

    const offchainAssetReceiptVaultFactoryFactory =
      await ethers.getContractFactory("OffchainAssetReceiptVaultFactory");

    offchainAssetReceiptVaultFactory =
      (await offchainAssetReceiptVaultFactoryFactory.deploy(
        receiptFactoryContract.address
      )) as OffchainAssetReceiptVaultFactory;
    await offchainAssetReceiptVaultFactory.deployed();
  });

  it("Should deploy Factory correctly", async () => {
    assert(
      offchainAssetReceiptVaultFactory.address !== ethers.constants.AddressZero
    );
  });

  it("Should createChild", async () => {
    const constructionConfig = {
      admin: alice.address,
      vaultConfig: {
        asset: ethers.constants.AddressZero,
        name: "OffchainAssetVault",
        symbol: "OAV",
      },
    };

    const receiptConfig = {
      uri: expectedUri,
    };

    let tx = await offchainAssetReceiptVaultFactory.createChildTyped(
      receiptConfig,
      constructionConfig
    );

    const { sender, child } = await getEventArgs(
      tx,
      "NewChild",
      offchainAssetReceiptVaultFactory
    );
    assert(sender === alice.address);
    assert(child !== ethers.constants.AddressZero);
  });
});
