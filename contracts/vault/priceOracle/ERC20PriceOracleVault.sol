// SPDX-License-Identifier: UNLICENSE
pragma solidity =0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReceiptVaultConstructionConfig, ReceiptVault} from "../ReceiptVault.sol";
import "../../oracle/price/IPriceOracle.sol";

/// All config required to construct `ERC20PriceOracleVault`.
/// @param asset `ERC4626` underlying asset.
/// @param name `ERC20` name for `ERC4626` shares.
/// @param symbol `ERC20` symbol for `ERC4626` shares.
/// @param uri `ERC1155` uri for deposit receipts.
/// @param address `IPriceOracle` oracle to define share mints upon deposit.
struct ERC20PriceOracleVaultConstructionConfig {
    address priceOracle;
    ReceiptVaultConstructionConfig receiptVaultConfig;
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
contract ERC20PriceOracleVault is ReceiptVault {
    /// Emitted when deployed and constructed.
    /// @param caller `msg.sender` that deployed the contract.
    /// @param config All construction config.
    event ERC20PriceOracleVaultConstruction(
        address caller,
        ERC20PriceOracleVaultConstructionConfig config
    );

    /// The price oracle used for all minting calculations.
    IPriceOracle public immutable priceOracle;

    /// Constructor.
    /// @param config_ All necessary config for deployment.
    constructor(ERC20PriceOracleVaultConstructionConfig memory config_)
        ReceiptVault(config_.receiptVaultConfig)
    {
        priceOracle = IPriceOracle(config_.priceOracle);
        emit ERC20PriceOracleVaultConstruction(msg.sender, config_);
    }

    /// @inheritdoc ReceiptVault
    function _nextId() internal view override returns (uint256 id_) {
        id_ = priceOracle.price();
    }

    function _shareRatio()
        internal
        view
        override
        returns (uint256 shareRatio_)
    {
        // The oracle CAN error so we wrap in a try block to meet spec
        // requirement that calls MUST NOT revert.
        try priceOracle.price() returns (uint256 price_) {
            shareRatio_ = price_;
        } catch {
            // Depositing assets while the price oracle is erroring will give 0
            // shares (it will revert due to 0 ratio).
            shareRatio_ = 0;
        }
    }

    function _shareRatioForId(uint256 id_)
        internal
        pure
        override
        returns (uint256 shareRatio_)
    {
        shareRatio_ = id_;
    }
}
