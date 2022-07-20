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

describe("Overloaded Withdraw", async function () {
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
  it("Withdraws", async function () {
    const receiptBalance = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      price
    );

    //calculate max assets available for withdraw
    const withdrawBalance = fixedPointDiv(receiptBalance, price);

    await vault["withdraw(uint256,address,address,uint256)"](
      withdrawBalance,
      aliceAddress,
      aliceAddress,
      price
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
    await assertError(
      async () =>
        await vault["withdraw(uint256,address,address,uint256)"](
          ethers.BigNumber.from(0),
          aliceAddress,
          aliceAddress,
          price
        ),
      "0_ASSETS",
      "failed to prevent a zero asset withdraw"
    );
  });
  it("Should not withdraw on zero address receiver", async function () {
    const receiptBalance = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      price
    );

    //calculate max assets available for withdraw
    const withdrawBalance = fixedPointDiv(receiptBalance, price);

    await assertError(
      async () =>
        await vault["withdraw(uint256,address,address,uint256)"](
          withdrawBalance,
          ADDRESS_ZERO,
          aliceAddress,
          price
        ),
      "0_RECEIVER",
      "failed to prevent a zero address receiver withdraw"
    );
  });
  it("Should not withdraw with zero address owner", async function () {
    const receiptBalance = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      price
    );

    //calculate max assets available for withdraw
    const withdrawBalance = fixedPointDiv(receiptBalance, price);

    await assertError(
      async () =>
        await vault["withdraw(uint256,address,address,uint256)"](
          withdrawBalance,
          aliceAddress,
          ADDRESS_ZERO,
          price
        ),
      "0_OWNER",
      "failed to prevent a zero address owner withdraw"
    );
  });
  it("Should emit withdraw event", async function () {
    const receiptBalance = await vault["balanceOf(address,uint256)"](
      aliceAddress,
      price
    );

    //calculate max assets available for withdraw
    const withdrawBalance = fixedPointDiv(receiptBalance, price);

    const { caller, receiver, owner, assets, shares } = (await getEventArgs(
      await vault["withdraw(uint256,address,address,uint256)"](
        withdrawBalance,
        aliceAddress,
        aliceAddress,
        price
      ),
      "Withdraw",
      vault
    )) as WithdrawEvent["args"];

    const expectedShares = fixedPointMul(withdrawBalance, price).add(1);

    assert(
      assets.eq(withdrawBalance),
      `wrong assets expected ${withdrawBalance} got ${assets}`
    );
    assert(
      caller === aliceAddress,
      `wrong caller expected ${aliceAddress} got ${caller}`
    );
    assert(
      owner === aliceAddress,
      `wrong owner expected ${aliceAddress} got ${owner}`
    );
    console.log(caller, owner, receiver);
    assert(
      receiver === aliceAddress,
      `wrong receiver expected ${aliceAddress} got ${receiver}`
    );
    assert(
      shares.eq(expectedShares),
      `wrong shares expected ${expectedShares} got ${shares}`
    );
  });
});
