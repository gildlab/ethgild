// SPDX-License-Identifier: UNLICENSE
pragma solidity =0.8.10;

// Open Zeppelin imports.
// solhint-ignore-next-line max-line-length
import {ERC20, ERC20Snapshot} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";

import "@beehiveinnovation/rain-protocol/contracts/tier/ITier.sol";
import "@beehiveinnovation/rain-protocol/contracts/tier/libraries/TierReport.sol";

struct CertifiedAssetConnectConfig {
    address admin;
    string name;
    string symbol;
    string uri;
}

contract CertifiedAssetConnect is
    ERC20Snapshot,
    ERC1155,
    ReentrancyGuard,
    AccessControl
{
    event Construction(address sender, CertifiedAssetConnectConfig config);
    event Certify(address sender, uint256 until, bytes data);
    event Connect(address sender, uint256 id, uint256 amount, bytes data);
    event Disconnect(address sender, uint256 id, uint256 amount, bytes data);

    bytes32 public constant CONNECTOR = keccak256("CONNECTOR");
    bytes32 public constant CONNECTOR_ADMIN = keccak256("CONNECTOR_ADMIN");

    bytes32 public constant DISCONNECTOR = keccak256("DISCONNECTOR");
    bytes32 public constant DISCONNECTOR_ADMIN =
        keccak256("DISCONNECTOR_ADMIN");

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

    uint256 private certifiedUntil;
    ITier private erc20Tier;
    uint256 private erc20MinimumTier;
    ITier private erc1155Tier;
    uint256 private erc1155MinimumTier;

    constructor(CertifiedAssetConnectConfig memory config_)
        ERC20(config_.name, config_.symbol)
        ERC1155(config_.uri)
    {
        _setRoleAdmin(CONNECTOR_ADMIN, CONNECTOR_ADMIN);
        _setRoleAdmin(CONNECTOR, CONNECTOR_ADMIN);

        _setRoleAdmin(DISCONNECTOR_ADMIN, DISCONNECTOR_ADMIN);
        _setRoleAdmin(DISCONNECTOR, DISCONNECTOR_ADMIN);

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

        _grantRole(CONNECTOR_ADMIN, config_.admin);
        _grantRole(DISCONNECTOR_ADMIN, config_.admin);
        _grantRole(CERTIFIER_ADMIN, config_.admin);
        _grantRole(HANDLER_ADMIN, config_.admin);
        _grantRole(ERC20TIERER_ADMIN, config_.admin);
        _grantRole(ERC1155TIERER_ADMIN, config_.admin);
        _grantRole(ERC20SNAPSHOTTER_ADMIN, config_.admin);

        emit Construction(msg.sender, config_);
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

    modifier onlyCertifiedTransfer(address from_, address to_) {
        // solhint-disable-next-line not-rely-on-time
        if (block.timestamp > certifiedUntil) {
            // Note the handler ALSO needs to meet associated tier requirements
            // for the token type being handled.
            require(
                hasRole(HANDLER, from_) || hasRole(HANDLER, to_),
                "ONLY_HANDLER"
            );
        }
        _;
    }

    modifier onlyTier(
        ITier tier_,
        uint256 minimumTier_,
        address to_
    ) {
        if (address(tier_) != address(0) && minimumTier_ > 0) {
            require(
                block.number >=
                    TierReport.tierBlock(tier_.report(to_), minimumTier_),
                "TIER"
            );
        }
        _;
    }

    // @inheritdoc ERC20
    function _beforeTokenTransfer(
        address from_,
        address to_,
        uint256
    )
        internal
        override
        onlyCertifiedTransfer(from_, to_)
        onlyTier(erc20Tier, erc20MinimumTier, to_)
    //solhint-disable-next-line no-empty-blocks
    {

    }

    // @inheritdoc ERC1155
    function _beforeTokenTransfer(
        address,
        address from_,
        address to_,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    )
        internal
        override
        onlyCertifiedTransfer(from_, to_)
        onlyTier(erc1155Tier, erc1155MinimumTier, to_)
    //solhint-disable-next-line no-empty-blocks
    {

    }

    function connect(uint256 amount_, bytes calldata data_)
        external
        nonReentrant
        onlyRole(CONNECTOR)
        returns (uint256)
    {
        // Hashing the `amount_` and `data_` together to produce the internal
        // `id_` effectively disallows partial burns on disconnect.
        uint256 id_ = uint256(keccak256(abi.encodePacked(amount_, data_)));
        emit Connect(msg.sender, id_, amount_, data_);
        // erc20 mint.
        _mint(msg.sender, amount_);

        // erc1155 mint.
        // Receiving contracts MUST implement `IERC1155Receiver`.
        _mint(msg.sender, id_, amount_, data_);
        return id_;
    }

    function disconnect(uint256 amount_, bytes calldata data_)
        external
        nonReentrant
        onlyRole(DISCONNECTOR)
        returns (uint256)
    {
        uint256 id_ = uint256(keccak256(abi.encodePacked(amount_, data_)));
        emit Disconnect(msg.sender, id_, amount_, data_);
        // erc20 burn.
        _burn(msg.sender, amount_);
        // erc1155 burn.
        _burn(msg.sender, id_, amount_);
        return id_;
    }
}
