import chai from 'chai'
import { solidity } from 'ethereum-waffle'
import { ethers } from 'hardhat'
import { deployEthGild, assertError, expectedReferencePrice, expected1155ID } from './util'
import type { EthGild } from '../typechain/EthGild'
import type { TestReentrant } from '../typechain/TestReentrant'

chai.use(solidity)
const { expect, assert } = chai

describe('reentrant behaviour', async function() {
    it('should receive and erc1155 receive', async function() {
        const ethGild = await deployEthGild() as EthGild

        const ethAmount = 100000

        const testReentrantFactory = await ethers.getContractFactory('TestReentrant')
        const testReentrant = await testReentrantFactory.deploy()
        await testReentrant.deployed()

        await testReentrant.gild(ethGild.address, {value: ethAmount})

        const didRecievePayable = await testReentrant.didReceivePayable()
        assert(didRecievePayable, 'did not receive payable')

        const erc1155ReceivedId = await testReentrant.erc1155Received(0)
        const erc1155ReceivedValue = await testReentrant.erc1155Received(1)

        assert(erc1155ReceivedId.eq(expected1155ID), 'wrong ID')

        const expectedValue = expectedReferencePrice.mul(ethAmount).div(100000000).div(2)
        assert(erc1155ReceivedValue.eq(expectedValue), `wrong received value ${expectedValue} ${erc1155ReceivedValue}`)
    })

    it('should error low value reentrant ungild', async function() {
        const ethGild = await deployEthGild() as EthGild

        const testReentrantFactory = await ethers.getContractFactory('TestReentrant')
        const testReentrant = await testReentrantFactory.deploy()
        await testReentrant.deployed()

        await testReentrant.gild(ethGild.address, {value: 2000})

        await assertError(
            async () => await testReentrant.lowValueUngild(ethGild.address, expectedReferencePrice),
            'revert UNGILD_ETH',
            'failed to revert an error in ungild receive',
        )
    })

    it('should error low value reentrant gild', async function() {
        const ethGild = await deployEthGild() as EthGild

        const testReentrantFactory = await ethers.getContractFactory('TestReentrant')
        const testReentrant = await testReentrantFactory.deploy()
        await testReentrant.deployed()

        await assertError(
            async () => await testReentrant.gild(ethGild.address, {value: 1800}),
            'revert ERC1155: ERC1155Receiver rejected tokens',
            'failed to revert an error in erc1155 receive',
        )
    })
})