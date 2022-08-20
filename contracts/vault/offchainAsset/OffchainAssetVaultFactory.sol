// SPDX-License-Identifier: MIT
pragma solidity =0.8.10;

import {Factory} from "@beehiveinnovation/rain-protocol/contracts/factory/Factory.sol";
import {OffchainAssetVault, OffchainAssetVaultConstructionConfig} from "./OffchainAssetVault.sol";

/// @title OffchainAssetVaultFactory
/// @notice Factory for creating and deploying `OffchainAssetVault`.
contract OffchainAssetVaultFactory is Factory {
    /// @inheritdoc Factory
    function _createChild(bytes memory data_)
        internal
        virtual
        override
        returns (address)
    {
        // Deploying each contract directly rather than cloning it as there
        // doesn't seem to be a way to cleanly inherit both ERC20Upgradeable
        // and ERC1155Upgradeable at the same time.
        return
            address(
                new OffchainAssetVault(
                    abi.decode(data_, (OffchainAssetVaultConstructionConfig))
                )
            );
    }

    /// Typed wrapper for `createChild` with Source.
    /// Use original `Factory` `createChild` function signature if function
    /// parameters are already encoded.
    ///
    /// @param config_ Construction config for the vault.
    /// @return New `OffchainAssetVault` child contract address.
    function createChildTyped(
        OffchainAssetVaultConstructionConfig memory config_
    ) external returns (OffchainAssetVault) {
        return OffchainAssetVault(createChild(abi.encode(config_)));
    }
}
