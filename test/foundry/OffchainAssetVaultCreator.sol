// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import {
    OffchainAssetReceiptVault,
    OffchainAssetVaultConfig
} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";
import {VaultConfig} from "../../contracts/vault/receipt/ReceiptVault.sol";
import {CreateOffchainAssetReceiptVaultFactory} from "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";

contract OffchainAssetVaultCreator is CreateOffchainAssetReceiptVaultFactory {
    /// Helper to create child offchainAssetReceiptVault.
    function createVault(address alice, string memory name, string memory symbol)
        public
        returns (OffchainAssetReceiptVault)
    {
        // VaultConfig to create child contract
        VaultConfig memory vaultConfig = VaultConfig({asset: address(0), name: name, symbol: symbol});
        OffchainAssetVaultConfig memory offchainAssetVaultConfig =
            OffchainAssetVaultConfig({admin: alice, vaultConfig: vaultConfig});

        // Use the factory to create the child contract
        return factory.createChildTyped(offchainAssetVaultConfig);
    }
}
