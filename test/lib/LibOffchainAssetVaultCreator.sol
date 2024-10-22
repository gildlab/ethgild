// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {OffchainAssetReceiptVault, OffchainAssetVaultConfig} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {VaultConfig} from "src/abstract/ReceiptVault.sol";

library LibOffchainAssetVaultCreator {
    /// Helper to create child offchainAssetReceiptVault.
    function createVault(
        ICloneableFactoryV2 factory,
        OffchainAssetReceiptVault implementation,
        address admin,
        string memory name,
        string memory symbol
    ) internal returns (OffchainAssetReceiptVault) {
        OffchainAssetVaultConfig memory offchainAssetVaultConfig = OffchainAssetVaultConfig({
            admin: admin,
            vaultConfig: VaultConfig({asset: address(0), name: name, symbol: symbol})
        });

        // Use the factory to create the child contract
        return OffchainAssetReceiptVault(
            payable(factory.clone(address(implementation), abi.encode(offchainAssetVaultConfig)))
        );
    }
}
