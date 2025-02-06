// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest, Vm} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {VaultConfig, MinShareRatio} from "src/abstract/ReceiptVault.sol";
import {
    OffchainAssetReceiptVault,
    OffchainAssetVaultConfigV2,
    OffchainAssetReceiptVaultConfigV2,
    DEPOSITOR_ADMIN,
    WITHDRAWER_ADMIN,
    HANDLER_ADMIN,
    ERC20TIERER_ADMIN,
    ERC1155TIERER_ADMIN,
    CONFISCATOR_ADMIN,
    ERC20TIERER,
    ERC1155TIERER,
    CERTIFIER,
    CONFISCATOR
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {StringsUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/StringsUpgradeable.sol";
import {TestErc20} from "../../../concrete/TestErc20.sol";
import {ReadWriteTier} from "../../../concrete/ReadWriteTier.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {
    OffchainAssetReceiptVaultAuthorizorV1,
    CERTIFIER_ADMIN
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizorV1.sol";

contract RolesTest is OffchainAssetReceiptVaultTest {
    /// Test to checks Admin roles granted
    function testGrantAdminRoles(uint256 fuzzedKeyAlice, string memory assetName, string memory assetSymbol) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        assertTrue(vault.hasRole(DEPOSITOR_ADMIN, alice));
        assertTrue(vault.hasRole(WITHDRAWER_ADMIN, alice));
        assertTrue(OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).hasRole(CERTIFIER_ADMIN, alice));
        assertTrue(vault.hasRole(HANDLER_ADMIN, alice));
        assertTrue(vault.hasRole(ERC20TIERER_ADMIN, alice));
        assertTrue(vault.hasRole(ERC1155TIERER_ADMIN, alice));
        assertTrue(vault.hasRole(CONFISCATOR_ADMIN, alice));
    }

    /// Test to checks deposit without depositor role
    function testDepositWithoutDepositorRole(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        uint256 aliceAssets,
        bytes memory receiptInformation
    ) external {
        // ShareRatio 1
        uint256 shareRatio = 1e18;
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        fuzzedKeyBob = bound(fuzzedKeyBob, 1, SECP256K1_ORDER - 1);
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(MinShareRatio.selector, shareRatio, 0));
        vault.deposit(aliceAssets, bob, shareRatio, receiptInformation);
        vm.stopPrank();
    }

    /// Test to checks SetERC20Tier without role
    function testSetERC20TierWithoutRole(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint8 minTier,
        uint256[] memory context
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // New testErc20 contract
        ReadWriteTier TierV2TestContract = new ReadWriteTier();

        string memory errorMessage = string(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(alice),
                " is missing role ",
                vm.toString(ERC20TIERER)
            )
        );

        vm.expectRevert(bytes(errorMessage));

        // Set Tier
        vault.setERC20Tier(address(TierV2TestContract), minTier, context, data);
    }

    /// Test to checks setERC1155Tier without role
    function testSetERC1155TierWithoutRole(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint8 minTier,
        uint256[] memory context
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // New testErc20 contract
        ReadWriteTier TierV2TestContract = new ReadWriteTier();

        string memory errorMessage = string(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(alice),
                " is missing role ",
                vm.toString(ERC1155TIERER)
            )
        );
        vm.expectRevert(bytes(errorMessage));

        // Set Tier
        vault.setERC1155Tier(address(TierV2TestContract), minTier, context, data);
    }

    /// Test to checks Certify without role
    function testCertifyWithoutRole(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 certifyUntil,
        bytes memory data
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);
        // Prank as Alice for the transaction
        vm.startPrank(alice);
        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        bool forceUntil = false;

        string memory errorMessage = string(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(alice),
                " is missing role ",
                vm.toString(CERTIFIER)
            )
        );
        vm.expectRevert(bytes(errorMessage));

        // Call the certify function
        vault.certify(certifyUntil, forceUntil, data);

        vm.stopPrank();
    }

    /// Test to checks Confiscate without role
    function testConfiscateWithoutRole(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);
        // Prank as Alice for the transaction
        vm.startPrank(alice);
        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        string memory errorMessage = string(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(alice),
                " is missing role ",
                vm.toString(CONFISCATOR)
            )
        );
        vm.expectRevert(bytes(errorMessage));

        // Call the confiscateShares function
        vault.confiscateShares(alice, data);

        vm.stopPrank();
    }
}
