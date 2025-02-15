// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVault} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {IReceiptVaultV2, IReceiptVaultV1} from "src/interface/IReceiptVaultV2.sol";

contract OffchainAssetReceiptVaultReceiptVaultInformationTest is OffchainAssetReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Test vault receiptVaultInformation
    function testReceiptVaultInformation(uint256 aliceKey, string memory assetName, bytes memory information)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((aliceKey % (SECP256K1_ORDER - 1)) + 1);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetName);

        vm.startPrank(alice);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.ReceiptVaultInformation(alice, information);

        vault.receiptVaultInformation(information);
    }
}
