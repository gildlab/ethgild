// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import {OffchainAssetReceiptVault} from "../vault/offchainAsset/OffchainAssetReceiptVault.sol";
import {ReceiptFactory} from "../vault/receipt/ReceiptFactory.sol";
import {ReceiptVaultFactoryConfig} from "../vault/receipt/ReceiptVaultFactory.sol";
import {OffchainAssetReceiptVaultFactory} from "../vault/offchainAsset/OffchainAssetReceiptVaultFactory.sol";

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
