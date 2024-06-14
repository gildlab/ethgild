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

    /// Test redeposit function
    function testReDeposit(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 assetsToRedeposit,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol,
        uint256 minShareRatio,
        uint256 timestamp,
        uint256 blockNumber
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        minShareRatio = bound(minShareRatio, 0, 1e18);
        timestamp = bound(timestamp, 1, type(uint32).max);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);
        // Bound assets
        assets = bound(assets, 1, type(uint256).max / 2);
        assetsToRedeposit = bound(assetsToRedeposit, 1, type(uint256).max / 2);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        // Prank as Alice to set roles
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);
        vault.grantRole(vault.CERTIFIER(), bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        vm.warp(timestamp);
        // Certify system till the current timestamp
        vault.certify(timestamp, blockNumber, false, data);

        vault.deposit(assets, alice, minShareRatio, data);

        vm.expectEmit(false, false, false, true);
        emit DepositWithReceipt(bob, alice, assetsToRedeposit, assetsToRedeposit, 1, data);

        // Redeposit
        vault.redeposit(assetsToRedeposit, alice, 1, data);

        vm.stopPrank();
    }

    /// Test redeposit to someone else reverts with certification expired
    function testReDepositToSomeoneElseReverts(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol,
        uint256 minShareRatio,
        uint256 timestamp,
        uint256 futureTimestamp,
        uint256 blockNumber
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        timestamp = bound(timestamp, 1, type(uint32).max - 1); // Need to subtract 1 for the next bound
        futureTimestamp = bound(futureTimestamp, timestamp + 1, type(uint32).max);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

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

        vm.warp(timestamp);
        // Certify system till the current timestamp
        vault.certify(timestamp, blockNumber, false, data);

        vm.expectEmit(false, false, false, true);
        emit DepositWithReceipt(bob, alice, assets, assets, 1, data);
        vault.deposit(assets, alice, minShareRatio, data);

        vm.warp(futureTimestamp);

        // Expect revert because the certification is expired
        vm.expectRevert(
            abi.encodeWithSelector(CertificationExpired.selector, address(0), alice, timestamp, futureTimestamp)
        );

        // Attempt to deposit, should revert
        vault.redeposit(assets, alice, 1, data);

        vm.stopPrank();
    }

    /// Test redeposit to someone else with Depositor role
    function testReDepositToSomeoneElse(
        uint256 fuzzedKeyAlice,
        uint256 assets,
        uint256 fuzzedKeyBob,
        uint256 minShareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);
        minShareRatio = bound(minShareRatio, 0, 1e18);

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
            // Assume that assets is less than totalSupply
            assets = bound(assets, 1, upperBound);

            vault.grantRole(vault.DEPOSITOR(), alice);
            vault.grantRole(vault.DEPOSITOR(), bob);
        }

        // Divide alice assets to 3 to have enough assets for redeposit
        uint256 assetsToDeposit = assets.fixedPointDiv(3, Math.Rounding.Down);
        uint256 expectedShares = assetsToDeposit.fixedPointMul(1e18, Math.Rounding.Up);

        vault.deposit(assetsToDeposit, bob, minShareRatio, data);

        // Set up the event expectation for DepositWithReceipt
        vm.expectEmit(true, true, true, true);
        emit DepositWithReceipt(alice, bob, assetsToDeposit, expectedShares, 1, data);

        // Redeposit same amount
        vault.redeposit(assetsToDeposit, bob, 1, data);

        vm.stopPrank();
    }

    /// Test redeposit to someone else While system is certified
    function testReDepositToSomeoneElseWhileCertified(
        uint256 fuzzedKeyAlice,
        uint256 assets,
        uint256 fuzzedKeyBob,
        uint256 minShareRatio,
        bytes memory data,
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

        minShareRatio = bound(minShareRatio, 0, 1e18);
        referenceBlockNumber = bound(referenceBlockNumber, 1, block.number);
        certifyUntil = bound(certifyUntil, 1, 1e6 - 1);

        vm.assume(alice != bob);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        {
            //set upperBound for assets so it does not overflow while calculating fixedPointDiv or fixedPointMul
            uint256 upperBound = type(uint256).max / 1e18;
            // Assume that assets is less than totalSupply
            assets = bound(assets, 1, upperBound);

            vault.grantRole(vault.DEPOSITOR(), alice);
            vault.grantRole(vault.DEPOSITOR(), bob);
            vault.grantRole(vault.CERTIFIER(), alice);
        }

        // Divide alice assets to 3 to have enough assets for redeposit
        uint256 assetsToDeposit = assets.fixedPointDiv(3, Math.Rounding.Down);

        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, false, data);

        vault.deposit(assetsToDeposit, bob, minShareRatio, data);

        uint256 expectedShares = assetsToDeposit.fixedPointMul(1e18, Math.Rounding.Up);

        // Set up the event expectation for DepositWithReceipt
        vm.expectEmit(true, true, true, true);
        emit DepositWithReceipt(alice, bob, assetsToDeposit, expectedShares, 1, data);

        // Redeposit same amount
        vault.redeposit(assetsToDeposit, bob, 1, data);

        vm.stopPrank();
    }

    /// Test redeposit reverts on nonexistent receipt id
    function testReDepositToNonExistentReceipt(
        uint256 fuzzedKeyAlice,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);
        minShareRatio = bound(minShareRatio, 0, 1e18);

        // Prank as Alice for the transaction
        vm.startPrank(alice);
        // Start recording logs
        vm.recordLogs();
        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        //set upperBound for assets so it does not overflow while calculating fixedPointDiv or fixedPointMul
        uint256 upperBound = type(uint256).max / 1e18;
        // Assume that assets is less than totalSupply
        assets = bound(assets, 1, upperBound);

        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.deposit(assets, alice, minShareRatio, data);

        vm.expectRevert(abi.encodeWithSelector(InvalidId.selector, 0));
        vault.redeposit(assets, alice, 0, data);

        vm.stopPrank();
    }
}
