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
  it("Checks ReceiptVaultInformation event is emitted", async function () {
    const [vault] = await deployERC20PriceOracleVault();
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const { sender, vaultInformation } = (await getEventArgs(
      await vault.connect(alice).receiptVaultInformation([1]),
      "ReceiptVaultInformation",
      vault
    )) as ReceiptVaultInformationEvent["args"];

    assert(
      sender === alice.address,
      `Incorrect sender. Expected ${alice.address} got ${sender}`
    );

    assert(
      vaultInformation === "0x01",
      `Incorrect sender. Expected 0x01 got ${vaultInformation}`
    );
  });
});
describe("Deposit", async () => {
  it("Receiver receives BOTH erc20 and erc1155, depositor gets nothing but MUST transfer assets", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const [vault, asset, priceOracle, receipt] =
      await deployERC20PriceOracleVault();
    const shareRatio = await priceOracle.price();

    const totalTokenSupply = await asset.totalSupply();
    const assets = totalTokenSupply.div(2);
    // give alice reserve to cover cost
    await asset.transfer(alice.address, assets);

    await asset.connect(alice).increaseAllowance(vault.address, assets);

    //Alice assets before deposit
    const aliceAssetBefore = await asset
      .connect(alice)
      .balanceOf(alice.address);

    await vault.connect(alice)["deposit(uint256,address)"](assets, bob.address);

    const expectedBobBalance = fixedPointMul(assets, shareRatio);

    //Receiver gets both Erc20 and Erc1155
    const erc1155Balance = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](bob.address, shareRatio);

    const bobErc20Balance = await vault
      .connect(alice)
      ["balanceOf(address)"](bob.address);

    assert(
      erc1155Balance.eq(expectedBobBalance),
      `wrong bob erc1155 balance ${expectedBobBalance} ${erc1155Balance}`
    );

    assert(
      bobErc20Balance.eq(expectedBobBalance),
      `wrong bob erc1155 balance ${expectedBobBalance} ${bobErc20Balance}`
    );

    //Depositor Gets nothing
    const aliceErc20Balance = await vault
      .connect(alice)
      ["balanceOf(address)"](alice.address);

    const aliceErc1155Balance = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](alice.address, shareRatio);

    assert(
      aliceErc1155Balance.eq(0),
      `wrong alice erc20 balance ${aliceErc1155Balance} 0`
    );

    assert(
      aliceErc20Balance.eq(0),
      `wrong alice erc20 balance ${aliceErc20Balance} 0`
    );

    //Depositor MUST transfer assets
    const aliceAssetAft = await asset.connect(alice).balanceOf(alice.address);

    assert(
      aliceAssetAft.eq(aliceAssetBefore.sub(assets)),
      `wrong alice assets ${aliceAssetAft} ${aliceAssetBefore.sub(assets)}`
    );
  });
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
describe("Overloaded `deposit`", async () => {
  it("Check ReceiptInformation event is emitted", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const [vault, asset, priceOracle, receipt] =
      await deployERC20PriceOracleVault();

    const shareRatio = await priceOracle.price();

    const aliceAmount = ethers.BigNumber.from(5000);
    await asset.transfer(alice.address, aliceAmount);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAmount);

    const expectedId = shareRatio;

    const informationBytes = [125, 126];
    //generate hex string
    const expectedInformation =
      "0x" + informationBytes.map((num) => num.toString(16)).join("");

    const { sender, id, information } = (await getEventArgs(
      await vault
        .connect(alice)
        ["deposit(uint256,address,uint256,bytes)"](
          aliceAmount,
          alice.address,
          shareRatio,
          informationBytes
        ),
      "ReceiptInformation",
      receipt
    )) as ReceiptInformationEvent["args"];

    assert(
      sender === alice.address,
      `wrong assets expected ${alice.address} got ${sender}`
    );
    assert(id.eq(expectedId), `wrong shares expected ${id} got ${expectedId}`);

    assert(
      information === expectedInformation,
      `wrong information expected ${information} got ${expectedInformation}`
    );
  })
})