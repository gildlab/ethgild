import chai from "chai";
import {solidity} from "ethereum-waffle";
import {ethers} from "hardhat";
import {
  deployERC20PriceOracleVault,
} from "../util";
import {ConstructionEvent} from "../../typechain/ERC20PriceOracleVault";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";

import {getEventArgs} from "../util";

let owner: SignerWithAddress

chai.use(solidity);

const {assert} = chai;

describe("config", async function () {
  it("Checks construction event", async function () {
    [owner] = await ethers.getSigners()

    const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();

    const {caller, config} = (await getEventArgs(
      vault.deployTransaction,
      "Construction",
      vault
    )) as ConstructionEvent["args"]

    assert(caller === owner.address, "wrong deploy sender");
    assert(config.asset === asset.address, "wrong asset address");
    assert(config.name === "EthGild", "wrong deploy name");
    assert(config.symbol === "ETHg", "wrong deploy symbol");
    assert(config.uri === "ipfs://bafkreiahuttak2jvjzsd4r62xoxb4e2mhphb66o4cl2ntegnjridtyqnz4", "wrong deploy uri");
    assert(config.priceOracle === priceOracle.address, "wrong deploy priceOracle address");
  })
})
