import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import { deployERC20PriceOracleVault, expectedReferencePrice } from "../util";

chai.use(solidity);
const { expect, assert } = chai;

describe("oracle", async function () {
  it("should have an oracle", async function () {
    const [_ethGild, _erc20, priceOracle] = await deployERC20PriceOracleVault();

    const price = await priceOracle.price();

    assert(
      price.eq(expectedReferencePrice),
      `wrong referencePrice. got ${price}. expected ${expectedReferencePrice}`
    );
  });
});
