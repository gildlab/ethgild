// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {
    OffchainAssetReceiptVault,
    ZeroCertifyUntil,
    FutureReferenceBlock,
    CertificationExpired
} from "../../../../../src/concrete/vault/OffchainAssetReceiptVault.sol";
import {IReceiptV1} from "../../../../../src/interface/IReceiptV1.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {LibOffchainAssetVaultCreator} from "test/lib/LibOffchainAssetVaultCreator.sol";
import {IReceiptVaultV1} from "../../../../../src/interface/IReceiptVaultV1.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract CertifyTest is OffchainAssetReceiptVaultTest {
    event Certify(address sender, uint256 certifyUntil, uint256 referenceBlockNumber, bool forceUntil, bytes data);

    /// Test certify event
    function testCertify(
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

        vm.roll(blockNumber);
        referenceBlockNumber = bound(referenceBlockNumber, 0, blockNumber);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to grant role
        vm.startPrank(alice);

        // Grant CERTIFIER role to Bob
        vault.grantRole(vault.CERTIFIER(), bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        // Expect the Certify event
        vm.expectEmit(false, false, false, true);
        emit Certify(bob, certifyUntil, referenceBlockNumber, forceUntil, data);

        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, forceUntil, data);

        vm.stopPrank();
    }

    /// Test certify reverts on zero certify until
    function testCertifyRevertOnZeroCertifyUntil(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 referenceBlockNumber,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint256 blockNumber,
        bool forceUntil
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        vm.roll(blockNumber);
        referenceBlockNumber = bound(referenceBlockNumber, 0, blockNumber);

        uint256 certifyUntil = 0;

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to grant role
        vm.startPrank(alice);

        // Grant CERTIFIER role to Bob
        vault.grantRole(vault.CERTIFIER(), bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        // Expect to revert
        vm.expectRevert(abi.encodeWithSelector(ZeroCertifyUntil.selector, bob));

        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, forceUntil, data);

        vm.stopPrank();
    }

    /// Test certify reverts on future reference
    function testCertifyRevertOnFutureReferenceBlock(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        uint256 certifyUntil,
        bytes memory data,
        uint256 fuzzedFutureBlockNumber,
        uint256 blockNumber,
        bool forceUntil
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        blockNumber = bound(block.number, 0, type(uint256).max);
        vm.roll(blockNumber);
        fuzzedFutureBlockNumber = bound(fuzzedFutureBlockNumber, blockNumber + 1, type(uint256).max - 1);

        certifyUntil = bound(certifyUntil, 1, blockNumber);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to grant role
        vm.startPrank(alice);

        // Grant CERTIFIER role to bob
        vault.grantRole(vault.CERTIFIER(), bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        // Expect the Certify event
        vm.expectRevert(abi.encodeWithSelector(FutureReferenceBlock.selector, bob, fuzzedFutureBlockNumber));

        // Call the certify function
        vault.certify(certifyUntil, fuzzedFutureBlockNumber, forceUntil, data);

        vm.stopPrank();
    }

    /// Test certify with force until true
    function testCertifyWithForceUntilTrue(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol,
        uint256 minShareRatio,
        uint256 timestamp,
        uint256 forceCertifyUntil,
        uint256 referenceBlockNumber
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        timestamp = bound(timestamp, 1, type(uint32).max); // Need to subtract 1 for the next bound
        forceCertifyUntil = bound(forceCertifyUntil, 1, type(uint32).max);

        vm.assume(forceCertifyUntil != timestamp);
        referenceBlockNumber = bound(referenceBlockNumber, 0, type(uint256).max);

        vm.roll(referenceBlockNumber);

        // Assume that assets are within a valid range
        assets = bound(assets, 1, type(uint256).max / 2);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.CERTIFIER(), bob);
        vm.stopPrank();

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        vm.warp(timestamp);

        vm.expectEmit(false, false, false, true);
        emit Certify(bob, timestamp, referenceBlockNumber, false, data);

        // Certify system till the current timestamp
        vault.certify(timestamp, referenceBlockNumber, false, data);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(bob, alice, assets, assets, 1, data);
        vault.deposit(assets, alice, minShareRatio, data);

        vm.warp(forceCertifyUntil);

        vm.expectEmit(false, false, false, true);
        emit Certify(bob, forceCertifyUntil, referenceBlockNumber, true, data);

        // Certify system till the current timestamp
        vault.certify(forceCertifyUntil, referenceBlockNumber, true, data);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(bob, alice, assets, assets, 2, data);
        vault.deposit(assets, alice, minShareRatio, data);

        vm.stopPrank();
    }

    /// Test certify with force until true revert deposit
    function testCertifyWithForceUntilTrueRevertDeposit(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory data,
        uint256 certifyUntil,
        uint256 forceCertifyUntil,
        uint256 futureTime,
        uint256 referenceBlockNumber
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);
        forceCertifyUntil = bound(forceCertifyUntil, 1, type(uint32).max);

        futureTime = bound(futureTime, forceCertifyUntil + 1, type(uint256).max);
        referenceBlockNumber = bound(referenceBlockNumber, 0, block.number);
        // Assume that assets are within a valid range
        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.CERTIFIER(), bob);
        vm.stopPrank();

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        // Certify system till the current timestamp
        vault.certify(certifyUntil, referenceBlockNumber, false, data);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(bob, alice, assets, assets, 1, data);
        vault.deposit(assets, alice, minShareRatio, data);

        // Expect the Certify event
        vm.expectEmit(false, false, false, true);
        emit Certify(bob, forceCertifyUntil, referenceBlockNumber, true, data);

        // Certify with forceUntil true
        vault.certify(forceCertifyUntil, referenceBlockNumber, true, data);
        vm.warp(futureTime);

        // Expect revert because the certification is expired
        vm.expectRevert(
            abi.encodeWithSelector(CertificationExpired.selector, address(0), alice, forceCertifyUntil, futureTime)
        );

        // Attempt to deposit, should revert
        vault.deposit(assets, alice, minShareRatio, data);

        vm.stopPrank();
    }

    /// Test to checks vault certifiedUntil is definitely updated and vault gets certified
    function testVaultGetsCertified(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 minShareRatio,
        uint256 assets,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint256 certifyUntil,
        uint256 referenceBlockNumber,
        uint256 blockNumber,
        bool forceUntil
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);

        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        // Assume that assets is less uint256 max
        assets = bound(assets, 1, type(uint256).max);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        referenceBlockNumber = bound(referenceBlockNumber, 0, blockNumber);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        vm.assume(alice != bob);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to grant roles
        vm.startPrank(alice);
        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.CERTIFIER(), bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);
        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, forceUntil, data);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(bob, alice, assets, assets, 1, data);
        vault.deposit(assets, alice, minShareRatio, data);

        vm.stopPrank();
    }
}
