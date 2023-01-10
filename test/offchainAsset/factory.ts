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
let alice: SignerWithAddress;

describe("OffchainAssetVaultFactory Test", () => {
  before(async () => {
    offchainAssetReceiptVaultFactory = await deployOffchainAssetVaultFactory()
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
