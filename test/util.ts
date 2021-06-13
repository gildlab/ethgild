import chai from 'chai'
import { ethers } from 'hardhat'
import type { Ounce } from '../typechain/Ounce'
const { assert } = chai

export const deployOunce = async () => {
    const ounceFactory = await ethers.getContractFactory(
        'Ounce'
    )
    const ounce = await ounceFactory.deploy()
    await ounce.deployed()

    return ounce
}

export const vault = async (ounce:Ounce, signer:any, amountEth:any) => {
    const tx = await signer.sendTransaction({
        to: ounce.address,
        value: amountEth
    })
    tx.wait()
}
console.log(ethers)
export const expectedPrice = ethers.BigNumber.from('129872166')

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