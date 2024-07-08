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

describe("Overloaded Withdraw", async function () {
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
  it("Should not withdraw on zero address receiver", async function () {
    const receiptBalance = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](aliceAddress, shareRatio);

    //calculate max assets available for withdraw
    const withdrawBalance = fixedPointDiv(receiptBalance, shareRatio);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["withdraw(uint256,address,address,uint256,bytes)"](
            withdrawBalance,
            ADDRESS_ZERO,
            aliceAddress,
            shareRatio,
            []
          ),
      "ZeroReceiver",
      "failed to prevent a zero address receiver withdraw"
    );
  });
  it("Should not withdraw with zero address owner", async function () {
    const receiptBalance = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](aliceAddress, shareRatio);

    //calculate max assets available for withdraw
    const withdrawBalance = fixedPointDiv(receiptBalance, shareRatio);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["withdraw(uint256,address,address,uint256,bytes)"](
            withdrawBalance,
            aliceAddress,
            ADDRESS_ZERO,
            shareRatio,
            []
          ),
      "ZeroOwner",
      "failed to prevent a zero address owner withdraw"
    );
  });

  it("Should emit withdraw event", async function () {
    const receiptBalance = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](aliceAddress, shareRatio);

    //calculate max assets available for withdraw
    const withdrawBalance = fixedPointDiv(receiptBalance, shareRatio);
    await vault.connect(alice).setWithdrawId(shareRatio);
    const withdrawTx = await vault
      .connect(alice)
      ["withdraw(uint256,address,address,uint256,bytes)"](
        withdrawBalance,
        aliceAddress,
        aliceAddress,
        shareRatio,
        []
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
      withdrawEvent.args.shares.eq(expectedShares),
      `wrong shares expected ${expectedShares} got ${withdrawEvent.args.shares}`
    );
  });
});
