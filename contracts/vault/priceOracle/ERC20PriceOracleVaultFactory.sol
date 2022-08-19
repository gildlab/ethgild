// SPDX-License-Identifier: MIT
pragma solidity =0.8.10;

import {Factory} from "@beehiveinnovation/rain-protocol/contracts/factory/Factory.sol";
import {ERC20PriceOracleVault, ConstructionConfig} from "./ERC20PriceOracleVault.sol";

/// @title ERC20PriceOracleVaultFactory
/// @notice Factory for creating and deploying `ERC20PriceOracleVault`.
contract ERC20PriceOracleVaultFactory is Factory {
    /// @inheritdoc Factory
    function _createChild(bytes memory data_)
        internal
        virtual
        override
        returns (address)
    {
        // This is built directly with `new` instead of cloning as we're
        // optimizing for use of cheap immutables at runtime rather than cheap
        // deployments.
        return
            address(
                new ERC20PriceOracleVault(
                    abi.decode(data_, (ConstructionConfig))
                )
            );
    }

    /// Typed wrapper for `createChild` with Source.
    /// Use original `Factory` `createChild` function signature if function
    /// parameters are already encoded.
    ///
    /// @param config_ construction config for the `ERC20PriceOracleVault`.
    /// @return New `ERC20PriceOracleVault` child contract address.
    function createChildTyped(ConstructionConfig memory config_)
        external
        returns (ERC20PriceOracleVault)
    {
        return ERC20PriceOracleVault(createChild(abi.encode(config_)));
    }
}
