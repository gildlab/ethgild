// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest, Vm} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {OffchainAssetReceiptVault, CertificationExpired} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract OffchainAssetReceipetVaultAuthorizedReceiptTransferTest is OffchainAssetReceiptVaultTest {
    event Certify(address sender, uint256 certifyUntil, uint256 referenceBlockNumber, bool forceUntil, bytes data);

    ///Test AuthorizeReceiptTransfer reverts if system not certified
    function testAuthorizeReceiptTransferRevert(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 warpTimestamp,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Generate unique addresses.
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        // Bound warpTimestamp from 1 to avoid potential issues with timestamp 0.
        warpTimestamp = bound(warpTimestamp, 1, type(uint32).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Warp the block timestamp to a non-zero value.
        vm.warp(warpTimestamp);

        // Prank as Bob for the transaction.
        vm.startPrank(bob);

        // Assuming that the certification is expired.
        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, bob, alice, 0, warpTimestamp));

        // Attempt to authorize receipt transfer, should revert.
        vault.authorizeReceiptTransfer2(bob, alice);

        vm.stopPrank();
    }

    /// Test AuthorizeReceiptTransfer reverts if system certification is expired
    function testAuthorizeReceiptTransferRevertExpiredCertification(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        uint256 timestamp,
        uint256 nextTimestamp,
        uint256 blockNumber,
        bytes memory data
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        // Bound timestamp from 1 to avoid potential issues with timestamp 0.
        timestamp = bound(timestamp, 1, type(uint32).max - 1); // Need to subtract 1 for the next bound
        nextTimestamp = bound(nextTimestamp, timestamp + 1, type(uint32).max);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        vault.grantRole(vault.CERTIFIER(), bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        vm.warp(timestamp);
        // Certify system till the current timestamp
        vault.certify(timestamp, blockNumber, false, data);

        // Set nextTimestamp as timestamp
        vm.warp(nextTimestamp);

        // Expect revert because the certification is expired
        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, bob, alice, timestamp, nextTimestamp));

        // Attempt to authorize receipt transfer, should revert
        vault.authorizeReceiptTransfer2(bob, alice);

        vm.stopPrank();
    }

    /// Test AuthorizeReceiptTransfer when system certified
    function testAuthorizeReceiptTransfer(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        uint256 certifyUntil,
        uint256 referenceBlockNumber,
        bytes memory data,
        uint256 blockNumber,
        bool forceUntil
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        blockNumber = bound(blockNumber, 0, type(uint32).max);
        vm.roll(blockNumber);
        referenceBlockNumber = bound(referenceBlockNumber, 0, blockNumber);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank Alice to set role
        vm.startPrank(alice);
        vault.grantRole(vault.CERTIFIER(), bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        // Expect the Certify event
        vm.expectEmit(false, false, false, true);
        emit Certify(bob, certifyUntil, referenceBlockNumber, forceUntil, data);

        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, forceUntil, data);

        vm.expectCall(address(vault), abi.encodeCall(vault.authorizeReceiptTransfer2, (bob, alice)));
        // Authorize should succeed
        vault.authorizeReceiptTransfer2(bob, alice);

        vm.stopPrank();
    }

    /// Test AuthorizeReceiptTransfer does not revert without certification if FROM has a handler role
    function testAuthorizeReceiptTransferForHandlerFrom(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        vault.grantRole(vault.HANDLER(), bob);

        vm.startPrank(bob);

        vm.expectCall(address(vault), abi.encodeCall(vault.authorizeReceiptTransfer2, (bob, alice)));
        vault.authorizeReceiptTransfer2(bob, alice);
    }

    /// Test AuthorizeReceiptTransfer does not revert without certification if To has a handler role
    function testAuthorizeReceiptTransferForHandlerTo(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);

        vault.grantRole(vault.HANDLER(), alice);

        vm.startPrank(bob);

        vm.expectCall(address(vault), abi.encodeCall(vault.authorizeReceiptTransfer2, (bob, alice)));
        vault.authorizeReceiptTransfer2(bob, alice);
    }

    /// Test AuthorizeReceiptTransfer does not revert without certification if To has a confiscator role
    function testAuthorizeReceiptTransferForConfiscatorTo(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        vault.grantRole(vault.CONFISCATOR(), alice);

        vm.startPrank(bob);

        vm.expectCall(address(vault), abi.encodeCall(vault.authorizeReceiptTransfer2, (bob, alice)));
        vault.authorizeReceiptTransfer2(bob, alice);
    }
}
