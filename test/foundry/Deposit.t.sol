// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import {MinShareRatio, ZeroAssetsAmount, ZeroReceiver} from "../../contracts/vault/receipt/ReceiptVault.sol";
import {CreateOffchainAssetReceiptVaultFactory} from "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfig,
    CertificationExpired
} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";
import {IReceiptV1} from "../../contracts/vault/receipt/IReceiptV1.sol";
import {LibFixedPointMath, Math} from "@rainprotocol/rain-protocol/contracts/math/LibFixedPointMath.sol";
import {OffchainAssetVaultCreator} from "./OffchainAssetVaultCreator.sol";

contract DepositTest is Test, CreateOffchainAssetReceiptVaultFactory {
    using LibFixedPointMath for uint256;

    event DepositWithReceipt(
        address sender, address owner, uint256 assets, uint256 shares, uint256 id, bytes receiptInformation
    );

    /// Test deposit function
    function testDeposit(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        minShareRatio = bound(minShareRatio, 0, 1e18);
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        // Set up the event expectation for DepositWithReceipt
        vm.expectEmit(false, false, false, true);
        emit DepositWithReceipt(bob, bob, assets, assets, 1, fuzzedReceiptInformation);

        // Call the deposit function that should emit the event
        vault.deposit(assets, bob, minShareRatio, fuzzedReceiptInformation);

        // Stop the prank
        vm.stopPrank();

        // Assert that the total supply and total assets are equal after the deposit
        assertEqUint(vault.totalSupply(), vault.totalAssets());
    }

    /// Test multiple deposits increment the ID
    function testMultipleDeposit(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 assetsSecondDeposit,
        uint256 minShareRatio,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        // Bound assets
        assets = bound(assets, 1, type(uint256).max / 2);
        assetsSecondDeposit = bound(assetsSecondDeposit, 1, type(uint256).max / 2);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice to grant role
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);

        // Prank as Bob for transactions
        vm.startPrank(bob);

        // Set up the event expectation for DepositWithReceipt
        vm.expectEmit(false, false, false, true);
        emit DepositWithReceipt(bob, bob, assets, assets, 1, fuzzedReceiptInformation);

        // Call the deposit function that should emit the event
        vault.deposit(assets, bob, minShareRatio, fuzzedReceiptInformation);

        assertEqUint(vault.totalSupply(), vault.totalAssets());

        // Set up the event expectation for DepositWithReceipt for the second deposit with increased ID
        vm.expectEmit(false, false, false, true);
        emit DepositWithReceipt(bob, bob, assetsSecondDeposit, assetsSecondDeposit, 2, fuzzedReceiptInformation);

        // Call the deposit function that should emit the event
        vault.deposit(assetsSecondDeposit, bob, minShareRatio, fuzzedReceiptInformation);

        // Stop the prank
        vm.stopPrank();

        // Assert that the total supply and total assets are equal after the deposit
        assertEqUint(vault.totalSupply(), vault.totalAssets());
    }

    /// Test to check deposit reverts with MinShareRatio
    function testMinShareRatio(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory receiptInformation
    ) external {
        minShareRatio = bound(minShareRatio, 1e18 + 1, type(uint256).max);
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);

        // Prank as Bob for transactions
        vm.startPrank(bob);

        vm.expectRevert(abi.encodeWithSelector(MinShareRatio.selector, minShareRatio, 1e18));
        vault.deposit(assets, bob, minShareRatio, receiptInformation);

        vm.stopPrank();
    }

    /// Test to check deposit reverts with ZeroAssetsAmount
    function testZeroAssetsAmount(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        bytes memory receiptInformation,
        uint256 minShareRatio
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        uint256 assets = 0;

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice to grant role
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);

        // Prank as Bob for transactions
        vm.startPrank(bob);

        vm.expectRevert(abi.encodeWithSelector(ZeroAssetsAmount.selector));
        vault.deposit(assets, bob, minShareRatio, receiptInformation);

        vm.stopPrank();
    }

    function testZeroReceiver(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory receiptInformation
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);

        // Prank as Bob for transaction
        vm.startPrank(bob);

        vm.expectRevert(abi.encodeWithSelector(ZeroReceiver.selector));
        vault.deposit(assets, address(0), minShareRatio, receiptInformation);

        vm.stopPrank();
    }

    /// Test deposit to someone else reverts if system not certified
    function testDepositToSomeoneElseExpiredCertification(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        uint256 timestamp
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        timestamp = bound(timestamp, 1, type(uint32).max);

        // Assume that assets is less uint256 max
        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        vault.grantRole(vault.DEPOSITOR(), bob);

        // Prank as bob for transaction
        vm.startPrank(bob);

        vm.warp(timestamp);

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, address(0), alice, 0, timestamp));

        vault.deposit(assets, alice, minShareRatio, receiptInformation);

        vm.stopPrank();
    }

    /// Test deposit to someone else with DEPOSITOR role
    function testDepositToSomeoneElseWithDepositorRole(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory fuzzedReceiptInformation
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        minShareRatio = bound(minShareRatio, 0, 1e18);

        // Assume that assets is less uint256 max
        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.DEPOSITOR(), bob);

        // Prank as Bob for transaction
        vm.startPrank(bob);

        // Set up the event expectation for DepositWithReceipt
        vm.expectEmit(false, false, false, true);
        emit DepositWithReceipt(bob, alice, assets, assets, 1, fuzzedReceiptInformation);

        vault.deposit(assets, alice, minShareRatio, fuzzedReceiptInformation);

        // Assert that the total supply and total assets are equal after the deposit
        assertEqUint(vault.totalSupply(), vault.totalAssets());
        vm.stopPrank();
    }

    /// Test PreviewDeposit returns correct shares
    function testPreviewDepositReturnedShares(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        uint256 assets
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);

        // Prank as Bob for transaction
        vm.startPrank(bob);
        uint256 shares = vault.previewDeposit(assets);

        assertEqUint(shares, assets);

        vm.stopPrank();
    }

    //Test PreviewMint without depositor role
    function testPreviewMintRevertWithoutRole(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        uint256 shares
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        shares = bound(shares, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        vm.startPrank(bob);
        vm.expectRevert();
        vault.previewMint(shares);

        vm.stopPrank();
    }

    //Test PreviewMint returns correct assets
    function testPreviewMintReturnedAssets(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        uint256 shares
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);
        // Prank as Bob for the transactions

        vm.startPrank(bob);
        uint256 assets = vault.previewMint(shares);

        assertEqUint(assets, shares);

        vm.stopPrank();
    }

    /// Test deposit without depositor role
    function testDepositWithoutDepositorRole(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);

        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);
        // Assume that assets is less uint256 max
        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        vm.expectRevert();
        // Call the deposit function that should emit the event
        vault.deposit(assets, alice, minShareRatio, fuzzedReceiptInformation);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test deposit without depositor role for admin
    function testDepositWithoutDepositorRoleForAdmin(
        uint256 fuzzedKeyAlice,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        minShareRatio = bound(minShareRatio, 0, 1e18);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Assume that assets is less uint256 max
        assets = bound(assets, 1, type(uint256).max);

        vm.expectRevert();
        // Call the deposit function that should emit the event
        vault.deposit(assets, alice, minShareRatio, fuzzedReceiptInformation);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test mint function
    function testMint(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        uint256 assets,
        bytes memory receiptInformation,
        uint256 minShareRatio
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);

        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Assume that assets is less uint256 max
        assets = bound(assets, 1, type(uint256).max);

        // Prank as Alice to grant role
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);

        // Prank as Bob for transaction
        vm.startPrank(bob);

        // Set up the event expectation for DepositWithReceipt
        vm.expectEmit(true, true, true, true);
        emit DepositWithReceipt(bob, bob, assets, assets, 1, receiptInformation);

        vault.mint(assets, bob, minShareRatio, receiptInformation);

        // Assert that the total supply and total assets are equal after the deposit
        assertEqUint(vault.totalSupply(), vault.totalAssets());

        vm.stopPrank();
    }
}
