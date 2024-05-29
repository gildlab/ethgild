// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import {OffchainAssetReceiptVault} from "../vault/offchainAsset/OffchainAssetReceiptVault.sol";
import {ReceiptFactory} from "../vault/receipt/ReceiptFactory.sol";
import {ReceiptVaultFactoryConfig} from "../vault/receipt/ReceiptVaultFactory.sol";
import {OffchainAssetReceiptVaultFactory} from "../vault/offchainAsset/OffchainAssetReceiptVaultFactory.sol";

abstract contract CreateOffchainAssetReceiptVaultFactory {
    OffchainAssetReceiptVault internal immutable implementation;
    ReceiptFactory internal immutable receiptFactory;
    OffchainAssetReceiptVaultFactory public immutable factory;

    constructor() {
        implementation = new OffchainAssetReceiptVault();
        receiptFactory = new ReceiptFactory();

        // Create OffchainAssetReceiptVaultFactory contract
        factory = new OffchainAssetReceiptVaultFactory(
            ReceiptVaultFactoryConfig({implementation: address(implementation), receiptFactory: address(receiptFactory)})
        );
    }
}