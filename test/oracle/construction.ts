import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import { expectedReferencePrice } from "../util";

chai.use(solidity);
const { assert } = chai;

export const usdDecimals = 8;
export const xauDecimals = 8;

describe("oracle construction", async function () {
  it("should set reference price", async function () {
    const oracleFactory = await ethers.getContractFactory(
      "TestChainlinkDataFeed"
    );
    const basePriceOracle = await oracleFactory.deploy();
    await basePriceOracle.deployed();
    // ETHUSD as of 2022-02-06
    await basePriceOracle.setDecimals(usdDecimals);
    await basePriceOracle.setRoundData(1, {
      startedAt: Date.now(),
      updatedAt: Date.now(),
      answer: "299438264211",
      answeredInRound: 1,
    });

    const quotePriceOracle = await oracleFactory.deploy();
    await quotePriceOracle.deployed();
    // XAUUSD as of 2022-02-06
    await quotePriceOracle.setDecimals(xauDecimals);
    await quotePriceOracle.setRoundData(1, {
      startedAt: Date.now(),
      updatedAt: Date.now(),
      answer: "180799500000",
      answeredInRound: 1,
    });

    const chainlinkTwoFeedPriceOracleFactory = await ethers.getContractFactory(
      "ChainlinkTwoFeedPriceOracle"
    );

    const chainlinkTwoFeedPriceOracle =
      await chainlinkTwoFeedPriceOracleFactory.deploy({
        base: basePriceOracle.address,
        quote: quotePriceOracle.address,
      });
    await chainlinkTwoFeedPriceOracle.deployed();

    const expectedPrice = await chainlinkTwoFeedPriceOracle.price();

    assert(
      expectedPrice.eq(expectedReferencePrice),
      `wrong price ${expectedReferencePrice} ${expectedPrice}`
    );
  });
});
