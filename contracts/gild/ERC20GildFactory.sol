// SPDX-License-Identifier: CAL
pragma solidity =0.8.10;

import {Factory} from "@beehiveinnovation/rain-protocol/contracts/factory/Factory.sol";
import {ERC20Gild, ERC20GildConfig} from "./ERC20Gild.sol";
import {GildConfig} from "./Gildable.sol";

/// @title ERC20GildFactory
/// @notice Factory for creating and deploying `ERC20Gild`.
contract ERC20GildFactory is Factory {
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
        return address(new ERC20Gild(abi.decode(data_, (ERC20GildConfig))));
    }

    /// Typed wrapper for `createChild` with Source.
    /// Use original `Factory` `createChild` function signature if function
    /// parameters are already encoded.
    ///
    /// @param config_ `GildConfig` of the `Gildable` logic.
    /// @return New `GildConfig` child contract address.
    function createChildTyped(GildConfig calldata config_)
        external
        returns (ERC20Gild)
    {
        return ERC20Gild(this.createChild(abi.encode(config_)));
    }
}
