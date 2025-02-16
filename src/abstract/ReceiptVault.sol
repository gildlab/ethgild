// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20Upgradeable as ERC20} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable as ReentrancyGuard} from
    "openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import {IERC20Upgradeable as IERC20} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable as SafeERC20} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {MulticallUpgradeable as Multicall} from
    "openzeppelin-contracts-upgradeable/contracts/utils/MulticallUpgradeable.sol";
import {IReceiptVaultV2, IReceiptVaultV1, IReceiptV2} from "../interface/IReceiptVaultV2.sol";
import {IReceiptManagerV2} from "../interface/IReceiptManagerV2.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/interface/ICloneableV2.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {
    InvalidId,
    ZeroReceiver,
    MinShareRatio,
    ZeroAssetsAmount,
    ZeroOwner,
    ZeroSharesAmount,
    WrongManager
} from "../error/ErrReceiptVault.sol";
import {UnmanagedReceiptTransfer} from "../interface/IReceiptManagerV2.sol";

/// Represents the action being taken on shares, ostensibly for calculating a
/// ratio.
enum ShareAction {
    Mint,
    Burn
}

/// Config for the _implementation_ of the `ReceiptVault` contract.
/// @param factory The factory that will be used to clone the receipt vault.
/// @param receiptImplementation The receipt implementation that will be cloned
/// by the factory.
struct ReceiptVaultConstructionConfig {
    ICloneableFactoryV2 factory;
    IReceiptV2 receiptImplementation;
}

/// All config required to initialize `ReceiptVault` except the receipt address.
/// Included as a field on `ReceiptVaultConfig` which is the full initialization
/// config struct. This is used by the `ReceiptVaultFactory` which will create a
/// new receipt in the same transaction and build the full `ReceiptVaultConfig`.
/// @param asset As per ERC4626.
/// @param name As per ERC20.
/// @param symbol As per ERC20.
struct VaultConfig {
    address asset;
    string name;
    string symbol;
}

/// All config required to initialize `ReceiptVault`.
/// @param receipt The `Receipt` e.g. built by `ReceiptVaultFactory` that is
/// owned by the `ReceiptVault` as an `IReceiptOwnerV1`.
/// @param vaultConfig all the vault configuration as `VaultConfig`.
struct ReceiptVaultConfig {
    address receipt;
    VaultConfig vaultConfig;
}

/// @title ReceiptVault
/// @notice The workhorse that binds several abstract concepts together into the
/// specific concrete implemenation of our working system.
///
/// - Implementing an ERC4626 standard vault with assets and shares
/// - where the shares are minted 1:1 with an ERC1155 receipt NFT across many IDs
/// - and each ID is associated with a specific deposit event
/// - that records arbitrary offchain data for decentralised commentary per-ID
/// - such that shares can be freely treated as standard onchain fungible assets
/// - and can be burned at any time, but only 1:1 with their creation event
/// - by forcing the burner to hold and burn both a receipt and some shares for
///   every burn.
///
/// The specifics of share/asset ratios on mints/burns, additional authorization
/// logic, transfer restrictions, etc. are all extensible and overridable through
/// inheritance and standard Open Zeppelin hooks from the underlying contracts.
///
/// Note that the receipt implementation is a separate contract as we found
/// during development that combining ERC20 and ERC1155 on a single contract
/// resulted in poor tooling/wallet support offchain (e.g. MetaMask).
/// Conceptually it is reasonable to consider the minted shares and receipts as
/// a single unit, forming a singular hybrid token model.
///
/// Note also that neither the receipt nor the shares are intended to represent
/// "ownership", whatever that means in your local legal/cultural bubble. The
/// receipt merely represents a right (or perhaps even responsibility) to burn
/// shares, and the shares only represent an expectation that assets associated
/// with the shares' mint event DO NOT MOVE (whatever that means) until/unless
/// those shares are burned.
///
/// Each vault is deployed from a factory as a clone from a reference
/// implementation, allowing for the model to cheaply and freedomly scale
/// horizontally. This allows for some trust/permissioned concessions to be made
/// per-vault as new competing vaults can always be deployed and traded against
/// each other in parallel, allowing trust to be "policed" at the liquidity and
/// free market layer.
abstract contract ReceiptVault is
    IReceiptManagerV2,
    Multicall,
    ReentrancyGuard,
    ERC20,
    IReceiptVaultV2,
    ICloneableV2
{
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;
    using SafeERC20 for IERC20;

    ICloneableFactoryV2 internal immutable iFactory;
    IReceiptV2 internal immutable iReceiptImplementation;

    /// Underlying ERC4626 asset.
    IERC20 internal sAsset;
    /// ERC1155 Receipt owned by this receipt vault for the purpose of tracking
    /// mints and enforcing integrity of subsequent burns.
    IReceiptV2 internal sReceipt;

    /// `ReceiptVault` is intended to be cloned and initialized by a
    /// `ReceiptVaultFactory` so is an implementation contract that can't itself
    /// be initialized.
    constructor(ReceiptVaultConstructionConfig memory config) {
        _disableInitializers();

        iFactory = config.factory;
        iReceiptImplementation = config.receiptImplementation;
    }

    /// Deposits are payable so this allows refunds.
    fallback() external payable {}

    /// Deposits are payable so this allows refunds.
    receive() external payable {}

    /// Initialize the `ReceiptVault`.
    /// @param config All config required for initialization.
    // solhint-disable-next-line func-name-mixedcase
    // slither-disable-next-line naming-convention
    function __ReceiptVault_init(VaultConfig memory config) internal virtual {
        __Multicall_init();
        __ReentrancyGuard_init();
        __ERC20_init(config.name, config.symbol);
        sAsset = IERC20(config.asset);

        // Slither false positive here due to it being impossible to set the
        // receipt before it has been deployed.
        // slither-disable-next-line reentrancy-benign
        IReceiptV2 managedReceipt =
            IReceiptV2(iFactory.clone(address(iReceiptImplementation), abi.encode(address(this))));
        sReceipt = managedReceipt;

        // Sanity check here. Should always be true as we cloned the receipt
        // from the factory ourselves just above.
        address receiptManager = managedReceipt.manager();
        if (receiptManager != address(this)) {
            revert WrongManager(address(this), receiptManager);
        }
    }

    /// @inheritdoc IReceiptVaultV1
    function asset() public view virtual returns (address) {
        return address(sAsset);
    }

    /// @inheritdoc IReceiptManagerV2
    function authorizeReceiptTransfer3(address from, address to, uint256[] memory ids, uint256[] memory amounts)
        public
        virtual
    {
        if (msg.sender != address(receipt())) {
            revert UnmanagedReceiptTransfer();
        }
        (from, to, ids, amounts);
    }

    /// The spec demands this function ignores per-user concerns. It seems to
    /// imply minting but doesn't provide a sibling conversion for burning.
    /// > The amount of shares that the Vault would exchange for the amount of
    /// > assets provided
    /// @inheritdoc IReceiptVaultV1
    function convertToShares(uint256 assets, uint256 id) external payable returns (uint256) {
        uint256 val = _calculateDeposit(assets, _shareRatioUserAgnostic(id, ShareAction.Mint), 0);
        Address.sendValue(payable(msg.sender), address(this).balance);
        return val;
    }

    /// The spec demands that this function ignores per-user concerns. It seems
    /// to imply burning but doesn't provide a sibling conversion for minting.
    /// > The amount of assets that the Vault would exchange for the amount of
    /// > shares provided
    /// @inheritdoc IReceiptVaultV1
    function convertToAssets(uint256 shares, uint256 id) external view virtual returns (uint256) {
        return _calculateRedeem(
            shares,
            // Not clear what a good ID for a hypothetical context free burn
            // should be. Next ID is technically nonsense but we don't have
            // any other ID to prefer either.
            _shareRatioUserAgnostic(id, ShareAction.Burn)
        );
    }

    /// @inheritdoc IReceiptVaultV2
    function receipt() public view virtual returns (IReceiptV2) {
        return sReceipt;
    }

    /// @inheritdoc IReceiptVaultV1
    function previewDeposit(uint256 assets, uint256 minShareRatio) external payable virtual returns (uint256) {
        uint256 val = _calculateDeposit(
            assets,
            // Spec doesn't provide us with a receipient but wants a per-user
            // preview so we assume that depositor = receipient.
            _shareRatio(msg.sender, msg.sender, _nextId(), ShareAction.Mint),
            // IERC4626:
            // > MUST NOT revert due to vault specific user/global limits.
            // > MAY revert due to other conditions that would also cause
            // > deposit to revert.
            // Unclear if the min share ratio set by the user for themselves
            // is a "vault specific user limit" or "other conditions that
            // would also cause deposit to revert".
            // The conservative interpretation is that the user will WANT
            // the preview calculation to revert according to their own
            // preferences they set for themselves onchain.
            // If the user did not set a min ratio then the min ratio will
            // be 0 and never revert.
            minShareRatio
        );
        Address.sendValue(payable(msg.sender), address(this).balance);
        return val;
    }

    /// @inheritdoc IReceiptVaultV1
    function previewMint(uint256 shares, uint256 minShareRatio) external payable virtual returns (uint256) {
        uint256 val = _calculateMint(
            shares,
            // Spec doesn't provide us with a recipient but wants a per-user
            // preview so we assume that depositor = recipient.
            _shareRatio(msg.sender, msg.sender, _nextId(), ShareAction.Mint),
            // IERC4626:
            // > MUST NOT revert due to vault specific user/global limits.
            // > MAY revert due to other conditions that would also cause mint
            // > to revert.
            // Unclear if the min share ratio set by the user for themselves is
            // a "vault specific user limit" or "other conditions that would
            // also cause mint to revert".
            // If the user did not set a min ratio the min ratio will be 0 and
            // never revert.
            minShareRatio
        );
        Address.sendValue(payable(msg.sender), address(this).balance);
        return val;
    }

    /// @inheritdoc IReceiptVaultV1
    function deposit(uint256 assets, address receiver, uint256 depositMinShareRatio, bytes memory receiptInformation)
        external
        payable
        returns (uint256)
    {
        uint256 id = _nextId();

        uint256 shares =
            _calculateDeposit(assets, _shareRatio(msg.sender, receiver, id, ShareAction.Mint), depositMinShareRatio);

        _deposit(assets, receiver, shares, id, receiptInformation);
        Address.sendValue(payable(msg.sender), address(this).balance);
        return shares;
    }

    /// @inheritdoc IReceiptVaultV1
    function mint(uint256 shares, address receiver, uint256 mintMinShareRatio, bytes memory receiptInformation)
        external
        payable
        returns (uint256)
    {
        uint256 id = _nextId();

        uint256 assets =
            _calculateMint(shares, _shareRatio(msg.sender, receiver, id, ShareAction.Mint), mintMinShareRatio);

        _deposit(assets, receiver, shares, id, receiptInformation);
        Address.sendValue(payable(msg.sender), address(this).balance);
        return assets;
    }

    /// Similar to `receiptInformation` on the underlying receipt but for this
    /// vault. Anyone can call this and provide any information. Indexers and
    /// clients MUST take care against corrupt and malicious data.
    /// @param vaultInformation The information to emit for this vault.
    function receiptVaultInformation(bytes memory vaultInformation) external virtual {
        emit ReceiptVaultInformation(msg.sender, vaultInformation);
    }

    /// Standard check to enforce the minimum share ratio. If the share ratio is
    /// less than the minimum the transaction will revert with `MinShareRatio`.
    /// @param minShareRatio The share ratio must be at least this.
    /// @param shareRatio The actual share ratio.
    function checkMinShareRatio(uint256 minShareRatio, uint256 shareRatio) internal pure {
        if (shareRatio < minShareRatio) {
            revert MinShareRatio(minShareRatio, shareRatio);
        }
    }

    /// Calculate how many `shares` will be minted in return for `assets` as
    /// per ERC4626 deposit logic.
    /// @param assets Amount of assets being deposited.
    /// @param shareRatio The ratio of shares to assets to deposit against.
    /// @param depositMinShareRatio The minimum share ratio required by the
    /// depositor. Will error if `shareRatio` is less than
    /// `depositMinShareRatio`.
    /// @return shares Amount of shares to mint for this deposit.
    function _calculateDeposit(uint256 assets, uint256 shareRatio, uint256 depositMinShareRatio)
        internal
        pure
        virtual
        returns (uint256)
    {
        checkMinShareRatio(depositMinShareRatio, shareRatio);

        // IRC4626:
        // If (1) it’s calculating how many shares to issue to a user for a
        // certain amount of the underlying tokens they provide, it should
        // round down.
        return assets.fixedPointMul(shareRatio, Math.Rounding.Down);
    }

    /// Calculate how many `assets` are needed to mint `shares` as per ERC4626
    /// mint logic.
    /// @param shares Amount of shares desired to be minted.
    /// @param shareRatio The ratio shares are minted at per asset.
    /// @param mintMinShareRatio The minimum ratio required by the minter. Will
    /// error if `shareRatio` is less than `mintMinShareRatio`.
    /// @return assets Amount of assets that must be deposited for this mint.
    function _calculateMint(uint256 shares, uint256 shareRatio, uint256 mintMinShareRatio)
        internal
        view
        virtual
        returns (uint256)
    {
        checkMinShareRatio(mintMinShareRatio, shareRatio);

        // IERC4626:
        // If (2) it’s calculating the amount of underlying tokens a user has
        // to provide to receive a certain amount of shares, it should
        // round up.
        return shares.fixedPointDiv(shareRatio, Math.Rounding.Up);
    }

    /// Calculate how many `shares` to burn to withdraw `assets` as per ERC4626
    /// withdraw logic.
    /// @param assets Amount of assets being withdrawn.
    /// @param shareRatio Ratio of shares to assets to withdraw against.
    /// @return shares Amount of shares to burn for this withdrawal.
    function _calculateWithdraw(uint256 assets, uint256 shareRatio) internal pure virtual returns (uint256) {
        // IERC4626:
        // If (1) it’s calculating the amount of shares a user has to supply to
        // receive a given amount of the underlying tokens, it should round up.
        return assets.fixedPointMul(shareRatio, Math.Rounding.Up);
    }

    /// Calculate how many `assets` to withdraw for burning `shares` as per
    /// ERC4626 redeem logic.
    /// @param shares Amount of shares being burned for redemption.
    /// @param shareRatio Ratio of shares to assets being redeemed against.
    /// @return assets Amount of assets that will be redeemed for the given
    /// shares.
    function _calculateRedeem(uint256 shares, uint256 shareRatio) internal pure virtual returns (uint256) {
        // IERC4626:
        // If (2) it’s determining the amount of the underlying tokens to
        // transfer to them for returning a certain amount of shares, it should
        // round down.
        return shares.fixedPointDiv(shareRatio, Math.Rounding.Down);
    }

    /// This is external NOT public. It is NOT allowed to revert BUT if we were
    /// to calculate anything important internally with this we'd need it to
    /// revert if there was an issue reading total assets.
    /// @inheritdoc IReceiptVaultV1
    function totalAssets() external view virtual returns (uint256) {
        // There are NO fees so the managed assets are the asset balance of the
        // vault.
        try IERC20(asset()).balanceOf(address(this))
        // slither puts false positives on `try/catch/returns`.
        // https://github.com/crytic/slither/issues/511
        //slither-disable-next-line
        returns (uint256 assetBalance) {
            return assetBalance;
        } catch {
            // It's not clear what the balance should be if querying it is
            // throwing an error. The conservative error in most cases should
            // be 0.
            return 0;
        }
    }

    /// Define the ratio that shares are minted and burned per asset for both
    /// deposit/mint and withdraw/redeem. The rounding will be function specific
    /// as per ERC4626 when the ratio is applied to an absolute value, but the
    /// ratio is defined in terms of who and what is being minted/burned. Sender
    /// is available as `msg.sender` so is NOT an argument to this function.
    /// Share ratios are always number of shares per unit of assets in both mint
    /// and burn scenarios, and are 18 decimal fixed point numbers.
    ///
    /// @param owner The owner of assets deposited on deposit and owner of
    /// shares burned on withdraw.
    /// @param receiver The receiver of new shares minted on deposit and of
    /// withdrawn assets on withdraw.
    /// @param id The receipt ID being minted/burned in tandem with the shares.
    /// @param shareAction Encodes whether shares are being minted or burned
    /// (hypothetically or actually) for this ratio calculation.
    /// @return
    function _shareRatio(address owner, address receiver, uint256 id, ShareAction shareAction)
        internal
        view
        virtual
        returns (uint256)
    {
        (owner, receiver);
        return _shareRatioUserAgnostic(id, shareAction);
    }

    /// Some functions in ERC4626 mandate the share ratio ignore the user.
    /// Otherwise identical to `_shareRatio`.
    /// @param id As per `_shareRatio`.
    /// @param shareAction As per `_shareRatio`.
    function _shareRatioUserAgnostic(uint256 id, ShareAction shareAction) internal view virtual returns (uint256) {
        (id, shareAction);
        // Default is 1:1 shares to assets.
        return 1e18;
    }

    /// Defines the next ID that a deposit will mint shares and receipts under.
    /// This MUST NOT be set by `msg.sender` as the `ReceiptVault` itself is
    /// responsible for managing the ID values that bind the minted shares and
    /// the associated receipt. These ID values are NOT necessarily meaningful
    /// to the asset depositor they purely bind mints to future potential burns.
    /// ID values that are meaningful to the depositor can be encoded in the
    /// receipt information that is emitted for offchain indexing via events.
    /// The default behaviour is to bind every mint and burn to the same ID, i.e.
    /// the ID is always `1`. This is almost certainly NOT desired behaviour so
    /// inheriting contracts will need to provide an override.
    /// Used inside ERC4626 functions that MUST NOT REVERT therefore this also
    /// MUST NOT REVERT. However, ID 0 is treated as invalid by default so
    /// returning 0 will revert where it needs to in the default implementation.
    // Not sure why slither flags this as dead code. It is used by both `deposit`
    // and `mint`.
    //slither-disable-next-line dead-code
    function _nextId() internal virtual returns (uint256) {
        return 1;
    }

    /// @inheritdoc IReceiptVaultV1
    function maxDeposit(address) external pure virtual returns (uint256) {
        // The spec states to return this if there is no deposit limit.
        // Technically a deposit this large would almost certainly overflow
        // somewhere in the process, but it isn't a limit imposed by the vault
        // per-se, it's more that the ERC20 tokens themselves won't handle such
        // large entries on their internal balances. Given typical token
        // total supplies are smaller than this number, this would be a
        // theoretical point only.
        return type(uint256).max;
    }

    /// @inheritdoc IReceiptVaultV1
    function maxMint(address) external pure virtual returns (uint256) {
        return type(uint256).max;
    }

    /// Handles minting and emitting events according to spec.
    /// It does NOT do any calculations so shares and assets need to be handled
    /// correctly according to spec including rounding, in the calling context.
    /// Depositing reentrantly is never ok so we restrict that here in the
    /// internal function rather than on the external methods.
    /// @param assets As per IERC4626 `deposit`.
    /// @param receiver As per IERC4626 `deposit`.
    /// @param shares Amount of shares to mint for receiver. MAY be different
    /// due to rounding in different contexts so caller MUST calculate
    /// according to the rounding specification.
    /// @param id ID of the 1155 receipt and MUST be provided on withdrawal.
    /// @param receiptInformation As per `Receipt` receipt information.
    function _deposit(uint256 assets, address receiver, uint256 shares, uint256 id, bytes memory receiptInformation)
        internal
        virtual
        nonReentrant
    {
        //slither-disable-next-line incorrect-equality
        if (assets == 0) {
            revert ZeroAssetsAmount();
        }
        //slither-disable-next-line incorrect-equality
        if (shares == 0) {
            revert ZeroSharesAmount();
        }
        if (receiver == address(0)) {
            revert ZeroReceiver();
        }
        //slither-disable-next-line incorrect-equality
        if (id == 0) {
            revert InvalidId(0);
        }

        emit IReceiptVaultV1.Deposit(msg.sender, receiver, assets, shares, id, receiptInformation);
        _beforeDeposit(assets, receiver, shares, id, receiptInformation);

        // erc20 mint.
        // Slither flags this as reentrant but this function has `nonReentrant`
        // on it from `ReentrancyGuard`.
        //slither-disable-next-line reentrancy-vulnerabilities-3 reentrancy-vulnerabilities-2
        _mint(receiver, shares);

        // erc1155 mint.
        // Receiving contracts MUST implement `IERC1155Receiver`.
        receipt().managerMint(msg.sender, receiver, id, shares, receiptInformation);
    }

    /// Hook for additional actions that MUST complete or revert before deposit
    /// is complete. This hook is responsible for any transfer of assets from
    /// the `msg.sender` to the receipt vault IN ADDITION to any other checks that
    /// may revert. As per 4626 the owner of the assets being deposited is always
    /// the `msg.sender`.
    /// @param assets Number of assets being deposited.
    /// !param receiver Receiver of shares that will be minted.
    /// !param shares Amount of shares that will be minted.
    /// !param id Recipt ID that will be minted for this deposit.
    function _beforeDeposit(
        uint256 assets,
        address receiver,
        uint256 shares,
        uint256 id,
        bytes memory receiptInformation
    ) internal virtual {
        // Default behaviour is to move assets before minting shares.
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), assets);
        (receiver, shares, id, receiptInformation);
    }

    /// @inheritdoc IReceiptVaultV1
    function maxWithdraw(address owner, uint256 id) external view virtual returns (uint256) {
        // Using `_calculateRedeem` instead of `_calculateWithdraw` becuase the
        // latter requires knowing the assets being withdrawn, which is what we
        // are attempting to reverse engineer from the owner's receipt balance.
        return _calculateRedeem(
            receipt().balanceOf(owner, id),
            // Assume the owner is hypothetically withdrawing for themselves.
            _shareRatio(owner, owner, id, ShareAction.Burn)
        );
    }

    /// @inheritdoc IReceiptVaultV1
    function previewWithdraw(uint256 assets, uint256 id) external view virtual returns (uint256) {
        return _calculateWithdraw(
            assets,
            // Assume that owner and receiver are the sender for a preview
            _shareRatio(msg.sender, msg.sender, id, ShareAction.Burn)
        );
    }

    /// @inheritdoc IReceiptVaultV1
    function withdraw(uint256 assets, address receiver, address owner, uint256 id, bytes memory receiptInformation)
        external
        virtual
        returns (uint256)
    {
        uint256 shares = _calculateWithdraw(assets, _shareRatio(owner, receiver, id, ShareAction.Burn));
        _withdraw(assets, receiver, owner, shares, id, receiptInformation);
        return shares;
    }

    /// Handles burning shares, withdrawing assets and emitting events to spec.
    /// It does NOT do any calculations so shares and assets need to be correct
    /// according to spec including rounding, in the calling context.
    /// Withdrawing reentrantly is never ok so we restrict that here in the
    /// internal function rather than on the external methods.
    /// @param assets As per IERC4626 `withdraw`.
    /// @param receiver As per IERC4626 `withdraw`.
    /// @param owner As per IERC4626 `withdraw`.
    /// @param shares Caller MUST calculate the correct shares to burn for
    /// withdrawal at `shareRatio_`. It is caller's responsibility to handle
    /// rounding correctly as per 4626 spec.
    /// @param id The receipt id to withdraw against. The owner MUST hold the
    /// receipt for the ID in addition to the shares being burned for
    /// withdrawal.
    /// @param receiptInformation New receipt information for the withdraw.
    function _withdraw(
        uint256 assets,
        address receiver,
        address owner,
        uint256 shares,
        uint256 id,
        bytes memory receiptInformation
    ) internal nonReentrant {
        //slither-disable-next-line incorrect-equality
        if (assets == 0) {
            revert ZeroAssetsAmount();
        }
        //slither-disable-next-line incorrect-equality
        if (shares == 0) {
            revert ZeroSharesAmount();
        }
        if (receiver == address(0)) {
            revert ZeroReceiver();
        }
        if (owner == address(0)) {
            revert ZeroOwner();
        }
        if (id == 0) {
            revert InvalidId(id);
        }

        emit IReceiptVaultV1.Withdraw(msg.sender, receiver, owner, assets, shares, id, receiptInformation);

        // IERC4626:
        // > MUST support a withdraw flow where the shares are burned from owner
        // > directly where owner is msg.sender or msg.sender has ERC-20
        // > approval over the shares of owner.
        if (owner != msg.sender) {
            _spendAllowance(owner, msg.sender, shares);

            // We additionally require that the sender is an operator of the
            // receipt in order to burn the owner's shares.
            // Same error message as Open Zeppelin ERC1155 implementation.
            require(receipt().isApprovedForAll(owner, msg.sender), "ERC1155: caller is not token owner or approved");
        }

        // ERC20 burn.
        _burn(owner, shares);

        // ERC1155 burn.
        receipt().managerBurn(msg.sender, owner, id, shares, receiptInformation);

        // Hook to allow additional withdrawal checks.
        _afterWithdraw(assets, receiver, owner, shares, id, receiptInformation);
    }

    /// @inheritdoc IReceiptVaultV1
    function maxRedeem(address owner, uint256 id) external view virtual returns (uint256) {
        return receipt().balanceOf(owner, id);
    }

    /// @inheritdoc IReceiptVaultV1
    function previewRedeem(uint256 shares, uint256 id) external view virtual returns (uint256) {
        return _calculateRedeem(shares, _shareRatio(msg.sender, msg.sender, id, ShareAction.Burn));
    }

    /// @inheritdoc IReceiptVaultV1
    function redeem(uint256 shares, address receiver, address owner, uint256 id, bytes memory receiptInformation)
        external
        virtual
        returns (uint256)
    {
        uint256 assets = _calculateRedeem(shares, _shareRatio(owner, receiver, id, ShareAction.Burn));
        _withdraw(assets, receiver, owner, shares, id, receiptInformation);
        return assets;
    }

    /// @inheritdoc ERC20
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
    }

    /// Hook that can be overridden/extended to add additional checks and
    /// effects to the `withdraw` function. This hook is called after the shares
    /// have been burned and the receipt has been burned. The default behaviour
    /// is to transfer the assets to the receiver.
    /// @param assets Amount of assets being withdrawn.
    /// @param receiver Receiver of the withdrawn assets.
    /// @param owner Owner of the shares being burned.
    /// @param shares Amount of shares being burned.
    /// @param id ID of the receipt being burned.
    /// @param receiptInformation New receipt information for the withdraw.
    function _afterWithdraw(
        uint256 assets,
        address receiver,
        address owner,
        uint256 shares,
        uint256 id,
        bytes memory receiptInformation
    ) internal virtual {
        // Default is to send assets after burning shares.
        IERC20(asset()).safeTransfer(receiver, assets);
        (owner, shares, id, receiptInformation);
    }
}
