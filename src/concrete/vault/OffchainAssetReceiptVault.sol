// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {UnmanagedReceiptTransfer} from "../../interface/IReceiptManagerV2.sol";
import {
    ReceiptVaultConfig,
    VaultConfig,
    ReceiptVault,
    ShareAction,
    InvalidId,
    ICLONEABLE_V2_SUCCESS,
    ReceiptVaultConstructionConfig
} from "../../abstract/ReceiptVault.sol";
import {AccessControlUpgradeable as AccessControl} from
    "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {OwnableUpgradeable as Ownable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {IReceiptV2} from "../../interface/IReceiptV2.sol";
import {MathUpgradeable as Math} from "openzeppelin-contracts-upgradeable/contracts/utils/math/MathUpgradeable.sol";
import {ITierV2} from "rain.tier.interface/interface/ITierV2.sol";
import {IAuthorizeV1, Unauthorized} from "../../interface/IAuthorizeV1.sol";
import {IERC165Upgradeable as IERC165} from
    "openzeppelin-contracts-upgradeable/contracts/utils/introspection/IERC165Upgradeable.sol";

import {ZeroInitialAdmin} from "../authorize/OffchainAssetReceiptVaultAuthorizorV1.sol";

/// Thrown when the asset is NOT address zero.
error NonZeroAsset();

/// Thrown when a 0 certification time is attempted.
error ZeroCertifyUntil();

/// Thrown when a 0 confiscation amount is attempted.
error ZeroConfiscateAmount();

/// Thrown when the authorizor is incompatible according to `IERC165` when set.
error IncompatibleAuthorizor();

/// All data required to configure an offchain asset vault except the receipt.
/// Typically the factory should build a receipt contract and set management
/// to the vault atomically during initialization so there is no opportunity for
/// an attacker to corrupt the initialzation process.
/// @param initialAdmin as per `OffchainAssetReceiptVaultConfig`.
/// @param authorizor as per `OffchainAssetReceiptVaultConfig`.
/// @param vaultConfig MUST be used by the factory to build a
/// `ReceiptVaultConfig` once the receipt address is known and management has
/// been set to the vault contract.
struct OffchainAssetVaultConfigV2 {
    address initialAdmin;
    VaultConfig vaultConfig;
}

/// All data required to construct `OffchainAssetReceiptVault`.
/// @param initialAdmin The initial admin has ALL ROLES. It is up to the admin to
/// appropriately delegate and renounce roles or to be a smart contract with
/// formal governance processes. In general a single EOA holding all admin roles
/// is completely insecure and counterproductive as it allows a single address
/// to both mint and audit assets (and everything else).
/// @param authorizor The authorizor contract that will be used to authorize
/// sensitive operations.
/// @param receiptVaultConfig Forwarded to ReceiptVault.
struct OffchainAssetReceiptVaultConfigV2 {
    address initialAdmin;
    ReceiptVaultConfig receiptVaultConfig;
}

/// Represents a change in the certification state of the system.
/// Provided to the authorization contract in case it needs to make decisions
/// based on the specifics of the change.
/// @param oldCertifiedUntil The previous certification time.
/// @param newCertifiedUntil The new certification time. May be the same as the
/// old certification time according to the logic of `certify`.
/// @param userCertifyUntil The certification time that the certifier attempted
/// to set.
/// @param forceUntil Whether the certifier forced the certification time.
/// @param data Arbitrary data justifying the certification as provided by the
/// certifier.
struct CertifyStateChange {
    uint256 oldCertifiedUntil;
    uint256 newCertifiedUntil;
    uint256 userCertifyUntil;
    bool forceUntil;
    bytes data;
}

struct ConfiscateReceiptStateChange {
    address confiscatee;
    uint256 id;
    uint256 targetAmount;
    uint256 actualAmount;
    bytes data;
}

struct ConfiscateSharesStateChange {
    address confiscatee;
    uint256 targetAmount;
    uint256 actualAmount;
    bytes data;
}

struct TransferSharesStateChange {
    address from;
    address to;
    uint256 amount;
    bool isCertificationExpired;
}

struct TransferReceiptStateChange {
    address from;
    address to;
    uint256[] ids;
    uint256[] amounts;
    bool isCertificationExpired;
}

struct DepositStateChange {
    address owner;
    address receiver;
    uint256 id;
    uint256 assetsDeposited;
    uint256 sharesMinted;
}

struct WithdrawStateChange {
    address owner;
    address receiver;
    uint256 id;
    uint256 assetsWithdrawn;
    uint256 sharesBurned;
}

/// @dev Permission for certification.
bytes32 constant CERTIFY = keccak256("CERTIFY");

/// @dev Permission for confiscating shares.
bytes32 constant CONFISCATE_SHARES = keccak256("CONFISCATE_SHARES");

/// @dev Permission for confiscating receipts.
bytes32 constant CONFISCATE_RECEIPT = keccak256("CONFISCATE_RECEIPT");

/// @dev Permission for transferring tokens.
bytes32 constant TRANSFER_SHARES = keccak256("TRANSFER_SHARES");

/// @dev Permission for transferring receipts
bytes32 constant TRANSFER_RECEIPT = keccak256("TRANSFER_RECEIPT");

/// @dev Permission for depositing tokens.
bytes32 constant DEPOSIT = keccak256("DEPOSIT");

/// @dev Permission for withdrawing tokens.
bytes32 constant WITHDRAW = keccak256("WITHDRAW");

/// @title OffchainAssetReceiptVault
/// @notice Enables issuers of offchain assets to create a token that they can
/// arbitrage offchain assets against onchain assets. This allows them to
/// maintain a peg between offchain and onchain markets.
///
/// At a high level this works because the issuer can always profitably trade
/// the peg against offchain markets in both directions. The exact tokenomics
/// are somewhat flexible and intentionally left open to the issuer to design.
/// The main requirement is that bringing the peg up or down is profitable for
/// the issuer, all the way down to buying and burning 100% of the supply.
///
/// Price is higher onchain: Issuer can buy/produce assets offchain and mint
/// tokens then sell the tokens for more than the assets would sell for offchain
/// thus making a profit. The sale of the tokens brings the onchain price down.
///
/// Price is higher offchain: Issuer can sell assets offchain and
/// buyback+burn tokens onchain for less than the offchain sale, thus making a
/// profit. The token purchase brings the onchain price up.
///
/// The issuer doesn't necessarily have to mint and burn tokens immediately, as
/// the offchain assets may not trade/yield so quickly, but delays have
/// implications for the peg fidelity onchain.
///
/// In contrast to pure algorithmic tokens and sentiment based stablecoins, a
/// competent issuer must profit sustainably to maintain the peg no matter how
/// badly or frequently the peg breaks. Ideally the issuer profits more when the
/// peg is broken more.
///
/// This contract does not attempt to solve for liquidity and trustworthyness,
/// it only seeks to provide baseline functionality that a competent issuer
/// will need to tackle the problem. The implementation provides:
///
/// - `ReceiptVault` base that allows transparent onchain/offchain audit history
/// - Certifier role that allows for audits of offchain assets that can fail
/// - KYC/membership lists that can restrict who can hold/transfer assets as
///   any Rain `ITierV2` interface
/// - Ability to comply with sanctions/regulators by confiscating assets
/// - `ERC20` shares in the vault that can be traded minted/burned to track a peg
/// - `ERC4626` inspired vault interface (inherited from `ReceiptVault`)
/// - Fine grained standard Open Zeppelin access control for all system roles
contract OffchainAssetReceiptVault is ReceiptVault, AccessControl, IAuthorizeV1, Ownable {
    using Math for uint256;

    /// Contract has initialized.
    /// @param sender The `msg.sender` constructing the contract.
    /// @param config All initialization config.
    event OffchainAssetReceiptVaultInitializedV2(address sender, OffchainAssetReceiptVaultConfigV2 config);

    /// A new certification time has been set.
    /// @param sender The certifier setting the new time.
    /// @param certifyUntil The time the system is newly certified until.
    /// Normally this will be a future time but certifiers MAY set it to a time
    /// in the past which will immediately freeze all transfers.
    /// @param forceUntil Whether the certifier forced the certification time.
    /// @param data The certifier MAY provide additional supporting data such
    /// as an auditor's report/comments etc.
    event Certify(address sender, uint256 certifyUntil, bool forceUntil, bytes data);

    /// Shares have been confiscated from a user who is not currently meeting
    /// the ERC20 tier contract minimum requirements.
    /// @param sender The confiscator who is confiscating the shares.
    /// @param confiscatee The user who had their shares confiscated.
    /// @param confiscated The amount of shares that were confiscated.
    /// @param justification The contextual data justifying the confiscation.
    event ConfiscateShares(
        address sender, address confiscatee, uint256 targetAmount, uint256 confiscated, bytes justification
    );

    /// A receipt has been confiscated from a user who is not currently meeting
    /// the ERC1155 tier contract minimum requirements.
    /// @param sender The confiscator who is confiscating the receipt.
    /// @param confiscatee The user who had their receipt confiscated.
    /// @param id The receipt ID that was confiscated.
    /// @param confiscated The amount of the receipt that was confiscated.
    /// @param justification The contextual data justifying the confiscation.
    event ConfiscateReceipt(
        address sender, address confiscatee, uint256 id, uint256 targetAmount, uint256 confiscated, bytes justification
    );

    IAuthorizeV1 sAuthorizor;

    /// The largest issued id. The next id issued will be larger than this.
    uint256 private sHighwaterId;

    /// The system is certified until this timestamp. If this is in the past then
    /// general transfers of shares and receipts will fail until the system can
    /// be certified to a future time.
    uint256 internal sCertifiedUntil;

    constructor(ReceiptVaultConstructionConfig memory config) ReceiptVault(config) {}

    /// Initializes the initial admin and the underlying `ReceiptVault`.
    /// The admin provided will be admin of all roles and can reassign and revoke
    /// this as appropriate according to standard Open Zeppelin access control
    /// logic.
    /// @param data All config required to initialize abi encoded.
    function initialize(bytes memory data) public virtual override initializer returns (bytes32) {
        OffchainAssetVaultConfigV2 memory config = abi.decode(data, (OffchainAssetVaultConfigV2));

        __ReceiptVault_init(config.vaultConfig);
        __AccessControl_init();

        // There is no asset, the asset is offchain.
        if (config.vaultConfig.asset != address(0)) {
            revert NonZeroAsset();
        }
        // The config admin MUST be set.
        if (config.initialAdmin == address(0)) {
            revert ZeroInitialAdmin();
        }

        sAuthorizor = IAuthorizeV1(address(this));

        _transferOwnership(config.initialAdmin);

        emit OffchainAssetReceiptVaultInitializedV2(
            msg.sender,
            OffchainAssetReceiptVaultConfigV2({
                initialAdmin: config.initialAdmin,
                receiptVaultConfig: ReceiptVaultConfig({receipt: address(receipt()), vaultConfig: config.vaultConfig})
            })
        );

        return ICLONEABLE_V2_SUCCESS;
    }

    /// Returns the current authorizor contract.
    function authorizor() external view returns (IAuthorizeV1) {
        return sAuthorizor;
    }

    /// The vault initializes with the authorizor as itself. Every permission
    /// reverts unconditionally, so the owner MUST set the real authorizor before
    /// any operations can be performed.
    /// @inheritdoc IAuthorizeV1
    function authorize(address user, bytes32 permission, bytes memory data) external view virtual override {
        (user, permission, data);
        revert Unauthorized(user, permission, data);
    }

    /// Sets the authorizor contract. This is a critical operation and should be
    /// done with extreme care by the owner.
    /// @param newAuthorizor The new authorizor contract.
    function setAuthorizor(IAuthorizeV1 newAuthorizor) external onlyOwner {
        if (!IERC165(address(newAuthorizor)).supportsInterface(type(IAuthorizeV1).interfaceId)) {
            revert IncompatibleAuthorizor();
        }
        sAuthorizor = newAuthorizor;
    }

    /// Apply standard transfer restrictions to receipt transfers.
    /// @inheritdoc ReceiptVault
    function authorizeReceiptTransfer3(address from, address to, uint256[] memory ids, uint256[] memory amounts)
        external
        virtual
        override
    {
        if (msg.sender != address(receipt())) {
            revert UnmanagedReceiptTransfer();
        }

        sAuthorizor.authorize(
            msg.sender,
            TRANSFER_RECEIPT,
            abi.encode(
                TransferReceiptStateChange({
                    from: from,
                    to: to,
                    ids: ids,
                    amounts: amounts,
                    isCertificationExpired: isCertificationExpired()
                })
            )
        );
    }

    /// DO NOT call super `_beforeDeposit` as there are no assets to move.
    /// Highwater needs to witness the incoming id.
    /// @inheritdoc ReceiptVault
    function _beforeDeposit(uint256 assets, address receiver, uint256 shares, uint256 id) internal virtual override {
        sHighwaterId = sHighwaterId.max(id);
        sAuthorizor.authorize(
            msg.sender,
            DEPOSIT,
            abi.encode(
                DepositStateChange({
                    owner: msg.sender,
                    receiver: receiver,
                    id: id,
                    assetsDeposited: assets,
                    sharesMinted: shares
                })
            )
        );
    }

    /// DO NOT call super `_afterWithdraw` as there are no assets to move.
    /// @inheritdoc ReceiptVault
    function _afterWithdraw(uint256 assets, address receiver, address owner, uint256 shares, uint256 id)
        internal
        virtual
        override
    {
        sAuthorizor.authorize(
            msg.sender,
            WITHDRAW,
            abi.encode(
                WithdrawStateChange({
                    owner: owner,
                    receiver: receiver,
                    id: id,
                    assetsWithdrawn: assets,
                    sharesBurned: shares
                })
            )
        );
    }

    /// Shares total supply is 1:1 with offchain assets.
    /// Assets aren't real so only way to report this is to return the total
    /// supply of shares.
    /// @inheritdoc ReceiptVault
    function totalAssets() external view virtual override returns (uint256) {
        return totalSupply();
    }

    /// IDs for offchain assets are merely autoincremented. If the minter wants
    /// to track some external ID system as a foreign key they can emit this in
    /// the associated receipt information.
    /// @inheritdoc ReceiptVault
    function _nextId() internal view virtual override returns (uint256) {
        return sHighwaterId + 1;
    }

    /// Depositors can increase the deposited assets for the existing id of this
    /// receipt. It is STRONGLY RECOMMENDED the redepositor also provides data to
    /// be forwarded to asset information to justify the additional deposit. New
    /// offchain assets MUST NOT redeposit under existing IDs, they MUST be
    /// deposited under a new id instead. The ID preservation provided by
    /// `redeposit` is intended to ensure a consistent audit trail for the
    /// lifecycle of any asset. We do not need a corresponding "rewithdraw"
    /// function because withdrawals already target an ID.
    ///
    /// Note that the existence of `redeposit` and `withdraw` both allow the
    /// potential of two different depositor/withdrawer accounts to apply the
    /// same mint/burn concurrently to the mempool and have both included in a
    /// block inappropriately. Features like this, as well as more fundamental
    /// trust assumptions/limitations offchain, make it impossible to fully
    /// decouple depositors and withdrawers from each other _per token_. The
    /// model is that there are many decoupled tokens each with their own "team"
    /// that can be expected to coordinate to prevent double-mint/burn.
    ///
    /// @param assets As per IERC4626 `deposit`.
    /// @param receiver As per IERC4626 `deposit`.
    /// @param id The existing receipt to despoit additional assets under. Will
    /// mint new ERC20 shares and also increase the held receipt amount 1:1.
    /// @param receiptInformation Forwarded to receipt mint and
    /// `receiptInformation`.
    /// @return shares As per IERC4626 `deposit`.
    function redeposit(uint256 assets, address receiver, uint256 id, bytes calldata receiptInformation)
        external
        returns (uint256)
    {
        // Only allow redepositing for IDs that exist.
        if (id > sHighwaterId) {
            revert InvalidId(id);
        }

        uint256 shares = _calculateDeposit(assets, _shareRatio(msg.sender, receiver, id, ShareAction.Mint), 0);

        _deposit(assets, receiver, shares, id, receiptInformation);
        return shares;
    }

    /// Certifiers MAY EXTEND OR REDUCE the `certifiedUntil` time. If there are
    /// many certifiers, any certifier can modify the certifiation at any time.
    /// It is STRONGLY RECOMMENDED that certifiers DO NOT set the `forceUntil`
    /// flag to `true` unless they want to:
    ///
    /// - Potentially override another certifier's concurrent certification
    /// - Reduce the certification time
    ///
    /// The certifier is STRONGLY RECOMMENDED to submit a summary report of the
    /// process and findings used to justify the modified `certifiedUntil` time.
    ///
    /// The certifier is STRONGLY RECOMMENDED to provide an unambiguous reference
    /// to the information used to inform their certification decision. This
    /// can be provided in the `data` field, and the onchain contracts are
    /// unopinionated as to what encoding convention is used, but it is
    /// important that end users can easily access and understand it somehow.
    /// This reference information is a SNAPSHOT of data and so if the onchain
    /// state moves relative to this snapshot (e.g. vault owner mints additional
    /// tokens while auditor is driving home from the gold vault), the auditor
    /// can't accidentally certify data that doesn't match what they reviewed
    /// in the real world. A good example of this would be a block number or a
    /// transaction hash from the blockchain this contract is deployed to, from
    /// which an offchain indexer such as a subgraph can compile all the mints,
    /// burns, additional data, etc. It is also STRONGLY RECOMMENDED that a self
    /// describing data format is used so that clients can interpret whether the
    /// reference is a block number, a transaction hash, a URL, etc.
    ///
    /// The certifier is STRONGLY RECOMMENDED to ONLY use publicly available
    /// documents e.g. those directly referenced by `ReceiptInformation` events
    /// to make their decision. The certifier SHOULD specify if, when and why
    /// private data was used to inform their certification decision. This is
    /// important for share (ERC20) holders who inform themselves on the quality
    /// of their tokens not only by the overall audit outcome, but by the
    /// integrity of the sum of its parts in the form of receipt and associated
    /// visible information.
    ///
    /// Note that redundant certifications MAY be submitted. Regardless of the
    /// `forceUntil` flag the transaction WILL NOT REVERT and the `Certify`
    /// event will be emitted for any valid `certifyUntil` time. If certifier A
    /// certifies until time X and certifier B certifies until time X - Y then
    /// both certifications will emit an event and time X is the certification
    /// date of the system. This encouranges multiple certifications to be sought
    /// in parallel if it helps maintain trust in the overall system.
    ///
    /// @param certifyUntil The new `certifiedUntil` time.
    /// @param forceUntil Whether to force the new certification time even if it
    /// is in the past relative to the existing certification time.
    /// @param data Arbitrary data justifying the certification. SHOULD reference
    /// data available offchain e.g. indexed data from this blockchain, IPFS,
    /// etc.
    function certify(uint256 certifyUntil, bool forceUntil, bytes calldata data) external {
        if (certifyUntil == 0) {
            revert ZeroCertifyUntil();
        }
        CertifyStateChange memory certifyStateChange = CertifyStateChange({
            oldCertifiedUntil: sCertifiedUntil,
            newCertifiedUntil: sCertifiedUntil,
            userCertifyUntil: certifyUntil,
            forceUntil: forceUntil,
            data: data
        });

        // A certifier can set `forceUntil` to true to force a _decrease_ in
        // the `certifiedUntil` time, which is unusual but MAY need to be done
        // in the case of rectifying a prior mistake.
        if (forceUntil || certifyUntil > sCertifiedUntil) {
            sCertifiedUntil = certifyUntil;
            certifyStateChange.newCertifiedUntil = sCertifiedUntil;
        }
        emit Certify(msg.sender, certifyUntil, forceUntil, data);

        sAuthorizor.authorize(msg.sender, CERTIFY, abi.encode(certifyStateChange));
    }

    function isCertificationExpired() internal view returns (bool) {
        return block.timestamp > sCertifiedUntil;
    }

    /// Apply standard transfer restrictions to share transfers.
    /// @inheritdoc ReceiptVault
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        sAuthorizor.authorize(
            msg.sender,
            TRANSFER_SHARES,
            abi.encode(
                TransferSharesStateChange({
                    from: from,
                    to: to,
                    amount: amount,
                    isCertificationExpired: isCertificationExpired()
                })
            )
        );
    }

    /// Confiscators can confiscate ERC20 vault shares from `confiscatee`.
    /// Confiscation BYPASSES TRANSFER RESTRICTIONS due to system freeze and
    /// IGNORES ALLOWANCES set by the confiscatee.
    ///
    /// The LIMITATION ON CONFISCATION is that the confiscatee MUST NOT have the
    /// minimum tier for transfers. I.e. confiscation is a two step process.
    /// First the tokens must be frozen according to due process by the token
    /// issuer (which may be an individual, organisation or many entities), THEN
    /// the confiscation can clear. This prevents rogue/compromised confiscators
    /// from being able to arbitrarily take tokens from users to themselves. At
    /// the least, assuming separate private keys managing the tiers and
    /// confiscation, the two steps require at least two critical security
    /// breaches per attack rather than one.
    ///
    /// Confiscation is a binary event. All shares or zero shares are
    /// confiscated from the confiscatee.
    ///
    /// Typically people DO NOT LIKE having their assets confiscated. It SHOULD
    /// be treated as a rare and extreme action, only taken when all other
    /// avenues/workarounds are explored and exhausted. The confiscator SHOULD
    /// provide their justification of each confiscation, and the general public,
    /// especially token holders SHOULD review and be highly suspect of unjust
    /// confiscation events. If you review and DO NOT agree with a confiscation
    /// you SHOULD NOT continue to hold the token, exiting systems that play fast
    /// and loose with user assets is the ONLY way to discourage such behaviour.
    ///
    /// @param confiscatee The address that shares are being confiscated from.
    /// @param targetAmount The amount of shares to confiscate. The actual amount
    /// will be capped at the current balance of the confiscatee.
    /// @param data The associated justification of the confiscation, and/or
    /// other relevant data.
    /// @return The amount of shares confiscated.
    function confiscateShares(address confiscatee, uint256 targetAmount, bytes memory data)
        external
        nonReentrant
        returns (uint256)
    {
        if (targetAmount == 0) {
            revert ZeroConfiscateAmount();
        }

        uint256 actualAmount = balanceOf(confiscatee).min(targetAmount);
        if (actualAmount > 0) {
            emit ConfiscateShares(msg.sender, confiscatee, targetAmount, actualAmount, data);
            _transfer(confiscatee, msg.sender, actualAmount);
        }

        sAuthorizor.authorize(
            msg.sender,
            CONFISCATE_SHARES,
            abi.encode(
                ConfiscateSharesStateChange({
                    confiscatee: confiscatee,
                    targetAmount: targetAmount,
                    actualAmount: actualAmount,
                    data: data
                })
            )
        );

        return actualAmount;
    }

    /// Confiscators can confiscate ERC1155 vault receipts from `confiscatee`.
    /// The process, limitations and logic is identical to share confiscation
    /// except that receipt confiscation is performed per-ID.
    ///
    /// Typically people DO NOT LIKE having their assets confiscated. It SHOULD
    /// be treated as a rare and extreme action, only taken when all other
    /// avenues/workarounds are explored and exhausted. The confiscator SHOULD
    /// provide their justification of each confiscation, and the general public,
    /// especially token holders SHOULD review and be highly suspect of unjust
    /// confiscation events. If you review and DO NOT agree with a confiscation
    /// you SHOULD NOT continue to hold the token, exiting systems that play fast
    /// and loose with user assets is the ONLY way to discourage such behaviour.
    ///
    /// @param confiscatee The address that receipts are being confiscated from.
    /// @param id The ID of the receipt to confiscate.
    /// @param targetAmount The amount of the receipt to confiscate. The actual
    /// amount will be capped at the current balance of the confiscatee.
    /// @param data The associated justification of the confiscation, and/or
    /// other relevant data.
    /// @return The amount of receipt confiscated.
    function confiscateReceipt(address confiscatee, uint256 id, uint256 targetAmount, bytes memory data)
        external
        nonReentrant
        returns (uint256)
    {
        if (targetAmount == 0) {
            revert ZeroConfiscateAmount();
        }

        uint256 actualAmount = receipt().balanceOf(confiscatee, id).min(targetAmount);
        if (actualAmount > 0) {
            emit ConfiscateReceipt(msg.sender, confiscatee, id, targetAmount, actualAmount, data);
            receipt().managerTransferFrom(confiscatee, msg.sender, id, actualAmount, "");
        }

        sAuthorizor.authorize(
            msg.sender,
            CONFISCATE_RECEIPT,
            abi.encode(
                ConfiscateReceiptStateChange({
                    confiscatee: confiscatee,
                    id: id,
                    targetAmount: targetAmount,
                    actualAmount: actualAmount,
                    data: data
                })
            )
        );

        return actualAmount;
    }
}
