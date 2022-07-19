import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import {
  deployERC20PriceOracleVault,
  fixedPointDiv,
} from "../util";

chai.use(solidity);

const { assert } = chai;

describe("Withdraw", async function () {
  it("Withdraws", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

    const price = await priceOracle.price();

    const aliceAssets = ethers.BigNumber.from(5000);
    await asset.transfer(alice.address, aliceAssets);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAssets);

    const depositTx = await vault["deposit(uint256,address,uint256,bytes)"](
      aliceAssets,
      alice.address,
      price,
      []
    );

    await depositTx.wait();
    const receiptBalance = await vault["balanceOf(address,uint256)"](
      alice.address,
      price
    );
    const withdrawBalance = fixedPointDiv(receiptBalance, price);

    await vault.setWithdrawId(price);
    await vault["withdraw(uint256,address,address)"](
      withdrawBalance,
      alice.address,
      alice.address
    );

    const receiptBalanceAfter = await vault["balanceOf(address,uint256)"](
      alice.address,
      price
    );

    assert(
      receiptBalanceAfter.eq(0),
      `alice did not withdraw all 1155 receipt amounts`
    );
  });
});
