import chai from 'chai'
import { solidity } from 'ethereum-waffle'
import { ethers } from 'hardhat'
import { deployEthGild, expectedName, expectedSymbol } from './util'
import type { EthGild } from '../typechain/EthGild'

chai.use(solidity)
const { expect, assert } = chai

describe('erc20 usage', async function() {
    it('should construct well', async function() {
        const ethGild = await deployEthGild() as EthGild

        const erc20Name = await ethGild.name()
        const erc20Symbol = await ethGild.symbol()

        assert(erc20Name === expectedName, 'erc20 did not construct with correct name')
        assert(erc20Symbol === expectedSymbol, 'erc20 did not construct with correct symbol')
    })
})