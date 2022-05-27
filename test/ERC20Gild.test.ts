import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import {
  deployNativeGild,
  expectedReferencePrice,
  assertError,
  eighteenZeros,
  priceOne,
  RESERVE_ONE
} from "./util";
import type { ERC20Gild } from "../typechain/ERC20Gild";
import type { ChainlinkTwoFeedPriceOracle } from "../typechain/ChainlinkTwoFeedPriceOracle";
import type { TestChainlinkDataFeed } from "../typechain/TestChainlinkDataFeed";
import type { TestErc20 } from "../typechain/TestErc20";


chai.use(solidity);

const { expect, assert } = chai;

describe("deposit", async function () {
  it("should not zero deposit", async function () {

    const signers = await ethers.getSigners();
    const alice = signers[1];



    const [ethGild, priceOracle, erc20Token] = (await deployNativeGild()) as [
      ERC20Gild,
      ChainlinkTwoFeedPriceOracle,
      TestErc20,
      TestChainlinkDataFeed,
      TestChainlinkDataFeed
    ];

    const totalTokenSupply = ethers.BigNumber.from("2000").mul(priceOne);
    const staticPrice = ethers.BigNumber.from("75").mul(RESERVE_ONE);

    const desiredUnitsAlice = totalTokenSupply;
    const costAlice = staticPrice.mul(desiredUnitsAlice).div(priceOne);

    // give alice reserve to cover cost
    await erc20Token.transfer(alice.address, costAlice);

    const aliceReserveBalance = await erc20Token.balanceOf(alice.address);

    await erc20Token
    .connect(alice)
    .approve(ethGild.address, aliceReserveBalance);

    await assertError(
      async () => await ethGild["deposit(uint256,address)"](ethers.BigNumber.from(0), alice.address),
      "0_ASSETS",
      "failed to prevent a zero value deposit"
    );
  });

  it("should deposit a sensible reference price", async function () {
    // At the time of writing
    // Block number: 12666285
    //
    // Trading View ETHUSD: 2218.71
    // Chainlink ETHUSD (8 decimals): 2228 25543758
    //
    // Trading View XAUUSD: 1763.95
    // Chainlink XAUUSD (8 decimals): 1767 15500000
    //
    // ~ 1 ETH should buy 1.26092812321 XAU

    const signers = await ethers.getSigners();

    const [ethGild, priceOracle, erc20Token] = (await deployNativeGild()) as [
      ERC20Gild,
      ChainlinkTwoFeedPriceOracle,
      TestErc20,
      TestChainlinkDataFeed,
      TestChainlinkDataFeed
    ];

    const alice = signers[1];

    const totalTokenSupply = await erc20Token.totalSupply()

    const aliceDepositAmount = totalTokenSupply.div(2)

    // give alice reserve to cover cost
    await erc20Token.transfer(alice.address, aliceDepositAmount);

    // Min gild price MUST be respected
    const oraclePrice = await priceOracle.price();

    await erc20Token.connect(alice).increaseAllowance(ethGild.address, aliceDepositAmount);

    await assertError(
      async () =>
      await ethGild.connect(alice)["deposit(uint256,address,uint256)"](aliceDepositAmount, alice.address, oraclePrice.add(1)),
      "MIN_PRICE",
      "failed to respect min price"
    );
    await ethGild.connect(alice)["deposit(uint256,address,uint256)"](aliceDepositAmount, alice.address, oraclePrice);

    const expectedShares = oraclePrice.mul(aliceDepositAmount).div(priceOne);
    const aliceShares = await ethGild["balanceOf(address)"](alice.address);
    assert(
      aliceShares.eq(expectedShares),
      `wrong alice ETHg ${expectedShares} ${aliceShares}`
    );
  });

  it("should deposit and withdraw", async function () {
    const signers = await ethers.getSigners();

    const [ethGild, priceOracle, erc20Token] = (await deployNativeGild()) as [
      ERC20Gild,
      ChainlinkTwoFeedPriceOracle,
      TestErc20,
      TestChainlinkDataFeed,
      TestChainlinkDataFeed
    ];

    const alice = signers[0];
    const bob = signers[1];

    const price = await priceOracle.price();
    const id1155 = price;
    assert(
      price.eq(expectedReferencePrice),
      `bad referencePrice ${price} ${expectedReferencePrice}`
    );

    let totalTokenSupply = await erc20Token.totalSupply()

    const aliceEthAmount = totalTokenSupply.div(2)


    await erc20Token.connect(alice).increaseAllowance(ethGild.address, aliceEthAmount);

    await ethGild.connect(alice)["deposit(uint256,address)"](aliceEthAmount, alice.address);

    const expectedAliceBalance = expectedReferencePrice
      .mul(aliceEthAmount)
      .div(priceOne);
    const ethgAliceBalance = await ethGild["balanceOf(address)"](alice.address);
    assert(
      ethgAliceBalance.eq(expectedAliceBalance),
      `wrong ERC20 balance ${ethgAliceBalance} ${expectedAliceBalance}`
    );

    const bobErc20Balance = await ethGild["balanceOf(address)"](bob.address);
    assert(
      bobErc20Balance.eq(0),
      `wrong bob erc20 balance ${bobErc20Balance} 0`
    );

    const erc1155Balance = await ethGild["balanceOf(address,uint256)"](
      alice.address,
      id1155
    );
    assert(
      erc1155Balance.eq(expectedAliceBalance),
      `wrong erc1155 balance ${erc1155Balance} ${expectedAliceBalance}`
    );

    const bobErc1155Balance = await ethGild["balanceOf(address,uint256)"](
      bob.address,
      id1155
    );
    assert(
      bobErc1155Balance.eq(0),
      `wrong bob erc1155 balance ${bobErc1155Balance} 0`
    );

    await assertError(
      async () => await ethGild.connect(alice)["redeem(uint256,address,address,uint256)"](erc1155Balance, alice.address, erc20Token.address, price),
      "burn amount exceeds balance",
      "failed to apply fee to ungild"
    );


    totalTokenSupply = await erc20Token.totalSupply()

    const bobEthAmount = totalTokenSupply.div(3)

    await erc20Token.transfer(bob.address, bobEthAmount);
    
    await erc20Token.connect(bob).increaseAllowance(ethGild.address, bobEthAmount);

    await ethGild.connect(bob)["deposit(uint256,address)"](bobEthAmount, bob.address);


    const expectedBobBalance = expectedReferencePrice
      .mul(bobEthAmount)
      .div(priceOne);
    const ethgBobBalance = await ethGild["balanceOf(address)"](bob.address);
    assert(
      ethgBobBalance.eq(expectedBobBalance),
      `wrong bob erc20 balance ${ethgBobBalance} ${expectedBobBalance}`
    );

    const erc1155BobBalance = await ethGild["balanceOf(address,uint256)"](
      bob.address,
      id1155
    );
    assert(
      erc1155BobBalance.eq(expectedBobBalance),
      `wrong bob erc1155 balance ${erc1155BobBalance} ${expectedBobBalance}`
    );

    // const bobToAliceEthg = ethgAliceBalance
    //   .mul(1001)
    //   .div(1000)
    //   .sub(ethgAliceBalance)
    //   .sub(1);
    // await ethGild.connect(bob).transfer(alice.address, bobToAliceEthg);

    // // alice cannot withdraw with less than the overburn erc20
    // await assertError(
    //   //3
    //   async () => await aliceEthGild.redeem([]),
    //   "burn amount exceeds balance",
    //   "failed to overburn"
    // );

    await ethGild.connect(alice)["redeem(uint256,address,address,uint256)"](erc1155Balance, alice.address, alice.address, price);
    const erc20AliceBalanceWithdraw = await ethGild["balanceOf(address)"](
      alice.address
    );
    
    assert(
      erc20AliceBalanceWithdraw.eq(0),
      `wrong alice erc20 balance after ungild ${erc20AliceBalanceWithdraw} 0`
    );

    // alice cannot withdraw a different referencePrice deposit.
    await assertError(
      async () => await ethGild.connect(alice)["redeem(uint256,address,address,uint256)"](erc1155Balance.sub(1), alice.address, alice.address, price),
      "burn amount exceeds balance",
      "failed to prevent gild referencePrice manipulation"
    );

    const erc1155AliceBalanceUngild = await ethGild[
      "balanceOf(address,uint256)"
    ](alice.address, id1155);
    assert(
      erc1155AliceBalanceUngild.eq(0),
      `wrong alice erc1155 balance after ungild ${erc1155AliceBalanceUngild} 0`
    );

  });

  // it("should trade erc1155", async function () {
  //   const signers = await ethers.getSigners();
  //   const [ethGild, priceOracle] = (await deployNativeGild()) as [
  //     ERC20Gild,
  //     ChainlinkTwoFeedPriceOracle,
  //     TestChainlinkDataFeed,
  //     TestChainlinkDataFeed
  //   ];

  //   const alice = signers[0];
  //   const bob = signers[1];

  //   const aliceEthGild = ethGild.connect(alice);
  //   const bobEthGild = ethGild.connect(bob);

  //   const price = await priceOracle.price();
  //   const id1155 = price;

  //   const aliceEthAmount = ethers.BigNumber.from("10" + eighteenZeros);
  //   const bobEthAmount = ethers.BigNumber.from("9" + eighteenZeros);

  //   await aliceEthGild.redeem([]);

  //   const aliceBalance = await ethGild["balanceOf(address)"](alice.address);
  //   // erc1155 transfer.
  //   await aliceEthGild.safeTransferFrom(
  //     alice.address,
  //     bob.address,
  //     id1155,
  //     aliceBalance,
  //     []
  //   );

  //   // alice cannot withdraw after sending to bob.
  //   await assertError(
  //     //3
  //     async () => await aliceEthGild.redeem([]),
  //     "burn amount exceeds balance",
  //     "failed to prevent alice withdrawing after sending erc1155"
  //   );

  //   // bob cannot withdraw without erc20
  //   await assertError(
  //     //3
  //     async () => await bobEthGild.redeem([]),
  //     "burn amount exceeds balance",
  //     "failed to prevent bob withdrawing without receiving erc20"
  //   );

  //   // erc20 transfer.
  //   await aliceEthGild.transfer(bob.address, aliceBalance);

  //   await assertError(
  //     //3
  //     async () => await aliceEthGild.redeem([]),
  //     "burn amount exceeds balance",
  //     "failed to prevent alice withdrawing after sending erc1155 and erc20"
  //   );

  //   // bob can withdraw now
  //   const bobEthBefore = await bob.getBalance();
  //   const erc1155BobBalance = await ethGild["balanceOf(address,uint256)"](
  //     bob.address,
  //     id1155
  //   );
  //   //3
  //   const bobUngildTx = await bobEthGild.redeem([]);
  //   const bobUngildTxReceipt = await bobUngildTx.wait();
  //   const erc1155BobBalanceAfter = await ethGild["balanceOf(address,uint256)"](
  //     bob.address,
  //     id1155
  //   );
  //   const bobEthAfter = await bob.getBalance();
  //   const bobEthDiff = bobEthAfter.sub(bobEthBefore);
  //   // Bob withdraw alice's gilded eth
  //   const bobEthDiffExpected = aliceEthAmount
  //     .mul(1000)
  //     .div(1001)
  //     .sub(bobUngildTxReceipt.gasUsed.mul(bobUngildTx.gasPrice || 0));
  //   assert(
  //     bobEthAfter.sub(bobEthBefore).eq(bobEthDiffExpected),
  //     `wrong bob diff ${bobEthDiffExpected} ${bobEthDiff}`
  //   );
  // });
});

