// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVault, DEPOSIT, CERTIFY} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {LibOffchainAssetVaultCreator} from "test/lib/LibOffchainAssetVaultCreator.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {
    OffchainAssetReceiptVaultAuthorizerV1,
    FREEZE_HANDLER
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract OffchainAssetReceiptVaultHandlerTest is OffchainAssetReceiptVaultTest {
    function setUpAddressesAndBounds(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 carolKey,
        uint256 balance,
        uint256 certifyUntil
    ) internal returns (address, address, address, uint256, uint256) {
        (address alice, address bob, address carol) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed, carolKey);

        balance = bound(balance, 1, type(uint256).max); // Bound from one to avoid ZeroAssets
        certifyUntil = bound(certifyUntil, 1, type(uint32).max - 1); // substruct 1 for next bound

        return (alice, bob, carol, balance, certifyUntil);
    }

    function setUpVault(address alice, string memory shareName, string memory shareSymbol)
        internal
        returns (OffchainAssetReceiptVault vault, ReceiptContract receipt)
    {
        vm.recordLogs();
        vault = createVault(alice, shareName, shareSymbol);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        receipt = getReceipt(logs);
        return (vault, receipt);
    }

    /// Test testReceiptTransfer to self with handler role
    function testReceiptTransferHandler(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 certifyUntil,
        uint256 futureTimeStamp,
        bool forceUntil,
        uint256 balance,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        address alice;
        address bob;
        (alice, bob,, balance, certifyUntil) = setUpAddressesAndBounds(aliceSeed, bobSeed, 0, balance, certifyUntil);

        // Need setting future timestamp so system gets unsertified but transfer is possible
        // due to a handler role
        futureTimeStamp = bound(futureTimeStamp, certifyUntil + 1, type(uint32).max);

        OffchainAssetReceiptVault vault;
        ReceiptContract receipt;
        (vault, receipt) = setUpVault(alice, shareName, shareSymbol);

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(FREEZE_HANDLER, bob);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, alice);

        // Call the certify function
        vault.certify(certifyUntil, forceUntil, bytes(""));

        vault.deposit(balance, bob, 1, bytes(""));

        vm.stopPrank();
        vm.warp(futureTimeStamp);

        // Show the transfer is authorized.
        vm.startPrank(address(receipt));
        vault.authorizeReceiptTransfer3(bob, bob, ids, amounts);

        // Prank as Bob
        vm.startPrank(bob);
        receipt.safeTransferFrom(bob, bob, 1, balance, bytes(""));
        assertEq(receipt.balanceOf(bob, 1), balance);

        vm.stopPrank();
    }

    /// Test testReceiptTransfer with Owner being a handler
    function testReceiptTransferHandlerOwner(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 carolKey,
        string memory shareName,
        string memory shareSymbol,
        uint256 certifyUntil,
        uint256 futureTimeStamp,
        bool forceUntil,
        uint256 balance,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        address alice;
        address bob;
        address john;
        (alice, bob, john, balance, certifyUntil) =
            setUpAddressesAndBounds(aliceSeed, bobSeed, carolKey, balance, certifyUntil);

        // Need setting future timestamp so system gets uncertified but transfer is possible
        // due to a handler role
        futureTimeStamp = bound(futureTimeStamp, certifyUntil + 1, type(uint32).max);

        OffchainAssetReceiptVault vault;
        ReceiptContract receipt;
        (vault, receipt) = setUpVault(alice, shareName, shareSymbol);

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(FREEZE_HANDLER, bob);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, alice);

        // Call the certify function
        vault.certify(certifyUntil, forceUntil, bytes(""));

        // Cannot fuzz assets value due to variable limits
        vault.deposit(balance, bob, 1, bytes(""));

        vm.stopPrank();
        vm.warp(futureTimeStamp);

        // Prank as the receipt
        vm.startPrank(address(receipt));
        vault.authorizeReceiptTransfer3(bob, john, ids, amounts);
        vm.stopPrank();

        vm.startPrank(bob);
        receipt.safeTransferFrom(bob, john, 1, balance, bytes(""));
        assertEq(receipt.balanceOf(john, 1), balance);

        vm.stopPrank();
    }

    /// Test testReceiptTransfer with Receiver being a handler
    function testReceiptTransferHandlerReceiver(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 carolKey,
        string memory shareName,
        string memory shareSymbol,
        uint256 certifyUntil,
        uint256 futureTimeStamp,
        bool forceUntil,
        uint256 balance,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        address alice;
        address bob;
        address john;
        (alice, bob, john, balance, certifyUntil) =
            setUpAddressesAndBounds(aliceSeed, bobSeed, carolKey, balance, certifyUntil);

        // Need setting future timestamp so system gets uncertified but transfer is possible
        // due to a handler role
        futureTimeStamp = bound(futureTimeStamp, certifyUntil + 1, type(uint32).max);

        OffchainAssetReceiptVault vault;
        ReceiptContract receipt;
        (vault, receipt) = setUpVault(alice, shareName, shareSymbol);

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(FREEZE_HANDLER, john);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, alice);

        // Call the certify function
        vault.certify(certifyUntil, forceUntil, bytes(""));

        // Cannot fuzz assets value due to variable limits
        vault.deposit(balance, bob, 1, bytes(""));

        vm.stopPrank();
        vm.warp(futureTimeStamp);

        // Show the transfer is authorized.
        vm.prank(address(receipt));
        vault.authorizeReceiptTransfer3(bob, john, ids, amounts);

        // Prank as Bob
        vm.startPrank(bob);
        receipt.safeTransferFrom(bob, john, 1, balance, bytes(""));
        assertEq(receipt.balanceOf(john, 1), balance);

        vm.stopPrank();
    }
}
