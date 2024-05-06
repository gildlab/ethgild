import { ethers } from "hardhat";
import {
  OffchainAssetReceiptVaultFactory
} from "../../typechain-types";
import { getEventArgs } from "../util";
import { deployOffchainAssetReceiptVaultFactory } from "./deployOffchainAssetReceiptVault";

const assert = require("assert");

let offchainAssetReceiptVaultFactory: OffchainAssetReceiptVaultFactory;

describe("OffchainAssetReceiptVaultFactory Test", async () => {
  offchainAssetReceiptVaultFactory =
    await deployOffchainAssetReceiptVaultFactory();

  it("Should deploy Factory correctly", async () => {
    assert(
      offchainAssetReceiptVaultFactory.address !== ethers.constants.AddressZero
    );
  });

  it("Should createChild", async () => {
    const signers = await ethers.getSigners();
    const alice = signers[ 0 ];

    const constructionConfig = {
      admin: alice.address,
      vaultConfig: {
        asset: ethers.constants.AddressZero,
        name: "OffchainAssetReceiptVault",
        symbol: "OAV"
      }
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
