// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std/Test.sol";
import {TestReceipt as ReceiptContract} from "contracts/test/TestReceipt.sol";
import "forge-std/console.sol";

contract ReceiptTest is Test {
    // Initialize receipt
    function testReceiptConstruction() external {
        ReceiptContract receipt = new ReceiptContract();
        assertTrue(address(receipt) != address(0));
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
}
