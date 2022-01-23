import chai from 'chai'
import { solidity } from 'ethereum-waffle'
import { ethers } from 'hardhat'
import { deployEthGild, expectedReferencePrice, expectedUri, expected1155ID } from './util'
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

    it('should only send itself', async function() {
        const signers = await ethers.getSigners()

        const ethGild = await deployEthGild() as EthGild

        await ethGild.gild({value: 1000})

        const expectedErc20Balance = ethers.BigNumber.from('1260')
        const expectedErc20BalanceAfter = ethers.BigNumber.from('1260')
        const expectedErc1155Balance = ethers.BigNumber.from('1260')
        const expectedErc1155BalanceAfter = ethers.BigNumber.from('630')

        const erc20Balance = await ethGild['balanceOf(address)'](signers[0].address)
        assert(
            erc20Balance.eq(expectedErc20Balance),
            `wrong erc20 balance ${expectedErc20Balance} ${erc20Balance}`
        )

        const erc1155Balance = await ethGild['balanceOf(address,uint256)'](signers[0].address, expected1155ID)
        assert(
            erc1155Balance.eq(expectedErc1155Balance),
            `wrong erc1155 balance ${expectedErc20Balance} ${erc1155Balance}`
        )

        await ethGild.safeTransferFrom(signers[0].address, signers[1].address, expected1155ID, '630', [])

        const erc20BalanceAfter = await ethGild['balanceOf(address)'](signers[0].address)
        assert(
            erc20BalanceAfter.eq(expectedErc20BalanceAfter),
            `wrong erc20 balance after ${expectedErc20BalanceAfter} ${erc20BalanceAfter}`
        )

        const erc20BalanceAfter2 = await ethGild['balanceOf(address)'](signers[1].address)
        assert(
            erc20BalanceAfter2.eq(0),
            `wrong erc20 balance after 2 0 ${erc20BalanceAfter2}`
        )

        const erc1155BalanceAfter = await ethGild['balanceOf(address,uint256)'](signers[0].address, expected1155ID)
        assert(
            erc1155BalanceAfter.eq(expectedErc1155BalanceAfter),
            `wrong erc1155 balance after ${expectedErc1155BalanceAfter} ${erc1155BalanceAfter}`
        )

        const erc1155BalanceAfter2 = await ethGild['balanceOf(address,uint256)'](signers[1].address, expected1155ID)
        assert(
            erc1155BalanceAfter2.eq(expectedErc1155BalanceAfter),
            `wrong erc1155 balance 2 after ${expectedErc1155BalanceAfter} ${erc1155BalanceAfter2}`
        )
    })
})