import {
  basePrice,
  deployERC20PriceOracleVault,
  expectedReferencePrice,
  latestBlockNow,
  usdDecimals,
} from "../util";
import { MockChainlinkDataFeed, TwoPriceOracle } from "../../typechain-types";
import { ethers } from "hardhat";

const assert = require("assert");

describe("oracle", async function () {
  it("should have an oracle", async function () {
    const [_vault, _erc20, priceOracle] = await deployERC20PriceOracleVault();

    const shareRatio = await priceOracle.price();

    assert(
      shareRatio.eq(expectedReferencePrice),
      `wrong shareRatio. got ${shareRatio}. expected ${expectedReferencePrice}`
    );
  });
  it("Checks price oracle does not change", async function () {
    const now = await latestBlockNow();

    const quotePriceA = "194076000000";
    const xauDecimalsA = 8;
    const quotePriceB = "1940760000000000000000";
    const xauDecimalsB = 18;

    const oracleFactory = await ethers.getContractFactory(
      "MockChainlinkDataFeed"
    );
    const basePriceOracle =
      (await oracleFactory.deploy()) as MockChainlinkDataFeed;
    await basePriceOracle.deployed();

    await basePriceOracle.setDecimals(usdDecimals);
    await basePriceOracle.setRoundData(1, {
      startedAt: now,
      updatedAt: now,
      answer: basePrice,
      answeredInRound: 1,
    });

    const quotePriceOracle =
      (await oracleFactory.deploy()) as MockChainlinkDataFeed;
    await quotePriceOracle.deployed();

    await quotePriceOracle.setDecimals(xauDecimalsA);
    await quotePriceOracle.setRoundData(1, {
      startedAt: now,
      updatedAt: now,
      answer: quotePriceA,
      answeredInRound: 1,
    });

    // 1 hour
    const baseStaleAfter = 60 * 60;
    // 48 hours
    const quoteStaleAfter = 48 * 60 * 60;

    const chainlinkFeedPriceOracleFactory = await ethers.getContractFactory(
      "ChainlinkFeedPriceOracle"
    );
    const chainlinkFeedPriceOracleBase =
      await chainlinkFeedPriceOracleFactory.deploy({
        feed: basePriceOracle.address,
        staleAfter: baseStaleAfter,
      });
    const chainlinkFeedPriceOracleQuote =
      await chainlinkFeedPriceOracleFactory.deploy({
        feed: quotePriceOracle.address,
        staleAfter: quoteStaleAfter,
      });
    await chainlinkFeedPriceOracleBase.deployed();
    await chainlinkFeedPriceOracleQuote.deployed();

    const twoPriceOracleFactory = await ethers.getContractFactory(
      "TwoPriceOracle"
    );
    const twoPriceOracle = (await twoPriceOracleFactory.deploy({
      base: chainlinkFeedPriceOracleBase.address,
      quote: chainlinkFeedPriceOracleQuote.address,
    })) as TwoPriceOracle;

    const priceA = await twoPriceOracle.price();

    await quotePriceOracle.setDecimals(xauDecimalsB);
    await quotePriceOracle.setRoundData(1, {
      startedAt: now,
      updatedAt: now,
      answer: quotePriceB,
      answeredInRound: 1,
    });

    const priceB = await twoPriceOracle.price();

    assert(priceA.eq(priceB), `Wrong price`);
  });
});
