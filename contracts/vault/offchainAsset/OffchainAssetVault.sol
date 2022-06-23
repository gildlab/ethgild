// SPDX-License-Identifier: UNLICENSE
pragma solidity =0.8.10;

import {ConstructionConfig as ReceiptVaultConstructionConfig, ReceiptVault, ERC1155} from "../ReceiptVault.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "@beehiveinnovation/rain-protocol/contracts/tier/ITier.sol";
import "@beehiveinnovation/rain-protocol/contracts/tier/libraries/TierReport.sol";

/// All data required to construct `CertifiedAssetConnect`.
/// @param admin The initial admin has ALL ROLES. It is up to the admin to
/// appropriately delegate and renounce roles or to be a smart contract with
/// formal governance processes. In general a single EOA holding all admin roles
/// is completely insecure and counterproductive as it allows a single address
/// to both mint and audit assets (and many other things).
/// @param receiptConstructionConfig Forwarded to construction ReceiptVault.
struct ConstructionConfig {
    address admin;
    ReceiptVaultConstructionConfig receiptVaultConfig;
}

/// Report of all assets successfully confiscated. MAY be a subset of what was
/// requested for confiscation as multiple confiscations could be included in
/// a single block, and will clear in order.
/// @param sharesAmount Total shares confiscated.
struct ConfiscationReport {
    uint256 sharesAmount;
    uint256[2][] erc1155Amounts;
}

contract OffchainAssetVault is ReceiptVault, AccessControl {
    event Construction(address sender, ConstructionConfig config);
    event Certify(address sender, uint256 until, bytes data);
    event Confiscate(address sender, ConfiscationReport report);

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

    uint256 private certifiedUntil;
    ITier private erc20Tier;
    uint256 private erc20MinimumTier;
    ITier private erc1155Tier;
    uint256 private erc1155MinimumTier;

    constructor(ConstructionConfig memory config_)
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

        emit Construction(msg.sender, config_);
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
    /// @param data_ Forwarded to receipt mint and `assetInformation`.
    function redeposit(
        uint256 assets_,
        address receiver_,
        uint256 id_,
        bytes calldata data_
    ) external returns (uint256 shares_) {
        require(balanceOf(msg.sender, id_) > 0, "NOT_RECEIPT_HOLDER");
        _deposit(
            assets_,
            receiver_,
            _shareRatio(msg.sender, receiver_),
            id_,
            data_
        );
        shares_ = assets_;
    }

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
    function setERC20Tier(address tier_, uint256 minimumTier_)
        external
        onlyRole(ERC20TIERER)
    {
        erc20Tier = ITier(tier_);
        erc20MinimumTier = minimumTier_;
    }

    /// @param tier_ `ITier` contract to check reports from. MAY be `0` to
    /// disable report checking.
    /// @param minimumTier_ The minimum tier to be held according to `tier_`.
    function setERC1155Tier(address tier_, uint256 minimumTier_)
        external
        onlyRole(ERC1155TIERER)
    {
        erc1155Tier = ITier(tier_);
        erc1155MinimumTier = minimumTier_;
    }

    function certify(
        uint256 until_,
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
        ITier tier_,
        uint256 minimumTier_,
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
                block.number >=
                    TierReport.tierBlock(tier_.report(from_), minimumTier_),
                "SENDER_TIER"
            );
            // The recipient must have a valid tier.
            require(
                block.number >=
                    TierReport.tierBlock(tier_.report(to_), minimumTier_),
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
        enforceValidTransfer(erc20Tier, erc20MinimumTier, from_, to_);
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
        enforceValidTransfer(erc1155Tier, erc1155MinimumTier, from_, to_);
    }

    // If there is no tier address then we always allow confiscations.
    // This means significant additional trust is placed on the
    // confiscators.
    // If there is a tier address we only allow confiscations from
    // addresses that are NOT currently holding the minimum tier.
    function confiscate(address confiscatee_, uint256[] calldata erc1155Ids_)
        external
        nonReentrant
        onlyRole(CONFISCATOR)
        returns (ConfiscationReport memory)
    {
        uint256 confiscatedERC20Amount_ = 0;
        if (
            address(erc20Tier) == address(0) ||
            block.number <
            TierReport.tierBlock(
                erc20Tier.report(confiscatee_),
                erc20MinimumTier
            )
        ) {
            confiscatedERC20Amount_ = balanceOf(confiscatee_);
            if (confiscatedERC20Amount_ > 0) {
                _transfer(confiscatee_, msg.sender, confiscatedERC20Amount_);
            }
        }

        uint256[2][] memory confiscatedERC1155Amounts_ = new uint256[2][](
            erc1155Ids_.length
        );
        if (
            address(erc1155Tier) == address(0) ||
            block.number <
            TierReport.tierBlock(
                erc1155Tier.report(confiscatee_),
                erc1155MinimumTier
            )
        ) {
            for (uint256 i_ = 0; i_ < erc1155Ids_.length; i_++) {
                confiscatedERC1155Amounts_[i_] = [
                    erc1155Ids_[i_],
                    balanceOf(confiscatee_, erc1155Ids_[i_])
                ];
                if (confiscatedERC1155Amounts_[i_][1] > 0) {
                    _safeTransferFrom(
                        confiscatee_,
                        msg.sender,
                        confiscatedERC1155Amounts_[i_][0],
                        confiscatedERC1155Amounts_[i_][1],
                        ""
                    );
                }
            }
        }

        ConfiscationReport memory report_ = ConfiscationReport(
            confiscatedERC20Amount_,
            confiscatedERC1155Amounts_
        );
        emit Confiscate(msg.sender, report_);
        return report_;
    }
}
