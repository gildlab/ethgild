import { expect, assert } from "chai";
import { ethers } from "hardhat";
import { OffchainAssetVaultFactory } from "../../typechain/OffchainAssetVaultFactory";
import { OffchainAssetVault } from "../../typechain/OffchainAssetVault";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { getEventArgs } from "../util";

let factory: OffchainAssetVaultFactory;
let alice: SignerWithAddress;
let vault: OffchainAssetVault;

describe("OffchainAssetVaultFactory Test", () => {
  before(async () => {
    const signers = await ethers.getSigners();
    alice = signers[0];

    const Factory = await ethers.getContractFactory(
      "OffchainAssetVaultFactory"
    );
    factory = (await Factory.deploy()) as OffchainAssetVaultFactory;
    await factory.deployed();
  });

  it("Should deploy Factory correctly", async () => {
    expect(factory.address).to.not.null;
  });

  it("Should createChild (createTypedChild)", async () => {
    const constructionConfig = {
      admin: alice.address,
      receiptVaultConfig: {
        asset: ethers.constants.AddressZero,
        name: "EthGild",
        symbol: "ETHg",
        uri: "ipfs://bafkreiahuttak2jvjzsd4r62xoxb4e2mhphb66o4cl2ntegnjridtyqnz4",
      },
    };

    let deployTrx = await factory
      .connect(alice)
      .createChildTyped(constructionConfig);
    const { sender, child } = await getEventArgs(
      deployTrx,
      "NewChild",
      factory
    );
    expect(sender).to.equals(alice.address);
    expect(child).to.not.null;
  });
});
