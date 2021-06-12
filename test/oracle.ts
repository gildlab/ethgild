import chai from 'chai'
import { solidity } from 'ethereum-waffle'
import { ethers } from 'hardhat'
import { deployOunce, expectedPrice } from './util'

chai.use(solidity)
const { expect, assert } = chai

describe("oracle", async function() {
    it("should have an oracle", async function() {
        const ounce = await deployOunce()

        const price = await ounce.price()

        assert(price.eq(expectedPrice), `wrong price. got ${price}. expected ${expectedPrice}`)
    })
})