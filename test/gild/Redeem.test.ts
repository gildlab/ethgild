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
  getEvent,
} from "../util";
import {
  ERC20Upgradeable as ERC20,
  ERC20PriceOracleVault,
} from "../../typechain";
import { BigNumber } from "ethers";
import { WithdrawEvent } from "../../typechain/IERC4626";

chai.use(solidity);

const { assert } = chai;

let vault: ERC20PriceOracleVault,
  asset: ERC20,
  shareRatio: BigNumber,
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
    shareRatio = await priceOracle.price();
    aliceAddress = alice.address;

    aliceAssets = ethers.BigNumber.from(5000);
    await asset.transfer(aliceAddress, aliceAssets);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAssets);

    const depositTx = await vault["deposit(uint256,address,uint256,bytes)"](
      aliceAssets,
      aliceAddress,
      shareRatio,
      []
    );

    await depositTx.wait();
  });
  it("Calculates correct maxRedeem", async function () {
    const expectedMaxRedeem = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      shareRatio
    );
    await vault.setWithdrawId(shareRatio);
    const maxRedeem = await vault["maxRedeem(address)"](aliceAddress);
    assert(
      maxRedeem.eq(expectedMaxRedeem),
      `Wrong max withdraw amount expected ${expectedMaxRedeem} got ${maxRedeem}`
    );
  });
  it("Overloaded maxRedeem - Calculates correct maxRedeem", async function () {
    const expectedMaxRedeem = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      shareRatio
    );

    const maxRedeem = await vault["maxRedeem(address,uint256)"](
      aliceAddress,
      shareRatio
    );

    assert(
      maxRedeem.eq(expectedMaxRedeem),
      `Wrong max withdraw amount expected ${expectedMaxRedeem} got ${maxRedeem}`
    );
  });
  it("previewRedeem - calculates correct assets", async function () {
    const aliceReceiptBalance = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      shareRatio
    );

    await vault.setWithdrawId(shareRatio);
    const expectedPreviewRedeem = fixedPointDiv(
      aliceReceiptBalance,
      shareRatio
    );

    const assets = await vault["previewRedeem(uint256)"](aliceReceiptBalance);
    assert(
      assets.eq(expectedPreviewRedeem),
      `Wrong asset amount expected ${expectedPreviewRedeem} got ${assets}`
    );
  });
  it("Overloaded previewRedeem - calculates correct assets", async function () {
    const aliceReceiptBalance = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      shareRatio
    );

    const expectedAssets = fixedPointDiv(aliceReceiptBalance, shareRatio);

    const assets = await vault["previewRedeem(uint256,uint256)"](
      aliceReceiptBalance,
      shareRatio
    );
    assert(
      assets.eq(expectedAssets),
      `Wrong asset amount expected ${expectedAssets} got ${assets}`
    );
  });
  it("Redeems", async function () {
    const receiptBalance = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      shareRatio
    );

    await vault.setWithdrawId(shareRatio);
    await vault["redeem(uint256,address,address)"](
      receiptBalance,
      aliceAddress,
      aliceAddress
    );

    const receiptBalanceAfter = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      shareRatio
    );
    assert(
      receiptBalanceAfter.eq(0),
      `alice did not redeem all 1155 receipt amounts`
    );
  });
  it("Should not redeem on zero assets", async function () {
    await vault.setWithdrawId(shareRatio);

    await assertError(
      async () =>
        await vault["redeem(uint256,address,address)"](
          ethers.BigNumber.from(0),
          aliceAddress,
          aliceAddress
        ),
      "0_ASSETS",
      "failed to prevent a zero asset redeem"
    );
  });
  it("Should not redeem on zero address receiver", async function () {
    const receiptBalance = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      shareRatio
    );

    await vault.setWithdrawId(shareRatio);

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
      shareRatio
    );
    await vault.setWithdrawId(shareRatio);

    const expectedAssets = fixedPointDiv(receiptBalance, shareRatio);

    const redeemTx = await vault["redeem(uint256,address,address)"](
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
      withdrawEvent.args.shares.eq(receiptBalance),
      `wrong shares expected ${receiptBalance} got ${withdrawEvent.args.shares}`
    );
  });
});
