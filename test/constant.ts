import chai from 'chai'
import { solidity } from 'ethereum-waffle'
import { deployEthGild } from './util'

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
        const chainlinkXauUsd = await ethGild.CHAINLINK_XAUUSD()
        const chainlinkEthUsd = await ethGild.CHAINLINK_ETHUSD()
        const decimals = await ethGild.decimals()

        assert(name === 'EthGild', 'wrong name')
        assert(symbol === 'ETHg', 'wrong symbol')
        assert(gildUri === 'https://ethgild.crypto/#/id/{id}', 'wrong uri')
        assert(overburnNumerator.eq(1001), 'wrong fee numerator')
        assert(overburnDenominator.eq(1000), 'wrong fee denominator')
        assert(xauDecimals.eq(8), 'wrong xau decimals')
        assert(chainlinkXauUsd === '0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6', 'wrong chainlink xau oracle')
        assert(chainlinkEthUsd === '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419', 'wrong chainlink eth oracle')
        assert(decimals === 18, 'wrong decimals')
    })

})