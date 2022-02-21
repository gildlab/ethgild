// SPDX-License-Identifier: CAL
pragma solidity ^0.8.12;

import {Factory} from "@beehiveinnovation/rain-protocol/contracts/factory/Factory.sol";
import {NativeGild} from "./NativeGild.sol";
import {GildConfig} from "./Gildable.sol";

/// @title NativeGildFactory
/// @notice Factory for creating and deploying `NativeGild`.
contract NativeGildFactory is Factory {
    /// @inheritdoc Factory
    function _createChild(bytes calldata data_)
        internal
        virtual
        override
        returns (address)
    {
        // This is built directly with `new` instead of cloning as we're
        // optimizing for use of cheap immutables at runtime rather than cheap
        // deployments.
        return address(new NativeGild(abi.decode(data_, (GildConfig))));
    }

    /// Typed wrapper for `createChild` with Source.
    /// Use original `Factory` `createChild` function signature if function
    /// parameters are already encoded.
    ///
    /// @param config_ `GildConfig` of the `Gildable` logic.
    /// @return New `NativeGild` child contract address.
    function createChildTyped(GildConfig calldata config_)
        external
        returns (NativeGild)
    {
        return NativeGild(this.createChild(abi.encode(config_)));
    }
}
