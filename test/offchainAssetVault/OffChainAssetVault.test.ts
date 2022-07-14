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
  it("Checks SetERC20Tier event is emitted", async function () {
    const [vault] = await deployOffChainAssetVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    const TierV2Test = await ethers.getContractFactory("TierV2Test");
    const TierV2TestContract = await TierV2Test.deploy();
    await TierV2TestContract.deployed();

    await vault.grantRole(await vault.ERC20TIERER(), alice.address);
    const minTier = ethers.BigNumber.from(10);

    const { caller, tier, minimumTier } = (await getEventArgs(
      await vault.setERC20Tier(TierV2TestContract.address, minTier),
      "SetERC20Tier",
      vault
    )) as SetERC20TierEvent["args"];

    assert(
      caller === alice.address,
      `wrong name expected ${alice.address} got ${caller}`
    );
    assert(
      tier === TierV2TestContract.address,
      `wrong asset expected ${TierV2TestContract.address} got ${tier}`
    );
    assert(
      minimumTier.eq(minTier),
      `wrong uri expected ${minTier} got ${minimumTier}`
    );
  });
});
