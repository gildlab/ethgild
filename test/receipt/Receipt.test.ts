import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import { fixedPointDiv, fixedPointMul, ONE } from "../util";
import { deployOffChainAssetVault } from "../offchainAsset/deployOffchainAssetVault";
import { TestErc20 } from "../../typechain";

chai.use(solidity);

const { assert } = chai;

describe("Receipt vault", async function () {
  it("Mints with data", async function () {
    const [vault, receipt] = await deployOffChainAssetVault();
    const signers = await ethers.getSigners();
    const alice = signers[0];

    const testErc20 = await ethers.getContractFactory("TestErc20");
    const asset = (await testErc20.deploy()) as TestErc20;
    await asset.deployed();

    await vault
      .connect(alice)
      .grantRole(await vault.connect(alice).DEPOSITOR(), alice.address);

    const assets = ethers.BigNumber.from(5000);
    await asset.transfer(alice.address, assets);
    await asset.connect(alice).increaseAllowance(vault.address, assets);

    const shares = fixedPointMul(assets, ONE).add(1);

    await vault
      .connect(alice)
      ["mint(uint256,address,uint256,bytes)"](shares, alice.address, ONE, [1]);

    // const expectedAssets = fixedPointDiv(shares,ONE)
    // const aliceBalanceAfter = await receipt
    //     .connect(alice)
    //     ["balanceOf(address,uint256)"](alice.address, 1);
    //
    // assert(
    //     aliceBalanceAfter.eq(expectedAssets),
    //     `wrong assets. expected ${expectedAssets} got ${aliceBalanceAfter}`
    // );
  });
});
