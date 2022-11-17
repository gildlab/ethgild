import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import {
  assertError,
  deployERC20PriceOracleVault,
  fixedPointDiv,
  fixedPointMul,
  ADDRESS_ZERO,
  getEvent,
} from "../util";
import {
  ERC20Upgradeable as ERC20,
  ERC20PriceOracleReceiptVault, Receipt,
} from "../../typechain";
import { BigNumber } from "ethers";
import { WithdrawEvent } from "../../typechain/IERC4626";

chai.use(solidity);

const { assert } = chai;

let vault: ERC20PriceOracleReceiptVault,
  asset: ERC20,
  shareRatio: BigNumber,
  aliceAddress: string,
  aliceAssets: BigNumber,
receipt: Receipt;

describe("Withdraw", async function () {
  let alice;
  beforeEach(async () => {
    const signers = await ethers.getSigners();
    alice = signers[0];

    const [ERC20PriceOracleVault, Erc20Asset, priceOracle, receiptContract] =
      await deployERC20PriceOracleVault();

    vault = await ERC20PriceOracleVault;
    asset = await Erc20Asset;
    shareRatio = await priceOracle.price();
    receipt = await receiptContract;
    aliceAddress = alice.address;

    aliceAssets = ethers.BigNumber.from(5000);
    await asset.transfer(aliceAddress, aliceAssets);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAssets);

    const depositTx = await vault.connect(alice)["deposit(uint256,address,uint256,bytes)"](
      aliceAssets,
      aliceAddress,
      shareRatio,
      []
    );

    await depositTx.wait();
  });
  it("Calculates correct maxWithdraw", async function () {
    const receiptBalance = await receipt.connect(alice)["balanceOf(address,uint256)"](
      aliceAddress,
      shareRatio
    );

    const expectedMaxWithdraw = fixedPointDiv(receiptBalance, shareRatio);
    await vault.connect(alice).setWithdrawId(shareRatio);

    const maxWithdraw = await vault.connect(alice)["maxWithdraw(address)"](aliceAddress);

    assert(maxWithdraw.eq(expectedMaxWithdraw), `Wrong max withdraw amount`);
  });
  it("Overloaded MaxWithdraw - Calculates correct maxWithdraw", async function () {
    const receiptBalance = await receipt.connect(alice)["balanceOf(address,uint256)"](
      aliceAddress,
      shareRatio
    );

    const expectedMaxWithdraw = fixedPointDiv(receiptBalance, shareRatio);
    const maxWithdraw = await vault.connect(alice)["maxWithdraw(address,uint256)"](
      aliceAddress,
      shareRatio
    );

    assert(maxWithdraw.eq(expectedMaxWithdraw), `Wrong max withdraw amount`);
  });
  it("PreviewWithdraw - calculates correct shares", async function () {
    //calculate max assets available for withdraw
    const withdrawBalance = fixedPointDiv(aliceAssets, shareRatio);

    await vault.connect(alice).setWithdrawId(shareRatio);

    const expectedPreviewWithdraw = fixedPointMul(
      withdrawBalance,
      shareRatio
    ).add(1);
    const previewWithdraw = await vault.connect(alice)["previewWithdraw(uint256)"](
      withdrawBalance
    );

    assert(
      previewWithdraw.eq(expectedPreviewWithdraw),
      `Wrong preview withdraw amount`
    );
  });
  it("Overloaded PreviewWithdraw - calculates correct shares", async function () {
    //calculate max assets available for withdraw
    const withdrawBalance = fixedPointDiv(aliceAssets, shareRatio);

    const expectedPreviewWithdraw = fixedPointMul(
      withdrawBalance,
      shareRatio
    ).add(1);
    const previewWithdraw = await vault.connect(alice)["previewWithdraw(uint256,uint256)"](
      withdrawBalance,
      shareRatio
    );

    assert(
      previewWithdraw.eq(expectedPreviewWithdraw),
      `Wrong preview withdraw amount`
    );
  });
  it("Withdraws", async function () {
    const receiptBalance = await receipt.connect(alice)["balanceOf(address,uint256)"](
      aliceAddress,
      shareRatio
    );

    //calculate max assets available for withdraw
    const withdrawBalance = fixedPointDiv(receiptBalance, shareRatio);

    await vault.connect(alice).setWithdrawId(shareRatio);
    await vault.connect(alice)["withdraw(uint256,address,address)"](
      withdrawBalance,
      aliceAddress,
      aliceAddress
    );

    const receiptBalanceAfter = await receipt.connect(alice)["balanceOf(address,uint256)"](
      aliceAddress,
      shareRatio
    );

    assert(
      receiptBalanceAfter.eq(0),
      `alice did not withdraw all 1155 receipt amounts`
    );
  });
  it("Should not withdraw on zero assets", async function () {
    await vault.connect(alice).setWithdrawId(shareRatio);

    await assertError(
      async () =>
        await vault.connect(alice)["withdraw(uint256,address,address)"](
          ethers.BigNumber.from(0),
          aliceAddress,
          aliceAddress
        ),
      "0_ASSETS",
      "failed to prevent a zero asset withdraw"
    );
  });
  it("Should not withdraw on zero address receiver", async function () {
    const receiptBalance = await receipt.connect(alice)["balanceOf(address,uint256)"](
      aliceAddress,
      shareRatio
    );

    //calculate max assets available for withdraw
    const withdrawBalance = fixedPointDiv(receiptBalance, shareRatio);
    await vault.connect(alice).setWithdrawId(shareRatio);

    await assertError(
      async () =>
        await vault.connect(alice)["withdraw(uint256,address,address)"](
          withdrawBalance,
          ADDRESS_ZERO,
          aliceAddress
        ),
      "0_RECEIVER",
      "failed to prevent a zero address receiver withdraw"
    );
  });
  it("Should not withdraw with zero address owner", async function () {
    const receiptBalance = await receipt.connect(alice)["balanceOf(address,uint256)"](
      aliceAddress,
      shareRatio
    );

    //calculate max assets available for withdraw
    const withdrawBalance = fixedPointDiv(receiptBalance, shareRatio);
    await vault.connect(alice).setWithdrawId(shareRatio);

    await assertError(
      async () =>
        await vault.connect(alice)["withdraw(uint256,address,address)"](
          withdrawBalance,
          aliceAddress,
          ADDRESS_ZERO
        ),
      "0_OWNER",
      "failed to prevent a zero address owner withdraw"
    );
  });
  it("Should emit withdraw event", async function () {
    const receiptBalance = await receipt.connect(alice)["balanceOf(address,uint256)"](
      aliceAddress,
      shareRatio
    );

    //calculate max assets available for withdraw
    const withdrawBalance = fixedPointDiv(receiptBalance, shareRatio);
    await vault.connect(alice).setWithdrawId(shareRatio);
    const withdrawTx = await vault.connect(alice)["withdraw(uint256,address,address)"](
      withdrawBalance,
      aliceAddress,
      aliceAddress
    );

    const withdrawEvent = (await getEvent(
      withdrawTx,
      "Withdraw",
      vault
    )) as WithdrawEvent;

    const expectedShares = fixedPointMul(withdrawBalance, shareRatio).add(1);

    assert(
      withdrawEvent.args.assets.eq(withdrawBalance),
      `wrong assets expected ${withdrawBalance} got ${withdrawEvent.args.assets}`
    );
    assert(
      withdrawEvent.args.caller === aliceAddress,
      `wrong caller expected ${aliceAddress} got ${withdrawEvent.args.caller}`
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
      withdrawEvent.args.shares.eq(expectedShares),
      `wrong shares expected ${expectedShares} got ${withdrawEvent.args.shares}`
    );
  });
});
