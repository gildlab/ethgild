import chai from "chai";
import {solidity} from "ethereum-waffle";
import {ethers} from "hardhat";
import {
  assertError,
  deployERC20PriceOracleVault,
  fixedPointDiv,
  fixedPointMul
} from "../util";
import {ERC20PriceOracleVaultConstructionEvent} from "../../typechain/ERC20PriceOracleVault";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {TestErc20} from "../../typechain";


import {getEventArgs} from "../util";

let owner: SignerWithAddress

chai.use(solidity);

const {assert} = chai;

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
      [owner] = await ethers.getSigners()
      const expectedMinShareRatio = ethers.BigNumber.from("100")

      const [vault] = await deployERC20PriceOracleVault();
      await vault.setMinShareRatio(100)
      let minShareRatio = await vault.minShareRatios(owner.address)

      assert(
        minShareRatio.eq(expectedMinShareRatio),
        `Wrong min Share Ratio ${expectedMinShareRatio} ${minShareRatio}`
      );
    }),
    it("Sets the correct withdraw Id", async function () {
      [owner] = await ethers.getSigners()
      const expectedWithdrawId = ethers.BigNumber.from("100")

      const [vault] = await deployERC20PriceOracleVault();
      await vault.setWithdrawId(100)
      let withdrawId = await vault.withdrawIds(owner.address)

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
      [owner] = await ethers.getSigners()

      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

      const price = await priceOracle.price()

      const share = ethers.BigNumber.from("10").pow(20)
      const expectedAsset = fixedPointDiv(share, price)

      const assets = await vault.convertToAssets(share)

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

      const price = await priceOracle.price()

      const share = ethers.BigNumber.from("10").pow(20)
      const expectedAsset = fixedPointDiv(share, price)

      const assetsAlice = await aliceEthGild.convertToAssets(share)
      const assetsBob = await bobEthGild.convertToAssets(share)

      assert(
        assetsAlice.eq(assetsBob),
        `Wrong asset ${assetsAlice} ${assetsBob}`
      );
    }),
    it("Calculates correct shares", async function () {
      [owner] = await ethers.getSigners()

      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

      const price = await priceOracle.price()

      const minPrice = ethers.BigNumber.from(0)

      assert(
        price >= minPrice,
        `price is less then minPrice ${price} ${minPrice}`
      );

      const assets = ethers.BigNumber.from("10").pow(20)
      const expectedShares = fixedPointMul(assets, price)

      const shares = await vault.convertToShares(assets)

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

      const price = await priceOracle.price()

      const assets = ethers.BigNumber.from("10").pow(20)
      const expectedShares = fixedPointMul(assets, price)

      const sharesAlice = await aliceEthGild.convertToShares(assets)
      const sharesBob = await bobEthGild.convertToShares(assets)

      assert(
        sharesAlice.eq(sharesBob),
        `Wrong shares ${sharesAlice} ${sharesBob}`
      );
    }),
    it("Sets correct max deposit value", async function () {
      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

      const expectedMaxDeposit = ethers.BigNumber.from(2).pow(256)
        //up to 2**256 so should substruct 1
        .sub(1)
      const maxDeposit = await vault.maxDeposit(owner.address)

      assert(
        maxDeposit.eq(expectedMaxDeposit),
        `Wrong max deposit ${expectedMaxDeposit} ${maxDeposit}`
      );
    }),
    it("Respects min price in case of previewDeposit", async function () {
      const signers = await ethers.getSigners();
      const alice = signers[0];

      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

      const assets = ethers.BigNumber.from("10").pow(20)
      const price = await priceOracle.price()

      await vault.setMinShareRatio(price.add(1))

      await assertError(
        async () =>
          await vault
            .connect(alice).previewDeposit(assets),
        "MIN_PRICE",
        "failed to respect min price"
      );
    }),
    it("Sets correct shares by previewDeposit", async function () {
      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

      const assets = ethers.BigNumber.from("10").pow(20)


      const price = await priceOracle.price()
      const expectedshares = fixedPointMul(assets, price)
      const share = await vault.previewDeposit(assets)

      assert(
        share.eq(expectedshares),
        `Wrong shares ${expectedshares} ${share}`
      );
    })
}),
  describe("Deposit", async () => {
    it("Must respect min Price", async function () {
      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
      const price = await priceOracle.price()

      const signers = await ethers.getSigners();
      const alice = signers[0];
      const bob = signers[1];

      const assets = ethers.BigNumber.from("10").pow(20)
      const expectedShares = fixedPointMul(assets, price)

      await vault.connect(alice).setMinShareRatio(price.add(1))

      await assertError(
        async () =>
          await vault
            .connect(alice)['deposit(uint256,address)'](assets, bob.address),
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
        await asset.transfer(alice.address, assets)

        // Min gild price MUST be respected
        const price = await priceOracle.price();

        await asset
          .connect(alice)
          .increaseAllowance(vault.address, assets);

        const expectedShares = fixedPointMul(assets, price)

        await vault.connect(alice).setMinShareRatio(price.sub(1))

        await vault.connect(alice)['deposit(uint256,address)'](assets, alice.address)
        const shares = await vault["balanceOf(address)"](alice.address);

        assert(
          shares.eq(expectedShares),
          `wrong alice ETHg ${expectedShares} ${shares}`
        );
      }),
      it("Calculates shares correctly with NO min price set", async function () {
        const signers = await ethers.getSigners();

        const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

        const alice = signers[1];

        const totalTokenSupply = await asset.totalSupply();

        const assets = totalTokenSupply.div(2);

        // give alice reserve to cover cost
        await asset.transfer(alice.address, assets)

        // Min gild price MUST be respected
        const price = await priceOracle.price();

        await asset
          .connect(alice)
          .increaseAllowance(vault.address, assets);

        const expectedShares = fixedPointMul(assets, price)

        await vault.connect(alice)['deposit(uint256,address)'](assets, alice.address)
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

        await asset
          .connect(alice)
          .increaseAllowance(vault.address, assets);

        await assertError(
          async () =>
            await vault
              .connect(alice)['deposit(uint256,address)'](assets, alice.address),
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
        await asset.transfer(alice.address, assets)

        await asset
          .connect(alice)
          .increaseAllowance(vault.address, assets);

        await vault.connect(alice)['deposit(uint256,address)'](assets, bob.address)
        const shares = await vault["balanceOf(address)"](bob.address);
        const expectedShares = fixedPointMul(assets, price)

        assert(
          shares.eq(expectedShares),
          `wrong alice ETHg ${expectedShares} ${shares}`
        );
      })
  })

