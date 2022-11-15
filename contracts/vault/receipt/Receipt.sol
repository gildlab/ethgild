// SPDX-License-Identifier: UNLICENSE
pragma solidity =0.8.17;

import {ERC1155Upgradeable as ERC1155} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {OwnableUpgradeable as Ownable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./IReceiptOwner.sol";
import "./IReceipt.sol";

struct ReceiptConstructionConfig {
    string uri;
}

contract Receipt is IReceipt, Ownable, ERC1155 {
    /// Emitted when new information is provided for a receipt.
    /// @param caller `msg.sender` emitting the information for the receipt.
    /// @param id Receipt the information is for.
    /// @param information Information for the receipt. MAY reference offchain
    /// data where the payload is large.
    event ReceiptInformation(address caller, uint256 id, bytes information);

    function initialize(ReceiptConstructionConfig memory config_)
        external
        initializer
    {
        __Ownable_init();
        __ERC1155_init(config_.uri);
    }

    /// @inheritdoc IReceipt
    function ownerMint(
        address account_,
        uint256 id_,
        uint256 amount_,
        bytes memory data_
    ) external onlyOwner {
        _mint(account_, id_, amount_, data_);
        receiptInformation(id_, data_);
    }

    /// @inheritdoc IReceipt
    function ownerBurn(
        address account_,
        uint256 id_,
        uint256 amount_
    ) external onlyOwner {
        _burn(account_, id_, amount_);
    }

    /// @inheritdoc IReceipt
    function ownerTransferFrom(
        address from_,
        address to_,
        uint256 id_,
        uint256 amount_,
        bytes memory data_
    ) external onlyOwner {
        _safeTransferFrom(from_, to_, id_, amount_, data_);
    }

    /// @inheritdoc ERC1155
    function _beforeTokenTransfer(
        address operator_,
        address from_,
        address to_,
        uint256[] memory ids_,
        uint256[] memory amounts_,
        bytes memory data_
    ) internal override virtual {
        super._beforeTokenTransfer(operator_, from_, to_, ids_, amounts_, data_);
        IReceiptOwner(owner()).authorizeReceiptTransfer(from_, to_);
    }

    /// @inheritdoc IReceipt
    function receiptInformation(uint256 id_, bytes memory data_) public {
        // No data is noop.
        if (data_.length > 0) {
            IReceiptOwner(owner()).authorizeReceiptInformation(id_, data_);
            emit ReceiptInformation(msg.sender, id_, data_);
        }
    }
}