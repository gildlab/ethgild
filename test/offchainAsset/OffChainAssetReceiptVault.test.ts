import { ReadWriteTier, TestErc20 } from "../../typechain-types";
import { ethers } from "hardhat";

import {
  getEventArgs,
  ADDRESS_ZERO,
  assertError,
  fixedPointMul,
  ONE,
  fixedPointDiv,
  fixedPointDivRound,
} from "../util";

import {
  SetERC20TierEvent,
  CertifyEvent,
  SnapshotEvent,
  SetERC1155TierEvent,
  SnapshotWithDataEvent,
} from "../../typechain-types/contracts/vault/offchainAsset/OffchainAssetReceiptVault";
import {
  deployOffChainAssetReceiptVault,
} from "./deployOffchainAssetReceiptVault";
import { ReceiptInformationEvent } from "../../typechain-types/contracts/vault/receipt/Receipt";

const assert = require("assert");

let TierV2TestContract: ReadWriteTier;

describe("OffChainAssetReceiptVault", async function () {
  beforeEach(async () => {
    const TierV2Test = await ethers.getContractFactory("ReadWriteTier");
    TierV2TestContract = (await TierV2Test.deploy()) as ReadWriteTier;
    await TierV2TestContract.deployed();
  });
  it("Check negative overflow", async () => {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const [vault] = await deployOffChainAssetReceiptVault();
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), bob.address);

    const shares = ethers.BigNumber.from(-1);

    await assertError(
      async () =>
        await vault
          .connect(bob)
          ["mint(uint256,address,uint256,bytes)"](shares, bob.address, 1, []),
      "out-of-bounds",
      "Failed to mint"
    );
  });
  it("Check positive overflow", async () => {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const [vault] = await deployOffChainAssetReceiptVault();
    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), bob.address);

    const shares = ethers.BigNumber.from(ethers.constants.MaxUint256).add(1);

    await assertError(
      async () =>
        await vault
          .connect(bob)
          ["mint(uint256,address,uint256,bytes)"](shares, bob.address, 1, []),
      "out-of-bounds",
      "Failed to mint"
    );
  });
});
