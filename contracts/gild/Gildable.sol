// SPDX-License-Identifier: UNLICENSE
pragma solidity =0.8.10;

// Open Zeppelin imports.
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {IPriceOracle} from "../oracle/price/IPriceOracle.sol";
import {PriceOracleConstants} from "../oracle/price/PriceOracleConstants.sol";

struct GildConfig {
    string name;
    string symbol;
    string uri;
    uint256 erc20OverburnNumerator;
    uint256 erc20OverburnDenominator;
    IPriceOracle priceOracle;
}

/// @title NativeGild
/// @author thedavidmeister
///
/// ## Purpose
///
/// Gild: to cover with gold.
///
/// A wrapped token that wraps/unwraps the native token for an EVM chain
/// according to a price oracle.
///
/// Similar to wrapped eth (WETH).
/// WETH "wraps" ETH 1:1 with an erc20 token that can be unwrapped to get the
/// original ETH back. GildEth (ETHg) wraps (gilds) ETH with an erc20 token at
/// the current reference gold price that can be unwrapped to get the original
/// ETH back. The gilding is represented as an NFT (erc1155) owned by the
/// gilder. The NFT owner can ungild ETHg back to ETH at the same rate the ETHg
/// was minted at for that NFT. 0.1% additional ETHg must be burned when it is
/// ungilded (overburn). The overburn locks a tiny sliver of ETH in each
/// gilding to help support growth of an organic ETHg community. Anyone who
/// wants to ungild all their ETH must first acquire a small amount of
/// additional ETHg from a fellow gilder. The heaviest stress on ETHg will
/// likely occur during rapid ETH market price spike and crash cycles. We
/// should expect large amounts of ETHg to be minted by skittish ETH hodlers
/// each time ETH nears an ATH or similar. As the market price of ETH crashes
/// with large new ETHg supply, there will be a lot of pressure on ETHg, likely
/// short term chaos. As (un)gild cycles continue the overburn will soak up
/// some ETHg glut in the medium term. The overburn means that a "bank run" on
/// ETHg will force the market price upward towards the current reference gold
/// price, incentivising new gildings. Long term the steady cumulative increase
/// of locked ETH in the system will cushion future shocks to the ETHg market
/// price. 0.1% is somewhat arbitrary but is intended to be competetive with
/// typical onchain DEX trades that include fee % + slippage + gas. The goal is
/// for the target audience to find it more compelling to wrap ETH to ETHg than
/// trade their ETH away for stablecoins.
///
/// ## Comparison to stablecoins
///
/// EthGild is NOT a stablecoin.
///
/// The primary goal of a stablecoin is to mimic the price of some external
/// "stable" asset. The primary goal of ETHg is to mitigate some of the
/// short-mid term risks associated with holding ETH while maintaining the long
/// term "owner" relationship to the gilded ETH.
///
/// The (un)gild process is designed to constrain gold denominated price
/// movements on ETHg through market forces but there is no explicit peg.
///
/// There are a few key issues that ETH holders face when interacting with
/// stablecoins:
/// - Stablecoins typically denominated in fiat, which inevitably introduces
///   counterparty risk from the fiat issuer
/// - Stablecoins with a fixed peg are either "algorithmic"
///   (undercollateralised) or heavily overcollateralized
///   - The former is a severe case of "works until it doesn't" where a single
///     catastrophic bank run can instantly wipe out the system
///     (e.g. $2 billion wiped out overnight by Titan/Iron)
///   - The latter requires complex mechanisms such as liquidations, custody,
///     DAOs etc. to eternally manage the collateral against the peg
///     (e.g. DAI, USDC)
/// - Moving from ETH to a stablecoin typically means risk of losing ETH,
///   whether you trade it in or borrow against it
///   - If you trade away your ETH then you trigger a taxable event in many
///     jurisdictions, and risk the market moving against you while you use the
///     stablecoin for short term costs, such that you can never buy your ETH
///     back later
///   - If you borrow against your ETH then you face constant liquidation
///     threat, if the market drops sharply for even one hour you can have your
///     ETH taken from you forever
///   - Trades can be front-run and suffer slippage, loan liquidations can
///     cascade and need to be defended even during periods of super-high
///     (500+ gwei) network fees
///
/// EthGild aims to address these concerns in a few ways:
/// - There is no explicit peg and ETHg ranging anywhere from 0-1x the current
///   gold price should be considered normal
///   - Removing rigid expectations from the system should mitigate certain
///     psychological factors that manifest as sudden price shocks and panics
///   - There is no need to actively manage the system if there is no peg to
///     maintain and every ETHg gilded is overcollateralised by design
/// - Gilding/ungilding ETH maintains the gilder's control on their ETH for as
///   long as they hold the erc1155 and can acquire sufficient ETHg to ungild
/// - Gilding/ungilding based on the gold price denominated in ETH decouples
///   the system from counterparty risk as much as possible
///   - Physical gold and by extension the gold price does not derive its value
///     from any specific authority and has well established, global liquid
///     markets
///   - Of course we now rely on the chain link oracle, this is a tradeoff
///     users will have to decide for themselves to accept
/// - The overburn mechanism ensures that bank runs on the underlying asset
///   bring the ETHg price _closer_ to the reference gold price
/// - ETH collateral is never liquidated, the worst case scenario for the
///   erc1155 holder is that they ungild the underlying ETH at the current
///   reference gold price
/// - Gilding/ungilding itself cannot be front-run and there is no slippage
///   because the only inputs are the reference price and your own ETH
/// - EthGild is very simple, the whole system runs off 2x unmodified Open
///   Zeppelin contracts, 1x oracle and 2x functions, `gild` and `ungild`
///
/// ## Implementation
///
/// EthGild is both an erc1155 and erc20.
/// All token behaviour is default Open Zeppelin.
/// This works because none of the function names collide, or if they do the
/// signature overloads cleanly (e.g. `_mint`).
///
/// ## Gilding
///
/// Call the payable `gild` function with an ETH `value` to be gilded. The
/// "reference price" is source from Chainlink oracle for internal
/// calculations, nothing is actually bought/sold/traded in a gild. The erc1155
/// is minted as the current reference price in ETH as its id, and the
/// reference price multiplied by ETH locked as amount (18 decimals). The ETHg
/// erc20 is minted as the reference price multiplied by ETH locked as amount
/// (18 decimals). The ETH amount is calculated as the `msg.value` sent to the
/// EthGild contract (excludes gas).
///
/// ## Ungilding
///
/// The erc1155 id (reference price) and amount of ETH to ungild must be
/// specified to the `ungild` function. The erc1155 under the reference price
/// id is burned as ETH being ungild multiplied by the reference price. The
/// ETHg erc20 is burned as 1001/1000 times the erc1155 burn. The ETH amount is
/// sent to `msg.sender` (excludes gas).
///
/// ## Reentrancy
///
/// The erc20 minting and all burning is not reentrant but the erc1155 mint
/// _is_ reentrant. Both `gild` and `ungild` end with reentrant calls to the
/// `msg.sender`. `gild` will attempt to treat the `msg.sender` as an
/// `IERC1155Receiver`. `ungild` will call the sender's `receive` function when
/// it sends the ungilded ETH. This is safe for the EthGild contract state as
/// the reentrant calls are last and allowed to facilitate creative use-cases.
///
/// ## Tokenomics
///
/// - Market price pressure above reference price of 1 ounce of gold.
///   - Exceeding this allows anyone to gild 1 ETH, sell minted ETHg, buy more
///     than 1 ETH, repeat infinitely.
/// - Market price pressure below max recent ETH drawdown.
///   - Exceeding this allows all gilded eth to be ungilded on a market buy of
///     ETHg cheaper than the gilded ETH backing it.
/// - Ranging between two (dynamic) limits.
///   - Gild when market is high to leverage ETH without liquidation threat.
///   - Buy low to anticipate upward "bank runs".
///   - Use in range as less-volatile proxy to underlying ETH value.
///   - Use in range for LP on AMM with low IL.
///     - Pair with other gold tokens knowing that ETHg is bounded by gold
///       reference price.
///     - IL is credibly impermanent, or at least mitigated.
///     - All liquidity on AMM is locking ETH in the bonding curve so more
///       liquidity implies tighter market (virtuous cycle).
///     - Should always be baseline supply/demand from leveraging use-case.
///     - Overburn should always tighten the price range as cumulative (un)gild
///       volume builds over time.
///     - The more ETHg is used outside of the (un)gild process, the more
///       underyling ETH is locked
///
/// ## Administration
///
/// - Contract has NO owner or other administrative functions.
/// - Contract has NO upgrades.
/// - There is NO peg.
/// - There is NO DAO.
/// - There are NO liquidations.
/// - There is NO collateralisation ratio.
/// - ETHg is increasingly overcollateralised due to overburn.
/// - There is NO WARRANTY and the code is PUBLIC DOMAIN (read the UNLICENSE).
/// - The tokenomics are hypothetical, have zero empirical evidence (yet) and
///   are certainly NOT FINANCIAL ADVICE.
/// - If this contract is EXPLOITED or contains BUGS
///   - There is NO support or compensation.
///   - There MAY be a NEW contract deployed without the exploit/bug but I am
///     not obligated to engineer or deploy any specific fix.
/// - Please feel welcome to build on top of this as a primitive
///   (read the UNLICENSE).
///
/// ## Smart contract risk
///
/// Every smart contract has significant "unknown risks".
/// This contract may suffer unforeseen bugs or exploits.
/// These bugs or exploits may result in partial or complete loss of your funds
/// if you choose to use it. These bugs or exploits may only manifest when
/// combined with onchain factors that do not exist and cannot be predicted
/// today. For example, consider the innovation of flash loans and the
/// implications to all existing contracts. Audits and other professional
/// reviews will be conducted over time if and when TVL justifies it.
/// Ultimately, the only useful measure of risk is `total value locked x time`
/// which cannot be measured in advance.
///
/// ## Oracle risk
///
/// The Chainlink oracles could cease to function or report incorrect data.
/// As EthGild is not targetting a strict peg or actively liquidating
/// participants, there is some tolerance for temporarily incorrect data.
/// However, if the reference price is significantly wrong for an extended
/// period of time this does harm the system, up to and including existential
/// risk. As there are no administrative functions for EthGild, there is no
/// ability to change the oracle data source after deployment. Changing the
/// oracle means deploying an entirely new contract with NO MIGRATION PATH.
/// You should NOT use this contract unless you have confidence in the
/// Chainlink oracle to maintain price feeds for as long as you hold either the
/// erc20 or erc1155. The Chainlink oracle contracts themselves are proxy
/// contracts, which means that the owner (Chainlink) can modify the data
/// source over time. This is great as it means that data should be available
/// even as they iterate on their contracts, as long as they support backwards
/// compatibility for `AggregatorV3Interface`. This also means that EthGild can
/// never be more secure than Chainlink itself, if their oracles are damaged
/// somehow then EthGild suffers too.
contract Gildable is ERC20, ERC1155, ReentrancyGuard {
    /// Sender has constructed the contract.
    event Construction(address sender, GildConfig config);

    /// Some ETH has been gilded.
    event Gild(
        /// `msg.sender` address gilding ETH.
        address sender,
        /// Reference price gilded at.
        uint256 price,
        /// Amount of token gilded.
        uint256 amount
    );
    /// Some native token has been ungilded.
    event Ungild(
        /// `msg.sender` address ungilding native token.
        address sender,
        /// Reference price ungilded at.
        uint256 price,
        /// Amount of token ungilded.
        uint256 amount
    );

    /// erc20 is burned faster than erc1155.
    /// This is the numerator for that.
    uint256 public immutable erc20OverburnNumerator;
    /// erc20 is burned faster than erc1155.
    /// This is the denominator for that.
    uint256 public immutable erc20OverburnDenominator;

    // Price oracle.
    IPriceOracle public immutable priceOracle;

    /// Constructs both erc20 and erc1155 tokens and sets oracle addresses.
    constructor(GildConfig memory config_)
        ERC20(config_.name, config_.symbol)
        ERC1155(config_.uri)
    {
        erc20OverburnNumerator = config_.erc20OverburnNumerator;
        erc20OverburnDenominator = config_.erc20OverburnDenominator;
        priceOracle = config_.priceOracle;
        emit Construction(msg.sender, config_);
    }

    function _gild(uint256 amount_, uint256 minPrice_)
        internal
        nonReentrant
        returns (uint256)
    {
        uint256 price_ = priceOracle.price();
        require(price_ >= minPrice_, "MIN_PRICE");

        // Amount of ETHg to mint.
        uint256 ethgAmount_ = (amount_ * price_) / PriceOracleConstants.ONE;
        require(ethgAmount_ >= erc20OverburnDenominator, "MIN_GILD");
        emit Gild(msg.sender, price_, amount_);

        // erc20 mint.
        _mint(msg.sender, ethgAmount_);

        // erc1155 mint.
        // Receiving contracts MUST implement `IERC1155Receiver`.
        _mint(msg.sender, price_, ethgAmount_, "");
        return price_;
    }

    /// Overburn ETHg at 1001:1000 ratio to receive initial ETH refund.
    /// If the `msg.sender` does not have _both_ the erc1155 and erc20 balances
    /// for a given reference price the ETH will not ungild. The erc20 and
    /// erc1155 amounts as `xauReferencePrice * ethAmount` (+0.1% for erc20)
    /// will be burned.
    /// @param price_ oracle price in Native asset. MUST correspond
    /// to an erc1155 balance held by `msg.sender`.
    /// @param erc1155Amount_ the amount of ETH to ungild.
    function _ungild(uint256 price_, uint256 erc1155Amount_)
        internal
        nonReentrant
        returns (uint256)
    {
        require(erc1155Amount_ >= erc20OverburnDenominator, "MIN_UNGILD");

        // ETHg erc20 burn.
        // 0.1% more than erc1155 burn.
        _burn(
            msg.sender,
            (erc1155Amount_ * erc20OverburnNumerator) / erc20OverburnDenominator
        );

        // erc1155 burn.
        _burn(msg.sender, price_, erc1155Amount_);

        // Amount of token to ungild.
        uint256 amount_ = (erc1155Amount_ * PriceOracleConstants.ONE) / price_;
        emit Ungild(msg.sender, price_, amount_);

        return amount_;
    }
}
