// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import {CreateOffchainAssetReceiptVaultFactory} from "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {
    OffchainAssetReceiptVault,
    ZeroCertifyUntil,
    FutureReferenceBlock
} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultFactory} from
    "../../contracts/vault/offchainAsset/OffchainAssetReceiptVaultFactory.sol";
import {OffchainAssetVaultCreator} from "./OffchainAssetVaultCreator.sol";

contract CertifyTest is Test, CreateOffchainAssetReceiptVaultFactory {
    event Certify(address sender, uint256 certifyUntil, uint256 referenceBlockNumber, bool forceUntil, bytes data);
    event DepositWithReceipt(
        address sender, address owner, uint256 assets, uint256 shares, uint256 id, bytes receiptInformation
    );

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
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        vm.roll(blockNumber);
        referenceBlockNumber = bound(referenceBlockNumber, 0, blockNumber);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice to grant role
        vm.startPrank(alice);

        // Grant CERTIFIER role to Alice
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
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        vm.roll(blockNumber);
        referenceBlockNumber = bound(referenceBlockNumber, 0, blockNumber);

        uint256 certifyUntil = 0;

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice to grant role
        vm.startPrank(alice);

        // Grant CERTIFIER role to Alice
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
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        blockNumber = bound(block.number, 0, type(uint256).max);
        vm.roll(blockNumber);
        fuzzedFutureBlockNumber = bound(fuzzedFutureBlockNumber, blockNumber + 1, type(uint256).max - 1);

        certifyUntil = bound(certifyUntil, 1, blockNumber);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

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
        string memory assetName,
        string memory assetSymbol,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory data,
        uint256 certifyUntil,
        uint256 forceCertifyUntil,
        uint256 blockNumber
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);
        forceCertifyUntil = bound(forceCertifyUntil, 1, type(uint32).max);
        vm.assume(certifyUntil != forceCertifyUntil);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        // Assume that assets are within a valid range
        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.CERTIFIER(), bob);
        vm.stopPrank();

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        // Certify system
        vault.certify(certifyUntil, blockNumber, false, data);

        // Certify with forceUntil true
        vault.certify(forceCertifyUntil, blockNumber, true, data);

        // Call deposit to make sure system is certified
        vm.expectEmit(false, false, false, true);
        emit DepositWithReceipt(bob, alice, assets, assets, 1, data);

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
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        // Ensure the fuzzed key is within the valid range for secp256k1
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        // Assume that assets is less uint256 max
        assets = bound(assets, 1, type(uint256).max);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        referenceBlockNumber = bound(referenceBlockNumber, 0, blockNumber);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        vm.assume(alice != bob);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice to grant roles
        vm.startPrank(alice);
        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.CERTIFIER(), bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);
        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, forceUntil, data);

        // Set up the event expectation for DepositWithReceipt
        vm.expectEmit(false, false, false, true);
        emit DepositWithReceipt(bob, alice, assets, assets, 1, data);
        vault.deposit(assets, alice, minShareRatio, data);

        vm.stopPrank();
    }
}
