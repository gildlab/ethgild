import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import { deployNativeGild, getEventArgs, priceOne } from "./util";
import type { NativeGild } from "../typechain/NativeGild";
import type { ChainlinkTwoFeedPriceOracle } from "../typechain/ChainlinkTwoFeedPriceOracle";
import type { TestChainlinkDataFeed } from "../typechain/TestChainlinkDataFeed";

chai.use(solidity);
const { expect, assert } = chai;

describe("gild events", async function () {
  it("should emit events on gild and ungild", async function () {
    const signers = await ethers.getSigners();
    const [ethGild, priceOracle] = (await deployNativeGild()) as [
      NativeGild,
      ChainlinkTwoFeedPriceOracle,
      TestChainlinkDataFeed,
      TestChainlinkDataFeed
    ];

    const alice = signers[0];

    const price = await priceOracle.price();

    const ethAmount = 5000;

    const id1155 = price;

    const gildTx = await ethGild.gild(0, { value: ethAmount });

    const gildEventArgs = await getEventArgs(gildTx, "Gild", ethGild);

    assert(
      gildEventArgs.sender === alice.address,
      `incorrect Gild sender. expected ${alice.address} got ${gildEventArgs.sender}`
    );
    assert(
      gildEventArgs.price.eq(price),
      `incorrect Gild reference price. expected ${price} got ${gildEventArgs.xauReferencePrice}`
    );
    assert(
      gildEventArgs.amount.eq(ethAmount),
      `incorrect Gild ethAmount. expected ${ethAmount} got ${gildEventArgs.ethAmount}`
    );

    const aliceBalance = await ethGild["balanceOf(address)"](alice.address);

    const alice1155BalanceBefore = await ethGild["balanceOf(address,uint256)"](
      alice.address,
      id1155
    );
    assert(
      aliceBalance.eq(alice1155BalanceBefore),
      `incorrect balance before. expected ${aliceBalance} got ${alice1155BalanceBefore}`
    );

    const gildTransferSingleEventArgs = await getEventArgs(
      gildTx,
      "TransferSingle",
      ethGild
    );
    assert(
      gildTransferSingleEventArgs.id.eq(id1155),
      `incorrect TransferSingle id. expected ${id1155} got ${gildTransferSingleEventArgs.id}`
    );
    assert(
      gildTransferSingleEventArgs.value.eq(aliceBalance),
      `incorrect TransferSingle value. expected ${aliceBalance} got ${gildTransferSingleEventArgs.value}`
    );

    const gildTransferEventArgs = await getEventArgs(
      gildTx,
      "Transfer",
      ethGild
    );
    assert(
      gildTransferEventArgs.value.eq(aliceBalance),
      `incorrect Transfer value. expected ${aliceBalance} got ${gildTransferEventArgs.value}`
    );

    const ungildERC1155Amount = aliceBalance.mul(1000).div(1001);
    const ungildTx = await ethGild.ungild(price, ungildERC1155Amount);

    const ungildEventArgs = await getEventArgs(ungildTx, "Ungild", ethGild);

    // Ungild ETH is always rounded down.
    const ungildAmount = ungildERC1155Amount.mul(priceOne).div(price);

    assert(
      ungildEventArgs.sender === alice.address,
      `incorrect ungild sender. expected ${alice.address} got ${ungildEventArgs.sender}`
    );
    assert(
      ungildEventArgs.price.eq(price),
      `incorrect ungild xauReferencePrice. expected ${price} got ${ungildEventArgs.price}`
    );
    assert(
      ungildEventArgs.amount.eq(ungildAmount),
      `wrong ungild amount. expected ${ungildAmount} actual ${ungildEventArgs.amount}`
    );

    const alice1155BalanceAfter = await ethGild["balanceOf(address,uint256)"](
      alice.address,
      id1155
    );
    const expected1155BalanceAfter =
      alice1155BalanceBefore.sub(ungildERC1155Amount);
    assert(
      alice1155BalanceAfter.eq(expected1155BalanceAfter),
      `incorrect 1155 balance after. expected ${expected1155BalanceAfter} got ${alice1155BalanceAfter}`
    );
  });
});
