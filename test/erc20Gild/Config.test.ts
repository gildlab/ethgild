import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import {
  basePrice,
  expectedName,
  expectedSymbol,
  latestBlockNow,
  quotePrice,
  usdDecimals,
  xauDecimals,
} from "../util";
import {
  ERC20PriceOracleVault,
  ERC20PriceOracleVaultConstructionEvent,
} from "../../typechain/ERC20PriceOracleVault";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { getEventArgs } from "../util";
import {
  Receipt,
  TestChainlinkDataFeed,
  TestErc20,
  TwoPriceOracle,
} from "../../typechain";

let owner: SignerWithAddress;

chai.use(solidity);

const { assert } = chai;

describe("config", async function () {
  it("Checks construction event", async function () {
    [owner] = await ethers.getSigners();
    const now = await latestBlockNow();

    const oracleFactory = await ethers.getContractFactory(
      "TestChainlinkDataFeed"
    );
    const basePriceOracle =
      (await oracleFactory.deploy()) as TestChainlinkDataFeed;
    await basePriceOracle.deployed();
    // ETHUSD as of 2022-06-30

    await basePriceOracle.setDecimals(usdDecimals);
    await basePriceOracle.setRoundData(1, {
      startedAt: now,
      updatedAt: now,
      answer: basePrice,
      answeredInRound: 1,
    });

    const quotePriceOracle =
      (await oracleFactory.deploy()) as TestChainlinkDataFeed;
    await quotePriceOracle.deployed();
    // XAUUSD as of 2022-06-30
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

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const receipt = await ethers.getContractFactory("Receipt");
    const receiptContract = (await receipt.deploy()) as Receipt;
    await receiptContract.deployed();

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

    const constructionConfig = {
      asset: asset.address,
      receipt: receiptContract.address,
      name: "EthGild",
      symbol: "ETHg",
    };

    const erc20PriceOracleVaultFactory = await ethers.getContractFactory(
      "ERC20PriceOracleVault"
    );

    let erc20PriceOracleVault =
      (await erc20PriceOracleVaultFactory.deploy()) as ERC20PriceOracleVault;
    await erc20PriceOracleVault.deployed();

    const { caller, config } = (await getEventArgs(
      await erc20PriceOracleVault.initialize({
        priceOracle: twoPriceOracle.address,
        receiptVaultConfig: constructionConfig,
      }),
      "ERC20PriceOracleVaultConstruction",
      erc20PriceOracleVault
    )) as ERC20PriceOracleVaultConstructionEvent["args"];

    assert(caller === owner.address, "wrong deploy sender");
    assert(
      config.receiptVaultConfig.asset === asset.address,
      "wrong asset address"
    );
    assert(
      config.receiptVaultConfig.name === expectedName,
      "wrong deploy name"
    );
    assert(
      config.receiptVaultConfig.symbol === expectedSymbol,
      "wrong deploy symbol"
    );
    assert(config.receiptVaultConfig.receipt === receiptContract.address);
    assert(
      config.priceOracle === twoPriceOracle.address,
      `wrong deploy priceOracle addresს: expected ${config.priceOracle} got ${twoPriceOracle.address}`
    );
  });
});
