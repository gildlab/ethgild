// SPDX-License-Identifier: UNLICENSE
pragma solidity =0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "../../erc4626/IERC4626.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../../oracle/price/IPriceOracle.sol";
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
/// Note on use of price oracles:
/// At the time of writing Chainlink oracles seem to be "best in class" oracles
/// yet suffer from several points of centralisation and counterparty risk. As
/// there are no owner/admin keys on `ERC20PriceOracleVault` this represents an
/// existential risk to the system if the price feeds stop behaving correctly.
/// This is because the wrong number of shares will be minted upon deposit and
/// nobody can modify the oracle address read by the vault. Long term holders
/// of the share tokens are the most likely bagholders in the case of some
/// oracle degradation as the fundamental tokenomics could break in arbitrary
/// ways due to incorrect minting.
///
/// Oracles can be silently paused:
/// Such as during the UST depegging event when Luna price was misreported by
/// chainlink oracles. Chainlink oracles report timestamps since last update
/// but every oracle has its own "heartbeat" during which prices are able to
/// NOT update unless the price deviation target is hit. It is impossible to
/// know from onchain timestamps within a heartbeat whether a price deviation
/// has not been hit or if a price deviation has been hit but the feed is
/// paused. The impact of this is specific to the configuration of the feed
/// which is NOT visible onchain, for example at the time of writing ETH/USD
/// feed updates every block, which the XAU/USD feed has a 24 hour heartbeat.
/// These values were discovered offchain by the author.
///
/// Oracles are owned and can be modified:
/// The underlying aggregator for an oracle can be changed by the owner. A new
/// aggregator may have different heartbeat and deviance parameters, so an
/// already deployed guard against stale data could become overly conservative
/// and start blocking deposits unnecessarily, for example.
///
/// Mitigations:
/// The `IPriceOracle` contracts do their best to guard against stale or
/// invalid data by erroring which would pause all new depositing, while still
/// allowing withdrawing. The `ChainlinkFeedPriceOracle` also does its best to
/// read the onchain data that does exist such as `decimals` before converting
/// prices to 18 decimal fixed point values. The best case scenario under a
/// broken oracle is that most users become aware of what is happening and pull
/// their collateral. One problem is that the system is designed to force some
/// collateral to be "sticky" in the vault as different wallets hold the 1155
/// and 20 tokens, so co-ordinating them for redemption may be impossible. In
/// this case it MAY be possible to build anew vault contract that includes a
/// matchmaking service for the compromised vault, to redeem old collateral for
/// itself and reissue new tokens against itself. At the time of writing such a
/// migration path is NOT implemented.
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

    /// Emitted when deployed and constructed.
    /// @param caller `msg.sender` that deployed the contract.
    /// @param config All construction config.
    event Construction(address caller, ConstructionConfig config);

    /// @inheritdoc IERC4626
    address public immutable asset;

    /// The price oracle used for all minting calculations.
    IPriceOracle public immutable priceOracle;

    /// Users MAY OPTIONALLY set minimum prices for 4626 deposits. Alternatively
    /// they MAY avoid the gas cost of modifying storage and call the
    /// non-standard equivalent functions that take a minimum price parameter.
    mapping(address => uint256) public minPrices;

    /// Users MAY OPTIONALLY set the receipt price they want to withdraw as a
    /// two step workflow and call the 4626 standard withdraw functions.
    /// Alternatively they MAY avoid the gas cost of modifying storage and call
    /// the non-standard equivalent functions that take a price parameter.
    mapping(address => uint256) public withdrawPrices;

    /// Constructor.
    /// @param config_ All necessary config for deployment.
    constructor(ConstructionConfig memory config_)
        ERC20(config_.name, config_.symbol)
        ERC1155(config_.uri)
    {
        asset = config_.asset;
        priceOracle = IPriceOracle(config_.priceOracle);
        emit Construction(msg.sender, config_);
    }

    /// Calculate how many shares_ will be minted in return for assets_.
    /// @param assets_ Amount of assets being deposited.
    /// @param price_ The oracle price to deposit against.
    /// @param minPrice_ The minimum price required by the depositor. Will
    /// error if `price_` is less than `minPrice_`.
    /// @return shares_ Amount of shares to mint for this deposit.
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
    /// @param shares_ Amount of shares desired to be minted.
    /// @param price_ The oracle price to mint against.
    /// @param minPrice_ The minimum price required by the minter. Will error if
    /// `price_` is less than `minPrice_`.
    /// @return assets_ Amount of assets that must be deposited for this mint.
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
    /// @param assets_ Amount of assets being withdrawn.
    /// @param price_ Oracle price to withdraw against.
    /// @return shares_ Amount of shares to burn for this withdrawal.
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
    /// @param shares_ Amount of shares being burned for redemption.
    /// @param price_ Oracle price being redeemed against.
    /// @return assets_ Amount of assets that will be redeemed for the given
    /// shares.
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

    /// Any address can set their own minimum price.
    /// This is optional as the non-standard 4626 equivalent functions accept
    /// a minimum price parameter. This facilitates the 4626 interface by adding
    /// one additional initial transaction for the user.
    /// @param minPrice_ The new minimum price for the `msg.sender` to be used
    /// in subsequent deposit calls.
    function setMinPrice(uint256 minPrice_) external {
        minPrices[msg.sender] = minPrice_;
    }

    /// Any address can set their own price for withdrawals.
    /// This is optional as the non-standard 4626 equivalent functions accept
    /// a withdrawal price parameter. This facilitates the 4626 interface by
    /// adding one initial transaction for the user.
    /// @param price_ The new withdrawal price for the `msg.sender` to be used
    /// in subsequent withdrawal calls. If the price does NOT match the ID of
    /// a receipt held by sender then these subsequent withdrawals will fail.
    /// It is the responsibility of the caller to set the correct price.
    function setWithdrawPrice(uint256 price_) external {
        withdrawPrices[msg.sender] = price_;
    }

    /// @inheritdoc IERC4626
    function totalAssets() external view returns (uint256 assets_) {
        // There are NO fees so the managed assets are the asset balance of the
        // vault.
        try IERC20(asset).balanceOf(address(this)) returns (uint256 balance_) {
            assets_ = balance_;
        } catch {
            // It's not clear what the balance should be if querying it is
            // throwing an error. The conservative error in most cases should
            // be 0.
            assets_ = 0;
        }
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint256 assets_)
        external
        view
        returns (uint256 shares_)
    {
        // The oracle CAN error so we wrap in a try block to meet spec
        // requirement that calls MUST NOT revert.
        try priceOracle.price() returns (uint256 price_) {
            // minPrice of 0 ensures `_calculateDeposit` does NOT revert also.
            shares_ = _calculateDeposit(assets_, price_, 0);
        } catch {
            // Depositing assets while the price oracle is erroring will give 0
            // shares.
            shares_ = 0;
        }
    }

    /// This function is a bit weird because in reality everyone converts their
    /// shares to assets at the price they minted at, NOT the current price. But
    /// the spec demands that this function ignores per-user concerns.
    /// @inheritdoc IERC4626
    function convertToAssets(uint256 shares_)
        external
        view
        returns (uint256 assets_)
    {
        // The oracle CAN error so we wrap in a try block to meet spec
        // requirement that calls MUST NOT revert.
        try priceOracle.price() returns (uint256 price_) {
            assets_ = _calculateRedeem(shares_, price_);
        } catch {
            // If we have no price from the oracle then we cannot say that
            // shares are worth any amount of assets.
            assets_ = 0;
        }
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address) external pure returns (uint256 maxAssets_) {
        // The spec states to return this if there is no deposit limit.
        // Technically a deposit this large would almost certainly overflow
        // somewhere in the process, but it isn't a limit imposed by the vault
        // per-se, it's more that the ERC20 tokens themselves won't handle such
        // large entries on their internal balances. Given typical token
        // total supplies are smaller than this number, this would be a
        // theoretical point only.
        maxAssets_ = type(uint256).max;
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 assets_) external view returns (uint256) {
        return
            _calculateDeposit(
                assets_,
                priceOracle.price(),
                // IERC4626:
                // > MUST NOT revert due to vault specific user/global limits.
                // > MAY revert due to other conditions that would also cause
                // > deposit to revert.
                // Unclear if the min price set by the user for themselves is a
                // "vault specific user limit" or "other conditions that would
                // also cause deposit to revert".
                // The conservative interpretation is that the user will WANT
                // the preview calculation to revert according to their own
                // preferences they set for themselves onchain.
                minPrices[msg.sender]
            );
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
        return maxWithdraw(owner_, withdrawPrices[owner_]);
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
        return previewWithdraw(assets_, withdrawPrices[msg.sender]);
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
        return withdraw(assets_, receiver_, owner_, withdrawPrices[owner_]);
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
        return maxRedeem(owner_, withdrawPrices[owner_]);
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
        return _calculateRedeem(shares_, withdrawPrices[msg.sender]);
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
        return redeem(shares_, receiver_, owner_, withdrawPrices[owner_]);
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
