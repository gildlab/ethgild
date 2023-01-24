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
    const quotePriceA = "194076000000";
    const priceOracle = await getPriceOracle(8, quotePriceA);

    const price = await priceOracle.price();

    const quotePriceB = "1940760000000000000000";
    const priceOracleB = await getPriceOracle(18, quotePriceB);

    const priceB = await priceOracleB.price();

    assert(price.eq(priceB), `Wrong price`);
  });
});

const getPriceOracle = async (
  xauDecimals,
  quotePrice
): Promise<TwoPriceOracle> => {
  const now = await latestBlockNow();

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

  await quotePriceOracle.setDecimals(xauDecimals);
  await quotePriceOracle.setRoundData(1, {
    startedAt: now,
    updatedAt: now,
    answer: quotePrice,
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

  return twoPriceOracle;
};
