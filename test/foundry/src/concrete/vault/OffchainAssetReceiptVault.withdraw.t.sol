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
import "forge-std/console.sol";

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

    /// Checks that balance owner balance changes after wirthdraw
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
        emit WithdrawWithReceipt(owner, receiver, owner, assets, assets, id, data);

        // Call withdraw function
        vault.withdraw(assets, receiver, owner, id, data);

        uint256 balanceAfterOwner = vault.balanceOf(owner);
        assertEq(balanceAfterOwner, initialBalanceOwner - assets);
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
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

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
        uint256 shareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        shareRatio = bound(shareRatio, 1, 1e18);
        // Assume that assets is not 0
        assets = bound(assets, 1, type(uint256).max);

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

        shareRatio = bound(shareRatio, 1, 1e18);
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
        vault.deposit(assets, bob, shareRatio, data);

        checkBalanceChange(vault, bob, bob, 1, assets, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw reverts when withdrawing more than balance
    function testWithdrawMoreThanBalance(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 assetsToWithdraw,
        uint256 shareRatio,
        uint256 id,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        shareRatio = bound(shareRatio, 1, 1e18);
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
        vault.deposit(assets, bob, shareRatio, data);

        // withdraw should revert
        vm.expectRevert();
        // Call withdraw function
        vault.withdraw(assetsToWithdraw, bob, bob, id, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw reverts on ZeroAssetsAmount
    function testWithdrawZeroAssetsAmount(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 shareRatio,
        uint256 id,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        shareRatio = bound(shareRatio, 1, 1e18);
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
        vault.deposit(assets, bob, shareRatio, data);

        // withdraw should revert
        vm.expectRevert(abi.encodeWithSelector(ZeroAssetsAmount.selector));
        // Call withdraw function
        vault.withdraw(0, bob, bob, id, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw reverts on ZeroReceiver
    function testWithdrawZeroReceiver(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 shareRatio,
        uint256 id,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        shareRatio = bound(shareRatio, 1, 1e18);
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
        vault.deposit(assets, bob, shareRatio, data);

        // withdraw should revert
        vm.expectRevert(abi.encodeWithSelector(ZeroReceiver.selector));
        // Call withdraw function
        vault.withdraw(assets, address(0), bob, id, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw reverts on ZeroOwner
    function testWithdrawZeroOwner(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 shareRatio,
        uint256 id,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        shareRatio = bound(shareRatio, 1, 1e18);
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
        vault.deposit(assets, bob, shareRatio, data);

        // withdraw should revert
        vm.expectRevert();
        // Call withdraw function
        vault.withdraw(assets, alice, address(0), id, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw reverts on InvalidId when id is 0
    function testWithdrawInvalidId(
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
        shareRatio = bound(shareRatio, 1, 1e18);
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
        vault.deposit(assets, bob, shareRatio, data);

        // withdraw should revert
        vm.expectRevert(abi.encodeWithSelector(InvalidId.selector, 0));

        // Call withdraw function
        vault.withdraw(assets, bob, bob, 0, data);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test withdraw function reverts when withdrawing someone else's assets
    function testWithdrawOfSomeoneElse(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 shareRatio,
        uint256 id,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol,
        uint256 certifyUntil,
        uint256 referenceBlockNumber,
        bool forceUntil
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        vm.assume(alice != bob);

        referenceBlockNumber = bound(referenceBlockNumber, 1, block.number);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);
        id = bound(id, 1, type(uint256).max);

        shareRatio = bound(shareRatio, 1, 1e18);
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
        vault.deposit(assets, alice, shareRatio, data);

        // withdraw should revert
        vm.expectRevert();

        // Call withdraw function
        vault.withdraw(assets, bob, alice, id, data);

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
        assets = bound(assets, 1, type(uint256).max);
        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set roles
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.WITHDRAWER(), bob);

        // Prank Bob for the transaction
        vm.startPrank(bob);

        // Call the deposit function
        vault.deposit(assets, bob, shareRatio, data);

        checkBalanceChange(vault, alice, bob, 1, assets, data);

        // Stop the prank
        vm.stopPrank();
    }
}
