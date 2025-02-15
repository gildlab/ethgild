// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {OffchainAssetReceiptVault} from "src/concrete/vault/OffchainAssetReceiptVault.sol";

contract OffchainAssetReceiptVaultAssetTest is OffchainAssetReceiptVaultTest {
    /// Test vault asset
    function testVaultAsset(uint256 aliceKey, string memory assetName) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((aliceKey % (SECP256K1_ORDER - 1)) + 1);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetName);

        assertEq(vault.asset(), address(0));
    }
}
