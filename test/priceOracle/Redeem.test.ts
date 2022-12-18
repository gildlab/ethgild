import { ethers } from "hardhat";
import {
  assertError,
  deployERC20PriceOracleVault,
  fixedPointDiv,
  ADDRESS_ZERO,
  getEvent,
} from "../util";
import {
  ERC20Upgradeable as ERC20,
  ERC20PriceOracleReceiptVault,
  Receipt,
} from "../../typechain";
import { BigNumber } from "ethers";
import { WithdrawEvent } from "../../typechain/IERC4626Upgradeable";

const assert = require("assert");

let vault: ERC20PriceOracleReceiptVault,
  asset: ERC20,
  shareRatio: BigNumber,
  aliceAddress: string,
  aliceAssets: BigNumber,
  receipt: Receipt;

describe("Redeem", async function () {
  let alice;
  beforeEach(async () => {
    const signers = await ethers.getSigners();
    alice = signers[0];

    const [ERC20PriceOracleVault, Erc20Asset, priceOracle, receiptVault] =
      await deployERC20PriceOracleVault();

    vault = await ERC20PriceOracleVault;
    asset = await Erc20Asset;
    shareRatio = await priceOracle.price();
    receipt = await receiptVault;
    aliceAddress = alice.address;

    aliceAssets = ethers.BigNumber.from(5000);
    await asset.transfer(aliceAddress, aliceAssets);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAssets);

    const depositTx = await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](
        aliceAssets,
        aliceAddress,
        shareRatio,
        []
      );

    await depositTx.wait();
  });
  it("Calculates correct maxRedeem", async function () {
    const expectedMaxRedeem = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](aliceAddress, shareRatio);
    await vault.connect(alice).setWithdrawId(shareRatio);
    const maxRedeem = await vault
      .connect(alice)
      ["maxRedeem(address)"](aliceAddress);
    assert(
      maxRedeem.eq(expectedMaxRedeem),
      `Wrong max withdraw amount expected ${expectedMaxRedeem} got ${maxRedeem}`
    );
  });
  it("Overloaded maxRedeem - Calculates correct maxRedeem", async function () {
    const expectedMaxRedeem = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](aliceAddress, shareRatio);

    const maxRedeem = await vault
      .connect(alice)
      ["maxRedeem(address,uint256)"](aliceAddress, shareRatio);

    assert(
      maxRedeem.eq(expectedMaxRedeem),
      `Wrong max withdraw amount expected ${expectedMaxRedeem} got ${maxRedeem}`
    );
  });
  it("previewRedeem - calculates correct assets", async function () {
    const aliceReceiptBalance = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](aliceAddress, shareRatio);

    await vault.connect(alice).setWithdrawId(shareRatio);
    const expectedPreviewRedeem = fixedPointDiv(
      aliceReceiptBalance,
      shareRatio
    );

    const assets = await vault
      .connect(alice)
      ["previewRedeem(uint256)"](aliceReceiptBalance);
    assert(
      assets.eq(expectedPreviewRedeem),
      `Wrong asset amount expected ${expectedPreviewRedeem} got ${assets}`
    );
  });
  it("Overloaded previewRedeem - calculates correct assets", async function () {
    const aliceReceiptBalance = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](aliceAddress, shareRatio);

    const expectedAssets = fixedPointDiv(aliceReceiptBalance, shareRatio);

    const assets = await vault
      .connect(alice)
      ["previewRedeem(uint256,uint256)"](aliceReceiptBalance, shareRatio);
    assert(
      assets.eq(expectedAssets),
      `Wrong asset amount expected ${expectedAssets} got ${assets}`
    );
  });
  it("Redeems", async function () {
    const receiptBalance = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](aliceAddress, shareRatio);

    await vault.connect(alice).setWithdrawId(shareRatio);
    await vault
      .connect(alice)
      ["redeem(uint256,address,address)"](
        receiptBalance,
        aliceAddress,
        aliceAddress
      );

    const receiptBalanceAfter = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](aliceAddress, shareRatio);
    assert(
      receiptBalanceAfter.eq(0),
      `alice did not redeem all 1155 receipt amounts`
    );
  });
  it("Should not redeem on zero assets", async function () {
    await vault.connect(alice).setWithdrawId(shareRatio);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["redeem(uint256,address,address)"](
            ethers.BigNumber.from(0),
            aliceAddress,
            aliceAddress
          ),
      "0_ASSETS",
      "failed to prevent a zero asset redeem"
    );
  });
  it("Should not redeem on zero address receiver", async function () {
    const receiptBalance = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](aliceAddress, shareRatio);

    await vault.connect(alice).setWithdrawId(shareRatio);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["redeem(uint256,address,address)"](
            receiptBalance,
            ADDRESS_ZERO,
            aliceAddress
          ),
      "0_RECEIVER",
      "failed to prevent a zero address receiver redeem"
    );
  });
  it("Should emit withdraw event", async function () {
    const receiptBalance = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](aliceAddress, shareRatio);
    await vault.connect(alice).setWithdrawId(shareRatio);

    const expectedAssets = fixedPointDiv(receiptBalance, shareRatio);

    const redeemTx = await vault
      .connect(alice)
      ["redeem(uint256,address,address)"](
        receiptBalance,
        aliceAddress,
        aliceAddress
      );

    const withdrawEvent = (await getEvent(
      redeemTx,
      "Withdraw",
      vault
    )) as WithdrawEvent;

    assert(
      withdrawEvent.args.assets.eq(expectedAssets),
      `wrong assets expected ${expectedAssets} got ${withdrawEvent.args.assets}`
    );
    assert(
      withdrawEvent.args.sender === aliceAddress,
      `wrong sender expected ${aliceAddress} got ${withdrawEvent.args.sender}`
    );
    assert(
      withdrawEvent.args.owner === aliceAddress,
      `wrong owner expected ${aliceAddress} got ${withdrawEvent.args.owner}`
    );
    assert(
      withdrawEvent.args.receiver === aliceAddress,
      `wrong receiver expected ${aliceAddress} got ${withdrawEvent.args.receiver}`
    );
    assert(
      withdrawEvent.args.shares.eq(receiptBalance),
      `wrong shares expected ${receiptBalance} got ${withdrawEvent.args.shares}`
    );
  });
});
