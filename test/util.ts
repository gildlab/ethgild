import chai from 'chai'
import { ethers } from 'hardhat'
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

export const expectedReferencePrice = ethers.BigNumber.from('135299829')

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

  export const expectedName = 'EthGild'
  export const expectedSymbol = 'ETHg'
  export const expectedUri = 'https://ethgild.crypto/#/id/{id}'