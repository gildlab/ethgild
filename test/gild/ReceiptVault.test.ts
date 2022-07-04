import chai from "chai";
import {solidity} from "ethereum-waffle";
import {ethers} from "hardhat";
import {
  deployERC20PriceOracleVault,
} from "../util";
import {ERC20PriceOracleVaultConstructionEvent} from "../../typechain/ERC20PriceOracleVault";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";

import {getEventArgs} from "../util";

let owner: SignerWithAddress

chai.use(solidity);

const {assert} = chai;

describe("config", async function () {
  it("Returns the address of the underlying asset that is deposited", async function () {
    const [vault, asset] = await deployERC20PriceOracleVault();
    const vaultAsset = await vault.asset();

    assert(
      vaultAsset === asset.address,
      "Wrong asset address"
    );
  }),
    it("Sets the correct min Share Ratio", async function () {
      [owner] = await ethers.getSigners()
      const expectedMinShareRatio = 100

      const [vault, asset] = await deployERC20PriceOracleVault();
      await vault.setMinShareRatio(100)
      let minShareRatio = await vault.minShareRatios(owner.address)

      assert(
        minShareRatio.toNumber() === expectedMinShareRatio,
        "Wrong min Share Ratio"
      );
    })
})
