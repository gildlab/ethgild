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

        const amountAliceEth = ethers.BigNumber.from('100' + eighteenZeros)
        await vault(ounce, alice, amountAliceEth)

        const price = await ounce.price()
        assert(price.eq(expectedPrice), `bad price ${price} ${expectedPrice}`)

        const expectedAliceBalance = expectedPrice.mul(amountAliceEth).div(xauOne)
        const erc20AliceBalance = await ounce['balanceOf(address)'](alice.address)
        assert(erc20AliceBalance.eq(expectedAliceBalance), `wrong ERC20 balance ${erc20AliceBalance} ${expectedAliceBalance}`)

        const bobErc20Balance = await ounce['balanceOf(address)'](bob.address)
        assert(bobErc20Balance.eq(0), `wrong bob erc20 balance ${bobErc20Balance} 0`)

        const erc1155Balance = await ounce['balanceOf(address,uint256)'](alice.address, price)
        assert(erc1155Balance.eq(expectedAliceBalance), `wrong erc1155 balance ${erc1155Balance} ${expectedAliceBalance}`)

        const bobErc1155Balance = await ounce['balanceOf(address,uint256)'](bob.address, price)
        assert(bobErc1155Balance.eq(0), `wrong bob erc1155 balance ${bobErc1155Balance} 0`)

        await assertError(
            async () => await aliceOunce.unvault(price, amountAliceEth),
            'burn amount exceeds balance',
            'failed to apply fee to unvault'
        )

        const amountBobEth = ethers.BigNumber.from('10' + eighteenZeros)
        await vault(ounce, bob, amountBobEth)

        const expectedBobBalance = expectedPrice.mul(amountBobEth).div(xauOne)
        const erc20BobBalance = await ounce['balanceOf(address)'](bob.address)
        assert(erc20BobBalance.eq(expectedBobBalance), `wrong bob erc20 balance ${erc20BobBalance} ${expectedBobBalance}`)

        const erc1155BobBalance = await ounce['balanceOf(address,uint256)'](bob.address, price)
        assert(erc1155BobBalance.eq(expectedBobBalance), `wrong bob erc1155 balance ${erc1155BobBalance} ${expectedBobBalance}`)

        const bobToAliceEth = erc20AliceBalance.mul(1001).div(1000).sub(erc20AliceBalance)
        await bobOunce.transfer(alice.address, bobToAliceEth)

        await assertError(
            async () => await aliceOunce.unvault(price.sub(1), amountAliceEth),
            'burn amount exceeds balance',
            'failed to prevent vault price manipulation'
        )

        await aliceOunce.unvault(price, amountAliceEth)
        const erc20AliceBalanceUnvault = await ounce['balanceOf(address)'](alice.address)
        assert(erc20AliceBalanceUnvault.eq(0), `wrong alice balance after unvault ${erc20AliceBalanceUnvault} 0`)
    })
})