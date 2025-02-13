// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {OffchainAssetReceiptVault} from "src/concrete/vault/OffchainAssetReceiptVault.sol";

contract OffchainAssetReceiptVaultMaxDepositTest is OffchainAssetReceiptVaultTest {
    /// Test vault sets correct max deposit
    function testMaxDeposit(uint256 fuzzedKeyAlice, string memory assetName) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetName);

        vm.startPrank(alice);
        uint256 maxDeposit = vault.maxDeposit(alice);

        assertEqUint(maxDeposit, type(uint256).max);
    }
}
