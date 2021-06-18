// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Chainlink imports.
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// Open Zeppelin imports.
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

/// @title EthGild
/// @author thedavidmeister
///
/// Gild: to wrap with gold.
///
/// Similar to wrapped eth (WETH).
/// WETH swaps ETH 1:1 with an erc20 token that can be unwrapped to get the original ETH back.
/// GildEth (ETHg) swaps ETH with an erc20 token at the current gold price that can be unwrapped to get the original ETH back.
/// The gold price for each wrapping is represented as an NFT (erc1155) owned by the wrapper.
/// Anyone who owns the NFT and correct amount of ETHg can unwrap the ETH.
/// 0.1% more ETHg must be burned when it is ungilded than gilded.
/// The overburn traps a tiny sliver of ETH in each gilding to help ETHg price recover faster after a market shock.
/// The temporary glut of ETHg dumped in a market crash should be soaked up from the overburn long before waiting for a new ETH ATH.
/// 0.1% is somewhat arbitrary but is intended to be less than a typical AMM trade that includes fee % + slippage + gas.
///
/// EthGild is both an erc1155 and erc20.
/// All token behaviour is default Open Zeppelin.
/// This works because none of the function names collide, or if they do the signature overloads cleanly (e.g. `_mint`).
///
/// ## Purpose
///
/// Product made for ourselves.
/// During bear markets cryptocurrency users may want exposure to precious metals.
/// But do not want to rely on or back nation state fiat.
/// Nor on the construction of stablecoins.
/// EthGild is a token contract that is fully collateralized by ETH and uses tradeable gold price snapshots to (hopefully) create an emergent soft peg.
///
/// ## Gilding
///
/// Simply send ETH to the contract.
/// `gild` is a private function wrapped by both `receive` and `fallback`.
/// The erc1155 is minted as the current gold price in ETH as its id, and the price multiplied by ETH locked as amount (18 decimals).
/// The ETHg erc20 is minted as the price multiplied by ETH locked as amount (18 decimals).
/// The ETH gilded is whatever is sent to the contract as a normal transaction.
///
/// ## Ungilding
///
/// The erc1155 id (ungild price) and amount of ETH to ungild must be specified to the ungild function.
/// The erc1155 under the price id is burned as ETH being ungild multiplied by the ungild price.
/// The ETHg erc20 is burned as 1001/1000 times the erc1155 burn.
/// The ETH amount is sent to `msg.sender`.
///
/// ## Reentrancy
///
/// The erc20 minting and all burning is not reentrant but the erc1155 mint _is_ reentrant.
/// Both gild and ungild end with possibly reentrant calls to the msg.sender.
/// `gild` will attempt to treat the `msg.sender` as an `IERC1155Receiver`.
/// `ungild` will call the sender with the appropriate ETH amount.
/// This should be safe for the contract state and may facilitate creative use-cases.
///
/// ## Tokenomics
///
/// - Hard price cap at 1 ounce of gold.
///   - Exceeding this allows to gild 1 eth, sell minted ETHg, buy more than 1 eth, repeat infinitely.
/// - Hard price cap at max recent ETH drawdown.
///   - Exceeding this allows all gilded eth to be ungilded on a market buy of ETHg cheaper than the gilded ETH backing it.
/// - Ranging between two caps.
///   - Sell high to leverage ETH without liquidation threat.
///     - Gild 1 ETH for ~1 ETH of ETHg, sell ETHg for ETH, wait for pump.
///     - Ungild original eth for roughly starting ETHg price, sell ~2 ETH.
///   - Buy low to trap degens.
///     - Ultimately every ETHg +0.1% must be burned for ETH to be returned.
///     - ETH should always be more desirable long term than ETHg so eventually the price will recover.
///     - A "bank run" on ETHg pushes the ETHg price _higher_ as it is burned to ungild ETH.
///     - Should find a natural equilibrium between gild and ungild based on market conditions.
///   - Use in range for sort-of protected ETH value.
///     - If ETH is uncomfortably high then gild and keep ETHg.
///     - Gilding is not a trade so is immune to front-running and slippage.
///     - Price based on gold oracle so does not rely on fiat for stability.
///     - If ETH crashes then ETHg probably will too but ETHg may recover stability faster.
///     - ETH can be ungilded for 0.1% haircut at any time if market remains strong.
///   - Use in range for LP on AMM with low IL.
///     - Pair with other gold tokens knowing that ETHg is bounded [0.x-1) with gold price.
///     - IL is credibly impermanent.
///     - All liquidity on AMM is locking ETH so more liquidity implies tighter price range.
///     - Should always be baseline supply/demand from leveraging use-case.
/// - Applicable to any token/price pair
///   - ETH and gold seem the most obvious first pair to experiment with.
///   - If it works then basically any token/pair should work as long as there is demand for the base token.
///
/// ## Administration
///
/// - Contract has NO owner or other administrative functions
/// - Contract has NO upgrades
/// - There is NO peg
/// - There is NO DAO
/// - There are NO liquidations
/// - There is NO collateralisation ratio (but 100%+ of all tokens minted must be burned to ungild ETH)
/// - This is all HIGHLY EXPERIMENTAL and comes with NO WARRANTY
/// - The tokenomics are HIGHLY EXPERIMENTAL and NOT FINANCIAL ADVICE
/// - If this contract is EXPLOITED or contains BUGS
///   - There is NO support or compensation
///   - There MAY be a NEW contract deployed without the exploit/bug
contract EthGild is ERC1155, ERC20 {
    // Chainlink oracles are signed integers so we need to handle them as unsigned for price feed.
    using SafeCast for int256;
    using SafeMath for uint256;

    /// @param caller the address gilding ETH.
    /// @param xauPrice the XAU price the ETH was gilded at.
    /// @param ethAmount the amount of ETH gilded.
    event Gild(address indexed caller, uint256 indexed xauPrice, uint256 indexed ethAmount);
    /// @param caller the address ungilding ETH.
    /// @param xauPrice the XAU price the ETH is ungilded at.
    /// @param ethAmount the amount of ETH ungilded.
    event Ungild(address indexed caller, uint256 indexed xauPrice, uint256 indexed ethAmount);

    /// erc20 name.
    string public constant NAME = "EthGild";
    /// erc20 symbol.
    string public constant SYMBOL = "ETHg";
    /// erc1155 uri.
    /// Note the erc1155 id is simply the xauPrice at which ETHg tokens can burn it to unlock ETH.
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
    AggregatorV3Interface public constant CHAINLINK_XAUUSD = AggregatorV3Interface(0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6);
    AggregatorV3Interface public constant CHAINLINK_ETHUSD = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    constructor () ERC20(NAME, SYMBOL) ERC1155(GILD_URI) { } //solhint-disable no-empty-blocks

    // Returns an XAU price in ETH or reverts.
    // Internally calls two separate chainlink oracles to factor out the USD price.
    // Ideally we'd avoid referencing USD even for internal math but chainlink doesn't support it.
    function price() public view returns (uint256) {
        ( , int256 _xauUsd, , , ) = CHAINLINK_XAUUSD.latestRoundData();
        ( , int256 _ethUsd, , , ) = CHAINLINK_ETHUSD.latestRoundData();
        return _ethUsd.toUint256().mul(10 ** XAU_DECIMALS).div(_xauUsd.toUint256());
    }

    /// Burn roughly equal (1001:1000 ratio) erc20:erc1155 to receive initial ETH refund.
    /// If the `msg.sender` does not have _both_ the erc1155 and erc20 balances for a given price the ETH will not ungild.
    /// The erc20 and erc1155 amounts as `xauPrice * ethAmount` (+0.1% for erc20) will be burned.
    /// @param xauPrice XAU price in ETH. MUST correspond to an erc1155 balance held by `msg.sender`.
    /// @param ethAmount the amount of ETH to ungild.
    function ungild(uint256 xauPrice, uint256 ethAmount) external {
        // Amount of oXAU to burn.
        uint256 _ethgAmount = ethAmount.mul(xauPrice);
        emit Ungild(msg.sender, xauPrice, ethAmount);

        // erc20 burn.
        // 0.1% more than erc1155 burn.
        // NOT reentrant.
        _burn(msg.sender, _ethgAmount.mul(ERC20_OVERBURN_NUMERATOR).div(ERC20_OVERBURN_DENOMINATOR).div(10 ** XAU_DECIMALS));

        // erc1155 burn.
        // NOT reentrant (doesn't trigger `IERC1155Receiver`).
        _burn(msg.sender, xauPrice, _ethgAmount.div(10 ** XAU_DECIMALS));

        // ETH ungild.
        // Reentrant via. sender's `receive` function.
        (bool _refundSuccess, ) = msg.sender.call{value: ethAmount}(""); // solhint-disable avoid-low-level-calls
        require(_refundSuccess, "ETH_UNGILD");
    }

    /// Gilds ETH for equal parts ETHg erc20 and erc1155 tokens.
    /// @param xauPrice XAU price in ETH.
    /// @param ethAmount amount of ETH to gild.
    function gild(uint256 xauPrice, uint256 ethAmount) private {
        require(ethAmount > 0, "ZERO_ETH");

        // Amount of ETHg to mint.
        uint256 _ethgAmount = ethAmount.mul(xauPrice).div(10 ** XAU_DECIMALS);
        emit Gild(msg.sender, xauPrice, ethAmount);

        // erc20 mint.
        // NOT reentrant.
        _mint(msg.sender, _ethgAmount);

        // erc1155 mint.
        // Reentrant via. `IERC1155Receiver`.
        _mint(msg.sender, xauPrice, _ethgAmount, "");
    }

    receive() external payable {
        gild(price(), msg.value);
    }

    fallback() external payable {
        gild(price(), msg.value);
    }
}