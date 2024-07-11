// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, Vm} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {Receipt} from "../../../../../contracts/concrete/receipt/Receipt.sol";
import {IReceiptOwnerV1} from "../../../../../contracts/interface/IReceiptOwnerV1.sol";
import {TestReceipt} from "../../../../../contracts/test/TestReceipt.sol";
import {TestReceiptOwner} from "../../../../../contracts/test/TestReceiptOwner.sol";

contract ReceiptTest is Test {
    event ReceiptInformation(address sender, uint256 id, bytes information);

    function generateNonEmptyBytes(uint256 maxLength, uint256 seed) internal pure returns (bytes memory) {
        uint256 length = (seed % (maxLength - 1)) + 1; // Ensure length is at least 1
        bytes memory data = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            data[i] = bytes1(uint8(seed % 256)); // Random data
        }
        return data;
    }

    function testInitialize() public {
        TestReceipt receipt = new TestReceipt();
        TestReceiptOwner mockOwner = new TestReceiptOwner();

        receipt.setOwner(address(mockOwner));
        assertEq(receipt.owner(), address(mockOwner));
    }

    // Test receipt sets owner
    function testReceiptOwnerIsSet(uint256 fuzzedKeyAlice) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        vm.startPrank(alice);
        TestReceipt receipt = new TestReceipt();

        receipt.setOwner(alice);

        address owner = receipt.owner();
        assertEq(owner, alice);
    }

    /// Test receipt OwnerMint function
    function testOwnerMint(uint256 fuzzedKeyAlice, uint256 id, uint256 amount, bytes memory data) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        amount = bound(amount, 1, type(uint256).max);

        TestReceipt receipt = new TestReceipt();
        TestReceiptOwner receiptOwner = new TestReceiptOwner();

        // Set the receipt owner
        receipt.setOwner(address(receiptOwner));

        // Set the authorized 'from' and 'to' addresses in receiptOwner
        receiptOwner.setFrom(address(0));
        receiptOwner.setTo(alice);

        vm.startPrank(alice);
        receiptOwner.ownerMint(receipt, alice, id, amount, data);

        // Check the balance of the minted tokens
        assertEq(receipt.balanceOf(alice, id), amount);
    }

    /// Test receipt OwnerBurn function
    function testOwnerBurn(uint256 fuzzedKeyAlice, uint256 id, uint256 amount, uint256 fuzzedReceiptSeed) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        amount = bound(amount, 1, type(uint256).max);
        id = bound(id, 0, type(uint256).max);

        bytes memory fuzzedReceiptInformation = generateNonEmptyBytes(100, fuzzedReceiptSeed); // Generate non-empty bytes

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

        // Set up the event expectation for ReceiptInformation
        vm.expectEmit(false, false, false, true);
        emit ReceiptInformation(alice, id, fuzzedReceiptInformation);

        receiptOwner.ownerBurn(receipt, alice, id, receiptBalance, fuzzedReceiptInformation);

        // Check the balance of the minted tokens
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
        burnAmount = bound(burnAmount, receiptBalance + 1, type(uint256).max);

        receiptOwner.setFrom(alice);
        receiptOwner.setTo(address(0));

        vm.expectRevert();
        receiptOwner.ownerBurn(receipt, alice, id, burnAmount, fuzzedReceiptInformation);
    }
}
