// SPDX-License-Identifier: UNLICENSE
pragma solidity =0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "../erc4626/IERC4626.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../oracle/price/IPriceOracle.sol";
import "../oracle/price/PriceOracleConstants.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";

struct ERC20GildConfig {
    address asset;
    string name;
    string symbol;
    string uri;
    address priceOracle;
}

contract ERC20Gild is ERC20, ERC1155, IERC4626, ReentrancyGuard {
    using Math for uint;
    using SafeERC20 for IERC20;

    event Construction(address caller, ERC20GildConfig config);

    /// @inheritdoc IERC4626
    address public immutable asset;

    IPriceOracle public immutable priceOracle;

    mapping(address => uint) public minPrices;

    mapping(address => uint) public prices;

    constructor(ERC20GildConfig memory config_) ERC20(config_.name, config_.symbol) ERC1155(config_.uri) {
        asset = config_.asset;
        priceOracle = IPriceOracle(config_.priceOracle);
        emit Construction(msg.sender, config_);
    }

    function _calculateDeposit(uint assets_, uint price_, uint minPrice_) internal pure returns (uint) {
        require(price_ >= minPrice_, "MIN_PRICE");
        return (assets_ * price_) / PriceOracleConstants.ONE;
    }

    function _calculateMint(uint shares_, uint price_, uint minPrice_) internal pure returns (uint) {
        require(price_ >= minPrice_, "MIN_PRICE");
        return _calculateRedeem(shares_, price_);
    }

    /// @return assets_
    function _calculateRedeem(uint shares_, uint price_) internal pure returns (uint) {
        return (shares_ * PriceOracleConstants.ONE) / price_;
    }

    function setMinPrice(uint minPrice_) external {
        minPrices[msg.sender] = minPrice_;
    }

    function setPrice(uint price_) external {
        prices[msg.sender] = price_;
    }

    /// @inheritdoc IERC4626
    function totalAssets() external view returns (uint) {
        // There are NO fees so the "managed" assets are the balance.
        return IERC20(asset).balanceOf(address(this));
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint assets_) external view returns (uint) {
        return _calculateDeposit(assets_, priceOracle.price(), 0);
    }

    /// @inheritdoc IERC4626
    function convertToAssets(uint shares_) external view returns (uint) {
        return _calculateRedeem(shares_, priceOracle.price());
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address) external pure returns (uint) {
        return type(uint).max;
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint assets_) external view returns (uint) {
        return _calculateDeposit(assets_, priceOracle.price(), 0);
    }

    /// If the sender wants to use the ERC4626 `deposit` function and set a
    /// minimum price they need to call `setMinPrice` first in a separate call.
    /// Alternatively they can use the off-spec overloaded `deposit` method.
    /// @inheritdoc IERC4626
    function deposit(uint assets_, address receiver_) external nonReentrant returns (uint) {
        return deposit(assets_, receiver_, minPrices[msg.sender]);
    }

    /// Overloaded `deposit` to allow `minPrice_` to be passed directly without
    /// the additional `setMinPrice` call, which saves gas and can provide a
    /// better UX overall.
    function deposit(uint assets_, address receiver_, uint minPrice_) public returns (uint) {
        uint price_ = priceOracle.price();
        uint shares_ = _calculateDeposit(assets_, price_, minPrice_);

        return _deposit(assets_, receiver_, shares_, price_);
    }

    function _deposit(uint assets_, address receiver_, uint shares_, uint price_) internal nonReentrant returns (uint) {
        emit IERC4626.Deposit(msg.sender, receiver_, assets_, shares_);

        IERC20(asset).safeTransfer(msg.sender, assets_);

        // erc20 mint.
        _mint(receiver_, shares_);

        // erc1155 mint.
        // Receiving contracts MUST implement `IERC1155Receiver`.
        _mint(receiver_, price_, shares_, "");

        return shares_;
    }

    /// @inheritdoc IERC4626
    function maxMint(address) external pure returns (uint) {
        return type(uint).max;
    }

    /// @inheritdoc IERC4626
    function previewMint(uint shares_) external view returns (uint) {
        return _calculateMint(shares_, priceOracle.price(), 0);
    }

    /// @inheritdoc IERC4626
    function mint(uint shares_, address receiver_) external returns (uint) {
        uint price_ = priceOracle.price();
        uint assets_ = _calculateMint(shares_, price_, minPrices[msg.sender]);
        _deposit(assets_, receiver_, shares_, price_);
        return assets_;
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address owner_) external view returns (uint) {
        return maxWithdraw(owner_, prices[owner_]);
    }

    /// Overloaded `maxWithdraw` that allows setting a price directly. The
    /// price needs to be provided so that we know which ERC1155 balance to
    /// check the withdraw against. The burnable ERC20 is capped per-withdraw
    /// to the balance of a price-bound ERC1155.
    /// @return max assets.
    function maxWithdraw(address owner_, uint price_) public view returns (uint) {
        return _calculateRedeem(balanceOf(owner_, price_), price_);
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint assets_) external view returns (uint) {
        return previewWithdraw(assets_, prices[msg.sender]);
    }

    function previewWithdraw(uint assets_, uint price_) public pure returns (uint) {
        return _calculateDeposit(assets_, price_, 0);
    }

    /// @inheritdoc IERC4626
    function withdraw(uint assets_, address receiver_, address owner_) external returns (uint) {
        return withdraw(assets_, receiver_, owner_, prices[owner_]);
    }

    function withdraw(uint assets_, address receiver_, address owner_, uint price_) public returns (uint) {
        return _withdraw(assets_, receiver_, owner_, price_);
    }

    function _withdraw(uint assets_, address receiver_, address owner_, uint price_) internal nonReentrant returns (uint) {
        uint shares_ = _calculateDeposit(assets_, price_, 0);
        emit IERC4626.Withdraw(msg.sender, receiver_, owner_, assets_, shares_);

        // erc20 burn.
        _burn(owner_, shares_);

        // erc1155 burn.
        _burn(owner_, price_, shares_);

        IERC20(asset).safeTransfer(receiver_, assets_);

        return shares_;
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address owner_) external view returns (uint) {
        return maxRedeem(owner_, prices[owner_]);
    }

    function maxRedeem(address owner_, uint price_) public view returns (uint) {
        return balanceOf(owner_, price_);
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint shares_) external view returns (uint) {
        return _calculateRedeem(shares_, prices[msg.sender]);
    }

    function previewRedeem(uint shares_, uint price_) public pure returns (uint) {
        return _calculateRedeem(shares_, price_);
    }

    /// @inheritdoc IERC4626
    function redeem(uint shares_, address receiver_, address owner_) external returns (uint) {
        return redeem(shares_, receiver_, owner_, prices[owner_]);
    }

    function redeem(uint shares_, address receiver_, address owner_, uint price_) public returns (uint) {
        uint assets_ = _calculateRedeem(shares_, price_);
        _withdraw(assets_, receiver_, owner_, price_);
        return assets_;
    }
}
