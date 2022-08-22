// SPDX-License-Identifier: UNLICENSE
pragma solidity =0.8.10;

import {ReceiptVaultConstructionConfig, ReceiptVault, ERC1155} from "../ReceiptVault.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "@beehiveinnovation/rain-protocol/contracts/tier/ITierV2.sol";

/// All data required to construct `CertifiedAssetConnect`.
/// @param admin The initial admin has ALL ROLES. It is up to the admin to
/// appropriately delegate and renounce roles or to be a smart contract with
/// formal governance processes. In general a single EOA holding all admin roles
/// is completely insecure and counterproductive as it allows a single address
/// to both mint and audit assets (and many other things).
/// @param receiptConstructionConfig Forwarded to construction ReceiptVault.
struct OffchainAssetVaultConstructionConfig {
    address admin;
    ReceiptVaultConstructionConfig receiptVaultConfig;
}

/// @title OffchainAssetVault
/// @notice Enables curators of offchain assets to create a token that they can
/// arbitrage offchain assets against onchain assets. This allows them to
/// maintain a peg between offchain and onchain markets.
///
/// At a high level this works because the custodian can always profitably trade
/// the peg against offchain markets in both directions.
///
/// Price is higher onchain: Custodian can buy/produce assets offchain and mint
/// tokens then sell the tokens for more than the assets would sell for offchain
/// thus making a profit. The sale of the tokens brings the onchain price down.
/// Price is higher offchain: Custodian can sell assets offchain and
/// buyback+burn tokens onchain for less than the offchain sale, thus making a
/// profit. The token purchase brings the onchain price up.
///
/// In contrast to pure algorithmic tokens and sentiment based stablecoins, a
/// competent custodian can profit "infinitely" to maintain the peg no matter
/// how badly the peg breaks. As long as every token is fully collateralised by
/// liquid offchain assets tokens can be profitably bought and burned by the
/// custodian all the way to 0 token supply.
///
/// This model is contingent on existing onchain and offchain liquidity
/// and the custodian being competent. These requirements are non-trivial. There
/// are far more incompetent and malicious custodians than competent ones. Only
/// so many bars of gold can fit in a vault, and only so many trees that can
/// live in a forest.
///
/// This contract does not attempt to solve for liquidity and trustworthyness,
/// it only seeks to provide baseline functionality that a competent custodian
/// will need to tackle the problem. The implementation provides:
///
/// - ReceiptVault base that allows a transparent onchain/offchain audit history
/// - Certifier role that allows for audits of offchain assets that can fail
/// - KYC/membership lists that can restrict who can hold/transfer assets
/// - Ability to comply with sanctions/regulators by confiscating assets
/// - ERC20 shares in the vault that can be traded minted/burned to track a peg
/// - ERC4626 compliant vault interface (inherited from ReceiptVault)
/// - Fine grained standard Open Zeppelin access control for all system roles
contract OffchainAssetVault is ReceiptVault, AccessControl {
    /// Contract has constructed.
    /// @param caller The `msg.sender` constructing the contract.
    /// @param config All construction config.
    event OffchainAssetVaultConstruction(
        address caller,
        OffchainAssetVaultConstructionConfig config
    );

    /// A new certification time has been set.
    /// @param caller The certifier setting the new time.
    /// @param until The time the system is certified until. Normally this will
    /// be a future time but certifiers MAY set it to a time in the past which
    /// will immediately freeze all transfers.
    /// @param data The certifier MAY provide additional supporting data such
    /// as an auditor's report/comments etc.
    event Certify(address caller, uint256 until, bytes data);

    /// Shares have been confiscated from a user who is not currently meeting
    /// the ERC20 tier contract minimum requirements.
    /// @param caller The confiscator who is confiscating the shares.
    /// @param confiscatee The user who had their shares confiscated.
    /// @param confiscated The amount of shares that were confiscated.
    event ConfiscateShares(
        address caller,
        address confiscatee,
        uint256 confiscated
    );

    /// A receipt has been confiscated from a user who is not currently meeting
    /// the ERC1155 tier contract minimum requirements.
    /// @param caller The confiscator who is confiscating the receipt.
    /// @param confiscatee The user who had their receipt confiscated.
    /// @param id The receipt ID that was confiscated.
    /// @param confiscated The amount of the receipt that was confiscated.
    event ConfiscateReceipt(
        address caller,
        address confiscatee,
        uint256 id,
        uint256 confiscated
    );

    /// A new ERC20 tier contract has been set.
    /// @param caller `msg.sender` who set the new tier contract.
    /// @param tier New tier contract used for all ERC20 transfers and
    /// confiscations.
    /// @param minimumTier Minimum tier that a user must hold to be eligible
    /// to send/receive/hold shares and be immune to share confiscations.
    /// @param context OPTIONAL additional context to pass to ITierV2 calls.
    event SetERC20Tier(
        address caller,
        address tier,
        uint256 minimumTier,
        uint256[] context
    );

    /// A new ERC1155 tier contract has been set.
    /// @param caller `msg.sender` who set the new tier contract.
    /// @param tier New tier contract used for all ERC1155 transfers and
    /// confiscations.
    /// @param minimumTier Minimum tier that a user must hold to be eligible
    /// to send/receive/hold receipts and be immune to receipt confiscations.
    /// @param context OPTIONAL additional context to pass to ITierV2 calls.
    event SetERC1155Tier(
        address caller,
        address tier,
        uint256 minimumTier,
        uint256[] context
    );

    bytes32 public constant DEPOSITOR = keccak256("DEPOSITOR");
    bytes32 public constant DEPOSITOR_ADMIN = keccak256("DEPOSITOR_ADMIN");

    bytes32 public constant WITHDRAWER = keccak256("WITHDRAWER");
    bytes32 public constant WITHDRAWER_ADMIN = keccak256("WITHDRAWER_ADMIN");

    bytes32 public constant CERTIFIER = keccak256("CERTIFIER");
    bytes32 public constant CERTIFIER_ADMIN = keccak256("CERTIFIER_ADMIN");

    bytes32 public constant HANDLER = keccak256("HANDLER");
    bytes32 public constant HANDLER_ADMIN = keccak256("HANDLER_ADMIN");

    bytes32 public constant ERC20TIERER = keccak256("ERC20TIERER");
    bytes32 public constant ERC20TIERER_ADMIN = keccak256("ERC20TIERER_ADMIN");

    bytes32 public constant ERC1155TIERER = keccak256("ERC1155TIERER");
    bytes32 public constant ERC1155TIERER_ADMIN =
        keccak256("ERC1155TIERER_ADMIN");

    bytes32 public constant ERC20SNAPSHOTTER = keccak256("ERC20SNAPSHOTTER");
    bytes32 public constant ERC20SNAPSHOTTER_ADMIN =
        keccak256("ERC20SNAPSHOTTER_ADMIN");

    bytes32 public constant CONFISCATOR = keccak256("CONFISCATOR");
    bytes32 public constant CONFISCATOR_ADMIN = keccak256("CONFISCATOR_ADMIN");

    uint256 private highwaterId;

    uint32 private certifiedUntil;

    uint8 private erc20MinimumTier;
    ITierV2 private erc20Tier;
    uint256[] private erc20TierContext;

    uint8 private erc1155MinimumTier;
    ITierV2 private erc1155Tier;
    uint256[] private erc1155TierContext;

    constructor(OffchainAssetVaultConstructionConfig memory config_)
        ReceiptVault(config_.receiptVaultConfig)
    {
        // There is no asset, the asset is offchain.
        require(
            config_.receiptVaultConfig.asset == address(0),
            "NONZERO_ASSET"
        );

        _setRoleAdmin(DEPOSITOR_ADMIN, DEPOSITOR_ADMIN);
        _setRoleAdmin(DEPOSITOR, DEPOSITOR_ADMIN);

        _setRoleAdmin(WITHDRAWER_ADMIN, WITHDRAWER_ADMIN);
        _setRoleAdmin(WITHDRAWER, WITHDRAWER_ADMIN);

        _setRoleAdmin(CERTIFIER_ADMIN, CERTIFIER_ADMIN);
        _setRoleAdmin(CERTIFIER, CERTIFIER_ADMIN);

        _setRoleAdmin(HANDLER_ADMIN, HANDLER_ADMIN);
        _setRoleAdmin(HANDLER, HANDLER_ADMIN);

        _setRoleAdmin(ERC20TIERER_ADMIN, ERC20TIERER_ADMIN);
        _setRoleAdmin(ERC20TIERER, ERC20TIERER_ADMIN);

        _setRoleAdmin(ERC1155TIERER_ADMIN, ERC1155TIERER_ADMIN);
        _setRoleAdmin(ERC1155TIERER, ERC1155TIERER_ADMIN);

        _setRoleAdmin(ERC20SNAPSHOTTER_ADMIN, ERC20SNAPSHOTTER_ADMIN);
        _setRoleAdmin(ERC20SNAPSHOTTER, ERC20SNAPSHOTTER_ADMIN);

        _setRoleAdmin(CONFISCATOR_ADMIN, CONFISCATOR_ADMIN);
        _setRoleAdmin(CONFISCATOR, CONFISCATOR_ADMIN);

        _grantRole(DEPOSITOR_ADMIN, config_.admin);
        _grantRole(WITHDRAWER_ADMIN, config_.admin);
        _grantRole(CERTIFIER_ADMIN, config_.admin);
        _grantRole(HANDLER_ADMIN, config_.admin);
        _grantRole(ERC20TIERER_ADMIN, config_.admin);
        _grantRole(ERC1155TIERER_ADMIN, config_.admin);
        _grantRole(ERC20SNAPSHOTTER_ADMIN, config_.admin);
        _grantRole(CONFISCATOR_ADMIN, config_.admin);

        emit OffchainAssetVaultConstruction(msg.sender, config_);
    }

    function _beforeDeposit(
        uint256,
        address,
        uint256,
        uint256
    ) internal view override {
        require(hasRole(DEPOSITOR, msg.sender), "NOT_DEPOSITOR");
    }

    function _afterWithdraw(
        uint256,
        address,
        address owner_,
        uint256,
        uint256
    ) internal view override {
        require(hasRole(WITHDRAWER, owner_), "NOT_WITHDRAWER");
    }

    /// Shares total supply is 1:1 with offchain assets.
    /// Assets aren't real so only way to report this is to return the total
    /// supply of shares.
    /// @inheritdoc ReceiptVault
    function totalAssets()
        external
        view
        override
        returns (uint256 totalManagedAssets_)
    {
        totalManagedAssets_ = totalSupply();
    }

    function _shareRatio(address depositor_, address)
        internal
        view
        override
        returns (uint256 shareRatio_)
    {
        shareRatio_ = hasRole(DEPOSITOR, depositor_) ? _shareRatio() : 0;
    }

    /// Offchain assets are always deposited 1:1 with shares.
    /// @inheritdoc ReceiptVault
    function previewDeposit(uint256 assets_)
        external
        view
        override
        returns (uint256 shares_)
    {
        shares_ = hasRole(DEPOSITOR, msg.sender) ? assets_ : 0;
    }

    function previewWithdraw(uint256 assets_, uint256 id_)
        public
        view
        override
        returns (uint256 shares_)
    {
        shares_ = hasRole(WITHDRAWER, msg.sender)
            ? super.previewWithdraw(assets_, id_)
            : 0;
    }

    function previewMint(uint256 shares_)
        public
        view
        override
        returns (uint256 assets_)
    {
        assets_ = hasRole(DEPOSITOR, msg.sender)
            ? super.previewMint(shares_)
            : 0;
    }

    function previewRedeem(uint256 shares_, uint256 id_)
        public
        view
        override
        returns (uint256 assets_)
    {
        assets_ = hasRole(WITHDRAWER, msg.sender)
            ? super.previewRedeem(shares_, id_)
            : 0;
    }

    function _nextId() internal override returns (uint256 id_) {
        id_ = highwaterId + 1;
        highwaterId = id_;
    }

    function _beforeReceiptInformation(uint256 id_, bytes memory)
        internal
        view
        override
    {
        // Only receipt holders and certifiers can assert things about offchain
        // assets.
        require(
            balanceOf(msg.sender, id_) > 0 || hasRole(CERTIFIER, msg.sender),
            "ASSET_INFORMATION_AUTH"
        );
    }

    /// Receipt holders who are also depositors can increase the deposit amount
    /// for the existing id of this receipt. It is STRONGLY RECOMMENDED the
    /// redepositor also provides data to be forwarded to asset information to
    /// justify the additional deposit. New offchain assets MUST NOT redeposit
    /// under existing IDs, deposit under a new id instead.
    /// @param assets_ As per IERC4626 `deposit`.
    /// @param receiver_ As per IERC4626 `deposit`.
    /// @param id_ The existing receipt to despoit additional assets under. Will
    /// mint new ERC20 shares and also increase the held receipt amount 1:1.
    /// @param receiptInformation_ Forwarded to receipt mint and
    /// `receiptInformation`.
    function redeposit(
        uint256 assets_,
        address receiver_,
        uint256 id_,
        bytes calldata receiptInformation_
    ) external returns (uint256 shares_) {
        require(balanceOf(msg.sender, id_) > 0, "NOT_RECEIPT_HOLDER");
        _deposit(
            assets_,
            receiver_,
            _shareRatio(msg.sender, receiver_),
            id_,
            receiptInformation_
        );
        shares_ = assets_;
    }

    /// Needed here to fix Open Zeppelin implementing `supportsInterface` on
    /// multiple base contracts.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function snapshot() external onlyRole(ERC20SNAPSHOTTER) returns (uint256) {
        return _snapshot();
    }

    /// @param tier_ `ITier` contract to check reports from. MAY be `0` to
    /// disable report checking.
    /// @param minimumTier_ The minimum tier to be held according to `tier_`.
    function setERC20Tier(
        address tier_,
        uint8 minimumTier_,
        uint256[] calldata context_
    ) external onlyRole(ERC20TIERER) {
        erc20Tier = ITierV2(tier_);
        erc20MinimumTier = minimumTier_;
        erc20TierContext = context_;
        emit SetERC20Tier(msg.sender, tier_, minimumTier_, context_);
    }

    /// @param tier_ `ITier` contract to check reports from. MAY be `0` to
    /// disable report checking.
    /// @param minimumTier_ The minimum tier to be held according to `tier_`.
    function setERC1155Tier(
        address tier_,
        uint8 minimumTier_,
        uint256[] calldata context_
    ) external onlyRole(ERC1155TIERER) {
        erc1155Tier = ITierV2(tier_);
        erc1155MinimumTier = minimumTier_;
        erc1155TierContext = context_;
        emit SetERC1155Tier(msg.sender, tier_, minimumTier_, context_);
    }

    function certify(
        uint32 until_,
        bytes calldata data_,
        bool forceUntil_
    ) external onlyRole(CERTIFIER) {
        // A certifier can set `forceUntil_` to true to force a _decrease_ in
        // the `certifiedUntil` time, which is unusual but MAY need to be done
        // in the case of rectifying a prior mistake.
        if (forceUntil_ || until_ > certifiedUntil) {
            certifiedUntil = until_;
        }
        emit Certify(msg.sender, until_, data_);
    }

    function enforceValidTransfer(
        ITierV2 tier_,
        uint256 minimumTier_,
        uint256[] memory tierContext_,
        address from_,
        address to_
    ) internal view {
        // Handlers can ALWAYS send and receive funds.
        // Handlers bypass BOTH the timestamp on certification AND tier based
        // restriction.
        if (hasRole(HANDLER, from_) || hasRole(HANDLER, to_)) {
            return;
        }

        // Minting and burning is always allowed as it is controlled via. RBAC
        // separately to the tier contracts. Minting and burning is ALSO valid
        // after the certification expires as it is likely the only way to
        // repair the system and bring it back to a certifiable state.
        if (from_ == address(0) || to_ == address(0)) {
            return;
        }

        // Confiscation is always allowed as it likely represents some kind of
        // regulatory/legal requirement. It may also be required to satisfy
        // certification requirements.
        if (hasRole(CONFISCATOR, to_)) {
            return;
        }

        // Everyone else can only transfer while the certification is valid.
        //solhint-disable-next-line not-rely-on-time
        require(block.timestamp <= certifiedUntil, "CERTIFICATION_EXPIRED");

        // If there is a tier contract we enforce it.
        if (address(tier_) != address(0) && minimumTier_ > 0) {
            // The sender must have a valid tier.
            require(
                block.timestamp >=
                    tier_.reportTimeForTier(from_, minimumTier_, tierContext_),
                "SENDER_TIER"
            );
            // The recipient must have a valid tier.
            require(
                block.timestamp >=
                    tier_.reportTimeForTier(to_, minimumTier_, tierContext_),
                "RECIPIENT_TIER"
            );
        }
    }

    // @inheritdoc ERC20
    function _beforeTokenTransfer(
        address from_,
        address to_,
        uint256
    ) internal view override {
        enforceValidTransfer(
            erc20Tier,
            erc20MinimumTier,
            erc20TierContext,
            from_,
            to_
        );
    }

    // @inheritdoc ERC1155
    function _beforeTokenTransfer(
        address,
        address from_,
        address to_,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) internal view override {
        enforceValidTransfer(
            erc1155Tier,
            erc1155MinimumTier,
            erc1155TierContext,
            from_,
            to_
        );
    }

    function confiscate(address confiscatee_)
        external
        nonReentrant
        onlyRole(CONFISCATOR)
        returns (uint256 confiscated_)
    {
        if (
            address(erc20Tier) == address(0) ||
            block.timestamp <
            erc20Tier.reportTimeForTier(
                confiscatee_,
                erc20MinimumTier,
                erc20TierContext
            )
        ) {
            confiscated_ = balanceOf(confiscatee_);
            if (confiscated_ > 0) {
                _transfer(confiscatee_, msg.sender, confiscated_);
            }
        }
        emit ConfiscateShares(msg.sender, confiscatee_, confiscated_);
    }

    function confiscate(address confiscatee_, uint256 id_)
        external
        nonReentrant
        onlyRole(CONFISCATOR)
        returns (uint256 confiscated_)
    {
        if (
            address(erc1155Tier) == address(0) ||
            block.timestamp <
            erc1155Tier.reportTimeForTier(
                confiscatee_,
                erc1155MinimumTier,
                erc1155TierContext
            )
        ) {
            confiscated_ = balanceOf(confiscatee_, id_);
            if (confiscated_ > 0) {
                _safeTransferFrom(
                    confiscatee_,
                    msg.sender,
                    id_,
                    confiscated_,
                    ""
                );
            }
        }
        emit ConfiscateReceipt(msg.sender, confiscatee_, id_, confiscated_);
    }
}
