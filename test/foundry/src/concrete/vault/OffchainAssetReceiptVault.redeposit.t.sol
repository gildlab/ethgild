// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {InvalidId, ZeroAssetsAmount} from "../../../../../contracts/abstract/ReceiptVault.sol";
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

    /// Checks that balance owner balance changes after wirthdraw
    function checkBalanceChange(
        OffchainAssetReceiptVault vault,
        address receiver,
        address owner,
        uint256 id,
        uint256 assets,
        bytes memory data
    ) internal {
        uint256 initialBalanceReceiver = vault.balanceOf(receiver);

        // Set up the event expectation for redeposit
        vm.expectEmit(false, false, false, true);
        emit DepositWithReceipt(owner, receiver, assets, assets, id, data);

        // Redeposit
        vault.redeposit(assets, receiver, id, data);

        uint256 balanceAfterReceiver = vault.balanceOf(receiver);

        assertEq(balanceAfterReceiver, initialBalanceReceiver + assets);
    }

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

        vault.deposit(assets, bob, minShareRatio, data);

        checkBalanceChange(vault, bob, bob, 1, assetsToRedeposit, data);

        vm.stopPrank();
    }

    /// Test redeposit function reverts when assets = 0
    function testReDepositRevertsWithZeroAssets(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
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

        vault.deposit(assets, bob, minShareRatio, data);

        vm.expectRevert(abi.encodeWithSelector(ZeroAssetsAmount.selector));

        // Redeposit
        vault.redeposit(0, bob, 1, data);

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
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        minShareRatio = bound(minShareRatio, 0, 1e18);

        // Assume that assets are within a valid range
        assets = bound(assets, 1, type(uint256).max / 2);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.DEPOSITOR(), bob);
        vm.stopPrank();

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        vm.expectEmit(false, false, false, true);
        emit DepositWithReceipt(bob, alice, assets, assets, 1, data);
        vault.deposit(assets, alice, minShareRatio, data);

        checkBalanceChange(vault, alice, bob, 1, assets, data);

        vm.stopPrank();
    }

    /// Test redeposit to someone else While system is certified
    function testReDepositToSomeoneElseWhileCertified(
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

        checkBalanceChange(vault, alice, bob, 1, assets, data);

        vm.stopPrank();
    }

    /// Test redeposit reverts on nonexistent receipt id
    function testReDepositToNonExistentReceipt(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol,
        uint256 minShareRatio,
        uint256 timestamp,
        uint256 blockNumber,
        uint256 id
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        timestamp = bound(timestamp, 1, type(uint32).max);
        id = bound(id, 0, type(uint256).max);
        vm.assume(id != 1); // If id is 1, it will not be an invalid

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

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
        // Certify system till the current timestamp
        vault.certify(timestamp, blockNumber, false, data);

        vm.expectEmit(false, false, false, true);
        emit DepositWithReceipt(bob, alice, assets, assets, 1, data);
        vault.deposit(assets, alice, minShareRatio, data);

        // Attempt to deposit, should revert
        vm.expectRevert(abi.encodeWithSelector(InvalidId.selector, id));
        vault.redeposit(assets, alice, id, data);

        vm.stopPrank();
    }

    /// Test redepositing works after there are several IDs due to deposit
    function testReDepositOverSeveralIds(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 depositAmount,
        uint256 anotherDepositAmount,
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
        // Bound depositAmounts
        depositAmount = bound(depositAmount, 1, type(uint64).max);
        anotherDepositAmount = bound(anotherDepositAmount, 1, type(uint64).max);
        assetsToRedeposit = bound(assetsToRedeposit, 1, type(uint64).max);

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

        vault.deposit(depositAmount, bob, minShareRatio, data);
        vault.deposit(anotherDepositAmount, bob, minShareRatio, data);
        vault.deposit(anotherDepositAmount, bob, minShareRatio, data);

        checkBalanceChange(vault, alice, bob, 1, assetsToRedeposit, data);
        checkBalanceChange(vault, alice, bob, 2, assetsToRedeposit, data);

        vm.stopPrank();
    }
}
