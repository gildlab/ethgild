import chai from 'chai'
import { solidity } from 'ethereum-waffle'
import { ethers } from 'hardhat'
import { deployEthGild, expectedReferencePrice } from './util'
import { EthGild } from '../typechain/EthGild'
import { Oracle } from '../typechain/Oracle'

chai.use(solidity)
const { expect, assert } = chai

describe("oracle", async function() {
    it("should have an oracle", async function() {
        const [ethGild, xauOracle, ethOracle] = await deployEthGild() as [EthGild, Oracle, Oracle]

        const [xauDecimals, referencePrice] = await ethGild.referencePrice()

        assert(xauDecimals == 8, `wrong xauDecimals`)
        assert(referencePrice.eq(expectedReferencePrice), `wrong referencePrice. got ${referencePrice}. expected ${expectedReferencePrice}`)
    })
})