import { ethers } from "hardhat";
import {
  deployERC20PriceOracleVault,
  expectedUri,
  fixedPointMul,
} from "../util";

const assert = require("assert");

describe("erc1155 usage", async function () {
  it("should initialize well", async function () {
    const [vault, asset, price, receipt] = await deployERC20PriceOracleVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];
    const id = 12345;

    const erc1155Uri = await receipt.connect(alice).uri(id);

    assert(
      erc1155Uri === expectedUri,
      `erc1155 did not construct with correct uri expected - ${expectedUri}, got - ${erc1155Uri} `
    );
  });

  it("should only send itself", async function () {
    const signers = await ethers.getSigners();

    const [vault, erc20Token, priceOracle, receipt] =
      await deployERC20PriceOracleVault();
    const shareRatio = await priceOracle.price();
    const alice = signers[0];
    const bob = signers[1];
    const depositAmount = ethers.BigNumber.from(1000);

    await erc20Token
      .connect(alice)
      .increaseAllowance(vault.address, depositAmount);
    await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](
        depositAmount,
        alice.address,
        shareRatio,
        []
      );

    const expectedErc20Balance = fixedPointMul(depositAmount, shareRatio);
    const expectedErc20BalanceAfter = expectedErc20Balance;
    const expectedErc1155Balance = expectedErc20Balance;
    const expectedErc1155BalanceAfter = expectedErc1155Balance.div(2);
    const expected1155ID = await priceOracle.price();

    const erc20Balance = await vault
      .connect(alice)
      ["balanceOf(address)"](signers[0].address);
    assert(
      erc20Balance.eq(expectedErc20Balance),
      `wrong erc20 balance ${expectedErc20Balance} ${erc20Balance}`
    );

    const erc1155Balance = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](alice.address, expected1155ID);
    assert(
      erc1155Balance.eq(expectedErc1155Balance),
      `wrong erc1155 balance ${expectedErc20Balance} ${erc1155Balance}`
    );

    await receipt
      .connect(alice)
      .safeTransferFrom(
        alice.address,
        bob.address,
        expected1155ID,
        expectedErc1155BalanceAfter,
        []
      );

    const erc20BalanceAfter = await vault
      .connect(alice)
      ["balanceOf(address)"](alice.address);
    assert(
      erc20BalanceAfter.eq(expectedErc20BalanceAfter),
      `wrong erc20 balance after ${expectedErc20BalanceAfter} ${erc20BalanceAfter}`
    );

    const erc20BalanceAfter2 = await vault
      .connect(bob)
      ["balanceOf(address)"](bob.address);
    assert(
      erc20BalanceAfter2.eq(0),
      `wrong erc20 balance after 2 0 ${erc20BalanceAfter2}`
    );

    const erc1155BalanceAfter = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](alice.address, expected1155ID);
    assert(
      erc1155BalanceAfter.eq(expectedErc1155BalanceAfter),
      `wrong erc1155 balance after ${expectedErc1155BalanceAfter} ${erc1155BalanceAfter}`
    );

    const erc1155BalanceAfter2 = await receipt
      .connect(bob)
      ["balanceOf(address,uint256)"](bob.address, expected1155ID);
    assert(
      erc1155BalanceAfter2.eq(expectedErc1155BalanceAfter),
      `wrong erc1155 balance 2 after ${expectedErc1155BalanceAfter} ${erc1155BalanceAfter2}`
    );
  });
});
