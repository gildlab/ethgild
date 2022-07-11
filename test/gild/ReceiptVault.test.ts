import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import {
  assertError,
  deployERC20PriceOracleVault,
  fixedPointDiv,
  fixedPointMul,
  ADDRESS_ZERO,
} from "../util";
import { DepositEvent } from "../../typechain/IERC4626";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ReceiptInformationEvent } from "../../typechain/ReceiptVault";

import { getEventArgs } from "../util";

let owner: SignerWithAddress;

chai.use(solidity);

const { assert } = chai;

describe("Receipt vault", async function () {
  it("Returns the address of the underlying asset that is deposited", async function () {
    const [vault, asset] = await deployERC20PriceOracleVault();
    const vaultAsset = await vault.asset();

    assert(
      vaultAsset === asset.address,
      `Wrong asset address ${asset.address} ${vaultAsset}`
    );
  }),
    it("Sets the correct min Share Ratio", async function () {
      [owner] = await ethers.getSigners();
      const expectedMinShareRatio = ethers.BigNumber.from("100");

      const [vault] = await deployERC20PriceOracleVault();
      await vault.setMinShareRatio(100);
      let minShareRatio = await vault.minShareRatios(owner.address);

      assert(
        minShareRatio.eq(expectedMinShareRatio),
        `Wrong min Share Ratio ${expectedMinShareRatio} ${minShareRatio}`
      );
    }),
    it("Sets the correct withdraw Id", async function () {
      [owner] = await ethers.getSigners();
      const expectedWithdrawId = ethers.BigNumber.from("100");

      const [vault] = await deployERC20PriceOracleVault();
      await vault.setWithdrawId(100);
      let withdrawId = await vault.withdrawIds(owner.address);

      assert(
        withdrawId.eq(expectedWithdrawId),
        `Wrong withdraw Id ${expectedWithdrawId} ${withdrawId}`
      );
    }),
    it("Checks total asset is same as balance", async function () {
      // [owner] = await ethers.getSigners()
      //
      // const [vault, asset] = await deployERC20PriceOracleVault();
      //
      // console.log(await asset.balanceOf(vault.address), await vault.totalAssets())
      // assert(
      //   withdrawId.toNumber() === expectedWithdrawId,
      //   `Wrong withdraw Id ${expectedWithdrawId} ${withdrawId.toNumber()}`
      // );
    }),
    it("Calculates correct assets", async function () {
      [owner] = await ethers.getSigners();

      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

      const price = await priceOracle.price();

      const share = ethers.BigNumber.from("10").pow(20);
      const expectedAsset = fixedPointDiv(share, price);

      const assets = await vault.convertToAssets(share);

      assert(
        assets.eq(expectedAsset),
        `Wrong asset ${expectedAsset} ${assets}`
      );
    }),
    it("Shows no variations based on caller", async function () {
      const signers = await ethers.getSigners();
      const alice = signers[0];
      const bob = signers[1];

      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

      const aliceEthGild = vault.connect(alice);
      const bobEthGild = vault.connect(bob);

      const price = await priceOracle.price();

      const share = ethers.BigNumber.from("10").pow(20);
      const expectedAsset = fixedPointDiv(share, price);

      const assetsAlice = await aliceEthGild.convertToAssets(share);
      const assetsBob = await bobEthGild.convertToAssets(share);

      assert(
        assetsAlice.eq(assetsBob),
        `Wrong asset ${assetsAlice} ${assetsBob}`
      );
    }),
    it("Calculates correct shares", async function () {
      [owner] = await ethers.getSigners();

      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

      const price = await priceOracle.price();

      const minPrice = ethers.BigNumber.from(0);

      assert(
        price >= minPrice,
        `price is less then minPrice ${price} ${minPrice}`
      );

      const assets = ethers.BigNumber.from("10").pow(20);
      const expectedShares = fixedPointMul(assets, price);

      const shares = await vault.convertToShares(assets);

      assert(
        shares.eq(expectedShares),
        `Wrong share ${expectedShares} ${shares}`
      );
    }),
    it("Shows no variations based on caller for convertToShares", async function () {
      const signers = await ethers.getSigners();
      const alice = signers[0];
      const bob = signers[1];

      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

      const aliceEthGild = vault.connect(alice);
      const bobEthGild = vault.connect(bob);

      const price = await priceOracle.price();

      const assets = ethers.BigNumber.from("10").pow(20);
      const expectedShares = fixedPointMul(assets, price);

      const sharesAlice = await aliceEthGild.convertToShares(assets);
      const sharesBob = await bobEthGild.convertToShares(assets);

      assert(
        sharesAlice.eq(sharesBob),
        `Wrong shares ${sharesAlice} ${sharesBob}`
      );
    }),
    it("Sets correct max deposit value", async function () {
      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

      const expectedMaxDeposit = ethers.BigNumber.from(2)
        .pow(256)
        //up to 2**256 so should substruct 1
        .sub(1);
      const maxDeposit = await vault.maxDeposit(owner.address);

      assert(
        maxDeposit.eq(expectedMaxDeposit),
        `Wrong max deposit ${expectedMaxDeposit} ${maxDeposit}`
      );
    }),
    it("Respects min price in case of previewDeposit", async function () {
      const signers = await ethers.getSigners();
      const alice = signers[0];

      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

      const assets = ethers.BigNumber.from("10").pow(20);
      const price = await priceOracle.price();

      await vault.setMinShareRatio(price.add(1));

      await assertError(
        async () => await vault.connect(alice).previewDeposit(assets),
        "MIN_PRICE",
        "failed to respect min price"
      );
    }),
    it("Sets correct shares by previewDeposit", async function () {
      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

      const assets = ethers.BigNumber.from("10").pow(20);

      const price = await priceOracle.price();
      const expectedshares = fixedPointMul(assets, price);
      const share = await vault.previewDeposit(assets);

      assert(
        share.eq(expectedshares),
        `Wrong shares ${expectedshares} ${share}`
      );
    });
}),
  describe("Deposit", async () => {
    it("Must respect min Price", async function () {
      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
      const price = await priceOracle.price();

      const signers = await ethers.getSigners();
      const alice = signers[0];
      const bob = signers[1];

      const assets = ethers.BigNumber.from("10").pow(20);
      const expectedShares = fixedPointMul(assets, price);

      await vault.connect(alice).setMinShareRatio(price.add(1));

      await asset.connect(alice).increaseAllowance(vault.address, assets);

      await assertError(
        async () =>
          await vault
            .connect(alice)
            ["deposit(uint256,address)"](assets, bob.address),
        "MIN_SHARE_RATIO",
        "failed to respect min price"
      );
    }),
      it("Calculates shares correctly with min price set", async function () {
        const signers = await ethers.getSigners();

        const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

        const alice = signers[1];

        const totalTokenSupply = await asset.totalSupply();

        const assets = totalTokenSupply.div(2);

        // give alice reserve to cover cost
        await asset.transfer(alice.address, assets);

        // Min gild price MUST be respected
        const price = await priceOracle.price();

        await asset.connect(alice).increaseAllowance(vault.address, assets);

        const expectedShares = fixedPointMul(assets, price);

        await vault.connect(alice).setMinShareRatio(price.sub(1));

        await vault
          .connect(alice)
          ["deposit(uint256,address)"](assets, alice.address);
        const shares = await vault["balanceOf(address)"](alice.address);

        assert(
          shares.eq(expectedShares),
          `wrong alice shares ${expectedShares} ${shares}`
        );
      }),
      it("Calculates shares correctly with NO min price set", async function () {
        const signers = await ethers.getSigners();

        const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

        const alice = signers[1];

        const totalTokenSupply = await asset.totalSupply();

        const assets = totalTokenSupply.div(2);

        // give alice reserve to cover cost
        await asset.transfer(alice.address, assets);

        // Min gild price MUST be respected
        const price = await priceOracle.price();

        await asset.connect(alice).increaseAllowance(vault.address, assets);

        const expectedShares = fixedPointMul(assets, price);

        await vault
          .connect(alice)
          ["deposit(uint256,address)"](assets, alice.address);
        const shares = await vault["balanceOf(address)"](alice.address);

        assert(
          shares.eq(expectedShares),
          `wrong alice ETHg ${expectedShares} ${shares}`
        );
      }),
      it("Reverts if not enough assets to be transfered", async function () {
        const signers = await ethers.getSigners();

        const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

        const alice = signers[1];

        const totalTokenSupply = await asset.totalSupply();

        const assets = totalTokenSupply.div(2);

        const price = await priceOracle.price();

        await asset.connect(alice).increaseAllowance(vault.address, assets);

        await assertError(
          async () =>
            await vault
              .connect(alice)
              ["deposit(uint256,address)"](assets, alice.address),
          "ERC20: transfer amount exceeds balance",
          "failed to respect min price"
        );
      }),
      it("Receiver MAY be different user to depositor", async function () {
        const signers = await ethers.getSigners();
        const alice = signers[0];
        const bob = signers[1];

        const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
        const price = await priceOracle.price();

        const totalTokenSupply = await asset.totalSupply();
        const assets = totalTokenSupply.div(2);
        // give alice reserve to cover cost
        await asset.transfer(alice.address, assets);

        await asset.connect(alice).increaseAllowance(vault.address, assets);

        await vault
          .connect(alice)
          ["deposit(uint256,address)"](assets, bob.address);
        const shares = await vault["balanceOf(address)"](bob.address);
        const expectedShares = fixedPointMul(assets, price);

        assert(
          shares.eq(expectedShares),
          `wrong alice ETHg ${expectedShares} ${shares}`
        );
      }),
      it("Receiver receives BOTH erc20 and erc1155, depositor gets nothing but MUST transfer assets", async function () {
        const signers = await ethers.getSigners();
        const alice = signers[0];
        const bob = signers[1];

        const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
        const price = await priceOracle.price();

        const totalTokenSupply = await asset.totalSupply();
        const assets = totalTokenSupply.div(2);
        // give alice reserve to cover cost
        await asset.transfer(alice.address, assets);

        await asset.connect(alice).increaseAllowance(vault.address, assets);

        const bobErc20BalanceBef = await vault["balanceOf(address)"](
          bob.address
        );
        const aliceErc20BalanceBef = await vault["balanceOf(address)"](
          alice.address
        );

        //Alice assets before deposit
        const aliceAssetBefore = await asset
          .connect(alice)
          .balanceOf(alice.address);

        await vault
          .connect(alice)
          ["deposit(uint256,address)"](assets, bob.address);

        const expectedBobBalance = fixedPointMul(assets, price);

        //Receiver gets both Erc20 and Erc1155
        const erc1155Balance = await vault["balanceOf(address,uint256)"](
          bob.address,
          price
        );

        const bobErc20Balance = await vault["balanceOf(address)"](bob.address);

        assert(
          erc1155Balance.eq(expectedBobBalance),
          `wrong bob erc1155 balance ${expectedBobBalance} ${erc1155Balance}`
        );

        assert(
          bobErc20Balance.eq(expectedBobBalance),
          `wrong bob erc1155 balance ${expectedBobBalance} ${bobErc20Balance}`
        );

        //Depositor Gets nothing
        const aliceErc20Balance = await vault["balanceOf(address)"](
          alice.address
        );

        const aliceErc1155Balance = await vault["balanceOf(address,uint256)"](
          alice.address,
          price
        );

        assert(
          aliceErc1155Balance.eq(0),
          `wrong alice erc20 balance ${aliceErc1155Balance} 0`
        );

        assert(
          aliceErc20Balance.eq(0),
          `wrong alice erc20 balance ${aliceErc20Balance} 0`
        );

        //Depositor MUST transfer assets
        const aliceAssetAft = await asset
          .connect(alice)
          .balanceOf(alice.address);

        assert(
          aliceAssetAft.eq(aliceAssetBefore.sub(assets)),
          `wrong alice assets ${aliceAssetAft} ${aliceAssetBefore.sub(assets)}`
        );
      }),
      it("MUST revert if the vault can't take enough assets from the depositor", async function () {
        const signers = await ethers.getSigners();
        const alice = signers[1];

        const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
        const price = await priceOracle.price();

        const totalTokenSupply = await asset.totalSupply();
        const assets = totalTokenSupply.div(2);
        // give alice reserve to cover cost
        await asset.transfer(alice.address, assets);

        const aliceAssets = await asset.connect(alice).balanceOf(alice.address);

        //alice has assets of totalsuply/2
        await asset
          .connect(alice)
          .increaseAllowance(vault.address, assets.add(1));

        //try to deposit more assets then alice owns
        await assertError(
          async () =>
            await vault
              .connect(alice)
              ["deposit(uint256,address)"](assets.add(1), alice.address),
          "ERC20: transfer amount exceeds balance",
          "failed to revert"
        );
      }),
      it("MUST NOT successfully deposit if the vault is not approved for the depositor's assets", async function () {
        const signers = await ethers.getSigners();
        const alice = signers[0];

        const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
        const price = await priceOracle.price();

        const totalTokenSupply = await asset.totalSupply();
        const assets = totalTokenSupply.div(2);
        // give alice reserve to cover cost
        await asset.transfer(alice.address, assets);

        const aliceAssets = await asset.connect(alice).balanceOf(alice.address);

        //try to deposit without approve
        await assertError(
          async () =>
            await vault
              .connect(alice)
              ["deposit(uint256,address)"](assets, alice.address),
          "ERC20: insufficient allowance'",
          "failed to revert"
        );
      }),
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
            await vault["deposit(uint256,address)"](
              aliceReserveBalance,
              ADDRESS_ZERO
            ),
          "0_RECEIVER",
          "failed to prevent deposit to zero address"
        );
      });
    it("Check deposit event is emitted", async function () {
      const signers = await ethers.getSigners();
      const alice = signers[0];

      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

      const price = await priceOracle.price();

      const aliceAmount = ethers.BigNumber.from(5000);
      await asset.transfer(alice.address, aliceAmount);

      await asset.connect(alice).increaseAllowance(vault.address, aliceAmount);

      const expectedShares = fixedPointMul(aliceAmount, price);

      const { caller, owner, assets, shares } = (await getEventArgs(
        await vault
          .connect(alice)
          ["deposit(uint256,address)"](aliceAmount, alice.address),
        "Deposit",
        vault
      )) as DepositEvent["args"];

      assert(
        assets.eq(aliceAmount),
        `wrong assets expected ${aliceAmount} got ${assets}`
      );
      assert(
        shares.eq(expectedShares),
        `wrong shares expected ${shares} got ${expectedShares}`
      );
    });
  }),
  describe("Overloaded `deposit`", async () => {
    it("Must respect min Price", async function () {
      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
      const price = await priceOracle.price();

      const signers = await ethers.getSigners();
      const alice = signers[0];
      const bob = signers[1];

      const totalTokenSupply = await asset.totalSupply();

      const assets = totalTokenSupply.div(2);

      const expectedShares = fixedPointMul(assets, price);

      await vault.connect(alice).setMinShareRatio(price.add(1));

      await asset.connect(alice).increaseAllowance(vault.address, assets);

      await assertError(
        async () =>
          await vault
            .connect(alice)
            ["deposit(uint256,address,uint256,bytes)"](
              assets,
              alice.address,
              price.add(1),
              []
            ),
        "MIN_SHARE_RATIO",
        "failed to respect min price"
      );
    }),
      it("Calculates shares correctly with min price set", async function () {
        const signers = await ethers.getSigners();

        const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

        const alice = signers[1];

        const totalTokenSupply = await asset.totalSupply();

        const assets = totalTokenSupply.div(2);

        // give alice reserve to cover cost
        await asset.transfer(alice.address, assets);

        // Min gild price MUST be respected
        const price = await priceOracle.price();

        await asset.connect(alice).increaseAllowance(vault.address, assets);

        const expectedShares = fixedPointMul(assets, price);

        await vault.connect(alice).setMinShareRatio(price.sub(1));

        await vault
          .connect(alice)
          ["deposit(uint256,address,uint256,bytes)"](
            assets,
            alice.address,
            price,
            []
          );
        const shares = await vault["balanceOf(address)"](alice.address);

        assert(
          shares.eq(expectedShares),
          `wrong alice shares ${expectedShares} ${shares}`
        );
      }),
      it("Calculates shares correctly with NO min price set", async function () {
        const signers = await ethers.getSigners();

        const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

        const alice = signers[1];

        const totalTokenSupply = await asset.totalSupply();

        const assets = totalTokenSupply.div(2);

        // give alice reserve to cover cost
        await asset.transfer(alice.address, assets);

        // Min gild price MUST be respected
        const price = await priceOracle.price();

        await asset.connect(alice).increaseAllowance(vault.address, assets);

        const expectedShares = fixedPointMul(assets, price);

        await vault
          .connect(alice)
          ["deposit(uint256,address,uint256,bytes)"](
            assets,
            alice.address,
            price,
            []
          );
        const shares = await vault["balanceOf(address)"](alice.address);

        assert(
          shares.eq(expectedShares),
          `wrong alice ETHg ${expectedShares} ${shares}`
        );
      }),
      it("Reverts if not enough assets to be transfered", async function () {
        const signers = await ethers.getSigners();

        const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

        const alice = signers[1];

        const totalTokenSupply = await asset.totalSupply();

        const assets = totalTokenSupply.div(2);

        const price = await priceOracle.price();

        await asset.connect(alice).increaseAllowance(vault.address, assets);

        await assertError(
          async () =>
            await vault
              .connect(alice)
              ["deposit(uint256,address,uint256,bytes)"](
                assets,
                alice.address,
                price,
                []
              ),
          "ERC20: transfer amount exceeds balance",
          "failed to respect min price"
        );
      }),
      it("Receiver MAY be different user to depositor", async function () {
        const signers = await ethers.getSigners();
        const alice = signers[0];
        const bob = signers[1];

        const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
        const price = await priceOracle.price();

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
            price,
            []
          );
        const shares = await vault["balanceOf(address)"](bob.address);
        const expectedShares = fixedPointMul(assets, price);

        assert(
          shares.eq(expectedShares),
          `wrong alice ETHg ${expectedShares} ${shares}`
        );
      }),
      it("Receiver receives BOTH erc20 and erc1155, depositor gets nothing but MUST transfer assets", async function () {
        const signers = await ethers.getSigners();
        const alice = signers[0];
        const bob = signers[1];

        const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
        const price = await priceOracle.price();

        const totalTokenSupply = await asset.totalSupply();
        const assets = totalTokenSupply.div(2);
        // give alice reserve to cover cost
        await asset.transfer(alice.address, assets);

        await asset.connect(alice).increaseAllowance(vault.address, assets);

        const bobErc20BalanceBef = await vault["balanceOf(address)"](
          bob.address
        );
        const aliceErc20BalanceBef = await vault["balanceOf(address)"](
          alice.address
        );

        //Alice assets before deposit
        const aliceAssetBefore = await asset
          .connect(alice)
          .balanceOf(alice.address);

        await vault
          .connect(alice)
          ["deposit(uint256,address,uint256,bytes)"](
            assets,
            bob.address,
            price,
            []
          );

        const expectedBobBalance = fixedPointMul(assets, price);

        //Receiver gets both Erc20 and Erc1155
        const erc1155Balance = await vault["balanceOf(address,uint256)"](
          bob.address,
          price
        );

        const bobErc20Balance = await vault["balanceOf(address)"](bob.address);

        assert(
          erc1155Balance.eq(expectedBobBalance),
          `wrong bob erc1155 balance ${expectedBobBalance} ${erc1155Balance}`
        );

        assert(
          bobErc20Balance.eq(expectedBobBalance),
          `wrong bob erc1155 balance ${expectedBobBalance} ${bobErc20Balance}`
        );

        //Depositor Gets nothing
        const aliceErc20Balance = await vault["balanceOf(address)"](
          alice.address
        );

        const aliceErc1155Balance = await vault["balanceOf(address,uint256)"](
          alice.address,
          price
        );

        assert(
          aliceErc1155Balance.eq(0),
          `wrong alice erc20 balance ${aliceErc1155Balance} 0`
        );

        assert(
          aliceErc20Balance.eq(0),
          `wrong alice erc20 balance ${aliceErc20Balance} 0`
        );

        //Depositor MUST transfer assets
        const aliceAssetAft = await asset
          .connect(alice)
          .balanceOf(alice.address);

        assert(
          aliceAssetAft.eq(aliceAssetBefore.sub(assets)),
          `wrong alice assets ${aliceAssetAft} ${aliceAssetBefore.sub(assets)}`
        );
      }),
      it("MUST revert if the vault can't take enough assets from the depositor", async function () {
        const signers = await ethers.getSigners();
        const alice = signers[1];

        const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
        const price = await priceOracle.price();

        const totalTokenSupply = await asset.totalSupply();
        const assets = totalTokenSupply.div(2);
        // give alice reserve to cover cost
        await asset.transfer(alice.address, assets);

        const aliceAssets = await asset.connect(alice).balanceOf(alice.address);

        //alice has assets of totalsuply/2
        await asset
          .connect(alice)
          .increaseAllowance(vault.address, assets.add(1));

        //try to deposit more assets then alice owns
        await assertError(
          async () =>
            await vault
              .connect(alice)
              ["deposit(uint256,address,uint256,bytes)"](
                assets.add(1),
                alice.address,
                price,
                []
              ),
          "ERC20: transfer amount exceeds balance",
          "failed to revert"
        );
      }),
      it("MUST NOT successfully deposit if the vault is not approved for the depositor's assets", async function () {
        const signers = await ethers.getSigners();
        const alice = signers[0];

        const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
        const price = await priceOracle.price();

        const totalTokenSupply = await asset.totalSupply();
        const assets = totalTokenSupply.div(2);
        // give alice reserve to cover cost
        await asset.transfer(alice.address, assets);

        const aliceAssets = await asset.connect(alice).balanceOf(alice.address);

        //try to deposit without approve
        await assertError(
          async () =>
            await vault
              .connect(alice)
              ["deposit(uint256,address,uint256,bytes)"](
                assets,
                alice.address,
                price,
                []
              ),
          "ERC20: insufficient allowance'",
          "failed to revert"
        );
      }),
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

        const price = await oraclePrice.price();
        await assertError(
          async () =>
            await vault
              .connect(alice)
              ["deposit(uint256,address,uint256,bytes)"](
                aliceReserveBalance,
                ADDRESS_ZERO,
                price,
                []
              ),
          "0_RECEIVER",
          "failed to prevent deposit to zero address"
        );
      });
    it("Check deposit event is emitted", async function () {
      const signers = await ethers.getSigners();
      const alice = signers[0];

      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

      const price = await priceOracle.price();

      const aliceAmount = ethers.BigNumber.from(5000);
      await asset.transfer(alice.address, aliceAmount);

      await asset.connect(alice).increaseAllowance(vault.address, aliceAmount);

      const expectedShares = fixedPointMul(aliceAmount, price);

      const { caller, owner, assets, shares } = (await getEventArgs(
        await vault["deposit(uint256,address,uint256,bytes)"](
          aliceAmount,
          alice.address,
          price,
          []
        ),
        "Deposit",
        vault
      )) as DepositEvent["args"];

      console.log(caller, owner);

      assert(
        assets.eq(aliceAmount),
        `wrong assets expected ${aliceAmount} got ${assets}`
      );
      assert(
        shares.eq(expectedShares),
        `wrong shares expected ${shares} got ${expectedShares}`
      );

      //todo
      // assert(
      //   caller === alice.address,
      //   `wrong caller expected ${alice.address} got ${caller}`
      // );
      // assert(
      //   owner === alice.address,
      //   `wrong owner expected ${alice.address} got ${owner}`
      // );
    });
  });
describe("Mint", async function () {
  it("Check ReceiptInformation event is emitted", async function () {
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

    const price = await priceOracle.price();

    const aliceAmount = ethers.BigNumber.from(5000);
    await asset.transfer(alice.address, aliceAmount);

    await asset.connect(alice).increaseAllowance(vault.address, aliceAmount);

    const expectedId = price;
    const expectedInformation = ethers.utils.randomBytes(5);

    const { caller, id, information } = (await getEventArgs(
      await vault["deposit(uint256,address,uint256,bytes)"](
        aliceAmount,
        alice.address,
        price,
        expectedInformation
      ),
      "ReceiptInformation",
      vault
    )) as ReceiptInformationEvent["args"];

    assert(
      caller === alice.address,
      `wrong assets expected ${alice.address} got ${caller}`
    );
    assert(id.eq(expectedId), `wrong shares expected ${id} got ${expectedId}`);

    //todo
    // assert(
    //   information === expectedInformation,
    //   `wrong shares expected ${information} got ${expectedInformation}`
    // );
  });
  it("Sets maxShares correctly", async function () {
    const [vault] = await deployERC20PriceOracleVault();

    const expectedMaxShares = ethers.BigNumber.from(2)
      .pow(256)
      //up to 2**256 so should substruct 1
      .sub(1);
    const maxShares = await vault.maxMint(owner.address);

    assert(
      maxShares.eq(expectedMaxShares),
      `Wrong max deposit ${expectedMaxShares} ${maxShares}`
    );
  }),
    it("Checks min share ratio is less than share ratio", async function () {
      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
      const price = await priceOracle.price();

      const signers = await ethers.getSigners();
      const alice = signers[0];

      const shares = ethers.BigNumber.from("10").pow(20);

      await vault.connect(alice).setMinShareRatio(price.add(1));

      await assertError(
        async () => await vault.previewMint(shares),
        "MIN_SHARE_RATIO",
        "failed to respect min price"
      );
    }),
    it("Calculates assets correctly with round up", async function () {
      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
      const price = await priceOracle.price();

      const shares = ethers.BigNumber.from("10").pow(20);
      const expectedAssets = fixedPointDiv(shares, price).add(1);

      const assets = await vault.previewMint(shares);

      assert(
        assets.eq(expectedAssets),
        `Wrong max deposit ${expectedAssets} ${assets}`
      );
    });
});
