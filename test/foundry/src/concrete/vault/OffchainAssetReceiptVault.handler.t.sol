// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfig
} from "../../../../../contracts/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/foundry/abstract/OffchainAssetReceiptVaultTest.sol";
import {LibOffchainAssetVaultCreator} from "test/foundry/lib/LibOffchainAssetVaultCreator.sol";
import {Receipt as ReceiptContract} from "../../../../../contracts/concrete/receipt/Receipt.sol";

contract OffchainAssetReceiptVaultHandlerTest is OffchainAssetReceiptVaultTest {
    event SetERC20Tier(address sender, address tier, uint256 minimumTier, uint256[] context, bytes data);
    event SetERC1155Tier(address sender, address tier, uint256 minimumTier, uint256[] context, bytes data);
    event OffchainAssetReceiptVaultInitialized(address sender, OffchainAssetReceiptVaultConfig config);
    event DepositWithReceipt(
        address sender, address owner, uint256 assets, uint256 shares, uint256 id, bytes receiptInformation
    );

    /// Get Receipt from event
    function getReceipt() internal returns (ReceiptContract) {
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find the OffchainAssetReceiptVaultInitialized event log
        address receiptAddress = address(0);
        bool eventFound = false; // Flag to indicate whether the event log was found
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == OffchainAssetReceiptVaultInitialized.selector) {
                // Decode the event data
                (, OffchainAssetReceiptVaultConfig memory config) =
                    abi.decode(logs[i].data, (address, OffchainAssetReceiptVaultConfig));
                receiptAddress = config.receiptVaultConfig.receipt;
                eventFound = true; // Set the flag to true since event log was found
                break;
            }
        }

        // Assert that the event log was found
        assertTrue(eventFound, "OffchainAssetReceiptVaultInitialized event log not found");
        // Return an receipt contract
        return ReceiptContract(receiptAddress);
    }

    /// Test testReceiptTransfer to self with handler role
    function testReceiptTransferHandler(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        uint256 referenceBlockNumber,
        uint256 certifyUntil,
        uint256 futureTimeStamp,
        bool forceUntil,
        uint256 balance
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        balance = bound(balance, 1, type(uint256).max); // Bound from one to avoid ZeroAssets
        referenceBlockNumber = bound(referenceBlockNumber, 1, block.number);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max - 1); // substruct 1 for next bound

        // Need setting future timestamp so system gets unsertified but transfer is possible
        // due to a handler role
        futureTimeStamp = bound(futureTimeStamp, certifyUntil + 1, type(uint32).max);

        vm.assume(alice != bob);

        // Start recording logs
        vm.recordLogs();
        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetName);
        ReceiptContract receipt = getReceipt();

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        vault.grantRole(vault.CERTIFIER(), alice);
        vault.grantRole(vault.HANDLER(), bob);
        vault.grantRole(vault.DEPOSITOR(), alice);

        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, forceUntil, bytes(""));

        // Cannot fuzz assets value due to variable limits
        vault.deposit(balance, bob, 1, bytes(""));

        vm.stopPrank();
        vm.warp(futureTimeStamp);

        // Prank as Bob
        vm.startPrank(bob);
        vault.authorizeReceiptTransfer(bob, bob);
        receipt.safeTransferFrom(bob, bob, 1, balance, bytes(""));
        assertEq(receipt.balanceOf(bob, 1), balance);

        vm.stopPrank();
    }

    /// Test testReceiptTransfer with Owner being a handler
    function testReceiptTransferHandlerOwner(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 fuzzedKeyJohn,
        string memory assetName,
        uint256 referenceBlockNumber,
        uint256 certifyUntil,
        uint256 futureTimeStamp,
        bool forceUntil,
        uint256 balance
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        address john = vm.addr((fuzzedKeyJohn % (SECP256K1_ORDER - 1)) + 1);

        balance = bound(balance, 1, type(uint256).max); // Bound from one to avoid ZeroAssets
        referenceBlockNumber = bound(referenceBlockNumber, 1, block.number);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max - 1); // substruct 1 for next bound

        // Need setting future timestamp so system gets unsertified but transfer is possible
        // due to a handler role
        futureTimeStamp = bound(futureTimeStamp, certifyUntil + 1, type(uint32).max);

        vm.assume(alice != bob);
        vm.assume(alice != john);
        vm.assume(bob != john);

        // Start recording logs
        vm.recordLogs();
        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetName);
        ReceiptContract receipt = getReceipt();

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        vault.grantRole(vault.CERTIFIER(), alice);
        vault.grantRole(vault.HANDLER(), bob);
        vault.grantRole(vault.DEPOSITOR(), alice);

        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, forceUntil, bytes(""));

        // Cannot fuzz assets value due to variable limits
        vault.deposit(balance, bob, 1, bytes(""));

        vm.stopPrank();
        vm.warp(futureTimeStamp);

        // Prank as Bob
        vm.startPrank(bob);
        vault.authorizeReceiptTransfer(bob, john);
        receipt.safeTransferFrom(bob, john, 1, balance, bytes(""));
        assertEq(receipt.balanceOf(john, 1), balance);

        vm.stopPrank();
    }

    /// Test testReceiptTransfer with Receiver being a handler
    function testReceiptTransferHandlerReceiver(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 fuzzedKeyJohn,
        string memory assetName,
        uint256 referenceBlockNumber,
        uint256 certifyUntil,
        uint256 futureTimeStamp,
        bool forceUntil,
        uint256 balance
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        address john = vm.addr((fuzzedKeyJohn % (SECP256K1_ORDER - 1)) + 1);

        balance = bound(balance, 1, type(uint256).max); // Bound from one to avoid ZeroAssets
        referenceBlockNumber = bound(referenceBlockNumber, 1, block.number);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max - 1); // substruct 1 for next bound

        // Need setting future timestamp so system gets unsertified but transfer is possible
        // due to a handler role
        futureTimeStamp = bound(futureTimeStamp, certifyUntil + 1, type(uint32).max);

        vm.assume(alice != bob);
        vm.assume(alice != john);
        vm.assume(bob != john);

        // Start recording logs
        vm.recordLogs();
        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetName);
        ReceiptContract receipt = getReceipt();

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        vault.grantRole(vault.CERTIFIER(), alice);
        vault.grantRole(vault.HANDLER(), john);
        vault.grantRole(vault.DEPOSITOR(), alice);

        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, forceUntil, bytes(""));

        // Cannot fuzz assets value due to variable limits
        vault.deposit(balance, bob, 1, bytes(""));

        vm.stopPrank();
        vm.warp(futureTimeStamp);

        // Prank as Bob
        vm.startPrank(bob);
        vault.authorizeReceiptTransfer(bob, john);
        receipt.safeTransferFrom(bob, john, 1, balance, bytes(""));
        assertEq(receipt.balanceOf(john, 1), balance);

        vm.stopPrank();
    }
}
