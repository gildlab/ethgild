import { artifacts, ethers } from "hardhat";
import { ADDRESS_ZERO, assertError, expectedUri, getEventArgs } from "../util";
import {
  Receipt,
  ReceiptFactory,
  TestErc20,
  TestReceipt,
  TestReceiptOwner,
} from "../../typechain-types";
import { Contract } from "ethers";
import { ReceiptInformationEvent } from "../../typechain-types/contracts/vault/receipt/Receipt";

const assert = require("assert");

describe("Receipt vault", async function () {
  it("OwnerTransferFrom more than balance", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const testReceipt = await ethers.getContractFactory("TestReceipt");
    const receipt = (await testReceipt.deploy()) as TestReceipt;
    await receipt.deployed();

    const testReceiptOwner = await ethers.getContractFactory(
      "TestReceiptOwner"
    );
    const receiptOwner = (await testReceiptOwner.deploy()) as TestReceiptOwner;
    await receiptOwner.deployed();

    await receipt.setOwner(receiptOwner.address);

    await receiptOwner.setFrom(ADDRESS_ZERO);
    await receiptOwner.setTo(alice.address);

    const assets = ethers.BigNumber.from(30);
    await asset.transfer(alice.address, assets);
    await asset.connect(alice).increaseAllowance(receiptOwner.address, assets);

    const receiptId = ethers.BigNumber.from(1);

    const transferAmount = ethers.BigNumber.from(10);

    await receiptOwner.setFrom(alice.address);
    await receiptOwner.setTo(bob.address);

    await assertError(
      async () =>
        await receiptOwner
          .connect(alice)
          .ownerTransferFrom(
            receipt.address,
            alice.address,
            bob.address,
            receiptId,
            transferAmount,
            []
          ),
      "ERC1155: insufficient balance for transfer",
      "failed to transfer"
    );
  });
  it("OwnerTransferFrom - transforms balances", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const testReceipt = await ethers.getContractFactory("TestReceipt");
    const receipt = (await testReceipt.deploy()) as TestReceipt;
    await receipt.deployed();

    const testReceiptOwner = await ethers.getContractFactory(
      "TestReceiptOwner"
    );
    const receiptOwner = (await testReceiptOwner.deploy()) as TestReceiptOwner;
    await receiptOwner.deployed();

    await receipt.setOwner(receiptOwner.address);

    await receiptOwner.setFrom(ADDRESS_ZERO);
    await receiptOwner.setTo(alice.address);

    const assets = ethers.BigNumber.from(30);
    await asset.transfer(alice.address, assets);
    await asset.connect(alice).increaseAllowance(receiptOwner.address, assets);

    const receiptId = ethers.BigNumber.from(1);
    const transferAmount = ethers.BigNumber.from(10);

    await receiptOwner
      .connect(alice)
      .ownerMint(receipt.address, alice.address, receiptId, transferAmount, []);

    const balanceBefore = await receipt.balanceOf(alice.address, receiptId);
    const balanceBeforeBob = await receipt.balanceOf(bob.address, receiptId);

    await receiptOwner.setFrom(alice.address);
    await receiptOwner.setTo(bob.address);

    await receiptOwner
      .connect(alice)
      .ownerTransferFrom(
        receipt.address,
        alice.address,
        bob.address,
        receiptId,
        transferAmount,
        []
      );

    const balanceAfter = await receipt.balanceOf(alice.address, receiptId);
    const balanceAfterBob = await receipt.balanceOf(bob.address, receiptId);

    assert(
      balanceAfterBob.eq(balanceBeforeBob.add(transferAmount)),
      `Wrong balance for bob. Expected ${balanceBeforeBob.add(
        transferAmount
      )}, got ${balanceAfterBob}`
    );

    assert(
      balanceAfter.eq(balanceBefore.sub(transferAmount)),
      `Wrong balance for alice. Expected ${balanceBefore.sub(
        transferAmount
      )}, got ${balanceAfter}`
    );
  });
  it("OwnerTransferFrom - checks if transfer is authorized", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    const testReceipt = await ethers.getContractFactory("TestReceipt");
    const receipt = (await testReceipt.deploy()) as TestReceipt;
    await receipt.deployed();

    const testReceiptOwner = await ethers.getContractFactory(
      "TestReceiptOwner"
    );
    const receiptOwner = (await testReceiptOwner.deploy()) as TestReceiptOwner;
    await receiptOwner.deployed();

    await receipt.setOwner(receiptOwner.address);

    await receiptOwner.setFrom(ADDRESS_ZERO);
    await receiptOwner.setTo(alice.address);

    const assets = ethers.BigNumber.from(30);
    await asset.transfer(alice.address, assets);
    await asset.connect(alice).increaseAllowance(receiptOwner.address, assets);

    const receiptId = ethers.BigNumber.from(1);
    const transferAmount = ethers.BigNumber.from(10);

    await receiptOwner
      .connect(alice)
      .ownerMint(receipt.address, alice.address, receiptId, transferAmount, []);

    await assertError(
      async () =>
        await receiptOwner
          .connect(alice)
          .ownerTransferFrom(
            receipt.address,
            alice.address,
            bob.address,
            receiptId,
            transferAmount,
            []
          ),
      `UnauthorizedTransfer("${alice.address}", "${bob.address}")`,
      "failed to prevent ownerBurn"
    );
  });
});
