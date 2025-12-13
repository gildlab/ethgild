// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std/Test.sol";
import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {OffchainAssetReceiptVault, OffchainAssetReceiptVaultConfigV2} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {ReceiptVaultConfigV2} from "src/abstract/ReceiptVault.sol";
import {
    OffchainAssetReceiptVaultAuthorizerV1,
    OffchainAssetReceiptVaultAuthorizerV1Config
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";

library LibOffchainAssetVaultCreator {
    /// Helper to create child offchainAssetReceiptVault.
    function createVault(
        Vm vm,
        ICloneableFactoryV2 factory,
        OffchainAssetReceiptVault implementation,
        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation,
        address initialAdmin,
        string memory name,
        string memory symbol
    ) internal returns (OffchainAssetReceiptVault) {
        OffchainAssetReceiptVaultConfigV2 memory offchainAssetVaultConfig = OffchainAssetReceiptVaultConfigV2({
            initialAdmin: initialAdmin,
            receiptVaultConfig: ReceiptVaultConfigV2({asset: address(0), name: name, symbol: symbol})
        });

        // Use the factory to create the child contract
        OffchainAssetReceiptVault vault = OffchainAssetReceiptVault(
            payable(factory.clone(address(implementation), abi.encode(offchainAssetVaultConfig)))
        );

        OffchainAssetReceiptVaultAuthorizerV1 authorizer = OffchainAssetReceiptVaultAuthorizerV1(
            factory.clone(
                address(authorizerImplementation),
                abi.encode(OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin}))
            )
        );

        vm.prank(initialAdmin);
        vault.setAuthorizer(authorizer);

        return vault;
    }
}
