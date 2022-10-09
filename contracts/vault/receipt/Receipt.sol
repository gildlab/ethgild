// SPDX-License-Identifier: UNLICENSE
pragma solidity =0.8.15;

import {ERC1155Upgradeable as ERC1155} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {OwnableUpgradeable as Ownable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./IReceiptOwner.sol";

struct ReceiptConstructionConfig {
    string uri;
}

contract Receipt is Ownable, ERC1155 {
    function initialize(ReceiptConstructionConfig memory config_) external initializer {
        __Ownable_init();
        __ERC1155_init(config_.uri);
    }

    function ownerMint(address account_, uint id_, uint amount_, bytes memory data_) external onlyOwner {
        _mint(account_, id_, amount_, data_);  
    }

    function ownerBurn(address account_, uint id_, uint amount_) external onlyOwner {
        _burn(account_, id_, amount_);
    }

    function ownerTransferFrom(address from_, address to_, uint id_, uint amount_, bytes memory data_) external onlyOwner {
        _safeTransferFrom(from_, to_, id_, amount_, data_);
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
        IReceiptOwner(owner()).authorizeReceiptTransfer(from_, to_);
    }
}
