// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ERC20Upgradeable as ERC20, ERC20SnapshotUpgradeable as ERC20Snapshot} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
import {IERC4626Upgradeable as IERC4626} from "@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable.sol";
import {ReentrancyGuardUpgradeable as ReentrancyGuard} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IERC20Upgradeable as IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable as SafeERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {MulticallUpgradeable as Multicall} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import "./IReceiptV1.sol";
import "@rainprotocol/rain-protocol/contracts/math/FixedPointMath.sol";
import "./IReceiptOwnerV1.sol";

struct VaultConfig {
    address asset;
    string name;
    string symbol;
}

struct ReceiptVaultConfig {
    address receipt;
    VaultConfig vaultConfig;
}

contract ReceiptVault is
    IReceiptOwnerV1,
    Multicall,
    ReentrancyGuard,
    ERC20Snapshot,
    IERC4626
{
    using FixedPointMath for uint256;
    using SafeERC20 for IERC20;

    /// Similar to IERC4626 deposit but with receipt ID and information.
    /// @param sender As per `IERC4626.Deposit`.
    /// @param owner As per `IERC4626.Deposit`.
    /// @param assets As per `IERC4626.Deposit`.
    /// @param shares As per `IERC4626.Deposit`.
    /// @param id As per `IERC1155.TransferSingle`.
    /// @param receiptInformation As per `ReceiptInformation`.
    event DepositWithReceipt(
        address sender,
        address owner,
        uint256 assets,
        uint256 shares,
        uint256 id,
        bytes receiptInformation
    );

    /// Similar to IERC4626 withdraw but with receipt ID.
    /// @param sender As per `IERC4626.Withdraw`.
    /// @param receiver As per `IERC4626.Withdraw`.
    /// @param owner As per `IERC4626.Withdraw`.
    /// @param assets As per `IERC4626.Withdraw`.
    /// @param shares As per `IERC4626.Withdraw`.
    /// @param id As per `IERC1155.TransferSingle`.
    event WithdrawWithReceipt(
        address sender,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares,
        uint256 id
    );

    IERC20 internal _asset;
    IReceiptV1 internal _receipt;

    /// Senders MAY OPTIONALLY set minimum share ratios for 4626 deposits.
    /// Alternatively they MAY avoid the gas cost of modifying storage and call
    /// the non-standard equivalent functions that take a minimum share ratio
    /// parameter.
    mapping(address => uint256) public minShareRatios;

    /// Users MAY OPTIONALLY set the receipt ID they want to withdraw as a
    /// two step workflow and call the 4626 standard withdraw functions.
    /// Alternatively they MAY avoid the gas cost of modifying storage and call
    /// the non-standard equivalent functions that take a ID parameter.
    mapping(address => uint256) public withdrawIds;

    constructor() {
        _disableInitializers();
    }

    // solhint-disable-next-line func-name-mixedcase
    function __ReceiptVault_init(
        ReceiptVaultConfig memory config_
    ) internal virtual {
        __Multicall_init();
        __ReentrancyGuard_init();
        __ERC20_init(config_.vaultConfig.name, config_.vaultConfig.symbol);
        _asset = IERC20(config_.vaultConfig.asset);
        _receipt = IReceiptV1(config_.receipt);
    }

    /// @inheritdoc IReceiptOwnerV1
    function authorizeReceiptTransfer(
        address,
        address // solhint-disable-next-line no-empty-blocks
    ) external view virtual {
        // Authorize all receipt transfers by default.
    }

    /// @inheritdoc IReceiptOwnerV1
    function authorizeReceiptInformation(
        address,
        uint256,
        bytes memory // solhint-disable-next-line no-empty-blocks
    ) external view virtual {
        // Authorize all receipt information by default.
    }

    /// Calculate how many shares_ will be minted in return for assets_.
    /// @param assets_ Amount of assets being deposited.
    /// @param shareRatio_ The ratio of shares to assets to deposit against.
    /// @param depositMinShareRatio_ The minimum share ratio required by the
    /// depositor. Will error if `shareRatio_` is less than
    /// `depositMinShareRatio_`.
    /// @return shares_ Amount of shares to mint for this deposit.
    function _calculateDeposit(
        uint256 assets_,
        uint256 shareRatio_,
        uint256 depositMinShareRatio_
    ) internal pure returns (uint256) {
        require(shareRatio_ >= depositMinShareRatio_, "MIN_SHARE_RATIO");
        // IRC4626:
        // If (1) it’s calculating how many shares to issue to a user for a
        // certain amount of the underlying tokens they provide, it should
        // round down.
        return assets_.fixedPointMul(shareRatio_, Math.Rounding.Down);
    }

    /// Calculate how many assets_ are needed to mint shares_.
    /// @param shares_ Amount of shares desired to be minted.
    /// @param shareRatio_ The ratio shares are minted at per asset.
    /// @param mintMinShareRatio_ The minimum ratio required by the minter. Will
    /// error if `shareRatio_` is less than `mintMinShareRatio_`.
    /// @return assets_ Amount of assets that must be deposited for this mint.
    function _calculateMint(
        uint256 shares_,
        uint256 shareRatio_,
        uint256 mintMinShareRatio_
    ) internal pure returns (uint256) {
        require(shareRatio_ >= mintMinShareRatio_, "MIN_SHARE_RATIO");
        // IERC4626:
        // If (2) it’s calculating the amount of underlying tokens a user has
        // to provide to receive a certain amount of shares, it should
        // round up.
        return shares_.fixedPointDiv(shareRatio_, Math.Rounding.Up);
    }

    /// Calculate how many shares_ to burn to withdraw assets_.
    /// @param assets_ Amount of assets being withdrawn.
    /// @param shareRatio_ Ratio of shares to assets to withdraw against.
    /// @return shares_ Amount of shares to burn for this withdrawal.
    function _calculateWithdraw(
        uint256 assets_,
        uint256 shareRatio_
    ) internal pure returns (uint256) {
        // IERC4626:
        // If (1) it’s calculating the amount of shares a user has to supply to
        // receive a given amount of the underlying tokens, it should round up.
        return assets_.fixedPointMul(shareRatio_, Math.Rounding.Up);
    }

    /// Calculate how many assets_ to withdraw for burning shares_.
    /// @param shares_ Amount of shares being burned for redemption.
    /// @param shareRatio_ Ratio of shares to assets being redeemed against.
    /// @return assets_ Amount of assets that will be redeemed for the given
    /// shares.
    function _calculateRedeem(
        uint256 shares_,
        uint256 shareRatio_
    ) internal pure returns (uint256) {
        // IERC4626:
        // If (2) it’s determining the amount of the underlying tokens to
        // transfer to them for returning a certain amount of shares, it should
        // round down.
        return shares_.fixedPointDiv(shareRatio_, Math.Rounding.Down);
    }

    /// There is no onchain asset. The asset is offchain.
    /// @inheritdoc IERC4626
    function asset() public view virtual returns (address) {
        return address(_asset);
    }

    /// Any address can set their own minimum share ratio.
    /// This is optional as the non-standard 4626 equivalent functions accept
    /// a minimum share ratio parameter. This facilitates the 4626 interface by
    /// adding one additional initial transaction for the user.
    /// @param senderMinShareRatio_ The new minimum share ratio for the
    /// `msg.sender` to be used in subsequent deposit calls.
    function setMinShareRatio(uint256 senderMinShareRatio_) external {
        minShareRatios[msg.sender] = senderMinShareRatio_;
    }

    /// Any address can set their own ID for withdrawals.
    /// This is optional as the non-standard 4626 equivalent functions accept
    /// a withdrawal ID parameter. This facilitates the 4626 interface
    /// by adding one initial transaction for the user.
    /// @param id_ The new withdrawal id_ for the `msg.sender` to be used
    /// in subsequent withdrawal calls. If the ID does NOT match the ID of a
    /// receipt held by sender then these subsequent withdrawals will fail.
    /// It is the responsibility of the caller to set a valid ID.
    function setWithdrawId(uint256 id_) external {
        withdrawIds[msg.sender] = id_;
    }

    /// @inheritdoc IERC4626
    function totalAssets() external view virtual returns (uint256) {
        // There are NO fees so the managed assets are the asset balance of the
        // vault.
        try IERC20(asset()).balanceOf(address(this)) returns (
            // slither puts false positives on `try/catch/returns`.
            // https://github.com/crytic/slither/issues/511
            //slither-disable-next-line
            uint256 assetBalance_
        ) {
            return assetBalance_;
        } catch {
            // It's not clear what the balance should be if querying it is
            // throwing an error. The conservative error in most cases should
            // be 0.
            return 0;
        }
    }

    /// Define the share ratio that assets are converted to shares on deposit.
    /// This variant of `_shareRatio` MUST return the same result for all users.
    /// As per IERC4626 `convertToShares` it should reflect the "average-user's"
    /// share ratio when all conditions are met.
    /// MUST NOT revert, instead return `0` and calling functions MUST revert or
    /// return values as appropriate.
    function _shareRatio() internal view virtual returns (uint256) {
        // Default is 1:1 shares to assets.
        return 1e18;
    }

    /// Define the share ratio that deposits convert to shares.
    /// This variant of `_shareRatio` MAY return different results dependant on
    /// the depositor and/or recipient as per `previewDeposit` and `deposit`.
    /// MUST NOT revert.
    function _shareRatio(
        address,
        address
    ) internal view virtual returns (uint256) {
        // Default is to fallback to user agnostic share ratio.
        return _shareRatio();
    }

    function _shareRatioForId(uint256) internal view virtual returns (uint256) {
        // Default is the same as share ratio with no id.
        return _shareRatio();
    }

    /// Defines the next ID that a deposit will mint shares and receipts under.
    /// This MUST NOT be set by `msg.sender` as the `ReceiptVault` itself is
    /// responsible for managing the ID values that bind the minted shares and
    /// the associated receipt. These ID values are NOT necessarily meaningful
    /// to the asset depositor they purely bind mints to future potential burns.
    /// ID values that are meaningful to the depositor can be encoded in the
    /// receipt information that is emitted for offchain indexing via events.
    /// The default behaviour is to bind every mint and burn to the same ID, i.e.
    /// the ID is always `0`. This is almost certainly NOT desired behaviour so
    /// inheriting contracts will need to provide an override.
    // Not sure why slither flags this as dead code. It is used by both `deposit`
    // and `mint`.
    //slither-disable-next-line dead-code
    function _nextId() internal virtual returns (uint256) {
        return 0;
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint256 assets_) external view returns (uint256) {
        return _calculateDeposit(assets_, _shareRatio(), 0);
    }

    /// This function is a bit weird because in reality everyone converts their
    /// shares to assets at the share ratio they minted at, NOT the current
    /// share ratio. But the spec demands that this function ignores per-user
    /// concerns.
    /// @inheritdoc IERC4626
    function convertToAssets(uint256 shares_) external view returns (uint256) {
        return _calculateRedeem(shares_, _shareRatio());
    }

    /// @inheritdoc IERC4626
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

    /// @inheritdoc IERC4626
    function maxMint(address) external pure virtual returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc IERC4626
    function previewDeposit(
        uint256 assets_
    ) external view virtual returns (uint256) {
        return
            _calculateDeposit(
                assets_,
                // Spec doesn't provide us with a receipient but wants a per-user
                // preview so we assume that depositor = receipient.
                _shareRatio(msg.sender, msg.sender),
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
                minShareRatios[msg.sender]
            );
    }

    /// @inheritdoc IERC4626
    function previewMint(
        uint256 shares_
    ) public view virtual returns (uint256) {
        return
            _calculateMint(
                shares_,
                // Spec doesn't provide us with a recipient but wants a per-user
                // preview so we assume that depositor = recipient.
                _shareRatio(msg.sender, msg.sender),
                // IERC4626:
                // > MUST NOT revert due to vault specific user/global limits.
                // > MAY revert due to other conditions that would also cause mint
                // > to revert.
                // Unclear if the min share ratio set by the user for themselves is
                // a "vault specific user limit" or "other conditions that would
                // also cause mint to revert".
                // The conservative interpretation is that the user will WANT
                // the preview calculation to revert according to their own
                // preferences they set for themselves onchain.
                // If the user did not set a min ratio the min ratio will be 0 and
                // never revert.
                minShareRatios[msg.sender]
            );
    }

    /// If the sender wants to use the ERC4626 `deposit` function and set a
    /// minimum ratio they need to call `setMinShareRatio` first in a separate
    /// call. Alternatively they can use the off-spec overloaded `deposit`
    /// method.
    /// @inheritdoc IERC4626
    function deposit(
        uint256 assets_,
        address receiver_
    ) external returns (uint256) {
        return deposit(assets_, receiver_, minShareRatios[msg.sender], "");
    }

    /// Overloaded `deposit` to allow `depositMinShareRatio_` to be passed
    /// directly without the additional `setMinShareRatio` call, which saves gas
    /// and can provide a better UX overall.
    /// @param assets_ As per IERC4626 `deposit`.
    /// @param receiver_ As per IERC4626 `deposit`.
    /// @param depositMinShareRatio_ Caller can set the minimum share ratio
    /// they'll accept from the oracle, otherwise the transaction is rolled back.
    /// @param receiptInformation_ Forwarded to `receiptInformation` to
    /// optionally emit offchain context about this deposit.
    /// @return shares_ As per IERC4626 `deposit`.
    function deposit(
        uint256 assets_,
        address receiver_,
        uint256 depositMinShareRatio_,
        bytes memory receiptInformation_
    ) public returns (uint256) {
        uint256 shareRatio_ = _shareRatio(msg.sender, receiver_);
        require(depositMinShareRatio_ <= shareRatio_, "MIN_SHARE_RATIO");
        uint256 shares_ = _calculateDeposit(
            assets_,
            shareRatio_,
            depositMinShareRatio_
        );

        _deposit(assets_, receiver_, shares_, _nextId(), receiptInformation_);
        return shares_;
    }

    /// Handles minting and emitting events according to spec.
    /// It does NOT do any calculations so shares and assets need to be handled
    /// correctly according to spec including rounding, in the calling context.
    /// Depositing reentrantly is never ok so we restrict that here in the
    /// internal function rather than on the external methods.
    /// @param assets_ As per IERC4626 `deposit`.
    /// @param receiver_ As per IERC4626 `deposit`.
    /// @param shares_ Amount of shares to mint for receiver. MAY be different
    /// due to rounding in different contexts so caller MUST calculate
    /// according to the rounding specification.
    /// @param id_ ID of the 1155 receipt and MUST be provided on withdrawal.
    function _deposit(
        uint256 assets_,
        address receiver_,
        uint256 shares_,
        uint256 id_,
        bytes memory receiptInformation_
    ) internal nonReentrant {
        require(assets_ > 0, "0_ASSETS");
        require(receiver_ != address(0), "0_RECEIVER");
        require(shares_ > 0, "0_SHARES");
        require(id_ > 0, "0_ID");
        emit IERC4626.Deposit(msg.sender, receiver_, assets_, shares_);
        emit DepositWithReceipt(
            msg.sender,
            receiver_,
            assets_,
            shares_,
            id_,
            receiptInformation_
        );
        _beforeDeposit(assets_, receiver_, shares_, id_);

        // erc20 mint.
        // Slither flags this as reentrant but this function has `nonReentrant`
        // on it from `ReentrancyGuard`.
        //slither-disable-next-line reentrancy-vulnerabilities-3 reentrancy-vulnerabilities-2
        _mint(receiver_, shares_);

        // erc1155 mint.
        // Receiving contracts MUST implement `IERC1155Receiver`.
        _receipt.ownerMint(
            receiver_,
            id_,
            shares_,
            receiptInformation_
        );
    }

    function _beforeDeposit(
        uint256 assets_,
        address,
        uint256,
        uint256
    ) internal virtual {
        // Default behaviour is to move assets before minting shares.
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), assets_);
    }

    /// If the sender wants to use the ERC4626 `mint` function and set a
    /// minimum share ratio they need to call `setMinShareRatio` first in a
    /// separate call.
    /// Alternatively they can use the off-spec overloaded `mint` method.
    /// @inheritdoc IERC4626
    function mint(
        uint256 shares_,
        address receiver_
    ) external returns (uint256) {
        return mint(shares_, receiver_, minShareRatios[msg.sender], "");
    }

    /// Overloaded version of IERC4626 `mint` that allows directly passing the
    /// minimum share ratio to avoid additional gas and transactions.
    /// @param shares_ As per IERC4626 `mint`.
    /// @param receiver_ As per IERC4626 `mint`.
    /// @param mintMinShareRatio_ Caller can set the minimum ratio they'll accept
    /// minting shares at, otherwise the transaction is rolled back.
    /// @param receiptInformation_ Forwarded to `receiptInformation` to
    /// optionally emit offchain context about this deposit.
    /// @return assets_ As per IERC4626 `mint`.
    function mint(
        uint256 shares_,
        address receiver_,
        uint256 mintMinShareRatio_,
        bytes memory receiptInformation_
    ) public returns (uint256) {
        uint256 shareRatio_ = _shareRatio(msg.sender, receiver_);
        require(mintMinShareRatio_ <= shareRatio_, "MIN_SHARE_RATIO");
        uint256 assets_ = _calculateMint(
            shares_,
            shareRatio_,
            mintMinShareRatio_
        );
        _deposit(assets_, receiver_, shares_, _nextId(), receiptInformation_);
        return assets_;
    }

    /// As withdrawal requires a ID the vault deposits are non fungible. This
    /// means the maximum amount of underlying asset that a user can withdraw is
    /// specific to the 1155 receipt they want to burn to handle the withdraw.
    /// A user with multiple receipts will only ever see the maxWithdraw for a
    /// single receipt. For most use cases it would be recommended to call the
    /// overloaded `maxWithdraw` that has the withdraw ID paramaterised. This
    /// can be looped over to build a view over several withdraw IDs.
    /// @inheritdoc IERC4626
    function maxWithdraw(
        address owner_
    ) external view virtual returns (uint256) {
        return maxWithdraw(owner_, withdrawIds[owner_]);
    }

    /// Overloaded `maxWithdraw` that allows passing a receipt id directly. The
    /// id needs to be provided so that we know which ERC1155 balance to
    /// check the withdraw against. The burnable ERC20 is capped per-withdraw
    /// to the balance of a ID-bound ERC1155. If a user has multiple 1155
    /// receipts they will need to call `maxWithdraw` multiple times to
    /// calculate a global withdrawal limit across all receipts.
    /// @param owner_ As per IERC4626 `maxWithdraw`.
    /// @param id_ The reference id to check the max withdrawal against
    /// for a specific receipt the owner presumably holds. Max withdrawal will
    /// be 0 if the user does not hold a receipt.
    /// @return maxAssets_ As per IERC4626 `maxWithdraw`.
    function maxWithdraw(
        address owner_,
        uint256 id_
    ) public view returns (uint256) {
        // Using `_calculateRedeem` instead of `_calculateWithdraw` becuase the
        // latter requires knowing the assets being withdrawn, which is what we
        // are attempting to reverse engineer from the owner's receipt balance.
        return
            _calculateRedeem(
                _receipt.balanceOf(owner_, id_),
                _shareRatioForId(id_)
            );
    }

    /// Previewing withdrawal will only calculate the shares required to
    /// withdraw assets against their singular preset withdraw ID. To
    /// calculate many withdrawals for a set of recieipts it is cheaper and
    /// easier to use the overloaded version that allows IDs to be passed in
    /// as arguments.
    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 assets_) external view returns (uint256) {
        return previewWithdraw(assets_, withdrawIds[msg.sender]);
    }

    /// Overloaded version of IERC4626 that allows caller to pass in the ID
    /// to preview. Multiple receipt holders will need to call this function
    /// for each recieipt ID to preview all their withdrawals.
    /// @param assets_ As per IERC4626 `previewWithdraw`.
    /// @param id_ The receipt to preview a withdrawal against.
    /// @return shares_ As per IERC4626 `previewWithdraw`.
    function previewWithdraw(
        uint256 assets_,
        uint256 id_
    ) public view virtual returns (uint256) {
        return _calculateWithdraw(assets_, _shareRatioForId(id_));
    }

    /// Withdraws against the current withdraw ID set by the owner.
    /// This enables spec compliant withdrawals but is additional gas and
    /// transactions for the user to set the withdraw ID in storage before
    /// each withdrawal. The overloaded `withdraw` function allows passing in a
    /// receipt ID directly, which may be cheaper and more convenient.
    /// @inheritdoc IERC4626
    function withdraw(
        uint256 assets_,
        address receiver_,
        address owner_
    ) external returns (uint256) {
        return withdraw(assets_, receiver_, owner_, withdrawIds[owner_]);
    }

    /// Overloaded version of IERC4626 `withdraw` that allows the id to be
    /// passed directly.
    /// @param assets_ As per IERC4626 `withdraw`.
    /// @param receiver_ As per IERC4626 `withdraw`.
    /// @param owner_ As per IERC4626 `withdraw`.
    /// @param id_ As per `_withdraw`.
    function withdraw(
        uint256 assets_,
        address receiver_,
        address owner_,
        uint256 id_
    ) public returns (uint256) {
        uint256 shares_ = _calculateWithdraw(assets_, _shareRatioForId(id_));
        _withdraw(assets_, receiver_, owner_, shares_, id_);
        return shares_;
    }

    /// Handles burning shares, withdrawing assets and emitting events to spec.
    /// It does NOT do any calculations so shares and assets need to be correct
    /// according to spec including rounding, in the calling context.
    /// Withdrawing reentrantly is never ok so we restrict that here in the
    /// internal function rather than on the external methods.
    /// @param assets_ As per IERC4626 `withdraw`.
    /// @param receiver_ As per IERC4626 `withdraw`.
    /// @param owner_ As per IERC4626 `withdraw`.
    /// @param shares_ Caller MUST calculate the correct shares to burn for
    /// withdrawal at `shareRatio_`. It is caller's responsibility to handle
    /// rounding correctly as per 4626 spec.
    /// @param id_ The receipt id to withdraw against. The owner MUST hold the
    /// receipt for the ID in addition to the shares being burned for
    /// withdrawal.
    function _withdraw(
        uint256 assets_,
        address receiver_,
        address owner_,
        uint256 shares_,
        uint256 id_
    ) internal nonReentrant {
        require(assets_ > 0, "0_ASSETS");
        require(receiver_ != address(0), "0_RECEIVER");
        require(owner_ != address(0), "0_OWNER");
        require(shares_ > 0, "0_SHARES");

        emit IERC4626.Withdraw(msg.sender, receiver_, owner_, assets_, shares_);
        emit WithdrawWithReceipt(
            msg.sender,
            receiver_,
            owner_,
            assets_,
            shares_,
            id_
        );

        // IERC4626:
        // > MUST support a withdraw flow where the shares are burned from owner
        // > directly where owner is msg.sender or msg.sender has ERC-20
        // > approval over the shares of owner.
        // Note that we do NOT require the caller has allowance over the receipt
        // in order to burn the shares to withdraw assets.
        if (owner_ != msg.sender) {
            _spendAllowance(owner_, msg.sender, shares_);
        }

        // ERC20 burn.
        _burn(owner_, shares_);

        // ERC1155 burn.
        _receipt.ownerBurn(owner_, id_, shares_);

        // Hook to allow additional withdrawal checks.
        _afterWithdraw(assets_, receiver_, owner_, shares_, id_);
    }

    function _afterWithdraw(
        uint256 assets_,
        address receiver_,
        address,
        uint256,
        uint256
    ) internal virtual {
        // Default is to send assets after burning shares.
        IERC20(asset()).safeTransfer(receiver_, assets_);
    }

    /// Max redemption is only relevant to the currently set withdraw ID for
    /// the owner. Checking a different max redemption requires the owner
    /// setting a different withdraw ID which costs gas and an additional
    /// transaction. The overloaded maxRedeem function allows the ID being
    /// checked against to be passed in directly.
    /// @inheritdoc IERC4626
    function maxRedeem(address owner_) external view returns (uint256) {
        return maxRedeem(owner_, withdrawIds[owner_]);
    }

    /// Overloaded maxRedeem function that allows the redemption ID to be
    /// passed directly. The maximum number of shares that can be redeemed is
    /// simply the balance of the associated receipt NFT the user holds for the
    /// given ID.
    /// @param owner_ As per IERC4626 `maxRedeem`.
    /// @param id_ The reference id to check the owner's 1155 balance for.
    /// @return maxShares_ As per IERC4626 `maxRedeem`.
    function maxRedeem(
        address owner_,
        uint256 id_
    ) public view returns (uint256) {
        return _receipt.balanceOf(owner_, id_);
    }

    /// Preview redeem is only relevant to the currently set withdraw ID for
    /// the caller. The overloaded previewRedeem allows the ID to be passed
    /// directly which may avoid gas costs and additional transactions.
    /// @inheritdoc IERC4626
    function previewRedeem(uint256 shares_) external view returns (uint256) {
        return _calculateRedeem(shares_, withdrawIds[msg.sender]);
    }

    /// Overloaded previewRedeem that allows ID to redeem for to be passed
    /// directly.
    /// @param shares_ As per IERC4626.
    /// @param id_ The receipt id_ to calculate redemption against.
    function previewRedeem(
        uint256 shares_,
        uint256 id_
    ) public view virtual returns (uint256) {
        return _calculateRedeem(shares_, id_);
    }

    /// Redeems with the currently set withdraw ID for the owner. The
    /// overloaded redeem function allows the ID to be passed in rather than
    /// set separately in storage.
    /// @inheritdoc IERC4626
    function redeem(
        uint256 shares_,
        address receiver_,
        address owner_
    ) external returns (uint256) {
        return redeem(shares_, receiver_, owner_, withdrawIds[owner_]);
    }

    /// Overloaded redeem that allows the ID to redeem with to be passed in.
    /// @param shares_ As per IERC4626 `redeem`.
    /// @param receiver_ As per IERC4626 `redeem`.
    /// @param owner_ As per IERC4626 `redeem`.
    /// @param id_ The reference id to redeem against. The owner MUST hold
    /// a receipt with id_ and it will be used to calculate the share ratio.
    function redeem(
        uint256 shares_,
        address receiver_,
        address owner_,
        uint256 id_
    ) public returns (uint256) {
        uint256 assets_ = _calculateRedeem(shares_, _shareRatioForId(id_));
        _withdraw(assets_, receiver_, owner_, shares_, id_);
        return assets_;
    }
}
