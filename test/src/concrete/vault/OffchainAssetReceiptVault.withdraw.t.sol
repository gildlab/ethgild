// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ZeroReceiver, InvalidId, ZeroAssetsAmount, ZeroSharesAmount} from "src/abstract/ReceiptVault.sol";
import {OffchainAssetReceiptVault} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm, ReceiptContract} from "../../../abstract/OffchainAssetReceiptVaultTest.sol";
import {IReceiptVaultV2, IReceiptVaultV1} from "src/interface/IReceiptVaultV2.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract WithdrawTest is OffchainAssetReceiptVaultTest {
    /// Checks that balance owner balance changes after withdraw
    function checkBalanceChange(
        OffchainAssetReceiptVault vault,
        address receiver,
        address owner,
        uint256 id,
        uint256 assets,
        bytes memory data
    ) internal {
        uint256 initialBalanceOwner = vault.balanceOf(owner);

        // Set up the event expectation for WithdrawWithReceipt
        vm.expectEmit(true, true, true, true);
        emit IReceiptVaultV1.Withdraw(owner, receiver, owner, assets, assets, id, data);

        // Call withdraw function
        vault.withdraw(assets, receiver, owner, id, data);

        uint256 balanceAfterOwner = vault.balanceOf(owner);
        assertEq(balanceAfterOwner, initialBalanceOwner - assets);
    }

    /// Checks that balance owner balance does not change after wirthdraw revert
    function checkNoBalanceChange(
        OffchainAssetReceiptVault vault,
        address receiver,
        address owner,
        uint256 id,
        uint256 assets,
        bytes memory data,
        bytes memory expectedRevertData
    ) internal {
        uint256 initialBalanceOwner = vault.balanceOf(owner);

        // Check if expectedRevertData is provided
        if (expectedRevertData.length > 0) {
            vm.expectRevert(expectedRevertData);
        } else {
            vm.expectRevert();
        }
        // Call withdraw function
        vault.withdraw(assets, receiver, owner, id, data);

        uint256 balanceAfterOwner = vault.balanceOf(owner);
        assertEq(balanceAfterOwner, initialBalanceOwner);
    }

    /// Test PreviewWithdraw returns 0 shares if no withdrawer role
    function testPreviewWithdrawReturnsZero(
        uint256 fuzzedKeyAlice,
        uint256 assets,
        string memory assetName,
        string memory assetSymbol,
        uint256 id
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        // Assume that assets is not 0
        assets = bound(assets, 1, type(uint256).max);
        id = bound(id, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Call withdraw function
        uint256 shares = vault.previewWithdraw(assets, id);

        assertEq(shares, 0);
        // Stop the prank
        vm.stopPrank();
    }

    /// Test PreviewWithdraw returns correct shares
    function testPreviewWithdraw(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        // Assume that assets is not 0
        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        // Prank as Alice to grant role
        vm.startPrank(alice);

        vault.grantRole(vault.WITHDRAWER(), bob);

        // Prank as Bob for transaction
        vm.startPrank(bob);

        // Call withdraw function
        uint256 shares = vault.previewWithdraw(assets, 1);

        assertEq(shares, assets);
        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw function reverts without WITHDRAWER role
    function testWithdrawRevertsWithoutRole(
        uint256 fuzzedKeyAlice,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Assume that assets is not 0
        assets = bound(assets, 1, type(uint256).max);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);

        // Call the deposit function
        vault.deposit(assets, alice, minShareRatio, data);

        checkNoBalanceChange(vault, alice, alice, 1, assets, data, abi.encodeWithSelector(ZeroSharesAmount.selector));

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw function emits WithdrawWithReceipt event
    function testWithdraw(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Assume that assets is not 0
        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        // Prank as Alice to grant roles
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.WITHDRAWER(), bob);

        // Prank Bob for the transaction
        vm.startPrank(bob);

        // Call the deposit function
        vault.deposit(assets, bob, minShareRatio, data);

        checkBalanceChange(vault, bob, bob, 1, assets, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test Withdraw function while withdrawing some part of the assets deposited
    function testWithdrawSomePartOfAssetsDeposited(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 withdrawAmmount,
        uint256 minShareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        minShareRatio = bound(minShareRatio, 0, 1e18);

        // Bound assets from 2 to make sure max bound for withdrawAmmount gets more than min
        assets = bound(assets, 2, type(uint256).max);

        // Get some part of assets to redeem
        withdrawAmmount = bound(withdrawAmmount, 1, assets);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        // Prank as Alice to grant roles
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.WITHDRAWER(), bob);

        // Prank Bob for the transaction
        vm.startPrank(bob);

        // Call the deposit function
        vault.deposit(assets, bob, minShareRatio, data);

        checkBalanceChange(vault, bob, bob, 1, withdrawAmmount, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw reverts when withdrawing more than balance
    function testWithdrawMoreThanBalance(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 assetsToWithdraw,
        uint256 minShareRatio,
        uint256 id,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        id = bound(id, 1, type(uint256).max);
        // Assume that assets is not 0
        assets = bound(assets, 1, type(uint256).max);
        vm.assume(assetsToWithdraw > assets);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.WITHDRAWER(), bob);

        // Prank Bob for the transaction
        vm.startPrank(bob);

        // Call the deposit function
        vault.deposit(assets, bob, minShareRatio, data);

        checkNoBalanceChange(vault, bob, bob, id, assetsToWithdraw, data, bytes(""));

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw reverts on ZeroAssetsAmount
    function testWithdrawZeroAssetsAmount(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 minShareRatio,
        uint256 id,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Assume that assets is not 0
        assets = bound(assets, 1, type(uint256).max);
        id = bound(id, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.WITHDRAWER(), bob);

        // Prank Bob for the transaction
        vm.startPrank(bob);

        // Call the deposit function
        vault.deposit(assets, bob, minShareRatio, data);

        checkNoBalanceChange(vault, bob, bob, id, 0, data, abi.encodeWithSelector(ZeroAssetsAmount.selector));

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw reverts on ZeroReceiver
    function testWithdrawZeroReceiver(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 minShareRatio,
        uint256 id,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Assume that assets is not 0
        assets = bound(assets, 1, type(uint256).max);
        id = bound(id, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.WITHDRAWER(), bob);

        // Prank Bob for the transaction
        vm.startPrank(bob);

        // Call the deposit function
        vault.deposit(assets, bob, minShareRatio, data);

        checkNoBalanceChange(vault, address(0), bob, id, assets, data, abi.encodeWithSelector(ZeroReceiver.selector));
        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw reverts on ZeroOwner
    function testWithdrawZeroOwner(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 minShareRatio,
        uint256 id,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Assume that assets is not 0
        assets = bound(assets, 1, type(uint256).max);
        id = bound(id, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.WITHDRAWER(), bob);

        // Prank Bob for the transaction
        vm.startPrank(bob);

        // Call the deposit function
        vault.deposit(assets, bob, minShareRatio, data);

        checkNoBalanceChange(
            vault, alice, address(0), id, assets, data, abi.encodeWithSelector(ZeroSharesAmount.selector)
        );

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw reverts on InvalidId when id is 0
    function testWithdrawInvalidId(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Assume that assets is not 0
        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.WITHDRAWER(), bob);

        // Prank Bob for the transaction
        vm.startPrank(bob);

        // Call the deposit function
        vault.deposit(assets, bob, minShareRatio, data);

        checkNoBalanceChange(vault, bob, bob, 0, assets, data, abi.encodeWithSelector(InvalidId.selector, 0));

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw function reverts when withdrawing someone else's assets
    function testWithdrawOfSomeoneElse(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol,
        uint256 certifyUntil,
        uint256 referenceBlockNumber,
        bool forceUntil
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        referenceBlockNumber = bound(referenceBlockNumber, 1, block.number);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Assume that assets is not 0
        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set roles
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.WITHDRAWER(), bob);
        vault.grantRole(vault.CERTIFIER(), bob);

        // Prank Bob for the transaction
        vm.startPrank(bob);

        // Certify
        vault.certify(certifyUntil, referenceBlockNumber, forceUntil, data);

        // Call the deposit function
        vault.deposit(assets, alice, minShareRatio, data);

        checkNoBalanceChange(vault, bob, alice, 1, assets, data, abi.encodeWithSelector(ZeroSharesAmount.selector));

        // Stop the prank
        vm.stopPrank();
    }

    /// Test someone can withdraw their own assets and set a different recipient
    function testWithdrawToSomeoneElse(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Assume that assets is not 0
        assets = bound(assets, 1, type(uint256).max);
        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set roles
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.WITHDRAWER(), bob);

        // Prank Bob for the transaction
        vm.startPrank(bob);

        // Call the deposit function
        vault.deposit(assets, bob, minShareRatio, data);

        checkBalanceChange(vault, alice, bob, 1, assets, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw function reverts when withdrawing someone else's assets
    /// deposeted by them
    function testWithdrawOthersAssetsReverts(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol,
        uint256 certifyUntil,
        uint256 referenceBlockNumber,
        bool forceUntil
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        referenceBlockNumber = bound(referenceBlockNumber, 1, block.number);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Assume that assets is not 0
        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set roles
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.WITHDRAWER(), bob);
        vault.grantRole(vault.CERTIFIER(), alice);

        // Certify
        vault.certify(certifyUntil, referenceBlockNumber, forceUntil, data);

        // Alice deposits to herself
        vault.deposit(assets, alice, minShareRatio, data);

        // Prank Bob for the withdraw transaction
        vm.startPrank(bob);

        checkNoBalanceChange(vault, bob, alice, 1, assets, data, abi.encodeWithSelector(ZeroSharesAmount.selector));

        // Stop the prank
        vm.stopPrank();
    }

    /// Test Withdraw over several different IDs
    function testWithdrawOverSeveralIds(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 firstDepositAmount,
        uint256 secondDepositAmount,
        uint256 thirdDepositAmount,
        uint256 minShareRatio,
        uint256 firstWithdrawAmmount,
        uint256 secondWithdrawAmmount,
        uint256 thirdWithdrawAmmount,
        bytes memory data,
        string memory assetName
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Assume that firstDepositAmount is not 0
        // Bound with uint64 max so next deposits doesnot cause overflow
        firstDepositAmount = bound(firstDepositAmount, 1, type(uint64).max);
        secondDepositAmount = bound(secondDepositAmount, 1, type(uint64).max);
        thirdDepositAmount = bound(thirdDepositAmount, 1, type(uint64).max);
        vm.assume(firstDepositAmount != secondDepositAmount);
        vm.assume(firstDepositAmount != thirdDepositAmount);
        vm.assume(secondDepositAmount != thirdDepositAmount);

        firstWithdrawAmmount = bound(firstWithdrawAmmount, 1, firstDepositAmount);
        secondWithdrawAmmount = bound(secondWithdrawAmmount, 1, secondDepositAmount);
        thirdWithdrawAmmount = bound(thirdWithdrawAmmount, 1, thirdDepositAmount);

        vm.assume(firstWithdrawAmmount != secondWithdrawAmmount);
        vm.assume(firstWithdrawAmmount != thirdWithdrawAmmount);
        vm.assume(secondWithdrawAmmount != thirdWithdrawAmmount);
        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetName);
        // Prank as Alice to grant roles
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.WITHDRAWER(), bob);

        // Prank Bob for the transaction
        vm.startPrank(bob);

        // Call the deposit function
        vault.deposit(firstDepositAmount, bob, minShareRatio, data);

        // Call another deposit deposit function
        vault.deposit(secondDepositAmount, bob, minShareRatio, data);

        // Call another deposit deposit function
        vault.deposit(thirdDepositAmount, bob, minShareRatio, data);

        checkBalanceChange(vault, bob, bob, 1, firstWithdrawAmmount, data);
        checkBalanceChange(vault, bob, bob, 2, secondWithdrawAmmount, data);
        checkBalanceChange(vault, bob, bob, 3, thirdWithdrawAmmount, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test alice attempting to burn bob's ID
    function testOffchainAssetWithdrawAliceBurnBob(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 aliceMinShareRatio,
        uint256 bobMinShareRatio,
        uint256 aliceDeposit,
        uint256 bobDeposit
    ) external {
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        aliceMinShareRatio = bound(aliceMinShareRatio, 0, 1e18);
        bobMinShareRatio = bound(bobMinShareRatio, 0, 1e18);
        aliceDeposit = bound(aliceDeposit, 1, type(uint128).max);
        bobDeposit = bound(bobDeposit, 1, type(uint128).max);

        vm.assume(alice != bob);
        vm.recordLogs();
        OffchainAssetReceiptVault vault = createVault(alice, "Alice", "Alice");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        ReceiptContract receipt = getReceipt(logs);

        vm.startPrank(alice);

        // Prank as Alice to grant roles
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.WITHDRAWER(), alice);
        vault.grantRole(vault.WITHDRAWER(), bob);

        vault.deposit(aliceDeposit, alice, aliceMinShareRatio, bytes(""));
        assertEqUint(vault.balanceOf(alice), aliceDeposit);
        assertEqUint(vault.balanceOf(bob), 0);
        assertEqUint(receipt.balanceOf(alice, 1), aliceDeposit);
        assertEqUint(receipt.balanceOf(bob, 1), 0);
        vm.stopPrank();

        vm.startPrank(bob);
        vault.deposit(bobDeposit, bob, bobMinShareRatio, bytes(""));
        assertEqUint(vault.balanceOf(alice), aliceDeposit);
        assertEqUint(vault.balanceOf(bob), bobDeposit);
        assertEqUint(receipt.balanceOf(alice, 1), aliceDeposit);
        assertEqUint(receipt.balanceOf(bob, 1), 0);
        assertEqUint(receipt.balanceOf(alice, 2), 0);
        assertEqUint(receipt.balanceOf(bob, 2), bobDeposit);
        vm.stopPrank();

        vm.startPrank(alice);

        // Alice attempts to burn Bob's receipt by ID, using herself as owner.
        vm.expectRevert("ERC1155: burn amount exceeds balance");
        vault.withdraw(1, alice, alice, 2, bytes(""));

        // Alice attempts to burn Bob's receipt by ID, using Bob as owner.
        vm.expectRevert("ERC20: insufficient allowance");
        vault.withdraw(1, alice, bob, 2, bytes(""));

        vm.stopPrank();
        //Bob can withdraw his own receipt.
        vm.startPrank(bob);
        uint256 maxWithdraw = vault.maxWithdraw(bob, 2);
        vault.withdraw(maxWithdraw, bob, bob, 2, bytes(""));

        vault.deposit(bobDeposit, bob, aliceMinShareRatio, bytes("")); //id 3

        // Bob cannot burn Alice's receipt.
        vm.expectRevert("ERC20: insufficient allowance");
        vault.withdraw(1, bob, alice, 1, bytes(""));

        uint256 maxWithdrawBalance = vault.maxWithdraw(bob, 3);

        //Bob's balance should be only from his latest deposit.
        assertEqUint(vault.balanceOf(bob), maxWithdrawBalance);

        // Bob cannot withdraw any more under alice price.
        vm.expectRevert("ERC1155: burn amount exceeds balance");
        vault.withdraw(1, bob, bob, 1, bytes(""));

        vm.stopPrank();
        // Alice can withdraw her own receipt.
        vm.startPrank(alice);

        uint256 maxWithdrawAlice = vault.maxWithdraw(alice, 1);
        vault.withdraw(maxWithdrawAlice, alice, alice, 1, bytes(""));
        vm.stopPrank();
    }
}
