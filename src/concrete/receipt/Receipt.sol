// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/interface/ICloneableV2.sol";

import {IReceiptManagerV1} from "../../interface/IReceiptManagerV1.sol";
import {IReceiptV2, IERC5313, ReceiptConfigV1} from "../../interface/IReceiptV2.sol";
import {OnlyManager} from "../../error/ErrReceipt.sol";
import {ERC1155Upgradeable as ERC1155} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import {OwnableUpgradeable as Ownable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {StringsUpgradeable as Strings} from "openzeppelin-contracts-upgradeable/contracts/utils/StringsUpgradeable.sol";

/// @dev The prefix for data URIs as base64 encoded JSON.
string constant DATA_URI_BASE64_PREFIX = "data:application/json;base64,";

/// @dev The URI for the metadata of the `Receipt` contract.
/// Decodes to a simple generic receipt metadata object.
/// `{"name":"Receipt","decimals":18,"description":"A receipt for a ReceiptVault."}`
string constant RECEIPT_METADATA_DATA_URI =
    "eyJuYW1lIjoiUmVjZWlwdCIsImRlY2ltYWxzIjoxOCwiZGVzY3JpcHRpb24iOiJBIHJlY2VpcHQgZm9yIGEgUmVjZWlwdFZhdWx0LiJ9";

/// @dev The symbol for the `Receipt` contract.
string constant RECEIPT_SYMBOL = "RECEIPT";

/// @dev The name for the `Receipt` contract.
string constant RECEIPT_NAME = "Receipt";

/// @title Receipt
/// @notice The `IReceiptV2` for a `ReceiptVault`. Standard implementation allows
/// receipt information to be emitted and mints/burns according to manager
/// authorization.
contract Receipt is IReceiptV2, Ownable, ERC1155, ICloneableV2 {
    /// The manager of the `Receipt` contract.
    /// Set during `initialize` and cannot be changed.
    /// Intended to be a `ReceiptVault` contract.
    IReceiptManagerV1 internal sManager;

    /// Disables initializers so that the clonable implementation cannot be
    /// initialized and used directly outside a factory deployment.
    constructor() {
        _disableInitializers();
    }

    /// Throws if the caller is not the manager of the `Receipt` contract.
    modifier onlyManager() {
        if (msg.sender != address(sManager)) {
            revert OnlyManager();
        }
        _;
    }

    /// Initializes the `Receipt` so that it is usable as a clonable
    /// implementation in `ReceiptFactory`.
    /// Compatible with `ICloneableV2`.
    function initialize(bytes memory data) external override initializer returns (bytes32) {
        __Ownable_init();
        __ERC1155_init(string.concat(DATA_URI_BASE64_PREFIX, RECEIPT_METADATA_DATA_URI));

        ReceiptConfigV1 memory config = abi.decode(data, (ReceiptConfigV1));
        _transferOwnership(config.receiptOwner);
        sManager = IReceiptManagerV1(config.receiptManager);

        return ICLONEABLE_V2_SUCCESS;
    }

    /// @inheritdoc IReceiptV2
    function name() external pure virtual returns (string memory) {
        return RECEIPT_NAME;
    }

    /// @inheritdoc IReceiptV2
    function symbol() external pure virtual returns (string memory) {
        return RECEIPT_SYMBOL;
    }

    /// @inheritdoc IReceiptV2
    function manager() external view virtual returns (address) {
        return address(sManager);
    }

    /// @inheritdoc IERC5313
    function owner() public view virtual override(IERC5313, Ownable) returns (address) {
        return Ownable.owner();
    }

    /// @inheritdoc IReceiptV2
    function managerMint(address sender, address account, uint256 id, uint256 amount, bytes memory data)
        external
        virtual
        onlyManager
    {
        _receiptInformation(sender, id, data);
        _mint(account, id, amount, data);
    }

    /// @inheritdoc IReceiptV2
    function managerBurn(address sender, address account, uint256 id, uint256 amount, bytes memory data)
        external
        virtual
        onlyManager
    {
        _receiptInformation(sender, id, data);
        _burn(account, id, amount);
    }

    /// @inheritdoc IReceiptV2
    function managerTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data)
        external
        virtual
        onlyManager
    {
        _safeTransferFrom(from, to, id, amount, data);
    }

    /// Checks with the manager before authorizing transfer IN ADDITION to
    /// `super` inherited checks.
    /// @inheritdoc ERC1155
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        sManager.authorizeReceiptTransfer2(from, to);
    }

    /// Emits `ReceiptInformation` if there is any data after checking with the
    /// receipt manager for authorization.
    /// @param account The account that is emitting receipt information.
    /// @param id The id of the receipt this information is for.
    /// @param data The data being emitted as information for the receipt.
    function _receiptInformation(address account, uint256 id, bytes memory data) internal virtual {
        // No data is noop.
        if (data.length > 0) {
            emit ReceiptInformation(account, id, data);
        }
    }

    /// @inheritdoc IReceiptV2
    function receiptInformation(uint256 id, bytes memory data) external virtual {
        _receiptInformation(msg.sender, id, data);
    }
}
