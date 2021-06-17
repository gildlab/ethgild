import chai from 'chai'
import { ethers } from 'hardhat'
import type { EthGild } from '../typechain/EthGild'
const { assert } = chai

export const eighteenZeros = '000000000000000000'
export const xauOne = '100000000'

export const deployEthGild = async () => {
    const ethGildFactory = await ethers.getContractFactory(
        'EthGild'
    )
    const ethGild = await ethGildFactory.deploy()
    await ethGild.deployed()

    return ethGild
}

export const gild = async (ethGild:EthGild, signer:any, amountEth:any, data:any) => {
    const tx = await signer.sendTransaction({
        to: ethGild.address,
        value: amountEth,
        data: data
    })
    await tx.wait()
}
export const expectedPrice = ethers.BigNumber.from('135299829')

export const assertError = async (f:Function, s:string, e:string) => {
    let didError = false
    try {
        await f()
    } catch (e) {
        assert(e.toString().includes(s), `error string ${e} does not include ${s}`)
        didError = true
    }
    assert(didError, e)
  }