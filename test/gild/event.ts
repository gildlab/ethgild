import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import { deployERC20PriceOracleVault, getEventArgs, priceOne } from "../util";

chai.use(solidity);
const { assert } = chai;

describe("events", async function () {
  it("should emit events on deposit and withdraw", async function () {
    const signers = await ethers.getSigners();
    const [vault, erc20Token, priceOracle] =
      await deployERC20PriceOracleVault();

    const alice = signers[0];

    const shareRatio = await priceOracle.price();

    const ethAmount = 5000;

    const id1155 = shareRatio;
    await erc20Token
      .connect(alice)
      .increaseAllowance(vault.address, ethAmount);

    const depositTx = await vault
      .connect(alice)
      ["deposit(uint256,address)"](ethAmount, alice.address);

    const depositEventArgs = await getEventArgs(depositTx, "Deposit", vault);

    assert(
        depositEventArgs.assets.eq(ethAmount),
      `incorrect assets. expected ${ethAmount} got ${depositEventArgs.assets}`
    );

    const aliceBalance = await vault["balanceOf(address)"](alice.address);

    const alice1155BalanceBefore = await vault["balanceOf(address,uint256)"](
      alice.address,
      id1155
    );
    assert(
      aliceBalance.eq(alice1155BalanceBefore),
      `incorrect balance before. expected ${aliceBalance} got ${alice1155BalanceBefore}`
    );

    const transferSingleEventArgs = await getEventArgs(
      depositTx,
      "TransferSingle",
      vault
    );
    assert(
        transferSingleEventArgs.id.eq(id1155),
      `incorrect TransferSingle id. expected ${id1155} got ${transferSingleEventArgs.id}`
    );
    assert(
        transferSingleEventArgs.value.eq(aliceBalance),
      `incorrect TransferSingle value. expected ${aliceBalance} got ${transferSingleEventArgs.value}`
    );

    const transferEventArgs = await getEventArgs(
      depositTx,
      "Transfer",
      vault
    );
    assert(
        transferEventArgs.value.eq(aliceBalance),
      `incorrect Transfer value. expected ${aliceBalance} got ${transferEventArgs.value}`
    );

    const ERC1155Amount = aliceBalance;
    const redeemTx = await vault["redeem(uint256,address,address,uint256)"](
        ERC1155Amount,
      alice.address,
      alice.address,
      shareRatio
    );

    const withdrawEventArgs = await getEventArgs(redeemTx, "Withdraw", vault);
    // withdrawAmount is always rounded down.
    const withdrawAmount = ERC1155Amount.mul(priceOne).div(shareRatio);
    assert(
        withdrawEventArgs.assets.eq(withdrawAmount),
      `wrong assets amount. expected ${withdrawAmount} actual ${withdrawEventArgs.assets}`
    );

    const withdrawTransferSingleEventArgs = await getEventArgs(
      redeemTx,
      "TransferSingle",
      vault
    );

    assert(
        withdrawTransferSingleEventArgs.id.eq(id1155),
      `incorrect TransferSingle id. expected ${id1155} got ${withdrawTransferSingleEventArgs.id}`
    );
    const alice1155BalanceAfter = await vault["balanceOf(address,uint256)"](
      alice.address,
      id1155
    );
    const expected1155BalanceAfter =
      alice1155BalanceBefore.sub(ERC1155Amount);
    assert(
      alice1155BalanceAfter.eq(expected1155BalanceAfter),
      `incorrect 1155 balance after. expected ${expected1155BalanceAfter} got ${alice1155BalanceAfter}`
    );
  });
});
