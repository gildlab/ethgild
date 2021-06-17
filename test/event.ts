import chai from 'chai'
import { solidity } from 'ethereum-waffle'
import { ethers } from 'hardhat'
import { deployOunce } from './util'
import type { Ounce } from '../typechain/Ounce'

chai.use(solidity)
const { expect, assert } = chai

describe('vault events', async function() {
    it('should emit events on receive', async function() {
        const signers = await ethers.getSigners()
        const ounce = await deployOunce() as Ounce

        const alice = signers[0]

        const price = await ounce.price()

        const ethAmount = 50
        const vaultTx = await alice.sendTransaction({
            to: ounce.address,
            value: ethAmount,
        })

        await expect(vaultTx).to.emit(ounce, 'Vault').withArgs(
            alice.address,
            price,
            ethAmount
        )

        const aliceBalance = await ounce['balanceOf(address)'](alice.address)
        const unvaultEthAmount = aliceBalance.div(ethAmount)

        const unvaultTx = await ounce.unvault(price, unvaultEthAmount)

        await expect(unvaultTx).to.emit(ounce, 'Unvault').withArgs(
            alice.address,
            price,
            unvaultEthAmount
        )
    })

    it('should emit Vault events on fallback', async function() {
        const signers = await ethers.getSigners()
        const ounce = await deployOunce() as Ounce

        const alice = signers[0]

        const price = await ounce.price()

        const ethAmount = 20
        // When data is sent with the transaction `fallback` will be called instead of `receive`.
        const data = "0x00"
        const vaultTx = await alice.sendTransaction({
            to: ounce.address,
            value: ethAmount,
            data,
        })

        await expect(vaultTx).to.emit(ounce, 'Vault').withArgs(
            alice.address,
            price,
            ethAmount
        )
    })
})