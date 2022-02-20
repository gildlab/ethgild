import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import {
  deployNativeGild,
  assertError,
  expectedReferencePrice,
  priceOne,
} from "./util";
import type { NativeGild } from "../typechain/NativeGild";
import type { ChainlinkTwoFeedPriceOracle } from "../typechain/ChainlinkTwoFeedPriceOracle";
import type { TestChainlinkDataFeed } from "../typechain/TestChainlinkDataFeed";
import type { TestReentrant } from "../typechain/TestReentrant";

chai.use(solidity);
const { expect, assert } = chai;

describe("reentrant behaviour", async function () {
  it("should receive and erc1155 receive", async function () {
    const [nativeGild, priceOracle, xauOracle, usdOracle] =
      (await deployNativeGild()) as [
        NativeGild,
        ChainlinkTwoFeedPriceOracle,
        TestChainlinkDataFeed,
        TestChainlinkDataFeed
      ];

    const ethAmount = 100000;

    const testReentrantFactory = await ethers.getContractFactory(
      "TestReentrant"
    );
    const testReentrant = await testReentrantFactory.deploy();
    await testReentrant.deployed();

    await assertError(
      async () =>
        await testReentrant.gild(nativeGild.address, false, {
          value: ethAmount,
        }),
      "ReentrancyGuard: reentrant call",
      "failed to prevent reentrant gild call"
    );

    await assertError(
      async () =>
        await testReentrant.gild(nativeGild.address, true, {
          value: ethAmount,
        }),
      "ReentrancyGuard: reentrant call",
      "failed to prevent reentrant ungild call"
    );
  });

  it("should be possible to atomically gild and ungild non-reentrantly", async function () {
    const [nativeGild, priceOracle, xauOracle, usdOracle] =
      (await deployNativeGild()) as [
        NativeGild,
        ChainlinkTwoFeedPriceOracle,
        TestChainlinkDataFeed,
        TestChainlinkDataFeed
      ];

    const ethAmount = 100000;

    const testDaoFactory = await ethers.getContractFactory("TestDao");
    const testDao = await testDaoFactory.deploy();
    await testDao.deployed();

    await testDao.doBotStuff(nativeGild.address, { value: ethAmount });
  });
});
