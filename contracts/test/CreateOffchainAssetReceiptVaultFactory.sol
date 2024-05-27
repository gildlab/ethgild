// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import "../vault/offchainAsset/OffchainAssetReceiptVault.sol";
import "../vault/receipt/ReceiptFactory.sol";
import "../vault/offchainAsset/OffchainAssetReceiptVaultFactory.sol";

abstract contract CreateOffchainAssetReceiptVaultFactory {
    OffchainAssetReceiptVault public implementation;
    ReceiptFactory public receiptFactory;
    OffchainAssetReceiptVaultFactory public factory;
    ReceiptVaultFactoryConfig public factoryConfig;

    function createOffchainAssetReceiptVaultFactory() internal {
        implementation = new OffchainAssetReceiptVault();
        receiptFactory = new ReceiptFactory();

        // Set up factory config
        factoryConfig = ReceiptVaultFactoryConfig({
            implementation: address(implementation),
            receiptFactory: address(receiptFactory)
        });

        // Create OffchainAssetReceiptVaultFactory contract
        factory = new OffchainAssetReceiptVaultFactory(factoryConfig);
    }
}
