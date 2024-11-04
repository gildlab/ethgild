// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/interface/ICloneableV2.sol";

import {IReceiptOwnerV1} from "../../interface/IReceiptOwnerV1.sol";
import {IReceiptV1} from "../../interface/IReceiptV1.sol";

import {ERC1155Upgradeable as ERC1155} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import {OwnableUpgradeable as Ownable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {StringsUpgradeable as Strings} from "openzeppelin-contracts-upgradeable/contracts/utils/StringsUpgradeable.sol";

/// @dev the ERC1155 URI is always the pinned metadata on ipfs.
string constant RECEIPT_METADATA_URI = "ipfs://bafkreih7cvpjocgrk7mgdel2hvjpquc26j4jo2jkez5y2qdaojfil7vley";

/// @title Receipt
/// @notice The `IReceiptV1` for a `ReceiptVault`. Standard implementation allows
/// receipt information to be emitted and mints/burns according to ownership and
/// owner authorization.
contract Receipt is IReceiptV1, Ownable, ERC1155, ICloneableV2 {
    /// Disables initializers so that the clonable implementation cannot be
    /// initialized and used directly outside a factory deployment.
    constructor() {
        _disableInitializers();
    }

    /// Initializes the `Receipt` so that it is usable as a clonable
    /// implementation in `ReceiptFactory`.
    function initialize(bytes memory data) external override initializer returns (bytes32) {
        __Ownable_init();
        __ERC1155_init(RECEIPT_METADATA_URI);

        address initialOwner = abi.decode(data, (address));
        _transferOwnership(initialOwner);

        return ICLONEABLE_V2_SUCCESS;
    }

    /// @inheritdoc IReceiptV1
    function owner() public view virtual override(IReceiptV1, Ownable) returns (address) {
        return Ownable.owner();
    }

    /// @inheritdoc IReceiptV1
    function ownerMint(address sender, address account, uint256 id, uint256 amount, bytes memory data)
        external
        virtual
        onlyOwner
    {
        _receiptInformation(sender, id, data);
        _mint(account, id, amount, data);
    }

    /// @inheritdoc IReceiptV1
    function ownerBurn(address sender, address account, uint256 id, uint256 amount, bytes memory data)
        external
        virtual
        onlyOwner
    {
        _receiptInformation(sender, id, data);
        _burn(account, id, amount);
    }

    /// @inheritdoc IReceiptV1
    function ownerTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data)
        external
        virtual
        onlyOwner
    {
        _safeTransferFrom(from, to, id, amount, data);
    }

    /// Checks with the owner before authorizing transfer IN ADDITION to `super`
    /// inherited checks.
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
        IReceiptOwnerV1(owner()).authorizeReceiptTransfer(from, to);
    }

    /// Emits `ReceiptInformation` if there is any data after checking with the
    /// receipt owner for authorization.
    /// @param account The account that is emitting receipt information.
    /// @param id The id of the receipt this information is for.
    /// @param data The data being emitted as information for the receipt.
    function _receiptInformation(address account, uint256 id, bytes memory data) internal virtual {
        // No data is noop.
        if (data.length > 0) {
            emit ReceiptInformation(account, id, data);
        }
    }

    /// @inheritdoc IReceiptV1
    function receiptInformation(uint256 id, bytes memory data) external virtual {
        _receiptInformation(msg.sender, id, data);
    }
}
