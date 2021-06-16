import chai from 'chai'
import { solidity } from 'ethereum-waffle'
import { deployOunce } from './util'

chai.use(solidity)
const { assert } = chai

describe("constants", async function() {
    it('should have correct constants', async function() {
        const ounce = await deployOunce()

        const name = await ounce.NAME()
        const symbol = await ounce.SYMBOL()
        const vaultUri = await ounce.VAULT_URI()
        const overburnNumerator = await ounce.ERC20_OVERBURN_NUMERATOR()
        const overburnDenominator = await ounce.ERC20_OVERBURN_DENOMINATOR()
        const xauDecimals = await ounce.XAU_DECIMALS()
        const chainlinkXauUsd = await ounce.CHAINLINK_XAUUSD()
        const chainlinkEthUsd = await ounce.CHAINLINK_ETHUSD()
        const decimals = await ounce.decimals()

        assert(name === 'ounce', 'wrong name')
        assert(symbol === 'oXAU', 'wrong symbol')
        assert(vaultUri === 'https://oxau.crypto/{id}', 'wrong uri')
        assert(overburnNumerator.eq(1001), 'wrong fee numerator')
        assert(overburnDenominator.eq(1000), 'wrong fee denominator')
        assert(xauDecimals.eq(8), 'wrong xau decimals')
        assert(chainlinkXauUsd === '0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6', 'wrong chainlink xau oracle')
        assert(chainlinkEthUsd === '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419', 'wrong chainlink eth oracle')
        assert(decimals === 18, 'wrong decimals')
    })

})