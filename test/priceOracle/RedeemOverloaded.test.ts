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
} from "../../typechain-types";
import { BigNumber } from "ethers";
import { WithdrawEvent } from "../../typechain-types/@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable";

const assert = require("assert");

let vault: ERC20PriceOracleReceiptVault,
  asset: ERC20,
  shareRatio: BigNumber,
  aliceAddress: string,
  aliceAssets: BigNumber,
  receipt: Receipt;

describe("Overloaded Redeem", async function () {
  let alice;
  const [ERC20PriceOracleVault, Erc20Asset, priceOracle, receiptContract] =
    await deployERC20PriceOracleVault();
  beforeEach(async () => {
    const signers = await ethers.getSigners();
    alice = signers[0];

    vault = await ERC20PriceOracleVault;
    asset = await Erc20Asset;
    shareRatio = await priceOracle.price();
    receipt = await receiptContract;
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
  it("Redeems", async function () {
    const receiptBalance = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](aliceAddress, shareRatio);

    await vault
      .connect(alice)
      ["redeem(uint256,address,address,uint256,bytes)"](
        receiptBalance,
        aliceAddress,
        aliceAddress,
        shareRatio,
        []
      );

    const receiptBalanceAfter = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](aliceAddress, shareRatio);
    assert(
      receiptBalanceAfter.eq(0),
      `alice did not redeem all 1155 receipt amounts`
    );
  });
  it("Redeems half of tokens", async function () {
    const receiptBalance = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](aliceAddress, shareRatio);

    await vault
      .connect(alice)
      ["redeem(uint256,address,address,uint256,bytes)"](
        receiptBalance.div(2),
        aliceAddress,
        aliceAddress,
        shareRatio,
        []
      );

    const receiptBalanceAfter = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](aliceAddress, shareRatio);

    assert(
      receiptBalanceAfter.eq(receiptBalance.div(2)),
      `alice did not redeem all 1155 receipt amounts`
    );
  });
  it("Should not redeem on zero assets", async function () {
    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["redeem(uint256,address,address,uint256,bytes)"](
            ethers.BigNumber.from(0),
            aliceAddress,
            aliceAddress,
            shareRatio,
            []
          ),
      "ZeroAssetsAmount",
      "failed to prevent a zero assets redeem"
    );
  });
  it("Should not redeem on zero address receiver", async function () {
    const receiptBalance = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](aliceAddress, shareRatio);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["redeem(uint256,address,address,uint256,bytes)"](
            receiptBalance,
            ADDRESS_ZERO,
            aliceAddress,
            shareRatio,
            []
          ),
      "ZeroReceiver",
      "failed to prevent a zero address receiver redeem"
    );
  });
  it("Should not redeem on zero address owner", async function () {
    const receiptBalance = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](aliceAddress, shareRatio);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["redeem(uint256,address,address,uint256,bytes)"](
            receiptBalance,
            aliceAddress,
            ADDRESS_ZERO,
            shareRatio,
            []
          ),
      "ZeroOwner",
      "failed to prevent a zero address owner redeem"
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
      ["redeem(uint256,address,address,uint256,bytes)"](
        receiptBalance,
        aliceAddress,
        aliceAddress,
        shareRatio,
        []
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
