// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {
    MinShareRatio,
    ZeroReceiver,
    InvalidId,
    ZeroAssetsAmount
} from "../../../../../contracts/abstract/ReceiptVault.sol";
import {OffchainAssetReceiptVault} from "../../../../../contracts/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/foundry/abstract/OffchainAssetReceiptVaultTest.sol";

contract WithdrawTest is OffchainAssetReceiptVaultTest {
    event WithdrawWithReceipt(
        address sender,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares,
        uint256 id,
        bytes receiptInformation
    );

    /// Test PreviewWithdraw returns 0 shares if no withdrawer role
    function testPreviewWithdrawReturnsZero(
        uint256 fuzzedKeyAlice,
        uint256 aliceAssets,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);
        // Assume that aliceAssets is not 0
        vm.assume(aliceAssets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Call withdraw function
        uint256 shares = vault.previewWithdraw(aliceAssets, 1);

        assertEq(shares, 0);
        // Stop the prank
        vm.stopPrank();
    }

    /// Test PreviewWithdraw returns correct shares
    function testPreviewWithdraw(
        uint256 fuzzedKeyAlice,
        uint256 aliceAssets,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);
        // Assume that aliceAssets is not 0
        vm.assume(aliceAssets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        vault.grantRole(vault.WITHDRAWER(), alice);

        // Call withdraw function
        uint256 shares = vault.previewWithdraw(aliceAssets, 1);

        assertEq(shares, aliceAssets);
        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw function reverts without WITHDRAWER role
    function testWithdrawRevertsWithoutRole(
        uint256 fuzzedKeyAlice,
        uint256 aliceAssets,
        uint256 shareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        shareRatio = bound(shareRatio, 1, 1e18);
        address alice = vm.addr(fuzzedKeyAlice);
        // Assume that aliceAssets is not 0
        vm.assume(aliceAssets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);

        // Call the deposit function
        vault.deposit(aliceAssets, alice, shareRatio, data);

        vm.expectRevert();
        // Call withdraw function
        vault.withdraw(aliceAssets, alice, alice, 1, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw function emits WithdrawWithReceipt event
    function testWithdraw(
        uint256 fuzzedKeyAlice,
        uint256 aliceAssets,
        uint256 shareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        shareRatio = bound(shareRatio, 1, 1e18);
        address alice = vm.addr(fuzzedKeyAlice);
        // Assume that aliceAssets is not 0
        vm.assume(aliceAssets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.WITHDRAWER(), alice);

        // Call the deposit function
        vault.deposit(aliceAssets, alice, shareRatio, data);

        // Set up the event expectation for WithdrawWithReceipt
        vm.expectEmit(true, true, true, true);
        emit WithdrawWithReceipt(alice, alice, alice, aliceAssets, aliceAssets, 1, data);

        // Call withdraw function
        vault.withdraw(aliceAssets, alice, alice, 1, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw reverts when withdrawing more than balance
    function testWithdrawMoreThanBalance(
        uint256 fuzzedKeyAlice,
        uint256 aliceAssets,
        uint256 assetsToWithdraw,
        uint256 shareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        shareRatio = bound(shareRatio, 1, 1e18);
        address alice = vm.addr(fuzzedKeyAlice);
        // Assume that aliceAssets is not 0
        vm.assume(aliceAssets != 0);
        vm.assume(assetsToWithdraw > aliceAssets);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.WITHDRAWER(), alice);

        // Call the deposit function
        vault.deposit(aliceAssets, alice, shareRatio, data);

        // withdraw should revert
        vm.expectRevert();
        // Call withdraw function
        vault.withdraw(assetsToWithdraw, alice, alice, 1, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw reverts on ZeroAssetsAmount
    function testWithdrawZeroAssetsAmount(
        uint256 fuzzedKeyAlice,
        uint256 aliceAssets,
        uint256 shareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        shareRatio = bound(shareRatio, 1, 1e18);
        address alice = vm.addr(fuzzedKeyAlice);
        // Assume that aliceAssets is not 0
        vm.assume(aliceAssets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.WITHDRAWER(), alice);

        // Call the deposit function
        vault.deposit(aliceAssets, alice, shareRatio, data);

        // withdraw should revert
        vm.expectRevert(abi.encodeWithSelector(ZeroAssetsAmount.selector));
        // Call withdraw function
        vault.withdraw(0, alice, alice, 1, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw reverts on ZeroReceiver
    function testWithdrawZeroReceiver(
        uint256 fuzzedKeyAlice,
        uint256 aliceAssets,
        uint256 shareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        shareRatio = bound(shareRatio, 1, 1e18);
        address alice = vm.addr(fuzzedKeyAlice);
        // Assume that aliceAssets is not 0
        vm.assume(aliceAssets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.WITHDRAWER(), alice);

        // Call the deposit function
        vault.deposit(aliceAssets, alice, shareRatio, data);

        // withdraw should revert
        vm.expectRevert(abi.encodeWithSelector(ZeroReceiver.selector));
        // Call withdraw function
        vault.withdraw(aliceAssets, address(0), alice, 1, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw reverts on ZeroOwner
    function testWithdrawZeroOwner(
        uint256 fuzzedKeyAlice,
        uint256 aliceAssets,
        uint256 shareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        shareRatio = bound(shareRatio, 1, 1e18);
        address alice = vm.addr(fuzzedKeyAlice);
        // Assume that aliceAssets is not 0
        vm.assume(aliceAssets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.WITHDRAWER(), alice);

        // Call the deposit function
        vault.deposit(aliceAssets, alice, shareRatio, data);

        // withdraw should revert
        vm.expectRevert();
        // Call withdraw function
        vault.withdraw(aliceAssets, alice, address(0), 1, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw reverts on InvalidId when id is 0
    function testWithdrawInvalidId(
        uint256 fuzzedKeyAlice,
        uint256 aliceAssets,
        uint256 shareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        shareRatio = bound(shareRatio, 1, 1e18);
        address alice = vm.addr(fuzzedKeyAlice);
        // Assume that aliceAssets is not 0
        vm.assume(aliceAssets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.WITHDRAWER(), alice);

        // Call the deposit function
        vault.deposit(aliceAssets, alice, shareRatio, data);

        // withdraw should revert
        vm.expectRevert(abi.encodeWithSelector(InvalidId.selector, 0));

        // Call withdraw function
        vault.withdraw(aliceAssets, alice, alice, 0, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw function reverts when withdrawing someone else's assets
    function testWithdrawOfSomeoneElse(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 aliceAssets,
        uint256 shareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol,
        uint256 certifyUntil,
        uint256 referenceBlockNumber
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyBob = bound(fuzzedKeyBob, 1, SECP256K1_ORDER - 1);
        address bob = vm.addr(fuzzedKeyBob);

        vm.assume(alice != bob);

        referenceBlockNumber = bound(referenceBlockNumber, 1, block.number);
        certifyUntil = bound(certifyUntil, 1, 1e6 - 1);

        shareRatio = bound(shareRatio, 1, 1e18);
        // Assume that aliceAssets is not 0
        vm.assume(aliceAssets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.WITHDRAWER(), alice);
        vault.grantRole(vault.CERTIFIER(), alice);

        // Certify
        vault.certify(certifyUntil, referenceBlockNumber, false, data);

        // Call the deposit function
        vault.deposit(aliceAssets, bob, shareRatio, data);

        // withdraw should revert
        vm.expectRevert();

        // Call withdraw function
        vault.withdraw(aliceAssets, alice, bob, 1, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw on someone else
    function testWithdrawOnfSomeoneElse(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 aliceAssets,
        uint256 shareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyBob = bound(fuzzedKeyBob, 1, SECP256K1_ORDER - 1);
        address bob = vm.addr(fuzzedKeyBob);

        vm.assume(alice != bob);

        shareRatio = bound(shareRatio, 1, 1e18);
        // Assume that aliceAssets is not 0
        vm.assume(aliceAssets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.WITHDRAWER(), alice);

        // Call the deposit function
        vault.deposit(aliceAssets, alice, shareRatio, data);

        // Set up the event expectation for WithdrawWithReceipt
        vm.expectEmit(true, true, true, true);
        emit WithdrawWithReceipt(alice, bob, alice, aliceAssets, aliceAssets, 1, data);
        // Call withdraw function
        vault.withdraw(aliceAssets, bob, alice, 1, data);

        // Stop the prank
        vm.stopPrank();
    }
}
