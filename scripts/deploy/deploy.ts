// scripts/deploy.js
import { ethers, artifacts } from "hardhat";
import type { ChainlinkFeedPriceOracleFactory } from "../../typechain";
import type { ChainlinkFeedPriceOracle } from "../../typechain";
import type { TwoPriceOracle } from "../../typechain";
import type { TwoPriceOracleFactory } from "../../typechain";
import type { ERC20PriceOracleVaultFactory } from "../../typechain";
import type { ERC20PriceOracleVault } from "../../typechain";

import type { Contract } from "ethers";
import { getEventArgs } from "../../test/util";

type Config = {
  name: string;
  symbol: string;
  uri: string;
};

export const deployERC20PriceOracleVault = async (
  base: string,
  quote: string,
  network: string,
  erc20ContractAddress: string,
  config: Config
) => {
  console.log(network);
  const [deployer] = await ethers.getSigners();
  // 1 hour
  const baseStaleAfter = 60 * 60;
  // 48 hours
  const quoteStaleAfter = 48 * 60 * 60;

  const chainlinkFeedPriceOracleConfig = {
    base,
    baseStaleAfter,
    quote,
    quoteStaleAfter,
    erc20ContractAddress,
  };

  const chainlinkFeedPriceOracleFactoryFactory =
    await ethers.getContractFactory("ChainlinkFeedPriceOracleFactory");

  const chainlinkFeedPriceOracleFactory =
    (await chainlinkFeedPriceOracleFactoryFactory.deploy()) as ChainlinkFeedPriceOracleFactory;

  await chainlinkFeedPriceOracleFactory.deployed();
  console.log(
    "chainlinkFeedPriceOracleFactory deployed to:",
    chainlinkFeedPriceOracleFactory.address
  );

  // Deploy chainlink oracle adapter for base.
  const txBase = await chainlinkFeedPriceOracleFactory.createChildTyped({
    feed: chainlinkFeedPriceOracleConfig.base,
    staleAfter: chainlinkFeedPriceOracleConfig.baseStaleAfter,
  });
  const basePriceOracle = new ethers.Contract(
    ethers.utils.hexZeroPad(
      ethers.utils.hexStripZeros(
        (
          await getEventArgs(
            txBase,
            "NewChild",
            chainlinkFeedPriceOracleFactory
          )
        ).child
      ),
      20
    ),

    (await artifacts.readArtifact("ChainlinkFeedPriceOracle")).abi,
    deployer
  ) as ChainlinkFeedPriceOracle & Contract;
  await basePriceOracle.deployed();

  console.log("basePriceOracle deployed to: ", basePriceOracle.address);

  // Deploy chainlink oracle adapter for quote.
  const txQuote = await chainlinkFeedPriceOracleFactory.createChildTyped({
    feed: chainlinkFeedPriceOracleConfig.quote,
    staleAfter: chainlinkFeedPriceOracleConfig.quoteStaleAfter,
  });
  const quotePriceOracle = new ethers.Contract(
    ethers.utils.hexZeroPad(
      ethers.utils.hexStripZeros(
        (
          await getEventArgs(
            txQuote,
            "NewChild",
            chainlinkFeedPriceOracleFactory
          )
        ).child
      ),
      20
    ),

    (await artifacts.readArtifact("ChainlinkFeedPriceOracle")).abi,
    deployer
  ) as ChainlinkFeedPriceOracle & Contract;
  await quotePriceOracle.deployed();

  console.log("quotePriceOracle deployed to: ", quotePriceOracle.address);

  const twoPriceOracleFactoryFactory = await ethers.getContractFactory(
    "TwoPriceOracleFactory"
  );
  const twoPriceOracleFactory =
    (await twoPriceOracleFactoryFactory.deploy()) as TwoPriceOracleFactory;
  await twoPriceOracleFactory.deployed();

  console.log(
    "twoPriceOracleFactory deployed to:",
    twoPriceOracleFactory.address
  );

  const txTwoPriceOracle = await twoPriceOracleFactory.createChildTyped({
    base: basePriceOracle.address,
    quote: quotePriceOracle.address,
  });

  const twoPriceOracle = new ethers.Contract(
    ethers.utils.hexZeroPad(
      ethers.utils.hexStripZeros(
        (
          await getEventArgs(
            txTwoPriceOracle,
            "NewChild",
            twoPriceOracleFactory
          )
        ).child
      ),
      20
    ),

    (await artifacts.readArtifact("TwoPriceOracle")).abi,
    deployer
  ) as ChainlinkFeedPriceOracle & Contract;

  const erc20PriceOracleVaultFactoryFactory = await ethers.getContractFactory(
    "ERC20PriceOracleVaultFactory"
  );

  const erc20PriceOracleVaultFactory =
    (await erc20PriceOracleVaultFactoryFactory.deploy()) as ERC20PriceOracleVaultFactory;

  await erc20PriceOracleVaultFactory.deployed();
  console.log(
    "ERC20PriceOracleVaultFactoryFactory deployed to:",
    erc20PriceOracleVaultFactory.address
  );

  const erc20PriceOracleVaultConfig = {
    priceOracle: twoPriceOracle.address,
    receiptVaultConfig: {
      asset: chainlinkFeedPriceOracleConfig.erc20ContractAddress,
      name: config.name,
      symbol: config.symbol,
      uri: config.uri,
    },
  };

  const erc20PriceOracleVaultTx =
    await erc20PriceOracleVaultFactory.createChildTyped(
      erc20PriceOracleVaultConfig
    );
  const erc20PriceOracleVault = new ethers.Contract(
    ethers.utils.hexZeroPad(
      ethers.utils.hexStripZeros(
        (
          await getEventArgs(
            erc20PriceOracleVaultTx,
            "NewChild",
            erc20PriceOracleVaultFactory
          )
        ).child
      ),
      20
    ),
    (await artifacts.readArtifact("ERC20PriceOracleVault")).abi,
    deployer
  ) as ERC20PriceOracleVault & Contract;

  await erc20PriceOracleVault.deployed();
  console.log(
    "ERC20PriceOracleVault deployed to:",
    erc20PriceOracleVault.address
  );
};
