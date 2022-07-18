import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import {
  assertError,
  deployERC20PriceOracleVault,
  fixedPointDiv,
  fixedPointMul,
  expectedReferencePrice,
} from "../util";

chai.use(solidity);

const { assert } = chai;

describe("Mint", async function () {
  it("Sets maxShares correctly", async function () {
    const signers = await ethers.getSigners();
    const owner = signers[0];

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
  });
  it("Checks min share ratio is less than share ratio", async function () {
    const [vault, _, priceOracle] = await deployERC20PriceOracleVault();
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
  });
  it("PreviewMint - Calculates assets correctly with round up", async function () {
    const [vault, _, priceOracle] = await deployERC20PriceOracleVault();
    const price = await priceOracle.price();

    assert(
      price.eq(expectedReferencePrice),
      `Incorrect referencePrice ${price} ${expectedReferencePrice}`
    );

    const shares = ethers.BigNumber.from("10").pow(20);
    const expectedAssets = fixedPointDiv(shares, price).add(1);

    const assets = await vault.previewMint(shares);

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

    const price = await priceOracle.price();

    const shares = fixedPointMul(assets, price);

    await vault.connect(alice)["mint(uint256,address)"](shares, alice.address);

    const expectedAssets = fixedPointDiv(shares, price).add(1);

    const aliceBalanceAfter = await asset.balanceOf(alice.address);
    const aliceBalanceDiff = aliceBalanceBefore.sub(aliceBalanceAfter);

    assert(
      aliceBalanceDiff.eq(expectedAssets),
      `wrong alice assets ${expectedAssets} ${aliceBalanceDiff}`
    );
  });
});
