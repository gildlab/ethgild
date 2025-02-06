// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {OffchainAssetReceiptVault, OffchainAssetVaultConfigV2} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {VaultConfig} from "src/abstract/ReceiptVault.sol";
import {OffchainAssetReceiptVaultAuthorizorV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizorV1.sol";

library LibOffchainAssetVaultCreator {
    /// Helper to create child offchainAssetReceiptVault.
    function createVault(
        ICloneableFactoryV2 factory,
        OffchainAssetReceiptVault implementation,
        OffchainAssetReceiptVaultAuthorizorV1 authorizor,
        address initialAdmin,
        string memory name,
        string memory symbol
    ) internal returns (OffchainAssetReceiptVault) {
        OffchainAssetVaultConfigV2 memory offchainAssetVaultConfig = OffchainAssetVaultConfigV2({
            initialAdmin: initialAdmin,
            authorizor: authorizor,
            vaultConfig: VaultConfig({asset: address(0), name: name, symbol: symbol})
        });

        // Use the factory to create the child contract
        return OffchainAssetReceiptVault(
            payable(factory.clone(address(implementation), abi.encode(offchainAssetVaultConfig)))
        );
    }
}
