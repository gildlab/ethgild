import chai from "chai";
import { ethers } from "hardhat";
import { ContractTransaction, Contract, BigNumber } from "ethers";
const { assert } = chai;
import { Result } from "ethers/lib/utils";

export const ethMainnetFeedRegistry =
  "0x47Fb2585D2C56Fe188D0E6ec628a38b74fCeeeDf";
export const feedRegistryDenominationEth =
  "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
export const feedRegistryDenominationXau =
  "0x0000000000000000000000000000000000000959";

export const chainlinkXauUsd = "0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6";
export const chainlinkEthUsd = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419";

export const eighteenZeros = "000000000000000000";
export const xauOne = "100000000";

export const priceOne = ethers.BigNumber.from("1" + eighteenZeros);

export const usdDecimals = 8;
export const xauDecimals = 8;

export const deployNativeGild = async () => {
  const oracleFactory = await ethers.getContractFactory(
    "TestChainlinkDataFeed"
  );
  const basePriceOracle = await oracleFactory.deploy();
  await basePriceOracle.deployed();
  const signers = await ethers.getSigners();
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

  const nativeGildFactory = await ethers.getContractFactory("ERC20Gild");
  const ERC20Gild = await nativeGildFactory.deploy({
    asset: signers[0].address,
    name: "EthGild",
    symbol: "ETHg",
    uri: "ipfs://bafkreiahuttak2jvjzsd4r62xoxb4e2mhphb66o4cl2ntegnjridtyqnz4",
    priceOracle: chainlinkTwoFeedPriceOracle.address,
  });
  await ERC20Gild.deployed();

  return [
    ERC20Gild,
    chainlinkTwoFeedPriceOracle,
    basePriceOracle,
    quotePriceOracle,
  ];
};

export const expectedReferencePrice = ethers.BigNumber.from(
  "1656189669833157724"
);

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

export const expectedName = "EthGild";
export const expectedSymbol = "ETHg";
export const expectedUri =
  "ipfs://bafkreiahuttak2jvjzsd4r62xoxb4e2mhphb66o4cl2ntegnjridtyqnz4";

/// @param tx - transaction where event occurs
/// @param eventName - name of event
/// @param contract - contract object holding the address, filters, interface
/// @returns Event arguments, can be deconstructed by array index or by object key
export const getEventArgs = async (
  tx: ContractTransaction,
  eventName: string,
  contract: Contract
): Promise<Result> => {
  const events = (await tx.wait()).events || [];
  const filter = (contract.filters[eventName]().topics || [])[0];
  const eventObj = events.find(
    (x) => x.topics[0] == filter && x.address == contract.address
  );

  if (!eventObj) {
    throw new Error(`Could not find event with name ${eventName}`);
  }

  return contract.interface.decodeEventLog(eventName, eventObj.data);
};
