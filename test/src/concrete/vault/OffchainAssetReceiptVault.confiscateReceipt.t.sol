// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfigV2,
    CONFISCATE_RECEIPT,
    DEPOSIT,
    CERTIFY
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {OffchainAssetReceiptVaultAuthorizorV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizorV1.sol";
import {MathUpgradeable as Math} from "openzeppelin-contracts-upgradeable/contracts/utils/math/MathUpgradeable.sol";

contract ConfiscateReceiptTest is OffchainAssetReceiptVaultTest {
    using Math for uint256;

    /// Checks that confiscateReceipt balances don't change or do change as expected
    function checkConfiscateReceipt(
        OffchainAssetReceiptVault vault,
        ReceiptContract receipt,
        address alice,
        address bob,
        uint256 id,
        uint256 targetAmount,
        bytes memory data
    ) internal {
        uint256 initialBalanceAlice = receipt.balanceOf(alice, id);
        uint256 initialBalanceBob = receipt.balanceOf(bob, id);
        bool expectNoChange = initialBalanceAlice == 0;
        uint256 expectedChange = targetAmount.min(initialBalanceAlice);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        if (!expectNoChange) {
            vm.expectEmit(false, false, false, true);
            emit OffchainAssetReceiptVault.ConfiscateReceipt(bob, alice, id, targetAmount, expectedChange, data);
        }

        vault.confiscateReceipt(alice, id, targetAmount, data);

        uint256 balanceAfterAlice = receipt.balanceOf(alice, id);
        uint256 balanceAfterBob = receipt.balanceOf(bob, id);

        bool balancesChanged = initialBalanceAlice == balanceAfterAlice && initialBalanceBob == balanceAfterBob;
        if (!expectNoChange) {
            balancesChanged = balanceAfterAlice == initialBalanceAlice - expectedChange
                && balanceAfterBob == initialBalanceBob + expectedChange;
        }

        assertTrue(balancesChanged, expectNoChange ? "Balances should not change" : "Balances should change");

        vm.stopPrank();
    }

    /// Test to checks ConfiscateReceipt does not change balances on zero balance
    function testConfiscateReceiptOnZeroBalance(
        uint256 aliceKey,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint256 id,
        uint256 targetAmount
    ) external {
        vm.assume(targetAmount > 0);

        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, aliceKey, fuzzedKeyBob);

        id = bound(id, 0, type(uint256).max);

        // Start recording logs
        vm.recordLogs();
        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        ReceiptContract receipt = getReceipt(logs);

        // Prank as Alice to grant role
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(CONFISCATE_RECEIPT, bob);

        checkConfiscateReceipt(vault, receipt, alice, bob, id, targetAmount, data);
    }

    /// Test to checks ConfiscateReceipt
    function testConfiscateReceiptBasic(
        uint256 aliceKey,
        uint256 fuzzedKeyBob,
        uint256 minShareRatio,
        uint256 assets,
        string memory assetName,
        bytes memory data,
        uint256 certifyUntil,
        uint256 blockNumber,
        bool forceUntil,
        uint256 targetAmount
    ) external {
        vm.assume(targetAmount > 0);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, aliceKey, fuzzedKeyBob);

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
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(CONFISCATE_RECEIPT, bob);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, bob);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(CERTIFY, bob);

        // Prank as Bob for transactions
        vm.startPrank(bob);

        // Call the certify function
        vault.certify(certifyUntil, forceUntil, data);

        vault.deposit(assets, alice, minShareRatio, data);

        checkConfiscateReceipt(vault, getReceipt(logs), alice, bob, 1, targetAmount, data);
        vm.stopPrank();
    }
}
