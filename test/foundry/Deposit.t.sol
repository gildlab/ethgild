// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import {
    MinShareRatio, ZeroAssetsAmount, ZeroReceiver, InvalidId
} from "../../contracts/vault/receipt/ReceiptVault.sol";
import {CreateOffchainAssetReceiptVaultFactory} from "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfig,
    ZeroAdmin,
    NonZeroAsset,
    CertificationExpired
} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";
import {IReceiptV1} from "../../contracts/vault/receipt/IReceiptV1.sol";
import {TestErc20} from "../../contracts/test/TestErc20.sol";
import {TestErc20} from "../../contracts/test/TestErc20.sol";
import {LibFixedPointMath, Math} from "@rainprotocol/rain-protocol/contracts/math/LibFixedPointMath.sol";
import {OffchainAssetVaultCreator} from "./OffchainAssetVaultCreator.sol";

contract DepositTest is Test, CreateOffchainAssetReceiptVaultFactory {
    using LibFixedPointMath for uint256;

    event OffchainAssetReceiptVaultInitialized(address sender, OffchainAssetReceiptVaultConfig config);
    event DepositWithReceipt(
        address sender, address owner, uint256 assets, uint256 shares, uint256 id, bytes receiptInformation
    );

    /// Test deposit function
    function testDeposit(
        uint256 fuzzedKeyAlice,
        uint256 aliceAssets,
        uint256 shareRatio,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        shareRatio = bound(shareRatio, 1, 1e18);
        address alice = vm.addr(fuzzedKeyAlice);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Assume that aliceAssets is not 0
        vm.assume(aliceAssets != 0);
        vault.grantRole(vault.DEPOSITOR(), alice);

        // Calculate expected shares
        uint256 expectedShares = aliceAssets.fixedPointMul(1e18, Math.Rounding.Up);

        // Set up the event expectation for DepositWithReceipt
        vm.expectEmit(true, true, true, true);
        emit DepositWithReceipt(alice, alice, aliceAssets, expectedShares, 1, fuzzedReceiptInformation);

        // Call the deposit function that should emit the event
        vault.deposit(aliceAssets, alice, shareRatio, fuzzedReceiptInformation);

        // Stop the prank
        vm.stopPrank();

        // Assert that the total supply and total assets are equal after the deposit
        assertEqUint(vault.totalSupply(), vault.totalAssets());
    }

    function testMinShareRatio(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 aliceAssets,
        uint256 shareRatio,
        bytes memory receiptInformation
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        vm.assume(shareRatio > 1e18);

        address alice = vm.addr(fuzzedKeyAlice);
        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Assume that aliceAssets is not 0
        vm.assume(aliceAssets != 0);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        vault.grantRole(vault.DEPOSITOR(), alice);
        vm.expectRevert(abi.encodeWithSelector(MinShareRatio.selector, shareRatio, 1e18));
        vault.deposit(aliceAssets, alice, shareRatio, receiptInformation);

        vm.stopPrank();
    }

    function testZeroReceiver(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 aliceAssets,
        uint256 shareRatio,
        bytes memory receiptInformation
    ) external {
        shareRatio = bound(shareRatio, 1, 1e18);

        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        // Assume that aliceAssets is not 0
        vm.assume(aliceAssets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);
        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        vault.grantRole(vault.DEPOSITOR(), alice);
        vm.expectRevert(abi.encodeWithSelector(ZeroReceiver.selector));
        vault.deposit(aliceAssets, address(0), shareRatio, receiptInformation);

        vm.stopPrank();
    }

    /// Test deposit to someone else reverts if system not certified
    function testDepositToSomeoneElseExpiredCertification(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 fuzzedKeyBob,
        uint256 aliceAssets,
        uint256 shareRatio,
        bytes memory receiptInformation
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyBob = bound(fuzzedKeyBob, 1, SECP256K1_ORDER - 1);
        address bob = vm.addr(fuzzedKeyBob);

        shareRatio = bound(shareRatio, 1, 1e18);

        vm.assume(alice != bob);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Assume that aliceAssets is not 0
        vm.assume(aliceAssets != 0);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        vault.grantRole(vault.DEPOSITOR(), alice);
        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, address(0), bob, 0, 1));

        vault.deposit(aliceAssets, bob, shareRatio, receiptInformation);

        vm.stopPrank();
    }

    /// Test deposit to someone else with DEPOSITOR role
    function testDepositToSomeoneElseWithDepositorRole(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 fuzzedKeyBob,
        uint256 aliceAssets,
        uint256 shareRatio,
        bytes memory fuzzedReceiptInformation
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyBob = bound(fuzzedKeyBob, 1, SECP256K1_ORDER - 1);
        address bob = vm.addr(fuzzedKeyBob);

        shareRatio = bound(shareRatio, 1, 1e18);

        vm.assume(alice != bob);
        // Assume that aliceAssets is not 0
        vm.assume(aliceAssets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.DEPOSITOR(), bob);

        // Log event
        // Start recording logs
        vm.recordLogs();

        uint256 expectedShares = aliceAssets.fixedPointMul(1e18, Math.Rounding.Up);

        // Set up the event expectation for DepositWithReceipt
        vm.expectEmit(true, true, true, true);
        emit DepositWithReceipt(alice, bob, aliceAssets, expectedShares, 1, fuzzedReceiptInformation);

        vault.deposit(aliceAssets, bob, shareRatio, fuzzedReceiptInformation);
        vm.stopPrank();
    }

    function testPreviewDepositReturnedShares(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 aliceAssets
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        // Prank as Alice for the transaction
        vm.startPrank(alice);
        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        vault.grantRole(vault.DEPOSITOR(), alice);
        uint256 shares = vault.previewDeposit(aliceAssets);

        assertEqUint(shares, aliceAssets);

        vm.stopPrank();
    }

    function testPreviewMintReturnedAssets(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 shares
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);
        uint256 shareRatio = 1e18;

        // Prank as Alice for the transaction
        vm.startPrank(alice);
        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        uint256 expectedAssets = shares.fixedPointDiv(shareRatio, Math.Rounding.Up);

        vault.grantRole(vault.DEPOSITOR(), alice);
        uint256 assets = vault.previewMint(shares);

        assertEqUint(assets, expectedAssets);

        vm.stopPrank();
    }

    /// Test mint function
    function testMint(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 aliceAssets,
        bytes memory receiptInformation,
        uint256 shareRatio
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);
        shareRatio = bound(shareRatio, 1, 1e18);

        // Assume that aliceAssets is not 0
        vm.assume(aliceAssets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Start recording logs
        vm.recordLogs();

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        vault.grantRole(vault.CERTIFIER(), alice);

        vault.grantRole(vault.DEPOSITOR(), alice);

        uint256 shares = aliceAssets.fixedPointMul(1e18, Math.Rounding.Up);

        // Set up the event expectation for DepositWithReceipt
        vm.expectEmit(true, true, true, true);
        emit DepositWithReceipt(alice, alice, aliceAssets, shares, 1, receiptInformation);

        vault.mint(shares, alice, shareRatio, receiptInformation);

        vm.stopPrank();
    }
}
