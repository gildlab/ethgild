// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ZeroReceiver, InvalidId, ZeroAssetsAmount, ZeroSharesAmount} from "src/abstract/ReceiptVault.sol";
import {OffchainAssetReceiptVault} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm, ReceiptContract} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {IReceiptVaultV2, IReceiptVaultV1} from "src/interface/IReceiptVaultV2.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract RedeemTest is OffchainAssetReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Checks that balance owner balance changes after wirthdraw
    function checkBalanceChange(
        OffchainAssetReceiptVault vault,
        address receiver,
        address owner,
        uint256 id,
        uint256 shares,
        bytes memory data
    ) internal {
        uint256 initialBalanceOwner = vault.balanceOf(owner);

        // Set up the event expectation for WithdrawWithReceipt
        vm.expectEmit(true, true, true, true);
        emit IReceiptVaultV1.Withdraw(owner, receiver, owner, shares, shares, id, data);

        // Call redeem function
        vault.redeem(shares, receiver, owner, id, data);

        uint256 balanceAfterOwner = vault.balanceOf(owner);
        assertEq(balanceAfterOwner, initialBalanceOwner - shares);
    }

    /// Checks that balance owner balance does not change after wirthdraw revert
    function checkNoBalanceChange(
        OffchainAssetReceiptVault vault,
        address receiver,
        address owner,
        uint256 id,
        uint256 shares,
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
        vault.redeem(shares, receiver, owner, id, data);

        uint256 balanceAfterOwner = vault.balanceOf(owner);
        assertEq(balanceAfterOwner, initialBalanceOwner);
    }

    /// Test PreviewRedeem returns 0 shares if no withdrawer role
    function testPreviewRedeemReturnsZero(
        uint256 fuzzedKeyAlice,
        uint256 shares,
        string memory assetName,
        string memory assetSymbol,
        uint256 minShareRatio
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        // Assume that shares is not 0
        shares = bound(shares, 1, type(uint256).max);
        minShareRatio = bound(minShareRatio, 1, 1e18); //Bound from 1 to avoid division by 0
        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Call withdraw function
        uint256 assets = vault.previewWithdraw(shares, minShareRatio);

        assertEq(assets, 0);
        // Stop the prank
        vm.stopPrank();
    }

    /// Test PreviewRedeem returns correct shares
    function testPreviewRedeem(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 shares,
        string memory assetName,
        string memory assetSymbol,
        uint256 minShareRatio
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        minShareRatio = bound(minShareRatio, 1, 1e18); //Bound from 1 to avoid division by 0
        // Assume that shares is not 0
        shares = bound(shares, 1, type(uint64).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        // Prank as Alice to grant role
        vm.startPrank(alice);

        vault.grantRole(vault.WITHDRAWER(), bob);

        // Prank as Bob for transaction
        vm.startPrank(bob);

        uint256 expectedAssets = shares.fixedPointDiv(minShareRatio, Math.Rounding.Down);

        // Get assets
        uint256 assets = vault.previewRedeem(shares, minShareRatio);

        assertEq(assets, expectedAssets);
        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw function reverts without WITHDRAWER role
    function testRedeemRevertsWithoutRole(
        uint256 fuzzedKeyAlice,
        uint256 shares,
        uint256 minShareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        minShareRatio = bound(minShareRatio, 1, 1e18);
        // Assume that shares is not 0
        shares = bound(shares, 1, type(uint64).max);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);

        // Call the deposit function
        vault.deposit(shares, alice, minShareRatio, data);

        checkNoBalanceChange(vault, alice, alice, minShareRatio, shares, data, bytes(""));

        // Stop the prank
        vm.stopPrank();
    }

    /// Test Redeem function emits WithdrawWithReceipt event
    function testRedeem(
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

    /// Test Redeem function while redeeming some part of the assets deposited
    function testRedeemSomePartOfAssetsDeposited(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 redeemAmount,
        uint256 minShareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        minShareRatio = bound(minShareRatio, 0, 1e18);

        // Bound assets from 2 to make sure max bound for redeemAmount gets more than min
        assets = bound(assets, 2, type(uint256).max);

        // Get some part of assets to redeem
        redeemAmount = bound(redeemAmount, 1, assets);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        // Prank as Alice to grant roles
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.WITHDRAWER(), bob);

        // Prank Bob for the transaction
        vm.startPrank(bob);

        // Call the deposit function
        vault.deposit(assets, bob, minShareRatio, data);

        checkBalanceChange(vault, bob, bob, 1, redeemAmount, data);

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

    /// Test redeem reverts on ZeroAssetsAmount
    function testRedeemZeroAssetsAmount(
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

        checkNoBalanceChange(vault, bob, bob, minShareRatio, 0, data, abi.encodeWithSelector(ZeroAssetsAmount.selector));

        // Stop the prank
        vm.stopPrank();
    }

    /// Test Redeem reverts on ZeroReceiver
    function testRedeemZeroReceiver(
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

        checkNoBalanceChange(
            vault, address(0), bob, minShareRatio, assets, data, abi.encodeWithSelector(ZeroReceiver.selector)
        );
        // Stop the prank
        vm.stopPrank();
    }

    /// Test redeem reverts on ZeroOwner
    function testRedeemZeroOwner(
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

        checkNoBalanceChange(vault, alice, address(0), minShareRatio, assets, data, bytes(""));

        // Stop the prank
        vm.stopPrank();
    }

    /// Test redeem reverts on InvalidId when id is 0
    function testRedeemInvalidId(
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

    /// Test redeem function reverts when redeeming someone else's assets
    function testRedeemOfSomeoneElse(
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

        uint256 shares = assets.fixedPointMul(minShareRatio, Math.Rounding.Down);

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

        checkNoBalanceChange(vault, bob, alice, minShareRatio, shares, data, bytes(""));

        // Stop the prank
        vm.stopPrank();
    }

    /// Test someone can redeem their own assets and set a different recipient
    function testRedeemToSomeoneElse(
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

    /// Test redeem function reverts when withdrawing someone else's assets
    /// deposeted by them
    function testRedeemOthersAssetsReverts(
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

        checkNoBalanceChange(vault, bob, alice, 1, assets, data, bytes(""));

        // Stop the prank
        vm.stopPrank();
    }

    /// Test Redeem over several different IDs
    function testRedeemOverSeveralIds(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 firstDepositAmount,
        uint256 secondDepositAmount,
        uint256 thirdDepositAmount,
        uint256 firstRedeemAmount,
        uint256 secondRedeemAmount,
        uint256 thirdRedeemAmount,
        uint256 minShareRatio,
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

        firstRedeemAmount = bound(firstRedeemAmount, 1, firstDepositAmount);
        secondRedeemAmount = bound(secondRedeemAmount, 1, secondDepositAmount);
        thirdRedeemAmount = bound(thirdRedeemAmount, 1, thirdDepositAmount);

        vm.assume(firstRedeemAmount != secondRedeemAmount);
        vm.assume(firstRedeemAmount != thirdRedeemAmount);
        vm.assume(secondRedeemAmount != thirdRedeemAmount);

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

        checkBalanceChange(vault, bob, bob, 1, firstRedeemAmount, data);
        checkBalanceChange(vault, bob, bob, 2, secondRedeemAmount, data);
        checkBalanceChange(vault, bob, bob, 3, thirdRedeemAmount, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw with erc20 approval
    function testOffchainAssetWithdrawWithERC20Approval(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 amount,
        uint256 minShareRatio,
        uint256 redeemSharesAmount
    ) external {
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        minShareRatio = bound(minShareRatio, 0, 1e18);

        vm.assume(alice != bob);
        amount = bound(amount, 1, type(uint128).max);

        vm.recordLogs();
        OffchainAssetReceiptVault vault = createVault(alice, "Alice", "Alice");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        ReceiptContract receipt = getReceipt(logs);

        vm.startPrank(alice);

        uint256 expectedShares = amount.fixedPointMul(minShareRatio, Math.Rounding.Down);
        vm.assume(expectedShares > 0);

        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.WITHDRAWER(), alice);
        vault.grantRole(vault.WITHDRAWER(), bob);

        uint256 totalShares = vault.deposit(amount, alice, minShareRatio, bytes(""));

        redeemSharesAmount = bound(redeemSharesAmount, 1, totalShares);

        uint256 aliceBalanceBeforeTransfer = vault.balanceOf(alice);
        assertEqUint(aliceBalanceBeforeTransfer, totalShares);

        uint256 assetsAmount = vault.previewRedeem(redeemSharesAmount, minShareRatio);
        vm.assume(assetsAmount > 0);
        vm.stopPrank();

        // Bob has no allowance so he cannot withdraw.
        vm.startPrank(bob);
        vm.expectRevert("ERC20: insufficient allowance");
        vault.redeem(redeemSharesAmount, bob, alice, minShareRatio, bytes(""));
        vm.stopPrank();

        // Alice approves Bob to withdraw her shares.
        vm.startPrank(alice);
        vault.approve(bob, redeemSharesAmount);
        vm.stopPrank();

        // Check allowance before withdrawal
        assertEq(vault.allowance(alice, bob), redeemSharesAmount);

        // Bob still cannot withdraw because he has not been assigned as a
        // receipt operator.
        vm.startPrank(bob);

        vm.expectRevert("ERC1155: caller is not token owner or approved");
        vault.redeem(redeemSharesAmount, bob, alice, 1, bytes(""));
        vm.stopPrank();

        // Alice makes Bob an operator.
        vm.startPrank(alice);
        receipt.setApprovalForAll(bob, true);
        vm.stopPrank();

        // Bob can now withdraw.
        vm.startPrank(bob);
        vault.redeem(redeemSharesAmount, bob, alice, 1, bytes(""));
        vm.stopPrank();
    }
}
