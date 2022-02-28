import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";

chai.use(solidity);
const { assert } = chai;

export const expectedReferencePrice = ethers.BigNumber.from(
  "1391466971980534617"
);


describe("construction", async function () {


  it("should set reference price", async function () {

    //etherium data feed chainlink oracles of rinkeby testnet

    const chainlinkXauUsd = "0x81570059A0cb83888f1459Ec66Aad1Ac16730243";
    const chainlinkEthUsd = "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e";
  
    const chainlinkTwoFeedPriceOracleFactory = await ethers.getContractFactory(
        "ChainlinkTwoFeedPriceOracle"
      );
  
    const chainlinkTwoFeedPriceOracle =
    await chainlinkTwoFeedPriceOracleFactory.deploy({
      base: chainlinkEthUsd,
      quote: chainlinkXauUsd,
    });
    await chainlinkTwoFeedPriceOracle.deployed();
  
    const expectedPrice = await chainlinkTwoFeedPriceOracle.price();

    assert(
      expectedPrice.eq(expectedReferencePrice),
      `wrong price ${expectedReferencePrice} ${expectedPrice}`
    );
  });


});
