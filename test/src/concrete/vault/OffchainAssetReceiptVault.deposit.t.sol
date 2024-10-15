// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {MinShareRatio, ZeroAssetsAmount, ZeroReceiver} from "../../../../../src/abstract/ReceiptVault.sol";
import {
    OffchainAssetReceiptVault,
    CertificationExpired
} from "../../../../../src/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {LibOffchainAssetVaultCreator} from "test/lib/LibOffchainAssetVaultCreator.sol";
import {IReceiptVaultV1} from "../../../../../src/interface/IReceiptVaultV1.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract OffchainAssetReceiptVaultDepositTest is OffchainAssetReceiptVaultTest {
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
        minShareRatio = bound(minShareRatio, 0, 1e18);

        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(bob, bob, assets, assets, 1, fuzzedReceiptInformation);

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
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        // Bound assets
        assets = bound(assets, 1, type(uint256).max / 2);
        assetsSecondDeposit = bound(assetsSecondDeposit, 1, type(uint256).max / 2);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to grant role
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);

        // Prank as Bob for transactions
        vm.startPrank(bob);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(bob, bob, assets, assets, 1, fuzzedReceiptInformation);

        // Call the deposit function that should emit the event
        vault.deposit(assets, bob, minShareRatio, fuzzedReceiptInformation);

        assertEqUint(vault.totalSupply(), vault.totalAssets());

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(bob, bob, assetsSecondDeposit, assetsSecondDeposit, 2, fuzzedReceiptInformation);

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
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

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
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        uint256 assets = 0;

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

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
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

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
    function testDepositToSomeoneElseNotCertified(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        uint256 timestamp
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        timestamp = bound(timestamp, 1, type(uint32).max);

        // Assume that assets is less uint256 max
        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

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

    /// Test deposit to someone else reverts if system certification expired
    function testDepositToSomeoneElseExpiredCertification(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        uint256 timestamp,
        uint256 nextTimestamp,
        uint256 blockNumber
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        timestamp = bound(timestamp, 1, type(uint32).max - 1); // Need to subtract 1 for the next bound
        nextTimestamp = bound(nextTimestamp, timestamp + 1, type(uint32).max);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        // Assume that assets are within a valid range
        assets = bound(assets, 1, type(uint256).max - 1);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.CERTIFIER(), bob);
        vm.stopPrank();

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        vm.warp(timestamp);
        // Certify system till the current timestamp
        vault.certify(timestamp, blockNumber, false, receiptInformation);

        // Set nextTimestamp as timestamp
        vm.warp(nextTimestamp);

        // Expect revert because the certification is expired
        vm.expectRevert(
            abi.encodeWithSelector(CertificationExpired.selector, address(0), alice, timestamp, nextTimestamp)
        );

        // Attempt to deposit, should revert
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
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        minShareRatio = bound(minShareRatio, 0, 1e18);

        // Assume that assets is less uint256 max
        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.DEPOSITOR(), bob);

        // Prank as Bob for transaction
        vm.startPrank(bob);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(bob, alice, assets, assets, 1, fuzzedReceiptInformation);

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
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);

        // Prank as Bob for transaction
        vm.startPrank(bob);
        uint256 shares = vault.previewDeposit(assets, 0);

        assertEqUint(shares, assets);

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
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        // Assume that assets is less uint256 max
        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

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

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

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
}
