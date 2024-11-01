// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity ^0.8.25;

import {Receipt} from "src/concrete/receipt/Receipt.sol";
import {IReceiptOwnerV1} from "src/interface/IReceiptOwnerV1.sol";
import {TestReceipt} from "test/concrete/TestReceipt.sol";
import {TestReceiptOwner} from "test/concrete/TestReceiptOwner.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {ReceiptFactoryTest, Vm} from "test/abstract/ReceiptFactoryTest.sol";
import {console} from "forge-std/console.sol";

contract ReceiptTest is ReceiptFactoryTest {
    event ReceiptInformation(address sender, uint256 id, bytes information);

    function testInitialize() public {
        TestReceiptOwner mockOwner = new TestReceiptOwner();
        TestReceipt receipt = createReceipt(address(mockOwner));
        assertEq(receipt.owner(), address(mockOwner));
    }

    // Test receipt sets owner
    function testReceiptOwnerIsSet(uint256 fuzzedKeyAlice) external {
        TestReceiptOwner mockOwner = new TestReceiptOwner();
        TestReceipt receipt = createReceipt(address(mockOwner));

        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        // Make mockOwner call setOwner to change to alice
        vm.startPrank(address(mockOwner));
        receipt.transferOwnership(alice);

        address owner = receipt.owner();
        assertEq(owner, alice);
        vm.stopPrank();
    }

    /// Test receipt OwnerMint function
    function testOwnerMint(uint256 fuzzedKeyAlice, uint256 id, uint256 amount, bytes memory data) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        amount = bound(amount, 1, type(uint256).max);

        TestReceipt receipt = createReceipt(alice);
        TestReceiptOwner receiptOwner = new TestReceiptOwner();

        vm.startPrank(alice);

        // Set the receipt owner
        receipt.transferOwnership(address(receiptOwner));

        // Set the authorized 'from' and 'to' addresses in receiptOwner
        receiptOwner.setFrom(address(0));
        receiptOwner.setTo(alice);

        receiptOwner.ownerMint(receipt, alice, id, amount, data);

        // Check the receipt balance of alice
        assertEq(receipt.balanceOf(alice, id), amount);
    }

    /// Test receipt OwnerBurn function
    function testOwnerBurn(uint256 fuzzedKeyAlice, uint256 id, uint256 amount, bytes memory fuzzedReceiptInformation)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        amount = bound(amount, 1, type(uint256).max);
        id = bound(id, 0, type(uint256).max);

        vm.assume(fuzzedReceiptInformation.length > 0);

        TestReceipt receipt = createReceipt(alice);

        TestReceiptOwner receiptOwner = new TestReceiptOwner();

        vm.startPrank(alice);
        // Set the receipt owner
        receipt.transferOwnership(address(receiptOwner));

        // Set the authorized 'from' and 'to' addresses in receiptOwner
        receiptOwner.setFrom(address(0));
        receiptOwner.setTo(alice);

        receiptOwner.ownerMint(receipt, alice, id, amount, fuzzedReceiptInformation);
        uint256 receiptBalance = receipt.balanceOf(alice, id);

        receiptOwner.setFrom(alice);
        receiptOwner.setTo(address(0));

        // Set up the event expectation for ReceiptInformation
        vm.expectEmit(false, false, false, true);
        emit ReceiptInformation(alice, id, fuzzedReceiptInformation);

        receiptOwner.ownerBurn(receipt, alice, id, receiptBalance, fuzzedReceiptInformation);

        // Check the balance of alice
        assertEq(receipt.balanceOf(alice, id), 0);
    }

    /// Test OwnerBurn fails while not enough balance to burn
    function testOwnerBurnNoTEnoughBalance(
        uint256 fuzzedKeyAlice,
        uint256 id,
        uint256 amount,
        bytes memory fuzzedReceiptInformation,
        uint256 burnAmount
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        // Bound with uint256 max - 1 so dowsnot get overflow while bounding burnAmount
        amount = bound(amount, 1, type(uint256).max - 1);
        id = bound(id, 0, type(uint256).max);

        TestReceipt receipt = createReceipt(alice);
        TestReceiptOwner receiptOwner = new TestReceiptOwner();
        vm.startPrank(alice);

        // Set the receipt owner
        receipt.transferOwnership(address(receiptOwner));

        // Set the authorized 'from' and 'to' addresses in receiptOwner
        receiptOwner.setFrom(address(0));
        receiptOwner.setTo(alice);

        receiptOwner.ownerMint(receipt, alice, id, amount, fuzzedReceiptInformation);
        uint256 receiptBalance = receipt.balanceOf(alice, id);
        burnAmount = bound(burnAmount, receiptBalance + 1, type(uint256).max);

        receiptOwner.setFrom(alice);
        receiptOwner.setTo(address(0));

        vm.expectRevert();
        receiptOwner.ownerBurn(receipt, alice, id, burnAmount, fuzzedReceiptInformation);
    }

    /// Test OwnerTransferFrom more than balance
    function testOwnerTransferFromMoreThanBalance(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 id,
        uint256 amount,
        bytes memory fuzzedReceiptInformation,
        uint256 transferAmount
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        // Bound with uint256 max - 1 so dowsnot get overflow while bounding transferAmount
        amount = bound(amount, 1, type(uint256).max - 1);
        id = bound(id, 0, type(uint256).max);

        TestReceipt receipt = new TestReceipt();
        TestReceiptOwner receiptOwner = new TestReceiptOwner();

        // Set the receipt owner
        receipt.setOwner(address(receiptOwner));

        // Set the authorized 'from' and 'to' addresses in receiptOwner
        receiptOwner.setFrom(address(0));
        receiptOwner.setTo(alice);

        vm.startPrank(alice);
        receiptOwner.ownerMint(receipt, alice, id, amount, fuzzedReceiptInformation);
        uint256 receiptBalance = receipt.balanceOf(alice, id);
        transferAmount = bound(transferAmount, receiptBalance + 1, type(uint256).max);

        receiptOwner.setFrom(alice);
        receiptOwner.setTo(bob);

        vm.expectRevert();
        receiptOwner.ownerTransferFrom(receipt, alice, bob, id, transferAmount, fuzzedReceiptInformation);
    }

    /// Test receipt OwnerTransferFrom function reverts while UnauthorizedTransfer
    function testUnauthorizedTransferOwnerTransferFrom(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 id,
        uint256 amount,
        bytes memory fuzzedReceiptInformation
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        amount = bound(amount, 1, type(uint256).max);
        id = bound(id, 0, type(uint256).max);

        TestReceipt receipt = new TestReceipt();
        TestReceiptOwner receiptOwner = new TestReceiptOwner();

        // Set the receipt owner
        receipt.setOwner(address(receiptOwner));

        // Set the authorized 'from' and 'to' addresses in receiptOwner
        receiptOwner.setFrom(address(0));
        receiptOwner.setTo(alice);

        vm.startPrank(alice);
        receiptOwner.ownerMint(receipt, alice, id, amount, fuzzedReceiptInformation);
        uint256 receiptBalance = receipt.balanceOf(alice, id);

        receiptOwner.setFrom(alice);
        receiptOwner.setTo(address(0));

        vm.expectRevert();
        receiptOwner.ownerTransferFrom(receipt, alice, bob, id, receiptBalance, fuzzedReceiptInformation);
    }

    /// Test receipt OwnerTransferFrom function
    function testTransferOwnerTransferFrom(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 id,
        uint256 amount,
        bytes memory fuzzedReceiptInformation
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        amount = bound(amount, 1, type(uint256).max);
        id = bound(id, 0, type(uint256).max);

        TestReceipt receipt = new TestReceipt();
        TestReceiptOwner receiptOwner = new TestReceiptOwner();

        // Set the receipt owner
        receipt.setOwner(address(receiptOwner));

        // Set the authorized 'from' and 'to' addresses in receiptOwner
        receiptOwner.setFrom(address(0));
        receiptOwner.setTo(alice);

        vm.startPrank(alice);
        receiptOwner.ownerMint(receipt, alice, id, amount, fuzzedReceiptInformation);
        uint256 receiptBalance = receipt.balanceOf(alice, id);

        receiptOwner.setFrom(alice);
        receiptOwner.setTo(bob);

        receiptOwner.ownerTransferFrom(receipt, alice, bob, id, receiptBalance, fuzzedReceiptInformation);

        assertEq(receipt.balanceOf(bob, id), receiptBalance);
        assertEq(receipt.balanceOf(alice, id), 0);
    }
}
