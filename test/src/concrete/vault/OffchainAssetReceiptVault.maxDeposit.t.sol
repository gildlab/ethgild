// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {OffchainAssetReceiptVault} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract OffchainAssetReceiptVaultMaxDepositTest is OffchainAssetReceiptVaultTest {
    /// Test vault sets correct max deposit
    function testMaxDeposit(uint256 aliceSeed, string memory shareName, string memory shareSymbol) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        vm.startPrank(alice);
        uint256 maxDeposit = vault.maxDeposit(alice);

        assertEqUint(maxDeposit, type(uint256).max);
    }
}
