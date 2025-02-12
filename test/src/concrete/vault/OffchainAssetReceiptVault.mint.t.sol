// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {MinShareRatio, ZeroAssetsAmount, ZeroReceiver} from "src/abstract/ReceiptVault.sol";
import {OffchainAssetReceiptVault, DEPOSIT, CERTIFY} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {LibOffchainAssetVaultCreator} from "test/lib/LibOffchainAssetVaultCreator.sol";
import {IReceiptVaultV2, IReceiptVaultV1} from "src/interface/IReceiptVaultV2.sol";
import {IReceiptV2} from "src/interface/IReceiptV2.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {
    OffchainAssetReceiptVaultAuthorizorV1,
    CertificationExpired
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizorV1.sol";

contract OffchainAssetReceiptVaultDepositTest is OffchainAssetReceiptVaultTest {
    /// Test mint function
    function testMintBasic(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        uint256 shares,
        bytes memory receiptInformation,
        uint256 minShareRatio
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);

        shares = bound(shares, 1, type(uint256).max);
        uint256 assets = shares;

        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        OffchainAssetReceiptVault vault = LibOffchainAssetVaultCreator.createVault(
            vm, iFactory, iImplementation, iAuthorizorImplementation, alice, assetName, assetSymbol
        );

        // Prank as Alice to grant role
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, bob);

        // Prank as Bob for transaction
        vm.startPrank(bob);

        vm.expectEmit(true, true, true, true);
        emit IReceiptVaultV1.Deposit(bob, bob, assets, assets, 1, receiptInformation);

        uint256 actualAssets = vault.mint(shares, bob, minShareRatio, receiptInformation);

        // Assert that the total supply and total assets are equal after the mint
        assertEqUint(vault.totalSupply(), vault.totalAssets());

        assertEqUint(actualAssets, assets);

        vm.stopPrank();
    }

    /// Test multiple mint increments the ID
    function testMultipleMints(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 shares,
        uint256 sharesSecondMint,
        uint256 minShareRatio,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        // Bound shares
        shares = bound(shares, 1, type(uint256).max / 2);
        sharesSecondMint = bound(sharesSecondMint, 1, type(uint256).max / 2);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to grant role
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, bob);

        // Prank as Bob for transactions
        vm.startPrank(bob);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(bob, bob, shares, shares, 1, fuzzedReceiptInformation);

        // Call the mint function that should emit the event
        uint256 actualAssets1 = vault.mint(shares, bob, minShareRatio, fuzzedReceiptInformation);

        assertEqUint(vault.totalSupply(), vault.totalAssets());
        assertEqUint(actualAssets1, shares);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(bob, bob, sharesSecondMint, sharesSecondMint, 2, fuzzedReceiptInformation);

        // Call the mint function that should emit the event
        uint256 actualAssets2 = vault.mint(sharesSecondMint, bob, minShareRatio, fuzzedReceiptInformation);

        // Stop the prank
        vm.stopPrank();

        assertEqUint(actualAssets2, sharesSecondMint);

        // Assert that the total supply and total assets are equal after the mint
        assertEqUint(vault.totalSupply(), vault.totalAssets());
    }

    /// Test to check mint reverts with MinShareRatio
    function testMintWithMinShareRatio(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        uint256 shares,
        uint256 minShareRatio,
        bytes memory receiptInformation
    ) external {
        minShareRatio = bound(minShareRatio, 1e18 + 1, type(uint256).max);
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        shares = bound(shares, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, bob);

        // Prank as Bob for transactions
        vm.startPrank(bob);

        vm.expectRevert(abi.encodeWithSelector(MinShareRatio.selector, minShareRatio, 1e18));
        vault.mint(shares, bob, minShareRatio, receiptInformation);

        vm.stopPrank();
    }

    /// Test to check mint reverts with ZeroAssetsAmount
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

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to grant role
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, bob);

        // Prank as Bob for transactions
        vm.startPrank(bob);

        vm.expectRevert(abi.encodeWithSelector(ZeroAssetsAmount.selector));
        vault.mint(0, bob, minShareRatio, receiptInformation);

        vm.stopPrank();
    }

    function testZeroReceiver(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        uint256 shares,
        uint256 minShareRatio,
        bytes memory receiptInformation
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);

        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        shares = bound(shares, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, bob);

        // Prank as Bob for transaction
        vm.startPrank(bob);

        vm.expectRevert(abi.encodeWithSelector(ZeroReceiver.selector));
        vault.mint(shares, address(0), minShareRatio, receiptInformation);

        vm.stopPrank();
    }

    /// Test mint to someone else reverts if system not certified
    function testMintToSomeoneElseNotCertified(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 fuzzedKeyBob,
        uint256 shares,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        uint256 timestamp
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        timestamp = bound(timestamp, 1, type(uint32).max);

        // Assume that shares is less uint256 max
        shares = bound(shares, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, bob);

        // Prank as bob for transaction
        vm.startPrank(bob);

        vm.warp(timestamp);

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, address(0), alice));

        vault.mint(shares, alice, minShareRatio, receiptInformation);

        vm.stopPrank();
    }

    /// Test mint to someone else reverts if system certification expired
    function testMintToSomeoneElseExpiredCertification(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 fuzzedKeyBob,
        uint256 shares,
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

        // Assume that shares are within a valid range
        shares = bound(shares, 1, type(uint256).max - 1);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, bob);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(CERTIFY, bob);
        vm.stopPrank();

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        vm.warp(timestamp);
        // Certify system till the current timestamp
        vault.certify(timestamp, false, receiptInformation);

        // Set nextTimestamp as timestamp
        vm.warp(nextTimestamp);

        // Expect revert because the certification is expired
        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, address(0), alice));

        // Attempt to mint, should revert
        vault.mint(shares, alice, minShareRatio, receiptInformation);

        vm.stopPrank();
    }

    /// Test mint to someone else with DEPOSITOR role
    function testMintToSomeoneElseWithDepositorRole(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 fuzzedKeyBob,
        uint256 shares,
        uint256 minShareRatio,
        bytes memory fuzzedReceiptInformation
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        minShareRatio = bound(minShareRatio, 0, 1e18);

        // Assume that shares is less uint256 max
        shares = bound(shares, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, alice);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, bob);

        // Prank as Bob for transaction
        vm.startPrank(bob);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(bob, alice, shares, shares, 1, fuzzedReceiptInformation);

        vault.mint(shares, alice, minShareRatio, fuzzedReceiptInformation);

        // Assert that the total supply and total shares are equal after the mint
        assertEqUint(vault.totalSupply(), vault.totalAssets());
        vm.stopPrank();
    }

    /// Test ReceiptInformation event
    function testReceiptInformationEvent(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 fuzzedKeyBob,
        uint256 shares,
        uint256 minShareRatio,
        bytes memory fuzzedReceiptInformation
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);
        vm.assume(fuzzedReceiptInformation.length > 0);

        minShareRatio = bound(minShareRatio, 0, 1e18);

        // Assume that shares is less uint256 max
        shares = bound(shares, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, alice);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, bob);

        // Prank as Bob for transaction
        vm.startPrank(bob);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(bob, alice, shares, shares, 1, fuzzedReceiptInformation);
        vm.expectEmit(false, false, false, true);
        emit IReceiptV2.ReceiptInformation(bob, 1, fuzzedReceiptInformation);

        vault.mint(shares, alice, minShareRatio, fuzzedReceiptInformation);

        // Assert that the total supply and total shares are equal after the mint
        assertEqUint(vault.totalSupply(), vault.totalAssets());
        vm.stopPrank();
    }

    /// Test mint without depositor role
    function testMintWithoutDepositorRole(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 shares,
        uint256 minShareRatio,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);
        // Assume that shares is less uint256 max
        shares = bound(shares, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        vm.expectRevert();
        // Call the mint function that should emit the event
        vault.mint(shares, alice, minShareRatio, fuzzedReceiptInformation);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test mint without depositor role for admin
    function testMintWithoutDepositorRoleForAdmin(
        uint256 fuzzedKeyAlice,
        uint256 shares,
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

        // Assume that shares is less uint256 max
        shares = bound(shares, 1, type(uint256).max);

        vm.expectRevert();
        // Call the mint function that should emit the event
        vault.mint(shares, alice, minShareRatio, fuzzedReceiptInformation);

        // Stop the prank
        vm.stopPrank();
    }
}
