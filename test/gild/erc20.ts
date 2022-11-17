import { assert } from "chai";
import { ethers } from "hardhat";
import {
  deployERC20PriceOracleVault,
  expectedName,
  expectedSymbol,
  fixedPointMul,
} from "../util";

describe("erc20 usage", async function () {
  it("should construct well", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const [vault] = await deployERC20PriceOracleVault();

    const erc20Name = await vault.connect(alice).name();
    const erc20Symbol = await vault.connect(alice).symbol();

    assert(
      erc20Name === expectedName,
      "erc20 did not construct with correct name"
    );
    assert(
      erc20Symbol === expectedSymbol,
      "erc20 did not construct with correct symbol"
    );
  });

  it("should only send itself", async function () {
    const signers = await ethers.getSigners();

    const [vault, erc20Token, priceOracle] =
      await deployERC20PriceOracleVault();

    const alice = signers[0];
    const shareRatio = await priceOracle.price();

    const assetAmount = ethers.BigNumber.from(1000);

    await erc20Token
      .connect(alice)
      .increaseAllowance(vault.address, assetAmount);
    await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](
        assetAmount,
        alice.address,
        shareRatio,
        []
      );

    const expectedErc20Balance = fixedPointMul(assetAmount, shareRatio);

    const expectedErc20BalanceAfter = expectedErc20Balance.div(2);
    const expectedErc1155Balance = expectedErc20Balance;
    const expectedErc1155BalanceAfter = expectedErc1155Balance;
    const expected1155ID = await priceOracle.price();

    const erc20Balance = await vault
      .connect(alice)
      ["balanceOf(address)"](signers[0].address);
    assert(
      erc20Balance.eq(expectedErc20Balance),
      `wrong erc20 balance ${expectedErc20Balance} ${erc20Balance}`
    );

    const erc1155Balance = await vault
      .connect(alice)
      ["balanceOf(address,uint256)"](signers[0].address, expected1155ID);
    assert(
      erc1155Balance.eq(expectedErc1155Balance),
      `wrong erc1155 balance ${expectedErc20Balance} ${erc1155Balance}`
    );

    await vault.transfer(signers[1].address, expectedErc20BalanceAfter);

    const erc20BalanceAfter = await vault
      .connect(alice)
      ["balanceOf(address)"](signers[0].address);
    assert(
      erc20BalanceAfter.eq(expectedErc20BalanceAfter),
      `wrong erc20 balance after ${expectedErc20BalanceAfter} ${erc20BalanceAfter}`
    );

    const erc20BalanceAfter2 = await vault
      .connect(alice)
      ["balanceOf(address)"](signers[1].address);
    assert(
      erc20BalanceAfter2.eq(expectedErc20BalanceAfter),
      `wrong erc20 balance after 2 ${expectedErc20BalanceAfter} ${erc20BalanceAfter2}`
    );

    const erc1155BalanceAfter = await vault
      .connect(alice)
      ["balanceOf(address,uint256)"](signers[0].address, expected1155ID);
    assert(
      erc1155BalanceAfter.eq(expectedErc20Balance),
      `wrong erc1155 balance after ${expectedErc1155BalanceAfter} ${erc1155BalanceAfter}`
    );

    assert(
      (
        await vault
          .connect(alice)
          ["balanceOf(address,uint256)"](signers[1].address, expected1155ID)
      ).eq(0),
      `wrong erc1155 balance 2 after ${expectedErc1155BalanceAfter} ${erc1155BalanceAfter}`
    );
  });
});
