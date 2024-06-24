// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {
    ZeroReceiver,
    InvalidId,
    ZeroAssetsAmount,
    ZeroSharesAmount
} from "../../../../../contracts/abstract/ReceiptVault.sol";
import {OffchainAssetReceiptVault} from "../../../../../contracts/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/foundry/abstract/OffchainAssetReceiptVaultTest.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";

contract RedeemTest is OffchainAssetReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

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
        uint256 shares,
        bytes memory data
    ) internal {
        uint256 initialBalanceOwner = vault.balanceOf(owner);

        // Set up the event expectation for WithdrawWithReceipt
        vm.expectEmit(true, true, true, true);
        emit WithdrawWithReceipt(owner, receiver, owner, shares, shares, id, data);

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
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
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
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

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
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

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
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

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
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
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
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
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
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
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
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        vm.assume(alice != bob);

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
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        vm.assume(alice != bob);

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
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        vm.assume(alice != bob);

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
}
