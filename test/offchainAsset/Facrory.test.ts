import { ethers } from "hardhat";
import {
  OffchainAssetReceiptVaultFactory,
  ReceiptFactory,
} from "../../typechain-types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expectedUri, getEventArgs } from "../util";
import { deployOffchainAssetVaultFactory } from "./deployOffchainAssetVault";

const assert = require("assert");

let offchainAssetReceiptVaultFactory: OffchainAssetReceiptVaultFactory;

describe("OffchainAssetVaultFactory Test", () => {
  before(async () => {
    offchainAssetReceiptVaultFactory = await deployOffchainAssetVaultFactory();
  });

  it("Should deploy Factory correctly", async () => {
    assert(
      offchainAssetReceiptVaultFactory.address !== ethers.constants.AddressZero
    );
  });

  it("Should createChild", async () => {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const constructionConfig = {
      admin: alice.address,
      vaultConfig: {
        asset: ethers.constants.AddressZero,
        name: "OffchainAssetVault",
        symbol: "OAV",
      },
    };

    let tx = await offchainAssetReceiptVaultFactory.createChildTyped(
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