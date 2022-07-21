import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import {
  assertError,
  deployERC20PriceOracleVault,
  fixedPointDiv,
  fixedPointMul,
  ADDRESS_ZERO,
  getEventArgs,
} from "../util";
import { ERC20, ERC20PriceOracleVault } from "../../typechain";
import { BigNumber } from "ethers";
import { WithdrawEvent } from "../../typechain/IERC4626";

chai.use(solidity);

const { assert } = chai;

let vault: ERC20PriceOracleVault,
  asset: ERC20,
  price: BigNumber,
  aliceAddress: string,
  aliceAssets: BigNumber;

describe("Redeem", async function () {
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
  it("Calculates correct maxRedeem", async function () {
    const expectedMaxRedeem = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      price
    );
    await vault.setWithdrawId(price);
    const maxRedeem = await vault["maxRedeem(address)"](aliceAddress);
    assert(
      maxRedeem.eq(expectedMaxRedeem),
      `Wrong max withdraw amount expected ${expectedMaxRedeem} got ${maxRedeem}`
    );
  });
  it("Overloaded maxRedeem - Calculates correct maxRedeem", async function () {
    const expectedMaxRedeem = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      price
    );

    const maxRedeem = await vault["maxRedeem(address,uint256)"](
      aliceAddress,
      price
    );

    assert(
      maxRedeem.eq(expectedMaxRedeem),
      `Wrong max withdraw amount expected ${expectedMaxRedeem} got ${maxRedeem}`
    );
  });
  it("previewRedeem - calculates correct assets", async function () {
    const aliceReceiptBalance = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      price
    );

    await vault.setWithdrawId(price);
    const expectedPreviewRedeem = fixedPointDiv(aliceReceiptBalance, price);

    const assets = await vault["previewRedeem(uint256)"](aliceReceiptBalance);
    assert(
      assets.eq(expectedPreviewRedeem),
      `Wrong asset amount expected ${expectedPreviewRedeem} got ${assets}`
    );
  });
  it("Overloaded previewRedeem - calculates correct assets", async function () {
    const aliceReceiptBalance = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      price
    );

    const expectedAssets = fixedPointDiv(aliceReceiptBalance, price);

    const assets = await vault["previewRedeem(uint256,uint256)"](
      aliceReceiptBalance,
      price
    );
    assert(
      assets.eq(expectedAssets),
      `Wrong asset amount expected ${expectedAssets} got ${assets}`
    );
  });
  it("Redeems", async function () {
    const receiptBalance = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      price
    );

    await vault.setWithdrawId(price);
    await vault["redeem(uint256,address,address)"](
      receiptBalance,
      aliceAddress,
      aliceAddress
    );

    const receiptBalanceAfter = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      price
    );
    assert(
      receiptBalanceAfter.eq(0),
      `alice did not redeem all 1155 receipt amounts`
    );
  });
  it("Should not redeem on zero shares", async function () {
    await vault.setWithdrawId(price);

    await assertError(
      async () =>
        await vault["redeem(uint256,address,address)"](
          ethers.BigNumber.from(0),
          aliceAddress,
          aliceAddress
        ),
      "0_ASSETS",
      "failed to prevent a zero shares redeem"
    );
  });
  it("Should not redeem on zero address receiver", async function () {
    const receiptBalance = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      price
    );

    await vault.setWithdrawId(price);

    await assertError(
      async () =>
        await vault["redeem(uint256,address,address)"](
          receiptBalance,
          ADDRESS_ZERO,
          aliceAddress
        ),
      "0_RECEIVER",
      "failed to prevent a zero address receiver redeem"
    );
  });
  it("Should emit withdraw event", async function () {
    const receiptBalance = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      price
    );
    await vault.setWithdrawId(price);
    const { caller, receiver, owner, assets, shares } = (await getEventArgs(
      await vault["redeem(uint256,address,address)"](
        receiptBalance,
        aliceAddress,
        aliceAddress
      ),
      "Withdraw",
      vault
    )) as WithdrawEvent["args"];

    const expectedAssets = fixedPointDiv(receiptBalance, price);

    assert(
      assets.eq(expectedAssets),
      `wrong assets expected ${expectedAssets} got ${assets}`
    );
    assert(
      caller === aliceAddress,
      `wrong caller expected ${aliceAddress} got ${caller}`
    );
    assert(
      owner === aliceAddress,
      `wrong owner expected ${aliceAddress} got ${owner}`
    );
    assert(
      receiver === aliceAddress,
      `wrong receiver expected ${aliceAddress} got ${receiver}`
    );
    assert(
      shares.eq(receiptBalance),
      `wrong shares expected ${receiptBalance} got ${shares}`
    );
  });
});
