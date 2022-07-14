import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import {
  getEventArgs,
  expectedName,
  expectedSymbol,
  expectedUri,
  ADDRESS_ZERO,
} from "../util";

import {
  SetERC20TierEvent,
  OffchainAssetVaultConstructionEvent,
} from "../../typechain/OffchainAssetVault";
import { deployOffChainAssetVault } from "./deployOffchainAssetVault";

chai.use(solidity);
const { assert } = chai;

describe("OffChainAssetVault", async function () {
  it("Constructs well", async function () {
    const [vault] = await deployOffChainAssetVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    const { caller, config } = (await getEventArgs(
      await vault.deployTransaction,
      "OffchainAssetVaultConstruction",
      vault
    )) as OffchainAssetVaultConstructionEvent["args"];

    assert(
      config.receiptVaultConfig.name === expectedName,
      `wrong name expected ${expectedName} got ${config.receiptVaultConfig.name}`
    );
    assert(
      config.receiptVaultConfig.asset === ADDRESS_ZERO,
      `wrong asset expected ${ADDRESS_ZERO} got ${config.receiptVaultConfig.asset}`
    );
    assert(
      config.receiptVaultConfig.uri === expectedUri,
      `wrong uri expected ${expectedUri} got ${config.receiptVaultConfig.uri}`
    );

    assert(
      config.receiptVaultConfig.symbol === expectedSymbol,
      `wrong symbol expected ${expectedSymbol} got ${config.receiptVaultConfig.symbol}`
    );

    assert(
      caller === alice.address,
      `wrong caller expected ${alice.address} got ${caller}`
    );
  });
});
