import { ethers } from "hardhat";
import {
  deployERC20PriceOracleVault,
  fixedPointDiv,
  fixedPointMul,
  getEventArgs,
} from "../util";

const assert = require("assert");

describe("events", async function () {
  it("should emit events on deposit and withdraw", async function () {
    const signers = await ethers.getSigners();
    const [vault, asset, priceOracle, receipt] =
      await deployERC20PriceOracleVault();

    const alice = signers[0];

    const shareRatio = await priceOracle.price();

    const ethAmount = 5000;

    const id1155 = shareRatio;
    await asset.connect(alice).increaseAllowance(vault.address, ethAmount);

    const depositTx = await vault
      .connect(alice)
      ["deposit(uint256,address)"](ethAmount, alice.address);

    const depositEventArgs = await getEventArgs(depositTx, "Deposit", vault);

    assert(
      depositEventArgs.assets.eq(ethAmount),
      `incorrect assets. expected ${ethAmount} got ${depositEventArgs.assets}`
    );

    const aliceBalance = await vault
      .connect(alice)
      ["balanceOf(address)"](alice.address);

    const alice1155BalanceBefore = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](alice.address, id1155);
    assert(
      aliceBalance.eq(alice1155BalanceBefore),
      `incorrect balance before. expected ${aliceBalance} got ${alice1155BalanceBefore}`
    );

    const { sender, owner, assets, shares, id } = await getEventArgs(
      depositTx,
      "DepositWithReceipt",
      vault
    );

    let expectedShares = fixedPointMul(
      ethers.BigNumber.from(ethAmount),
      shareRatio
    );
    assert(
      sender === alice.address,
      `incorrect sender expected ${alice.address} got ${sender}`
    );
    assert(
      owner === alice.address,
      `incorrect owner expected ${alice.address} got ${owner}`
    );
    assert(
      assets.eq(ethAmount),
      `incorrect assets expected ${ethAmount} got ${assets}`
    );
    assert(
      shares.eq(expectedShares),
      `incorrect shares expected ${expectedShares} got ${shares}`
    );
    assert(id.eq(id1155), `incorrect id expected ${id1155} got ${id}`);

    const transferEventArgs = await getEventArgs(depositTx, "Transfer", vault);
    assert(
      transferEventArgs.value.eq(aliceBalance),
      `incorrect Transfer value. expected ${aliceBalance} got ${transferEventArgs.value}`
    );

    const ERC1155Amount = aliceBalance;
    const redeemTx = await vault
      .connect(alice)
      ["redeem(uint256,address,address,uint256,bytes)"](
        ERC1155Amount,
        alice.address,
        alice.address,
        shareRatio,
        []
      );

    const withdrawEventArgs = await getEventArgs(redeemTx, "Withdraw", vault);
    // withdrawAmount is always rounded down.
    const withdrawAmount = fixedPointDiv(ERC1155Amount, shareRatio);
    assert(
      withdrawEventArgs.assets.eq(withdrawAmount),
      `wrong assets amount. expected ${withdrawAmount} actual ${withdrawEventArgs.assets}`
    );

    const withdrawEvent = await getEventArgs(
      redeemTx,
      "WithdrawWithReceipt",
      vault
    );

    let expectedAssets = fixedPointDiv(
      ethers.BigNumber.from(ERC1155Amount),
      shareRatio
    );

    assert(
      withdrawEvent.sender === alice.address,
      `incorrect sender expected ${alice.address} got ${withdrawEvent.sender}`
    );
    assert(
      withdrawEvent.receiver === alice.address,
      `incorrect receiver expected ${alice.address} got ${withdrawEvent.receiver}`
    );
    assert(
      withdrawEvent.assets.eq(expectedAssets),
      `incorrect assets expected ${expectedAssets} got ${withdrawEvent.assets}`
    );
    assert(
      withdrawEvent.shares.eq(ERC1155Amount),
      `incorrect shares expected ${ERC1155Amount} got ${withdrawEvent.shares}`
    );
    assert(
      withdrawEvent.id.eq(id1155),
      `incorrect id expected ${id1155} got ${withdrawEvent.id}`
    );
    assert(
      withdrawEvent.owner === alice.address,
      `incorrect id expected ${alice.address} got ${withdrawEvent.owner}`
    );

    const alice1155BalanceAfter = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](alice.address, id1155);

    const expected1155BalanceAfter = alice1155BalanceBefore.sub(ERC1155Amount);
    assert(
      alice1155BalanceAfter.eq(expected1155BalanceAfter),
      `incorrect 1155 balance after. expected ${expected1155BalanceAfter} got ${alice1155BalanceAfter}`
    );
  });
});
