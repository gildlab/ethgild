// SPDX-License-Identifier: MIT
pragma solidity =0.8.10;

import {Factory} from "@beehiveinnovation/rain-protocol/contracts/factory/Factory.sol";
import {CertifiedAssetConnect, CertifiedAssetConnectConfig} from "./CertifiedAssetConnect.sol";

/// @title CertifiedAssetConnectFactory
/// @notice Factory for creating and deploying `CertifiedAssetConnect`.
contract CertifiedAssetConnectFactory is Factory {
    /// @inheritdoc Factory
    function _createChild(bytes calldata data_)
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
                new CertifiedAssetConnect(
                    abi.decode(data_, (CertifiedAssetConnectConfig))
                )
            );
    }

    /// Typed wrapper for `createChild` with Source.
    /// Use original `Factory` `createChild` function signature if function
    /// parameters are already encoded.
    ///
    /// @param config_ `CertifiedAssetConnectConfig` of the `CertifiedAssetConnect` logic.
    /// @return New `CertifiedAssetConnect` child contract address.
    function createChildTyped(CertifiedAssetConnectConfig calldata config_)
        external
        returns (CertifiedAssetConnect)
    {
        return CertifiedAssetConnect(this.createChild(abi.encode(config_)));
    }
}
