import chai from "chai";
import { solidity } from "ethereum-waffle";
import { BigNumber } from "ethers";
import {
  expectedReferencePrice,
  deployERC20PriceOracleVault,
  basePrice,
  quotePrice,
  latestBlockNow
} from "../util";
import { ethers } from "hardhat"

chai.use(solidity);
const { assert } = chai;

export const usdDecimals = 8;
export const xauDecimals = 8;

describe("oracle construction", async function () {
  it.only("should set reference price", async function () {
    const [
      _vault,
      _erc20,
      priceOracle,
      receipt,
      basePriceOracle,
      quotePriceOracle,
    ] = await deployERC20PriceOracleVault();

    let now = await latestBlockNow();

    // ETHUSD as of 2022-11-14
    await basePriceOracle.setDecimals(usdDecimals);
    await basePriceOracle.setRoundData(1, {
      startedAt: now,
      updatedAt: now,
      answer: basePrice,
      answeredInRound: 1,
    });

    // XAUUSD as of 2022-11-14
    await quotePriceOracle.setDecimals(xauDecimals);
    await quotePriceOracle.setRoundData(1, {
      startedAt: now,
      updatedAt: now,
      answer: quotePrice,
      answeredInRound: 1,
    });

    const actualPrice = await priceOracle.price();

    assert(
      actualPrice.eq(expectedReferencePrice),
      `wrong price ${expectedReferencePrice} ${actualPrice}`
    );
  });
});
