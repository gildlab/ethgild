import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import { deployERC20Gild, expectedReferencePrice } from "../util";

chai.use(solidity);
const { expect, assert } = chai;

describe("oracle", async function () {
  it("should have an oracle", async function () {
    const [_ethGild, _erc20, priceOracle] = await deployERC20Gild();

    const price = await priceOracle.price();

    assert(
      price.eq(expectedReferencePrice),
      `wrong referencePrice. got ${price}. expected ${expectedReferencePrice}`
    );
  });
});
