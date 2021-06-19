import chai from 'chai'
import { solidity } from 'ethereum-waffle'
import { ethers } from 'hardhat'
import { deployEthGild, expectedReferencePrice } from './util'

chai.use(solidity)
const { expect, assert } = chai

describe("oracle", async function() {
    it("should have an oracle", async function() {
        const ethGild = await deployEthGild()

        const referencePrice = await ethGild.referencePrice()

        assert(referencePrice.eq(expectedReferencePrice), `wrong referencePrice. got ${referencePrice}. expected ${expectedReferencePrice}`)
    })
})