// SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

import {Factory} from "@beehiveinnovation/rain-protocol/contracts/factory/Factory.sol";
import {ERC20PriceOracleVault, ERC20PriceOracleVaultConstructionConfig} from "./ERC20PriceOracleVault.sol";
import {ClonesUpgradeable as Clones} from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

/// @title ERC20PriceOracleVaultFactory
/// @notice Factory for creating and deploying `ERC20PriceOracleVault`.
contract ERC20PriceOracleVaultFactory is Factory {
    /// Template contract to clone.
    /// Deployed by the constructor.
    address public immutable implementation;

    /// Build the reference implementation to clone for each child.
    constructor() {
        address implementation_ = address(new ERC20PriceOracleVault());
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
        ERC20PriceOracleVaultConstructionConfig memory config_ = abi.decode(data_, (ERC20PriceOracleVaultConstructionConfig));
        address clone_ = Clones.clone(implementation);
        ERC20PriceOracleVault(payable(clone_)).initialize(config_);
        return clone_;
    }

    /// Typed wrapper for `createChild` with Source.
    /// Use original `Factory` `createChild` function signature if function
    /// parameters are already encoded.
    ///
    /// @param config_ construction config for the `ERC20PriceOracleVault`.
    /// @return New `ERC20PriceOracleVault` child contract address.
    function createChildTyped(
        ERC20PriceOracleVaultConstructionConfig memory config_
    ) external returns (ERC20PriceOracleVault) {
        return ERC20PriceOracleVault(createChild(abi.encode(config_)));
    }
}
