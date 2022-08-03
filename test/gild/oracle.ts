import chai from "chai";
import { solidity } from "ethereum-waffle";
import { deployERC20PriceOracleVault, expectedReferencePrice } from "../util";

chai.use(solidity);
const { expect, assert } = chai;

describe("oracle", async function () {
  it("should have an oracle", async function () {
    const [_vault, _erc20, priceOracle] = await deployERC20PriceOracleVault();

    const shareRatio = await priceOracle.price();

    assert(
      shareRatio.eq(expectedReferencePrice),
      `wrong shareRatio. got ${shareRatio}. expected ${expectedReferencePrice}`
    );
  });
});
