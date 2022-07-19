import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import {
  assertError,
  deployERC20PriceOracleVault,
  fixedPointDiv,
  fixedPointMul,
} from "../util";
import { ERC20, ERC20PriceOracleVault } from "../../typechain";
import { BigNumber } from "ethers";

chai.use(solidity);

const { assert } = chai;

let vault: ERC20PriceOracleVault,
  asset: ERC20,
  price: BigNumber,
  aliceAddress: string,
  aliceAssets: BigNumber;

describe("Withdraw", async function () {
  beforeEach(async () => {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const [ERC20PriceOracleVault, Erc20Asset, priceOracle] =
      await deployERC20PriceOracleVault();

    vault = await ERC20PriceOracleVault;
    asset = await Erc20Asset;
    price = await priceOracle.price();
    aliceAddress = alice.address;

    aliceAssets = ethers.BigNumber.from(5000);
    await asset.transfer(aliceAddress, aliceAssets);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAssets);

    const depositTx = await vault["deposit(uint256,address,uint256,bytes)"](
      aliceAssets,
      aliceAddress,
      price,
      []
    );

    await depositTx.wait();
  });
  it("Calculates correct maxWithdraw", async function () {
    const receiptBalance = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      price
    );

    const expectedMaxWithdraw = fixedPointDiv(receiptBalance, price);
    await vault.setWithdrawId(price);

    const maxWithdraw = await vault["maxWithdraw(address)"](aliceAddress);

    assert(maxWithdraw.eq(expectedMaxWithdraw), `Wrong max withdraw amount`);
  });
  it("Overloaded MaxWithdraw - Calculates correct maxWithdraw", async function () {
    const receiptBalance = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      price
    );

    const expectedMaxWithdraw = fixedPointDiv(receiptBalance, price);
    const maxWithdraw = await vault["maxWithdraw(address,uint256)"](
      aliceAddress,
      price
    );

    assert(maxWithdraw.eq(expectedMaxWithdraw), `Wrong max withdraw amount`);
  });
  it("PreviewWithdraw - calculates correct shares", async function () {
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
    const receiptBalance = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      price
    );

    //calculate max assets available for withdraw
    const withdrawBalance = fixedPointDiv(receiptBalance, price);

    await vault.setWithdrawId(price);
    await vault["withdraw(uint256,address,address)"](
      withdrawBalance,
      aliceAddress,
      aliceAddress
    );

    const receiptBalanceAfter = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      price
    );

    assert(
      receiptBalanceAfter.eq(0),
      `alice did not withdraw all 1155 receipt amounts`
    );
  });
  it("Should not withdraw on zero assets", async function () {
    await vault.setWithdrawId(price);

    await assertError(
      async () =>
        await vault["withdraw(uint256,address,address)"](
          ethers.BigNumber.from(0),
          aliceAddress,
          aliceAddress
        ),
      "0_ASSETS",
      "failed to prevent a zero asset withdraw"
    );
  });
});
