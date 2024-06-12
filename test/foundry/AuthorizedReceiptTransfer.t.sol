// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import {CreateOffchainAssetReceiptVaultFactory} from "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {
    OffchainAssetReceiptVault,
    CertificationExpired
} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";
import {OffchainAssetVaultCreator} from "./OffchainAssetVaultCreator.sol";

contract AuthorizedReceiptTransfer is Test, CreateOffchainAssetReceiptVaultFactory {
    event Certify(address sender, uint256 certifyUntil, uint256 referenceBlockNumber, bool forceUntil, bytes data);

    ///Test AuthorizeReceiptTransfer reverts if system not certified
    function testAuthorizeReceiptTransferRevert(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 warpTimestamp,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        vm.assume(alice != bob);

        // Bound warpTimestamp from 1 to avoid potential issues with timestamp 0.
        warpTimestamp = bound(warpTimestamp, 1, type(uint32).max);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Warp the block timestamp to a non-zero value
        vm.warp(warpTimestamp);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        // Assuming that the certification is expired
        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, bob, alice, 0, warpTimestamp));

        // Attempt to authorize receipt transfer, should revert
        vault.authorizeReceiptTransfer(bob, alice);

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
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        vm.assume(alice != bob);

        // Bound warpTimestamp from 1 to avoid potential issues with timestamp 0.
        timestamp = bound(timestamp, 1, type(uint32).max - 1); // Need to subtract 1 for the next bound
        nextTimestamp = bound(nextTimestamp, timestamp + 1, type(uint32).max);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

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
        vault.authorizeReceiptTransfer(bob, alice);

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
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        vm.assume(alice != bob);

        blockNumber = bound(blockNumber, 0, type(uint32).max);
        vm.roll(blockNumber);
        referenceBlockNumber = bound(referenceBlockNumber, 0, blockNumber);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

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

        vm.expectCall(address(vault), abi.encodeCall(vault.authorizeReceiptTransfer, (bob, alice)));
        // Attempt to authorize receipt transfer, should revert
        vault.authorizeReceiptTransfer(bob, alice);

        vm.stopPrank();
    }

    ///Test AuthorizeReceiptTransfer does not reverts without certification if FROM has a handler role
    function testAuthorizeReceiptTransferForHandlerFrom(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        vm.assume(alice != bob);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        vault.grantRole(vault.HANDLER(), bob);

        vm.startPrank(bob);

        vm.expectCall(address(vault), abi.encodeCall(vault.authorizeReceiptTransfer, (bob, alice)));
        vault.authorizeReceiptTransfer(bob, alice);
    }

    ///Test AuthorizeReceiptTransfer does not revert without certification if To has a handler role
    function testAuthorizeReceiptTransferForHandlerTo(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        vm.assume(alice != bob);
        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);

        vault.grantRole(vault.HANDLER(), alice);

        vm.startPrank(bob);

        vm.expectCall(address(vault), abi.encodeCall(vault.authorizeReceiptTransfer, (bob, alice)));
        vault.authorizeReceiptTransfer(bob, alice);
    }

    ///Test AuthorizeReceiptTransfer does not revert without certification if To has a confiscator role
    function testAuthorizeReceiptTransferForConfiscatorTo(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        vm.assume(alice != bob);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        vault.grantRole(vault.CONFISCATOR(), alice);

        vm.startPrank(bob);

        vm.expectCall(address(vault), abi.encodeCall(vault.authorizeReceiptTransfer, (bob, alice)));
        vault.authorizeReceiptTransfer(bob, alice);
    }
}
