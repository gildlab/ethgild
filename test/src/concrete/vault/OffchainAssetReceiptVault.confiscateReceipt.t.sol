// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfigV2,
    CONFISCATOR,
    DEPOSITOR
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {
    OffchainAssetReceiptVaultAuthorizorV1,
    CERTIFIER
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizorV1.sol";

contract ConfiscateReceiptTest is OffchainAssetReceiptVaultTest {
    event ConfiscateReceipt(address sender, address confiscatee, uint256 id, uint256 confiscated, bytes justification);

    /// Checks that confiscateReceipt balances don't change or do change as expected
    function checkConfiscateReceipt(
        OffchainAssetReceiptVault vault,
        ReceiptContract receipt,
        address alice,
        address bob,
        uint256 id,
        bytes memory data
    ) internal {
        uint256 initialBalanceAlice = receipt.balanceOf(alice, id);
        uint256 initialBalanceBob = receipt.balanceOf(bob, id);
        bool expectNoChange = initialBalanceAlice == 0;

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        if (!expectNoChange) {
            vm.expectEmit(false, false, false, true);
            emit ConfiscateReceipt(bob, alice, id, initialBalanceAlice, data);
        }

        vault.confiscateReceipt(alice, id, data);

        uint256 balanceAfterAlice = receipt.balanceOf(alice, id);
        uint256 balanceAfterBob = receipt.balanceOf(bob, id);

        bool balancesChanged = initialBalanceAlice == balanceAfterAlice && initialBalanceBob == balanceAfterBob;
        if (!expectNoChange) {
            balancesChanged = balanceAfterAlice == 0 && balanceAfterBob == initialBalanceBob + initialBalanceAlice;
        }

        assertTrue(balancesChanged, expectNoChange ? "Balances should not change" : "Balances should change");

        vm.stopPrank();
    }

    /// Test to checks ConfiscateReceipt does not change balances on zero balance
    function testConfiscateReceiptOnZeroBalance(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint256 id
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        id = bound(id, 0, type(uint256).max);

        // Start recording logs
        vm.recordLogs();
        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        ReceiptContract receipt = getReceipt(logs);

        // Prank as Alice to grant role
        vm.startPrank(alice);

        vault.grantRole(CONFISCATOR, bob);

        checkConfiscateReceipt(vault, receipt, alice, bob, id, data);
    }

    /// Test to checks ConfiscateReceipt
    function testConfiscateReceipt(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 minShareRatio,
        uint256 assets,
        string memory assetName,
        bytes memory data,
        uint256 certifyUntil,
        uint256 blockNumber,
        bool forceUntil
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        // Assume that assets is less than uint256 max
        assets = bound(assets, 1, type(uint256).max);

        // Start recording logs
        vm.recordLogs();
        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetName);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Prank as Alice to set roles
        vm.startPrank(alice);
        vault.grantRole(CONFISCATOR, bob);
        vault.grantRole(DEPOSITOR, bob);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(CERTIFIER, bob);

        // Prank as Bob for transactions
        vm.startPrank(bob);

        // Call the certify function
        vault.certify(certifyUntil, forceUntil, data);

        vault.deposit(assets, alice, minShareRatio, data);

        checkConfiscateReceipt(vault, getReceipt(logs), alice, bob, 1, data);
        vm.stopPrank();
    }
}
