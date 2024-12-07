// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfig
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract ConfiscateSharesTest is OffchainAssetReceiptVaultTest {
    event ConfiscateShares(address sender, address confiscatee, uint256 confiscated, bytes justification);

    /// Checks that confiscateShares balances don't change or do change as expected
    function checkConfiscateShares(OffchainAssetReceiptVault vault, address alice, address bob, bytes memory data)
        internal
    {
        uint256 initialBalanceAlice = vault.balanceOf(alice);
        uint256 initialBalanceBob = vault.balanceOf(bob);
        bool expectNoChange = initialBalanceAlice == 0;

        if (!expectNoChange) {
            vm.expectEmit(false, false, false, true);
            emit ConfiscateShares(bob, alice, initialBalanceAlice, data);
        }

        vault.confiscateShares(alice, data);

        uint256 balanceAfterAlice = vault.balanceOf(alice);
        uint256 balanceAfterBob = vault.balanceOf(bob);

        bool balancesChanged = initialBalanceAlice == balanceAfterAlice && initialBalanceBob == balanceAfterBob;
        if (!expectNoChange) {
            balancesChanged = balanceAfterAlice == 0 && balanceAfterBob == initialBalanceBob + initialBalanceAlice;
        }

        assertTrue(balancesChanged, expectNoChange ? "Balances should not change" : "Balances should change");
    }

    /// Test to checks ConfiscateShares does not change balances on zero balance
    function testConfiscateSharesOnZeroBalance(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint256 balance,
        uint256 minShareRatio
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        minShareRatio = bound(minShareRatio, 0, 1e18);

        // Bound balance from 1 so depositing does not revert with ZeroAssetsAmount
        balance = bound(balance, 1, type(uint256).max);

        vm.assume(alice != bob);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        vault.grantRole(vault.CONFISCATOR(), bob);
        vault.grantRole(vault.DEPOSITOR(), bob);

        // Prank as Bob for tranactions
        vm.startPrank(bob);

        // Deposit to increase bob's balance
        vault.deposit(balance, bob, minShareRatio, data);

        checkConfiscateShares(vault, alice, bob, data);

        vm.stopPrank();
    }

    /// Test to check ConfiscateShares
    function testConfiscateShares(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 minShareRatio,
        uint256 assets,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint256 certifyUntil,
        uint256 referenceBlockNumber,
        uint256 blockNumber,
        bool forceUntil
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        referenceBlockNumber = bound(referenceBlockNumber, 0, blockNumber);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        vm.assume(alice != bob);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set roles
        vm.startPrank(alice);
        vault.grantRole(vault.CONFISCATOR(), bob);
        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.CERTIFIER(), bob);

        // Prank as Bob for transactions
        vm.startPrank(bob);

        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, forceUntil, data);

        // Assume that assets is less than uint256 max
        assets = bound(assets, 1, type(uint256).max);

        vault.deposit(assets, alice, minShareRatio, data);

        checkConfiscateShares(vault, alice, bob, data);
        vm.stopPrank();
    }
}
