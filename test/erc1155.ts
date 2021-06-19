import chai from 'chai'
import { solidity } from 'ethereum-waffle'
import { ethers } from 'hardhat'
import { deployEthGild, expectedUri } from './util'
import type { EthGild } from '../typechain/EthGild'

chai.use(solidity)
const { expect, assert }  = chai

describe('erc1155 usage', async function() {
    it('should construct well', async function() {
        const ethGild = await deployEthGild() as EthGild

        const id = 12345

        const erc1155Uri = await ethGild.uri(id)

        assert(erc1155Uri === expectedUri, 'erc1155 did not construct with correct uri')
    })
})