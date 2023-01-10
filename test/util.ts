import { artifacts, ethers } from "hardhat";
import {
  ERC20PriceOracleReceiptVault,
  ERC20PriceOracleReceiptVaultInitializedEvent,
} from "../typechain/ERC20PriceOracleReceiptVault";
import {
  ERC20PriceOracleReceiptVaultFactory,
  NewChildEvent,
} from "../typechain/ERC20PriceOracleReceiptVaultFactory";

import {
  Receipt,
  ReceiptFactory,
  MockChainlinkDataFeed,
  TestErc20,
  TwoPriceOracle,
} from "../typechain-types";
import { ContractTransaction, Contract, BigNumber, Event } from "ethers";
import { Result } from "ethers/lib/utils";

const assert = require("assert");

export const ethMainnetFeedRegistry =
  "0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf";
export const feedRegistryDenominationEth =
  "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
export const feedRegistryDenominationXau =
  "0x0000000000000000000000000000000000000959";
export const ADDRESS_ZERO = ethers.constants.AddressZero;

export const chainlinkXauUsd = "0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6";
export const chainlinkEthUsd = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419";

export const eighteenZeros = "000000000000000000";
export const sixZeros = "000000";
export const xauOne = "100000000";

export const ONE = ethers.BigNumber.from("1" + eighteenZeros);

export const usdDecimals = 8;
export const xauDecimals = 8;

export const quotePrice = "176617500000";
export const basePrice = "119832442811";

export const fixedPointMul = (a: BigNumber, b: BigNumber): BigNumber =>
  a.mul(b).div(ONE);
export const fixedPointDiv = (a: BigNumber, b: BigNumber): BigNumber =>
  a.mul(ONE).div(b);
export const fixedPointDivRound = (a: BigNumber, b: BigNumber): BigNumber => {
  let result = a.mul(ONE).div(b);

  if (a.mul(ONE).mod(b).gt(0)) {
    result = result.add(1);
  }
  return result;
};

export const RESERVE_ONE = ethers.BigNumber.from("1" + sixZeros);

export const latestBlockNow = async (): Promise<number> =>
  (await ethers.provider.getBlock(await ethers.provider.getBlockNumber()))
    .timestamp;

export const deployERC20PriceOracleVault = async (): Promise<
  [
    ERC20PriceOracleReceiptVault,
    TestErc20,
    TwoPriceOracle,
    Receipt,
    MockChainlinkDataFeed,
    MockChainlinkDataFeed
  ]
> => {
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

  let childContract = new Contract(
    child,
    (await artifacts.readArtifact("ERC20PriceOracleReceiptVault")).abi
  ) as ERC20PriceOracleReceiptVault;

  let { config } = (await getEventArgs(
    tx,
    "ERC20PriceOracleReceiptVaultInitialized",
    childContract
  )) as ERC20PriceOracleReceiptVaultInitializedEvent["args"];

  let receiptContractAddress = config.receiptVaultConfig.receipt;

  let receiptContract = new Contract(
    receiptContractAddress,
    (await artifacts.readArtifact("Receipt")).abi
  ) as Receipt;

  return [
    childContract,
    asset,
    twoPriceOracle,
    receiptContract,
    basePriceOracle,
    quotePriceOracle,
  ];
};

export const expectedReferencePrice = ethers.BigNumber.from(basePrice)
  .mul(ONE)
  .div(ethers.BigNumber.from(quotePrice));

export const assertError = async (f: Function, s: string, e: string) => {
  let didError = false;
  try {
    await f();
  } catch (err) {
    if (err instanceof Error) {
      assert(
        err.toString().includes(s),
        `error string ${err} does not include ${s}`
      );
    } else {
      throw "err not an Error";
    }
    didError = true;
  }
  assert(didError, e);
};

export const expectedName = "PriceOracleVault";
export const expectedSymbol = "POV";
export const expectedUri =
  "ipfs://bafkreih7cvpjocgrk7mgdel2hvjpquc26j4jo2jkez5y2qdaojfil7vley";

/// @param tx - transaction where event occurs
/// @param eventName - name of event
/// @param contract - contract object holding the address, filters, interface
/// @returns Event arguments, can be deconstructed by array index or by object key
export const getEventArgs = async (
  tx: ContractTransaction,
  eventName: string,
  contract: Contract
): Promise<Result> => {
  const eventObj = await getEvent(tx, eventName, contract);
  return await contract.interface.decodeEventLog(
    eventName,
    eventObj.data,
    eventObj.topics
  );
};

export const getEvent = async (
  tx: ContractTransaction,
  eventName: string,
  contract: Contract
): Promise<Event> => {
  const events = (await tx.wait()).events || [];
  const filter = (contract.filters[eventName]().topics || [])[0];
  const eventObj = events.find(
    (x) => x.topics[0] == filter && x.address == contract.address
  );

  if (!eventObj) {
    throw new Error(`Could not find event with name ${eventName}`);
  }

  return eventObj;
};

// /**
//  *
//  * @param tx - transaction where event occurs
//  * @param eventName - name of event
//  * @param contract - contract object holding the address, filters, interface
//  * @param contractAddressOverride - (optional) override the contract address which emits this event
//  * @returns Event arguments of first matching event, can be deconstructed by array index or by object key
//  */
// export const getEventArgs = async (
//   tx: ContractTransaction,
//   eventName: string,
//   contract: Contract,
//   contractAddressOverride: string = null
// ): Promise<Result> => {
//   const address = contractAddressOverride
//     ? contractAddressOverride
//     : contract.address;

//   const eventObj = (await tx.wait()).events.find(
//     (x) =>
//       x.topics[0] == contract.filters[eventName]().topics[0] &&
//       x.address == address
//   );

//   if (!eventObj) {
//     throw new Error(`Could not find event ${eventName} at address ${address}`);
//   }

//   return contract.interface.decodeEventLog(
//     eventName,
//     eventObj.data,
//     eventObj.topics
//   );
// };
