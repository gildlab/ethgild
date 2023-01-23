import { ethers } from "hardhat";
import {
  assertError,
  deployERC20PriceOracleVault,
  fixedPointDiv,
  fixedPointMul,
  ADDRESS_ZERO,
  expectedReferencePrice,
  getEvent,
} from "../util";
import { DepositEvent } from "../../typechain-types/@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  DepositWithReceiptEvent,
  WithdrawWithReceiptEvent,
} from "../../typechain-types/contracts/vault/receipt/ReceiptVault";

import { getEventArgs } from "../util";
import { ReceiptInformationEvent } from "../../typechain-types/contracts/vault/receipt/Receipt";
const assert = require("assert");

let owner: SignerWithAddress;

describe("Receipt vault", async function () {
  it("Returns the address of the underlying asset that is deposited", async function () {
    const [vault, asset] = await deployERC20PriceOracleVault();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    const vaultAsset = await vault.connect(alice).asset();

    assert(
      vaultAsset === asset.address,
      `Wrong asset address ${asset.address} ${vaultAsset}`
    );
  });
  it("Sets the correct min Share Ratio", async function () {
    [owner] = await ethers.getSigners();
    const expectedMinShareRatio = ethers.BigNumber.from("100");
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const [vault] = await deployERC20PriceOracleVault();
    await vault.connect(alice).setMinShareRatio(100);
    let minShareRatio = await vault
      .connect(alice)
      .minShareRatios(owner.address);

    assert(
      minShareRatio.eq(expectedMinShareRatio),
      `Wrong min Share Ratio ${expectedMinShareRatio} ${minShareRatio}`
    );
  });
  it("Sets the correct withdraw Id", async function () {
    [owner] = await ethers.getSigners();
    const expectedWithdrawId = ethers.BigNumber.from("100");
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const [vault] = await deployERC20PriceOracleVault();
    await vault.connect(alice).setWithdrawId(100);
    let withdrawId = await vault.connect(alice).withdrawIds(owner.address);

    assert(
      withdrawId.eq(expectedWithdrawId),
      `Wrong withdraw Id ${expectedWithdrawId} ${withdrawId}`
    );
  });
  it("Checks total asset is same as balance", async function () {
    const [vault, asset] = await deployERC20PriceOracleVault();
    const signers = await ethers.getSigners();
    const alice = signers[0];

    await asset.transfer(vault.address, ethers.BigNumber.from(1000));

    const assets = await asset.balanceOf(vault.address);

    const totalAssets = await vault.connect(alice).totalAssets();

    assert(
      totalAssets.eq(assets),
      `Wrong total assets ${assets} ${totalAssets}`
    );
  });
  it("Calculates correct assets", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

    const shareRatio = await priceOracle.price();

    assert(
      shareRatio.eq(expectedReferencePrice),
      `Incorrect referencePrice ${shareRatio} ${expectedReferencePrice}`
    );

    const share = ethers.BigNumber.from("10").pow(20);
    const expectedAsset = fixedPointDiv(share, shareRatio);

    const assets = await vault.connect(alice).convertToAssets(share);

    assert(assets.eq(expectedAsset), `Wrong asset ${expectedAsset} ${assets}`);
  });
  it("Shows no variations based on caller", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const [vault] = await deployERC20PriceOracleVault();

    const aliceVault = vault.connect(alice);
    const bobVault = vault.connect(bob);

    const share = ethers.BigNumber.from("10").pow(20);

    const assetsAlice = await aliceVault.convertToAssets(share);
    const assetsBob = await bobVault.convertToAssets(share);

    assert(
      assetsAlice.eq(assetsBob),
      `Wrong asset ${assetsAlice} ${assetsBob}`
    );
  });
  it("Calculates correct shares", async function () {
    [owner] = await ethers.getSigners();

    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

    const shareRatio = await priceOracle.price();

    const minPrice = ethers.BigNumber.from(0);

    assert(
      shareRatio >= minPrice,
      `ShareRatio is less then minShareRatio ${shareRatio} ${minPrice}`
    );

    assert(
      shareRatio.eq(expectedReferencePrice),
      `Incorrect shareRatio ${shareRatio} ${expectedReferencePrice}`
    );

    const assets = ethers.BigNumber.from("10").pow(20);
    const expectedShares = fixedPointMul(assets, shareRatio);

    const shares = await vault.connect(owner).convertToShares(assets);

    assert(
      shares.eq(expectedShares),
      `Wrong share ${expectedShares} ${shares}`
    );
  });
  it("Shows no variations based on caller for convertToShares", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const [vault] = await deployERC20PriceOracleVault();

    const aliceVault = vault.connect(alice);
    const bobVault = vault.connect(bob);

    const assets = ethers.BigNumber.from("10").pow(20);

    const sharesAlice = await aliceVault.convertToShares(assets);
    const sharesBob = await bobVault.convertToShares(assets);

    assert(
      sharesAlice.eq(sharesBob),
      `Wrong shares ${sharesAlice} ${sharesBob}`
    );
  });
  it("Sets correct max deposit value", async function () {
    const [vault] = await deployERC20PriceOracleVault();
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const expectedMaxDeposit = ethers.BigNumber.from(2)
      .pow(256)
      //up to 2**256 so should substruct 1
      .sub(1);
    const maxDeposit = await vault.connect(alice).maxDeposit(owner.address);

    assert(
      maxDeposit.eq(expectedMaxDeposit),
      `Wrong max deposit ${expectedMaxDeposit} ${maxDeposit}`
    );
  });
  it("Respects min shareRatio in case of previewDeposit", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

    const assets = ethers.BigNumber.from("10").pow(20);
    const shareRatio = await priceOracle.price();

    await vault.connect(alice).setMinShareRatio(shareRatio.add(1));

    await assertError(
      async () => await vault.connect(alice).previewDeposit(assets),
      "MinShareRatio",
      "failed to respect min share ratio"
    );
  });
  it("Sets correct shares by previewDeposit", async function () {
    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const assets = ethers.BigNumber.from("10").pow(20);

    const shareRatio = await priceOracle.price();

    assert(
      shareRatio.eq(expectedReferencePrice),
      `Incorrect referencePrice ${shareRatio} ${expectedReferencePrice}`
    );

    const expectedshares = fixedPointMul(assets, shareRatio);
    const share = await vault.connect(alice).previewDeposit(assets);

    assert(share.eq(expectedshares), `Wrong shares ${expectedshares} ${share}`);
  });
});
describe("Deposit", async () => {
  it("Must respect min Price", async function () {
    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
    const shareRatio = await priceOracle.price();

    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const assets = ethers.BigNumber.from("10").pow(20);

    await vault.connect(alice).setMinShareRatio(shareRatio.add(1));

    await asset.connect(alice).increaseAllowance(vault.address, assets);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["deposit(uint256,address)"](assets, bob.address),
      "MinShareRatio",
      "failed to respect min price"
    );
  }),
    it("Calculates shares correctly with min shareRatio set", async function () {
      const signers = await ethers.getSigners();

      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

      const alice = signers[1];

      const totalTokenSupply = await asset.totalSupply();

      const assets = totalTokenSupply.div(2);

      // give alice reserve to cover cost
      await asset.transfer(alice.address, assets);

      // Min shareRatio MUST be respected
      const shareRatio = await priceOracle.price();

      await asset.connect(alice).increaseAllowance(vault.address, assets);

      const expectedShares = fixedPointMul(assets, shareRatio);

      await vault.connect(alice).setMinShareRatio(shareRatio.sub(1));

      await vault
        .connect(alice)
        ["deposit(uint256,address)"](assets, alice.address);
      const shares = await vault
        .connect(alice)
        ["balanceOf(address)"](alice.address);

      assert(
        shares.eq(expectedShares),
        `Wrong alice shares ${expectedShares} ${shares}`
      );
    }),
    it("Calculates shares correctly with NO min shareRatio set", async function () {
      const signers = await ethers.getSigners();

      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

      const alice = signers[1];

      const totalTokenSupply = await asset.totalSupply();

      const assets = totalTokenSupply.div(2);

      // give alice reserve to cover cost
      await asset.transfer(alice.address, assets);

      // Min shareRatio MUST be respected
      const shareRatio = await priceOracle.price();

      await asset.connect(alice).increaseAllowance(vault.address, assets);

      const expectedShares = fixedPointMul(assets, shareRatio);

      await vault
        .connect(alice)
        ["deposit(uint256,address)"](assets, alice.address);
      const shares = await vault
        .connect(alice)
        ["balanceOf(address)"](alice.address);

      assert(
        shares.eq(expectedShares),
        `Wrong alice ETHg ${expectedShares} ${shares}`
      );
    });
  it("Reverts if not enough assets to be transferred", async function () {
    const signers = await ethers.getSigners();

    const [vault, asset] = await deployERC20PriceOracleVault();

    const alice = signers[1];

    const totalTokenSupply = await asset.totalSupply();

    const assets = totalTokenSupply.div(2);

    await asset.connect(alice).increaseAllowance(vault.address, assets);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["deposit(uint256,address)"](assets, alice.address),
      "ERC20: transfer amount exceeds balance",
      "failed to respect min price"
    );
  });
  it("Receiver MAY be different user to depositor", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
    const shareRatio = await priceOracle.price();

    const totalTokenSupply = await asset.totalSupply();
    const assets = totalTokenSupply.div(2);
    // give alice reserve to cover cost
    await asset.transfer(alice.address, assets);

    await asset.connect(alice).increaseAllowance(vault.address, assets);

    await vault.connect(alice)["deposit(uint256,address)"](assets, bob.address);
    const shares = await vault
      .connect(alice)
      ["balanceOf(address)"](bob.address);
    const expectedShares = fixedPointMul(assets, shareRatio);

    assert(
      shares.eq(expectedShares),
      `wrong alice ETHg ${expectedShares} ${shares}`
    );
  });
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
  it("MUST revert if the vault can't take enough assets from the depositor", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[1];

    const [vault, asset] = await deployERC20PriceOracleVault();

    const totalTokenSupply = await asset.totalSupply();
    const assets = totalTokenSupply.div(2);
    // give alice reserve to cover cost
    await asset.transfer(alice.address, assets);

    //alice has assets of totalsuply/2
    await asset.connect(alice).increaseAllowance(vault.address, assets.add(1));

    //try to deposit more assets then alice owns
    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["deposit(uint256,address)"](assets.add(1), alice.address),
      "ERC20: transfer amount exceeds balance",
      "failed to revert"
    );
  });
  it("MUST NOT successfully deposit if the vault is not approved for the depositor's assets", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const [vault, asset] = await deployERC20PriceOracleVault();

    const totalTokenSupply = await asset.totalSupply();
    const assets = totalTokenSupply.div(2);
    // give alice reserve to cover cost
    await asset.transfer(alice.address, assets);

    //try to deposit without approve
    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["deposit(uint256,address)"](assets, alice.address),
      "ERC20: insufficient allowance'",
      "failed to revert"
    );
  });
  it("should not deposit to zero address", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[1];

    const [vault, asset] = await deployERC20PriceOracleVault();

    const totalTokenSupply = await asset.totalSupply();
    const aliceDepositAmount = totalTokenSupply.div(2);

    // give alice reserve to cover cost
    await asset.transfer(alice.address, aliceDepositAmount);

    const aliceReserveBalance = await asset.balanceOf(alice.address);

    await asset.connect(alice).approve(vault.address, aliceReserveBalance);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["deposit(uint256,address)"](aliceReserveBalance, ADDRESS_ZERO),
      "ZeroReceiver",
      "failed to prevent deposit to zero address"
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
  it("Must respect min shareRatio", async function () {
    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
    const shareRatio = await priceOracle.price();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    const totalTokenSupply = await asset.totalSupply();

    const assets = totalTokenSupply.div(2);

    await vault.connect(alice).setMinShareRatio(shareRatio.add(1));

    await asset.connect(alice).increaseAllowance(vault.address, assets);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["deposit(uint256,address,uint256,bytes)"](
            assets,
            alice.address,
            shareRatio.add(1),
            []
          ),
      "MinShareRatio",
      "failed to respect min shareRatio"
    );
  }),
    it("Calculates shares correctly with min shareRatio set", async function () {
      const signers = await ethers.getSigners();

      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

      const alice = signers[1];

      const totalTokenSupply = await asset.totalSupply();

      const assets = totalTokenSupply.div(2);

      // give alice reserve to cover cost
      await asset.transfer(alice.address, assets);

      // Min shareRatio MUST be respected
      const shareRatio = await priceOracle.price();

      await asset.connect(alice).increaseAllowance(vault.address, assets);

      const expectedShares = fixedPointMul(assets, shareRatio);

      await vault.connect(alice).setMinShareRatio(shareRatio.sub(1));

      await vault
        .connect(alice)
        ["deposit(uint256,address,uint256,bytes)"](
          assets,
          alice.address,
          shareRatio,
          []
        );
      const shares = await vault
        .connect(alice)
        ["balanceOf(address)"](alice.address);

      assert(
        shares.eq(expectedShares),
        `wrong alice shares ${expectedShares} ${shares}`
      );
    }),
    it("Calculates shares correctly with NO min shareRatio set", async function () {
      const signers = await ethers.getSigners();

      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

      const alice = signers[1];

      const totalTokenSupply = await asset.totalSupply();

      const assets = totalTokenSupply.div(2);

      // give alice reserve to cover cost
      await asset.transfer(alice.address, assets);

      // Min shareRatio price MUST be respected
      const shareRatio = await priceOracle.price();

      await asset.connect(alice).increaseAllowance(vault.address, assets);

      const expectedShares = fixedPointMul(assets, shareRatio);

      await vault
        .connect(alice)
        ["deposit(uint256,address,uint256,bytes)"](
          assets,
          alice.address,
          shareRatio,
          []
        );
      const shares = await vault
        .connect(alice)
        ["balanceOf(address)"](alice.address);

      assert(
        shares.eq(expectedShares),
        `wrong alice ETHg ${expectedShares} ${shares}`
      );
    });
  it("Reverts if not enough assets to be transferred", async function () {
    const signers = await ethers.getSigners();

    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

    const alice = signers[1];

    const totalTokenSupply = await asset.totalSupply();

    const assets = totalTokenSupply.div(2);

    const shareRatio = await priceOracle.price();

    await asset.connect(alice).increaseAllowance(vault.address, assets);

    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["deposit(uint256,address,uint256,bytes)"](
            assets,
            alice.address,
            shareRatio,
            []
          ),
      "ERC20: transfer amount exceeds balance",
      "failed to deposit"
    );
  });
  it("Receiver MAY be different user to depositor", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const bob = signers[1];

    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
    const shareRatio = await priceOracle.price();

    const totalTokenSupply = await asset.totalSupply();
    const assets = totalTokenSupply.div(2);
    // give alice reserve to cover cost
    await asset.transfer(alice.address, assets);

    await asset.connect(alice).increaseAllowance(vault.address, assets);

    await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](
        assets,
        bob.address,
        shareRatio,
        []
      );
    const shares = await vault
      .connect(alice)
      ["balanceOf(address)"](bob.address);
    const expectedShares = fixedPointMul(assets, shareRatio);

    assert(
      shares.eq(expectedShares),
      `wrong alice shares ${expectedShares} ${shares}`
    );
  });
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

    await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](
        assets,
        bob.address,
        shareRatio,
        []
      );

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
  it("MUST revert if the vault can't take enough assets from the depositor", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[1];

    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
    const shareRatio = await priceOracle.price();

    const totalTokenSupply = await asset.totalSupply();
    const assets = totalTokenSupply.div(2);
    // give alice reserve to cover cost
    await asset.transfer(alice.address, assets);

    //alice has assets of totalsuply/2
    await asset.connect(alice).increaseAllowance(vault.address, assets.add(1));

    //try to deposit more assets than alice owns
    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["deposit(uint256,address,uint256,bytes)"](
            assets.add(1),
            alice.address,
            shareRatio,
            []
          ),
      "ERC20: transfer amount exceeds balance",
      "failed to revert"
    );
  });
  it("MUST NOT successfully deposit if the vault is not approved for the depositor's assets", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
    const shareRatio = await priceOracle.price();

    const totalTokenSupply = await asset.totalSupply();
    const assets = totalTokenSupply.div(2);
    // give alice reserve to cover cost
    await asset.transfer(alice.address, assets);

    //try to deposit without approve
    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["deposit(uint256,address,uint256,bytes)"](
            assets,
            alice.address,
            shareRatio,
            []
          ),
      "ERC20: insufficient allowance'",
      "failed to revert"
    );
  });
  it("should not deposit to zero address", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[1];

    const [vault, asset, oraclePrice] = await deployERC20PriceOracleVault();

    const totalTokenSupply = await asset.totalSupply();
    const aliceDepositAmount = totalTokenSupply.div(2);

    // give alice reserve to cover cost
    await asset.transfer(alice.address, aliceDepositAmount);

    const aliceReserveBalance = await asset.balanceOf(alice.address);

    await asset.connect(alice).approve(vault.address, aliceReserveBalance);

    const shareRatio = await oraclePrice.price();
    await assertError(
      async () =>
        await vault
          .connect(alice)
          ["deposit(uint256,address,uint256,bytes)"](
            aliceReserveBalance,
            ADDRESS_ZERO,
            shareRatio,
            []
          ),
      "ZeroReceiver",
      "failed to prevent deposit to zero address"
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
      ["deposit(uint256,address,uint256,bytes)"](
        aliceAmount,
        alice.address,
        shareRatio,
        []
      );
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
      `wrong caller expected ${alice.address} got ${depositEvent.args.sender}`
    );
    assert(
      depositEvent.args.owner === alice.address,
      `wrong owner expected ${alice.address} got ${depositEvent.args.owner}`
    );
  });
  it("Check DepositWithReceipt event is emitted", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

    const shareRatio = await priceOracle.price();

    const aliceAmount = ethers.BigNumber.from(5000);
    await asset.transfer(alice.address, aliceAmount);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAmount);

    const expectedId = shareRatio;
    //take random bytes for information
    const information = [125, 126];
    //generate hex string
    const expectedInformation =
      "0x" + information.map((num) => num.toString(16)).join("");

    const expectedShares = fixedPointMul(aliceAmount, shareRatio);

    const { sender, owner, assets, shares, id, receiptInformation } =
      (await getEventArgs(
        await vault
          .connect(alice)
          ["deposit(uint256,address,uint256,bytes)"](
            aliceAmount,
            alice.address,
            shareRatio,
            information
          ),
        "DepositWithReceipt",
        vault
      )) as DepositWithReceiptEvent["args"];

    assert(
      sender === alice.address,
      `wrong sender expected ${alice.address} got ${sender}`
    );
    assert(id.eq(expectedId), `wrong id expected ${id} got ${expectedId}`);

    assert(
      owner === alice.address,
      `wrong owner expected ${alice.address} got ${owner}`
    );
    assert(
      assets.eq(aliceAmount),
      `wrong assets expected ${aliceAmount} got ${assets}`
    );
    assert(
      shares.eq(expectedShares),
      `wrong shares expected ${expectedShares} got ${shares}`
    );

    assert(
      receiptInformation === expectedInformation,
      `wrong receiptInformation expected ${receiptInformation} got ${expectedInformation}`
    );
  });
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
  });
  it("Check WithdrawWithReceipt event is emitted", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const [vault, asset, priceOracle, receipt] =
      await deployERC20PriceOracleVault();

    const shareRatio = await priceOracle.price();

    const aliceAmount = ethers.BigNumber.from(5000);
    await asset.transfer(alice.address, aliceAmount);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAmount);

    const expectedId = shareRatio;
    //take random bytes for information
    const information = [125, 126];

    const depositTx = await vault
      .connect(alice)
      ["deposit(uint256,address,uint256,bytes)"](
        aliceAmount,
        alice.address,
        shareRatio,
        information
      );

    await depositTx.wait();

    const erc1155Balance = await receipt
      .connect(alice)
      ["balanceOf(address,uint256)"](alice.address, shareRatio);

    const { sender, receiver, owner, assets, shares, id } = (await getEventArgs(
      await vault
        .connect(alice)
        ["withdraw(uint256,address,address,uint256,bytes)"](
          erc1155Balance,
          alice.address,
          alice.address,
          shareRatio,
          []
        ),
      "WithdrawWithReceipt",
      vault
    )) as WithdrawWithReceiptEvent["args"];

    const expectedShares = fixedPointMul(assets, shareRatio).add(1);

    assert(
      sender === alice.address,
      `wrong caller expected ${alice.address} got ${sender}`
    );

    assert(
      receiver === alice.address,
      `wrong receiver expected ${alice.address} got ${receiver}`
    );

    assert(
      owner === alice.address,
      `wrong owner expected ${alice.address} got ${owner}`
    );

    assert(
      assets.eq(erc1155Balance),
      `wrong assets expected ${erc1155Balance} got ${assets}`
    );
    assert(
      shares.eq(expectedShares),
      `wrong shares expected ${expectedShares} got ${shares}`
    );

    assert(id.eq(expectedId), `wrong id expected ${id} got ${expectedId}`);
  });
});
describe("Mint", async function () {
  it("Sets maxShares correctly", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const [vault] = await deployERC20PriceOracleVault();

    const expectedMaxShares = ethers.BigNumber.from(2)
      .pow(256)
      //up to 2**256 so should substruct 1
      .sub(1);
    const maxShares = await vault.connect(alice).maxMint(owner.address);

    assert(
      maxShares.eq(expectedMaxShares),
      `Wrong max deposit ${expectedMaxShares} ${maxShares}`
    );
  });
  it("Checks min share ratio is less than share ratio", async function () {
    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
    const shareRatio = await priceOracle.price();

    const signers = await ethers.getSigners();
    const alice = signers[0];

    const shares = ethers.BigNumber.from("10").pow(20);

    await vault.connect(alice).setMinShareRatio(shareRatio.add(1));

    await assertError(
      async () => await vault.connect(alice).previewMint(shares),
      "MinShareRatio",
      "failed to respect min shareRatio"
    );
  });
  it("PreviewMint - Calculates assets correctly with round up", async function () {
    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
    const signers = await ethers.getSigners();
    const alice = signers[0];
    const shareRatio = await priceOracle.price();

    assert(
      shareRatio.eq(expectedReferencePrice),
      `Incorrect shareRatio ${shareRatio} ${expectedReferencePrice}`
    );

    const shares = ethers.BigNumber.from("10").pow(20);
    const expectedAssets = fixedPointDiv(shares, shareRatio).add(1);

    const assets = await vault.connect(alice).previewMint(shares);

    assert(
      assets.eq(expectedAssets),
      `Wrong max deposit ${expectedAssets} ${assets}`
    );
  });
  it("Mint - Calculates assets correctly", async function () {
    const signers = await ethers.getSigners();

    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

    const alice = signers[0];

    const assets = ethers.BigNumber.from(5000);
    await asset.transfer(alice.address, assets);
    await asset.connect(alice).increaseAllowance(vault.address, assets);

    const aliceBalanceBefore = await asset.balanceOf(alice.address);

    const shareRatio = await priceOracle.price();

    const shares = fixedPointMul(assets, shareRatio);

    await vault.connect(alice)["mint(uint256,address)"](shares, alice.address);

    const expectedAssets = fixedPointDiv(shares, shareRatio).add(1);

    const aliceBalanceAfter = await asset.balanceOf(alice.address);
    const aliceBalanceDiff = aliceBalanceBefore.sub(aliceBalanceAfter);

    assert(
      aliceBalanceDiff.eq(expectedAssets),
      `wrong alice assets ${expectedAssets} ${aliceBalanceDiff}`
    );
  });
});
