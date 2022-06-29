// scripts/deploy.js
import {ethers, artifacts} from "hardhat";
import type {ChainlinkFeedPriceOracleFactory} from "../typechain";
import type {ChainlinkFeedPriceOracle} from "../typechain";
import type {TwoPriceOracle} from "../typechain";
import type {TwoPriceOracleFactory} from "../typechain";
import type {ERC20PriceOracleVaultFactory} from "../typechain";
import type {ERC20PriceOracleVault} from "../typechain";

import type {Contract} from "ethers";
import {getEventArgs} from "../test/util";

async function main() {
  const [deployer] = await ethers.getSigners();

  const xauUsd = "0x81570059A0cb83888f1459Ec66Aad1Ac16730243";
  const ethUsd = "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e";

  const chainlinkFeedPriceOracleConfig = {
    base: ethUsd,
    // 1 hour
    baseStaleAfter: 60 * 60,
    quote: xauUsd,
    // 48 hours
    quoteStaleAfter: 48 * 60 * 60,
    erc20ContractAddress: "0xc778417E063141139Fce010982780140Aa0cD5Ab"
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

  console.log("basePriceOracle deployed to: ", basePriceOracle.address)

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

  console.log("quotePriceOracle deployed to: ", quotePriceOracle.address)

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

  let erc20PriceOracleVaultConfig = {
    asset: chainlinkFeedPriceOracleConfig.erc20ContractAddress,
    name: "EthGild",
    symbol: "ETHg",
    uri: "ipfs://bafkreiahuttak2jvjzsd4r62xoxb4e2mhphb66o4cl2ntegnjridtyqnz4",
    priceOracle: twoPriceOracle.address,
  };

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
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
