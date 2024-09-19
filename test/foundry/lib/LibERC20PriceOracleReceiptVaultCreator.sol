// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {
    ERC20PriceOracleReceiptVault,
    ERC20PriceOracleVaultConfig
} from "contracts/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {VaultConfig} from "contracts/abstract/ReceiptVault.sol";

library LibERC20PriceOracleReceiptVaultCreator {
    /// Helper to create child erc20PriceOracleVault.
    function createVault(
        ICloneableFactoryV2 factory,
        ERC20PriceOracleReceiptVault implementation,
        address priceOracle,
        address asset,
        string memory name,
        string memory symbol
    ) internal returns (ERC20PriceOracleReceiptVault) {
        ERC20PriceOracleVaultConfig memory erc20PriceOracleVault = ERC20PriceOracleVaultConfig({
            priceOracle: priceOracle,
            vaultConfig: VaultConfig({asset: asset, name: name, symbol: symbol})
        });

        // Use the factory to create the child contract
        return ERC20PriceOracleReceiptVault(factory.clone(address(implementation), abi.encode(erc20PriceOracleVault)));
    }
}
