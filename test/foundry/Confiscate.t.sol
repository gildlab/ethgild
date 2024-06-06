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

    /// Test to checks ConfiscateShares is NOT emitted on zero balance
    function testConfiscateOnZeroBalance(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        bytes memory justification
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyBob = bound(fuzzedKeyBob, 1, SECP256K1_ORDER - 1);
        address bob = vm.addr(fuzzedKeyBob);

        vm.assume(alice != bob);
        // Prank as Alice for the transaction
        vm.startPrank(alice);
        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        vault.grantRole(vault.CONFISCATOR(), alice);

        // Stop recording logs
        Vm.Log[] memory logs = vm.getRecordedLogs();
        vault.confiscateShares(bob, justification);

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

    /// Test to checks ConfiscateShares
    function testConfiscateShares(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 shareRatio,
        uint256 aliceAssets,
        string memory assetName,
        string memory assetSymbol,
        bytes memory justification,
        uint256 certifyUntil,
        uint256 fuzzedBlockNumber
    ) external {
        shareRatio = bound(shareRatio, 1, 1e18);
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyBob = bound(fuzzedKeyBob, 1, SECP256K1_ORDER - 1);
        address bob = vm.addr(fuzzedKeyBob);

        fuzzedBlockNumber = bound(fuzzedBlockNumber, 1, 1e6);
        certifyUntil = bound(certifyUntil, 1, fuzzedBlockNumber);

        vm.assume(alice != bob);
        // Prank as Alice for the transaction
        vm.startPrank(alice);
        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);
        vault.grantRole(vault.CONFISCATOR(), alice);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.CERTIFIER(), alice);

        // Call the certify function
        vault.certify(certifyUntil, block.number, false, justification);

        //set upperBound for assets so it does not overflow while calculating fixedPointDiv or fixedPointMul
        uint256 upperBound = type(uint256).max / 1e18;
        // Assume that aliceAssets is less than totalSupply
        aliceAssets = bound(aliceAssets, 1, upperBound);

        // Divide alice assets to 3 to have enough assets for redeposit
        vault.deposit(aliceAssets, bob, shareRatio, justification);

        vm.expectEmit(true, true, true, true);
        emit ConfiscateShares(alice, bob, aliceAssets, justification);

        vault.confiscateShares(bob, justification);
        vm.stopPrank();
    }

    /// Test to checks Confiscated amount is transferred
    function testConfiscatedIsTransferred(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 shareRatio,
        uint256 aliceAssets,
        string memory assetName,
        string memory assetSymbol,
        bytes memory justification,
        uint256 certifyUntil,
        uint256 fuzzedBlockNumber
    ) external {
        shareRatio = bound(shareRatio, 1, 1e18);
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyBob = bound(fuzzedKeyBob, 1, SECP256K1_ORDER - 1);
        address bob = vm.addr(fuzzedKeyBob);

        fuzzedBlockNumber = bound(fuzzedBlockNumber, 1, 1e6);
        certifyUntil = bound(certifyUntil, 1, fuzzedBlockNumber);

        vm.assume(alice != bob);
        // Prank as Alice for the transaction
        vm.startPrank(alice);
        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);
        vault.grantRole(vault.CONFISCATOR(), alice);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.CERTIFIER(), alice);

        // Call the certify function
        vault.certify(certifyUntil, block.number, false, justification);

        //set upperBound for assets so it does not overflow while calculating fixedPointDiv or fixedPointMul
        uint256 upperBound = type(uint256).max / 1e18;
        // Assume that aliceAssets is less than totalSupply
        aliceAssets = bound(aliceAssets, 1, upperBound);

        // Divide alice assets to 3 to have enough assets for redeposit
        vault.deposit(aliceAssets, bob, shareRatio, justification);

        vm.expectEmit(true, true, true, true);
        emit Transfer(bob, alice, aliceAssets);

        vault.confiscateShares(bob, justification);
        vm.stopPrank();
    }

    /// Test to checks ConfiscateReceipt
    function testConfiscateReceipt(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 shareRatio,
        uint256 aliceAssets,
        string memory assetName,
        string memory assetSymbol,
        bytes memory justification,
        uint256 certifyUntil,
        uint256 fuzzedBlockNumber
    ) external {
        shareRatio = bound(shareRatio, 1, 1e18);
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyBob = bound(fuzzedKeyBob, 1, SECP256K1_ORDER - 1);
        address bob = vm.addr(fuzzedKeyBob);

        fuzzedBlockNumber = bound(fuzzedBlockNumber, 1, 1e6);
        certifyUntil = bound(certifyUntil, 1, fuzzedBlockNumber);

        vm.assume(alice != bob);
        // Prank as Alice for the transaction
        vm.startPrank(alice);
        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);
        vault.grantRole(vault.CONFISCATOR(), alice);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.CERTIFIER(), alice);

        // Call the certify function
        vault.certify(certifyUntil, block.number, false, justification);

        //set upperBound for assets so it does not overflow while calculating fixedPointDiv or fixedPointMul
        uint256 upperBound = type(uint256).max / 1e18;
        // Assume that aliceAssets is less than totalSupply
        aliceAssets = bound(aliceAssets, 1, upperBound);

        // Divide alice assets to 3 to have enough assets for redeposit
        vault.deposit(aliceAssets, bob, shareRatio, justification);

        vm.expectEmit(true, true, true, true);
        emit ConfiscateReceipt(alice, bob, 1, aliceAssets, justification);

        vault.confiscateReceipt(bob, 1, justification);
        vm.stopPrank();
    }
}
