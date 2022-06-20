// scripts/deploy.js
import { ethers, artifacts } from "hardhat";
import type { ChainlinkFeedPriceOracleFactory } from "../typechain/ChainlinkFeedPriceOracleFactory";
import type { ChainlinkFeedPriceOracle } from "../typechain/ChainlinkFeedPriceOracle";
import type { TwoPriceOracle } from "../typechain/TwoPriceOracle";
import type { TwoPriceOracleFactory } from "../typechain/TwoPriceOracleFactory";
import type { ERC20PriceOracleVaultFactory } from "../typechain/ERC20PriceOracleVaultFactory";
import type { ERC20PriceOracleVault } from "../typechain/ERC20PriceOracleVault";

import type { Contract } from "ethers";
import { getEventArgs } from "../test/util";

async function main() {
  const [deployer] = await ethers.getSigners();

  const rinkebyXauUsd = "0x81570059A0cb83888f1459Ec66Aad1Ac16730243";
  const rinkebyEthUsd = "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e";

  const polygonXauUsd = "0x0C466540B2ee1a31b441671eac0ca886e051E410";
  const polygonMaticUsd = "0xab594600376ec9fd91f8e885dadf0ce036862de0";

  const chainlinkFeedPriceOracleConfig = {
    rinkeby: {
      base: rinkebyEthUsd,
      // 1 hour
      baseStaleAfter: 60 * 60,
      quote: rinkebyXauUsd,
      // 48 hours
      quoteStaleAfter: 48 * 60 * 60,
    },
    polygon: {
      base: polygonMaticUsd,
      // 1 hour
      baseStaleAfter: 60 * 60,
      quote: polygonXauUsd,
      // 48 hours
      quoteStaleAfter: 48 * 60 * 60,
    },
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
    feed: chainlinkFeedPriceOracleConfig.polygon.base,
    staleAfter: chainlinkFeedPriceOracleConfig.polygon.baseStaleAfter,
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

  // Deploy chainlink oracle adapter for quote.
  const txQuote = await chainlinkFeedPriceOracleFactory.createChildTyped({
    feed: chainlinkFeedPriceOracleConfig.polygon.quote,
    staleAfter: chainlinkFeedPriceOracleConfig.polygon.quoteStaleAfter,
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
        (await getEventArgs(txTwoPriceOracle, "NewChild", twoPriceOracleFactory)).child
      ),
      20
    ),

    (await artifacts.readArtifact("TwoPriceOracle")).abi,
    deployer
  ) as ChainlinkFeedPriceOracle & Contract;

  const erc20ContractAddress = "0xc778417E063141139Fce010982780140Aa0cD5Ab";

  let erc20PriceOracleVaultConfig = {
    asset: erc20ContractAddress,
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
