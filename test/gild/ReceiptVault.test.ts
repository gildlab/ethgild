import chai from "chai";
import {solidity} from "ethereum-waffle";
import {ethers} from "hardhat";
import {
  deployERC20PriceOracleVault,
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
      const expectedMinShareRatio = 100

      const [vault] = await deployERC20PriceOracleVault();
      await vault.setMinShareRatio(100)
      let minShareRatio = await vault.minShareRatios(owner.address)

      assert(
        minShareRatio.toNumber() === expectedMinShareRatio,
        `Wrong min Share Ratio ${expectedMinShareRatio} ${minShareRatio.toNumber()}`
      );
    }),
    it("Sets the correct withdraw Id", async function () {
      [owner] = await ethers.getSigners()
      const expectedWithdrawId = 100

      const [vault] = await deployERC20PriceOracleVault();
      await vault.setWithdrawId(100)
      let withdrawId = await vault.withdrawIds(owner.address)

      assert(
        withdrawId.toNumber() === expectedWithdrawId,
        `Wrong withdraw Id ${expectedWithdrawId} ${withdrawId.toNumber()}`
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
    it("calculates correct assets", async function () {
      [owner] = await ethers.getSigners()

      const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

      const price = await priceOracle.price()

      const share = 100

      const expectedAsset = share / price.toNumber()

      console.log(expectedAsset)

      const assets = await vault.convertToAssets(share)
      console.log(assets)

      // assert(
      // withdrawId.toNumber() === expectedWithdrawId,
      // `Wrong withdraw Id ${expectedWithdrawId} ${withdrawId.toNumber()}`
      // );
    })
})
