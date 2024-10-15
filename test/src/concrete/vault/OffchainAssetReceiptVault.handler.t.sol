// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {OffchainAssetReceiptVault} from "../../../../../src/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {LibOffchainAssetVaultCreator} from "test/lib/LibOffchainAssetVaultCreator.sol";
import {Receipt as ReceiptContract} from "../../../../../src/concrete/receipt/Receipt.sol";

contract OffchainAssetReceiptVaultHandlerTest is OffchainAssetReceiptVaultTest {
    event SetERC20Tier(address sender, address tier, uint256 minimumTier, uint256[] context, bytes data);
    event SetERC1155Tier(address sender, address tier, uint256 minimumTier, uint256[] context, bytes data);
    event DepositWithReceipt(
        address sender, address owner, uint256 assets, uint256 shares, uint256 id, bytes receiptInformation
    );

    function setUpAddressesAndBounds(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 fuzzedKeyJohn,
        uint256 balance,
        uint256 referenceBlockNumber,
        uint256 certifyUntil
    ) internal view returns (address alice, address bob, address john, uint256, uint256, uint256) {
        // Ensure the fuzzed key is within the valid range for secp256k
        alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        john = vm.addr((fuzzedKeyJohn % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob && alice != john);
        vm.assume(bob != john);

        balance = bound(balance, 1, type(uint256).max); // Bound from one to avoid ZeroAssets
        referenceBlockNumber = bound(referenceBlockNumber, 1, block.number);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max - 1); // substruct 1 for next bound

        return (alice, bob, john, balance, referenceBlockNumber, certifyUntil);
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
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        uint256 referenceBlockNumber,
        uint256 certifyUntil,
        uint256 futureTimeStamp,
        bool forceUntil,
        uint256 balance
    ) external {
        address alice;
        address bob;
        (alice, bob,, balance, referenceBlockNumber, certifyUntil) =
            setUpAddressesAndBounds(fuzzedKeyAlice, fuzzedKeyBob, 0, balance, referenceBlockNumber, certifyUntil);

        // Need setting future timestamp so system gets unsertified but transfer is possible
        // due to a handler role
        futureTimeStamp = bound(futureTimeStamp, certifyUntil + 1, type(uint32).max);

        vm.assume(alice != bob);

        OffchainAssetReceiptVault vault;
        ReceiptContract receipt;
        (vault, receipt) = setUpVault(alice, assetName, assetName);

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        vault.grantRole(vault.CERTIFIER(), alice);
        vault.grantRole(vault.HANDLER(), bob);
        vault.grantRole(vault.DEPOSITOR(), alice);

        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, forceUntil, bytes(""));

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
        address alice;
        address bob;
        address john;
        (alice, bob, john, balance, referenceBlockNumber, certifyUntil) = setUpAddressesAndBounds(
            fuzzedKeyAlice, fuzzedKeyBob, fuzzedKeyJohn, balance, referenceBlockNumber, certifyUntil
        );

        // Need setting future timestamp so system gets uncertified but transfer is possible
        // due to a handler role
        futureTimeStamp = bound(futureTimeStamp, certifyUntil + 1, type(uint32).max);

        vm.assume(alice != bob);
        vm.assume(alice != john);
        vm.assume(bob != john);

        OffchainAssetReceiptVault vault;
        ReceiptContract receipt;
        (vault, receipt) = setUpVault(alice, assetName, assetName);

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
        address alice;
        address bob;
        address john;
        (alice, bob, john, balance, referenceBlockNumber, certifyUntil) = setUpAddressesAndBounds(
            fuzzedKeyAlice, fuzzedKeyBob, fuzzedKeyJohn, balance, referenceBlockNumber, certifyUntil
        );

        // Need setting future timestamp so system gets uncertified but transfer is possible
        // due to a handler role
        futureTimeStamp = bound(futureTimeStamp, certifyUntil + 1, type(uint32).max);

        OffchainAssetReceiptVault vault;
        ReceiptContract receipt;
        (vault, receipt) = setUpVault(alice, assetName, assetName);

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
