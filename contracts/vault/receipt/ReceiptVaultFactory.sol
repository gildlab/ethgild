// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Factory} from "@rainprotocol/rain-protocol/contracts/factory/Factory.sol";
import {Receipt, ReceiptFactory} from "../receipt/ReceiptFactory.sol";
import {ClonesUpgradeable as Clones} from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

/// Thrown when the provided implementation is address zero.
error ZeroImplementation();

/// Thrown when the provided receipt factory is address zero.
error ZeroReceiptFactory();

/// All config required to construct the `ReceiptVaultFactory`.
/// @param implementation Template contract to clone for each child.
/// @param receiptFactory `ReceiptFactory` to produce receipts for each child.
struct ReceiptVaultFactoryConfig {
    address implementation;
    address receiptFactory;
}

abstract contract ReceiptVaultFactory is Factory {
    event Construction(address caller, ReceiptVaultFactoryConfig config);

    /// Template contract to clone for each child.
    address public immutable implementation;
    /// Factory that produces receipts for the receipt vault.
    address public immutable receiptFactory;

    /// Build the reference implementation to clone for each child.
    constructor(ReceiptVaultFactoryConfig memory config_) {
        if (config_.implementation == address(0)) {
            revert ZeroImplementation();
        }
        if (config_.receiptFactory == address(0)) {
            revert ZeroReceiptFactory();
        }

        implementation = config_.implementation;
        receiptFactory = config_.receiptFactory;

        emit Implementation(msg.sender, config_.implementation);
        emit Construction(msg.sender, config_);
    }
}
