import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import { deployERC20PriceOracleVault, assertError } from "./util";

chai.use(solidity);
const { expect, assert } = chai;

describe("fallback", async function () {
  it("should not fallback", async function () {
    const signers = await ethers.getSigners();
    const [ethGild] = await deployERC20PriceOracleVault();

    const alice = signers[0];

    await assertError(
      async () =>
        await alice.sendTransaction({
          to: ethGild.address,
          value: 10,
        }),
      "function selector was not recognized and there's no fallback nor receive function",
      "failed to error on fallback transaction"
    );
  });

  it("should not receive", async function () {
    const signers = await ethers.getSigners();
    const [ethGild] = await deployERC20PriceOracleVault();

    const alice = signers[0];

    await assertError(
      async () =>
        await alice.sendTransaction({
          to: ethGild.address,
          value: 10,
          data: "0x01",
        }),
      "function selector was not recognized and there's no fallback function",
      "failed to error on receive transaction"
    );
  });
});
