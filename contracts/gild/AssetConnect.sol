// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

// Open Zeppelin imports.
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";

import "@beehiveinnovation/rain-protocol/contracts/tier/ITier.sol";
import "@beehiveinnovation/rain-protocol/contracts/tier/libraries/TierReport.sol";

struct AssetConnectConfig {
    string name;
    string symbol;
    string uri;
}

contract AssetConnect is ERC20, ERC1155, ReentrancyGuard, AccessControl {
    event Construction(address sender, AssetConnectConfig config);
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

    uint256 private certifiedUntil;
    address private erc20Tier;
    uint256 private erc20MinimumTier;
    address private erc1155Tier;
    uint256 private erc1155MinimumTier;

    constructor(AssetConnectConfig memory config_)
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

        _setupRole(CONNECTOR_ADMIN, msg.sender);
        _setupRole(DISCONNECTOR_ADMIN, msg.sender);
        _setupRole(CERTIFIER_ADMIN, msg.sender);
        _setupRole(HANDLER_ADMIN, msg.sender);
        _setupRole(ERC20TIERER_ADMIN, msg.sender);
        _setupRole(ERC1155TIERER_ADMIN, msg.sender);

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

    function setERC20Tier(address tier_, uint256 minimumTier_)
        external
        onlyRole(ERC20TIERER)
    {
        erc20Tier = tier_;
        erc20MinimumTier = minimumTier_;
    }

    function setERC1155Tier(address tier_, uint256 minimumTier_)
        external
        onlyRole(ERC1155TIERER)
    {
        erc1155Tier = tier_;
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
        address tier_,
        uint256 minimumTier_,
        address to_
    ) {
        if (tier_ != address(0) && minimumTier_ > 0) {
            require(
                block.number >=
                    TierReport.tierBlock(
                        ITier(tier_).report(to_),
                        minimumTier_
                    ),
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
