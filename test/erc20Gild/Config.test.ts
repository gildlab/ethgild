import chai from "chai";
import { solidity } from "ethereum-waffle";
import { ethers } from "hardhat";
import {
  deployERC20PriceOracleVault,
  expectedName,
  expectedSymbol,
  expectedUri,
} from "../util";
import { ERC20PriceOracleVaultConstructionEvent } from "../../typechain/ERC20PriceOracleVault";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { getEventArgs } from "../util";

let owner: SignerWithAddress;

chai.use(solidity);

const { assert } = chai;

describe("config", async function () {
  it("Checks construction event", async function () {
    [owner] = await ethers.getSigners();

    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

    const { caller, config } = (await getEventArgs(
      vault.deployTransaction,
      "ERC20PriceOracleVaultConstruction",
      vault
    )) as ERC20PriceOracleVaultConstructionEvent["args"];

    assert(caller === owner.address, "wrong deploy sender");
    assert(
      config.receiptVaultConfig.asset === asset.address,
      "wrong asset address"
    );
    assert(
      config.receiptVaultConfig.name === expectedName,
      "wrong deploy name"
    );
    assert(
      config.receiptVaultConfig.symbol === expectedSymbol,
      "wrong deploy symbol"
    );
    assert(config.receiptVaultConfig.uri === expectedUri);
    assert(
      config.priceOracle === priceOracle.address,
      "wrong deploy priceOracle address"
    );
  });
});
