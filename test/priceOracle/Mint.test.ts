import { ethers } from "hardhat";
import {
  assertError,
  deployERC20PriceOracleVault,
  fixedPointDiv,
  fixedPointMul,
  expectedReferencePrice,
  ADDRESS_ZERO,
} from "../util";

const assert = require("assert");

describe("Mint", async function () {
  it("Sets maxShares correctly", async function () {
    const signers = await ethers.getSigners();
    const owner = signers[0];

    const [vault] = await deployERC20PriceOracleVault();

    const expectedMaxShares = ethers.BigNumber.from(2)
      .pow(256)
      //up to 2**256 so should substruct 1
      .sub(1);
    const maxShares = await vault.connect(owner).maxMint(owner.address);

    assert(
      maxShares.eq(expectedMaxShares),
      `Wrong max deposit ${expectedMaxShares} ${maxShares}`
    );
  });
  it("Mint - Calculates assets correctly while minShareRation is set", async function () {
    const signers = await ethers.getSigners();

    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

    const alice = signers[0];

    const assets = ethers.BigNumber.from(5000);
    await asset.transfer(alice.address, assets);
    await asset.connect(alice).increaseAllowance(vault.address, assets);

    const aliceBalanceBefore = await asset.balanceOf(alice.address);

    const shareRatio = await priceOracle.price();

    const shares = fixedPointMul(assets, shareRatio);
    //set minShareRatio
    await vault.connect(alice).setMinShareRatio(shareRatio.sub(1));

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
