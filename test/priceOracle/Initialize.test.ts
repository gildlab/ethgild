import { artifacts, ethers } from "hardhat";
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
  ERC20PriceOracleReceiptVault,
  ERC20PriceOracleReceiptVaultInitializedEvent,
} from "../../typechain-types/contracts/vault/priceOracle/ERC20PriceOracleReceiptVault";
import {
  ERC20PriceOracleReceiptVaultFactory,
  NewChildEvent,
} from "../../typechain-types/contracts/vault/priceOracle/ERC20PriceOracleReceiptVaultFactory";

import { getEventArgs } from "../util";
import {
  ReceiptFactory,
  MockChainlinkDataFeed,
  TestErc20,
  TwoPriceOracle,
} from "../../typechain-types";
import { Contract } from "ethers";

const assert = require("assert");

describe("PriceOracle construction", async function () {
  it("Checks construction event", async function () {
    const now = await latestBlockNow();

    const oracleFactory = await ethers.getContractFactory(
      "MockChainlinkDataFeed"
    );
    const basePriceOracle =
      (await oracleFactory.deploy()) as MockChainlinkDataFeed;
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
      (await oracleFactory.deploy()) as MockChainlinkDataFeed;
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

    const ERC20PriceOracleReceiptVaultImplementationFactory =
      await ethers.getContractFactory("ERC20PriceOracleReceiptVault");
    const ERC20PriceOracleReceiptVaultImplementation =
      (await ERC20PriceOracleReceiptVaultImplementationFactory.deploy()) as ERC20PriceOracleReceiptVault;

    const receiptFactoryFactory = await ethers.getContractFactory(
      "ReceiptFactory"
    );
    const receiptFactoryContract =
      (await receiptFactoryFactory.deploy()) as ReceiptFactory;
    await receiptFactoryContract.deployed();

    const erc20PriceOracleVaultConfig = {
      priceOracle: twoPriceOracle.address,
      vaultConfig: {
        asset: asset.address,
        name: "PriceOracleVault",
        symbol: "POV",
      },
    };

    const erc20PriceOracleVaultFactoryFactory = await ethers.getContractFactory(
      "ERC20PriceOracleReceiptVaultFactory"
    );

    let erc20PriceOracleReceiptVaultFactory =
      (await erc20PriceOracleVaultFactoryFactory.deploy({
        implementation: ERC20PriceOracleReceiptVaultImplementation.address,
        receiptFactory: receiptFactoryContract.address,
      })) as ERC20PriceOracleReceiptVaultFactory;
    await erc20PriceOracleReceiptVaultFactory.deployed();

    let tx = await erc20PriceOracleReceiptVaultFactory.createChildTyped(
      erc20PriceOracleVaultConfig
    );
    let { child } = (await getEventArgs(
      tx,
      "NewChild",
      erc20PriceOracleReceiptVaultFactory
    )) as NewChildEvent["args"];

    let receiptFactoryArgs = (await getEventArgs(
      tx,
      "NewChild",
      receiptFactoryContract
    )) as NewChildEvent["args"];

    let childContract = new Contract(
      child,
      (await artifacts.readArtifact("ERC20PriceOracleReceiptVault")).abi
    );

    let { caller, config } = (await getEventArgs(
      tx,
      "ERC20PriceOracleReceiptVaultInitialized",
      childContract
    )) as ERC20PriceOracleReceiptVaultInitializedEvent["args"];

    assert(
      caller === erc20PriceOracleReceiptVaultFactory.address,
      "wrong deploy sender"
    );
    assert(
      config.receiptVaultConfig.vaultConfig.asset === asset.address,
      "wrong asset address"
    );
    assert(
      config.receiptVaultConfig.vaultConfig.name === expectedName,
      "wrong deploy name"
    );
    assert(
      config.receiptVaultConfig.vaultConfig.symbol === expectedSymbol,
      "wrong deploy symbol"
    );
    assert(config.receiptVaultConfig.receipt === receiptFactoryArgs.child);
    assert(
      config.priceOracle === twoPriceOracle.address,
      `wrong deploy priceOracle address: expected ${config.priceOracle} got ${twoPriceOracle.address}`
    );
  });
});
