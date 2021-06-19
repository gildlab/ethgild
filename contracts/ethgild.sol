// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Chainlink imports.
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// Open Zeppelin imports.
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

/// @title EthGild
/// @author thedavidmeister
///
/// ## Purpose
///
/// Gild: to wrap with gold.
///
/// Not a stablecoin.
/// A wrapped token that wraps/unwraps according to the reference price of gold in ETH.
///
/// Similar to wrapped eth (WETH).
/// WETH "wraps" ETH 1:1 with an erc20 token that can be unwrapped to get the original ETH back.
/// GildEth (ETHg) wraps (gilds) ETH with an erc20 token at the current reference gold price that can be unwrapped to get the original ETH back.
/// The gilding is represented as an NFT (erc1155) owned by the gilder.
/// The NFT owner can ungild ETHg back to ETH at the same rate the ETHg was minted at for that NFT.
/// 0.1% additional ETHg must be burned when it is ungilded (overburn).
/// The overburn locks a tiny sliver of ETH in each gilding to help support growth of an organic ETHg community.
/// Anyone who wants to ungild all their ETH must first acquire a small amount of additional ETHg from a fellow gilder.
/// The heaviest stress on ETHg will likely occur during rapid ETH market price spike and crash cycles.
/// We should expect large amounts of ETHg to be minted by skittish ETH hodlers each time ETH nears an ATH or similar market event.
/// As the market price of ETH crashes with large new ETHg supply, there will be a lot of pressure on ETHg, likely a lot of short term chaos for ETHg.
/// As gild/ungild cycles continue the overburn will soak up the ETHg glut in the medium term.
/// The overburn also guarantees that any "bank run" on ETHg will force the market price upward towards the current reference gold price, incentivising new gildings.
/// Long term the steady increase of locked ETH in the system will cushion future shocks to the ETHg market price as oustanding NFTs represent data points in an emergent "moving average".
/// 0.1% is somewhat arbitrary but is intended to be competetive with typical onchain trades that include fee % + slippage + gas.
/// Hopefully the target audience finds it more compelling to wrap ETH to ETHg than trade their ETH away for stablecoins.
///
/// ## Implementation
///
/// EthGild is both an erc1155 and erc20.
/// All token behaviour is default Open Zeppelin.
/// This works because none of the function names collide, or if they do the signature overloads cleanly (e.g. `_mint`).
///
/// ## Gilding
///
/// Simply send ETH to the contract.
/// `gild` is a private function wrapped by both `receive` and `fallback`.
/// The "reference price" is source from chainlink oracle for internal calculations, nothing is actually bought/sold/traded in a gild.
/// The erc1155 is minted as the current reference price in ETH as its id, and the reference price multiplied by ETH locked as amount (18 decimals).
/// The ETHg erc20 is minted as the reference price multiplied by ETH locked as amount (18 decimals).
/// The ETH amount is calculated as the `msg.value` sent to the `EthGild` contract (excludes gas).
///
/// ## Ungilding
///
/// The erc1155 id (reference price) and amount of ETH to ungild must be specified to the ungild function.
/// The erc1155 under the reference price id is burned as ETH being ungild multiplied by the reference price.
/// The ETHg erc20 is burned as 1001/1000 times the erc1155 burn.
/// The ETH amount is sent to `msg.sender`.
///
/// ## Reentrancy
///
/// The erc20 minting and all burning is not reentrant but the erc1155 mint _is_ reentrant.
/// Both gild and ungild end with reentrant calls to the msg.sender.
/// `gild` will attempt to treat the `msg.sender` as an `IERC1155Receiver`.
/// `ungild` will call the sender's `receive` function when it sends the ungilded ETH.
/// This is safe for the `EthGild` contract state as the reentrant calls are last and allowed to facilitate creative use-cases.
///
/// ## Tokenomics
///
/// - Market price pressure above reference price of 1 ounce of gold.
///   - Exceeding this allows anyone to gild 1 ETH, sell minted ETHg, buy more than 1 ETH, repeat infinitely.
/// - Market price pressure below max recent ETH drawdown.
///   - Exceeding this allows all gilded eth to be ungilded on a market buy of ETHg cheaper than the gilded ETH backing it.
/// - Ranging between two (dynamic) limits.
///   - Gild when market is high to leverage ETH without liquidation threat.
///     - Gild 1 ETH for ~1 ETH of ETHg, sell ETHg for ETH, wait for pump.
///     - Ungild original eth for roughly the starting ETHg price, sell ~2 ETH.
///   - Buy low to anticipate upward "bank runs".
///     - Ultimately every ETHg +0.1% must be burned for ETH to be returned.
///     - ETH should always be more desirable long term than ETHg so eventually the ETHg market will recover.
///     - A "bank run" on ETHg pushes the ETHg market _higher_ as it is burned to ungild ETH.
///   - Use in range as less-volatile proxy to underlying ETH value.
///     - If ETH is uncomfortably high then gild and keep ETHg.
///     - Gilding is NOT a trade so is immune to front-running, counterpary risk and slippage.
///     - Reference price based on gold oracle so avoids fiat risk.
///     - If ETH crashes then ETHg probably will too but ETHg may land softer and recover faster in relative terms.
///   - Use in range for LP on AMM with low IL.
///     - Pair with other gold tokens knowing that ETHg is bounded by gold reference price.
///     - IL is credibly impermanent, or at least mitigated.
///     - All liquidity on AMM is locking ETH in the bonding curve so more liquidity implies tighter market (virtuous cycle).
///     - Should always be baseline supply/demand from leveraging use-case.
///     - Overburn should always tighten the price range as cumulative gild/ungild volume builds over time.
///
/// ## Administration
///
/// - Contract has NO owner or other administrative functions
/// - Contract has NO upgrades
/// - There is NO peg
/// - There is NO DAO
/// - There are NO liquidations
/// - There is NO collateralisation ratio
/// - ETHg is increasingly overcollateralised due to overburn
/// - This is all HIGHLY EXPERIMENTAL and comes with NO WARRANTY
/// - The tokenomics are HIGHLY EXPERIMENTAL and NOT FINANCIAL ADVICE
/// - If this contract is EXPLOITED or contains BUGS
///   - There is NO support or compensation
///   - There MAY be a NEW contract deployed without the exploit/bug
/// - I would LOVE it if you want to build on top of this as a primitive
contract EthGild is ERC1155, ERC20 {
    // Chainlink oracles are signed integers so we need to handle them as unsigned.
    using SafeCast for int256;
    using SafeMath for uint256;

    /// @param caller the address gilding ETH.
    /// @param xauReferencePrice the reference XAU price the ETH was gilded at.
    /// @param ethAmount the amount of ETH gilded.
    event Gild(
        address indexed caller,
        uint256 indexed xauReferencePrice,
        uint256 indexed ethAmount
    );
    /// @param caller the address ungilding ETH.
    /// @param xauReferencePrice the reference XAU price the ETH is ungilded at.
    /// @param ethAmount the amount of ETH ungilded.
    event Ungild(
        address indexed caller,
        uint256 indexed xauReferencePrice,
        uint256 indexed ethAmount
    );

    /// erc20 name.
    string public constant NAME = "EthGild";
    /// erc20 symbol.
    string public constant SYMBOL = "ETHg";
    /// erc1155 uri.
    /// Note the erc1155 id is simply the reference XAU price at which ETHg tokens can burn it to unlock ETH.
    string public constant GILD_URI = "https://ethgild.crypto/#/id/{id}";

    /// erc20 is burned 0.1% faster than erc1155.
    /// This is the numerator for that.
    uint256 public constant ERC20_OVERBURN_NUMERATOR = 1001;
    /// erc20 is burned 0.1% faster than erc1155.
    /// This is the denominator for that.
    uint256 public constant ERC20_OVERBURN_DENOMINATOR = 1000;

    // Chainlink oracles.
    // https://docs.chain.link/docs/ethereum-addresses/
    uint256 public constant XAU_DECIMALS = 8;
    AggregatorV3Interface public constant CHAINLINK_XAUUSD =
        AggregatorV3Interface(0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6);
    AggregatorV3Interface public constant CHAINLINK_ETHUSD =
        AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    constructor() ERC20(NAME, SYMBOL) ERC1155(GILD_URI) {} //solhint-disable no-empty-blocks

    /// Returns a reference XAU price in ETH or reverts.
    /// Internally calls two separate chainlink oracles to factor out the USD price.
    /// Ideally we'd avoid referencing USD even for internal math but chainlink doesn't support that yet.
    /// Having two calls costs extra gas and deriving a reference price from some arbitrary fiat adds no value.
    function referencePrice() public view returns (uint256) {
        (, int256 _xauUsd, , , ) = CHAINLINK_XAUUSD.latestRoundData();
        (, int256 _ethUsd, , , ) = CHAINLINK_ETHUSD.latestRoundData();
        return
            _ethUsd.toUint256().mul(10**XAU_DECIMALS).div(_xauUsd.toUint256());
    }

    /// Overburn ETHg at 1001:1000 ratio to receive initial ETH refund.
    /// If the `msg.sender` does not have _both_ the erc1155 and erc20 balances for a given reference price the ETH will not ungild.
    /// The erc20 and erc1155 amounts as `xauReferencePrice * ethAmount` (+0.1% for erc20) will be burned.
    /// @param xauReferencePrice XAU reference price in ETH. MUST correspond to an erc1155 balance held by `msg.sender`.
    /// @param ethAmount the amount of ETH to ungild.
    function ungild(uint256 xauReferencePrice, uint256 ethAmount) external {
        // Amount of ETHg to burn.
        uint256 _ethgAmount = ethAmount.mul(xauReferencePrice);
        emit Ungild(msg.sender, xauReferencePrice, ethAmount);

        // ETHg erc20 burn.
        // 0.1% more than erc1155 burn.
        // NOT reentrant.
        _burn(
            msg.sender,
            _ethgAmount
                .mul(ERC20_OVERBURN_NUMERATOR)
                .div(ERC20_OVERBURN_DENOMINATOR)
                .div(10**XAU_DECIMALS)
        );

        // erc1155 burn.
        // NOT reentrant (doesn't trigger `IERC1155Receiver`).
        _burn(msg.sender, xauReferencePrice, _ethgAmount.div(10**XAU_DECIMALS));

        // ETH ungild.
        // Reentrant via. sender's `receive` function.
        (bool _refundSuccess, ) = msg.sender.call{value: ethAmount}(""); // solhint-disable avoid-low-level-calls
        require(_refundSuccess, "UNGILD_ETH");
    }

    /// Gilds ETH for equal parts ETHg erc20 and erc1155 tokens.
    /// @param xauReferencePrice XAU reference price in ETH.
    /// @param ethAmount amount of ETH to gild.
    function gild(uint256 xauReferencePrice, uint256 ethAmount) private {
        require(ethAmount > 0, "GILD_ZERO");

        // Amount of ETHg to mint.
        uint256 _ethgAmount = ethAmount.mul(xauReferencePrice).div(10**XAU_DECIMALS);
        emit Gild(msg.sender, xauReferencePrice, ethAmount);

        // erc20 mint.
        // NOT reentrant.
        _mint(msg.sender, _ethgAmount);

        // erc1155 mint.
        // Reentrant via. `IERC1155Receiver`.
        _mint(msg.sender, xauReferencePrice, _ethgAmount, "");
    }

    receive() external payable {
        gild(referencePrice(), msg.value);
    }

    fallback() external payable {
        gild(referencePrice(), msg.value);
    }
}
