import chai from 'chai'
import { solidity } from 'ethereum-waffle'
import { ethers } from 'hardhat'
import { deployEthGild } from './util'
import type { EthGild } from '../typechain/EthGild'

chai.use(solidity)
const { expect, assert } = chai

describe('gild events', async function() {
    it('should emit events on gild and ungild', async function() {
        const signers = await ethers.getSigners()
        const ethGild = await deployEthGild() as EthGild

        const alice = signers[0]

        const referencePrice = await ethGild.referencePrice()

        const ethAmount = 50
        await expect(ethGild.gild({value: ethAmount})).to.emit(ethGild, 'Gild').withArgs(
            alice.address,
            referencePrice,
            ethAmount
        )

        const aliceBalance = await ethGild['balanceOf(address)'](alice.address)
        const ungildEthAmount = aliceBalance.div(ethAmount)

        const ungildTx = await ethGild.ungild(referencePrice, ungildEthAmount)

        await expect(ungildTx).to.emit(ethGild, 'Ungild').withArgs(
            alice.address,
            referencePrice,
            ungildEthAmount
        )
    })
})