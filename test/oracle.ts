import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import { deployEthGild, expectedReferencePrice } from "./util";
import type { NativeGild } from "../typechain/NativeGild";
import type { TestPriceOracle } from "../typechain/TestPriceOracle";

chai.use(solidity);
const { expect, assert } = chai;

describe("oracle", async function () {
  it("should have an oracle", async function () {
    const [ethGild, priceOracle] = (await deployEthGild()) as [
      NativeGild,
      TestPriceOracle,
    ];

    const [xauDecimals, referencePrice] = await priceOracle.price();

    assert(xauDecimals == 8, `wrong xauDecimals`);
    assert(
      referencePrice.eq(expectedReferencePrice),
      `wrong referencePrice. got ${referencePrice}. expected ${expectedReferencePrice}`
    );
  });
});
