// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import {CreateOffchainAssetReceiptVaultFactory} from "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {OffchainAssetReceiptVault} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";
import {OffchainAssetVaultCreator} from "./OffchainAssetVaultCreator.sol";
import {LibFixedPointMath, Math} from "@rainprotocol/rain-protocol/contracts/math/LibFixedPointMath.sol";

contract Confiscate is Test, CreateOffchainAssetReceiptVaultFactory {
    using LibFixedPointMath for uint256;

    event ConfiscateShares(address sender, address confiscatee, uint256 confiscated, bytes justification);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event ConfiscateReceipt(address sender, address confiscatee, uint256 id, uint256 confiscated, bytes justification);
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /// Test to checks ConfiscateShares is NOT emitted on zero balance
    function testConfiscateOnZeroBalance(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        vm.assume(alice != bob);
        // Prank as Alice for the transaction
        vm.startPrank(alice);
        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        vault.grantRole(vault.CONFISCATOR(), alice);

        // Stop recording logs
        Vm.Log[] memory logs = vm.getRecordedLogs();
        vault.confiscateShares(bob, data);

        // Check the logs to ensure event is not present
        bool eventFound = false;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == ConfiscateShares.selector) {
                eventFound = true;
                break;
            }
        }

        assertFalse(eventFound, "ConfiscateShares event should not be emitted");
        vm.stopPrank();
    }

    /// Test to check ConfiscateShares
    function testConfiscateShares(
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
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        referenceBlockNumber = bound(referenceBlockNumber, 0, blockNumber);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        vm.assume(alice != bob);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice to set roles
        vm.startPrank(alice);
        vault.grantRole(vault.CONFISCATOR(), bob);
        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.CERTIFIER(), bob);

        // Prank as Bob for transactions
        vm.startPrank(bob);

        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, forceUntil, data);

        // Assume that assets is less than totalSupply
        assets = bound(assets, 1, type(uint256).max);

        vault.deposit(assets, alice, minShareRatio, data);

        vm.expectEmit(false, false, false, true);
        emit ConfiscateShares(bob, alice, assets, data);

        vault.confiscateShares(alice, data);
        vm.stopPrank();
    }

    /// Test to checks Confiscated amount is transferred
    function testConfiscatedIsTransferred(
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
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        referenceBlockNumber = bound(referenceBlockNumber, 0, blockNumber);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        vm.assume(alice != bob);
        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice to set roles
        vm.startPrank(alice);
        vault.grantRole(vault.CONFISCATOR(), bob);
        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.CERTIFIER(), bob);

        // Prank as Bob for transactions
        vm.startPrank(bob);

        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, forceUntil, data);

        // Assume that assets is less than uint256 max
        assets = bound(assets, 1, type(uint256).max);

        vault.deposit(assets, alice, minShareRatio, data);

        vm.expectEmit(false, false, false, true);
        emit Transfer(alice, bob, assets);

        vault.confiscateShares(alice, data);
        vm.stopPrank();
    }

    /// Test to checks ConfiscateReceipt is NOT emitted on zero balance
    function testConfiscateReceiptOnZeroBalance(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint256 id
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        id = bound(id, 0, type(uint256).max);
        vm.assume(alice != bob);
        // Prank as Alice for the transaction
        vm.startPrank(alice);
        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        vault.grantRole(vault.CONFISCATOR(), alice);

        // Stop recording logs
        Vm.Log[] memory logs = vm.getRecordedLogs();
        vault.confiscateReceipt(bob, id, data);

        // Check the logs to ensure event is not present
        bool eventFound = false;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == ConfiscateReceipt.selector) {
                eventFound = true;
                break;
            }
        }

        assertFalse(eventFound, "ConfiscateReceipt event should not be emitted");
        vm.stopPrank();
    }

    /// Test to checks ConfiscateReceipt
    function testConfiscateReceipt(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 minShareRatio,
        uint256 assets,
        string memory assetName,
        bytes memory data,
        uint256 certifyUntil,
        uint256 referenceBlockNumber,
        uint256 blockNumber,
        bool forceUntil
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        referenceBlockNumber = bound(referenceBlockNumber, 0, blockNumber);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        // Assume that assets is less than uint256 max
        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetName);

        vm.assume(alice != bob);
        // Prank as Alice to set roles
        vm.startPrank(alice);
        vault.grantRole(vault.CONFISCATOR(), bob);
        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.CERTIFIER(), bob);

        // Prank as Bob for transactions
        vm.startPrank(bob);

        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, forceUntil, data);

        vault.deposit(assets, alice, minShareRatio, data);

        vm.expectEmit(false, false, false, true);
        emit ConfiscateReceipt(bob, alice, 1, assets, data);

        vault.confiscateReceipt(alice, 1, data);
        vm.stopPrank();
    }

    /// Test to checks ConfiscatedReceipt amount is transferred
    function testConfiscatedReceiptIsTransferred(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 minShareRatio,
        uint256 assets,
        string memory assetName,
        bytes memory data,
        uint256 certifyUntil,
        uint256 referenceBlockNumber,
        uint256 blockNumber,
        bool forceUntil
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        referenceBlockNumber = bound(referenceBlockNumber, 0, blockNumber);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetName);

        // Prank as Alice to set roles
        vm.startPrank(alice);
        vault.grantRole(vault.CONFISCATOR(), bob);
        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.CERTIFIER(), bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, forceUntil, data);

        //set upperBound for assets so it does not overflow
        uint256 upperBound = type(uint256).max / 1e18;
        // Assume that assets is less than totalSupply
        assets = bound(assets, 1, upperBound);

        vault.deposit(assets, alice, minShareRatio, data);
        vault.deposit(assets, alice, minShareRatio, data);

        vm.expectEmit(false, false, false, true);
        emit TransferSingle(address(vault), alice, bob, 1, assets);

        vault.confiscateReceipt(alice, 1, data);
        vm.stopPrank();
    }
}
