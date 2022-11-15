// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Factory} from "@beehiveinnovation/rain-protocol/contracts/factory/Factory.sol";
import {OffchainAssetVault, OffchainAssetVaultConfig} from "./OffchainAssetVault.sol";
import {ClonesUpgradeable as Clones} from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

/// @title OffchainAssetVaultFactory
/// @notice Factory for creating and deploying `OffchainAssetVault`.
contract OffchainAssetVaultFactory is Factory {
    /// Template contract to clone.
    /// Deployed by the constructor.
    address public immutable implementation;

    /// Build the reference implementation to clone for each child.
    constructor() {
        address implementation_ = address(new OffchainAssetVault());
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
        OffchainAssetVaultConfig memory config_ = abi.decode(
            data_,
            (OffchainAssetVaultConfig)
        );
        address clone_ = Clones.clone(implementation);
        OffchainAssetVault(clone_).initialize(config_);
        return clone_;
    }

    /// Typed wrapper for `createChild` with Source.
    /// Use original `Factory` `createChild` function signature if function
    /// parameters are already encoded.
    ///
    /// @param config_ Config for the vault.
    /// @return New `OffchainAssetVault` child contract address.
    function createChildTyped(
        OffchainAssetVaultConfig memory config_
    ) external returns (OffchainAssetVault) {
        return OffchainAssetVault(createChild(abi.encode(config_)));
    }
}
