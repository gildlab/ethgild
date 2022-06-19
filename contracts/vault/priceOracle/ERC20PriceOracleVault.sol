// SPDX-License-Identifier: UNLICENSE
pragma solidity =0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "../erc4626/IERC4626.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../oracle/price/IPriceOracle.sol";
import "@beehiveinnovation/rain-protocol/contracts/math/FixedPointMath.sol";

/// All config required to construct `ERC20PriceOracleVault`.
/// @param asset `ERC4626` underlying asset.
/// @param name `ERC20` name for `ERC4626` shares.
/// @param symbol `ERC20` symbol for `ERC4626` shares.
/// @param uri `ERC1155` uri for deposit receipts.
/// @param address `IPriceOracle` oracle to define share mints upon deposit.
struct ConstructionConfig {
    address asset;
    string name;
    string symbol;
    string uri;
    address priceOracle;
}

/// @title ERC20PriceOracleVault
/// @notice An ERC4626 vault that mints shares according to a price oracle. As
/// shares are minted an associated ERC1155 NFT receipt is minted for the
/// asset depositor. The price oracle defines the amount of shares minted for
/// each deposit. The price oracle's base MUST be the deposited asset but the
/// price quote can be anything with a reliable oracle.
///
/// When the assets are withdrawn from the vault, the withdrawer must provide a
/// receipt from a previous deposit. The receipt amount and the original
/// shares minted are the same according to the price at the time of deposit.
/// The withdraw burns shares in return for assets as per ERC4626 AND burns the
/// receipt nominated by the withdrawer. The current price from the oracle is
/// irrelevant to withdraws, only the receipt price is relevant.
///
/// As an analogy, consider buying a shirt on sale and then attempting to get a
/// refund for it after the sale ends. The store will refund the shirt but only
/// at the sale price marked on the receipt, NOT the current price of the same
/// shirt in-store.
///
/// This dual 20/1155 token system allows for a dynamic shares:asset mint
/// ratio on deposits without withdrawals ever being able to remove more assets
/// than were ever deposited.
///
/// Where this gets interesting is trying to discover a price for the ERC20
/// share token. The share token can't be worth 0 because it represents a claim
/// on a fully collateralized vault of assets. The share token also can't be
/// worth more than the current oracle price as it would allow depositors to
/// buy infinite assets. To see why this is true, consider that selling 1 asset
/// for a token pegged to the price buys the same number of pegged tokens as
/// depositing 1 asset yields minted shares. If 1 share buys more than 1 pegged
/// token then depositing 1 asset and selling the minted shares buys more than
/// 1 asset. This sets up an infinite loop which can't exist in a real market.
///
/// ERC20PriceOracleVault shares are useful primitives that convert a valuable
/// but volatile asset (e.g. wBTC/wETH) into shares that trade in a range (0, 1)
/// of some reference price. Such a primitive MAY have trustless utility in
/// domains such as providing liquidity on DEX/AMMs, non-liquidating leverage
/// for speculation, risk management, etc.
///
/// Note on ERC4626 rounding requirements:
/// In various places the ERC4626 specification defines whether a function
/// rounds up or round down when calculating mints and burns. This is to ensure
/// that rounding erros always favour the vault, in that deposited assets will
/// slowly accrue as dust (1 wei per rounding error) wherever the deposit and
/// withdraw round trip cannot be precisely calculated. Technically to achieve
/// this we should do something like the Open Zeppelin `ceilDiv` function that
/// includes checks that `X % Y == 0` before rounding up after the integer
/// division that first floors the result. We don't do that. To achieve the
/// stated goals of ERC4626 rounding, which is setting aside 1 wei for security
/// to guarantee total withdrawals are strictly <= deposits, we always add 1
/// wei to the "round up" function results unconditionally. This saves gas and
/// simplifies the contract overall.
contract ERC20PriceOracleVault is ERC20, ERC1155, IERC4626, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using FixedPointMath for uint256;

    event Construction(address caller, ConstructionConfig config);

    /// @inheritdoc IERC4626
    address public immutable asset;

    IPriceOracle public immutable priceOracle;

    mapping(address => uint256) public minPrices;
    mapping(address => uint256) public prices;

    constructor(ConstructionConfig memory config_)
        ERC20(config_.name, config_.symbol)
        ERC1155(config_.uri)
    {
        asset = config_.asset;
        priceOracle = IPriceOracle(config_.priceOracle);
        emit Construction(msg.sender, config_);
    }

    /// Calculate how many shares_ will be minted in return for assets_.
    /// @return shares_
    function _calculateDeposit(
        uint256 assets_,
        uint256 price_,
        uint256 minPrice_
    ) internal pure returns (uint256 shares_) {
        require(price_ >= minPrice_, "MIN_PRICE");
        // IRC4626:
        // If (1) it’s calculating how many shares to issue to a user for a
        // certain amount of the underlying tokens they provide, it should
        // round down.
        shares_ = assets_.fixedPointMul(price_);
    }

    /// Calculate how many assets_ are needed to mint shares_.
    /// @return assets_
    function _calculateMint(
        uint256 shares_,
        uint256 price_,
        uint256 minPrice_
    ) internal pure returns (uint256 assets_) {
        require(price_ >= minPrice_, "MIN_PRICE");
        // IERC4626:
        // If (2) it’s calculating the amount of underlying tokens a user has
        // to provide to receive a certain amount of shares, it should
        // round up.
        assets_ = shares_.fixedPointDiv(price_) + 1;
    }

    /// Calculate how many shares_ to burn to withdraw assets_.
    /// @return shares_
    function _calculateWithdraw(uint256 assets_, uint256 price_)
        internal
        pure
        returns (uint256 shares_)
    {
        // IERC4626:
        // If (1) it’s calculating the amount of shares a user has to supply to
        // receive a given amount of the underlying tokens, it should round up.
        shares_ = assets_.fixedPointMul(price_) + 1;
    }

    /// Calculate how many assets_ to withdraw for burning shares_.
    /// @return assets_
    function _calculateRedeem(uint256 shares_, uint256 price_)
        internal
        pure
        returns (uint256 assets_)
    {
        // IERC4626:
        // If (2) it’s determining the amount of the underlying tokens to
        // transfer to them for returning a certain amount of shares, it should
        // round down.
        assets_ = shares_.fixedPointDiv(price_);
    }

    function setMinPrice(uint256 minPrice_) external {
        minPrices[msg.sender] = minPrice_;
    }

    function setPrice(uint256 price_) external {
        prices[msg.sender] = price_;
    }

    /// @inheritdoc IERC4626
    function totalAssets() external view returns (uint256) {
        // There are NO fees so the managed assets are the balance.
        return IERC20(asset).balanceOf(address(this));
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint256 assets_) external view returns (uint256) {
        return _calculateDeposit(assets_, priceOracle.price(), 0);
    }

    /// @inheritdoc IERC4626
    function convertToAssets(uint256 shares_) external view returns (uint256) {
        return _calculateRedeem(shares_, priceOracle.price());
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 assets_) external view returns (uint256) {
        return _calculateDeposit(assets_, priceOracle.price(), 0);
    }

    /// If the sender wants to use the ERC4626 `deposit` function and set a
    /// minimum price they need to call `setMinPrice` first in a separate call.
    /// Alternatively they can use the off-spec overloaded `deposit` method.
    /// @inheritdoc IERC4626
    function deposit(uint256 assets_, address receiver_)
        external
        returns (uint256)
    {
        return deposit(assets_, receiver_, minPrices[msg.sender]);
    }

    /// Overloaded `deposit` to allow `minPrice_` to be passed directly without
    /// the additional `setMinPrice` call, which saves gas and can provide a
    /// better UX overall.
    function deposit(
        uint256 assets_,
        address receiver_,
        uint256 minPrice_
    ) public returns (uint256) {
        uint256 price_ = priceOracle.price();
        require(minPrice_ <= price_, "MIN_PRICE");
        uint256 shares_ = _calculateDeposit(assets_, price_, minPrice_);

        return _deposit(assets_, receiver_, shares_, price_);
    }

    /// _deposit handles minting and emitting events according to spec.
    /// It does NOT do any calculations so shares and assets need to be handled
    /// correctly according to spec including rounding, in the calling context.
    function _deposit(
        uint256 assets_,
        address receiver_,
        uint256 shares_,
        uint256 price_
    ) internal nonReentrant returns (uint256) {
        require(assets_ > 0, "0_ASSETS");
        require(receiver_ != address(0), "0_RECEIVER");
        require(shares_ > 0, "0_SHARES");
        require(price_ > 0, "0_PRICE");
        emit IERC4626.Deposit(msg.sender, receiver_, assets_, shares_);

        IERC20(asset).safeTransferFrom(msg.sender, address(this), assets_);

        // erc20 mint.
        _mint(receiver_, shares_);

        // erc1155 mint.
        // Receiving contracts MUST implement `IERC1155Receiver`.
        _mint(receiver_, price_, shares_, "");

        return shares_;
    }

    /// @inheritdoc IERC4626
    function maxMint(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 shares_) external view returns (uint256) {
        return _calculateMint(shares_, priceOracle.price(), 0);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares_, address receiver_)
        external
        returns (uint256)
    {
        return mint(shares_, receiver_, minPrices[msg.sender]);
    }

    /// @return assets_
    function mint(
        uint256 shares_,
        address receiver_,
        uint256 minPrice_
    ) public returns (uint256) {
        uint256 price_ = priceOracle.price();
        uint256 assets_ = _calculateMint(shares_, price_, minPrice_);
        _deposit(assets_, receiver_, shares_, price_);
        return assets_;
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address owner_) external view returns (uint256) {
        return maxWithdraw(owner_, prices[owner_]);
    }

    /// Overloaded `maxWithdraw` that allows setting a price directly. The
    /// price needs to be provided so that we know which ERC1155 balance to
    /// check the withdraw against. The burnable ERC20 is capped per-withdraw
    /// to the balance of a price-bound ERC1155.
    /// @return max assets.
    function maxWithdraw(address owner_, uint256 price_)
        public
        view
        returns (uint256)
    {
        return _calculateWithdraw(balanceOf(owner_, price_), price_);
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 assets_) external view returns (uint256) {
        return previewWithdraw(assets_, prices[msg.sender]);
    }

    function previewWithdraw(uint256 assets_, uint256 price_)
        public
        pure
        returns (uint256)
    {
        return _calculateWithdraw(assets_, price_);
    }

    /// @inheritdoc IERC4626
    function withdraw(
        uint256 assets_,
        address receiver_,
        address owner_
    ) external returns (uint256) {
        return withdraw(assets_, receiver_, owner_, prices[owner_]);
    }

    function withdraw(
        uint256 assets_,
        address receiver_,
        address owner_,
        uint256 price_
    ) public returns (uint256) {
        uint256 shares_ = _calculateWithdraw(assets_, price_);
        return _withdraw(assets_, receiver_, owner_, shares_, price_);
    }

    /// @return shares_
    function _withdraw(
        uint256 assets_,
        address receiver_,
        address owner_,
        uint256 shares_,
        uint256 price_
    ) internal nonReentrant returns (uint256) {
        require(assets_ > 0, "0_ASSETS");
        require(receiver_ != address(0), "0_RECEIVER");
        require(owner_ != address(0), "0_OWNER");
        require(shares_ > 0, "0_SHARES");
        require(price_ > 0, "0_PRICE");

        emit IERC4626.Withdraw(msg.sender, receiver_, owner_, assets_, shares_);

        // erc20 burn.
        _burn(owner_, shares_);

        // erc1155 burn.
        _burn(owner_, price_, shares_);

        IERC20(asset).safeTransfer(receiver_, assets_);

        return shares_;
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address owner_) external view returns (uint256) {
        return maxRedeem(owner_, prices[owner_]);
    }

    function maxRedeem(address owner_, uint256 price_)
        public
        view
        returns (uint256)
    {
        return balanceOf(owner_, price_);
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 shares_) external view returns (uint256) {
        return _calculateRedeem(shares_, prices[msg.sender]);
    }

    function previewRedeem(uint256 shares_, uint256 price_)
        public
        pure
        returns (uint256)
    {
        return _calculateRedeem(shares_, price_);
    }

    /// @inheritdoc IERC4626
    function redeem(
        uint256 shares_,
        address receiver_,
        address owner_
    ) external returns (uint256) {
        return redeem(shares_, receiver_, owner_, prices[owner_]);
    }

    function redeem(
        uint256 shares_,
        address receiver_,
        address owner_,
        uint256 price_
    ) public returns (uint256) {
        uint256 assets_ = _calculateRedeem(shares_, price_);
        _withdraw(assets_, receiver_, owner_, shares_, price_);
        return assets_;
    }
}
