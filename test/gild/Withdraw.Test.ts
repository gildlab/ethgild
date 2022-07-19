import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import {
  assertError,
  deployERC20PriceOracleVault,
  fixedPointDiv,
  fixedPointMul,
} from "../util";

chai.use(solidity);

const { assert } = chai;
describe("Withdraw", async function () {
  it("Calculates correct maxWithdraw", async function () {
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

    const expectedMaxWithdraw = fixedPointDiv(receiptBalance, price);
    await vault.setWithdrawId(price);

    const maxWithdraw = await vault["maxWithdraw(address)"](alice.address);

    assert(maxWithdraw.eq(expectedMaxWithdraw), `Wrong max withdraw amount`);
  });
  it("Overloaded MaxWithdraw - Calculates correct maxWithdraw", async function () {
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

    const expectedMaxWithdraw = fixedPointDiv(receiptBalance, price);
    const maxWithdraw = await vault["maxWithdraw(address,uint256)"](
      alice.address,
      price
    );

    assert(maxWithdraw.eq(expectedMaxWithdraw), `Wrong max withdraw amount`);
  });
  it("PreviewWithdraw - calculates correct shares", async function () {
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
    //calculate max assets available for withdraw
    const withdrawBalance = fixedPointDiv(aliceAssets, price);

    await vault.setWithdrawId(price);

    const expectedPreviewWithdraw = fixedPointMul(withdrawBalance, price).add(
      1
    );
    const previewWithdraw = await vault["previewWithdraw(uint256)"](
      withdrawBalance
    );

    assert(
      previewWithdraw.eq(expectedPreviewWithdraw),
      `Wrong preview withdraw amount`
    );
  });
  it("Overloaded PreviewWithdraw - calculates correct shares", async function () {
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
    //calculate max assets available for withdraw
    const withdrawBalance = fixedPointDiv(aliceAssets, price);

    const expectedPreviewWithdraw = fixedPointMul(withdrawBalance, price).add(
      1
    );
    const previewWithdraw = await vault["previewWithdraw(uint256,uint256)"](
      withdrawBalance,
      price
    );

    assert(
      previewWithdraw.eq(expectedPreviewWithdraw),
      `Wrong preview withdraw amount`
    );
  });
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

    //calculate max assets available for withdraw
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
  it("Should not withdraw on zero assets", async function () {
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

    await vault.setWithdrawId(price);

    await assertError(
        async () =>
            await vault["withdraw(uint256,address,address)"](
                ethers.BigNumber.from(0),
                alice.address,
                alice.address
            ),
        "0_ASSETS",
        "failed to prevent a zero asset withdraw"
    );
  });
});
