// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {InvalidId} from "../../../../../contracts/abstract/ReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/foundry/abstract/OffchainAssetReceiptVaultTest.sol";

import {
    OffchainAssetReceiptVault,
    CertificationExpired
} from "../../../../../contracts/concrete/vault/OffchainAssetReceiptVault.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {LibOffchainAssetVaultCreator} from "test/foundry/lib/LibOffchainAssetVaultCreator.sol";

contract RedepositTest is OffchainAssetReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    event DepositWithReceipt(
        address sender, address owner, uint256 assets, uint256 shares, uint256 id, bytes receiptInformation
    );

    function testReDeposit(
        uint256 fuzzedKeyAlice,
        uint256 aliceAssets,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol,
        uint256 shareRatio
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);
        shareRatio = bound(shareRatio, 1, 1e18);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Start recording logs
        vm.recordLogs();
         OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        //set upperBound for assets so it does not overflow while calculating fixedPointDiv or fixedPointMul
        uint256 upperBound = type(uint256).max / 1e18;
        // Assume that aliceAssets is less than totalSupply
        aliceAssets = bound(aliceAssets, 1, upperBound);

        vault.grantRole(vault.DEPOSITOR(), alice);

        // Divide alice assets to 3 to have enough assets for redeposit
        uint256 assetsToDeposit = aliceAssets.fixedPointDiv(3, Math.Rounding.Up);
        uint256 expectedShares = assetsToDeposit.fixedPointMul(1e18, Math.Rounding.Up);
        vault.deposit(assetsToDeposit, alice, shareRatio, fuzzedReceiptInformation);

        // Set up the event expectation for DepositWithReceipt
        vm.expectEmit(true, true, true, true);
        emit DepositWithReceipt(alice, alice, assetsToDeposit, expectedShares, 1, fuzzedReceiptInformation);

        // Redeposit same amount
        vault.redeposit(assetsToDeposit, alice, 1, fuzzedReceiptInformation);

        vm.stopPrank();
    }

    /// Test redeposit to someone else reverts with certification expired
    function testReDepositToSomeoneElseReverts(
        uint256 fuzzedKeyAlice,
        uint256 aliceAssets,
        uint256 fuzzedKeyBob,
        uint256 shareRatio,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);
        shareRatio = bound(shareRatio, 1, 1e18);

        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyBob = bound(fuzzedKeyBob, 1, SECP256K1_ORDER - 1);
        address bob = vm.addr(fuzzedKeyBob);

        vm.assume(alice != bob);

        // Prank as Alice for the transaction
        vm.startPrank(alice);
        // Start recording logs
        vm.recordLogs();
         OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        //set upperBound for assets so it does not overflow while calculating fixedPointDiv or fixedPointMul
        uint256 upperBound = type(uint256).max / 1e18;
        // Assume that aliceAssets is less than totalSupply
        aliceAssets = bound(aliceAssets, 1, upperBound);

        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.deposit(aliceAssets, alice, shareRatio, fuzzedReceiptInformation);

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, address(0), bob, 0, 1));
        vault.redeposit(aliceAssets, bob, 1, fuzzedReceiptInformation);

        vm.stopPrank();
    }

    /// Test redeposit to someone else with Depositor role
    function testReDepositToSomeoneElse(
        uint256 fuzzedKeyAlice,
        uint256 aliceAssets,
        uint256 fuzzedKeyBob,
        uint256 shareRatio,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);
        shareRatio = bound(shareRatio, 1, 1e18);

        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyBob = bound(fuzzedKeyBob, 1, SECP256K1_ORDER - 1);
        address bob = vm.addr(fuzzedKeyBob);

        vm.assume(alice != bob);

        // Prank as Alice for the transaction
        vm.startPrank(alice);
        // Start recording logs
        vm.recordLogs();
         OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        {
            //set upperBound for assets so it does not overflow while calculating fixedPointDiv or fixedPointMul
            uint256 upperBound = type(uint256).max / 1e18;
            // Assume that aliceAssets is less than totalSupply
            aliceAssets = bound(aliceAssets, 1, upperBound);

            vault.grantRole(vault.DEPOSITOR(), alice);
            vault.grantRole(vault.DEPOSITOR(), bob);
        }

        // Divide alice assets to 3 to have enough assets for redeposit
        uint256 assetsToDeposit = aliceAssets.fixedPointDiv(3, Math.Rounding.Down);
        uint256 expectedShares = assetsToDeposit.fixedPointMul(1e18, Math.Rounding.Up);

        vault.deposit(assetsToDeposit, bob, shareRatio, fuzzedReceiptInformation);

        // Set up the event expectation for DepositWithReceipt
        vm.expectEmit(true, true, true, true);
        emit DepositWithReceipt(alice, bob, assetsToDeposit, expectedShares, 1, fuzzedReceiptInformation);

        // Redeposit same amount
        vault.redeposit(assetsToDeposit, bob, 1, fuzzedReceiptInformation);

        vm.stopPrank();
    }

    /// Test redeposit to someone else While system is certified
    function testReDepositToSomeoneElseWhileCertified(
        uint256 fuzzedKeyAlice,
        uint256 aliceAssets,
        uint256 fuzzedKeyBob,
        uint256 shareRatio,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol,
        uint256 certifyUntil,
        uint256 referenceBlockNumber
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyBob = bound(fuzzedKeyBob, 1, SECP256K1_ORDER - 1);
        address bob = vm.addr(fuzzedKeyBob);

        shareRatio = bound(shareRatio, 1, 1e18);
        referenceBlockNumber = bound(referenceBlockNumber, 1, block.number);
        certifyUntil = bound(certifyUntil, 1, 1e6 - 1);

        vm.assume(alice != bob);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

         OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        {
            //set upperBound for assets so it does not overflow while calculating fixedPointDiv or fixedPointMul
            uint256 upperBound = type(uint256).max / 1e18;
            // Assume that aliceAssets is less than totalSupply
            aliceAssets = bound(aliceAssets, 1, upperBound);

            vault.grantRole(vault.DEPOSITOR(), alice);
            vault.grantRole(vault.DEPOSITOR(), bob);
            vault.grantRole(vault.CERTIFIER(), alice);
        }

        // Divide alice assets to 3 to have enough assets for redeposit
        uint256 assetsToDeposit = aliceAssets.fixedPointDiv(3, Math.Rounding.Down);

        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, false, fuzzedReceiptInformation);

        vault.deposit(assetsToDeposit, bob, shareRatio, fuzzedReceiptInformation);

        uint256 expectedShares = assetsToDeposit.fixedPointMul(1e18, Math.Rounding.Up);

        // Set up the event expectation for DepositWithReceipt
        vm.expectEmit(true, true, true, true);
        emit DepositWithReceipt(alice, bob, assetsToDeposit, expectedShares, 1, fuzzedReceiptInformation);

        // Redeposit same amount
        vault.redeposit(assetsToDeposit, bob, 1, fuzzedReceiptInformation);

        vm.stopPrank();
    }

    /// Test redeposit reverts on nonexistent receipt id
    function testReDepositToNonExistentReceipt(
        uint256 fuzzedKeyAlice,
        uint256 aliceAssets,
        uint256 shareRatio,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);
        shareRatio = bound(shareRatio, 1, 1e18);

        // Prank as Alice for the transaction
        vm.startPrank(alice);
        // Start recording logs
        vm.recordLogs();
         OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        //set upperBound for assets so it does not overflow while calculating fixedPointDiv or fixedPointMul
        uint256 upperBound = type(uint256).max / 1e18;
        // Assume that aliceAssets is less than totalSupply
        aliceAssets = bound(aliceAssets, 1, upperBound);

        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.deposit(aliceAssets, alice, shareRatio, fuzzedReceiptInformation);

        vm.expectRevert(abi.encodeWithSelector(InvalidId.selector, 0));
        vault.redeposit(aliceAssets, alice, 0, fuzzedReceiptInformation);

        vm.stopPrank();
    }
}
