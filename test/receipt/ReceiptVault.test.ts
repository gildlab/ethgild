import { ethers } from "hardhat";
import {
  deployERC20PriceOracleVault,
  fixedPointMul,
  getEvent,
} from "../util";
import { DepositEvent } from "../../typechain-types/@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable";
import {
  ReceiptVaultInformationEvent,
} from "../../typechain-types/contracts/vault/receipt/ReceiptVault";

import { getEventArgs } from "../util";
import { ReceiptInformationEvent } from "../../typechain-types/contracts/vault/receipt/Receipt";
const assert = require("assert");

describe("Receipt vault", async function () {
describe("Deposit", async () => {
  it("Check deposit event is emitted", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

    const shareRatio = await priceOracle.price();

    const aliceAmount = ethers.BigNumber.from(5000);
    await asset.transfer(alice.address, aliceAmount);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAmount);

    const expectedShares = fixedPointMul(aliceAmount, shareRatio);

    const depositTX = await vault
      .connect(alice)
      ["deposit(uint256,address)"](aliceAmount, alice.address);
    const depositEvent = (await getEvent(
      depositTX,
      "Deposit",
      vault
    )) as DepositEvent;

    assert(
      depositEvent.args.assets.eq(aliceAmount),
      `wrong assets expected ${aliceAmount} got ${depositEvent.args.assets}`
    );
    assert(
      depositEvent.args.shares.eq(expectedShares),
      `wrong shares expected ${depositEvent.args.shares} got ${expectedShares}`
    );
    assert(
      depositEvent.args.sender === alice.address,
      `wrong sender expected ${alice.address} got ${depositEvent.args.sender}`
    );
    assert(
      depositEvent.args.owner === alice.address,
      `wrong owner expected ${alice.address} got ${depositEvent.args.owner}`
    );
  });
});