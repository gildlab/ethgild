// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest, Vm} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {VaultConfig, MinShareRatio} from "src/abstract/ReceiptVault.sol";
import {
    OffchainAssetReceiptVault,
    OffchainAssetVaultConfigV2,
    OffchainAssetReceiptVaultConfigV2,
    CONFISCATE_RECEIPT,
    CONFISCATE_SHARES,
    CERTIFY,
    CertifyStateChange,
    DepositStateChange,
    ConfiscateSharesStateChange,
    ConfiscateReceiptStateChange
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {StringsUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/StringsUpgradeable.sol";
import {TestErc20} from "../../../concrete/TestErc20.sol";
import {ReadWriteTier} from "../../../concrete/ReadWriteTier.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {
    OffchainAssetReceiptVaultAuthorizorV1,
    Unauthorized,
    CERTIFY_ADMIN,
    CONFISCATE_RECEIPT_ADMIN,
    CONFISCATE_SHARES_ADMIN,
    FREEZE_HANDLER_ADMIN,
    DEPOSIT_ADMIN,
    WITHDRAW_ADMIN,
    DEPOSIT,
    WITHDRAW,
    CERTIFY,
    FREEZE_HANDLER,
    CONFISCATE_RECEIPT,
    CONFISCATE_SHARES
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizorV1.sol";

contract RolesTest is OffchainAssetReceiptVaultTest {
    /// Test to checks Admin roles granted
    function testGrantAdminRoles(uint256 aliceKey, string memory assetName, string memory assetSymbol) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        aliceKey = bound(aliceKey, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(aliceKey);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        assertTrue(OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).hasRole(DEPOSIT_ADMIN, alice));
        assertTrue(OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).hasRole(WITHDRAW_ADMIN, alice));
        assertTrue(OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).hasRole(CERTIFY_ADMIN, alice));
        assertTrue(
            OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).hasRole(FREEZE_HANDLER_ADMIN, alice)
        );
        assertTrue(
            OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).hasRole(CONFISCATE_RECEIPT_ADMIN, alice)
        );
        assertTrue(
            OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).hasRole(CONFISCATE_SHARES_ADMIN, alice)
        );

        assertTrue(!OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).hasRole(DEPOSIT, alice));
        assertTrue(!OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).hasRole(WITHDRAW, alice));
        assertTrue(!OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).hasRole(CERTIFY, alice));
        assertTrue(!OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).hasRole(FREEZE_HANDLER, alice));
        assertTrue(
            !OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).hasRole(CONFISCATE_RECEIPT, alice)
        );
        assertTrue(
            !OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).hasRole(CONFISCATE_SHARES, alice)
        );
    }

    /// Test to checks deposit without depositor role
    function testDepositWithoutDepositorRole(
        uint256 aliceKey,
        uint256 bobKey,
        string memory assetName,
        string memory assetSymbol,
        uint256 aliceAssets,
        bytes memory receiptInformation
    ) external {
        vm.assume(aliceAssets > 0);

        // ShareRatio 1
        uint256 shareRatio = 1e18;
        // Ensure the fuzzed key is within the valid range for secp256k1
        aliceKey = bound(aliceKey, 1, SECP256K1_ORDER - 1);
        bobKey = bound(bobKey, 1, SECP256K1_ORDER - 1);
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, aliceKey, bobKey);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        vm.expectRevert(
            abi.encodeWithSelector(
                Unauthorized.selector,
                alice,
                DEPOSIT,
                abi.encode(
                    DepositStateChange({
                        owner: alice,
                        receiver: bob,
                        id: 1,
                        assetsDeposited: aliceAssets,
                        sharesMinted: aliceAssets,
                        data: receiptInformation
                    })
                )
            )
        );
        vault.deposit(aliceAssets, bob, shareRatio, receiptInformation);
        vm.stopPrank();
    }

    /// Test to checks Certify without role
    function testCertifyWithoutRole(
        uint256 aliceKey,
        string memory assetName,
        string memory assetSymbol,
        uint256 certifyUntil,
        bytes memory data
    ) external {
        vm.assume(certifyUntil > 0);
        // Ensure the fuzzed key is within the valid range for secp256k1
        aliceKey = bound(aliceKey, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(aliceKey);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        bool forceUntil = false;

        vm.expectRevert(
            abi.encodeWithSelector(
                Unauthorized.selector,
                alice,
                CERTIFY,
                abi.encode(
                    CertifyStateChange({
                        oldCertifiedUntil: 0,
                        newCertifiedUntil: certifyUntil,
                        userCertifyUntil: certifyUntil,
                        forceUntil: forceUntil,
                        data: data
                    })
                )
            )
        );

        // Call the certify function
        vault.certify(certifyUntil, forceUntil, data);

        vm.stopPrank();
    }

    /// Test to checks confiscate receipt without role
    function testConfiscateReceiptWithoutRole(
        uint256 aliceKey,
        string memory assetName,
        string memory assetSymbol,
        uint256 id,
        uint256 targetAmount,
        bytes memory data
    ) external {
        vm.assume(targetAmount > 0);

        // Ensure the fuzzed key is within the valid range for secp256k1
        aliceKey = bound(aliceKey, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(aliceKey);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        vm.expectRevert(
            abi.encodeWithSelector(
                Unauthorized.selector,
                alice,
                CONFISCATE_RECEIPT,
                abi.encode(
                    ConfiscateReceiptStateChange({
                        confiscatee: alice,
                        id: id,
                        targetAmount: targetAmount,
                        actualAmount: 0,
                        data: data
                    })
                )
            )
        );

        // Call the confiscateReceipt function
        vault.confiscateReceipt(alice, id, targetAmount, data);

        vm.stopPrank();
    }

    /// Test to checks confiscate shares without role
    function testConfiscateSharesWithoutRole(
        uint256 aliceKey,
        string memory assetName,
        string memory assetSymbol,
        uint256 targetAmount,
        bytes memory data
    ) external {
        vm.assume(targetAmount > 0);

        // Ensure the fuzzed key is within the valid range for secp256k1
        aliceKey = bound(aliceKey, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(aliceKey);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        vm.expectRevert(
            abi.encodeWithSelector(
                Unauthorized.selector,
                alice,
                CONFISCATE_SHARES,
                abi.encode(
                    ConfiscateSharesStateChange({
                        confiscatee: alice,
                        targetAmount: targetAmount,
                        actualAmount: 0,
                        data: data
                    })
                )
            )
        );

        // Call the confiscateShares function
        vault.confiscateShares(alice, targetAmount, data);

        vm.stopPrank();
    }
}
