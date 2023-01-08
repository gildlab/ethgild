// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Factory} from "@rainprotocol/rain-protocol/contracts/factory/Factory.sol";
import {Receipt, ReceiptFactory, ReceiptConfig} from "../receipt/ReceiptFactory.sol";
import {ClonesUpgradeable as Clones} from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

abstract contract ReceiptVaultFactory is Factory {
    event SetReceiptFactory(address caller, address receiptFactory);

    /// Template contract to clone.
    /// Deployed by the constructor.
    address public immutable implementation;
    address public immutable receiptFactory;

    /// Build the reference implementation to clone for each child.
    constructor(address receiptFactory_) {
        require(receiptFactory_ != address(0), "0_RECEIPT_FACTORY");
        receiptFactory = receiptFactory_;
        emit SetReceiptFactory(msg.sender, receiptFactory_);

        address implementation_ = _createImplementation();
        emit Implementation(msg.sender, implementation_);
        implementation = implementation_;
    }

    function _createImplementation() internal virtual returns (address) {

    }
}