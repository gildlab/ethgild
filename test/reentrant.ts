import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import {
  deployEthGild,
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
    const [ethGild, priceOracle, xauOracle, ethOracle] = (await deployEthGild()) as [
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

    await testReentrant.gild(ethGild.address, { value: ethAmount });

    const didRecievePayable = await testReentrant.didReceivePayable();
    assert(didRecievePayable, "did not receive payable");

    const erc1155ReceivedId = await testReentrant.erc1155Received(0);
    const erc1155ReceivedValue = await testReentrant.erc1155Received(1);

    const expected1155ID = await priceOracle.price()

    assert(erc1155ReceivedId.eq(expected1155ID), "wrong ID");

    const expectedValue = expectedReferencePrice
      .mul(ethAmount)
      .div(priceOne)
      .div(2);
    assert(
      erc1155ReceivedValue.eq(expectedValue),
      `wrong received value expected: ${expectedValue} got: ${erc1155ReceivedValue}`
    );
  });

  it("should error low value reentrant ungild", async function () {
    const [ethGild, priceOracle, xauOracle, ethOracle] = (await deployEthGild()) as [
      NativeGild,
      ChainlinkTwoFeedPriceOracle,
      TestChainlinkDataFeed,
      TestChainlinkDataFeed
    ];

    const testReentrantFactory = await ethers.getContractFactory(
      "TestReentrant"
    );
    const testReentrant = await testReentrantFactory.deploy();
    await testReentrant.deployed();

    await testReentrant.gild(ethGild.address, { value: 3000 });

    await assertError(
      async () =>
        await testReentrant.lowValueUngild(
          ethGild.address,
          expectedReferencePrice
        ),
      "UNGILD_ETH",
      "failed to revert an error in ungild receive"
    );
  });

  it("should error low value reentrant gild", async function () {
    const [ethGild, priceOracle, xauOracle, ethOracle] = (await deployEthGild()) as [
      NativeGild,
      ChainlinkTwoFeedPriceOracle,
      TestChainlinkDataFeed,
      TestChainlinkDataFeed
    ];

    const testReentrantFactory = await ethers.getContractFactory(
      "TestReentrant"
    );
    const testReentrant = await testReentrantFactory.deploy();
    await testReentrant.deployed();

    await assertError(
      async () => await testReentrant.gild(ethGild.address, { value: 1800 }),
      "revert ERC1155: ERC1155Receiver rejected tokens",
      "failed to revert an error in erc1155 receive"
    );
  });
});
