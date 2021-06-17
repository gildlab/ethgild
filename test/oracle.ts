import chai from 'chai'
import { solidity } from 'ethereum-waffle'
import { ethers } from 'hardhat'
import { deployEthGild, expectedPrice } from './util'

chai.use(solidity)
const { expect, assert } = chai

describe("oracle", async function() {
    it("should have an oracle", async function() {
        const ethGild = await deployEthGild()

        const price = await ethGild.price()

        assert(price.eq(expectedPrice), `wrong price. got ${price}. expected ${expectedPrice}`)
    })
})