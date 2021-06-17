import chai from 'chai'
import { ethers } from 'hardhat'
import type { Ounce } from '../typechain/Ounce'
const { assert } = chai

export const eighteenZeros = '000000000000000000'
export const xauOne = '100000000'

export const deployOunce = async () => {
    const ounceFactory = await ethers.getContractFactory(
        'Ounce'
    )
    const ounce = await ounceFactory.deploy()
    await ounce.deployed()

    return ounce
}

export const vault = async (ounce:Ounce, signer:any, amountEth:any, data:any) => {
    const tx = await signer.sendTransaction({
        to: ounce.address,
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