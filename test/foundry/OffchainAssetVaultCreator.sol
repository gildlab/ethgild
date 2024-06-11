// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {
    OffchainAssetReceiptVault,
    OffchainAssetVaultConfig
} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";
import {VaultConfig} from "../../contracts/vault/receipt/ReceiptVault.sol";
import {OffchainAssetReceiptVaultFactory} from
    "../../contracts/vault/offchainAsset/OffchainAssetReceiptVaultFactory.sol";
import {CreateOffchainAssetReceiptVaultFactory} from "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";

library OffchainAssetVaultCreator {
    /// Helper to create child offchainAssetReceiptVault.
    function createVault(
        OffchainAssetReceiptVaultFactory factory,
        address alice,
        string memory name,
        string memory symbol
    ) external returns (OffchainAssetReceiptVault) {
        // VaultConfig to create child contract
        VaultConfig memory vaultConfig = VaultConfig({asset: address(0), name: name, symbol: symbol});
        OffchainAssetVaultConfig memory offchainAssetVaultConfig =
            OffchainAssetVaultConfig({admin: alice, vaultConfig: vaultConfig});

        // Use the factory to create the child contract
        return factory.createChildTyped(offchainAssetVaultConfig);
    }
}
