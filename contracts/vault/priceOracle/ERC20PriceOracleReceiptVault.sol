// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IERC20Upgradeable as IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ReceiptVaultConfig, VaultConfig, ReceiptVault, ShareAction} from "../receipt/ReceiptVault.sol";
import "../../oracle/price/IPriceOracleV1.sol";

/// All the same config as `ERC20PriceOracleReceiptVaultConfig` but without the
/// receipt. Typically the receipt will be deployed and ownership transferred
/// atomically by a factory to build the full config.
/// @param priceOracle as per `ERC20PriceOracleReceiptVaultConfig`.
/// @param vaultConfig config for the underlying `ReceiptVault`.
struct ERC20PriceOracleVaultConfig {
    address priceOracle;
    VaultConfig vaultConfig;
}

/// @param priceOracle The price oracle that will be permanently bound to the
/// `ERC20PriceOracleVault` upon initialization.
/// @param receiptVaultConfig All config for the underlying receipt vault.
struct ERC20PriceOracleReceiptVaultConfig {
    address priceOracle;
    ReceiptVaultConfig receiptVaultConfig;
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
/// irrelevant to withdrawals, only the receipt price is relevant.
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
/// `ERC20PriceOracleVault` shares are useful primitives that convert a valuable
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
/// but every oracle has its own "heartbeat" during which prices are allowed to
/// NOT update unless the price deviation target is hit. It is impossible to
/// know from onchain timestamps within a heartbeat whether a price deviation
/// has not been hit or if a price deviation has been hit but the feed is
/// paused. The impact of this is specific to the configuration of the feed
/// which is NOT visible onchain, for example at the time of writing ETH/USD
/// feed updates every block, which the XAU/USD feed has a 24 hour heartbeat.
/// Even if we read the current values that may be defined in the code of the
/// oracle contract (but are not exposed via the interface to be read from other
/// contracts) and set the same values in our contract, the upstream values can
/// be changed at any time through a contract upgrade. As Chainlink admins are
/// a company acting on instruction from clients (how the example UST price
/// pausing came into being) it's relatively easy for someone to request a
/// pause threshold to be added, changed or removed at any time.
///
/// Oracles are owned and can be modified:
/// The underlying aggregator for an oracle can be changed by the owner. A new
/// aggregator may have different heartbeat and deviance parameters, so an
/// already deployed guard against stale data could become overly conservative
/// and start blocking deposits unnecessarily. Eventually the oracle should hit
/// a heartbeat and/or threshold and update, allowing mints once more, but it
/// would be an unfortunate situation if mints were regularly disabled simply due
/// to upstream configuration.
///
/// Mitigations:
/// The `IPriceOracleV1` contracts do their best to guard against stale or
/// invalid data by erroring which would pause all new depositing, while still
/// allowing withdrawals. The `ChainlinkFeedPriceOracle` also does its best to
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
contract ERC20PriceOracleReceiptVault is ReceiptVault {
    /// Emitted when deployed and constructed.
    /// @param sender `msg.sender` that deployed the contract.
    /// @param config All construction config.
    event ERC20PriceOracleReceiptVaultInitialized(
        address sender,
        ERC20PriceOracleReceiptVaultConfig config
    );

    /// The price oracle used for all minting calculations.
    IPriceOracleV1 public priceOracle;

    /// Initialization of the underlying receipt vault and price oracle.
    function initialize(
        ERC20PriceOracleReceiptVaultConfig memory config_
    ) external initializer {
        __ReceiptVault_init(config_.receiptVaultConfig);
        priceOracle = IPriceOracleV1(config_.priceOracle);
        emit ERC20PriceOracleReceiptVaultInitialized(msg.sender, config_);
    }

    /// The ID is the current oracle price always, even if this ID has already
    /// been issued for some other receipt, it will simply result in multiple
    /// holders of receipts with amounts of the same ID.
    /// @inheritdoc ReceiptVault
    function _nextId() internal view virtual override returns (uint256) {
        // The oracle CAN error so we wrap in a try block to meet spec
        // requirement that calls MUST NOT revert.
        try priceOracle.price() returns (
            // slither puts false positives on `try/catch/returns`.
            // https://github.com/crytic/slither/issues/511
            //slither-disable-next-line
            uint256 price_
        ) {
            return price_;
        } catch {
            // Depositing assets while the price oracle is erroring will give 0
            // shares (a real deposit will revert due to 0 ratio).
            return 0;
        }
    }

    /// The ID-less share ratio is the current oracle price, which will be the
    /// ID in the case of a real deposit.
    /// @inheritdoc ReceiptVault
    function _shareRatioUserAgnostic(
        uint256 id_,
        ShareAction
    ) internal view virtual override returns (uint256) {
        return id_;
    }
}
