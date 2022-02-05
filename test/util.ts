import chai from "chai";
import { ethers } from "hardhat";
import { ContractTransaction, Contract, BigNumber } from "ethers";
const { assert } = chai;
import { Result } from "ethers/lib/utils";

export const chainlinkXauUsd = "0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6";
export const chainlinkEthUsd = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419";

export const eighteenZeros = "000000000000000000";
export const xauOne = "100000000";

export const deployEthGild = async () => {
  const oracleFactory = await ethers.getContractFactory("TestPriceOracle");
  const priceOracle = await oracleFactory.deploy();
  await priceOracle.deployed();
  await priceOracle.setDecimals(8);
  await priceOracle.setPrice(BigNumber.from("117250000"))

  const ethGildFactory = await ethers.getContractFactory("NativeGild");
  const ethGild = await ethGildFactory.deploy({
    name: "EthGild",
    symbol: "ETHg",
    erc20OverburnNumerator: 1001,
    erc20OverburnDenominator: 1000,
    priceOracle: priceOracle.address,
  });
  await ethGild.deployed();

  return [ethGild, priceOracle];
};

export const expectedReferencePrice = ethers.BigNumber.from("117250000");

export const assertError = async (f: Function, s: string, e: string) => {
  let didError = false;
  try {
    await f();
  } catch (e) {
    assert(e.toString().includes(s), `error string ${e} does not include ${s}`);
    didError = true;
  }
  assert(didError, e);
};

export const expectedName = "EthGild";
export const expectedSymbol = "ETHg";
export const expectedUri = "ipfs://bafkreiahuttak2jvjzsd4r62xoxb4e2mhphb66o4cl2ntegnjridtyqnz4";

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

export const generate1155ID = (
  referencePrice: BigNumber,
  xauDecimals: number
): BigNumber => {
  return BigNumber.from(
    (referencePrice.toBigInt() << BigInt(8)) | BigInt(xauDecimals)
  );
};
export const expected1155ID = generate1155ID(expectedReferencePrice, 8);
