// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {Receipt, RECEIPT_METADATA_DATA_URI, DATA_URI_BASE64_PREFIX} from "src/concrete/receipt/Receipt.sol";
import {IReceiptOwnerV1} from "src/interface/IReceiptOwnerV1.sol";
import {TestReceipt} from "test/concrete/TestReceipt.sol";
import {TestReceiptOwner} from "test/concrete/TestReceiptOwner.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {ReceiptFactoryTest, Vm} from "test/abstract/ReceiptFactoryTest.sol";
import {Base64} from "solady/utils/Base64.sol";
import {console2} from "forge-std/Test.sol";

contract ReceiptTest is ReceiptFactoryTest {
    event ReceiptInformation(address sender, uint256 id, bytes information);

    struct Metadata {
        uint256 decimals;
        string description;
        string name;
    }

    function testInitialize() public {
        TestReceiptOwner mockOwner = new TestReceiptOwner();
        TestReceipt receipt = createReceipt(address(mockOwner));
        assertEq(receipt.owner(), address(mockOwner));
    }

    function testReceiptURI(uint256 id) external {
        // Deploy the Receipt contract
        TestReceiptOwner mockOwner = new TestReceiptOwner();
        TestReceipt receipt = createReceipt(address(mockOwner));

        string memory uri = receipt.uri(id);

        uint256 uriLength = bytes(uri).length;
        assembly ("memory-safe") {
            mstore(uri, 29)
        }
        assertEq(uri, DATA_URI_BASE64_PREFIX);
        assembly ("memory-safe") {
            uri := add(uri, 29)
            mstore(uri, sub(uriLength, 29))
        }
        assertEq(uri, RECEIPT_METADATA_DATA_URI);

        string memory uriDecoded = string(Base64.decode(uri));
        bytes memory uriJsonData = vm.parseJson(uriDecoded);

        Metadata memory metadataJson = abi.decode(uriJsonData, (Metadata));
        assertEq(metadataJson.description, "A receipt for a ReceiptVault.");
        assertEq(metadataJson.decimals, 18);
        assertEq(metadataJson.name, "Receipt");
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
    function testOwnerBurnNotEnoughBalance(
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

        TestReceipt receipt = createReceipt(alice);
        TestReceiptOwner receiptOwner = new TestReceiptOwner();

        vm.startPrank(alice);

        // Set the receipt owner
        receipt.transferOwnership(address(receiptOwner));

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
