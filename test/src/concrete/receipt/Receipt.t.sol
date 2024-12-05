// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {IReceiptOwnerV1} from "src/interface/IReceiptOwnerV1.sol";
import {TestReceipt} from "test/concrete/TestReceipt.sol";
import {TestReceiptOwner, UnauthorizedTransfer} from "test/concrete/TestReceiptOwner.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {ReceiptFactoryTest, Vm} from "test/abstract/ReceiptFactoryTest.sol";

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

        vm.expectRevert(abi.encodeWithSelector(UnauthorizedTransfer.selector, alice, bob));
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

    /// Test ERC1155 balanceOf function
    function testBalanceOf(uint256 fuzzedKeyAlice, uint256 id, uint256 amount, bytes memory data) external {
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

        uint256 balance = receipt.balanceOf(alice, id);

        // Check the receipt balance of alice
        assertEq(balance, amount);
    }

    /// Test ERC1155 balanceOfBatch function
    function testBalanceOfBatch(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 idOne,
        uint256 idTwo,
        uint256 amountOne,
        uint256 amountTwo,
        bytes memory data
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        amountOne = bound(amountOne, 1, type(uint256).max);
        amountTwo = bound(amountTwo, 1, type(uint256).max);
        vm.assume(amountOne != amountTwo);

        TestReceipt receipt = createReceipt(alice);
        TestReceiptOwner receiptOwner = new TestReceiptOwner();

        vm.startPrank(alice);

        // Set the receipt owner
        receipt.transferOwnership(address(receiptOwner));

        // Set the authorized 'from' and 'to' addresses in receiptOwner
        receiptOwner.setFrom(address(0));
        receiptOwner.setTo(alice);

        receiptOwner.ownerMint(receipt, alice, idOne, amountOne, data);

        receiptOwner.setTo(bob);
        receiptOwner.ownerMint(receipt, bob, idTwo, amountTwo, data);

        address[] memory addresses = new address[](2);
        addresses[0] = alice;
        addresses[1] = bob;

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = idOne;
        tokenIds[1] = idTwo;

        uint256[] memory balances = receipt.balanceOfBatch(addresses, tokenIds);

        // Check the receipt balance of alice
        assertEq(balances[0], amountOne);
        assertEq(balances[1], amountTwo);
    }

    /// Test ERC1155 setApprovalForAll And IsApprovedForAll function
    function testSetApprovalForAllAndIsApprovedForAll(uint256 fuzzedKeyAlice, uint256 fuzzedKeyBob) public {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        TestReceipt receipt = createReceipt(alice);

        vm.startPrank(alice);
        // Alice approves operator
        receipt.setApprovalForAll(bob, true);
        assertTrue(receipt.isApprovedForAll(alice, bob));

        // Alice revokes approval
        receipt.setApprovalForAll(bob, false);
        assertFalse(receipt.isApprovedForAll(alice, bob));
    }

    /// Test ERC1155 safeTransferFrom function
    function testSafeTransferFrom(uint256 fuzzedKeyAlice, uint256 fuzzedKeyBob, uint256 tokenId, uint256 amount)
        public
    {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        amount = bound(amount, 1, type(uint256).max);

        TestReceipt receipt = createReceipt(alice);
        TestReceiptOwner receiptOwner = new TestReceiptOwner();

        vm.startPrank(alice);

        // Set the receipt owner
        receipt.transferOwnership(address(receiptOwner));

        // Set the authorized 'from' and 'to' addresses in receiptOwner
        receiptOwner.setFrom(address(0));
        receiptOwner.setTo(alice);

        receiptOwner.ownerMint(receipt, alice, tokenId, amount, "");

        // Check UnauthorizedTransfer reverts
        vm.expectRevert(abi.encodeWithSelector(UnauthorizedTransfer.selector, alice, bob));
        receipt.safeTransferFrom(alice, bob, tokenId, amount, "");

        // Expect revert on transfer to zero address
        receiptOwner.setTo(address(0));
        vm.expectRevert("ERC1155: transfer to the zero address");
        receipt.safeTransferFrom(alice, address(0), tokenId, amount, "");

        receiptOwner.setFrom(alice);
        receiptOwner.setTo(bob);

        // Perform transfer
        receipt.safeTransferFrom(alice, bob, tokenId, amount, "");
        assertEq(receipt.balanceOf(alice, tokenId), 0);
        assertEq(receipt.balanceOf(bob, tokenId), amount);
    }

    /// Test ERC1155 safeBatchTransferFrom function
    function testSafeBatchTransferFrom(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 tokenId1,
        uint256 tokenId2,
        uint256 amount1,
        uint256 amount2
    ) public {
        // Ensure the fuzzed keys are within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        vm.assume(tokenId1 != tokenId2);

        // Ensure amounts are bounded to avoid zero transfers
        amount1 = bound(amount1, 1, type(uint256).max);
        amount2 = bound(amount2, 1, type(uint256).max);
        vm.assume(amount1 != amount2);

        // Define arrays with token IDs and amounts
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;
        // Create a new receipt and receipt owner
        TestReceipt receipt = createReceipt(alice);
        TestReceiptOwner receiptOwner = new TestReceiptOwner();

        vm.startPrank(alice);

        // Transfer ownership to the receipt owner
        receipt.transferOwnership(address(receiptOwner));

        // Authorize alice as the sender and receiver in receiptOwner
        receiptOwner.setFrom(address(0));
        receiptOwner.setTo(alice);

        // Mint the specified token IDs and amounts to alice
        receiptOwner.ownerMint(receipt, alice, tokenId1, amount1, "");
        receiptOwner.ownerMint(receipt, alice, tokenId2, amount2, "");

        // Set the valid from/to addresses for the transfer
        receiptOwner.setFrom(alice);
        receiptOwner.setTo(bob);

        // Perform batch transfer
        receipt.safeBatchTransferFrom(alice, bob, tokenIds, amounts, "");

        // Verify balances are updated correctly
        assertEq(receipt.balanceOf(alice, tokenId1), 0);
        assertEq(receipt.balanceOf(bob, tokenId1), amount1);
        assertEq(receipt.balanceOf(alice, tokenId2), 0);
        assertEq(receipt.balanceOf(bob, tokenId2), amount2);
    }
}
