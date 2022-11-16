import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import {
  assertError,
  deployERC20PriceOracleVault,
  expectedReferencePrice,
  fixedPointMul,
  fixedPointDiv,
} from "../util";

chai.use(solidity);

const { assert } = chai;

describe("deposit", async function () {
  it("should not zero deposit", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[1];

    const [vault, asset] = await deployERC20PriceOracleVault();

    const totalTokenSupply = await asset.totalSupply();
    const aliceDepositAmount = totalTokenSupply.div(2);

    // give alice reserve to cover cost
    await asset.transfer(alice.address, aliceDepositAmount);

    const aliceReserveBalance = await asset.balanceOf(alice.address);

    await asset.connect(alice).approve(vault.address, aliceReserveBalance);

    await assertError(
      async () =>
        await vault["deposit(uint256,address)"](
          ethers.BigNumber.from(0),
          alice.address
        ),
      "0_ASSETS",
      "failed to prevent a zero value deposit"
    );
  });

<<<<<<< HEAD
  it.only("should deposit a sensible reference price", async function () {
=======
  it("should deposit a sensible reference price", async function () {

>>>>>>> c6ea1c69e291bea80747f2d04b760479fee34b5a
    const signers = await ethers.getSigners();

    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

    const alice = signers[1];

    const totalTokenSupply = await asset.totalSupply();

    const aliceDepositAmount = totalTokenSupply.div(2);

    // give alice reserve to cover cost
    await asset.transfer(alice.address, aliceDepositAmount);

    // Min shareRatio MUST be respected
    const shareRatio = await priceOracle.price();

    await asset
      .connect(alice)
      .increaseAllowance(vault.address, aliceDepositAmount);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["deposit(uint256,address,uint256,bytes)"](
            aliceDepositAmount,
            alice.address,
            shareRatio.add(1),
            []
          ),
      "MIN_SHARE_RATIO",
      "failed to respect min price"
    );
    await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](
        aliceDepositAmount,
        alice.address,
        shareRatio,
        []
      );

    const expectedShares = fixedPointMul(shareRatio, aliceDepositAmount);
    const aliceShares = await vault["balanceOf(address)"](alice.address);
    assert(
      aliceShares.eq(expectedShares),
      `wrong alice shares ${expectedShares} ${aliceShares}`
    );
  });

  it("should deposit and withdraw", async function () {
    const signers = await ethers.getSigners();

    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

    const alice = signers[0];
    const bob = signers[1];

    const shareRatio = await priceOracle.price();
    const id1155 = shareRatio;
    assert(
      shareRatio.eq(expectedReferencePrice),
      `bad shareRatio ${shareRatio} ${expectedReferencePrice}`
    );

    let totalTokenSupply = await asset.totalSupply();

    const aliceEthAmount = totalTokenSupply.div(2);

    await asset.connect(alice).increaseAllowance(vault.address, aliceEthAmount);

    await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](
        aliceEthAmount,
        alice.address,
        shareRatio,
        []
      );

    const expectedAliceBalance = fixedPointMul(
      aliceEthAmount,
      expectedReferencePrice
    );
    const aliceBalance = await vault["balanceOf(address)"](alice.address);
    assert(
      aliceBalance.eq(expectedAliceBalance),
      `wrong ERC20 balance ${aliceBalance} ${expectedAliceBalance}`
    );

    const bobErc20Balance = await vault["balanceOf(address)"](bob.address);
    assert(
      bobErc20Balance.eq(0),
      `wrong bob erc20 balance ${bobErc20Balance} 0`
    );

    const erc1155Balance = await vault["balanceOf(address,uint256)"](
      alice.address,
      id1155
    );
    assert(
      erc1155Balance.eq(expectedAliceBalance),
      `wrong erc1155 balance ${erc1155Balance} ${expectedAliceBalance}`
    );

    const bobErc1155Balance = await vault["balanceOf(address,uint256)"](
      bob.address,
      id1155
    );
    assert(
      bobErc1155Balance.eq(0),
      `wrong bob erc1155 balance ${bobErc1155Balance} 0`
    );

    totalTokenSupply = await asset.totalSupply();

    const bobEthAmount = totalTokenSupply.div(3);

    await asset.transfer(bob.address, bobEthAmount);

    await asset.connect(bob).increaseAllowance(vault.address, bobEthAmount);

    await vault
      .connect(bob)
      ["deposit(uint256,address,uint256,bytes)"](
        bobEthAmount,
        bob.address,
        shareRatio,
        []
      );

    const expectedBobBalance = fixedPointMul(
      expectedReferencePrice,
      bobEthAmount
    );
    const bobBalance = await vault["balanceOf(address)"](bob.address);
    assert(
      bobBalance.eq(expectedBobBalance),
      `wrong bob erc20 balance ${bobBalance} ${expectedBobBalance}`
    );

    const erc1155BobBalance = await vault["balanceOf(address,uint256)"](
      bob.address,
      id1155
    );
    assert(
      erc1155BobBalance.eq(expectedBobBalance),
      `wrong bob erc1155 balance ${erc1155BobBalance} ${expectedBobBalance}`
    );

    await vault
      .connect(alice)
      ["redeem(uint256,address,address,uint256)"](
        erc1155Balance,
        alice.address,
        alice.address,
        shareRatio
      );
    const erc20AliceBalanceWithdraw = await vault["balanceOf(address)"](
      alice.address
    );

    assert(
      erc20AliceBalanceWithdraw.eq(0),
      `wrong alice erc20 balance after redeem ${erc20AliceBalanceWithdraw} 0`
    );

    // alice cannot withdraw a different shareRatio deposit.
    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["redeem(uint256,address,address,uint256)"](
            erc1155Balance.sub(1),
            alice.address,
            alice.address,
            shareRatio
          ),
      "burn amount exceeds balance",
      "failed to prevent shareRatio manipulation"
    );

    const erc1155AliceBalanceRedeem = await vault["balanceOf(address,uint256)"](
      alice.address,
      id1155
    );
    assert(
      erc1155AliceBalanceRedeem.eq(0),
      `wrong alice erc1155 balance after redeem ${erc1155AliceBalanceRedeem} 0`
    );
  });

  // it("should trade erc1155", async function () {
  //   const signers = await ethers.getSigners();
  //
  //   const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
  //
  //   const alice = signers[0];
  //   const bob = signers[1];
  //
  //   const aliceVault = vault.connect(alice);
  //   const bobVault = vault.connect(bob);
  //
  //   const shareRatio = await priceOracle.price();
  //   const id1155 = shareRatio;
  //
  //   let totalTokenSupply = await asset.totalSupply();
  //
  //   const aliceAssetBalanceAmount = totalTokenSupply.div(2);
  //
  //   await asset.transfer(alice.address, aliceAssetBalanceAmount);
  //
  //   await asset
  //     .connect(alice)
  //     .increaseAllowance(vault.address, aliceAssetBalanceAmount);
  //
  //   await aliceVault["deposit(uint256,address)"](
  //     aliceAssetBalanceAmount,
  //     alice.address
  //   );
  //
  //   const aliceShareBalance = await vault["balanceOf(address)"](alice.address);
  //
  //   const expectedAliceShareBalance = fixedPointMul(
  //     shareRatio,
  //     aliceAssetBalanceAmount
  //   );
  //   assert(
  //     expectedAliceShareBalance.eq(aliceShareBalance),
  //     `wrong alice share balance`
  //   );
  //
  //   // transfer all receipt from alice to bob.
  //   await aliceVault.safeTransferFrom(
  //     alice.address,
  //     bob.address,
  //     id1155,
  //     aliceShareBalance,
  //     []
  //   );
  //
  //   // alice cannot withdraw after sending to bob.
  //   await assertError(
  //     async () =>
  //       await aliceVault["redeem(uint256,address,address,uint256)"](
  //         1000,
  //         alice.address,
  //         alice.address,
  //         shareRatio
  //       ),
  //     "burn amount exceeds balance",
  //     "failed to prevent alice withdrawing after sending erc1155"
  //   );
  //
  //   // bob cannot withdraw without erc20
  //   await assertError(
  //     async () =>
  //       await bobVault["redeem(uint256,address,address,uint256)"](
  //         1000,
  //         bob.address,
  //         bob.address,
  //         shareRatio
  //       ),
  //     "burn amount exceeds balance",
  //     "failed to prevent bob withdrawing without receiving erc20"
  //   );
  //
  //   // erc20 transfer all of alice's shares to bob.
  //   await aliceVault.transfer(bob.address, aliceShareBalance);
  //
  //   await assertError(
  //     async () =>
  //       await aliceVault["redeem(uint256,address,address,uint256)"](
  //         1000,
  //         alice.address,
  //         alice.address,
  //         shareRatio
  //       ),
  //     "burn amount exceeds balance",
  //     "failed to prevent alice withdrawing after sending erc1155 and erc20"
  //   );
  //
  //   // bob can redeem now
  //   const bobAssetBalanceBefore = await asset.balanceOf(bob.address);
  //   const bobReceiptBalance = await vault["balanceOf(address,uint256)"](
  //     bob.address,
  //     id1155
  //   );
  //
  //   const bobRedeemTx = await bobVault[
  //     "redeem(uint256,address,address,uint256)"
  //   ](bobReceiptBalance, bob.address, bob.address, shareRatio);
  //   await bobRedeemTx.wait();
  //   const bobReceiptBalanceAfter = await vault["balanceOf(address,uint256)"](
  //     bob.address,
  //     id1155
  //   );
  //   const bobAssetBalanceAfter = await asset.balanceOf(bob.address);
  //   assert(
  //     bobReceiptBalanceAfter.eq(0),
  //     `bob did not redeem all 1155 receipt amounts`
  //   );
  //
  //   const bobAssetBalanceDiff = bobAssetBalanceAfter.sub(bobAssetBalanceBefore);
  //   // Bob should be able to withdraw what alice deposited.
  //   const bobAssetBalanceDiffExpected = fixedPointDiv(
  //     aliceShareBalance,
  //     shareRatio
  //   );
  //   assert(
  //     bobAssetBalanceDiff.eq(bobAssetBalanceDiffExpected),
  //     `wrong bob asset diff ${bobAssetBalanceDiffExpected} ${bobAssetBalanceDiff}`
  //   );
  // });
});
