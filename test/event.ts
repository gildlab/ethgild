import chai from 'chai'
import { solidity } from 'ethereum-waffle'
import { ethers } from 'hardhat'
import { deployEthGild, getEventArgs } from './util'
import type { EthGild } from '../typechain/EthGild'

chai.use(solidity)
const { expect, assert } = chai

describe('gild events', async function() {
    it.only('should emit events on gild and ungild', async function() {
        const signers = await ethers.getSigners()
        const ethGild = await deployEthGild() as EthGild

        const alice = signers[0]

        const referencePrice = await ethGild.referencePrice()

        const ethAmount = 5000

        const gildTx = await ethGild.gild({value: ethAmount})

        const gildEventArgs = await getEventArgs(gildTx, 'Gild', ethGild)

        assert(gildEventArgs.sender === alice.address)
        assert(gildEventArgs.xauReferencePrice.eq(referencePrice))
        assert(gildEventArgs.ethAmount.eq(ethAmount))

        const aliceBalance = await ethGild['balanceOf(address)'](alice.address)

        const alice1155BalanceBefore = await ethGild['balanceOf(address,uint256)'](alice.address, referencePrice)
        console.log(alice1155BalanceBefore)
        assert(aliceBalance.eq(alice1155BalanceBefore))

        console.log(referencePrice.toString())

        const gildTransferSingleEventArgs = await getEventArgs(gildTx, 'TransferSingle', ethGild)
        assert(gildTransferSingleEventArgs.id.eq(referencePrice))
        assert(gildTransferSingleEventArgs.value.eq(aliceBalance))

        const gildTransferEventArgs = await getEventArgs(gildTx, 'Transfer', ethGild)
        assert(gildTransferEventArgs.value.eq(aliceBalance))

        const ungildAmount = aliceBalance.mul(1000).div(1001)
        const ungildTx = await ethGild.ungild(referencePrice, ungildAmount)

        const ungildEventArgs = await getEventArgs(ungildTx, 'Ungild', ethGild)

        // Ungild ETH is always rounded down.
        const ungildEthAmount = ungildAmount.mul(await ethGild.XAU_DECIMALS_MULTIPLIER()).div(referencePrice)

        console.log(ungildEthAmount.toString())

        assert(ungildEventArgs.sender === alice.address)
        assert(ungildEventArgs.xauReferencePrice.eq(referencePrice))
        assert(
            ungildEventArgs.ethAmount.eq(ungildEthAmount),
            `wrong ungild amount. expected ${ungildEthAmount} actual ${ungildEventArgs.ethAmount}`
        )

        const alice1155BalanceAfter = await ethGild['balanceOf(address,uint256)'](alice.address, referencePrice)
        console.log(alice1155BalanceAfter)
        assert(alice1155BalanceAfter.eq(0))
    })
})