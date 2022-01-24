import chai from 'chai'
import { solidity } from 'ethereum-waffle'
import { ethers } from 'hardhat'
import { deployEthGild, expectedReferencePrice, assertError, eighteenZeros, xauOne, generate1155ID } from './util'
import type { EthGild } from '../typechain/EthGild'
import type { Oracle } from '../typechain/Oracle'

chai.use(solidity)
const { expect, assert } = chai

describe("gild", async function() {
    it('should not zero gild', async function() {
        const [ethGild, xauOracle, ethOracle] = await deployEthGild() as [EthGild, Oracle, Oracle]

        await assertError(
            async () => await ethGild.gild(),
            'revert MIN_GILD',
            'failed to prevent a zero value gild'
        )
    })

    it('should gild a sensible reference price', async function() {
        // At the time of writing
        // Block number: 12666285
        //
        // Trading View ETHUSD: 2218.71
        // Chainlink ETHUSD (8 decimals): 2228 25543758
        //
        // Trading View XAUUSD: 1763.95
        // Chainlink XAUUSD (8 decimals): 1767 15500000
        //
        // ~ 1 ETH should buy 1.26092812321 XAU

        const signers = await ethers.getSigners()
        const [ethGild, xauOracle, ethOracle] = await deployEthGild() as [EthGild, Oracle, Oracle]

        const alice = signers[0]

        const aliceEthGild = ethGild.connect(alice)

        const aliceEthAmount = ethers.BigNumber.from('1' + eighteenZeros)
        await aliceEthGild.gild({value: aliceEthAmount})

        // XAU to 8 decimal places (from oracle) with 18 decimals (as erc20 standard).
        const expectedEthG = '1172500000000000000';
        const aliceEthG = await aliceEthGild['balanceOf(address)'](alice.address)
        assert(
            aliceEthG.eq(expectedEthG),
            `wrong alice ETHg ${expectedEthG} ${aliceEthG}`
        )
    })

    it('should gild', async function() {
        const signers = await ethers.getSigners()
        const [ethGild, xauOracle, ethOracle] = await deployEthGild() as [EthGild, Oracle, Oracle]

        const alice = signers[0]
        const bob = signers[1]

        const aliceEthGild = ethGild.connect(alice)
        const bobEthGild = ethGild.connect(bob)

        const [xauDecimals, referencePrice] = await ethGild.referencePrice()
        const id1155 = generate1155ID(referencePrice, xauDecimals)
        assert(referencePrice.eq(expectedReferencePrice), `bad referencePrice ${referencePrice} ${expectedReferencePrice}`)

        const aliceEthAmount = ethers.BigNumber.from('100' + eighteenZeros)
        await aliceEthGild.gild({value: aliceEthAmount})

        const expectedAliceBalance = expectedReferencePrice.mul(aliceEthAmount).div(xauOne)
        const ethgAliceBalance = await ethGild['balanceOf(address)'](alice.address)
        assert(ethgAliceBalance.eq(expectedAliceBalance), `wrong ERC20 balance ${ethgAliceBalance} ${expectedAliceBalance}`)

        const bobErc20Balance = await ethGild['balanceOf(address)'](bob.address)
        assert(bobErc20Balance.eq(0), `wrong bob erc20 balance ${bobErc20Balance} 0`)

        const erc1155Balance = await ethGild['balanceOf(address,uint256)'](alice.address, id1155)
        assert(erc1155Balance.eq(expectedAliceBalance), `wrong erc1155 balance ${erc1155Balance} ${expectedAliceBalance}`)

        const bobErc1155Balance = await ethGild['balanceOf(address,uint256)'](bob.address, id1155)
        assert(bobErc1155Balance.eq(0), `wrong bob erc1155 balance ${bobErc1155Balance} 0`)

        await assertError(
            async () => await aliceEthGild.ungild(xauDecimals, referencePrice, erc1155Balance),
            'burn amount exceeds balance',
            'failed to apply fee to ungild'
        )

        const bobEthAmount = ethers.BigNumber.from('10' + eighteenZeros)
        await bobEthGild.gild({value: bobEthAmount})

        const expectedBobBalance = expectedReferencePrice.mul(bobEthAmount).div(xauOne)
        const ethgBobBalance = await ethGild['balanceOf(address)'](bob.address)
        assert(ethgBobBalance.eq(expectedBobBalance), `wrong bob erc20 balance ${ethgBobBalance} ${expectedBobBalance}`)

        const erc1155BobBalance = await ethGild['balanceOf(address,uint256)'](bob.address, id1155)
        assert(erc1155BobBalance.eq(expectedBobBalance), `wrong bob erc1155 balance ${erc1155BobBalance} ${expectedBobBalance}`)

        const bobToAliceEthg = ethgAliceBalance.mul(1001).div(1000).sub(ethgAliceBalance).sub(1)
        await bobEthGild.transfer(alice.address, bobToAliceEthg)

        // alice cannot withdraw a different referencePrice gild.
        await assertError(
            async () => await aliceEthGild.ungild(xauDecimals, referencePrice.sub(1), 1000),
            'burn amount exceeds balance',
            'failed to prevent gild referencePrice manipulation'
        )

        // alice cannot withdraw with less than the overburn erc20
        await assertError(
            async () => await aliceEthGild.ungild(xauDecimals, id1155, erc1155Balance),
            'burn amount exceeds balance',
            'failed to overburn'
        )

        await bobEthGild.transfer(alice.address, 1)

        await aliceEthGild.ungild(xauDecimals, referencePrice, erc1155Balance)
        const erc20AliceBalanceUngild = await ethGild['balanceOf(address)'](alice.address)
        assert(erc20AliceBalanceUngild.eq(0), `wrong alice erc20 balance after ungild ${erc20AliceBalanceUngild} 0`)

        const erc1155AliceBalanceUngild = await ethGild['balanceOf(address,uint256)'](alice.address, id1155)
        assert(erc1155AliceBalanceUngild.eq(0), `wrong alice erc1155 balance after ungild ${erc1155AliceBalanceUngild} 0`)
    })

    it('should trade erc1155', async function() {
        const signers = await ethers.getSigners()
        const [ethGild, xauOracle, ethOracle] = await deployEthGild() as [EthGild, Oracle, Oracle]

        const alice = signers[0]
        const bob = signers[1]

        const aliceEthGild = ethGild.connect(alice)
        const bobEthGild = ethGild.connect(bob)

        const [xauDecimals, referencePrice] = await ethGild.referencePrice()
        const id1155 = generate1155ID(referencePrice, xauDecimals)

        const aliceEthAmount = ethers.BigNumber.from('10' + eighteenZeros)
        const bobEthAmount = ethers.BigNumber.from('9' + eighteenZeros)

        await aliceEthGild.gild({value: aliceEthAmount})

        const aliceBalance = await ethGild['balanceOf(address)'](alice.address)
        // erc1155 transfer.
        await aliceEthGild.safeTransferFrom(alice.address, bob.address, id1155, aliceBalance, [])

        // alice cannot withdraw after sending to bob.
        await assertError(
            async () => await aliceEthGild.ungild(xauDecimals, referencePrice, 1000),
            'burn amount exceeds balance',
            'failed to prevent alice withdrawing after sending erc1155'
        )

        // bob cannot withdraw without erc20
        await assertError(
            async () => await bobEthGild.ungild(xauDecimals, referencePrice, 1000),
            'burn amount exceeds balance',
            'failed to prevent bob withdrawing without receiving erc20'
        )

        // erc20 transfer.
        await aliceEthGild.transfer(bob.address, aliceBalance)

        await assertError(
            async () => await aliceEthGild.ungild(xauDecimals, referencePrice, 1000),
            'burn amount exceeds balance',
            'failed to prevent alice withdrawing after sending erc1155 and erc20'
        )

        // bob can withdraw now
        const bobEthBefore = await bob.getBalance()
        const erc1155BobBalance = await ethGild['balanceOf(address,uint256)'](bob.address, id1155)
        const bobUngildTx = await bobEthGild.ungild(xauDecimals, referencePrice, erc1155BobBalance.mul(1000).div(1001))
        const bobUngildTxReceipt = await bobUngildTx.wait()
        const erc1155BobBalanceAfter = await ethGild['balanceOf(address,uint256)'](bob.address, id1155)
        const bobEthAfter = await bob.getBalance()
        const bobEthDiff = bobEthAfter.sub(bobEthBefore)
        // Bob withdraw alice's gilded eth
        const bobEthDiffExpected = aliceEthAmount.mul(1000).div(1001).sub(bobUngildTxReceipt.gasUsed.mul(bobUngildTx.gasPrice))
        assert(bobEthAfter.sub(bobEthBefore).eq(bobEthDiffExpected), `wrong bob diff ${bobEthDiffExpected} ${bobEthDiff}`)
    })
})