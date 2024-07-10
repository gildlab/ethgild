// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, Vm} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {Receipt} from "../../../../../contracts/concrete/receipt/Receipt.sol";
import {IReceiptOwnerV1} from "../../../../../contracts/interface/IReceiptOwnerV1.sol";
import {TestReceipt} from "../../../../../contracts/test/TestReceipt.sol";
import {TestReceiptOwner} from "../../../../../contracts/test/TestReceiptOwner.sol";

contract ReceiptTest is Test {
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
        ReceiptContract receipt = new ReceiptContract();

        receipt.setOwner(alice);

        address owner = receipt.owner();
        assertEq(owner, alice);
    }

    /// test receipt OwnerMint function
    function testOwnerMint(uint256 fuzzedKeyAlice, uint256 id, uint256 amount, bytes memory data) public {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        amount = bound(amount, 1, type(uint256).max);

        TestReceipt receipt = new TestReceipt();
        TestReceiptOwner receiptOwner = new TestReceiptOwner();
        console.log(address(receiptOwner));
        console.log(address(receipt));
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
}
