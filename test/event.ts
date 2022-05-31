import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import { deployNativeGild, getEventArgs, priceOne } from "./util";
import type { ERC20Gild } from "../typechain/ERC20Gild";
import type { TestErc20 } from "../typechain/TestErc20";
import type { ChainlinkTwoFeedPriceOracle } from "../typechain/ChainlinkTwoFeedPriceOracle";
import type { TestChainlinkDataFeed } from "../typechain/TestChainlinkDataFeed";

chai.use(solidity);
const { expect, assert } = chai;

describe("events", async function () {
  it("should emit events on gild and ungild", async function () {
    const signers = await ethers.getSigners();
    const [ethGild, priceOracle, erc20Token] = (await deployNativeGild()) as [
      ERC20Gild,
      ChainlinkTwoFeedPriceOracle,
      TestErc20,
      TestChainlinkDataFeed,
      TestChainlinkDataFeed
    ];

    const alice = signers[0];

    const price = await priceOracle.price();

    const ethAmount = 5000;

    const id1155 = price;
    await erc20Token.connect(alice).increaseAllowance(ethGild.address, ethAmount);

    const gildTx = await ethGild.connect(alice)["deposit(uint256,address)"](ethAmount, alice.address);

    const gildEventArgs = await getEventArgs(gildTx, "Deposit", ethGild);

    //todo: figure it out
    // assert(
    //   gildEventArgs.sender === alice.address,
    //   `incorrect Gild sender. expected ${alice.address} got ${gildEventArgs.sender}`
    // );
    // assert(
    //   gildEventArgs.price.eq(price),
    //   `incorrect Gild reference price. expected ${price} got ${gildEventArgs.xauReferencePrice}`
    // );
    assert(
      gildEventArgs.assets.eq(ethAmount),
      `incorrect Gild ethAmount. expected ${ethAmount} got ${gildEventArgs.assets}`
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
    const ungildTx = await ethGild["redeem(uint256,address,address,uint256)"](ungildERC1155Amount, alice.address, alice.address, price);

    const ungildEventArgs = await getEventArgs(ungildTx, "Withdraw", ethGild);

    // Ungild ETH is always rounded down.
    const ungildAmount = ungildERC1155Amount.mul(priceOne).div(price);
    //todo: figure it out
    // assert(
    //   ungildEventArgs.sender === alice.address,
    //   `incorrect ungild sender. expected ${alice.address} got ${ungildEventArgs.sender}`
    // );
    // assert(
    //   ungildEventArgs.price.eq(price),
    //   `incorrect ungild xauReferencePrice. expected ${price} got ${ungildEventArgs.price}`
    // );
    assert(
      ungildEventArgs.assets.eq(ungildAmount),
      `wrong ungild amount. expected ${ungildAmount} actual ${ungildEventArgs.assets}`
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
