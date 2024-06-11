// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ReceiptVaultFactory, ReceiptVaultFactoryConfig, Factory} from "../receipt/ReceiptVaultFactory.sol";
import {
    ERC20PriceOracleReceiptVault,
    ERC20PriceOracleReceiptVaultConfig,
    ERC20PriceOracleVaultConfig,
    ReceiptVaultConfig
} from "./ERC20PriceOracleReceiptVault.sol";
import {Receipt, ReceiptFactory} from "../receipt/ReceiptFactory.sol";
import {ClonesUpgradeable as Clones} from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

/// @title ERC20PriceOracleReceiptVaultFactory
/// @notice Factory for creating and deploying `ERC20PriceOracleReceiptVault`.
contract ERC20PriceOracleReceiptVaultFactory is ReceiptVaultFactory {
    constructor(ReceiptVaultFactoryConfig memory config)
        ReceiptVaultFactory(config) //solhint-disable-next-line no-empty-blocks
    {}

    /// @inheritdoc Factory
    function _createChild(bytes memory data) internal virtual override returns (address) {
        ERC20PriceOracleVaultConfig memory erc20PriceOracleVaultConfig = abi.decode(data, (ERC20PriceOracleVaultConfig));

        address clone = Clones.clone(implementation);
        ERC20PriceOracleReceiptVault(clone).initialize(
            ERC20PriceOracleReceiptVaultConfig(
                erc20PriceOracleVaultConfig.priceOracle, _createReceipt(clone, erc20PriceOracleVaultConfig.vaultConfig)
            )
        );
        return clone;
    }

    /// Typed wrapper for `createChild`.
    /// Use original `Factory` `createChild` function signature if function
    /// parameters are already encoded.
    ///
    /// @param erc20PriceOracleVaultConfig Config for the
    /// `ERC20PriceOracleReceiptVault`.
    /// @return New `ERC20PriceOracleReceiptVault` child contract address.
    function createChildTyped(ERC20PriceOracleVaultConfig memory erc20PriceOracleVaultConfig)
        external
        returns (ERC20PriceOracleReceiptVault)
    {
        return ERC20PriceOracleReceiptVault(createChild(abi.encode(erc20PriceOracleVaultConfig)));
    }
}
