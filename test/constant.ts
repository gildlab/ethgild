import chai from 'chai'
import { solidity } from 'ethereum-waffle'
import { chainlinkXauUsd, chainlinkEthUsd, deployEthGild, expectedName, expectedSymbol, expectedUri } from './util'

chai.use(solidity)
const { assert } = chai

describe("constants", async function() {
    it('should have correct constants', async function() {
        const ethGild = await deployEthGild()

        const name = await ethGild.NAME()
        const symbol = await ethGild.SYMBOL()
        const gildUri = await ethGild.GILD_URI()
        const overburnNumerator = await ethGild.ERC20_OVERBURN_NUMERATOR()
        const overburnDenominator = await ethGild.ERC20_OVERBURN_DENOMINATOR()
        const xauDecimals = await ethGild.XAU_DECIMALS()
        const chainlinkXauUsdResult = await ethGild.chainlinkXauUsd()
        const chainlinkEthUsdResult = await ethGild.chainlinkEthUsd()
        const decimals = await ethGild.decimals()

        assert(name === expectedName, 'wrong name')
        assert(symbol === expectedSymbol, 'wrong symbol')
        assert(gildUri === expectedUri, 'wrong uri')
        assert(overburnNumerator.eq(1001), 'wrong fee numerator')
        assert(overburnDenominator.eq(1000), 'wrong fee denominator')
        assert(xauDecimals.eq(8), 'wrong xau decimals')
        assert(chainlinkXauUsdResult === chainlinkXauUsd, 'wrong chainlink xau oracle')
        assert(chainlinkEthUsdResult === chainlinkEthUsd, 'wrong chainlink eth oracle')
        assert(decimals === 18, 'wrong decimals')
    })

})