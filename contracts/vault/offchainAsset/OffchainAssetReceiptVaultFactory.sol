// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Factory} from "@beehiveinnovation/rain-protocol/contracts/factory/Factory.sol";
import {OffchainAssetReceiptVault, OffchainAssetReceiptVaultConfig, OffchainAssetVaultConfig, ReceiptVaultConfig} from "./OffchainAssetReceiptVault.sol";
import {Receipt, ReceiptFactory, ReceiptConfig} from "../receipt/ReceiptFactory.sol";
import {ClonesUpgradeable as Clones} from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

/// @title OffchainAssetReceiptVaultFactory
/// @notice Factory for creating and deploying `OffchainAssetReceiptVault`.
contract OffchainAssetReceiptVaultFactory is Factory {
    event SetReceiptFactory(address caller, address receiptFactory);

    /// Template contract to clone.
    /// Deployed by the constructor.
    address public immutable implementation;
    address public immutable receiptFactory;

    /// Build the reference implementation to clone for each child.
    constructor(address receiptFactory_) {
        receiptFactory = receiptFactory_;
        emit SetReceiptFactory(msg.sender, receiptFactory_);

        address implementation_ = address(new OffchainAssetReceiptVault());
        emit Implementation(msg.sender, implementation_);
        implementation = implementation_;
    }

    /// @inheritdoc Factory
    function _createChild(bytes memory data_)
        internal
        virtual
        override
        returns (address)
    {
        (
            ReceiptConfig memory receiptConfig_,
            OffchainAssetVaultConfig memory offchainAssetVaultConfig_
        ) = abi.decode(data_, (ReceiptConfig, OffchainAssetVaultConfig));
        Receipt receipt_ = ReceiptFactory(receiptFactory).createChildTyped(
            receiptConfig_
        );

        address clone_ = Clones.clone(implementation);
        receipt_.transferOwnership(clone_);

        OffchainAssetReceiptVault(clone_).initialize(
            OffchainAssetReceiptVaultConfig(
                offchainAssetVaultConfig_.admin,
                ReceiptVaultConfig(
                    address(receipt_),
                    offchainAssetVaultConfig_.vaultConfig
                )
            )
        );
        return clone_;
    }

    /// Typed wrapper for `createChild` with Source.
    /// Use original `Factory` `createChild` function signature if function
    /// parameters are already encoded.
    ///
    /// @param config_ Config for the vault.
    /// @return New `OffchainAssetVault` child contract address.
    function createChildTyped(OffchainAssetVaultConfig memory config_)
        external
        returns (OffchainAssetReceiptVault)
    {
        return OffchainAssetReceiptVault(createChild(abi.encode(config_)));
    }
}
