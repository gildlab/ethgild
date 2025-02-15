// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVault, DEPOSIT, CERTIFY} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {LibOffchainAssetVaultCreator} from "test/lib/LibOffchainAssetVaultCreator.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {
    OffchainAssetReceiptVaultAuthorizorV1,
    FREEZE_HANDLER
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizorV1.sol";

contract OffchainAssetReceiptVaultHandlerTest is OffchainAssetReceiptVaultTest {
    function setUpAddressesAndBounds(
        uint256 aliceKey,
        uint256 bobKey,
        uint256 carolKey,
        uint256 balance,
        uint256 certifyUntil
    ) internal pure returns (address alice, address bob, address john, uint256, uint256) {
        // Ensure the fuzzed key is within the valid range for secp256k
        alice = vm.addr((aliceKey % (SECP256K1_ORDER - 1)) + 1);
        bob = vm.addr((bobKey % (SECP256K1_ORDER - 1)) + 1);
        john = vm.addr((carolKey % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob && alice != john);
        vm.assume(bob != john);

        balance = bound(balance, 1, type(uint256).max); // Bound from one to avoid ZeroAssets
        certifyUntil = bound(certifyUntil, 1, type(uint32).max - 1); // substruct 1 for next bound

        return (alice, bob, john, balance, certifyUntil);
    }

    function setUpVault(address alice, string memory assetName, string memory assetSymbol)
        internal
        returns (OffchainAssetReceiptVault vault, ReceiptContract receipt)
    {
        vm.recordLogs();
        vault = createVault(alice, assetName, assetSymbol);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        receipt = getReceipt(logs);
        return (vault, receipt);
    }

    /// Test testReceiptTransfer to self with handler role
    function testReceiptTransferHandler(
        uint256 aliceKey,
        uint256 bobKey,
        string memory assetName,
        uint256 certifyUntil,
        uint256 futureTimeStamp,
        bool forceUntil,
        uint256 balance,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        address alice;
        address bob;
        (alice, bob,, balance, certifyUntil) =
            setUpAddressesAndBounds(aliceKey, bobKey, 0, balance, certifyUntil);

        // Need setting future timestamp so system gets unsertified but transfer is possible
        // due to a handler role
        futureTimeStamp = bound(futureTimeStamp, certifyUntil + 1, type(uint32).max);

        OffchainAssetReceiptVault vault;
        ReceiptContract receipt;
        (vault, receipt) = setUpVault(alice, assetName, assetName);

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(CERTIFY, alice);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(FREEZE_HANDLER, bob);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, alice);

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
        uint256 aliceKey,
        uint256 bobKey,
        uint256 carolKey,
        string memory assetName,
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
            setUpAddressesAndBounds(aliceKey, bobKey, carolKey, balance, certifyUntil);

        // Need setting future timestamp so system gets uncertified but transfer is possible
        // due to a handler role
        futureTimeStamp = bound(futureTimeStamp, certifyUntil + 1, type(uint32).max);

        OffchainAssetReceiptVault vault;
        ReceiptContract receipt;
        (vault, receipt) = setUpVault(alice, assetName, assetName);

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(CERTIFY, alice);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(FREEZE_HANDLER, bob);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, alice);

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
        uint256 aliceKey,
        uint256 bobKey,
        uint256 carolKey,
        string memory assetName,
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
            setUpAddressesAndBounds(aliceKey, bobKey, carolKey, balance, certifyUntil);

        // Need setting future timestamp so system gets uncertified but transfer is possible
        // due to a handler role
        futureTimeStamp = bound(futureTimeStamp, certifyUntil + 1, type(uint32).max);

        OffchainAssetReceiptVault vault;
        ReceiptContract receipt;
        (vault, receipt) = setUpVault(alice, assetName, assetName);

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(CERTIFY, alice);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(FREEZE_HANDLER, john);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, alice);

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
