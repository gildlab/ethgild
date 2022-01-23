import chai from 'chai'
import { solidity } from 'ethereum-waffle'
import { ethers } from 'hardhat'
import { deployEthGild, getEventArgs, generate1155ID } from './util'
import type { EthGild } from '../typechain/EthGild'

chai.use(solidity)
const { expect, assert } = chai

describe('gild events', async function () {
    it('should emit events on gild and ungild', async function () {
        const signers = await ethers.getSigners()
        const ethGild = await deployEthGild() as EthGild

        const alice = signers[0]

        const [xauDecimals, referencePrice] = await ethGild.referencePrice()

        const ethAmount = 5000

        const id1155 = generate1155ID(referencePrice, xauDecimals)

        const gildTx = await ethGild.gild({ value: ethAmount })

        const gildEventArgs = await getEventArgs(gildTx, 'Gild', ethGild)

        assert(gildEventArgs.sender === alice.address, `incorrect Gild sender. expected ${alice.address} got ${gildEventArgs.sender}`)
        assert(
            gildEventArgs.xauReferencePrice.eq(referencePrice),
            `incorrect Gild reference price. expected ${referencePrice} got ${gildEventArgs.xauReferencePrice}`
        )
        assert(gildEventArgs.ethAmount.eq(ethAmount), `incorrect Gild ethAmount. expected ${ethAmount} got ${gildEventArgs.ethAmount}`)

        const aliceBalance = await ethGild['balanceOf(address)'](alice.address)

        const alice1155BalanceBefore = await ethGild['balanceOf(address,uint256)'](alice.address, id1155)
        assert(aliceBalance.eq(alice1155BalanceBefore), `incorrect balance before. expected ${aliceBalance} got ${alice1155BalanceBefore}`)

        const gildTransferSingleEventArgs = await getEventArgs(gildTx, 'TransferSingle', ethGild)
        assert(gildTransferSingleEventArgs.id.eq(id1155), `incorrect TransferSingle id. expected ${id1155} got ${gildTransferSingleEventArgs.id}`)
        assert(gildTransferSingleEventArgs.value.eq(aliceBalance), `incorrect TransferSingle value. expected ${aliceBalance} got ${gildTransferSingleEventArgs.value}`)

        const gildTransferEventArgs = await getEventArgs(gildTx, 'Transfer', ethGild)
        assert(gildTransferEventArgs.value.eq(aliceBalance), `incorrect Transfer value. expected ${aliceBalance} got ${gildTransferEventArgs.value}`)

        const ungildAmount = aliceBalance.mul(1000).div(1001)
        const ungildTx = await ethGild.ungild(xauDecimals, referencePrice, ungildAmount)

        const ungildEventArgs = await getEventArgs(ungildTx, 'Ungild', ethGild)

        // Ungild ETH is always rounded down.
        const ungildEthAmount = ungildAmount.mul(Math.pow(10, xauDecimals)).div(referencePrice)

        assert(ungildEventArgs.sender === alice.address, `incorrect ungild sender. expected ${alice.address} got ${ungildEventArgs.sender}`)
        assert(ungildEventArgs.xauReferencePrice.eq(referencePrice), `incorrect ungild xauReferencePrice. expected ${referencePrice} got ${ungildEventArgs.xauReferencePrice}`)
        assert(
            ungildEventArgs.ethAmount.eq(ungildEthAmount),
            `wrong ungild amount. expected ${ungildEthAmount} actual ${ungildEventArgs.ethAmount}`
        )

        const alice1155BalanceAfter = await ethGild['balanceOf(address,uint256)'](alice.address, id1155)
        const expected1155BalanceAfter = alice1155BalanceBefore.sub(ungildAmount)
        assert(alice1155BalanceAfter.eq(expected1155BalanceAfter), `incorrect 1155 balance after. expected ${expected1155BalanceAfter} got ${alice1155BalanceAfter}`)
    })
})