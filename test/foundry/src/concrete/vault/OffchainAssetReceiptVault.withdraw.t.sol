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
        uint256 assets,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        // Assume that assets is not 0
        vm.assume(assets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Call withdraw function
        uint256 shares = vault.previewWithdraw(assets, 1);

        assertEq(shares, 0);
        // Stop the prank
        vm.stopPrank();
    }

    /// Test PreviewWithdraw returns correct shares
    function testPreviewWithdraw(
        uint256 fuzzedKeyAlice,
        uint256 assets,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        // Assume that assets is not 0
        vm.assume(assets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        vault.grantRole(vault.WITHDRAWER(), alice);

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
        uint256 shareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        shareRatio = bound(shareRatio, 1, 1e18);
        // Assume that assets is not 0
        vm.assume(assets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);

        // Call the deposit function
        vault.deposit(assets, alice, shareRatio, data);

        vm.expectRevert();
        // Call withdraw function
        vault.withdraw(assets, alice, alice, 1, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw function emits WithdrawWithReceipt event
    function testWithdraw(
        uint256 fuzzedKeyAlice,
        uint256 assets,
        uint256 shareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        shareRatio = bound(shareRatio, 1, 1e18);
        // Assume that assets is not 0
        vm.assume(assets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.WITHDRAWER(), alice);

        // Call the deposit function
        vault.deposit(assets, alice, shareRatio, data);

        // Set up the event expectation for WithdrawWithReceipt
        vm.expectEmit(true, true, true, true);
        emit WithdrawWithReceipt(alice, alice, alice, assets, assets, 1, data);

        // Call withdraw function
        vault.withdraw(assets, alice, alice, 1, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw reverts when withdrawing more than balance
    function testWithdrawMoreThanBalance(
        uint256 fuzzedKeyAlice,
        uint256 assets,
        uint256 assetsToWithdraw,
        uint256 shareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        shareRatio = bound(shareRatio, 1, 1e18);
        // Assume that assets is not 0
        vm.assume(assets != 0);
        vm.assume(assetsToWithdraw > assets);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.WITHDRAWER(), alice);

        // Call the deposit function
        vault.deposit(assets, alice, shareRatio, data);

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
        uint256 assets,
        uint256 shareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        shareRatio = bound(shareRatio, 1, 1e18);
        // Assume that assets is not 0
        vm.assume(assets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.WITHDRAWER(), alice);

        // Call the deposit function
        vault.deposit(assets, alice, shareRatio, data);

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
        uint256 assets,
        uint256 shareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        shareRatio = bound(shareRatio, 1, 1e18);
        // Assume that assets is not 0
        vm.assume(assets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.WITHDRAWER(), alice);

        // Call the deposit function
        vault.deposit(assets, alice, shareRatio, data);

        // withdraw should revert
        vm.expectRevert(abi.encodeWithSelector(ZeroReceiver.selector));
        // Call withdraw function
        vault.withdraw(assets, address(0), alice, 1, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw reverts on ZeroOwner
    function testWithdrawZeroOwner(
        uint256 fuzzedKeyAlice,
        uint256 assets,
        uint256 shareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        shareRatio = bound(shareRatio, 1, 1e18);
        // Assume that assets is not 0
        vm.assume(assets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.WITHDRAWER(), alice);

        // Call the deposit function
        vault.deposit(assets, alice, shareRatio, data);

        // withdraw should revert
        vm.expectRevert();
        // Call withdraw function
        vault.withdraw(assets, alice, address(0), 1, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw reverts on InvalidId when id is 0
    function testWithdrawInvalidId(
        uint256 fuzzedKeyAlice,
        uint256 assets,
        uint256 shareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        shareRatio = bound(shareRatio, 1, 1e18);
        // Assume that assets is not 0
        vm.assume(assets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.WITHDRAWER(), alice);

        // Call the deposit function
        vault.deposit(assets, alice, shareRatio, data);

        // withdraw should revert
        vm.expectRevert(abi.encodeWithSelector(InvalidId.selector, 0));

        // Call withdraw function
        vault.withdraw(assets, alice, alice, 0, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw function reverts when withdrawing someone else's assets
    function testWithdrawOfSomeoneElse(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 shareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol,
        uint256 certifyUntil,
        uint256 referenceBlockNumber
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        vm.assume(alice != bob);

        referenceBlockNumber = bound(referenceBlockNumber, 1, block.number);
        certifyUntil = bound(certifyUntil, 1, 1e6 - 1);

        shareRatio = bound(shareRatio, 1, 1e18);
        // Assume that assets is not 0
        vm.assume(assets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.WITHDRAWER(), alice);
        vault.grantRole(vault.CERTIFIER(), alice);

        // Certify
        vault.certify(certifyUntil, referenceBlockNumber, false, data);

        // Call the deposit function
        vault.deposit(assets, bob, shareRatio, data);

        // withdraw should revert
        vm.expectRevert();

        // Call withdraw function
        vault.withdraw(assets, alice, bob, 1, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw on someone else
    function testWithdrawOnfSomeoneElse(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 shareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        vm.assume(alice != bob);

        shareRatio = bound(shareRatio, 1, 1e18);
        // Assume that assets is not 0
        vm.assume(assets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.WITHDRAWER(), alice);

        // Call the deposit function
        vault.deposit(assets, alice, shareRatio, data);

        // Set up the event expectation for WithdrawWithReceipt
        vm.expectEmit(true, true, true, true);
        emit WithdrawWithReceipt(alice, bob, alice, assets, assets, 1, data);
        // Call withdraw function
        vault.withdraw(assets, bob, alice, 1, data);

        // Stop the prank
        vm.stopPrank();
    }
}
