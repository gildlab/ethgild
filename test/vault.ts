import chai from 'chai'
import { solidity } from 'ethereum-waffle'
import { ethers } from 'hardhat'
import { deployOunce, expectedPrice, assertError, vault, eighteenZeros, xauOne } from './util'
import type { Ounce } from '../typechain/Ounce'

chai.use(solidity)
const { expect, assert } = chai

describe("vault", async function() {
    it('should vault', async function() {
        const signers = await ethers.getSigners()
        const ounce = await deployOunce() as Ounce

        const alice = signers[0]
        const bob = signers[1]

        const aliceOunce = ounce.connect(alice)
        const bobOunce = ounce.connect(bob)

        const price = await ounce.price()
        assert(price.eq(expectedPrice), `bad price ${price} ${expectedPrice}`)

        const aliceEthAmount = ethers.BigNumber.from('100' + eighteenZeros)
        await vault(ounce, alice, aliceEthAmount, [])

        const expectedAliceBalance = expectedPrice.mul(aliceEthAmount).div(xauOne)
        const erc20AliceBalance = await ounce['balanceOf(address)'](alice.address)
        assert(erc20AliceBalance.eq(expectedAliceBalance), `wrong ERC20 balance ${erc20AliceBalance} ${expectedAliceBalance}`)

        const bobErc20Balance = await ounce['balanceOf(address)'](bob.address)
        assert(bobErc20Balance.eq(0), `wrong bob erc20 balance ${bobErc20Balance} 0`)

        const erc1155Balance = await ounce['balanceOf(address,uint256)'](alice.address, price)
        assert(erc1155Balance.eq(expectedAliceBalance), `wrong erc1155 balance ${erc1155Balance} ${expectedAliceBalance}`)

        const bobErc1155Balance = await ounce['balanceOf(address,uint256)'](bob.address, price)
        assert(bobErc1155Balance.eq(0), `wrong bob erc1155 balance ${bobErc1155Balance} 0`)

        await assertError(
            async () => await aliceOunce.unvault(price, aliceEthAmount),
            'burn amount exceeds balance',
            'failed to apply fee to unvault'
        )

        const bobEthAmount = ethers.BigNumber.from('10' + eighteenZeros)
        await vault(ounce, bob, bobEthAmount, [])

        const expectedBobBalance = expectedPrice.mul(bobEthAmount).div(xauOne)
        const erc20BobBalance = await ounce['balanceOf(address)'](bob.address)
        assert(erc20BobBalance.eq(expectedBobBalance), `wrong bob erc20 balance ${erc20BobBalance} ${expectedBobBalance}`)

        const erc1155BobBalance = await ounce['balanceOf(address,uint256)'](bob.address, price)
        assert(erc1155BobBalance.eq(expectedBobBalance), `wrong bob erc1155 balance ${erc1155BobBalance} ${expectedBobBalance}`)

        const bobToAliceEth = erc20AliceBalance.mul(1001).div(1000).sub(erc20AliceBalance)
        await bobOunce.transfer(alice.address, bobToAliceEth)

        // alice cannot withdraw a different price vault.
        await assertError(
            async () => await aliceOunce.unvault(price.sub(1), aliceEthAmount),
            'burn amount exceeds balance',
            'failed to prevent vault price manipulation'
        )

        await aliceOunce.unvault(price, aliceEthAmount)
        const erc20AliceBalanceUnvault = await ounce['balanceOf(address)'](alice.address)
        assert(erc20AliceBalanceUnvault.eq(0), `wrong alice balance after unvault ${erc20AliceBalanceUnvault} 0`)
    })

    it('should trade erc1155', async function() {
        const signers = await ethers.getSigners()
        const ounce = await deployOunce() as Ounce

        const alice = signers[0]
        const bob = signers[1]

        const aliceOunce = ounce.connect(alice)
        const bobOunce = ounce.connect(bob)

        const price = await ounce.price()

        const aliceEthAmount = ethers.BigNumber.from('10' + eighteenZeros)
        const bobEthAmount = ethers.BigNumber.from('9' + eighteenZeros)

        await vault(ounce, alice, aliceEthAmount, [])

        const aliceBalance = await ounce['balanceOf(address)'](alice.address)
        // erc1155 transfer.
        await aliceOunce.safeTransferFrom(alice.address, bob.address, price, aliceBalance, [])

        // alice cannot withdraw after sending to bob.
        await assertError(
            async () => await aliceOunce.unvault(price, 1),
            'burn amount exceeds balance',
            'failed to prevent alice withdrawing after sending erc1155'
        )

        // bob cannot withdraw without erc20
        await assertError(
            async () => await bobOunce.unvault(price, bobEthAmount),
            'burn amount exceeds balance',
            'failed to prevent bob withdrawing without receiving erc20'
        )

        // erc20 transfer.
        await aliceOunce.transfer(bob.address, aliceBalance)

        await assertError(
            async () => await aliceOunce.unvault(price, 1),
            'burn amount exceeds balance',
            'failed to prevent alice withdrawing after sending erc1155 and erc20'
        )

        // bob can withdraw now
        const bobEthBefore = await bob.getBalance()
        const bobUnvaultTx = await bobOunce.unvault(price, bobEthAmount)
        console.log(bobUnvaultTx)
        const bobUnvaultTxReceipt = await bobUnvaultTx.wait()
        console.log(bobUnvaultTxReceipt)
        const bobEthAfter = await bob.getBalance()
        const bobEthDiff = bobEthAfter.sub(bobEthBefore)
        const bobEthDiffExpected = bobEthAmount.sub(bobUnvaultTxReceipt.cumulativeGasUsed)
        assert(bobEthAfter.sub(bobEthBefore).eq(bobEthDiffExpected), `wrong bob diff ${bobEthDiffExpected} ${bobEthDiff}`)
    })
})