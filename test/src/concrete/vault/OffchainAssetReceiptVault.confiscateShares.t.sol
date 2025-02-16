// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfigV2,
    CONFISCATE_SHARES,
    DEPOSIT,
    CERTIFY
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {OffchainAssetReceiptVaultAuthorizorV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizorV1.sol";
import {MathUpgradeable as Math} from "openzeppelin-contracts-upgradeable/contracts/utils/math/MathUpgradeable.sol";

contract ConfiscateSharesTest is OffchainAssetReceiptVaultTest {
    using Math for uint256;

    /// Checks that confiscateShares balances don't change or do change as expected
    function checkConfiscateShares(
        OffchainAssetReceiptVault vault,
        address alice,
        address bob,
        uint256 targetAmount,
        bytes memory data
    ) internal {
        uint256 initialBalanceAlice = vault.balanceOf(alice);
        uint256 initialBalanceBob = vault.balanceOf(bob);
        bool expectNoChange = initialBalanceAlice == 0;

        uint256 expectedChange = initialBalanceAlice.min(targetAmount);
        if (!expectNoChange) {
            vm.expectEmit(false, false, false, true);
            emit OffchainAssetReceiptVault.ConfiscateShares(bob, alice, targetAmount, expectedChange, data);
        }

        vault.confiscateShares(alice, targetAmount, data);

        uint256 balanceAfterAlice = vault.balanceOf(alice);
        uint256 balanceAfterBob = vault.balanceOf(bob);

        bool balancesChanged = initialBalanceAlice == balanceAfterAlice && initialBalanceBob == balanceAfterBob;
        if (!expectNoChange) {
            balancesChanged = balanceAfterAlice == initialBalanceAlice - expectedChange
                && balanceAfterBob == initialBalanceBob + expectedChange;
        }

        assertTrue(balancesChanged, expectNoChange ? "Balances should not change" : "Balances should change");
    }

    /// Test to checks ConfiscateShares does not change balances on zero balance
    function testConfiscateSharesOnZeroBalance(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        bytes memory data,
        uint256 balance,
        uint256 targetAmount,
        uint256 minShareRatio
    ) external {
        vm.assume(targetAmount > 0);

        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);

        // Bound balance from 1 so depositing does not revert with ZeroAssetsAmount
        balance = bound(balance, 1, type(uint256).max);

        vm.assume(alice != bob);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(CONFISCATE_SHARES, bob);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, bob);

        // Prank as Bob for tranactions
        vm.startPrank(bob);

        // Deposit to increase bob's balance
        vault.deposit(balance, bob, minShareRatio, data);

        checkConfiscateShares(vault, alice, bob, targetAmount, data);

        vm.stopPrank();
    }

    /// Test to check ConfiscateShares
    function testConfiscateSharesBasic(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 minShareRatio,
        uint256 assets,
        string memory shareName,
        string memory shareSymbol,
        bytes memory data,
        uint256 certifyUntil,
        uint256 blockNumber,
        bool forceUntil,
        uint256 targetAmount
    ) external {
        vm.assume(targetAmount > 0);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        vm.assume(alice != bob);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        // Prank as Alice to set roles
        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(CONFISCATE_SHARES, bob);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, bob);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(CERTIFY, bob);

        // Prank as Bob for transactions
        vm.startPrank(bob);

        // Call the certify function
        vault.certify(certifyUntil, forceUntil, data);

        // Assume that assets is less than uint256 max
        assets = bound(assets, 1, type(uint256).max);

        vault.deposit(assets, alice, minShareRatio, data);

        checkConfiscateShares(vault, alice, bob, targetAmount, data);
        vm.stopPrank();
    }
}
